{**
 * SpxStudio -- editor-core (spec §5, layer 2): a GUI- and network-free orchestration
 * seam over `unit Spintax`, the layer both the GUI and the LLM loop hang off.
 *
 * What lives here is the Studio-side CONTEXT -- locale, runtime variable values, the
 * template set, the RNG mode -- and the handful of calls that turn it into engine calls.
 * What does NOT live here is a second implementation of anything the engine already does:
 * no rescanning, no re-deriving of verdicts, and no include expansion. `#include` is
 * resolved BY THE ENGINE through a resolver this layer hands it (ADR 0003, engine ADR
 * 0004); all Studio owns is the lookup.
 *
 * Three engine facts are enforced in one place rather than remembered at every call site,
 * because each has already cost this family a debugging session (spec §7):
 *   - the host must set the UTF-8 codepage before the first engine call;
 *   - `Default(TSpContext)` leaves PostProcess FALSE, where every shipping engine defaults
 *     it true -- so every render from here sets it explicitly;
 *   - the RNG is a seam: a seeded generator for a stable preview and for reproducible
 *     export, no generator at all when the caller wants a fresh draw.
 *
 * NOT THREAD-SAFE against concurrent calls, by design. The engine builds a lazy global on
 * its first post-process, so two first renders on two threads race; this layer keeps no
 * state of its own so a single dedicated worker can own every call (spec §5).
 *}
unit SpxStudio;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  Classes, Generics.Collections, Spintax;

