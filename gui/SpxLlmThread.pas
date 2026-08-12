(*
 * SpxLlmThread -- `TAuthoringLoop` from the spec (§4.5): Generate -> Verify -> Fix.
 *
 * ITS OWN THREAD, WHICH IS NEITHER OF THE OTHER TWO. The UI thread must not wait on a
 * network; the engine worker must not either, and more importantly the network call must
 * never touch the engine -- the single-thread rule around the engine's lazy global
 * (`GAbbrevs`, spec §5) stays exactly as it is. So this thread talks to providers and asks
 * the ENGINE THREAD for every verdict:
 *
 *     this thread -> TSpxEngineThread.RequestVerify -> OnVerify -> this thread
 *
 * The verify request rides its own queue over there, never the ordinary Post: Post is
 * latest-wins by design, and one typed character would silently evict a queued verify,
 * leaving this loop waiting for an answer nobody will compute.
 *
 * THE VERDICT IS THE ENGINE'S, NEVER THE MODEL'S SELF-REPORT. Verify is `SpxHealthReport`:
 * the include closure validated file by file, plus N probe renders whose empty outputs and
 * fullwidth fallback are the sign of a broken plural (spec §4.5). Nothing here re-implements
 * any of that; the loop only reads the report.
 *
 * WHAT A VERIFY VERDICT DOES, WRITTEN OUT RATHER THAN IMPLIED (the plan's own table):
 *
 *     error rows in the document      -> an automatic Fix round; a fix attempt is spent
 *     no document errors, but a file
 *       it includes has one           -> stop (loClosureError): shown, never applied, and
 *                                        not fixable -- the model cannot repair a file on
 *                                        disk. The spec's "clean" is the whole closure.
 *     no errors, but empty probes or
 *       fullwidth fallback            -> stop with the warning visible; no attempt spent
 *                                        (measured: fullwidth never travels without an
 *                                        arity error today, so its arm is defensive)
 *     clean                           -> success
 *     transport / provider / redirect
 *       / insecure / no key           -> stop; no attempt spent -- regenerating a template
 *                                        does not fix a 401, and `leRedirected` is an answer
 *                                        from the endpoint, not a failure to retry past
 *
 * "Error rows in the document" means the OPEN DOCUMENT'S OWN rows (Slug = ''), the same line
 * the manual repair path draws: a fragment's error is real and the panel shows it, but it is
 * not the candidate's to fix -- a regenerated template cannot repair a broken file on disk,
 * and burning the fix budget against one would spend the reader's money on a wall. The
 * result still carries the closure-wide counts, so the window stays honest about them.
 *
 * THE FIX LOOP IS AUTOMATIC, LIMIT 2, AND EVERY ROUND IS VISIBLE ("attempt 1 of 2") --
 * each round is the reader's money, so it is counted out loud through OnProgress. An
 * attempt is spent when a fix round's answer ARRIVES; a round that dies in transport did
 * not consume the budget, because the reader can retry it for free once the transport is
 * back.
 *
 * THE ANSWER IS APPLIED ONLY TO THE DOCUMENT THAT ASKED. A request carries an immutable
 * snapshot -- the text, locale, variables and profile it was built from, summarised by a
 * REVISION number the window bumps (Invalidate) whenever any of those change. The revision
 * is compared before every retry and before a result is delivered as applicable; a stale
 * answer comes back as `loStale`, which the window may SHOW but must never auto-apply.
 *
 * PREFLIGHT BEFORE ANY PROMPT IS BUILT. A profile that authenticates with no stored key is
 * `leNoKey`; plain http off this machine is `leInsecure` -- both answered before the
 * document is copied into a prompt, let alone a request body (spec §4.5). `SpxLlmAsk` asks
 * both again: one rule, two callers, no way past it.
 *
 * `Line = 0` IS A CODE WITHOUT A COORDINATE (spec §4.5). The repair-prompt port repeats the
 * JS byte for byte and would print `line 0, column 0`; fixing that IN the port would break
 * the fixtures that hold it to upstream. So the unplaced findings are selected out HERE, in
 * the caller -- exactly the way rows of other files are already selected out -- and travel
 * as their own list: appended after the port's prompt when located errors exist, and in
 * place of the port's "(none reported)" placeholder when none do, because a list of errors
 * after an instruction to change nothing is a contradiction (SpxLoopRepairPrompt).
 *
 * EVERY COMMENT IS STAR-PAREN, NEVER A BRACE COMMENT -- prompts in this program are full of
 * `{a|b}`.
 *)
unit SpxLlmThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Spintax, SpxStudio, SpxPrompt, SpxHttp, SpxLlm,
  SpxEngineThread;

type
  TSpxLoopOp = (loOpGenerate, loOpFix);

  TSpxLoopStage = (lsAsking, lsVerifying);

  TSpxLoopOutcome = (
    loNone,
    loClean,          (* verified: no error rows, probes healthy -- the window may apply *)
    loDegenerate,     (* no errors, but empty probes or fullwidth fallback: shown, not applied *)
    loClosureError,   (* the candidate is clean; a file it includes is not. Shown, not
                         applied, and no fix round is spent: a regenerated template cannot
                         repair a broken file on disk. "Clean verdict" in the spec is the
                         whole closure (IsValid), so this cannot ride loClean. *)
    loStillInvalid,   (* the fix budget is spent and error rows remain *)
    loNothingToFix,   (* a fix was asked for and the rows carry no document error *)
    loStale,          (* the document moved on while the answer flew: shown, never applied *)
    loProviderError,  (* preflight, transport or provider stopped it -- LlmError says which *)
    loCancelled
  );

  (* One operation, snapshotted WHOLE at the moment the reader asked. Nothing in here is read
     from the window again while the loop runs -- that is the point: the window may move on,
     and the snapshot is what the answer is about.

     For a fix, DocText and Rows MUST be the same age -- the window takes both from one
     TSpxJobResult (its Source and its Rows), never the text from the editor and the rows
     from an older answer: a pair of different ages quotes spans that point at other
     characters. *)
  TSpxLoopRequest = record
    Id: Int64;
    Op: TSpxLoopOp;
    Cfg: TSpxLlmConfig;
    (* generate inputs *)
    Brief: string;
    Channel: TSpxChannel;
    Level: TSpxVariation;
    Allowed: TSpxAllowedVars;
    (* fix inputs: the document and its findings, one age *)
    DocText: string;
    Rows: TSpxPanelRows;
    (* the verify context -- the same fields a render job carries *)
    Locale: string;
    SetFolder: string;
    DocSlug: string;
    Vars: TSpxVarPairs;
    UiLang: TSpxLang;
    NoPostProcess: Boolean;
    (* the loop's Revision at the moment the request was built; see Invalidate *)
    Revision: Int64;
    FixLimit: Integer;   (* 0 means SPX_LOOP_FIX_LIMIT *)
    Probes: Integer;     (* 0 means SPX_LOOP_PROBES *)
  end;

  (* Attempt 0 is the generate round; 1..Limit are fix rounds. The window phrases the money
     sentence; this carries the numbers. *)
  TSpxLoopProgress = record
    Id: Int64;
    Stage: TSpxLoopStage;
    Attempt: Integer;
    Limit: Integer;
  end;

  TSpxLoopResult = record
    Id: Int64;
    Op: TSpxLoopOp;
    Outcome: TSpxLoopOutcome;
    LlmError: TSpxLlmError;  (* meaningful when Outcome = loProviderError or loCancelled *)
    Status: Integer;
    Detail: string;          (* the provider's or transport's words; the redirect's address *)
    (* The candidate and the verdict it earned, of ONE age: Text is the exact string the
       rows describe (TSpxVerifyResult.Source), never a second look anywhere. *)
    HaveText: Boolean;
    Text: string;
    Errors: Integer;         (* closure-wide, the honest total *)
    DocErrors: Integer;      (* the open document's own error rows -- what the loop acts on *)
    Warnings: Integer;
    Probes, EmptyProbes: Integer;
    Fullwidth: Boolean;
    Rows: TSpxPanelRows;
    FixSpent: Integer;
    Limit: Integer;
    (* The request's snapshot revision, echoed so the WINDOW can close the last race: the
       loop checks staleness on its own thread, but an edit can land between that check and
       the synchronized delivery. Invalidate and the delivery both run on the main thread,
       so `Loop.Revision = R.Revision`, asked there right before applying, cannot be
       overtaken -- the loop-side check is the early exit, this is the guarantee. *)
    Revision: Int64;
  end;

  TSpxLoopProgressEvent = procedure(const P: TSpxLoopProgress) of object;
  TSpxLoopResultEvent = procedure(const R: TSpxLoopResult) of object;

  (* The provider call, injectable so the suite can run the whole loop against recorded
     answers -- a check that has to dial out is a check that reddens behind a proxy. The
     default is SpxLlmAsk. *)
  TSpxLlmAskFunc = function(const ACfg: TSpxLlmConfig; const APrompt: TSpxBuiltPrompt;
    const ACancel: PBoolean): TSpxLlmAnswer;

  TSpxAuthoringLoop = class(TThread)
  private
    FLock: TCriticalSection;
    FWake: TSimpleEvent;
    FEngine: TSpxEngineThread;
    FAsk: TSpxLlmAskFunc;
    FOnProgress: TSpxLoopProgressEvent;
    FOnResult: TSpxLoopResultEvent;
    FPending: TSpxLoopRequest;     (* under FLock; latest wins, displaced ones answered *)
    FHasPending: Boolean;          (* under FLock *)
    FBusy: Boolean;                (* under FLock: an op is inside RunOp *)
    FAbandoned: array of Int64;    (* under FLock: every request gets exactly one result *)
    (* Read by SpxHttp between reads and by the loop between steps. Plain Boolean writes are
       atomic; it is never read-modify-written. *)
    FCancel: Boolean;
    FRevision: Int64;              (* under FLock; see Invalidate *)
    (* the verify handoff: written by HandleVerify ON THE ENGINE THREAD *)
    FVerifyRes: TSpxVerifyResult;  (* under FLock *)
    FVerifyReady: Boolean;         (* under FLock *)
    FVerifyWake: TSimpleEvent;
    FVerifySeq: Int64;             (* this thread only *)
    (* staging for Synchronize *)
    FProgress: TSpxLoopProgress;
    FResult: TSpxLoopResult;
    procedure HandleVerify(const Res: TSpxVerifyResult);   (* ON THE ENGINE THREAD *)
    procedure DeliverProgress;                             (* main thread *)
    procedure DeliverResult;                               (* main thread *)
    function TakeRequest(out Req: TSpxLoopRequest): Boolean;
    function TakeAbandoned(out AId: Int64): Boolean;
    function WorkPending: Boolean;
    function CancelWanted: Boolean;
    function Stale(const Req: TSpxLoopRequest): Boolean;
    procedure Say(AId: Int64; AStage: TSpxLoopStage; AAttempt, ALimit: Integer);
    procedure Finish(const R: TSpxLoopResult);
    function AskVerify(const Req: TSpxLoopRequest; const AText: string; AProbes: Integer;
      out VRes: TSpxVerifyResult): Boolean;
    procedure RunOp(const Req: TSpxLoopRequest);
  protected
    procedure Execute; override;
  public
    (* Takes over AEngine.OnVerify: this loop is the verify consumer.

       TEARDOWN ORDER IS PART OF THE CONTRACT:

           Loop.Shutdown; Loop.WaitFor;
           Engine.Shutdown; Engine.WaitFor; Engine.Free;
           Loop.Free;

       The loop is JOINED first, because its thread reads FEngine (Finished, RequestVerify)
       -- an engine freed while the loop still runs is a use-after-free, which is what the
       first version of this comment prescribed (found by review). The ENGINE is joined and
       freed before Loop.Free, because it calls HandleVerify, which takes this object's
       lock. Neither wait can deadlock: the loop's verify wait polls its own termination,
       and both WaitFor calls, made from the main thread, pump the Synchronize queue
       (rtl/win/tthread.inc -- the same guarantee TSpxEngineThread.Shutdown documents). *)
    constructor Create(AEngine: TSpxEngineThread; AOnProgress: TSpxLoopProgressEvent;
      AOnResult: TSpxLoopResultEvent; AAsk: TSpxLlmAskFunc = nil);
    destructor Destroy; override;
    (* Replaces anything not yet started and cancels an op already running: the reader asked
       for something else. The displaced request still gets its one result (loCancelled).
       Safe from the UI thread. *)
    procedure Post(const Req: TSpxLoopRequest);
    (* Stops the running op between steps -- and mid-transfer: SpxHttp reads the flag
       between reads. The pending request, if any, is abandoned too. *)
    procedure Cancel;
    (* The window calls this whenever the document text, locale, variables, allow-list or
       connection profile change. A request snapshots Revision when it is built; the loop
       compares before every retry and before delivering an applicable result. *)
    procedure Invalidate;
    function Revision: Int64;
    procedure Shutdown;
  end;

const
  SPX_LOOP_FIX_LIMIT = 2;
  SPX_LOOP_PROBES = 5;

(* The document's own error rows -- what the loop's verdict and the Fix button's enabled
   state are both about. A fragment's row (Slug <> '') is somebody else's file; an unplaced
   row (Line = 0) still counts, it just travels without a coordinate. *)
function SpxLoopDocErrors(const ARows: TSpxPanelRows): Integer;

(* The repair prompt the loop sends, built from panel rows. Located document rows go through
   the byte-exact port (which filters to severity 'error' itself -- note 4 in SpxPrompt);
   unplaced document errors are appended as their own list, code without coordinate, because
   the port would print `line 0, column 0` and must not be changed (spec §4.5). Rows of
   other files are dropped: their coordinates belong to another buffer. Exported so the
   suite can hold the bytes. *)
function SpxLoopRepairPrompt(const AText, ALocale: string; const ARows: TSpxPanelRows;
  const AVars: TSpxAllowedVars): TSpxBuiltPrompt;

implementation

uses
  StrUtils;

const
  LF = #10;
  (* The port's whole empty-ERRORS block head: the section header plus its placeholder
     line, exactly as SpxBuildRepairPrompt emits them. Quoted here for the replacement in
     SpxLoopRepairPrompt; if the port's wording ever moves, the suite names the drift
     (`repair-split/the-replaced-literal-matches-the-port`) instead of the replacement
     silently missing. *)
  LOOP_PORT_EMPTY_LIST = LF + 'ERRORS:' + LF +
    '- (none reported — return the template unchanged)';

function SpxLoopDocErrors(const ARows: TSpxPanelRows): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(ARows) do
    if (ARows[i].Slug = '') and (ARows[i].Severity = 'error') then Inc(Result);
end;

function SpxLoopRepairPrompt(const AText, ALocale: string; const ARows: TSpxPanelRows;
  const AVars: TSpxAllowedVars): TSpxBuiltPrompt;
var
  diags: TSpDiagList;
  msgs: array of string;
  d: TSpDiag;
  i, n, locatedErrors, p: Integer;
  unplaced: string;
begin
  diags := TSpDiagList.Create;
  try
    SetLength(msgs, Length(ARows));
    n := 0;
    locatedErrors := 0;
    unplaced := '';
    for i := 0 to High(ARows) do
    begin
      (* The open document only. A finding inside an included fragment is real and the panel
         shows it, but its line and column are coordinates in another buffer -- handing it to
         a repair prompt would point the model at a span of a text it has never seen. *)
      if ARows[i].Slug <> '' then Continue;
      if ARows[i].Line = 0 then
      begin
        (* Errors only, the same gate the port applies to the located list: a warning does
           not go to the model with a coordinate, so it does not go without one either. *)
        if ARows[i].Severity = 'error' then
          unplaced := unplaced + '- [' + ARows[i].Code + ']: ' + ARows[i].Text +
                      ' (reported without a line or column)' + LF;
        Continue;
      end;
      d := Default(TSpDiag);
      d.Severity := ARows[i].Severity;
      d.Code := ARows[i].Code;
      d.Line := ARows[i].Line;
      d.Column := ARows[i].Column;
      diags.Add(d);
      msgs[n] := ARows[i].Text;
      Inc(n);
      if ARows[i].Severity = 'error' then Inc(locatedErrors);
    end;
    SetLength(msgs, n);
    Result := SpxBuildRepairPrompt(AText, ALocale, diags, msgs, AVars);
    (* The port stays byte-identical to its fixtures; what happens with the unplaced list
       depends on whether the port had anything to say. With located errors present, the
       list is appended after the prompt. With NONE, the port's own list is the placeholder
       "(none reported -- return the template unchanged)", and appending a list of errors
       after an instruction to change nothing hands the model a contradiction -- found by
       review. So in that case the whole empty ERRORS block head is replaced by one carrying
       the unplaced entries, each with its own "no coordinate" note. The replaced string is
       the port's exact literal (SpxPrompt.pas), and the suite fails by name if the two
       drift apart. *)
    if unplaced <> '' then
    begin
      if locatedErrors = 0 then
      begin
        (* The needle is the whole ERRORS block head, and the LAST occurrence is the one
           replaced. Both halves matter, and each closed a hole a review found: a bare
           line-start anchor was still reachable from a variable's NOTE, which the port
           quotes verbatim and which a grid paste can make multiline -- so the anchor
           carries the section header; and user-controlled text (the note, the template,
           the messages) can only appear BEFORE the real block, whose only successor is
           one fixed closing sentence -- so the last occurrence is the port's own. *)
        p := 0;
        i := Pos(LOOP_PORT_EMPTY_LIST, Result.UserPrompt);
        while i > 0 do
        begin
          p := i;
          i := PosEx(LOOP_PORT_EMPTY_LIST, Result.UserPrompt, i + 1);
        end;
        if p > 0 then
          Result.UserPrompt := Copy(Result.UserPrompt, 1, p - 1) +
            LF + 'ERRORS:' + LF + TrimRight(unplaced) +
            Copy(Result.UserPrompt, p + Length(LOOP_PORT_EMPTY_LIST), MaxInt);
      end
      else
        Result.UserPrompt := Result.UserPrompt + LF + LF +
          'These errors were also reported, but the validator could not name a line or column.' +
          LF + 'They are in the template above; find and fix them as well:' + LF +
          TrimRight(unplaced);
    end;
  finally
    diags.Free;
  end;
end;

constructor TSpxAuthoringLoop.Create(AEngine: TSpxEngineThread;
  AOnProgress: TSpxLoopProgressEvent; AOnResult: TSpxLoopResultEvent; AAsk: TSpxLlmAskFunc);
begin
  FLock := TCriticalSection.Create;
  FWake := TSimpleEvent.Create;
  FVerifyWake := TSimpleEvent.Create;
  FEngine := AEngine;
  FOnProgress := AOnProgress;
  FOnResult := AOnResult;
  FAsk := AAsk;
  if FAsk = nil then FAsk := @SpxLlmAsk;
  FEngine.OnVerify := @HandleVerify;
  inherited Create(False);
end;

destructor TSpxAuthoringLoop.Destroy;
begin
  inherited Destroy;   (* waits for Execute to leave; see Create for the teardown order *)
  FVerifyWake.Free;
  FWake.Free;
  FLock.Free;
end;

procedure TSpxAuthoringLoop.Post(const Req: TSpxLoopRequest);
begin
  FLock.Enter;
  try
    if FHasPending then
    begin
      SetLength(FAbandoned, Length(FAbandoned) + 1);
      FAbandoned[High(FAbandoned)] := FPending.Id;
    end;
    FPending := Req;
    (* The snapshot must be DEEP for its arrays: a dynamic-array assignment aliases the
       caller's storage, so a window that later edited a row in place would be editing this
       op's snapshot with it -- "immutable" by refcount only. Strings inside the records are
       safe (copy-on-write); the records themselves are not. Found by review. *)
    FPending.Allowed := Copy(Req.Allowed);
    FPending.Rows := Copy(Req.Rows);
    FPending.Vars := Copy(Req.Vars);
    FHasPending := True;
    (* An op already running is asked to stop: the reader wants something else now. Its
       result arrives as loCancelled before the new op starts. *)
    if FBusy then FCancel := True;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TSpxAuthoringLoop.Cancel;
begin
  FLock.Enter;
  try
    FCancel := True;
    if FHasPending then
    begin
      SetLength(FAbandoned, Length(FAbandoned) + 1);
      FAbandoned[High(FAbandoned)] := FPending.Id;
      FHasPending := False;
    end;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TSpxAuthoringLoop.Invalidate;
begin
  FLock.Enter;
  try
    Inc(FRevision);
  finally
    FLock.Leave;
  end;
end;

function TSpxAuthoringLoop.Revision: Int64;
begin
  FLock.Enter;
  try
    Result := FRevision;
  finally
    FLock.Leave;
  end;
end;

function TSpxAuthoringLoop.Stale(const Req: TSpxLoopRequest): Boolean;
begin
  Result := Revision <> Req.Revision;
end;

procedure TSpxAuthoringLoop.Shutdown;
begin
  Terminate;
  (* And cancel, not just terminate: a provider exchange in flight checks the cancel flag
     between reads, and without this it would run to its timeout with WaitFor hostage to
     it -- sixty seconds of a window that will not close. Found by review. *)
  FLock.Enter;
  try
    FCancel := True;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TSpxAuthoringLoop.TakeRequest(out Req: TSpxLoopRequest): Boolean;
begin
  FLock.Enter;
  try
    (* Nothing is claimed once Terminated: Execute's own check can be a step behind a
       Shutdown, and claiming here would reset the cancel flag Shutdown just raised --
       starting a provider call DURING shutdown and holding WaitFor to its timeout. The
       unclaimed request is dropped, which is what shutdown means for queued work. Found
       by review. *)
    Result := FHasPending and (not Terminated);
    if Result then
    begin
      Req := FPending;
      FHasPending := False;
      (* Marked busy and given its clear cancel flag UNDER THE SAME LOCK the take happens
         under. Done as two steps outside it, there was a window in which a Post saw FBusy
         still False, set no cancel, and the op it meant to displace ran to completion --
         delivering a full result the reader had already superseded. *)
      FBusy := True;
      FCancel := False;
    end;
  finally
    FLock.Leave;
  end;
end;

function TSpxAuthoringLoop.TakeAbandoned(out AId: Int64): Boolean;
var
  i: Integer;
begin
  FLock.Enter;
  try
    Result := Length(FAbandoned) > 0;
    if Result then
    begin
      AId := FAbandoned[0];
      for i := 1 to High(FAbandoned) do FAbandoned[i - 1] := FAbandoned[i];
      SetLength(FAbandoned, Length(FAbandoned) - 1);
    end;
  finally
    FLock.Leave;
  end;
end;

function TSpxAuthoringLoop.WorkPending: Boolean;
begin
  FLock.Enter;
  try
    Result := FHasPending or (Length(FAbandoned) > 0);
  finally
    FLock.Leave;
  end;
end;

function TSpxAuthoringLoop.CancelWanted: Boolean;
begin
  (* A plain read on purpose -- the same access SpxHttp gets through the pointer. *)
  Result := FCancel;
end;

procedure TSpxAuthoringLoop.HandleVerify(const Res: TSpxVerifyResult);
begin
  (* ON THE ENGINE THREAD. Copy under the lock, wake the waiter, return -- nothing here may
     call back into the engine thread or into the window. *)
  FLock.Enter;
  try
    FVerifyRes := Res;
    FVerifyReady := True;
  finally
    FLock.Leave;
  end;
  FVerifyWake.SetEvent;
end;

procedure TSpxAuthoringLoop.DeliverProgress;
begin
  if Assigned(FOnProgress) then FOnProgress(FProgress);
end;

procedure TSpxAuthoringLoop.DeliverResult;
begin
  (* THE LAST CHECK RUNS WHERE THE RACE ENDS. A Cancel or a superseding Post can land after
     RunOp's own checks and before this callback -- but both of those are made from the main
     thread, and this IS the main thread, so asking here is not "later", it is AFTER the
     last moment they could have happened. Only the applicable outcome is downgraded: the
     text is kept and shown, it just must not be applied to a document whose reader has
     already asked for something else. Found by review, twice -- the loop-side checks narrow
     the window and cannot close it. *)
  FLock.Enter;
  try
    if (FResult.Outcome = loClean) and (FCancel or FHasPending) then
    begin
      FResult.Outcome := loCancelled;
      FResult.LlmError := leCancelled;
    end;
  finally
    FLock.Leave;
  end;
  if Assigned(FOnResult) then FOnResult(FResult);
end;

procedure TSpxAuthoringLoop.Say(AId: Int64; AStage: TSpxLoopStage; AAttempt, ALimit: Integer);
begin
  FProgress := Default(TSpxLoopProgress);
  FProgress.Id := AId;
  FProgress.Stage := AStage;
  FProgress.Attempt := AAttempt;
  FProgress.Limit := ALimit;
  if not Terminated then Synchronize(@DeliverProgress);
end;

procedure TSpxAuthoringLoop.Finish(const R: TSpxLoopResult);
begin
  FResult := R;
  if not Terminated then Synchronize(@DeliverResult);
end;

(* Ask the engine thread and wait. Returns False when the wait was abandoned -- this thread
   terminating, the op cancelled, or the engine gone -- in which case the request may still
   be answered later and the answer is dropped by id. Never a bare wait-forever: the engine
   guarantees an answer only while it is alive. *)
function TSpxAuthoringLoop.AskVerify(const Req: TSpxLoopRequest; const AText: string;
  AProbes: Integer; out VRes: TSpxVerifyResult): Boolean;
var
  vreq: TSpxVerifyRequest;
  vid: Int64;
  got, staleAnswer: Boolean;
begin
  Result := False;
  Inc(FVerifySeq);
  vid := FVerifySeq;

  FLock.Enter;
  try
    FVerifyReady := False;
  finally
    FLock.Leave;
  end;
  FVerifyWake.ResetEvent;

  vreq := Default(TSpxVerifyRequest);
  vreq.Id := vid;
  vreq.Text := AText;
  vreq.Locale := Req.Locale;
  vreq.SetFolder := Req.SetFolder;
  vreq.DocSlug := Req.DocSlug;
  vreq.Vars := Req.Vars;
  vreq.UiLang := Req.UiLang;
  vreq.NoPostProcess := Req.NoPostProcess;
  vreq.Probes := AProbes;
  FEngine.RequestVerify(vreq);

  repeat
    if Terminated or CancelWanted then Exit;
    if FEngine.Finished then Exit;
    FVerifyWake.WaitFor(50);
    FVerifyWake.ResetEvent;
    FLock.Enter;
    try
      got := FVerifyReady and (FVerifyRes.Id = vid);
      staleAnswer := FVerifyReady and (FVerifyRes.Id <> vid);
      if got then VRes := FVerifyRes;
      (* An answer to an older, abandoned request: dropped, and the flag cleared so it
         cannot be mistaken for ours on the next turn. *)
      if staleAnswer then FVerifyReady := False;
    finally
      FLock.Leave;
    end;
  until got;
  Result := True;
end;

procedure TSpxAuthoringLoop.RunOp(const Req: TSpxLoopRequest);
var
  r: TSpxLoopResult;
  built: TSpxBuiltPrompt;
  ans: TSpxLlmAnswer;
  vres: TSpxVerifyResult;
  cleaned: string;
  limit, probes, fixSpent, attempt: Integer;
begin
  limit := Req.FixLimit;
  if limit <= 0 then limit := SPX_LOOP_FIX_LIMIT;
  probes := Req.Probes;
  if probes <= 0 then probes := SPX_LOOP_PROBES;

  r := Default(TSpxLoopResult);
  r.Id := Req.Id;
  r.Op := Req.Op;
  r.Limit := limit;
  r.Revision := Req.Revision;

  (* Preflight, before any prompt is built -- see the unit header. Wording matches SpxLlm's
     for the same conditions, because the window keys its sentences on the enum, not on
     these strings. *)
  if (Req.Cfg.Auth <> laNone) and (Trim(Req.Cfg.ApiKey) = '') then
  begin
    r.Outcome := loProviderError;
    r.LlmError := leNoKey;
    r.Detail := 'this profile authenticates, and no credential is stored for it';
    Finish(r);
    Exit;
  end;
  if SpxHttpTransportAllowed(Req.Cfg.Endpoint) = heInsecure then
  begin
    r.Outcome := loProviderError;
    r.LlmError := leInsecure;
    r.Detail := 'plain http off this machine would put the request on the wire in clear';
    Finish(r);
    Exit;
  end;

  fixSpent := 0;
  if Req.Op = loOpGenerate then
  begin
    attempt := 0;
    built := SpxBuildAuthoringPrompt(Req.Brief, Req.Locale, Req.Allowed, Req.Channel,
                                     Req.Level);
  end
  else
  begin
    if SpxLoopDocErrors(Req.Rows) = 0 then
    begin
      r.Outcome := loNothingToFix;
      Finish(r);
      Exit;
    end;
    (* A fix op's first call is already fix attempt 1: the reader pressed the button about
       errors that exist, and this round is the money it costs. *)
    attempt := 1;
    built := SpxLoopRepairPrompt(Req.DocText, Req.Locale, Req.Rows, Req.Allowed);
  end;

  repeat
    (* Asked BEFORE the call, not only after it: a Stop that landed since the last check
       must not start a network exchange at all -- SpxHttp reads the same flag before it
       dials (its zeroth read), and this is the round's. Found by review. *)
    if Terminated or CancelWanted then
    begin
      r.Outcome := loCancelled;
      r.LlmError := leCancelled;
      r.FixSpent := fixSpent;
      Finish(r);
      Exit;
    end;
    Say(Req.Id, lsAsking, attempt, limit);
    ans := FAsk(Req.Cfg, built, @FCancel);
    (* Spent the moment the answer ARRIVES -- before the cancel check, not after it: a fix
       round whose answer came back was billed whether or not the reader pressed Stop in the
       same instant, and reporting it unspent would promise a free retry that is not free.
       Found by review. A round cancelled mid-transfer stays unspent: no answer arrived. *)
    if (ans.Error = leNone) and (attempt > 0) then fixSpent := attempt;
    if Terminated or CancelWanted or (ans.Error = leCancelled) then
    begin
      r.Outcome := loCancelled;
      r.LlmError := leCancelled;
      r.FixSpent := fixSpent;
      Finish(r);
      Exit;
    end;
    if ans.Error <> leNone then
    begin
      (* The outcome table's last row. The attempt is NOT spent: a 401, a redirect or a dead
         network is not something a regenerated template fixes, and the reader retries this
         round for free once the profile or the network is right. *)
      r.Outcome := loProviderError;
      r.LlmError := ans.Error;
      r.Status := ans.Status;
      r.Detail := ans.Detail;
      r.FixSpent := fixSpent;
      Finish(r);
      Exit;
    end;
    cleaned := SpxCleanModelTemplate(ans.Text);
    if Trim(cleaned) = '' then
    begin
      r.Outcome := loProviderError;
      r.LlmError := leEmpty;
      r.Detail := 'the answer carried no template after cleaning';
      r.FixSpent := fixSpent;
      Finish(r);
      Exit;
    end;

    Say(Req.Id, lsVerifying, attempt, limit);
    if not AskVerify(Req, cleaned, probes, vres) then
    begin
      r.Outcome := loCancelled;
      r.LlmError := leCancelled;
      r.HaveText := True;
      r.Text := cleaned;
      r.FixSpent := fixSpent;
      if FEngine.Finished then r.Detail := 'the engine thread is gone; no verdict is coming';
      Finish(r);
      Exit;
    end;

    (* Stop pressed while the verdict was being computed: the answer exists, and delivering
       it as loClean would hand the window a result the reader has already refused. Found by
       review -- AskVerify checks the flag before each wait, not after the last one. *)
    if Terminated or CancelWanted then
    begin
      r.Outcome := loCancelled;
      r.LlmError := leCancelled;
      r.HaveText := True;
      r.Text := vres.Source;
      r.FixSpent := fixSpent;
      Finish(r);
      Exit;
    end;

    (* The pair (text, rows) of one age: everything below reads vres.Source, never the local
       variable, so the result cannot carry a text the rows are not about. *)
    r.HaveText := True;
    r.Text := vres.Source;
    r.Errors := vres.Errors;
    r.DocErrors := SpxLoopDocErrors(vres.Rows);
    r.Warnings := vres.Warnings;
    r.Probes := vres.Probes;
    r.EmptyProbes := vres.EmptyProbes;
    r.Fullwidth := vres.FullwidthFallback;
    r.Rows := vres.Rows;
    r.FixSpent := fixSpent;

    if r.DocErrors = 0 then
    begin
      if vres.Errors > 0 then
      begin
        (* Nothing left for the model, and the verdict is still not clean: the errors live
           in an included file. Checked before the probe flags because it is the more
           specific fact -- a fragment that unwinds to empty is WHY a probe can come back
           empty, and "fix the fragment" is the actionable sentence. Found by review: this
           reached loClean, which the window is allowed to apply, on a verdict the spec
           calls invalid (IsValid is closure-wide). *)
        r.Outcome := loClosureError;
        Finish(r);
        Exit;
      end;
      if (vres.EmptyProbes > 0) or vres.FullwidthFallback then
      begin
        (* No error anywhere, and the render dies anyway -- the broken-plural signature.
           `IsValid` would say yes, which is exactly why this row of the table exists: "no
           error" is not "ready". Stop, visibly; do not spend a fix round on a warning the
           model was never told about. *)
        r.Outcome := loDegenerate;
        Finish(r);
        Exit;
      end;
      if Stale(Req) then r.Outcome := loStale else r.Outcome := loClean;
      Finish(r);
      Exit;
    end;

    if fixSpent >= limit then
    begin
      r.Outcome := loStillInvalid;
      Finish(r);
      Exit;
    end;

    (* Before every retry: the snapshot check. The reader may have changed the document, the
       locale or the profile while the last round flew; a fix built for the old snapshot
       would spend their money on a template nobody asked about any more. *)
    if Stale(Req) then
    begin
      r.Outcome := loStale;
      Finish(r);
      Exit;
    end;

    Inc(attempt);
    built := SpxLoopRepairPrompt(vres.Source, Req.Locale, vres.Rows, Req.Allowed);
  until False;
end;

procedure TSpxAuthoringLoop.Execute;
var
  req: TSpxLoopRequest;
  aid: Int64;
begin
  while not Terminated do
  begin
    if WorkPending then FWake.WaitFor(0) else FWake.WaitFor(INFINITE);
    FWake.ResetEvent;

    (* Displaced requests first: their one promised result, then the real work. *)
    while (not Terminated) and TakeAbandoned(aid) do
    begin
      FResult := Default(TSpxLoopResult);
      FResult.Id := aid;
      FResult.Outcome := loCancelled;
      FResult.LlmError := leCancelled;
      if not Terminated then Synchronize(@DeliverResult);
    end;

    if (not Terminated) and TakeRequest(req) then
    begin
      try
        RunOp(req);
      finally
        FLock.Enter;
        try
          FBusy := False;
        finally
          FLock.Leave;
        end;
      end;
    end;
  end;
end;

end.
