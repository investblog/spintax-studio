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
  Classes, SysUtils, SyncObjs, Spintax, SpxStudio, SpxCount, SpxFiles, SpxDedupe,
  SpxGsaImport, SpxHelpText;

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
    { The language the PANEL will show these rows in. It comes with the job rather than being
      read from a global on this thread, and it is the INTERFACE's language rather than the
      document's: the two are separate settings now, and a panel with Russian headers over
      English findings is what deriving it from the locale produced. }
    UiLang: TSpxLang;
    (* THE COSMETIC STAGE, per document rather than per build -- and NEGATIVE on purpose.
       Everything this editor normally shows is post-processed; a converted GSA template is
       not, because it is not ours to tidy (spec §4.7).

       Written as `No…` so the SAFE answer is the zero one. A positive `PostProcess` was
       written first and the suite caught it within the minute: these records are filled field
       by field by their callers, three of which do not know this field exists, and a Boolean
       they do not set is False -- so every one of them quietly lost the cosmetic stage. The
       charter already carries this lesson about the engine's own `Default(TSpContext)`; it
       applies to any record a caller builds by hand. *)
    NoPostProcess: Boolean;
    (* HOW MANY LINE TERMINATORS THE RENDER MAY END WITH, or -1 to leave it alone (which is
       every ordinary document).

       A converted GSA template is the exception. The converter appends its `#def` block to
       the END of the document (`Spintax.Gsa.pas:841`), and a consumed directive still leaves
       its line break behind -- so `{#A a|#B b} X {#A c|#B d}`, which GSA renders as `a X c`
       and nothing else, came out with two terminators after it, growing by one per branch.
       The engine's own note says `PostProcess=True` trims them away, and spec §4.7 forbids
       exactly that for this document.

       So the host says what the SOURCE ended with and the render is clamped to it -- never
       padded, only cut, and only down to the reader's own file. The text that goes back to
       GSA has to survive character for character.

       TWO FIELDS, and the Boolean is why. `MaxTrailEols` alone made ZERO mean "end with no
       terminator at all", which is the most destructive value there is -- and zero is exactly
       what a caller who has never heard of the field leaves behind. The help branch of
       RequestRender returns before the field is set and took it: measured harmless today (no
       help example ends with a terminator) and one new example away from silent. This is the
       lesson written twelve lines above for `HelpSet` and twenty above for `NoPostProcess`,
       applied here after a review pointed out it had not been. *)
    ClampTrailEols: Boolean;
    MaxTrailEols: Integer;
    { A selection to preview on its own, in the DOCUMENT's scope -- its `#set`/`#def` lines,
      the runtime context and the locale all still apply (spec §4.2). Empty means the whole
      document, which is the ordinary case. Only the PREVIEW narrows: diagnostics keep
      describing the whole file, because selecting a paragraph does not make the errors
      outside it go away. }
    Fragment: string;
    { THE HELP IS RENDERED UNDER THE HELP'S OWN CONDITIONS. The locale and the seed come with
      the job as usual, but the template set cannot -- it is the fragments the document declares
      rather than a folder on disk -- so the thread builds it from SpxHelpText.

      A BOOLEAN AND NOT A LANGUAGE INDEX, and the difference cost an export. The field used to be
      -1 for an ordinary document and 0..n for a help one; `Default(TSpxJob)` zeroes it, and zero
      was the ENGLISH HELP. BatchStep builds its job that way, so every export rendered against
      the help's own fragments -- and the help declares one called `frag`, so a document with a
      fragment of that name silently exported the help's text instead of its own. Measured.

      Encoded so the default is the safe answer: a field whose zero is dangerous will be
      defaulted wrong again, and the comment warning about it sat six lines from the site that
      did. }
    HelpSet: Boolean;
    HelpLang: Integer;
    { WHICH DOCUMENT of that language: its fragments, its locale and its seed are the ones the
      page was measured under, and a language has more than one. }
    HelpDoc: Integer;
    { WHICH example this job renders. It rides on the job -- and back on the result -- rather
      than being read from the window when the answer lands, because the window has moved on by
      then. Measured by review: with a 1.2 MB document still rendering, opening the help and
      clicking a BROKEN example put the offer up for 16 ms on the document's own verdict.

      ITS ZERO IS DANGEROUS in exactly the way the paragraph above describes -- zero is a real
      example -- so it is never read on its own. HelpSet is the guard: False by default, so a
      job built with Default() can never be mistaken for an answer about example 0. }
    HelpExample: Integer;
  end;

  TSpxJobResult = record
    Id: Int64;
    (* THE TEXT THIS ANSWER IS ABOUT, carried rather than fetched again.

       A superseded result IS delivered and IS shown -- see JobDone, where that is argued for
       the preview -- so `FEditor.Text` at the moment a result arrives is not necessarily the
       text that produced it. The preview can lag one edit behind harmlessly. The AI panel
       cannot: it pairs the document with the findings' line and column numbers, and a repair
       prompt built from now-text and then-rows quotes spans that point at other characters.

       The comment above that call already claimed the panel is fed "from the SAME answer, not
       from a second look at the document" -- and the next line took a second look. Found by
       review. A string crosses the thread boundary by reference count, so this costs a
       reference and not a copy. *)
    Source: string;
    { Both copied from the job, so the window can ask "is this an answer about what I am
      showing?" instead of assuming it is. Read together, never apart: see the job's field. }
    HelpSet: Boolean;
    HelpExample: Integer;
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
    { And every `#include` the document names, with whether the set has it (spec §4.4). These
      never reached the GUI before -- the model computed them and the result dropped them. }
    Includes: TSpxIncludeInfos;
    { WHETHER THERE WAS A SET AT ALL, which the panel cannot work out and must not guess.
      `Known` is False both for a fragment the set does not have and for a document that has no
      set to look in -- a new file has none -- and telling a user "missing" in the second case
      would be a plain lie. Only this thread knows: it owns FSet. }
    HaveSet: Boolean;
    { How many VARIANTS the template can make (SpxCount -- a variant is one filled-in
      template, which is not the same as a text that reads differently). Computed HERE and
      not in the panel
      because counting reads the directive prelude through the engine, and the UI thread does
      not touch the engine -- the same rule the preview and the model already follow. It also
      needs FSet to resolve an `#include`, which only this thread owns. }
    Count: TSpxCount;
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
    { Same rule and the same polarity as the render job's, for the same reason. }
    NoPostProcess: Boolean;
    { And the same ending. THIS is the path whose text goes back to GSA -- the preview is only
      what the reader looks at -- and the clamp was added to the preview alone, which the
      commit message justified with the export. Found by review. }
    ClampTrailEols: Boolean;
    MaxTrailEols: Integer;
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

  { ── verify: a request that CANNOT be displaced ─────────────────────────────

    The authoring loop's Verify step (spec §4.5). It runs HERE and not on the loop's own
    thread because every engine call belongs to this one (spec §5) -- and it cannot ride the
    ordinary Post, whose whole design is latest-wins: one typed character while a verify was
    queued would silently evict it, and the loop would wait forever for an answer nobody is
    going to compute. So verify requests have their own queue, FIFO, never replaced: every
    request gets exactly one result. Preview jobs keep displacing each other exactly as
    before; they are checked first, because a person is waiting on them. }
  TSpxVerifyRequest = record
    Id: Int64;
    Text: string;         { the CANDIDATE -- the model's answer, not the editor's buffer }
    Locale: string;
    SetFolder: string;
    DocSlug: string;
    Vars: TSpxVarPairs;
    UiLang: TSpxLang;
    { Same polarity and same reason as the render job's field: the zero a caller who has
      never heard of it leaves behind must be the safe answer. }
    NoPostProcess: Boolean;
    Probes: Integer;      { N probe renders for the health flags (spec §4.5) }
  end;

  TSpxVerifyResult = record
    Id: Int64;
    { The text this verdict is about, carried for the same reason TSpxJobResult.Source is:
      the loop pairs it with the rows' coordinates, and a pair of different ages quotes
      spans that point at other characters. }
    Source: string;
    Errors, Warnings: Integer;
    Probes, EmptyProbes, DistinctProbes: Integer;
    FullwidthFallback: Boolean;
    Rows: TSpxPanelRows;
  end;

  (* ▁▁▁ AN IMPORT, WHICH IS AN ENGINE CALL LIKE ANY OTHER ▁▁▁

     `SpGsaToSpintax` converts a GSA SER template, and it ran on the UI THREAD until
     2026-08-19 -- the one engine-family call in this application that did not come through
     here. It is quadratic in the count of DISTINCT lifted macros, because the converter's
     lifter looks its keys up linearly, so the window simply stopped. Measured on this machine,
     unoptimised, which is how the shipped project is built:

       1 000 distinct  #file[...]   20 KB     353 ms
       2 000                        41 KB   1 286 ms
       4 000                        83 KB   5 229 ms
       8 000                       167 KB  18 212 ms

     Quadratic confirmed by the doubling, and the cost is the ENGINE's: timed either side of
     `SpGsaToSpintax`, everything Studio adds on top -- the variable list, the sort, the
     tag-block guard -- is inside run-to-run noise. So this moves the wait off the UI thread;
     it does not make it shorter. The lifter is reported upstream.

     A QUEUE, LIKE VERIFY, NEVER REPLACED: an import is a thing the reader asked for by
     picking a file, and a render posted a keystroke later must not evict it. Delivered on the
     MAIN thread like a render, unlike verify, because the consumer is the window: the result
     replaces the document, the session values and the caption.

     It was safe to run anywhere -- the engine's only shared state is `GAbbrevArr`, reached
     solely from the post-process, and `GRngCounter`, reached solely from `MakeDefaultRng`, and
     the converter renders nothing. It comes through here anyway. The rule that every engine
     call is on one thread is worth more than the exception: whoever reads it next should not
     have to re-derive that enumeration to know the code is sound.

     TWO PRICES OF PUTTING IT HERE, both known and both accepted. A conversion already RUNNING
     holds a shutdown for its whole length -- `Shutdown` sets a flag and this loop checks it
     between pieces of work, and there is no way to interrupt the engine mid-convert -- so
     closing the window during an eight-thousand-macro import waits the eighteen seconds. (It
     does not DEADLOCK: on the main thread `TThread.WaitFor` waits on the sync event as well as
     the handle and runs `CheckSynchronize`, so a Synchronize that slipped past the check above
     is still serviced. FPC 3.2.2, `rtl/win/tthread.inc`.) And `Synchronize` blocks THIS thread
     until the handler returns, so a modal dialog raised by the handler -- the import summary is
     one -- holds the worker open the whole time it is on screen: the render the handler asked
     for lands after the reader clicks OK. Both were paid for anyway before this moved, when the
     entire window was frozen instead. *)
  TSpxImportRequest = record
    Id: Int64;
    Source: string;       { the GSA template's text, as the FILE has it }
  end;

  TSpxImportResult = record
    Id: Int64;
    Res: TSpxGsaResult;
  end;

  { Main thread, through Synchronize -- see the note above. }
  TSpxImportDone = procedure(const Res: TSpxImportResult) of object;

  { CALLED ON THE ENGINE THREAD, not through Synchronize. The consumer is the authoring
    loop's own thread, which waits on an event of its own -- routing the answer through the
    main thread would add a hop that only matters when it is busy, and the loop is exactly
    the caller that must not depend on the window pumping messages. The handler copies the
    record under its own lock and returns; it must not call back into this thread. }
  TSpxVerifyDone = procedure(const Res: TSpxVerifyResult) of object;

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
    { The verify queue. An ARRAY, not a slot: requests are appended and taken in order,
      and nothing ever overwrites one -- see TSpxVerifyRequest for why. }
    FVerifyQueue: array of TSpxVerifyRequest;   // under FLock
    FOnVerify: TSpxVerifyDone;
    { The import queue, the same shape and for the same reason: appended, popped, never
      overwritten. One per loop turn. }
    FImportQueue: array of TSpxImportRequest;   // under FLock
    FImportResult: TSpxImportResult;            // worker only, read by DeliverImport
    FOnImport: TSpxImportDone;
    FSet: TSpxTemplateSet;                // owned here, touched only on this thread
    FSetFolder: string;
    { Which help language FSet was built for, or -1 when it is an ordinary document's set. }
    FSetHelpLang: Integer;
    FSetHelpDoc: Integer;
    { Per-file validation results, reused across renders. The walk validates every file in
      the closure on every keystroke while only the open document has changed, and
      SpValidate is quadratic in the count of #set/#def -- so a folder of fragments makes
      each keystroke pay for all of them. Owned here for the same reason the set is: this is
      the thread that knows what changed. }
    FCache: TSpxValidationCache;
    procedure Deliver;                    // main thread, via Synchronize
    procedure DeliverBatch;               // main thread, via Synchronize
    procedure DeliverImport;              // main thread, via Synchronize
    function TakePending(out Job: TSpxJob): Boolean;
    function TakeVerify(out Req: TSpxVerifyRequest): Boolean;
    function VerifyPending: Boolean;
    function TakeImport(out Req: TSpxImportRequest): Boolean;
    function ImportPending: Boolean;
    procedure RunImport(const Req: TSpxImportRequest);
    procedure RunVerify(const Req: TSpxVerifyRequest);
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
    { Appends -- never replaces. Safe from any thread. The result arrives through OnVerify,
      ON THIS WORKER THREAD; every request still queued gets its answer eventually, in
      order, however many renders are posted in between. Requests still queued when the
      thread is shut down are dropped without an answer, which is why a waiter must poll
      its own termination rather than wait forever (the loop does). }
    procedure RequestVerify(const Req: TSpxVerifyRequest);
    { Appends -- never replaces, the same as RequestVerify. Safe from the UI thread. The
      answer arrives through OnImport, on the MAIN thread. A request still queued when the
      thread shuts down is dropped without an answer, so a caller that disables part of its
      window while it waits must re-enable it on shutdown too. }
    procedure RequestImport(const Req: TSpxImportRequest);
    procedure Shutdown;
    property OnBatch: TSpxBatchEvent read FOnBatch write FOnBatch;
    property OnVerify: TSpxVerifyDone read FOnVerify write FOnVerify;
    property OnImport: TSpxImportDone read FOnImport write FOnImport;
  end;

implementation

constructor TSpxEngineThread.Create(AOnDone: TSpxJobDone);
begin
  FLock := TCriticalSection.Create;
  FWake := TSimpleEvent.Create;
  FOnDone := AOnDone;
  FHasPending := False;
  { -1 AND NOT THE DEFAULT ZERO: zero is a valid help language, so a field left at its default
    would tell SyncSet the set is already the English help's and the first document would render
    against three fragments out of the help. }
  FSetHelpLang := -1;
  FSetHelpDoc := -1;
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
        vars.AddOrSetValue(req.Vars[i].Name, SpxValueForEngine(req.Vars[i]));
  end;
  try
    ctx := SpxSeededContext(req.Locale, vars, seed, FSet);
    ctx.PostProcess := not req.NoPostProcess;
    batch := SpxRenderBatch(req.Text, ctx, 1, seed);
    try
      if batch.Count = 0 then v := Default(TSpxVariant) else v := batch[0];
      if req.ClampTrailEols then v.Text := SpxClampTrailEols(v.Text, req.MaxTrailEols);
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

procedure TSpxEngineThread.RequestVerify(const Req: TSpxVerifyRequest);
begin
  FLock.Enter;
  try
    SetLength(FVerifyQueue, Length(FVerifyQueue) + 1);
    FVerifyQueue[High(FVerifyQueue)] := Req;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TSpxEngineThread.TakeVerify(out Req: TSpxVerifyRequest): Boolean;
var i: Integer;
begin
  FLock.Enter;
  try
    Result := Length(FVerifyQueue) > 0;
    if Result then
    begin
      Req := FVerifyQueue[0];
      for i := 1 to High(FVerifyQueue) do FVerifyQueue[i - 1] := FVerifyQueue[i];
      SetLength(FVerifyQueue, Length(FVerifyQueue) - 1);
    end;
  finally
    FLock.Leave;
  end;
end;

function TSpxEngineThread.VerifyPending: Boolean;
begin
  FLock.Enter;
  try
    Result := Length(FVerifyQueue) > 0;
  finally
    FLock.Leave;
  end;
end;

procedure TSpxEngineThread.RequestImport(const Req: TSpxImportRequest);
begin
  FLock.Enter;
  try
    SetLength(FImportQueue, Length(FImportQueue) + 1);
    FImportQueue[High(FImportQueue)] := Req;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TSpxEngineThread.TakeImport(out Req: TSpxImportRequest): Boolean;
var i: Integer;
begin
  FLock.Enter;
  try
    Result := Length(FImportQueue) > 0;
    if Result then
    begin
      Req := FImportQueue[0];
      for i := 1 to High(FImportQueue) do FImportQueue[i - 1] := FImportQueue[i];
      SetLength(FImportQueue, Length(FImportQueue) - 1);
    end;
  finally
    FLock.Leave;
  end;
end;

function TSpxEngineThread.ImportPending: Boolean;
begin
  FLock.Enter;
  try
    Result := Length(FImportQueue) > 0;
  finally
    FLock.Leave;
  end;
end;

{ The conversion itself, on this thread. Nothing here touches the set, the cache or any state
  a render owns -- it is a pure function of the source text -- so it needs no SyncSet and
  cannot disturb a batch in flight. }
procedure TSpxEngineThread.RunImport(const Req: TSpxImportRequest);
begin
  FImportResult.Id := Req.Id;
  FImportResult.Res := SpxImportGsa(Req.Source);
end;

procedure TSpxEngineThread.DeliverImport;
begin
  if Assigned(FOnImport) then FOnImport(FImportResult);
end;

{ The Verify of spec §4.5: the closure validated file by file, plus N probe renders for the
  health flags. It reuses everything the interactive path owns -- the set, the cache -- and
  differs from Run in what it does NOT compute: no preview, no marks, no variables panel, no
  count. The candidate is not on screen; only the verdict travels. }
procedure TSpxEngineThread.RunVerify(const Req: TSpxVerifyRequest);
var
  ctx: TSpxContext;
  report: TSpxReport;
  vars: TStrMap;
  res: TSpxVerifyResult;
  job: TSpxJob;
  i: Integer;
begin
  job := Default(TSpxJob);
  job.SetFolder := Req.SetFolder;
  job.DocSlug := Req.DocSlug;
  SyncSet(job);

  vars := nil;
  if Length(Req.Vars) > 0 then
  begin
    vars := TStrMap.Create;
    for i := 0 to High(Req.Vars) do
      if Req.Vars[i].Name <> '' then
        vars.AddOrSetValue(Req.Vars[i].Name, SpxValueForEngine(Req.Vars[i]));
  end;
  try
    { Unseeded on purpose: the health probes seed THEMSELVES, one fixed seed per probe
      (SpxHealthReport), so the same candidate always reports the same numbers. }
    ctx := SpxContext(Req.Locale, vars, FSet);
    ctx.PostProcess := not Req.NoPostProcess;

    res := Default(TSpxVerifyResult);
    res.Id := Req.Id;
    res.Source := Req.Text;
    report := SpxHealthReport(Req.Text, ctx, Req.Probes, Req.DocSlug, FCache);
    try
      res.Errors := report.Errors;
      res.Warnings := report.Warnings;
      res.Probes := report.Probes;
      res.EmptyProbes := report.EmptyProbes;
      res.DistinctProbes := report.DistinctProbes;
      res.FullwidthFallback := report.FullwidthFallback;
      res.Rows := SpxPanelRows(report, Req.UiLang);
    finally
      report.Free;
    end;
  finally
    vars.Free;
  end;

  { Delivered on THIS thread -- see TSpxVerifyDone for why not Synchronize. }
  if Assigned(FOnVerify) then FOnVerify(res);
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
var i: Integer;
begin
  { The help's set is the fragments the DOCUMENT declares, not a folder -- built here and
    cached by (language, document), so a caret moving through the help does not rebuild it per
    keystroke, and turning from one document to another does. }
  if Job.HelpSet then
  begin
    if (FSetHelpLang = Job.HelpLang) and (FSetHelpDoc = Job.HelpDoc) then Exit;
    FreeAndNil(FSet);
    FSetFolder := '';
    FSetHelpLang := Job.HelpLang;
    FSetHelpDoc := Job.HelpDoc;
    FSet := TSpxTemplateSet.Create;
    for i := 0 to SpxHelpIncludeCount(Job.HelpLang, Job.HelpDoc) - 1 do
      FSet.AddOrSetValue(SpxHelpIncludeName(Job.HelpLang, Job.HelpDoc, i),
                         SpxHelpIncludeText(Job.HelpLang, Job.HelpDoc, i));
    Exit;
  end;
  if (not Job.ReloadSet) and (FSetHelpLang < 0) and (Job.SetFolder = FSetFolder) and
     ((FSet <> nil) = (Job.SetFolder <> '')) then Exit;
  FreeAndNil(FSet);
  FSetHelpLang := -1;
  FSetHelpDoc := -1;
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
        vars.AddOrSetValue(Job.Vars[i].Name, SpxValueForEngine(Job.Vars[i]));
  end;
  try
    if Job.Seeded then ctx := SpxSeededContext(Job.Locale, vars, Job.Seed, FSet)
    else ctx := SpxContext(Job.Locale, vars, FSet);
    ctx.PostProcess := not Job.NoPostProcess;

    FResult := Default(TSpxJobResult);
    FResult.Id := Job.Id;
    FResult.Source := Job.Text;
    FResult.HelpSet := Job.HelpSet;
    FResult.HelpExample := Job.HelpExample;
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
    if Job.ClampTrailEols then
      FResult.Preview := SpxClampTrailEols(FResult.Preview, Job.MaxTrailEols);

    { Probes = 0: the interactive path already has its one render, and the health flags are
      the panel's business (M2), not the status bar's. }
    report := SpxHealthReport(Job.Text, ctx, 0, Job.DocSlug, FCache);
    try
      FResult.Errors := report.Errors;
      FResult.Warnings := report.Warnings;
      FResult.Notes := report.Notes.Count;
      FResult.Marks := SpxDocumentMarks(report);
      { The document's own locale decides the wording, not whatever the window happens to be
        showing: the rows are built here, off the UI thread, and a global read across that
        boundary is exactly the race this worker exists to avoid. }
      FResult.Rows := SpxPanelRows(report, Job.UiLang);
    finally
      report.Free;
    end;

    { The panel's model, flattened out of the object editor-core returns. }
    model := SpxExtractModel(Job.Text, ctx);
    try
      SetLength(FResult.Vars, model.Vars.Count);
      for i := 0 to model.Vars.Count - 1 do FResult.Vars[i] := model.Vars[i];
      SetLength(FResult.Includes, model.Includes.Count);
      for i := 0 to model.Includes.Count - 1 do FResult.Includes[i] := model.Includes[i];
      FResult.HaveSet := FSet <> nil;
    finally
      model.Free;
    end;

    { The count is about the DOCUMENT, so a fragment render does not change it: narrowing the
      preview to a selection must not make the panel say the template got smaller. }
    FResult.Count := SpxCountVariants(Job.Text, ctx);
  finally
    vars.Free;
  end;
  FResult.Elapsed := Round((Now - started) * 24 * 60 * 60 * 1000);
end;

procedure TSpxEngineThread.Execute;
var job: TSpxJob; vreq: TSpxVerifyRequest; ireq: TSpxImportRequest;
begin
  { Warm the engine's lazy global here, on the only thread that will ever touch it, before
    the first real request can arrive. }
  SpxRenderSample('warm', SpxSeededContext('en', nil, 1));

  while not Terminated do
  begin
    { Blocking only when there is nothing to do. With a batch running -- or a verify still
      queued, since only one is taken per turn and the event was already reset -- the wait is
      a poll, so the loop comes straight back to the next piece of work; and it still notices
      a posted render first, because that is the one a person is waiting on. }
    if BatchRunning or VerifyPending or ImportPending then FWake.WaitFor(0)
    else FWake.WaitFor(INFINITE);
    FWake.ResetEvent;

    while (not Terminated) and TakePending(job) do
    begin
      Run(job);
      if not Terminated then Synchronize(@Deliver);
    end;

    { AFTER the renders -- a person is waiting on those -- and one per loop turn, so a posted
      render gets its look between two verifies. Never displaced: TakeVerify only ever pops. }
    if (not Terminated) and TakeVerify(vreq) then
      RunVerify(vreq);

    { An import, one per turn, on the same terms: never displaced, and delivered on the MAIN
      thread because the window is what consumes it. It sits after the renders for the same
      reason verify does -- a person watching the preview is waiting on those -- and before
      the batch, because a reader who asked for a file is waiting on this. }
    if (not Terminated) and TakeImport(ireq) then
    begin
      RunImport(ireq);
      if not Terminated then Synchronize(@DeliverImport);
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
