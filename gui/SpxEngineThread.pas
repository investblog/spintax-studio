{**
 * SpxEngineThread -- the one thread that is allowed to call the engine (spec §5).
 *
 * Two reasons it exists, both measured rather than assumed:
 *   - the engine builds a lazy global on its FIRST post-process, with no synchronisation,
 *     so two first renders on two threads race. One thread, warmed before anything else
 *     asks for work, removes the question;
 *   - a render is milliseconds on a normal document and hundreds of them on a large one
 *     (post-process is 0.7 s on 237 KB), which is far too long to spend on the UI thread
 *     between two keystrokes.
 *
 * LATEST WINS. A request that arrives while another is running replaces whatever was
 * queued -- the user has typed again, and the older answer is already wrong. Results carry
 * the id they were asked for, so the form drops anything stale that beat its successor
 * home.
 *}
unit SpxEngineThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Spintax, SpxStudio, SpxFiles, SpxDedupe;

type
  { TSpxVarPairs (what the panel sends) and TSpxVarInfos (what it receives) are declared in
    editor-core beside the record they carry, so the panel does not have to know this unit
    exists to speak about them.

    What the form asks for. A plain record: it crosses the thread boundary by value, so
    there is nothing to own and nothing to free on either side.

    Note what is NOT here: the template set. Only the FOLDER crosses, as a string, and the
    worker owns the map it builds from it. That keeps a mutable object out of the boundary
    entirely -- with latest-wins replacing queued jobs, a set travelling by reference would
    need an owner at both ends -- and it puts the directory scan off the UI thread. }
  TSpxJob = record
    Id: Int64;
    Text: string;
    Locale: string;
    Seeded: Boolean;
    Seed: LongWord;
    { The folder the document lives in, '' while it has never been saved. Empty means no
      resolver, which is the engine's own behaviour: every `#include` stays verbatim. }
    SetFolder: string;
    { The document's own slug, so the closure walk does not validate the open buffer a
      second time through its saved copy (SpxHealthReport). }
    DocSlug: string;
    { Re-read the folder even when it has not changed -- after a save, or on request. }
    ReloadSet: Boolean;
    { Values the user typed into the panel for variables the document references and nothing
      defines. They are the session's, never the document's: they feed the render context and
      knownVariables, so a `%name%` with a value stops being reported as undefined. }
    Vars: TSpxVarPairs;
    { A selection to preview on its own, in the DOCUMENT's scope -- its `#set`/`#def` lines,
      the runtime context and the locale all still apply (spec §4.2). Empty means the whole
      document, which is the ordinary case. Only the PREVIEW narrows: diagnostics keep
      describing the whole file, because selecting a paragraph does not make the errors
      outside it go away. }
    Fragment: string;
  end;

  TSpxJobResult = record
    Id: Int64;
    Preview: string;
    Errors: Integer;
    Warnings: Integer;
    Notes: Integer;
    Elapsed: Integer;      // milliseconds, for the status bar
    { True when Preview is a fragment rather than the document, so the pane can say so. }
    Partial: Boolean;
    { The open document's diagnostics as spans, ready to underline. A dynamic array crosses
      the thread boundary by reference count, like the strings beside it. }
    Marks: TSpxDiagMarks;
    { Every finding there is, including the ones no squiggle can show: an error inside an
      included file, and a finding the engine could not place. }
    Rows: TSpxPanelRows;
    { The variables panel: every macro the document defines, with the occurrence it lives at,
      and every name it references that nothing defines. }
    Vars: TSpxVarInfos;
  end;

  TSpxJobDone = procedure(const Res: TSpxJobResult) of object;

  { ── a batch, which is a long job rather than a call ────────────────────────

    Generating a set is not a bigger render, it is a different shape of work: with the
    default retry budget it is up to N + 2N renders -- measured at 61 seconds for N = 200 on
    a 30 KB template -- and doing that inside one request would freeze the preview for the
    whole of it, show nothing while it ran, and offer no way to stop.

    So the batch runs on THIS thread (the engine still has exactly one caller, which is the
    reason this thread exists) but ONE VARIANT AT A TIME, with the interactive queue checked
    between every render. Typing during an export still repaints; the batch simply takes the
    gaps. }
  TSpxBatchRequest = record
    Id: Int64;
    Text: string;
    Locale: string;
    SetFolder: string;
    DocSlug: string;
    Vars: TSpxVarPairs;
    Count: Integer;
    SeedBase: LongWord;
    Opts: TSpxDedupeOpts;
  end;

  { One step's worth of news. Accepted says whether the variant just rendered went into the
    set or was dropped as a near-duplicate; Done marks the last message of a batch, and then
    Report carries the totals the author needs to read (requested / generated / dropped /
    tried / exhausted). }
  TSpxBatchProgress = record
    Id: Int64;
    Variant: TSpxVariant;
    Accepted: Boolean;
    Done: Boolean;
    Cancelled: Boolean;
    Report: TSpxBatchReport;
  end;

  TSpxBatchEvent = procedure(const Progress: TSpxBatchProgress) of object;

  TSpxEngineThread = class(TThread)
  private
    FLock: TCriticalSection;
    FWake: TSimpleEvent;
    FPending: TSpxJob;
    FHasPending: Boolean;
    FResult: TSpxJobResult;
    FOnDone: TSpxJobDone;
    { The batch, owned the same way a render job is: the UI thread leaves a REQUEST, the
      worker installs it and from then on nothing else touches the batch's state.

      The first version let StartBatch reach in and replace the running batch's fields
      directly, and a review took it apart: BatchStep reads its seed, renders outside the
      lock, then writes the result back -- so a replacement arriving in that gap charged the
      old batch's variant, with the old batch's seed and text, to the NEW batch's set.
      Measured, and it reached the grid and the export. Ownership fixes it by construction. }
    FPendingBatch: TSpxBatchRequest;   // under FLock
    FHasPendingBatch: Boolean;         // under FLock
    FBatchCancel: Boolean;             // under FLock
    { Requests displaced before the worker ever saw them. EVERY request gets exactly one
      Done, including one replaced while it was still only a request -- otherwise a panel
      that starts a batch and waits for its ending waits for a message nobody will send. }
    FAbandoned: array of Int64;        // under FLock
    FBatch: TSpxBatchRequest;          // worker only, below here
    FBatchActive: Boolean;
    FBatchSeed: LongWord;
    FBatchTried: Integer;
    FBatchLimit: Integer;
    FBatchKept: TSpxUniqueSet;
    FBatchReport: TSpxBatchReport;
    FBatchProgress: TSpxBatchProgress;
    FOnBatch: TSpxBatchEvent;
    FSet: TSpxTemplateSet;                // owned here, touched only on this thread
    FSetFolder: string;
    { Per-file validation results, reused across renders. The walk validates every file in
      the closure on every keystroke while only the open document has changed, and
      SpValidate is quadratic in the count of #set/#def -- so a folder of fragments makes
      each keystroke pay for all of them. Owned here for the same reason the set is: this is
      the thread that knows what changed. }
    FCache: TSpxValidationCache;
    procedure Deliver;                    // main thread, via Synchronize
    procedure DeliverBatch;               // main thread, via Synchronize
    function TakePending(out Job: TSpxJob): Boolean;
    function BatchRunning: Boolean;
    function BatchStep: Boolean;
    function InstallPendingBatch: Boolean;
    procedure EndBatch(ACancelled: Boolean);
    procedure SyncSet(const Job: TSpxJob);
    procedure Run(const Job: TSpxJob);
  protected
    procedure Execute; override;
  public
    constructor Create(AOnDone: TSpxJobDone);
    destructor Destroy; override;
    { Replaces anything not yet started. Safe from the UI thread. }
    procedure Post(const Job: TSpxJob);
    { Starts a batch, replacing one already running. Safe from the UI thread; progress
      arrives on the main thread through OnBatch. }
    procedure StartBatch(const Request: TSpxBatchRequest);
    { Asks the running batch to stop. It ends after the render in flight, so the answer comes
      back as a normal Done message with Cancelled set -- never by abandoning the thread. }
    procedure CancelBatch;
    function BatchInProgress: Boolean;
    procedure Shutdown;
    property OnBatch: TSpxBatchEvent read FOnBatch write FOnBatch;
  end;

implementation

constructor TSpxEngineThread.Create(AOnDone: TSpxJobDone);
begin
  FLock := TCriticalSection.Create;
  FWake := TSimpleEvent.Create;
  FOnDone := AOnDone;
  FHasPending := False;
  FCache := TSpxValidationCache.Create;   // before the thread starts, so it cannot race
  inherited Create(False);   // start at once: the first thing it does is warm the engine
end;

destructor TSpxEngineThread.Destroy;
begin
  inherited Destroy;         // waits for Execute to leave
  FSet.Free;                 // safe here: the only thread that touched it has ended
  FCache.Free;
  FBatchKept.Free;           // same: the batch cannot be mid-step once Execute has returned
  FWake.Free;
  FLock.Free;
end;

procedure TSpxEngineThread.StartBatch(const Request: TSpxBatchRequest);
begin
  FLock.Enter;
  try
    { Left as a REQUEST, not applied. The worker installs it between two renders, which is
      the only moment at which no batch state is in use. }
    if FHasPendingBatch then
    begin
      SetLength(FAbandoned, Length(FAbandoned) + 1);
      FAbandoned[High(FAbandoned)] := FPendingBatch.Id;
    end;
    FPendingBatch := Request;
    FHasPendingBatch := True;
    FBatchCancel := False;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TSpxEngineThread.CancelBatch;
begin
  FLock.Enter;
  try
    FBatchCancel := True;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TSpxEngineThread.BatchRunning: Boolean;
begin
  FLock.Enter;
  try
    Result := FBatchActive or FHasPendingBatch;
  finally
    FLock.Leave;
  end;
end;

function TSpxEngineThread.BatchInProgress: Boolean;
begin
  Result := BatchRunning;
end;

procedure TSpxEngineThread.EndBatch(ACancelled: Boolean);
begin
  FBatchActive := False;
  FBatchReport.Generated := FBatchKept.Count;
  FBatchReport.Tried := FBatchTried;
  FBatchReport.NextSeed := FBatchSeed;
  { A cancelled batch is not an exhausted one: the template was never given the chance. }
  FBatchReport.Exhausted := (not ACancelled) and
                            (FBatchReport.Generated < FBatchReport.Requested);
  FBatchProgress := Default(TSpxBatchProgress);
  FBatchProgress.Id := FBatch.Id;
  FBatchProgress.Done := True;
  FBatchProgress.Cancelled := ACancelled;
  FBatchProgress.Report := FBatchReport;
end;

{ Take a waiting request, if there is one. A batch already running is ENDED first, with its
  own Done, so the panel that started it is never left with a spinner nobody will stop --
  and a request for nothing at all is exactly that: an end, not a new batch.

  Returns True when a message was written for delivery. }
function TSpxEngineThread.InstallPendingBatch: Boolean;
var req: TSpxBatchRequest; had: Boolean; abandoned: Int64; i: Integer;
begin
  Result := False;

  { One ending per displaced request, one loop turn each -- the caller delivers a single
    message per call. }
  abandoned := -1;
  FLock.Enter;
  try
    if Length(FAbandoned) > 0 then
    begin
      abandoned := FAbandoned[0];
      for i := 1 to High(FAbandoned) do FAbandoned[i - 1] := FAbandoned[i];
      SetLength(FAbandoned, Length(FAbandoned) - 1);
    end;
  finally
    FLock.Leave;
  end;
  if abandoned >= 0 then
  begin
    FBatchProgress := Default(TSpxBatchProgress);
    FBatchProgress.Id := abandoned;
    FBatchProgress.Done := True;
    FBatchProgress.Cancelled := True;
    Exit(True);
  end;

  FLock.Enter;
  try
    if not FHasPendingBatch then Exit;
    req := FPendingBatch;
    FHasPendingBatch := False;
    FBatchCancel := False;
  finally
    FLock.Leave;
  end;

  had := FBatchActive;
  if had then
  begin
    { The replaced batch ends as a cancellation, which is what it is from where the author
      stands: they asked for something else. }
    EndBatch(True);
    Result := True;
  end;

  FreeAndNil(FBatchKept);
  if req.Count <= 0 then
  begin
    FBatchActive := False;
    Exit;
  end;

  FBatch := req;
  FBatchActive := True;
  FBatchSeed := req.SeedBase;
  FBatchTried := 0;
  FBatchKept := TSpxUniqueSet.Create(req.Opts);
  { The seeds this batch may spend: N for the set, plus the budget for replacing whatever is
    dropped. Resolved once so the loop below is a plain comparison. }
  FBatchLimit := req.Count + SpxResolveDedupeOpts(req.Opts, req.Count).RetryBudget;
  FBatchReport := Default(TSpxBatchReport);
  FBatchReport.Requested := req.Count;
  FBatchReport.SeedBase := req.SeedBase;
  FBatchReport.NextSeed := req.SeedBase;
end;

{ ONE variant. Everything expensive happens here and nowhere else, which is what lets the
  loop above check for a posted render between every one of them.

  Returns True when there is a message to deliver -- an ended batch writes one, a step
  writes one, and a call that finds nothing to do writes none. Without that answer the loop
  would re-deliver the previous record, i.e. a duplicate row or a duplicate Done. }
function TSpxEngineThread.BatchStep: Boolean;
var
  req: TSpxBatchRequest;
  ctx: TSpxContext;
  vars: TStrMap;
  batch: TSpxVariantList;
  v: TSpxVariant;
  seed: LongWord;
  i: Integer;
  cancelled, atLimit: Boolean;
  job: TSpxJob;
begin
  Result := False;
  if not FBatchActive then Exit;

  FLock.Enter;
  try
    cancelled := FBatchCancel;
  finally
    FLock.Leave;
  end;

  { A FULL set is not a cancelled one, even when Stop was pressed during its last render:
    the author gets the set they asked for and the report says so. Checked before the flag
    for exactly that reason. }
  atLimit := (FBatchKept.Count >= FBatch.Count) or (FBatchTried >= FBatchLimit);
  if atLimit or cancelled then
  begin
    EndBatch(cancelled and not atLimit);
    Exit(True);
  end;

  req := FBatch;
  seed := FBatchSeed;

  { The set has to be in step with the document the batch was started for -- the same folder
    scan the interactive path does, reusing what this thread already owns. }
  job := Default(TSpxJob);
  job.SetFolder := req.SetFolder;
  job.DocSlug := req.DocSlug;
  SyncSet(job);

  vars := nil;
  if Length(req.Vars) > 0 then
  begin
    vars := TStrMap.Create;
    for i := 0 to High(req.Vars) do
      if req.Vars[i].Name <> '' then
        vars.AddOrSetValue(req.Vars[i].Name, req.Vars[i].Value);
  end;
  try
    ctx := SpxSeededContext(req.Locale, vars, seed, FSet);
    batch := SpxRenderBatch(req.Text, ctx, 1, seed);
    try
      if batch.Count = 0 then v := Default(TSpxVariant) else v := batch[0];
    finally
      batch.Free;
    end;
  finally
    vars.Free;
  end;

  { No lock around any of this: the batch state is this thread's alone. The first version
    fingerprinted inside FLock, and a review measured the cost -- 6 ms of UI stall per
    keystroke during an export on a 36 KB template, growing with the set. }
  Inc(FBatchTried);
  FBatchSeed := SpxNextSeed(seed);         { wraps with the range, guarded there }
  FBatchProgress := Default(TSpxBatchProgress);
  FBatchProgress.Id := req.Id;
  FBatchProgress.Variant := v;
  FBatchProgress.Accepted := FBatchKept.Accept(v.Text);
  if not FBatchProgress.Accepted then Inc(FBatchReport.Dropped);
  FBatchReport.Generated := FBatchKept.Count;
  FBatchReport.Tried := FBatchTried;
  FBatchReport.NextSeed := FBatchSeed;
  FBatchProgress.Report := FBatchReport;
  { The last variant and the "done" news arrive as two messages rather than one, so the list
    and the summary are never written from the same event -- one place decides what a row
    is, another what the totals say. }
  Result := True;
end;

procedure TSpxEngineThread.DeliverBatch;
begin
  if Assigned(FOnBatch) then FOnBatch(FBatchProgress);
end;

procedure TSpxEngineThread.Post(const Job: TSpxJob);
begin
  FLock.Enter;
  try
    FPending := Job;         // latest wins: whatever was queued is stale by definition
    FHasPending := True;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

{ Terminate, then wake it so it can notice. The caller then WaitFor's, and the obvious worry
  is a deadlock: the worker may be inside Synchronize, which blocks until the main thread
  services the queue -- and the main thread is the one waiting. It does not deadlock, and not
  by luck: FPC's Windows TThread.WaitFor, when called from the main thread, waits on the
  thread handle AND on SynchronizeTimeoutEvent, calling CheckSynchronize whenever the latter
  fires (rtl/win/tthread.inc). The pending Deliver runs, the worker proceeds, the wait ends.
  Verified by reading that source, and gated by `thread/shutdown-during-a-render-does-not-hang`
  below, which would hang rather than fail if this were wrong. }
procedure TSpxEngineThread.Shutdown;
begin
  Terminate;
  FWake.SetEvent;
end;

function TSpxEngineThread.TakePending(out Job: TSpxJob): Boolean;
begin
  FLock.Enter;
  try
    Result := FHasPending;
    if Result then
    begin
      Job := FPending;
      FHasPending := False;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSpxEngineThread.Deliver;
begin
  if Assigned(FOnDone) then FOnDone(FResult);
end;

{ The set is re-read when the document moved to another folder, and when the caller says so
  -- after a save, or from the menu. It is NOT re-read per keystroke: a directory scan plus
  every fragment's bytes on every debounce tick would be paid for nothing, since the files
  only change when something outside this window changes them. The cost of that choice is
  named where the user can see it: a fragment edited in another program shows up after
  "Перечитать набор". }
procedure TSpxEngineThread.SyncSet(const Job: TSpxJob);
begin
  if (not Job.ReloadSet) and (Job.SetFolder = FSetFolder) and
     ((FSet <> nil) = (Job.SetFolder <> '')) then Exit;
  FreeAndNil(FSet);
  FSetFolder := Job.SetFolder;
  if FSetFolder <> '' then FSet := SpxLoadTemplateSet(FSetFolder);
end;

procedure TSpxEngineThread.Run(const Job: TSpxJob);
var
  ctx: TSpxContext;
  report: TSpxReport;
  model: TSpxModel;
  vars: TStrMap;
  started: TDateTime;
  i: Integer;
begin
  started := Now;
  SyncSet(Job);

  { The session's values, rebuilt per job and owned right here: editor-core never frees a
    map it was handed, and the job that carried these may already have been superseded. }
  vars := nil;
  if Length(Job.Vars) > 0 then
  begin
    vars := TStrMap.Create;
    for i := 0 to High(Job.Vars) do
      if Job.Vars[i].Name <> '' then
        vars.AddOrSetValue(Job.Vars[i].Name, Job.Vars[i].Value);
  end;
  try
    if Job.Seeded then ctx := SpxSeededContext(Job.Locale, vars, Job.Seed, FSet)
    else ctx := SpxContext(Job.Locale, vars, FSet);

    FResult := Default(TSpxJobResult);
    FResult.Id := Job.Id;
    { A selection renders in the document's scope, not on its own: editor-core prepends the
      document's directives in source order, so a fragment that references a macro shows what
      the macro produces rather than the literal `%name%`. }
    { Whitespace is not a fragment worth narrowing to: it renders to nothing, and an empty
      right pane under a caption saying "fragment" is indistinguishable from a crash. The
      test is here rather than in the form so the suite can reach it. }
    FResult.Partial := Trim(Job.Fragment) <> '';
    if FResult.Partial then
      FResult.Preview := SpxRenderFragment(Job.Text, Job.Fragment, ctx)
    else
      FResult.Preview := SpxRenderSample(Job.Text, ctx);

    { Probes = 0: the interactive path already has its one render, and the health flags are
      the panel's business (M2), not the status bar's. }
    report := SpxHealthReport(Job.Text, ctx, 0, Job.DocSlug, FCache);
    try
      FResult.Errors := report.Errors;
      FResult.Warnings := report.Warnings;
      FResult.Notes := report.Notes.Count;
      FResult.Marks := SpxDocumentMarks(report);
      FResult.Rows := SpxPanelRows(report);
    finally
      report.Free;
    end;

    { The panel's model, flattened out of the object editor-core returns. }
    model := SpxExtractModel(Job.Text, ctx);
    try
      SetLength(FResult.Vars, model.Vars.Count);
      for i := 0 to model.Vars.Count - 1 do FResult.Vars[i] := model.Vars[i];
    finally
      model.Free;
    end;
  finally
    vars.Free;
  end;
  FResult.Elapsed := Round((Now - started) * 24 * 60 * 60 * 1000);
end;

procedure TSpxEngineThread.Execute;
var job: TSpxJob;
begin
  { Warm the engine's lazy global here, on the only thread that will ever touch it, before
    the first real request can arrive. }
  SpxRenderSample('warm', SpxSeededContext('en', nil, 1));

  while not Terminated do
  begin
    { Blocking only when there is nothing to do. With a batch running the wait is a poll, so
      the loop comes straight back to the next variant -- and still notices a posted render
      first, because that is the one a person is waiting on. }
    if BatchRunning then FWake.WaitFor(0) else FWake.WaitFor(INFINITE);
    FWake.ResetEvent;

    while (not Terminated) and TakePending(job) do
    begin
      Run(job);
      if not Terminated then Synchronize(@Deliver);
    end;

    { Installed HERE, between renders: the one moment at which no batch state is in use.
      Replacing a running batch ends it first, and that ending is a message of its own. }
    if (not Terminated) and InstallPendingBatch then Synchronize(@DeliverBatch);

    { Only a step that produced news is delivered. Delivering unconditionally re-sent the
      previous record whenever a step found nothing to do -- a duplicate row, or a second
      Done for a batch that had already finished. }
    if (not Terminated) and FBatchActive then
      if BatchStep and (not Terminated) then Synchronize(@DeliverBatch);
  end;
end;

end.