type
  { A preview draws fresh unless the user pins a seed; a batch always seeds, because an
    exported variant that cannot be regenerated is not reproducible (spec §4.6). }
  TSpxRngMode = (spxRandom, spxSeeded);

  { The workspace's template set: slug -> text, built by the HOST from a folder listing and
    handed in whole (ADR 0003). editor-core does no I/O, so M0 is testable without a
    filesystem and the folder rules live in the loader.

    Lookup is EXACT. TDictionary compares strings case-sensitively, which is what the engine
    does since v0.2.2 and what every engine in the family does -- `#include "Intro"` does not
    find `intro`. Do not "fix" that with a case-insensitive comparer: on NTFS the filesystem
    would happily open the wrong file and the preview would then disagree with every other
    engine about the same document. }
  TSpxTemplateSet = TStrMap;

  { The lookup half of the engine's seam (engine ADR 0004). The engine owns the semantics --
    the child is parsed and rendered on its own, inherits the runtime context but not the
    parent's #set/#def, an unknown target or a cycle or a depth overflow resolves to the
    empty string -- and this owns nothing but the map it was handed. }
  TSpxSetResolver = class(TSpIncludeResolver)
  private
    FTemplates: TSpxTemplateSet;   // caller owns
  public
    constructor Create(ATemplates: TSpxTemplateSet);
    function Resolve(const Ref: string; out Text: string): Boolean; override;
  end;

  { Everything an engine call needs that is not the template text. The variable map and the
    template set are the CALLER's -- this layer never frees them -- matching `TSpContext.Vars`
    and `TSpContext.IncludeResolver`, which the engine documents the same way.

    Templates = nil leaves every `#include` in the output verbatim, which is the engine's
    no-resolver behaviour and the reference's. MaxIncludeDepth is left at the engine's family
    default (20); Studio has no reason to want a different cap. }
  TSpxContext = record
    Locale: string;
    Vars: TStrMap;
    Templates: TSpxTemplateSet;
    RngMode: TSpxRngMode;
    Seed: LongWord;
  end;

  { One generated variant and the seed that produced it. The seed travels with the text
    because export has to be able to regenerate a single row later (spec §4.6): the same
    seed, engine tag and context reproduce it exactly. }
  TSpxVariant = record
    Seed: LongWord;
    Text: string;
  end;
  TSpxVariantList = TList<TSpxVariant>;

  { What the variables panel draws (spec §4.4). A macro is `#set` or `#def` and comes with
    the value and the position the ENGINE reported for its directive; a runtime variable is
    a `%name%` the document references and nothing defines, so its value is whatever the
    user has typed into the panel and its position is 0/0 -- there is no definition to jump
    to. }
  TSpxVarKind = (spxVarSet, spxVarDef, spxVarRuntime);

  TSpxVarInfo = record
    Name: string;          // lower-cased, the way the engine keys macros
    Kind: TSpxVarKind;
    Value: string;
    Line, Column: Integer;
  end;

  { One `#include` OCCURRENCE, so "jump to the directive" has somewhere to go and two
    includes of one target stay two rows. Known is measured against the template set, with
    the engine's exact comparison. }
  TSpxIncludeInfo = record
    Target: string;
    Known: Boolean;
    Line, Column: Integer;
  end;

  TSpxModel = class
  public
    Vars: TList<TSpxVarInfo>;
    Includes: TList<TSpxIncludeInfo>;
    constructor Create;
    destructor Destroy; override;
  end;

  { Diagnostics for ONE file, in that file's own coordinates. Slug is '' for the open
    document. Mixing coordinate spaces is the one thing this must never do: a position from
    a fragment means nothing in the editor's buffer. }
  TSpxFileReport = class
  public
    Slug: string;
    Diags: TSpDiagList;
    constructor Create(const ASlug: string; ADiags: TSpDiagList);
    destructor Destroy; override;
  end;

  { Studio's OWN findings, kept apart from engine diagnostics so the panel can say which is
    which (spec §4.3). They carry a file and a position for the same reason engine
    diagnostics do -- a note the user cannot jump to is a note they cannot act on.

    Position 0/0 means "unknown", the engine's own convention: the raw-sentinel note has one,
    because locating it would mean re-deriving the engine's editor-coordinate walk, and this
    layer does not re-derive what the engine owns. }
  TSpxNoteKind = (spxNoteCycle, spxNoteTooDeep, spxNoteCaseMismatch, spxNoteUnknownTarget,
                  spxNoteRawSentinel);

  TSpxNote = record
    Kind: TSpxNoteKind;
    Slug: string;      // the file the note was found in; '' = the open document
    Target: string;    // the include target it is about, where there is one
    Hint: string;      // the near-miss slug for a case mismatch
    Line, Column: Integer;
  end;
  TSpxNoteList = TList<TSpxNote>;

  { One diagnostic reduced to what an editor can draw: a span and whether it is fatal.
    Everything else -- the code, the file, the panel row -- stays in TSpxReport; this is the
    squiggle layer and nothing more. }
  TSpxDiagMark = record
    Line, Col: Integer;
    EndLine, EndCol: Integer;
    IsError: Boolean;
    Code: string;
  end;
  TSpxDiagMarks = array of TSpxDiagMark;

  { What the diagnostics panel and the repair loop consume (spec §4.3, §5).

    Errors/Warnings are counted over the WHOLE include closure, because an export degrades
    on a broken fragment just as surely as on a broken document. Probes are M renders used
    for the health flags, on fixed seeds so the same document always reports the same
    numbers. }
  TSpxReport = class
  public
    Files: TObjectList<TSpxFileReport>;
    Errors, Warnings: Integer;
    Probes, EmptyProbes, DistinctProbes: Integer;
    FullwidthFallback: Boolean;
    Notes: TSpxNoteList;
    constructor Create;
    destructor Destroy; override;
    function IsValid: Boolean;
  end;

{ Call once at start-up, before any engine call.

  Under FPC a `string` holds UTF-8 BYTES, and the RTL decodes literals, files and OS
  strings through DefaultSystemCodePage. Leave it at the machine's ANSI codepage and
  Cyrillic turns into '?' BEFORE the engine ever sees it -- the engine cannot fix that
  for its host, because the setting is a global of the host process. It cost the engine a
  whole debugging session (spec §7), which is why it is the first thing in this layer
  rather than a note in a README.

  A UTF-16 compiler needs nothing here: there `string` is code units and no codepage is
  consulted. }
procedure SpxInitHost;

{ A context that draws fresh every render -- the preview's default (spec §4.2). Templates
  may be nil: then `#include` stays in the output verbatim. }
function SpxContext(const Locale: string; Vars: TStrMap;
  Templates: TSpxTemplateSet = nil): TSpxContext;

{ A context pinned to a seed: the same template renders the same text every time, which is
  what makes a preview stable while an edit is compared against it, and what lets an
  exported row be regenerated. }
function SpxSeededContext(const Locale: string; Vars: TStrMap; Seed: LongWord;
  Templates: TSpxTemplateSet = nil): TSpxContext;

{ One rendered example. PostProcess is always on: the right pane is WYSIWYG against the
  engines that ship the text, and a preview without the cosmetic stage lies about spacing
  and capitalization. }
function SpxRenderSample(const Tmpl: string; const Ctx: TSpxContext): string;

{ A selection rendered in the document's scope (spec §4.2): the document's `#set`/`#def`
  lines, in source order, prepended to the fragment. The directives come from the engine's
  own list, so a `#set` that only LOOKS like one -- inside a `/# ... #/` comment, or
  malformed -- is not in scope here either.

  Not byte-identical to the same slice of a full render (fresh draw, `#def` rolled again).
  It is a true preview of what the fragment produces, not a promise of the same bytes. A
  selection taken from the MIDDLE of a line is rendered at a line start, so a line-anchored
  construct inside it (`#include`, `#set`) behaves as it would at the start of a line, not
  as it does where it sits -- the fragment is rendered "as if it were the template", which
  is the definition, not an accident. }
function SpxRenderFragment(const Doc, Fragment: string; const Ctx: TSpxContext): string;

{ The variables and includes panel model (spec §4.4). Macros and include occurrences come
  from `SpExtractDirectives` -- values and positions included -- and the runtime variables
  are what the document references and nothing defines. Caller frees. }
function SpxExtractModel(const Tmpl: string; const Ctx: TSpxContext): TSpxModel;

{ Diagnostics for the document AND every file it includes, each validated separately in its
  own coordinates (spec §4.3), plus Probes health renders. Caller frees.

  `knownVariables` is the runtime context's names, for every file: a file's own `#set`/`#def`
  are visible to the validator already, and the parent's are NOT visible to a child at render
  time, so passing them down would silence a warning that is true (ADR 0003).

  DocSlug is the document's own slug when it is a member of the set -- which it is whenever
  the host built the set from the folder the document lives in. Without it the walk would
  reach the document again through its own slug and validate the same text twice, counting
  one broken bracket as two errors.

  LIMIT, and it cannot be closed here: the closure is found by scanning SOURCE for `#include`
  lines, while the engine resolves over the RENDERED text. An include that only appears after
  a macro expands (`#set %inc% = #include "frag"`, then `%inc%`) is resolved by the engine and
  never validated by this walk. Closing it would mean rendering first and re-parsing the
  output, which buys a corner at the price of the whole design.

  No caching here: this layer stays stateless so one worker can own every engine call
  (spec §5). Deciding what to re-validate on a keystroke is the caller's, which is the layer
  that knows what the user touched. }
function SpxHealthReport(const Doc: string; const Ctx: TSpxContext;
  Probes: Integer; const DocSlug: string = ''): TSpxReport;

{ The OPEN DOCUMENT's diagnostics as spans the editor can underline (spec §4.1).

  Three rules, all of them the spec's:
    * only the document's own file. A fragment's Line/Column are coordinates in ANOTHER
      buffer, and drawing them here would underline whatever text happens to sit there;
    * `Line = 0` means the engine could not locate the finding, honestly. It stays in the
      panel and gets no squiggle -- Studio does not invent a place;
    * `End* = 0` means no span was cheap to compute, so the mark is one character wide at
      the start rather than a guess at the extent. }
function SpxDocumentMarks(Report: TSpxReport): TSpxDiagMarks;

{ Count variants with reproducible seeds: `seed_i = SeedBase + i`, recorded on each variant.
  TMulberry32Rng mixes its seed internally (add-constant, then xorshift-multiply), so
  consecutive seeds give uncorrelated streams and the derivation needs nothing cleverer
  (spec §4.6).

  Ctx.RngMode is deliberately IGNORED here: a batch is always seeded, or the set it produces
  cannot be regenerated. Count <= 0 yields an empty list. The caller frees the list. }
function SpxRenderBatch(const Tmpl: string; const Ctx: TSpxContext;
  Count: Integer; SeedBase: LongWord): TSpxVariantList;

implementation

uses
  SysUtils;   // implementation-only: Trim, Format-free helpers below

procedure SpxInitHost;
begin
  {$IFDEF FPC}
  DefaultSystemCodePage := CP_UTF8;
  {$ENDIF}
end;

constructor TSpxSetResolver.Create(ATemplates: TSpxTemplateSet);
begin
  inherited Create;
  FTemplates := ATemplates;
end;

{ False is the reference's `null`: no such template. The engine turns that into the empty
  string, leniently, and never into an error -- an unknown target is already reported by
  SpValidate against the set's slugs (spec §4.3), which is where a user should hear about it. }
function TSpxSetResolver.Resolve(const Ref: string; out Text: string): Boolean;
begin
  Text := '';
  Result := (FTemplates <> nil) and FTemplates.TryGetValue(Ref, Text);
end;

function SpxContext(const Locale: string; Vars: TStrMap;
  Templates: TSpxTemplateSet = nil): TSpxContext;
begin
  Result.Locale := Locale;
  Result.Vars := Vars;
  Result.Templates := Templates;
  Result.RngMode := spxRandom;
  Result.Seed := 0;
end;

function SpxSeededContext(const Locale: string; Vars: TStrMap; Seed: LongWord;
  Templates: TSpxTemplateSet = nil): TSpxContext;
begin
  Result := SpxContext(Locale, Vars, Templates);
  Result.RngMode := spxSeeded;
  Result.Seed := Seed;
end;

{ The engine context for one call. Rng = nil is not an oversight: the engine then builds its
  own default generator, which is the analogue of the reference rendering with no seed. The
  resolver is nil exactly when there is no template set, which leaves `#include` verbatim --
  also the reference's behaviour with no resolver.

  MaxIncludeDepth stays 0, which selects the engine's SP_DEFAULT_INCLUDE_DEPTH, the family's
  20. A different cap would make this preview disagree with the engines that ship the text. }
function EngineContext(const Ctx: TSpxContext; Rng: TSpRng;
  Resolver: TSpIncludeResolver): TSpContext;
begin
  Result := Default(TSpContext);
  Result.Locale := Ctx.Locale;
  Result.Vars := Ctx.Vars;
  Result.PostProcess := True;   // never left to the record's zeroed default (spec §7)
  Result.Rng := Rng;
  Result.IncludeResolver := Resolver;
end;

{ One render with the seed the caller asked for, or with none. Whatever this creates, it
  frees: the engine takes ownership of neither the RNG nor the resolver. }
function RenderWith(const Tmpl: string; const Ctx: TSpxContext;
  Seeded: Boolean; Seed: LongWord): string;
var rng: TSpRng; resolver: TSpxSetResolver;
begin
  if Seeded then rng := TMulberry32Rng.Create(Seed) else rng := nil;
  if Ctx.Templates <> nil then resolver := TSpxSetResolver.Create(Ctx.Templates)
  else resolver := nil;
  try
    Result := SpRender(Tmpl, EngineContext(Ctx, rng, resolver));
  finally
    resolver.Free;
    rng.Free;
  end;
end;

function SpxRenderSample(const Tmpl: string; const Ctx: TSpxContext): string;
begin
  Result := RenderWith(Tmpl, Ctx, Ctx.RngMode = spxSeeded, Ctx.Seed);
end;

function SpxRenderBatch(const Tmpl: string; const Ctx: TSpxContext;
  Count: Integer; SeedBase: LongWord): TSpxVariantList;
var i: Integer; v: TSpxVariant;
begin
  Result := TSpxVariantList.Create;
  for i := 0 to Count - 1 do
  begin
    { LongWord arithmetic wraps, which is the intended behaviour at the top of the range:
      the seed is an identifier for regenerating a row, not a counter to overflow. }
    v.Seed := SeedBase + LongWord(i);
    v.Text := RenderWith(Tmpl, Ctx, True, v.Seed);
    Result.Add(v);
  end;
end;

function SpxDocumentMarks(Report: TSpxReport): TSpxDiagMarks;
var i, j, n: Integer; d: TSpDiag; m: TSpxDiagMark;
begin
  Result := nil;
  n := 0;
  for i := 0 to Report.Files.Count - 1 do
  begin
    if Report.Files[i].Slug <> '' then Continue;
    for j := 0 to Report.Files[i].Diags.Count - 1 do
    begin
      d := Report.Files[i].Diags[j];
      if d.Line <= 0 then Continue;             { unlocated: panel only }
      m.Line := d.Line;
      m.Col := d.Column;
      m.IsError := d.Severity = 'error';
      m.Code := d.Code;
      if (d.EndLine > 0) and ((d.EndLine > d.Line) or (d.EndColumn > d.Column)) then
      begin
        m.EndLine := d.EndLine;
        m.EndCol := d.EndColumn;
      end
      else
      begin
        m.EndLine := d.Line;
        m.EndCol := d.Column + 1;               { one character, not a guessed extent }
      end;
      if n = Length(Result) then
        SetLength(Result, 8 + n * 2);
      Result[n] := m;
      Inc(n);
    end;
  end;
  SetLength(Result, n);
end;

{ ── the fragment preview ─────────────────────────────────────────────────── }

function SpxRenderFragment(const Doc, Fragment: string; const Ctx: TSpxContext): string;
var dirs: TSpDirectiveList; i: Integer; prelude: string;
begin
  prelude := '';
  dirs := SpExtractDirectives(Doc);
  try
    for i := 0 to dirs.Count - 1 do
      if (dirs[i].Kind = 'set') or (dirs[i].Kind = 'def') then
        { Text is the line the RENDERER consumed, comments already gone, so re-emitting it
          costs no re-spelling of the grammar. }
        prelude := prelude + dirs[i].Text + #10;
  finally
    dirs.Free;
  end;
  Result := SpxRenderSample(prelude + Fragment, Ctx);
end;

{ ── the panel model ──────────────────────────────────────────────────────── }

constructor TSpxModel.Create;
begin
  inherited Create;
  Vars := TList<TSpxVarInfo>.Create;
  Includes := TList<TSpxIncludeInfo>.Create;
end;

destructor TSpxModel.Destroy;
begin
  Vars.Free;
  Includes.Free;
  inherited Destroy;
end;

function SpxExtractModel(const Tmpl: string; const Ctx: TSpxContext): TSpxModel;
var
  dirs: TSpDirectiveList;
  ex: TExtractResult;
  defined: TStringList;
  runtimeVals: TStrMap;
  pair: TPair<string, string>;
  i: Integer;
  v: TSpxVarInfo;
  incInfo: TSpxIncludeInfo;
begin
  Result := TSpxModel.Create;
  defined := nil;
  runtimeVals := nil;
  try
   try
    defined := TStringList.Create;
    { Macro names are ASCII by the engine's grammar, so the default (case-insensitive)
      compare would only ever fold names that are already equal -- but say what is meant. }
    defined.CaseSensitive := True;
    runtimeVals := TStrMap.Create;
    { The engine keys macros lower-cased and matches runtime names case-insensitively, so
      the panel can show a value the user typed as BRAND against a %brand% reference. }
    if Assigned(Ctx.Vars) then
      for pair in Ctx.Vars do runtimeVals.AddOrSetValue(LowerCase(pair.Key), pair.Value);

    dirs := SpExtractDirectives(Tmpl);
    try
      for i := 0 to dirs.Count - 1 do
        if dirs[i].Kind = 'include' then
        begin
          { Known is False both for a real miss and for "there is no set at all"; the caller
            knows which, because it is the caller that did or did not supply Templates. }
          incInfo.Target := dirs[i].Name;
          incInfo.Known := (Ctx.Templates <> nil) and Ctx.Templates.ContainsKey(dirs[i].Name);
          incInfo.Line := dirs[i].Line;
          incInfo.Column := dirs[i].Column;
          Result.Includes.Add(incInfo);
        end
        else
        begin
          v.Name := dirs[i].Name;
          if dirs[i].Kind = 'def' then v.Kind := spxVarDef else v.Kind := spxVarSet;
          v.Value := dirs[i].Value;
          v.Line := dirs[i].Line;
          v.Column := dirs[i].Column;
          Result.Vars.Add(v);
          { Duplicates are kept: two definitions of one name is what the engine calls
            definition.duplicate-name, and a panel that silently showed one row would hide
            the second half of the error. }
          if defined.IndexOf(v.Name) < 0 then defined.Add(v.Name);
        end;
    finally
      dirs.Free;
    end;

    { Everything referenced and not defined here is a runtime variable: the panel offers a
      value for it, and until one is given the validator warns (spec §4.3/§4.4). }
    ex := SpExtract(Tmpl);
    try
      for i := 0 to ex.Refs.Count - 1 do
        if defined.IndexOf(ex.Refs[i]) < 0 then
        begin
          v.Name := ex.Refs[i];
          v.Kind := spxVarRuntime;
          if not runtimeVals.TryGetValue(v.Name, v.Value) then v.Value := '';
          v.Line := 0;
          v.Column := 0;
          Result.Vars.Add(v);
        end;
    finally
      ex.Refs.Free; ex.Sets.Free; ex.Defs.Free; ex.Includes.Free;
    end;
   finally
    defined.Free;
    runtimeVals.Free;
   end;
  except
    { Result is the return value: if we leave by exception nobody else can free it. }
    Result.Free;
    raise;
  end;
end;

{ ── the health report ────────────────────────────────────────────────────── }

constructor TSpxFileReport.Create(const ASlug: string; ADiags: TSpDiagList);
begin
  inherited Create;
  Slug := ASlug;
  Diags := ADiags;
end;

destructor TSpxFileReport.Destroy;
begin
  Diags.Free;
  inherited Destroy;
end;

constructor TSpxReport.Create;
begin
  inherited Create;
  Files := TObjectList<TSpxFileReport>.Create(True);
  Notes := TSpxNoteList.Create;
end;

destructor TSpxReport.Destroy;
begin
  Files.Free;
  Notes.Free;
  inherited Destroy;
end;

function TSpxReport.IsValid: Boolean;
begin
  Result := Errors = 0;
end;

{ U+FF5B / U+FF5D -- the fullwidth braces the engine emits when a block is too malformed to
  render but must not throw. Their presence in a probe is the signal that something the
  validator may have called a mere warning is destroying output. Spelled per string width,
  like the engine's own literals. }
function FullwidthBrace(opening: Boolean): string;
begin
  {$IFDEF UNICODE}
  if opening then Result := #$FF5B else Result := #$FF5D;
  {$ELSE}
  if opening then Result := #$EF#$BD#$9B else Result := #$EF#$BD#$9D;
  {$ENDIF}
end;

{ Case folding through the ENGINE's Unicode tables, not SysUtils.LowerCase, which folds
  A..Z and stops. This runs on include targets, and targets are filenames: in a product
  written for Russian templates they will be Cyrillic, where an ASCII fold makes
  `Вступление` and `вступление` look like different words and the near-miss hint below
  would never fire -- exactly where it is needed most. }
function FoldCase(const s: string): string;
var i, cpLen: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(s) do
  begin
    Result := Result + SpUpperCodePoint(SpCodePointAt(s, i, cpLen));
    Inc(i, cpLen);
  end;
end;

{ Reserved sentinels in author markup. `SpRender` deletes U+E000..U+E005 before parsing
  while the editor-side calls read the source as written, so a document carrying raw ones
  makes the panel and the preview tell different stories (spec §7). No position: locating it
  would mean re-deriving the engine's editor-coordinate walk, and this layer does not
  re-derive what the engine owns. }
function HasRawSentinel(const s: string): Boolean;
var i, cpLen: Integer; cp: LongWord;
begin
  Result := False;
  i := 1;
  while i <= Length(s) do
  begin
    cp := SpCodePointAt(s, i, cpLen);
    if (cp >= $E000) and (cp <= $E005) then Exit(True);
    Inc(i, cpLen);
  end;
end;

procedure AddNote(Report: TSpxReport; Kind: TSpxNoteKind; const Slug, Target, Hint: string;
  Line, Column: Integer);
var n: TSpxNote;
begin
  n.Kind := Kind;
  n.Slug := Slug;
  n.Target := Target;
  n.Hint := Hint;
  n.Line := Line;
  n.Column := Column;
  Report.Notes.Add(n);
end;

{ Validate ONE file and file its diagnostics under its own slug. Coordinate spaces are never
  merged: a position from a fragment means nothing in the document's buffer. }
procedure ValidateFile(Report: TSpxReport; const Slug, Text, Locale: string;
  KnownIncludes, KnownVars: TStringList);
var diags: TSpDiagList; i: Integer;
begin
  diags := SpValidate(Text, Locale, KnownIncludes, KnownVars);
  try
    for i := 0 to diags.Count - 1 do
      if diags[i].Severity = 'error' then Inc(Report.Errors) else Inc(Report.Warnings);
    Report.Files.Add(TSpxFileReport.Create(Slug, diags));
    diags := nil;   // ownership moved into the file report
  finally
    diags.Free;     // only reached if the line above raised
  end;
  if HasRawSentinel(Text) then
    AddNote(Report, spxNoteRawSentinel, Slug, '', '', 0, 0);
end;

{ The include closure, walked the way the engine renders it: targets compared exactly, a
  cycle keyed on the ref string, the depth cap counting the include stack only. Each file is
  validated once however many times it is included; Path is what makes a cycle a cycle and a
  diamond merely a second visit. }
procedure WalkClosure(Report: TSpxReport; const Text, Slug: string; const Ctx: TSpxContext;
  Visited, Path, KnownIncludes, KnownVars: TStringList);
var
  dirs: TSpDirectiveList;
  i, j: Integer;
  target, childText, folded, hint: string;
begin
  ValidateFile(Report, Slug, Text, Ctx.Locale, KnownIncludes, KnownVars);
  if Ctx.Templates = nil then Exit;

  dirs := SpExtractDirectives(Text);
  try
    for i := 0 to dirs.Count - 1 do
    begin
      if dirs[i].Kind <> 'include' then Continue;
      target := dirs[i].Name;

      { Path IS the engine's include stack: a cycle is a target already on it, keyed on the
        ref string, and the depth cap counts this stack only. Both lists compare
        case-sensitively (set where they are created) because the engine compares targets
        exactly -- a case-insensitive IndexOf here would call `Intro` a cycle of `intro` and
        skip a real file that differs only in case. }
      if Path.IndexOf(target) >= 0 then
      begin
        { The engine unwinds this to the empty string and does not call it invalid -- so
          neither do we. But a fragment that silently renders as nothing deserves a word. }
        AddNote(Report, spxNoteCycle, Slug, target, '', dirs[i].Line, dirs[i].Column);
        Continue;
      end;
      if Path.Count >= SP_DEFAULT_INCLUDE_DEPTH then
      begin
        AddNote(Report, spxNoteTooDeep, Slug, target, '', dirs[i].Line, dirs[i].Column);
        Continue;
      end;

      if not Ctx.Templates.TryGetValue(target, childText) then
      begin
        { The engine reports include.unknown-target against the set's slugs -- but only when
          it was given a non-empty list, so an EMPTY set leaves the miss unsaid. And it can
          never know that the set holds the same name in another case, which on Windows is
          the likeliest reason for the miss. }
        folded := FoldCase(target);
        hint := '';
        for j := 0 to KnownIncludes.Count - 1 do
          if FoldCase(KnownIncludes[j]) = folded then
            { Several slugs can fold to one target (`frag` and `FRAG`). Take the smallest
              rather than whichever the map happened to enumerate first, so the note reads
              the same on every rebuild of the set. }
            if (hint = '') or (KnownIncludes[j] < hint) then hint := KnownIncludes[j];
        if hint <> '' then
          AddNote(Report, spxNoteCaseMismatch, Slug, target, hint,
                  dirs[i].Line, dirs[i].Column);
        if KnownIncludes.Count = 0 then
          AddNote(Report, spxNoteUnknownTarget, Slug, target, '',
                  dirs[i].Line, dirs[i].Column);
        Continue;
      end;

      { Visited is per-closure, not per-path: a file included from two places is one file to
        validate, while two ALIASES of one text are two slugs and neither is a cycle. }
      if Visited.IndexOf(target) >= 0 then Continue;
      Visited.Add(target);
      Path.Add(target);
      WalkClosure(Report, childText, target, Ctx, Visited, Path, KnownIncludes, KnownVars);
      Path.Delete(Path.Count - 1);
    end;
  finally
    dirs.Free;
  end;
end;

function SpxHealthReport(const Doc: string; const Ctx: TSpxContext;
  Probes: Integer; const DocSlug: string = ''): TSpxReport;
var
  knownIncludes, knownVars, visited, path, outputs: TStringList;
  pair: TPair<string, string>;
  i: Integer;
  probe, savedDoc: string;
begin
  Result := TSpxReport.Create;
  knownIncludes := nil; knownVars := nil; visited := nil; path := nil; outputs := nil;
  try
    knownIncludes := TStringList.Create;
    knownVars := TStringList.Create;
    visited := TStringList.Create;
    path := TStringList.Create;
    outputs := TStringList.Create;
    try
      { The engine compares include targets EXACTLY (v0.2.2). `visited` and `path` decide
        what counts as already-seen and as a cycle, so leaving them on TStringList's
        case-INSENSITIVE default would reintroduce, inside Studio, the very defect the
        engine fixed: `Intro` would read as a cycle of `intro`, and a real file differing
        only in case would never be validated. `knownIncludes` is only ever indexed here --
        SpValidate compares slugs with its own exact helper -- so its flag changes nothing
        today and is set so it cannot start to. }
      knownIncludes.CaseSensitive := True;
      visited.CaseSensitive := True;
      path.CaseSensitive := True;

      if Ctx.Templates <> nil then
        for pair in Ctx.Templates do knownIncludes.Add(pair.Key);
      { Variable names are ASCII by the engine's grammar and it matches knownVariables
        case-insensitively, so an ASCII fold is the right one here. }
      if Assigned(Ctx.Vars) then
        for pair in Ctx.Vars do knownVars.Add(LowerCase(pair.Key));

      { The document is normally a member of its own folder's set, so the walk can reach it
        again through its own slug. Skip that ONLY when the set's copy is the same text as
        the buffer -- then it is genuinely the same file and validating it twice would count
        one broken bracket as two errors. When the buffer has unsaved edits the two differ,
        and the SAVED copy is what the engine will render for an `#include`, so it has to be
        validated on its own. Path stays EMPTY at document level either way, because the
        engine's include stack is empty there and the depth cap counts that stack. }
      if (DocSlug <> '') and (Ctx.Templates <> nil) and
         Ctx.Templates.TryGetValue(DocSlug, savedDoc) and (savedDoc = Doc) then
        visited.Add(DocSlug);

      { Both sets go in on every pass. knownVars carries the RUNTIME names only: a file's own
        macros are visible to the validator anyway, and the parent's are not visible to a
        child at render time (ADR 0003). }
      WalkClosure(Result, Doc, '', Ctx, visited, path, knownIncludes, knownVars);

      { Health probes on fixed seeds, so the same document always reports the same numbers --
        a status bar that flickers between runs teaches the user to ignore it. }
      outputs.CaseSensitive := True;   // 'AA' and 'aa' are two renders, not one
      outputs.Sorted := True;
      outputs.Duplicates := dupIgnore;
      for i := 1 to Probes do
      begin
        probe := RenderWith(Doc, Ctx, True, LongWord(i));
        Inc(Result.Probes);
        if Trim(probe) = '' then Inc(Result.EmptyProbes);
        if (Pos(FullwidthBrace(True), probe) > 0) or (Pos(FullwidthBrace(False), probe) > 0) then
          Result.FullwidthFallback := True;
        outputs.Add(probe);
      end;
      Result.DistinctProbes := outputs.Count;
    finally
      knownIncludes.Free;
      knownVars.Free;
      visited.Free;
      path.Free;
      outputs.Free;
    end;
  except
    { The report is the return value, so nothing else can free it if we leave by exception --
      and this layer is built for a cancelling worker (spec §5), where that is not exotic. }
    Result.Free;
    raise;
  end;
end;

end.
