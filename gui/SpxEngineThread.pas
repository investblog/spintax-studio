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
  Classes, SysUtils, SyncObjs, Spintax, SpxStudio, SpxFiles;

type
  { What the form asks for. A plain record: it crosses the thread boundary by value, so
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
  end;

  TSpxJobResult = record
    Id: Int64;
    Preview: string;
    Errors: Integer;
    Warnings: Integer;
    Notes: Integer;
    Elapsed: Integer;      // milliseconds, for the status bar
    { The open document's diagnostics as spans, ready to underline. A dynamic array crosses
      the thread boundary by reference count, like the strings beside it. }
    Marks: TSpxDiagMarks;
    { Every finding there is, including the ones no squiggle can show: an error inside an
      included file, and a finding the engine could not place. }
    Rows: TSpxPanelRows;
  end;

  TSpxJobDone = procedure(const Res: TSpxJobResult) of object;

  TSpxEngineThread = class(TThread)
  private
    FLock: TCriticalSection;
    FWake: TSimpleEvent;
    FPending: TSpxJob;
    FHasPending: Boolean;
    FResult: TSpxJobResult;
    FOnDone: TSpxJobDone;
    FSet: TSpxTemplateSet;                // owned here, touched only on this thread
    FSetFolder: string;
    { Per-file validation results, reused across renders. The walk validates every file in
      the closure on every keystroke while only the open document has changed, and
      SpValidate is quadratic in the count of #set/#def -- so a folder of fragments makes
      each keystroke pay for all of them. Owned here for the same reason the set is: this is
      the thread that knows what changed. }
    FCache: TSpxValidationCache;
    procedure Deliver;                    // main thread, via Synchronize
    function TakePending(out Job: TSpxJob): Boolean;
    procedure SyncSet(const Job: TSpxJob);
    procedure Run(const Job: TSpxJob);
  protected
    procedure Execute; override;
  public
    constructor Create(AOnDone: TSpxJobDone);
    destructor Destroy; override;
    { Replaces anything not yet started. Safe from the UI thread. }
    procedure Post(const Job: TSpxJob);
    procedure Shutdown;
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
  FWake.Free;
  FLock.Free;
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
  started: TDateTime;
begin
  started := Now;
  SyncSet(Job);
  if Job.Seeded then ctx := SpxSeededContext(Job.Locale, nil, Job.Seed, FSet)
  else ctx := SpxContext(Job.Locale, nil, FSet);

  FResult := Default(TSpxJobResult);
  FResult.Id := Job.Id;
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
    FWake.WaitFor(INFINITE);
    FWake.ResetEvent;
    while (not Terminated) and TakePending(job) do
    begin
      Run(job);
      if not Terminated then Synchronize(@Deliver);
    end;
  end;
end;

end.
