{**
 * studio_tests -- Studio's own assertions.
 *
 * Two things are gated here, and neither is the engine's behaviour: the engine has its
 * own golden corpus and local suite, which this repository references and never copies
 * (engine decision 0001).
 *
 *   1. THE HOST CONTRACT this layer owns -- the codepage the engine cannot set for its
 *      caller, and the PostProcess flag a zeroed record leaves False (spec §7). Both cost
 *      the engine real debugging sessions; here they are executable rather than advisory.
 *
 *   2. THE ENGINE BASELINE the design is pinned to -- that `engine/` really is a build
 *      carrying diagnostic positions, `SpExtractDirectives` and the four-argument
 *      `SpValidate` (spec §4.1-§4.3), and that `#include` still renders verbatim, which is
 *      what the preview currently relies on (ADR 0003). These are tripwires on the
 *      submodule pin, not a second opinion about the engine: if a bump changes any of
 *      them, Studio's spec has to change with it, and this is where that gets noticed.
 *
 * Exits 1 on failure; the pre-push gate and CI both run it.
 *}
program studio_tests;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}
{$APPTYPE CONSOLE}

uses
  { First, and before anything that might pull in the RTL's threading: without it a TThread
    on Unix fails at run time with "This binary has no thread support compiled in". The GUI
    entry point does the same; the suite needs it because it exercises the engine worker. }
  {$IFDEF UNIX}cthreads,{$ENDIF}
  { zipper for reading an exported .xlsx back apart -- the writer is only worth as much as
    the check that opens what it wrote. }
  SysUtils, Classes, Generics.Collections, zipper, StrUtils, DOM, XMLRead,
  {$IFDEF FPC}
  Spintax, SpxStudio, SpxTokens, SpxDemo, SpxDedupe, SpxExport, SpxFiles, SpxEngineThread;
  {$ELSE}
  Spintax in '..\engine\src\Spintax.pas',
  SpxStudio in '..\src\SpxStudio.pas',
  SpxTokens in '..\src\SpxTokens.pas',
  SpxDemo in '..\src\SpxDemo.pas',
  SpxDedupe in '..\src\SpxDedupe.pas',
  SpxExport in '..\src\SpxExport.pas',
  SpxFiles in '..\gui\SpxFiles.pas',
  SpxEngineThread in '..\gui\SpxEngineThread.pas';
  {$ENDIF}

var
  Failures: Integer = 0;
  Checks: Integer = 0;

function Hex(const s: string): string;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(s) do Result := Result + IntToHex(Ord(s[i]), 2) + ' ';
  Result := TrimRight(Result);
end;

procedure Check(const name, got, want: string);
begin
  Inc(Checks);
  if got = want then Exit;
  Inc(Failures);
  Writeln('FAIL ', name);
  Writeln('     want <', Hex(want), '>');
  Writeln('     got  <', Hex(got), '>');
end;

procedure CheckTrue(const name: string; cond: Boolean);
begin
  Inc(Checks);
  if cond then Exit;
  Inc(Failures);
  Writeln('FAIL ', name, ' (expected true)');
end;

{ A preview-shaped context: what spec §4.2 says every Studio render carries. }
function PreviewCtx(const locale: string; rng: TSpRng): TSpContext;
begin
  Result := Default(TSpContext);
  Result.Locale := locale;
  Result.PostProcess := True;
  Result.Rng := rng;
end;

function RenderFirst(const tmpl: string; postProcess: Boolean): string;
var ctx: TSpContext;
begin
  ctx := Default(TSpContext);
  ctx.Locale := 'ru';
  ctx.PostProcess := postProcess;
  ctx.Rng := TFirstRng.Create;
  try
    Result := SpRender(tmpl, ctx);
  finally
    ctx.Rng.Free;
  end;
end;

{ ── 1. the host contract ─────────────────────────────────────────────────── }

procedure TestHostContract;
var ctx: TSpContext;
begin
  {$IFDEF FPC}
  { SpxInitHost ran in the main block. Without it the RTL decodes through the machine's
    ANSI codepage and the next check would come back full of '?'. }
  CheckTrue('host/default-codepage-is-utf8', DefaultSystemCodePage = CP_UTF8);
  {$ENDIF}

  { Cyrillic in, the same Cyrillic out -- byte for byte, which is what Hex() reports on a
    failure. The engine is full of it, and so is every template this product exists for. }
  Check('host/cyrillic-round-trip', RenderFirst('Привет, {мир|свет}', False), 'Привет, мир');

  { A zeroed TSpContext leaves PostProcess FALSE, where the JS reference defaults it true.
    Studio must set it explicitly for WYSIWYG or the right pane diverges from the engines
    that actually ship the text (spec §7). Pinned in both directions so a future default
    change cannot pass unnoticed. }
  ctx := Default(TSpContext);
  CheckTrue('host/postprocess-defaults-false', ctx.PostProcess = False);
  Check('host/postprocess-off-leaves-text', RenderFirst('привет. мир', False), 'привет. мир');
  { The reference's post-process capitalizes the first letter and the letter after
    sentence punctuation; with Unicode tables that holds for Cyrillic too. }
  Check('host/postprocess-on-capitalizes', RenderFirst('привет. мир', True), 'Привет. Мир');

  { And the shape Studio actually renders with. }
  ctx := PreviewCtx('ru', nil);
  CheckTrue('host/preview-ctx-postprocess', ctx.PostProcess);
  CheckTrue('host/preview-ctx-locale', ctx.Locale = 'ru');
end;

{ ── 2. the engine baseline (submodule pin tripwires) ─────────────────────── }

function FirstDiag(const src: string; known: TStringList): string;
var d: TSpDiagList; i: Integer;
begin
  Result := 'none';
  d := SpValidate(src, 'ru', known, nil);
  try
    for i := 0 to d.Count - 1 do
      Exit(Format('%s/%s@%d:%d', [d[i].Code, d[i].Severity, d[i].Line, d[i].Column]));
  finally
    d.Free;
  end;
end;

procedure TestEngineBaseline;
var
  dirs: TSpDirectiveList;
  kv: TStringList;
  diags: TSpDiagList;
begin
  { Diagnostics carry source positions from v0.2.0 on. Studio draws squiggles and jumps
    to errors from these instead of scanning the document itself (spec §4.1). }
  Check('engine/diag-carries-position', FirstDiag(']', nil),
        'bracket.unexpected-closing/error@1:1');

  { SpExtractDirectives: occurrences with spans, values and the consumed line. The
    fragment preview and the variables panel are both built on it (spec §4.2, §4.4). }
  dirs := SpExtractDirectives('#set %brand% = Акме'#10'#include "frag"');
  try
    CheckTrue('engine/directives-count', dirs.Count = 2);
    if dirs.Count = 2 then
    begin
      Check('engine/directive-set', Format('%s:%s=%s@%d:%d',
        [dirs[0].Kind, dirs[0].Name, dirs[0].Value, dirs[0].Line, dirs[0].Column]),
        'set:brand=Акме@1:1');
      Check('engine/directive-include', Format('%s:%s@%d:%d',
        [dirs[1].Kind, dirs[1].Name, dirs[1].Line, dirs[1].Column]), 'include:frag@2:1');
    end;
  finally
    dirs.Free;
  end;

  { v0.2.1 narrowed #include to the family's anchor: anything after the quoted target makes
    the line plain text, not an include. Studio's design builds on the family rule (ADR
    0003), and on the older tag this line was an include AND an include.unknown-target
    error — a template the rest of the family calls valid. A submodule moved back before
    that tag has to be noticed here rather than in a user's red status bar. }
  dirs := SpExtractDirectives('#include "a" "b"');
  try
    CheckTrue('engine/include-rule-is-family-anchored', dirs.Count = 0);
  finally
    dirs.Free;
  end;

  { engine v0.3.2, two fixes Studio can see. An include match may span line terminators, and
    the scans used to retry the line starts it had swallowed -- finding a PHANTOM second
    include, which the closure walk would then chase and validate. }
  dirs := SpExtractDirectives('#include "a'#10'#include "'#10'b"');
  try
    CheckTrue('engine/no-phantom-second-include', dirs.Count = 1);
  finally
    dirs.Free;
  end;

  { ...and a CRLF-terminated include reported a span ending BETWEEN the CR and the LF, which
    the editor line model rounds forward to the next line, with a stray CR left in Text.
    The panel points at these positions and the fragment prelude re-emits that text. }
  dirs := SpExtractDirectives('#include "frag"'#13#10'после');
  try
    CheckTrue('engine/crlf-include-is-one-directive', dirs.Count = 1);
    if dirs.Count = 1 then
      Check('engine/crlf-include-span-stops-before-the-terminator',
            Format('%s@%d:%d..%d:%d', [dirs[0].Text, dirs[0].Line, dirs[0].Column,
              dirs[0].EndLine, dirs[0].EndColumn]), '#include "frag"@1:1..1:16');
  finally
    dirs.Free;
  end;

  { The four-argument SpValidate. Studio must pass BOTH sets: a variable the user defined
    in the panel is not undefined, and the warning must not redden the status (spec §4.3). }
  kv := TStringList.Create;
  try
    kv.Add('brand');
    diags := SpValidate('%brand% рулит', 'ru', nil, kv);
    try
      CheckTrue('engine/knownvariables-suppresses-warning', diags.Count = 0);
    finally
      diags.Free;
    end;
  finally
    kv.Free;
  end;
  Check('engine/undefined-without-knownvariables', FirstDiag('%brand% рулит', nil),
        'variable.undefined/warning@1:1');

  { #include resolution is the host's, and with no resolver supplied the directive is
    rendered verbatim. Studio's preview shows exactly this until the engine grows the
    family's resolver seam (ADR 0003) -- when it does, this check is what notices. }
  Check('engine/include-renders-verbatim',
        RenderFirst('#include "frag"'#10'после', False), '#include "frag"'#10'после');
end;

{ ── 3. editor-core: the render path ──────────────────────────────────────── }

{ A runtime variable map, the shape the panel will hand editor-core. Caller frees. }
function Vars(const pairs: array of string): TStrMap;
var i: Integer;
begin
  Result := TStrMap.Create;
  i := 0;
  while i + 1 <= High(pairs) do
  begin
    Result.AddOrSetValue(pairs[i], pairs[i + 1]);
    Inc(i, 2);
  end;
end;

procedure TestRenderPath;
var
  v: TStrMap;
  ctx: TSpxContext;
  batch: TSpxVariantList;
  seen: TStringList;
  i: Integer;
  seeds, got: string;
begin
  { PostProcess is the layer's job, not the caller's: nobody mentioned it here, and the
    cosmetic stage still ran. Left to Default(TSpContext) it would be False and the right
    pane would drift from every engine that ships the text (spec §7). }
  ctx := SpxSeededContext('ru', nil, 1);
  Check('render/postprocess-is-always-on', SpxRenderSample('привет. мир', ctx),
        'Привет. Мир');

  { A pinned seed is what makes a preview hold still while an edit is compared against it. }
  ctx := SpxSeededContext('ru', nil, 7);
  Check('render/seeded-is-reproducible',
        SpxRenderSample('вариант: {a|b|c|d|e|f|g|h}', ctx),
        SpxRenderSample('вариант: {a|b|c|d|e|f|g|h}', ctx));

  { ...and the seed has to actually reach the generator. Asserted as "32 seeds do not all
    agree" rather than "seed 1 differs from seed 2": the second form would pin one engine's
    RNG mapping, and cross-engine RNG parity is an explicit non-goal. Eight options over 32
    draws makes a false failure a 1-in-8^31 event. }
  seen := TStringList.Create;
  try
    seen.Duplicates := dupIgnore;
    seen.Sorted := True;
    for i := 1 to 32 do
      seen.Add(SpxRenderSample('выбор: {a|b|c|d|e|f|g|h}', SpxSeededContext('ru', nil, i)));
    CheckTrue('render/seed-changes-the-draw', seen.Count > 1);
  finally
    seen.Free;
  end;

  { Random mode passes no generator at all, and the engine builds its own -- the analogue
    of the reference rendering without a seed. Only the shape is assertable. }
  got := SpxRenderSample('вариант: {a|b}', SpxContext('ru', nil));
  CheckTrue('render/random-mode-picks-an-option',
            (got = 'Вариант: a') or (got = 'Вариант: b'));

  { Runtime values reach the engine, and their keys are matched case-insensitively -- the
    panel should not have to lower-case what the user typed. }
  v := Vars(['brand', 'Акме']);
  try
    Check('render/vars-reach-the-engine',
          SpxRenderSample('%brand%', SpxSeededContext('ru', v, 1)), 'Акме');
  finally
    v.Free;
  end;
  v := Vars(['BRAND', 'Акме']);
  try
    Check('render/vars-key-is-case-insensitive',
          SpxRenderSample('%brand%', SpxSeededContext('ru', v, 1)), 'Акме');
  finally
    v.Free;
  end;

  { Locale flows through to the plural buckets: three forms for ru, two for en. }
  v := Vars(['n', '2']);
  try
    Check('render/locale-ru-plural',
          SpxRenderSample('штук: {plural %n%: товар|товара|товаров}',
                          SpxSeededContext('ru', v, 1)), 'Штук: товара');
    Check('render/locale-en-plural',
          SpxRenderSample('files: {plural %n%: file|files}',
                          SpxSeededContext('en', v, 1)), 'Files: files');
  finally
    v.Free;
  end;

  { seed_i = SeedBase + i, recorded on the variant. }
  batch := SpxRenderBatch('вариант: {a|b|c|d}', SpxContext('ru', nil), 4, 1000);
  try
    CheckTrue('batch/count', batch.Count = 4);
    seeds := '';
    for i := 0 to batch.Count - 1 do
    begin
      if i > 0 then seeds := seeds + ',';
      seeds := seeds + IntToStr(batch[i].Seed);
    end;
    Check('batch/seed-derivation', seeds, '1000,1001,1002,1003');

    { The export promise: a recorded seed regenerates its row byte for byte, given the same
      engine tag and the same context (spec §4.6). Note the batch was asked for from a
      RANDOM-mode context and still seeded every variant -- a set that cannot be
      regenerated is not an export. }
    for i := 0 to batch.Count - 1 do
      Check('batch/variant-' + IntToStr(i) + '-reproduces-from-its-seed',
            SpxRenderSample('вариант: {a|b|c|d}', SpxSeededContext('ru', nil, batch[i].Seed)),
            batch[i].Text);
  finally
    batch.Free;
  end;

  batch := SpxRenderBatch('x', SpxContext('ru', nil), 0, 1);
  try
    CheckTrue('batch/count-zero-is-empty', batch.Count = 0);
  finally
    batch.Free;
  end;
end;

{ ── 4. editor-core: #include through the engine's resolver seam ───────────── }

{ Studio owns the lookup, the engine owns the semantics (engine ADR 0004). These pin the
  semantics Studio's design depends on -- not because the engine is doubted, but because
  the whole preview claim rests on them, and a host that got them wrong is exactly how this
  seam came to exist. }
procedure TestIncludeResolution;
var
  set1, v: TStrMap;
  batch: TSpxVariantList;
begin
  set1 := Vars(['frag', 'Привет']);
  try
    Check('include/resolves-from-the-set',
          SpxRenderSample('#include "frag"', SpxSeededContext('ru', nil, 1, set1)),
          'Привет');

    { An unknown target is empty, leniently -- never an error and never the directive text.
      The user hears about it from SpValidate against the set's slugs, not from the render. }
    Check('include/unknown-target-is-empty',
          SpxRenderSample('#include "missing"', SpxSeededContext('ru', nil, 1, set1)), '');

    { Targets match EXACTLY, as they do everywhere in the family since engine v0.2.2. On
      NTFS a filesystem lookup would have opened `frag.spintax` here and the preview would
      then disagree with every other engine about the same document. }
    Check('include/target-case-is-exact',
          SpxRenderSample('#include "Frag"', SpxSeededContext('ru', nil, 1, set1)), '');

    { No set, no resolution: the line survives verbatim, which is the engine's no-resolver
      behaviour and the reference's. }
    Check('include/no-set-leaves-it-verbatim',
          SpxRenderSample('#include "frag"', SpxSeededContext('ru', nil, 1)),
          '#include "frag"');
  finally
    set1.Free;
  end;

  { The child is a document of its own: it inherits the runtime context but NOT the parent's
    macros. Splicing the child's source into the parent -- the design this project nearly
    shipped -- would have resolved %x% here and produced 'A'. }
  set1 := Vars(['child', 'ребёнок видит: %x%']);
  try
    { The blank line the stripped #set leaves behind is trimmed by the post-process, which
      ends in a trim -- hence no leading LF in the expectation. }
    Check('include/child-does-not-see-parent-macros',
          SpxRenderSample('#set %x% = A'#10'#include "child"',
                          SpxSeededContext('ru', nil, 1, set1)),
          'Ребёнок видит: %x%');
  finally
    set1.Free;
  end;

  v := Vars(['brand', 'Акме']);
  set1 := Vars(['child', 'бренд: %brand%']);
  try
    Check('include/child-inherits-the-runtime-context',
          SpxRenderSample('#include "child"', SpxSeededContext('ru', v, 1, set1)),
          'Бренд: Акме');
  finally
    set1.Free; v.Free;
  end;

  { Nested includes resolve; a cycle unwinds to empty rather than hanging or raising.
    Note the child's own include is LINE-ANCHORED: `A#include "b"` would be plain text,
    the family rule the engine narrowed to in v0.2.1 -- the first draft of this test got
    that wrong and the suite said so. }
  set1 := Vars(['a', 'A'#10'#include "b"', 'b', 'B']);
  try
    Check('include/nested-resolves',
          SpxRenderSample('#include "a"', SpxSeededContext('ru', nil, 1, set1)), 'A'#10'B');
  finally
    set1.Free;
  end;
  set1 := Vars(['a', 'A'#10'#include "b"', 'b', 'B'#10'#include "a"']);
  try
    Check('include/cycle-unwinds-to-empty',
          SpxRenderSample('#include "a"', SpxSeededContext('ru', nil, 1, set1)),
          'A'#10'B');
  finally
    set1.Free;
  end;

  { Export renders through the same context, so a batch resolves too -- and each variant
    still regenerates from its recorded seed. }
  set1 := Vars(['frag', '{красный|синий}']);
  try
    batch := SpxRenderBatch('цвет:'#10'#include "frag"', SpxContext('ru', nil, set1), 3, 77);
    try
      CheckTrue('include/batch-resolves', batch.Count = 3);
      { Substrings without their first letter: the post-process capitalizes after a line
        break, so the child's word arrives as 'Красный' or 'Синий'. }
      CheckTrue('include/batch-variant-has-the-child',
                (Pos('расный', batch[0].Text) > 0) or (Pos('иний', batch[0].Text) > 0));
      Check('include/batch-variant-reproduces',
            SpxRenderSample('цвет:'#10'#include "frag"',
                            SpxSeededContext('ru', nil, batch[2].Seed, set1)),
            batch[2].Text);
    finally
      batch.Free;
    end;
  finally
    set1.Free;
  end;
end;

{ ── 5. editor-core: the analysis path ────────────────────────────────────── }

{ The model as `kind:name=value@line:col` rows, so one string pins order and content. }
function ModelVars(const tmpl: string; const ctx: TSpxContext): string;
const KIND: array[TSpxVarKind] of string = ('set', 'def', 'runtime');
var m: TSpxModel; i: Integer;
begin
  Result := '';
  m := SpxExtractModel(tmpl, ctx);
  try
    for i := 0 to m.Vars.Count - 1 do
    begin
      if i > 0 then Result := Result + ' | ';
      Result := Result + Format('%s:%s=%s@%d:%d', [KIND[m.Vars[i].Kind], m.Vars[i].Name,
        m.Vars[i].Value, m.Vars[i].Line, m.Vars[i].Column]);
    end;
    if Result = '' then Result := '<none>';
  finally
    m.Free;
  end;
end;

function ModelIncludes(const tmpl: string; const ctx: TSpxContext): string;
var m: TSpxModel; i: Integer; mark: string;
begin
  Result := '';
  m := SpxExtractModel(tmpl, ctx);
  try
    for i := 0 to m.Includes.Count - 1 do
    begin
      if i > 0 then Result := Result + ' | ';
      if m.Includes[i].Known then mark := 'known' else mark := 'unknown';
      Result := Result + Format('%s(%s)@%d:%d',
        [m.Includes[i].Target, mark, m.Includes[i].Line, m.Includes[i].Column]);
    end;
    if Result = '' then Result := '<none>';
  finally
    m.Free;
  end;
end;

{ Studio's own notes as `kind:target->hint@slug:line:col`, joined -- one string pins kind,
  file, position and order together. }
function NotesOf(r: TSpxReport): string;
const KIND: array[TSpxNoteKind] of string =
  ('cycle', 'too-deep', 'case-mismatch', 'unknown-target', 'raw-sentinel');
var i: Integer; hint: string;
begin
  Result := '';
  for i := 0 to r.Notes.Count - 1 do
  begin
    if i > 0 then Result := Result + ' | ';
    if r.Notes[i].Hint <> '' then hint := '->' + r.Notes[i].Hint else hint := '';
    Result := Result + Format('%s:%s%s@%s:%d:%d', [KIND[r.Notes[i].Kind], r.Notes[i].Target,
      hint, r.Notes[i].Slug, r.Notes[i].Line, r.Notes[i].Column]);
  end;
  if Result = '' then Result := '<none>';
end;

{ U+E000, the first reserved sentinel, spelled per string width like the engine's literals. }
function Sentinel0: string;
begin
  {$IFDEF UNICODE}
  Result := #$E000;
  {$ELSE}
  Result := #$EE#$80#$80;
  {$ENDIF}
end;

{ Diagnostics of one file in a report, as `slug:code/severity@line:col`. }
function ReportOf(r: TSpxReport; const slug: string): string;
var i, j: Integer;
begin
  Result := 'no-such-file';
  for i := 0 to r.Files.Count - 1 do
    if r.Files[i].Slug = slug then
    begin
      Result := '';
      for j := 0 to r.Files[i].Diags.Count - 1 do
      begin
        if j > 0 then Result := Result + ' | ';
        Result := Result + Format('%s/%s@%d:%d', [r.Files[i].Diags[j].Code,
          r.Files[i].Diags[j].Severity, r.Files[i].Diags[j].Line, r.Files[i].Diags[j].Column]);
      end;
      if Result = '' then Result := 'clean';
      Exit;
    end;
end;

procedure TestAnalysisPath;
var
  doc: string;
  set1, v: TStrMap;
  ctx: TSpxContext;
  r: TSpxReport;
  i: Integer;
begin
  { ── the fragment preview ── }

  { A selection renders in the document's scope: the macros are there even though the
    selection does not contain their definitions. }
  Check('fragment/sees-document-macros',
        SpxRenderFragment('#set %brand% = Акме'#10'всякий текст', '%brand% рулит',
                          SpxSeededContext('ru', nil, 1)), 'Акме рулит');

  { No directives in the document: the fragment is just itself. }
  Check('fragment/without-directives',
        SpxRenderFragment('обычный текст', 'кусок', SpxSeededContext('ru', nil, 1)), 'Кусок');

  { A `#set` inside a block comment is not a directive, and the prelude comes from the
    engine's list rather than a scan of ours -- so it cannot leak into scope. This is the
    whole reason SpExtractDirectives exists on this path. }
  Check('fragment/ignores-commented-out-directive',
        SpxRenderFragment('/#'#10'#set %x% = A'#10'#/', '[%x%]',
                          SpxSeededContext('ru', nil, 1)), '%x%');

  { Source order is preserved where it is OBSERVABLE. A #def chain would not prove it --
    the engine rolls definitions in dependency order, so it renders the same either way --
    but a redefinition does: the last `#set` of a name wins, so a reversed prelude would
    render '1' here. }
  Check('fragment/prelude-keeps-source-order',
        SpxRenderFragment('#set %a% = 1'#10'#set %a% = 2', '%a%',
                          SpxSeededContext('ru', nil, 1)), '2');

  { A CRLF document produces the same fragment as an LF one. This guards THIS layer's use of
    `TSpDirective.Text` (the line without its terminator), not the engine -- the engine's own
    CRLF fix is pinned in the baseline group. }
  Check('fragment/prelude-survives-crlf',
        SpxRenderFragment('#set %brand% = Акме'#13#10'текст', '%brand% рулит',
                          SpxSeededContext('ru', nil, 1)), 'Акме рулит');

  { The other half of "document scope": the runtime context reaches the fragment too. }
  v := Vars(['brand', 'Акме']);
  try
    Check('fragment/carries-the-runtime-context',
          SpxRenderFragment('всякий текст', '%brand%', SpxSeededContext('ru', v, 1)), 'Акме');
  finally
    v.Free;
  end;

  { The fragment renders with the same context, so an include inside it resolves too. }
  set1 := Vars(['frag', 'кусок фрагмента']);
  try
    Check('fragment/resolves-includes',
          SpxRenderFragment('#set %x% = 1', '#include "frag"',
                            SpxSeededContext('ru', nil, 1, set1)), 'Кусок фрагмента');
  finally
    set1.Free;
  end;

  { ── the panel model ── }

  doc := '#set %brand% = Акме'#10'#def %greet% = Привет'#10'%brand%, %greet%, %missing%';
  Check('model/macros-carry-value-and-position', ModelVars(doc, SpxContext('ru', nil)),
        'set:brand=Акме@1:1 | def:greet=Привет@2:1 | runtime:missing=@0:0');

  { A runtime value the user typed shows up against the reference, whatever case the key
    was entered in. }
  v := Vars(['MISSING', 'заполнено']);
  try
    Check('model/runtime-value-from-the-context',
          ModelVars('%missing%', SpxContext('ru', v)), 'runtime:missing=заполнено@0:0');
  finally
    v.Free;
  end;

  { engine v0.3.1/v0.3.2 narrowed the directive-value trim to the reference's, and Studio
    shows the result in two places: this panel and the right pane. A trailing NUL is part of
    the value now (it was trimmed away before), so the panel must not "clean" it -- that
    would be the same drift from our side. }
  Check('model/value-is-trimmed-the-reference-way',
        ModelVars('#set %x% = A'#0, SpxContext('ru', nil)), 'set:x=A'#0'@1:1');

  { Duplicate definitions stay two rows: the engine calls that definition.duplicate-name,
    and a panel that showed one row would hide half the error. }
  Check('model/duplicate-definitions-kept',
        ModelVars('#set %x% = 1'#10'#set %x% = 2', SpxContext('ru', nil)),
        'set:x=1@1:1 | set:x=2@2:1');

  set1 := Vars(['frag', 'текст']);
  try
    Check('model/includes-marked-known-and-unknown',
          ModelIncludes('#include "frag"'#10'#include "missing"', SpxContext('ru', nil, set1)),
          'frag(known)@1:1 | missing(unknown)@2:1');
  finally
    set1.Free;
  end;

  { ── the health report ── }

  r := SpxHealthReport('просто текст', SpxContext('ru', nil), 3);
  try
    CheckTrue('health/clean-document-is-valid', r.IsValid);
    Check('health/clean-document-has-no-diags', ReportOf(r, ''), 'clean');
    CheckTrue('health/probe-count', r.Probes = 3);
  finally
    r.Free;
  end;

  r := SpxHealthReport('текст]', SpxContext('ru', nil), 1);
  try
    CheckTrue('health/error-makes-it-invalid', not r.IsValid);
    Check('health/error-is-filed-under-the-document', ReportOf(r, ''),
          'bracket.unexpected-closing/error@1:6');
  finally
    r.Free;
  end;

  { THE closure contract: a broken fragment must not leave the document green, and its
    diagnostic must arrive in the FRAGMENT's coordinates, filed under the fragment. }
  set1 := Vars(['frag', 'первая строка'#10'вторая {a|b']);
  try
    r := SpxHealthReport('#include "frag"', SpxContext('ru', nil, set1), 1);
    try
      CheckTrue('health/broken-fragment-invalidates-the-document', not r.IsValid);
      Check('health/document-itself-is-clean', ReportOf(r, ''), 'clean');
      Check('health/fragment-diag-in-its-own-coordinates', ReportOf(r, 'frag'),
            'bracket.unclosed/error@2:8');
      CheckTrue('health/closure-has-both-files', r.Files.Count = 2);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { A child does not inherit the parent's macros, so a fragment leaning on one is warned
    about -- passing the parent's names down would have silenced a warning that is true. }
  set1 := Vars(['frag', '%brand% внутри']);
  try
    r := SpxHealthReport('#set %brand% = Акме'#10'#include "frag"',
                         SpxContext('ru', nil, set1), 1);
    try
      Check('health/child-does-not-inherit-parent-macros', ReportOf(r, 'frag'),
            'variable.undefined/warning@1:1');
      CheckTrue('health/warning-is-not-an-error', r.IsValid);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { An unknown target is the engine's error, reported against the set's slugs... }
  set1 := Vars(['frag', 'текст']);
  try
    r := SpxHealthReport('#include "nope"', SpxContext('ru', nil, set1), 1);
    try
      Check('health/unknown-target-is-an-error', ReportOf(r, ''),
            'include.unknown-target/error@1:11');
    finally
      r.Free;
    end;

    { ...and when the miss is only in case, Studio adds what the engine cannot know. The
      note carries the file and the position, so the panel can jump to it. }
    r := SpxHealthReport('#include "Frag"', SpxContext('ru', nil, set1), 1);
    try
      Check('health/case-mismatch-note', NotesOf(r), 'case-mismatch:Frag->frag@:1:1');
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { The hint has to fold Unicode, not just A..Z: this product's fragments will be named in
    Russian, and an ASCII fold is dead exactly there. }
  set1 := Vars(['Вступление', 'текст']);
  try
    r := SpxHealthReport('#include "вступление"', SpxContext('ru', nil, set1), 1);
    try
      Check('health/case-mismatch-note-folds-cyrillic', NotesOf(r),
            'case-mismatch:вступление->Вступление@:1:1');
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { An EMPTY set is the one state where the engine stays silent -- SpValidate only reports
    unknown targets when it was given a non-empty slug list -- so Studio says it instead. }
  set1 := TStrMap.Create;
  try
    r := SpxHealthReport('#include "nope"', SpxContext('ru', nil, set1), 1);
    try
      Check('health/unknown-target-noted-when-the-set-is-empty', NotesOf(r),
            'unknown-target:nope@:1:1');
      Check('health/empty-set-leaves-the-engine-silent', ReportOf(r, ''), 'clean');
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { A cycle is a render-time guard, not a verdict: the engine unwinds it to empty and calls
    the template valid. Studio still says so, because a silently empty fragment is worse. }
  set1 := Vars(['a', 'A'#10'#include "b"', 'b', 'B'#10'#include "a"']);
  try
    r := SpxHealthReport('#include "a"', SpxContext('ru', nil, set1), 1);
    try
      Check('health/cycle-is-noted-where-it-closes', NotesOf(r), 'cycle:a@b:2:1');
      CheckTrue('health/cycle-is-not-an-error', r.IsValid);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { A target that differs only in case is NOT the same file, so it is not a cycle either --
    the engine compares exactly, and so must the walk. With a case-insensitive IndexOf this
    reports a cycle that does not exist AND swallows the hint that explains the miss. }
  set1 := Vars(['intro', 'Привет'#10'#include "Intro"']);
  try
    r := SpxHealthReport('#include "intro"', SpxContext('ru', nil, set1), 1);
    try
      Check('closure/case-differing-target-is-not-a-cycle', NotesOf(r),
            'case-mismatch:Intro->intro@intro:2:1');
      CheckTrue('closure/both-files-validated', r.Files.Count = 2);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { Two aliases of one text are two slugs; neither is a cycle (engine ADR 0004). }
  set1 := Vars(['x', 'X', 'y', 'X']);
  try
    r := SpxHealthReport('#include "x"'#10'#include "y"', SpxContext('ru', nil, set1), 1);
    try
      Check('closure/aliases-are-not-a-cycle', NotesOf(r), '<none>');
      CheckTrue('closure/aliases-are-two-files', r.Files.Count = 3);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { A diamond -- one fragment reached from two places -- is validated once. }
  set1 := Vars(['a', 'A'#10'#include "c"', 'b', 'B'#10'#include "c"', 'c', 'C']);
  try
    r := SpxHealthReport('#include "a"'#10'#include "b"', SpxContext('ru', nil, set1), 1);
    try
      CheckTrue('closure/diamond-validates-the-shared-file-once', r.Files.Count = 4);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { The depth cap counts the include stack only, and matches the engine's 20: the document
    plus twenty files are validated, and the twenty-first link is noted, not followed. }
  set1 := TStrMap.Create;
  try
    for i := 1 to 25 do
      set1.AddOrSetValue('t' + IntToStr(i), 'T' + IntToStr(i) + #10'#include "t' +
                         IntToStr(i + 1) + '"');
    r := SpxHealthReport('#include "t1"', SpxContext('ru', nil, set1), 1);
    try
      CheckTrue('closure/depth-cap-stops-at-twenty', r.Files.Count = 21);
      Check('closure/depth-cap-is-noted', NotesOf(r), 'too-deep:t21@t20:2:1');
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { The document is normally a member of its own folder's set. Told its own slug, the walk
    validates its text once; without that it walks back into itself and counts one broken
    bracket as two errors in two files. }
  set1 := Vars(['main', 'текст]'#10'#include "main"']);
  try
    r := SpxHealthReport('текст]'#10'#include "main"', SpxContext('ru', nil, set1), 1, 'main');
    try
      CheckTrue('health/own-slug-is-not-walked-again', r.Files.Count = 1);
      CheckTrue('health/own-error-counted-once', r.Errors = 1);
    finally
      r.Free;
    end;
    r := SpxHealthReport('текст]'#10'#include "main"', SpxContext('ru', nil, set1), 1);
    try
      CheckTrue('health/without-its-slug-the-document-is-seen-twice', r.Errors = 2);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { ...but the skip is only right when the set's copy IS the buffer. With unsaved edits the
    two differ, and it is the SAVED text the engine renders for an `#include` -- so it still
    has to be validated, under its own slug. Skipping by slug alone would hide a broken
    bracket that the preview is showing. }
  set1 := Vars(['main', 'сохранено]']);
  try
    r := SpxHealthReport('буфер'#10'#include "main"', SpxContext('ru', nil, set1), 1, 'main');
    try
      CheckTrue('health/unsaved-buffer-still-validates-the-saved-copy', r.Files.Count = 2);
      Check('health/saved-copy-diag-is-filed-under-its-slug', ReportOf(r, 'main'),
            'bracket.unexpected-closing/error@1:10');
      CheckTrue('health/saved-copy-error-counted-once', r.Errors = 1);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { Two slugs differing only in case are two files. A case-insensitive `visited` would
    validate the first and silently skip the second -- the same defect as the false cycle,
    wearing different clothes. }
  set1 := Vars(['intro', 'A]', 'Intro', 'B]']);
  try
    r := SpxHealthReport('#include "intro"'#10'#include "Intro"',
                         SpxContext('ru', nil, set1), 1);
    try
      CheckTrue('closure/case-differing-slugs-are-two-files', r.Files.Count = 3);
      CheckTrue('closure/case-differing-slugs-both-validated', r.Errors = 2);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { Two occurrences of one bad target are two notes: the panel points at both lines, and a
    note keyed only on its text would have collapsed them. }
  set1 := Vars(['frag', 'текст']);
  try
    r := SpxHealthReport('#include "Frag"'#10'#include "Frag"',
                         SpxContext('ru', nil, set1), 1);
    try
      Check('health/repeated-note-keeps-both-positions', NotesOf(r),
            'case-mismatch:Frag->frag@:1:1 | case-mismatch:Frag->frag@:2:1');
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  { A raw reserved sentinel in author markup makes the panel and the preview disagree, and
    the engine cannot warn about it because it deletes them before parsing (spec §7). }
  r := SpxHealthReport('текст' + Sentinel0 + 'ещё', SpxContext('ru', nil), 1);
  try
    Check('health/raw-sentinel-is-noted', NotesOf(r), 'raw-sentinel:@:0:0');
  finally
    r.Free;
  end;

  { The document's locale reaches every file in the closure: three plural forms are an error
    under 'en' and correct under 'ru'. }
  set1 := Vars(['frag', '{plural %n%: товар|товара|товаров}']);
  v := Vars(['n', '2']);
  try
    r := SpxHealthReport('#include "frag"', SpxContext('en', v, set1), 1);
    try
      Check('health/locale-reaches-the-child', ReportOf(r, 'frag'), 'plural.arity/error@1:1');
    finally
      r.Free;
    end;
    r := SpxHealthReport('#include "frag"', SpxContext('ru', v, set1), 1);
    try
      Check('health/child-is-clean-under-its-locale', ReportOf(r, 'frag'), 'clean');
    finally
      r.Free;
    end;
  finally
    set1.Free; v.Free;
  end;

  { Health flags: variability, emptiness, and the fullwidth fallback that marks a block the
    engine could not render. }
  ctx := SpxContext('ru', nil);
  r := SpxHealthReport('вариант: {a|b|c|d|e|f}', ctx, 8);
  try
    CheckTrue('health/variability-is-measured', r.DistinctProbes > 1);
    CheckTrue('health/no-empty-probes', r.EmptyProbes = 0);
    CheckTrue('health/no-fullwidth-fallback', not r.FullwidthFallback);
  finally
    r.Free;
  end;

  { A document with one possible output reports exactly one -- without this, `DistinctProbes
    := Probes` would pass the check above and the variability flag would be decoration. }
  r := SpxHealthReport('ровно один вариант', ctx, 6);
  try
    CheckTrue('health/constant-document-has-one-distinct-render', r.DistinctProbes = 1);
  finally
    r.Free;
  end;

  { Two outputs that differ only in case are two outputs. A sorted TStringList compares
    case-insensitively unless told otherwise, and would report a varying document as flat. }
  r := SpxHealthReport('x {AA|aa}', ctx, 12);
  try
    CheckTrue('health/case-only-variation-still-counts', r.DistinctProbes = 2);
  finally
    r.Free;
  end;

  { The counts the status bar shows -- "N ошибок" -- are counted over the closure, so they
    need pinning as numbers, not only through IsValid. }
  set1 := Vars(['frag', '%undefined1% %undefined2%']);
  try
    r := SpxHealthReport('текст] %undefined3%'#10'#include "frag"',
                         SpxContext('ru', nil, set1), 1);
    try
      CheckTrue('health/errors-are-counted-over-the-closure', r.Errors = 1);
      CheckTrue('health/warnings-are-counted-over-the-closure', r.Warnings = 3);
    finally
      r.Free;
    end;
  finally
    set1.Free;
  end;

  r := SpxHealthReport('', ctx, 2);
  try
    CheckTrue('health/empty-render-is-counted', r.EmptyProbes = 2);
  finally
    r.Free;
  end;

  { 'en' takes two plural forms; three is malformed, and the engine emits fullwidth braces
    rather than throwing. That is the signal a status bar should surface even though the
    verdict is only a warning. }
  v := Vars(['n', '2']);
  try
    r := SpxHealthReport('{plural %n%: a|b|c}', SpxContext('en', v), 2);
    try
      CheckTrue('health/fullwidth-fallback-is-flagged', r.FullwidthFallback);
    finally
      r.Free;
    end;
  finally
    v.Free;
  end;
end;

{ ── 6. the tokenizer the editor colours by ───────────────────────────────── }

function Scan(const line: string; var st: TSpxScanState): string;
const KIND: array[TSpxTokenKind] of string =
  ('text', 'comment', 'dir', 'str', 'var', '{', '}', '[', ']', '|', 'cond', 'plural', 'cfg',
   'tsep');
var toks: TSpxTokenList; i: Integer;
begin
  toks := TSpxTokenList.Create;
  try
    SpxScanLine(line, st, toks);
    Result := '';
    for i := 0 to toks.Count - 1 do
    begin
      if i > 0 then Result := Result + ' ';
      Result := Result + Format('%s(%s)%d', [KIND[toks[i].Kind],
        Copy(line, toks[i].Start, toks[i].Length), toks[i].Depth]);
    end;
    if Result = '' then Result := '<none>';
  finally
    toks.Free;
  end;
end;

function ScanOne(const line: string): string;
var st: TSpxScanState;
begin
  st := Default(TSpxScanState);
  st.LineEmpty := True;
  Result := Scan(line, st);
end;

{ Every token must butt against the previous one, the first must start at 1, and the last
  must end at the end of the line. SynEdit paints exactly what it is handed: a gap leaves
  text unpainted and an overlap corrupts the run beside it, and neither shows up in a check
  that only compares kinds. }
function Tiles(const line: string): Boolean;
var st: TSpxScanState; toks: TSpxTokenList; i, expect: Integer;
begin
  st := Default(TSpxScanState);
  st.LineEmpty := True;
  toks := TSpxTokenList.Create;
  try
    SpxScanLine(line, st, toks);
    Result := True;
    expect := 1;
    for i := 0 to toks.Count - 1 do
    begin
      if (toks[i].Start <> expect) or (toks[i].Length <= 0) then Exit(False);
      expect := toks[i].Start + toks[i].Length;
    end;
    Result := expect = Length(line) + 1;
  finally
    toks.Free;
  end;
end;

procedure TestTokenizer;
var
  st: TSpxScanState;
  toks: TSpxTokenList;
  lines: TStringList;
  i: Integer;
  deep: string;
  seenKinds: set of TSpxTokenKind;
begin
  { The classes the family's own grammar colours, one line each. }
  Check('scan/plain-text', ScanOne('Привет, мир'), 'text(Привет, мир)0');
  Check('scan/enumeration', ScanOne('{a|b}'), '{({)1 text(a)1 |(|)1 text(b)1 }(})1');
  Check('scan/variable', ScanOne('%brand% рулит'), 'var(%brand%)0 text( рулит)0');
  Check('scan/not-a-variable', ScanOne('50% скидка'), 'text(50% скидка)0');
  Check('scan/directive-set', ScanOne('#set %x% = {a|b}'),
        'dir(#set)0 text( )0 var(%x%)0 text( = )0 {({)1 text(a)1 |(|)1 text(b)1 }(})1');
  Check('scan/directive-include', ScanOne('#include "frag"'),
        'dir(#include)0 text( )0 str("frag")0');
  Check('scan/conditional', ScanOne('{?ai?да|нет}'),
        '{({)1 cond(?ai?)1 text(да)1 |(|)1 text(нет)1 }(})1');
  Check('scan/negated-conditional', ScanOne('{?!ai?нет}'),
        '{({)1 cond(?!ai?)1 text(нет)1 }(})1');
  Check('scan/plural', ScanOne('{plural %n%: товар|товара}'),
        '{({)1 plural(plural %n%:)1 text( товар)1 |(|)1 text(товара)1 }(})1');
  Check('scan/permutation-with-config', ScanOne('[<minsize=2;sep=", ">a|b]'),
        '[([)1 cfg(<minsize=2;sep=", ">)1 text(a)1 |(|)1 text(b)1 ](])1');
  Check('scan/inline-comment', ScanOne('до /# заметка #/ после'),
        'text(до )0 comment(/# заметка #/)0 text( после)0');

  { Nesting is a number, not a stack -- which is exactly why unbounded depth is not a
    problem for a line-at-a-time highlighter (ADR 0002's open risk). }
  Check('scan/nesting-depth', ScanOne('{a{b}c}'),
        '{({)1 text(a)1 {({)2 text(b)2 }(})2 text(c)1 }(})1');

  { State crosses lines: a comment stays open... }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Check('scan/comment-opens', Scan('до /# начало', st), 'text(до )0 comment(/# начало)0');
  CheckTrue('scan/comment-state-carries', st.InComment);
  Check('scan/comment-continues', Scan('всё ещё внутри', st), 'comment(всё ещё внутри)0');
  Check('scan/comment-closes', Scan('конец #/ хвост', st),
        'comment(конец #/)0 text( хвост)0');
  CheckTrue('scan/comment-state-cleared', not st.InComment);

  { ...and so does depth, which is what makes a multi-line template colour correctly. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('{первая', st);
  CheckTrue('scan/depth-carries-to-the-next-line', st.Depth = 1);
  Check('scan/close-on-a-later-line', Scan('вторая}', st), 'text(вторая)1 }(})1');
  CheckTrue('scan/depth-returns-to-zero', st.Depth = 0);

  { A closer with nothing open is drawn, not diagnosed: this scan has no opinion about
    validity, which belongs to SpValidate (spec §4.1). }
  Check('scan/unmatched-close-is-just-a-brace', ScanOne('}'), '}(})0');

  { A directive is anchored to the LOGICAL line -- what survives comment removal -- which is
    how the engine anchors it. Both halves matter, and each was wrong once:
      * text before the comment means the #set is NOT a directive (the engine renders it
        literally and never defines the macro), and colouring it bold would confirm a
        definition that does not exist;
      * a comment that opened at the very start IS transparent, and the #set after it is a
        real directive. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('до /# начало', st);
  Check('scan/set-after-text-and-comment-is-not-a-directive',
        Scan('конец #/ #set %x% = 1', st),
        'comment(конец #/)0 text( #set )0 var(%x%)0 text( = 1)0');
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('/# начало', st);
  Check('scan/set-after-only-a-comment-is-a-directive',
        Scan('конец #/ #set %x% = 1', st),
        'comment(конец #/)0 text( )0 dir(#set)0 text( )0 var(%x%)0 text( = 1)0');

  { The same rule when the comment OPENS AND CLOSES on the directive's own line. This one
    was missed: the anchor was tried once, before the scan, so a line beginning with a
    comment never got a second look and a real directive was drawn as text. Both cases were
    measured against SpExtractDirectives -- the engine reports set(x) for each. }
  Check('scan/set-after-a-comment-on-the-same-line',
        ScanOne('/# c #/#set %x% = 1'),
        'comment(/# c #/)0 dir(#set)0 text( )0 var(%x%)0 text( = 1)0');
  Check('scan/set-after-an-indented-comment-on-the-same-line',
        ScanOne('  /# c #/ #set %x% = 1'),
        'text(  )0 comment(/# c #/)0 text( )0 dir(#set)0 text( )0 var(%x%)0 text( = 1)0');
  { And the half that must NOT move: text first, and the engine defines nothing. }
  Check('scan/set-after-text-and-a-comment-on-one-line-is-text',
        ScanOne('текст /# c #/#set %x% = 1'),
        'text(текст )0 comment(/# c #/)0 text(#set )0 var(%x%)0 text( = 1)0');

  { The include anchor's gap is `[ \t\n\r\f\x0B]+`, wider than anywhere else in the
    language. Measured: the engine resolves all four same-line members. }
  Check('scan/include-gap-vertical-tab', ScanOne('#include'#11'"frag"'),
        'dir(#include)0 text('#11')0 str("frag")0');
  Check('scan/include-gap-form-feed', ScanOne('#include'#12'"frag"'),
        'dir(#include)0 text('#12')0 str("frag")0');
  { The newline members of that same class are the unit's ONE known gap: the engine reads
    this as include(frag), and the scanner deliberately leaves it plain rather than paint a
    keyword before knowing whether a target ever follows. Pinned so the boundary is visible
    and cannot move by accident. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Check('scan/include-target-on-the-next-line-is-a-known-gap',
        Scan('#include', st), 'text(#include)0');

  { The wide gap belongs to #include alone. For #set/#def the engine rejects a vertical tab
    outright -- measured, it reports no directive -- so the colouring must not be generous
    here either. }
  Check('scan/set-gap-stays-space-or-tab', ScanOne('#set'#11'%x% = 1'),
        'text(#set'#11')0 var(%x%)0 text( = 1)0');

  { A keyword alone is not a directive: `#set brand = Acme` (no percent signs) is literal
    text to the engine, and it is the likeliest directive typo there is. }
  Check('scan/set-without-a-macro-name-is-text', ScanOne('#set brand = Акме'),
        'text(#set brand = Акме)0');
  Check('scan/set-without-an-equals-is-text', ScanOne('#set %x% Акме'),
        'text(#set )0 var(%x%)0 text( Акме)0');

  { A digit-leading or empty conditional name is not a conditional -- the engine falls
    through to an enumeration, and so must the colouring. }
  Check('scan/digit-leading-conditional-is-an-enumeration', ScanOne('{?1x?да|нет}'),
        '{({)1 text(?1x?да)1 |(|)1 text(нет)1 }(})1');
  Check('scan/empty-conditional-name-is-an-enumeration', ScanOne('{??да}'),
        '{({)1 text(??да)1 }(})1');

  { The per-element trailing separator: `<...>` ending a permutation element, which the
    engine takes as the separator placed before the NEXT element. Every case below was
    rendered through the engine first -- the rule is subtle enough that reading the grammar
    would not have settled it. }
  Check('scan/trailing-separator', ScanOne('[a<br>|b]'),
        '[([)1 text(a)1 tsep(<br>)1 |(|)1 text(b)1 ](])1');
  Check('scan/one-letter-is-still-a-separator', ScanOne('[a<b>|b]'),
        '[([)1 text(a)1 tsep(<b>)1 |(|)1 text(b)1 ](])1');
  Check('scan/punctuation-is-a-separator', ScanOne('[a<, >|b]'),
        '[([)1 text(a)1 tsep(<, >)1 |(|)1 text(b)1 ](])1');
  { The HTML guard, all three of its branches: a leading slash, a trailing slash, and a tag
    name followed by whitespace. The engine renders each of these as text. }
  Check('scan/self-closing-tag-is-text', ScanOne('[a<br/>|b]'),
        '[([)1 text(a<br/>)1 |(|)1 text(b)1 ](])1');
  Check('scan/spaced-self-closing-is-text', ScanOne('[a<br />|b]'),
        '[([)1 text(a<br />)1 |(|)1 text(b)1 ](])1');
  Check('scan/closing-tag-is-text', ScanOne('[a</b>|b]'),
        '[([)1 text(a</b>)1 |(|)1 text(b)1 ](])1');
  Check('scan/tag-with-an-attribute-is-text', ScanOne('[a<span class="x">|b]'),
        '[([)1 text(a<span class="x">)1 |(|)1 text(b)1 ](])1');
  { Position decides as much as shape: before the closing bracket it belongs to the LAST
    element and stays text; only the last one in an element is the separator; and inside a
    brace group the pipe is not a permutation boundary at all. }
  Check('scan/before-the-close-is-text', ScanOne('[a|b<br>]'),
        '[([)1 text(a)1 |(|)1 text(b<br>)1 ](])1');
  Check('scan/only-the-last-tag-in-an-element', ScanOne('[a<b>c<br>|d]'),
        '[([)1 text(a<b>c)1 tsep(<br>)1 |(|)1 text(d)1 ](])1');
  Check('scan/inside-a-brace-group-is-text', ScanOne('[{x<br>|y}|d]'),
        '[([)1 {({)2 text(x<br>)2 |(|)2 text(y)2 }(})2 |(|)1 text(d)1 ](])1');
  Check('scan/blanks-before-the-pipe', ScanOne('[a<br>  |b]'),
        '[([)1 text(a)1 tsep(<br>)1 text(  )1 |(|)1 text(b)1 ](])1');

  { STRUCTURE INSIDE THE CANDIDATE. The engine cuts a permutation into parts first --
    SplitTopLevel, signed brace and bracket counters, a split only where both are zero -- and
    looks for a trailing separator afterwards. So a candidate that swallows a top-level `|`,
    or the `]` that actually closes the permutation, is not a separator at all: the part
    ended before it. Painting one would claim a construct the engine does not see AND hide
    the characters carrying the structure -- in `[A<]>|B]` the bracket matcher still pairs
    that `]` with the opening one, so the two halves of the editor would disagree on one
    screen. Every line here was rendered through the engine first. }
  CheckTrue('scan/a-top-level-pipe-inside-is-not-a-separator',
            Pos('tsep(', ScanOne('[a< | >|b]')) = 0);
  CheckTrue('scan/the-closing-bracket-inside-is-not-a-separator',
            Pos('tsep(', ScanOne('[A<]>|B]')) = 0);
  CheckTrue('scan/an-unclosed-bracket-inside', Pos('tsep(', ScanOne('[A<[>|B]')) = 0);
  CheckTrue('scan/an-unmatched-brace-inside', Pos('tsep(', ScanOne('[A<}s>|B]')) = 0);
  CheckTrue('scan/an-unclosed-brace-inside', Pos('tsep(', ScanOne('[A<s{r>|B]')) = 0);
  { The permutation ended at that `]`, so what follows is outside it. }
  CheckTrue('scan/after-the-permutation-already-closed',
            Pos('tsep(', ScanOne('[A{B]C<br>|D]')) = 0);

  { The `<` guard is what makes a forward scan reproduce the engine's backward one: the
    separator is the LAST `<...>` of the element. }
  Check('scan/only-the-last-open-angle-counts', ScanOne('[a<x<br>|c]'),
        '[([)1 text(a<x)1 tsep(<br>)1 |(|)1 text(c)1 ](])1');
  { An empty one is still a separator to the engine -- an empty separator. }
  Check('scan/an-empty-separator', ScanOne('[A<>|B]'),
        '[([)1 text(A)1 tsep(<>)1 |(|)1 text(B)1 ](])1');
  { A tag name must START with a letter for the HTML guard to fire. }
  Check('scan/a-digit-first-is-not-a-tag-name', ScanOne('[a<1 x>|b]'),
        '[([)1 text(a)1 tsep(<1 x>)1 |(|)1 text(b)1 ](])1');
  { The blanks before the pipe are the engine's rtrim class: tab and vertical tab count. }
  Check('scan/a-tab-before-the-pipe', ScanOne('[a<br>'#9'|b]'),
        '[([)1 text(a)1 tsep(<br>)1 text('#9')1 |(|)1 text(b)1 ](])1');
  Check('scan/a-vertical-tab-before-the-pipe', ScanOne('[a<br>'#11'|b]'),
        '[([)1 text(a)1 tsep(<br>)1 text('#11')1 |(|)1 text(b)1 ](])1');
  { And a brace group that CLOSES before the separator leaves the split level where it was,
    so the separator after it is real. }
  Check('scan/after-a-closed-brace-group', ScanOne('[{x|y}<br>|d]'),
        '[([)1 {({)2 text(x)2 |(|)2 text(y)2 }(})2 tsep(<br>)1 |(|)1 text(d)1 ](])1');

  { The known gap, pinned so it cannot move by accident: the kinds of open brackets are
    tracked for one line only -- what crosses a line is a depth, which is what makes deep
    nesting free -- so a permutation opened earlier does not colour its separators. A
    missing colour, never a wrong one. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('[a', st);
  Check('scan/a-permutation-opened-on-an-earlier-line-is-a-known-gap',
        Scan('<br>|b]', st), 'text(<br>)1 |(|)1 text(b)1 ](])1');

  { The engine left-trims a permutation config, so a space before it does not turn it off
    and must not turn the colour off either. }
  Check('scan/config-after-a-space', ScanOne('[ <minsize=2>a|b]'),
        '[([)1 text( )1 cfg(<minsize=2>)1 text(a)1 |(|)1 text(b)1 ](])1');

  { The config/content boundary, ported from the engine's v0.3.3 gate. Each of these was
    measured against that engine first: colouring a user's HTML as configuration, or their
    configuration as HTML, is the one thing this class must not do.

    CONTENT -- a leading HTML start tag stays in the permutation's text: }
  Check('scan/html-pair-is-not-config', ScanOne('[<li>a</li>|<li>b</li>]'),
        '[([)1 text(<li>a</li>)1 |(|)1 text(<li>b</li>)1 ](])1');
  Check('scan/self-closing-tag-is-not-config', ScanOne('[<br/>a|b]'),
        '[([)1 text(<br/>a)1 |(|)1 text(b)1 ](])1');
  Check('scan/tag-with-attributes-is-not-config', ScanOne('[<a href="x">one</a>|two]'),
        '[([)1 text(<a href="x">one</a>)1 |(|)1 text(two)1 ](])1');

  { CONFIG -- the key form, the single-separator form, and the two traps the engine's own
    review found: a word that merely CONTAINS a key, and a key with a prefix. }
  Check('scan/word-separator-is-config', ScanOne('[<separator>a|b]'),
        '[([)1 cfg(<separator>)1 text(a)1 |(|)1 text(b)1 ](])1');
  Check('scan/prefixed-key-is-a-separator-not-a-key', ScanOne('[<xminsize=2>a|b]'),
        '[([)1 cfg(<xminsize=2>)1 text(a)1 |(|)1 text(b)1 ](])1');
  { A tag whose partner never comes is a separator, not markup -- the engine renders `li`
    between the options. }
  Check('scan/unpaired-tag-is-config', ScanOne('[<li>a|b]'),
        '[([)1 cfg(<li>)1 text(a)1 |(|)1 text(b)1 ](])1');
  { The closing `>` is found respecting quotes, so a separator may contain one. }
  Check('scan/quoted-gt-inside-config', ScanOne('[<sep="a>b">x|y]'),
        '[([)1 cfg(<sep="a>b">)1 text(x)1 |(|)1 text(y)1 ](])1');

  { Tokens must tile the line exactly: SynEdit paints what it is handed, so a gap leaves
    text unpainted and an overlap corrupts its neighbour. Neither shows up in a check that
    only compares kinds. }
  CheckTrue('scan/tiles-plain', Tiles('обычный текст'));
  CheckTrue('scan/tiles-markup', Tiles('{a|b} [<minsize=2>c|d] %v% /# c #/ }'));
  CheckTrue('scan/tiles-directive', Tiles('#set %x% = {a|b}'));
  CheckTrue('scan/tiles-include', Tiles('#include "frag"'));
  CheckTrue('scan/tiles-unterminated-quote', Tiles('#include "frag'));
  CheckTrue('scan/tiles-empty-line', Tiles(''));
  CheckTrue('scan/tiles-crlf-remnant', Tiles('текст'#13));

  { Depth is capped so it can ride in SynEdit's range pointer; three hundred levels must
    neither crash nor wrap. }
  deep := StringOfChar('{', 300);
  st := Default(TSpxScanState); st.LineEmpty := True;
  toks := TSpxTokenList.Create;
  try
    SpxScanLine(deep, st, toks);
    CheckTrue('scan/deep-nesting-is-capped', st.Depth = SPX_MAX_DEPTH);
    CheckTrue('scan/deep-nesting-emits-every-brace', toks.Count = 300);
    { ...and comes back down. An asymmetric Push/Pop only shows on the way out. }
    SpxScanLine(StringOfChar('}', 300), st, toks);
    CheckTrue('scan/deep-nesting-unwinds-to-zero', st.Depth = 0);
  finally
    toks.Free;
  end;

  { The state round-trips through the integer SynEdit hands back. }
  { Round-trip AT the cap: the depth mask and the flags used to share bits, so a deep nest
    turned the whole document into a comment. }
  st.InComment := True;
  st.LineEmpty := True;
  st.Depth := SPX_MAX_DEPTH;
  st := SpxUnpackState(SpxPackState(st));
  CheckTrue('scan/state-round-trips-at-the-cap',
            st.InComment and st.LineEmpty and (st.Depth = SPX_MAX_DEPTH));

  { The demo template, scanned line by line: a real document must come out BALANCED, with
    every brace and bracket closed and no comment left open. A tokenizer that miscounts
    would leave the rest of the file coloured as the inside of something. }
  lines := TStringList.Create;
  toks := TSpxTokenList.Create;
  try
    lines.Text := SpxDemoTemplate;
    st := Default(TSpxScanState);
    st.LineEmpty := True;
    for i := 0 to lines.Count - 1 do
      SpxScanLine(lines[i], st, toks);
    CheckTrue('demo/scan-ends-balanced', (st.Depth = 0) and (not st.InComment));
    CheckTrue('demo/scan-produced-tokens', toks.Count > lines.Count);

    { And it exercises what it claims to. Presence of each class, not a count: a threshold
      would be a number nobody can defend, while "the demo contains a conditional" is the
      actual claim. #include and a block comment are the two it has no reason to hold. }
    seenKinds := [];
    for i := 0 to toks.Count - 1 do
      Include(seenKinds, toks[i].Kind);
    CheckTrue('demo/covers-directives', sptDirective in seenKinds);
    CheckTrue('demo/covers-variables', sptVariable in seenKinds);
    CheckTrue('demo/covers-enumerations', sptBraceOpen in seenKinds);
    CheckTrue('demo/covers-permutations', sptBracketOpen in seenKinds);
    CheckTrue('demo/covers-options', sptPipe in seenKinds);
    CheckTrue('demo/covers-conditionals', sptCondHead in seenKinds);
    CheckTrue('demo/covers-plurals', sptPluralHead in seenKinds);
    CheckTrue('demo/covers-permutation-config', sptPermConfig in seenKinds);
  finally
    toks.Free;
    lines.Free;
  end;
end;

{ ── 6b. the bracket under the caret ─────────────────────────────────────── }

procedure TestBracketMatching;
const
  PAIRS = '{a|b} [c|d]';
var
  i, m: Integer;
  ok: Boolean;
  doc: string;
begin
  { Both directions, both kinds. }
  CheckTrue('bracket/open-brace-finds-its-close', SpxMatchBracket(PAIRS, 1) = 5);
  CheckTrue('bracket/close-brace-finds-its-open', SpxMatchBracket(PAIRS, 5) = 1);
  CheckTrue('bracket/open-bracket-finds-its-close', SpxMatchBracket(PAIRS, 7) = 11);
  CheckTrue('bracket/close-bracket-finds-its-open', SpxMatchBracket(PAIRS, 11) = 7);

  { Nesting: the inner pair, not the outer one. }
  CheckTrue('bracket/inner-pair', SpxMatchBracket('{a{b}c}', 3) = 5);
  CheckTrue('bracket/outer-pair', SpxMatchBracket('{a{b}c}', 1) = 7);

  { Across lines, because a template is not one line. }
  CheckTrue('bracket/across-lines', SpxMatchBracket('{a'#10'b}', 1) = 5);

  { What SynEdit's own matcher gets wrong, and why this function exists: a parenthesis and
    a quote are ordinary text in spintax, and a comment is not code. }
  CheckTrue('bracket/paren-is-not-a-bracket', SpxMatchBracket('(a|b)', 1) = 0);
  CheckTrue('bracket/quote-is-not-a-bracket', SpxMatchBracket('"a"', 1) = 0);
  CheckTrue('bracket/open-inside-a-comment-has-no-partner',
            SpxMatchBracket('/# { #/ }', 4) = 0);
  CheckTrue('bracket/close-outside-does-not-reach-into-a-comment',
            SpxMatchBracket('/# { #/ }', 9) = 0);
  CheckTrue('bracket/pair-inside-one-comment-is-still-no-pair',
            SpxMatchBracket('/# {a|b} #/', 4) = 0);

  { A mismatched kind is the validator's finding, not a pair to draw. }
  CheckTrue('bracket/mismatched-kinds-do-not-pair', SpxMatchBracket('{a]', 1) = 0);
  CheckTrue('bracket/unclosed-has-no-partner', SpxMatchBracket('{a', 1) = 0);
  CheckTrue('bracket/unopened-has-no-partner', SpxMatchBracket('a}', 2) = 0);

  { Anything that is not a bracket, and offsets outside the text. }
  CheckTrue('bracket/not-a-bracket', SpxMatchBracket(PAIRS, 2) = 0);
  CheckTrue('bracket/offset-past-the-end', SpxMatchBracket(PAIRS, 999) = 0);
  CheckTrue('bracket/offset-zero', SpxMatchBracket(PAIRS, 0) = 0);

  { The demo document: every bracket in it must find its partner, in both directions. That
    is a real template rather than a fixture, and it is where an off-by-one would show. }
  begin
    doc := SpxDemoTemplate;
    ok := True;
    for i := 1 to Length(doc) do
      if doc[i] in ['{', '}', '[', ']'] then
      begin
        m := SpxMatchBracket(doc, i);
        if (m = 0) or (SpxMatchBracket(doc, m) <> i) then ok := False;
      end;
    CheckTrue('bracket/every-pair-in-the-demo-round-trips', ok);
  end;
end;

{ ── 7. the demo template as a document ───────────────────────────────────── }

procedure TestDemoTemplate;
var
  r: TSpxReport;
  seen: TStringList;
  i: Integer;
begin
  { It must validate CLEAN. Every macro it references it defines, so a warning here means
    either the template drifted or this project misunderstands the language. }
  r := SpxHealthReport(SpxDemoTemplate, SpxContext('en', nil), 8);
  try
    CheckTrue('demo/validates-clean', r.IsValid);
    CheckTrue('demo/no-warnings', r.Warnings = 0);
    CheckTrue('demo/no-studio-notes', r.Notes.Count = 0);

    { It renders, it never renders empty, and it never falls back to the fullwidth braces
      the engine emits for a block it could not render. }
    CheckTrue('demo/renders-something', r.EmptyProbes = 0);
    CheckTrue('demo/no-fullwidth-fallback', not r.FullwidthFallback);

    { And it varies -- which is the whole point of the document. }
    CheckTrue('demo/varies-across-seeds', r.DistinctProbes = r.Probes);
  finally
    r.Free;
  end;

  { The same seed gives the same text: this is what the export promise rests on, checked
    here on a document with permutations, plurals and conditionals rather than on a two-
    option toy. }
  seen := TStringList.Create;
  try
    for i := 1 to 3 do
      seen.Add(SpxRenderSample(SpxDemoTemplate, SpxSeededContext('en', nil, 12345)));
    CheckTrue('demo/seeded-render-is-stable', (seen[0] = seen[1]) and (seen[1] = seen[2]));
    { Longer than the template's own prose minus its markup: proof it rendered rather
      than collapsed to a fragment. }
    CheckTrue('demo/render-is-substantial', Length(seen[0]) > Length(SpxDemoTemplate) div 2);
  finally
    seen.Free;
  end;
end;

{ ── 7b. diagnostics as spans the editor can underline ───────────────────── }

function MarksOf(const doc: string; const ctx: TSpxContext): string;
var r: TSpxReport; m: TSpxDiagMarks; i: Integer; sev: string;
begin
  Result := '';
  r := SpxHealthReport(doc, ctx, 0);
  try
    m := SpxDocumentMarks(r);
    for i := 0 to High(m) do
    begin
      if i > 0 then Result := Result + ' | ';
      if m[i].IsError then sev := 'err' else sev := 'warn';
      Result := Result + Format('%s:%s@%d:%d..%d:%d',
        [sev, m[i].Code, m[i].Line, m[i].Col, m[i].EndLine, m[i].EndCol]);
    end;
    if Result = '' then Result := '<none>';
  finally
    r.Free;
  end;
end;

procedure TestDiagMarks;
var
  set1: TStrMap;
  r: TSpxReport;
  diags: TSpDiagList;
  d: TSpDiag;
  m: TSpxDiagMarks;
begin
  { The engine's own span, unchanged: this layer reshapes, it never recomputes. }
  Check('marks/error-span', MarksOf('текст]', SpxContext('ru', nil)),
        'err:bracket.unexpected-closing@1:6..1:7');
  Check('marks/warning-span', MarksOf('%brand% рулит', SpxContext('ru', nil)),
        'warn:variable.undefined@1:1..1:8');
  Check('marks/clean-document', MarksOf('обычный текст', SpxContext('ru', nil)), '<none>');

  { A FRAGMENT's positions are coordinates in another buffer. Underlining them here would
    mark whatever text happens to sit at those numbers in the open document. }
  set1 := Vars(['frag', 'первая'#10'вторая {a|b']);
  try
    Check('marks/fragment-diagnostics-stay-out',
          MarksOf('#include "frag"', SpxContext('ru', nil, set1)), '<none>');
  finally
    set1.Free;
  end;

  { Two rules that need a hand-built report, because the engine rarely produces them:
    an unlocated diagnostic is panel-only, and a diagnostic without a span gets one
    character rather than a guess. }
  r := TSpxReport.Create;
  try
    diags := TSpDiagList.Create;
    d.Code := 'nowhere'; d.Severity := 'error';
    d.Line := 0; d.Column := 0; d.EndLine := 0; d.EndColumn := 0;
    diags.Add(d);
    d.Code := 'point'; d.Severity := 'warning';
    d.Line := 3; d.Column := 5; d.EndLine := 0; d.EndColumn := 0;
    diags.Add(d);
    r.Files.Add(TSpxFileReport.Create('', diags));

    m := SpxDocumentMarks(r);
    CheckTrue('marks/unlocated-diagnostic-is-not-drawn', Length(m) = 1);
    if Length(m) = 1 then
      Check('marks/spanless-diagnostic-gets-one-character',
            Format('%s@%d:%d..%d:%d', [m[0].Code, m[0].Line, m[0].Col, m[0].EndLine, m[0].EndCol]),
            'point@3:5..3:6');
  finally
    r.Free;
  end;
end;

{ ── 8. the engine thread (GUI layer, but the part that is logic) ─────────── }

type
  { Collects what the worker delivers. The form does the same thing with a status bar. }
  TThreadProbe = class
  public
    Delivered: Integer;
    LastId: Int64;
    Last: TSpxJobResult;
    { the batch's side }
    Steps: Integer;
    Dones: Integer;
    Ids: TStringList;
    LastDoneId: Int64;
    Kept: TSpxVariantList;
    BatchDone: Boolean;
    Cancelled: Boolean;
    Report: TSpxBatchReport;
    destructor Destroy; override;
    procedure Done(const Res: TSpxJobResult);
    procedure Batch(const P: TSpxBatchProgress);
  end;

destructor TThreadProbe.Destroy;
begin
  Kept.Free;
  Ids.Free;
  inherited Destroy;
end;

procedure TThreadProbe.Done(const Res: TSpxJobResult);
begin
  Inc(Delivered);
  LastId := Res.Id;
  Last := Res;
end;

{ The batch's side of the same worker: every step lands here, on the main thread. }
procedure TThreadProbe.Batch(const P: TSpxBatchProgress);
begin
  Inc(Steps);
  if Ids = nil then Ids := TStringList.Create;
  Ids.Add(IntToStr(P.Id));
  if P.Accepted then
  begin
    if Kept = nil then Kept := TSpxVariantList.Create;
    Kept.Add(P.Variant);
  end;
  if P.Done then
  begin
    Inc(Dones);
    BatchDone := True;
    LastDoneId := P.Id;
    Cancelled := P.Cancelled;
    Report := P.Report;
  end;
end;

{ Pump until the batch has delivered at least Want steps -- what "the batch is under way"
  has to mean before anything can be asserted about interleaving. }
function PumpSteps(probe: TThreadProbe; Want, timeoutMs: Integer): Boolean;
var waited: Integer;
begin
  waited := 0;
  while (probe.Steps < Want) and (waited < timeoutMs) do
  begin
    CheckSynchronize(10);
    Inc(waited, 10);
  end;
  Result := probe.Steps >= Want;
end;

{ Pump until the batch with this id has ended. Needed because replacing a running batch
  ends BOTH -- the first Done belongs to the batch that was displaced, and waiting on
  "any Done" reads its report instead of the one under test. }
function PumpDone(probe: TThreadProbe; wantId: Int64; timeoutMs: Integer): Boolean;
var waited: Integer;
begin
  waited := 0;
  while (probe.LastDoneId <> wantId) and (waited < timeoutMs) do
  begin
    CheckSynchronize(10);
    Inc(waited, 10);
  end;
  Result := probe.LastDoneId = wantId;
end;

{ Pump until the batch says it is finished, or give up. }
function PumpBatch(probe: TThreadProbe; timeoutMs: Integer): Boolean;
var waited: Integer;
begin
  waited := 0;
  while (not probe.BatchDone) and (waited < timeoutMs) do
  begin
    CheckSynchronize(10);
    Inc(waited, 10);
  end;
  Result := probe.BatchDone;
end;

{ Pump Synchronize until the worker has delivered `wantId`, or give up. A console program
  has no message loop, so the main thread has to run the queue itself -- CheckSynchronize is
  what the LCL does for the form. }
function PumpUntil(probe: TThreadProbe; wantId: Int64; timeoutMs: Integer): Boolean;
var waited: Integer;
begin
  waited := 0;
  while (probe.LastId < wantId) and (waited < timeoutMs) do
  begin
    CheckSynchronize(10);
    Inc(waited, 10);
  end;
  Result := probe.LastId >= wantId;
end;

procedure TestEngineThread;
var
  probe: TThreadProbe;
  th: TSpxEngineThread;
  job: TSpxJob;
  i: Integer;
begin
  probe := TThreadProbe.Create;
  th := TSpxEngineThread.Create(probe.Done);
  try
    { One job, one answer, and it is the same text the same context produces on this thread:
      the worker is a place to run the engine, not a second implementation of it. }
    job.Id := 1;
    job.Text := 'вариант: {a|b|c|d}';
    job.Locale := 'ru';
    job.Seeded := True;
    job.Seed := 42;
    th.Post(job);
    CheckTrue('thread/delivers-a-result', PumpUntil(probe, 1, 5000));
    Check('thread/result-matches-a-direct-render', probe.Last.Preview,
          SpxRenderSample(job.Text, SpxSeededContext('ru', nil, 42)));

    { The status bar's numbers come from the same worker. }
    job.Id := 2;
    job.Text := 'сломано]';
    th.Post(job);
    CheckTrue('thread/delivers-the-second', PumpUntil(probe, 2, 5000));
    CheckTrue('thread/reports-the-error-count', probe.Last.Errors = 1);

    { The variables panel's whole round trip, which nothing gated until a review pointed at
      it: a session value crosses into the job, becomes the context's Vars, and comes back
      as BOTH a substituted preview and a name the validator no longer calls undefined. }
    job.Id := 3;
    job.Text := '<p>%city%</p>';
    job.Vars := nil;
    th.Post(job);
    CheckTrue('thread/delivers-the-third', PumpUntil(probe, 3, 5000));
    CheckTrue('thread/an-unsupplied-name-is-a-warning', probe.Last.Warnings = 1);
    CheckTrue('thread/and-renders-verbatim', Pos('%city%', probe.Last.Preview) > 0);

    job.Id := 4;
    SetLength(job.Vars, 1);
    job.Vars[0].Name := 'city';
    job.Vars[0].Value := 'Тверь';
    th.Post(job);
    CheckTrue('thread/delivers-the-fourth', PumpUntil(probe, 4, 5000));
    CheckTrue('thread/a-session-value-silences-the-warning', probe.Last.Warnings = 0);
    CheckTrue('thread/and-is-substituted', Pos('Тверь', probe.Last.Preview) > 0);
    { And it comes back in the model the panel draws from. }
    CheckTrue('thread/the-model-comes-back', Length(probe.Last.Vars) = 1);
    if Length(probe.Last.Vars) = 1 then
      Check('thread/the-model-carries-the-session-value',
            probe.Last.Vars[0].Name + '=' + probe.Last.Vars[0].Value, 'city=Тверь');
    job.Vars := nil;

    { A SELECTION previews on its own, and two halves of that matter equally: the fragment
      renders in the DOCUMENT's scope -- so a macro defined outside it still expands -- while
      the verdict keeps describing the whole file. Selecting a clean paragraph does not make
      the broken bracket below it go away. }
    job.Id := 5;
    job.Text := '#set %greet% = Привет'#10'<p>%greet%, мир</p>'#10'сломано]';
    job.Fragment := '<p>%greet%, мир</p>';
    th.Post(job);
    CheckTrue('thread/delivers-the-fifth', PumpUntil(probe, 5, 5000));
    CheckTrue('thread/a-fragment-is-flagged-as-partial', probe.Last.Partial);
    CheckTrue('thread/the-fragment-sees-the-document-scope',
              Pos('Привет', probe.Last.Preview) > 0);
    { Without the first letter: post-process capitalises the opening word of a sentence, so
      the document's `сломано]` renders as `Сломано]` -- and a check written against the
      lower-case form would pass here for the wrong reason and fail below for the right one. }
    CheckTrue('thread/and-only-the-fragment-is-rendered',
              Pos('ломано', probe.Last.Preview) = 0);
    CheckTrue('thread/the-verdict-still-covers-the-whole-file', probe.Last.Errors = 1);

    { Whitespace is not a fragment: it would render to nothing, and an empty preview under a
      caption saying "fragment" reads as a crash. }
    job.Id := 6;
    job.Fragment := '   '#9;
    th.Post(job);
    CheckTrue('thread/delivers-the-sixth', PumpUntil(probe, 6, 5000));
    CheckTrue('thread/whitespace-is-not-a-fragment', not probe.Last.Partial);
    CheckTrue('thread/and-the-document-is-previewed-instead',
              Pos('ломано', probe.Last.Preview) > 0);

    { And without a selection the preview is the document again. }
    job.Id := 7;
    job.Fragment := '';
    th.Post(job);
    CheckTrue('thread/delivers-the-seventh', PumpUntil(probe, 7, 5000));
    CheckTrue('thread/no-fragment-is-not-partial', not probe.Last.Partial);
    CheckTrue('thread/the-whole-document-renders-again',
              Pos('ломано', probe.Last.Preview) > 0);

    { LATEST WINS. Fifty edits arrive faster than fifty renders can run, so the queue holds
      one job and the rest are replaced unrendered. Without that, a fast typist would build
      a backlog the UI then walks through one stale preview at a time. }
    probe.Delivered := 0;
    for i := 3 to 52 do
    begin
      job.Id := i;
      job.Text := 'правка ' + IntToStr(i) + ': {a|b}';
      th.Post(job);
    end;
    CheckTrue('thread/latest-job-arrives', PumpUntil(probe, 52, 5000));
    CheckTrue('thread/superseded-jobs-are-dropped', probe.Delivered < 50);
    { Without the first letter: post-process capitalizes the opening word. }
    CheckTrue('thread/last-answer-is-the-last-edit',
              Pos('равка 52:', probe.Last.Preview) > 0);
  finally
    th.Shutdown;
    th.WaitFor;
    th.Free;
    probe.Free;
  end;

  { Shutting down WHILE a render is in flight. The worker may be inside Synchronize, which
    waits for the main thread to service the queue -- and the main thread is the one calling
    WaitFor. If that ever deadlocks, this check does not fail, it HANGS, and the CI timeout
    is the failure. Kept for exactly that reason: the alternative is discovering it when a
    user closes the window on a big document. }
  probe := TThreadProbe.Create;
  th := TSpxEngineThread.Create(probe.Done);
  try
    job.Id := 1;
    job.Locale := 'ru';
    job.Seeded := True;
    job.Seed := 1;
    job.Text := '';
    for i := 1 to 400 do
      job.Text := job.Text + 'строка ' + IntToStr(i) + ': {а|б|в} [x|y|z] %v'
                  + IntToStr(i) + '%' + LineEnding;
    th.Post(job);
    th.Shutdown;
    th.WaitFor;
    CheckTrue('thread/shutdown-during-a-render-does-not-hang', True);
  finally
    th.Free;
    probe.Free;
  end;
end;

{ ── 8f. a batch on the same worker ────────────────────────────────────────── }

procedure TestEngineBatch;
var
  probe: TThreadProbe;
  th: TSpxEngineThread;
  req: TSpxBatchRequest;
  job: TSpxJob;
  expected: string;
  i, seen, before: Integer;
begin
  probe := TThreadProbe.Create;
  th := TSpxEngineThread.Create(probe.Done);
  try
    th.OnBatch := probe.Batch;

    { A set that the template can actually produce, generated one variant at a time. }
    req := Default(TSpxBatchRequest);
    req.Id := 1;
    req.Text := 'вариант {один|два|три|четыре|пять|шесть|семь|восемь}';
    req.Locale := 'ru';
    req.Count := 5;
    req.SeedBase := 1;
    req.Opts := SpxDefaultDedupeOpts;
    th.StartBatch(req);
    CheckTrue('batchthread/finishes', PumpBatch(probe, 15000));
    CheckTrue('batchthread/delivers-the-whole-set', probe.Kept.Count = 5);
    CheckTrue('batchthread/says-what-it-did', probe.Report.Generated = 5);
    CheckTrue('batchthread/was-not-cancelled', not probe.Cancelled);
    { Every step is reported, not only the accepted ones: the tab shows progress against
      renders, and a batch that drops half its work would otherwise look stalled. }
    CheckTrue('batchthread/reports-every-render', probe.Steps >= probe.Report.Tried);
    { Seeds are the plain derivation, so any row can be regenerated on its own. }
    CheckTrue('batchthread/seeds-start-at-the-base', probe.Kept[0].Seed = 1);
    { And the variants really are what the same seed produces here. }
    Check('batchthread/a-row-matches-a-direct-render', probe.Kept[0].Text,
          SpxRenderSample(req.Text, SpxSeededContext('ru', nil, probe.Kept[0].Seed)));

    { A thin template cannot fill the request, and the report says so rather than leaving a
      short list to be interpreted. }
    probe.BatchDone := False;
    probe.Kept.Free;
    probe.Kept := nil;
    req.Id := 2;
    req.Text := '{раз|два}';
    req.Count := 6;
    th.StartBatch(req);
    CheckTrue('batchthread/a-thin-template-finishes-too', PumpBatch(probe, 15000));
    CheckTrue('batchthread/with-what-it-has', probe.Kept.Count = 2);
    CheckTrue('batchthread/and-says-it-ran-out', probe.Report.Exhausted);

    { THE reason the batch is sliced: a render posted while it runs must still come back,
      and quickly. Without interleaving this answer would wait for the whole batch.

      The expected text is computed BEFORE the batch starts. Computing it afterwards, as the
      first version did, calls the engine from this thread while the worker is rendering --
      breaking, inside the test for that thread, the one rule the thread exists to enforce. }
    expected := SpxRenderSample('быстрый {a|b}', SpxSeededContext('ru', nil, 7));

    probe.BatchDone := False;
    probe.Kept.Free;
    probe.Kept := nil;
    probe.Steps := 0;
    req.Id := 3;
    req.Text := '';
    for i := 1 to 60 do
      req.Text := req.Text + 'абзац ' + IntToStr(i) + ' {альфа|бета|гамма} ' + LineEnding;
    req.Count := 60;
    th.StartBatch(req);

    { Wait until the batch is DEMONSTRABLY under way. Without this the render was posted
      before the worker had begun, so it was answered first and the check below passed
      whether the batch interleaved or not -- measured, 20 runs out of 20. }
    PumpSteps(probe, 3, 15000);
    CheckTrue('batchthread/the-batch-is-under-way', probe.Steps >= 3);
    before := probe.Steps;

    job := Default(TSpxJob);
    job.Id := 900;
    job.Text := 'быстрый {a|b}';
    job.Locale := 'ru';
    job.Seeded := True;
    job.Seed := 7;
    th.Post(job);
    CheckTrue('batchthread/a-render-posted-during-a-batch-still-answers',
              PumpUntil(probe, 900, 10000));
    Check('batchthread/and-answers-correctly', probe.Last.Preview, expected);
    { Still running when the answer arrived, and it had NOT stalled meanwhile: both, because
      either one alone is satisfied by a batch that was simply not running. }
    CheckTrue('batchthread/the-batch-was-still-running', not probe.BatchDone);
    { And it goes on working afterwards. Pumped rather than asserted on the instant: the
      render answers in a millisecond and the next variant takes as long as a variant takes,
      so "did it stop" is a question about the next few steps, not about this one. }
    PumpSteps(probe, before + 1, 10000);
    CheckTrue('batchthread/and-kept-working-through-the-render', probe.Steps > before);

    { Cancelling stops it, and the ending is a normal message rather than an abandoned
      thread: the tab needs the totals for what it did manage. }
    th.CancelBatch;
    CheckTrue('batchthread/cancel-ends-it', PumpBatch(probe, 15000));
    CheckTrue('batchthread/and-says-it-was-cancelled', probe.Cancelled);
    { A cancelled batch is not an exhausted one -- the template was never given the chance. }
    CheckTrue('batchthread/cancelled-is-not-exhausted', not probe.Report.Exhausted);
    seen := probe.Report.Generated;
    { > 0 because the batch was pumped until it had delivered, not because the cancel
      happened to be slow. }
    CheckTrue('batchthread/keeps-what-it-had', (seen > 0) and (seen < 60));

    { Starting a batch while one runs replaces it -- and the replacement must not INHERIT
      anything. A review reproduced the old code charging the previous batch's variant, seed
      and text to the new batch's set, all the way into the grid and the export. }
    probe.BatchDone := False;
    probe.Kept.Free;
    probe.Kept := nil;
    probe.Steps := 0;
    if probe.Ids <> nil then probe.Ids.Clear;
    req.Id := 4;
    req.Text := '';
    for i := 1 to 40 do
      req.Text := req.Text + 'длинный абзац ' + IntToStr(i) + ' {альфа|бета|гамма} ' + LineEnding;
    req.Count := 40;
    req.SeedBase := 100;
    th.StartBatch(req);
    { The batch being replaced has to have STARTED, or this tests the pending slot instead
      of the running one. }
    CheckTrue('batchthread/the-batch-to-be-replaced-started', PumpSteps(probe, 2, 15000));

    probe.Kept.Free;
    probe.Kept := nil;
    req.Id := 5;
    req.Text := 'короткий {a|b|c|d|e|f}';
    req.Count := 3;
    req.SeedBase := 900;
    th.StartBatch(req);
    CheckTrue('batchthread/a-restart-finishes', PumpDone(probe, 5, 15000));
    { The replaced batch gets its own ending, so a panel waiting on Done is never wedged. }
    CheckTrue('batchthread/the-replaced-batch-was-ended-too', probe.Dones >= 2);
    CheckTrue('batchthread/the-second-request-is-the-one-that-ran',
              probe.Report.Requested = 3);
    { NOTHING from the first batch is in the second's set: every row carries the new id and
      a seed from the new base. }
    CheckTrue('batchthread/no-row-came-from-the-replaced-batch',
              (probe.Kept <> nil) and (probe.Kept.Count = 3));
    for i := 0 to probe.Kept.Count - 1 do
      CheckTrue('batchthread/every-row-belongs-to-the-new-batch',
                (probe.Kept[i].Seed >= 900) and (probe.Kept[i].Seed < 910));
    CheckTrue('batchthread/and-the-seeds-start-at-the-new-base', probe.Kept[0].Seed = 900);

    { A request for nothing ends whatever is running, and ends it PROPERLY -- the old code
      cleared the state without a Done, leaving a panel spinning for the session. }
    probe.BatchDone := False;
    probe.Kept.Free;
    probe.Kept := nil;
    probe.Steps := 0;
    req.Id := 6;
    req.Text := '';
    for i := 1 to 40 do
      req.Text := req.Text + 'абзац ' + IntToStr(i) + ' {альфа|бета|гамма} ' + LineEnding;
    req.Count := 20;
    req.SeedBase := 1;
    th.StartBatch(req);
    { Steps is cumulative across the whole test, so it is reset first -- without that this
      wait returns instantly, the second request replaces the first before the worker ever
      saw it, and the sequence under test never happens. }
    CheckTrue('batchthread/the-batch-to-be-cut-short-started', PumpSteps(probe, 2, 15000));
    req.Id := 7;
    req.Count := 0;
    th.StartBatch(req);
    CheckTrue('batchthread/a-zero-request-still-ends-the-running-one',
              PumpDone(probe, 6, 15000));
    CheckTrue('batchthread/and-nothing-is-left-running', not th.BatchInProgress);

    { Shutdown WHILE a batch runs. Untested until a review pointed at it, and the failure
      mode is a hang rather than a wrong answer -- which no other check would catch. }
    probe.BatchDone := False;
    probe.Kept.Free;
    probe.Kept := nil;
    probe.Steps := 0;
    req.Id := 8;
    req.Text := '';
    for i := 1 to 40 do
      req.Text := req.Text + 'абзац ' + IntToStr(i) + ' {альфа|бета|гамма} ' + LineEnding;
    req.Count := 200;
    th.StartBatch(req);
    CheckTrue('batchthread/the-batch-to-shut-down-on-started', PumpSteps(probe, 2, 15000));
    th.Shutdown;
    th.WaitFor;
    CheckTrue('batchthread/shutdown-during-a-batch-does-not-hang', True);
  finally
    th.Shutdown;
    th.WaitFor;
    th.Free;
    probe.Free;
  end;
end;

{ ── 8b. the diagnostics panel's rows ─────────────────────────────────────── }

type
  { Stands in for the editor's lines, so the code-point-to-byte rule can be gated without a
    window -- the same seam the markup uses. }
  TLineFixture = class
  private
    FLines: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const S: string);
    function GetLine(ALine: Integer): string;
  end;

constructor TLineFixture.Create;
begin
  FLines := TStringList.Create;
end;

destructor TLineFixture.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

procedure TLineFixture.Add(const S: string);
begin
  FLines.Add(S);
end;

function TLineFixture.GetLine(ALine: Integer): string;
begin
  if (ALine >= 1) and (ALine <= FLines.Count) then Result := FLines[ALine - 1]
  else Result := '';
end;

function RowsOf(const doc: string; const ctx: TSpxContext): string;
var r: TSpxReport; rows: TSpxPanelRows; i: Integer; src, slug: string;
begin
  Result := '';
  r := SpxHealthReport(doc, ctx, 0);
  try
    rows := SpxPanelRows(r);
    for i := 0 to High(rows) do
    begin
      if i > 0 then Result := Result + ' | ';
      if rows[i].Source = spxRowEngine then src := 'eng' else src := 'spx';
      if rows[i].Slug = '' then slug := '<doc>' else slug := rows[i].Slug;
      Result := Result + Format('%s/%s/%s:%s@%d:%d',
        [slug, src, rows[i].Severity, rows[i].Code, rows[i].Line, rows[i].Column]);
    end;
    if Result = '' then Result := '<none>';
  finally
    r.Free;
  end;
end;

procedure TestPanelRows;
var
  set1: TStrMap;
  r: TSpxReport;
  diags: TSpDiagList;
  d: TSpDiag;
  note: TSpxNote;
  rows: TSpxPanelRows;
  fix: TLineFixture;
  marks: TSpxDiagMarks;
begin
  { The engine's columns are CODE POINTS and SynEdit's are BYTES. On an ASCII line the two
    agree, which is exactly why the mistake survives until someone writes Cyrillic. }
  CheckTrue('column/ascii-needs-no-conversion', SpxByteColumn('abc def', 5) = 5);
  { Asserted by MEANING rather than by a number counted in someone's head: the byte column
    must index the character the engine was pointing at. 'Э','Т','О' are two bytes each. }
  CheckTrue('column/cyrillic-shifts-the-byte-column',
            'ЭТО {a|b}'[SpxByteColumn('ЭТО {a|b}', 5)] = '{');
  CheckTrue('column/first-column-is-one', SpxByteColumn('ЭТО', 1) = 1);
  CheckTrue('column/zero-and-below-clamp-to-one', SpxByteColumn('ЭТО', 0) = 1);
  { Past the end is where a caret at the end of the line goes, not an error. }
  CheckTrue('column/past-the-end-clamps-after-the-last-byte', SpxByteColumn('abc', 99) = 4);
  CheckTrue('column/empty-line', SpxByteColumn('', 5) = 1);
  { The line that found the defect in the running app: the engine put the unclosed brace at
    code point 35, and the caret arrived thirteen characters early. }
  CheckTrue('column/the-line-that-found-it',
            '<p>ЭТО ФРАГМЕНТ ИЗ frag.spintax — {первый|второй'[
              SpxByteColumn('<p>ЭТО ФРАГМЕНТ ИЗ frag.spintax — {первый|второй', 35)] = '{');
  { A four-byte code point, which is where "code units, not code points" would show: the
    two-byte Cyrillic and three-byte dash above both survive a walker that is subtly wrong
    about surrogate-sized characters. }
  CheckTrue('column/four-byte-code-point',
            '🙂 текст {a|b}'[SpxByteColumn('🙂 текст {a|b}', 9)] = '{');

  { The marks conversion as the editor uses it, including the detail a single-line fixture
    cannot catch: EndCol is measured against the END line, not the start line. Here the two
    lines have different byte layouts, so converting against the wrong one lands mid-letter. }
  fix := TLineFixture.Create;
  try
    fix.Add('abc {x');       { the brace is code point 5, byte 5 }
    fix.Add('ЭТО}');         { the brace is code point 4, byte 7 }
    SetLength(marks, 1);
    marks[0].Line := 1; marks[0].Col := 5;
    marks[0].EndLine := 2; marks[0].EndCol := 4;
    marks[0].IsError := True; marks[0].Code := 'span';
    marks := SpxMarksToBytes(marks, fix.GetLine);
    CheckTrue('marks/start-column-is-converted-against-its-own-line',
              fix.GetLine(1)[marks[0].Col] = '{');
    CheckTrue('marks/end-column-is-converted-against-the-end-line',
              fix.GetLine(2)[marks[0].EndCol] = '}');
  finally
    fix.Free;
  end;

  Check('rows/document-error', RowsOf('текст]', SpxContext('ru', nil)),
        '<doc>/eng/error:bracket.unexpected-closing@1:6');
  Check('rows/clean-document', RowsOf('обычный текст', SpxContext('ru', nil)), '<none>');

  { The difference that justifies the panel: a fragment's finding has no place in the open
    document, so no squiggle can show it -- and it is exactly the finding a user cannot
    otherwise explain, because their own file looks clean. }
  set1 := Vars(['frag', 'первая'#10'вторая {a|b']);
  try
    Check('rows/fragment-error-is-listed',
          RowsOf('#include "frag"', SpxContext('ru', nil, set1)),
          'frag/eng/error:bracket.unclosed@2:8');

    { A near miss on the target: the engine's verdict AND Studio's note about it, each
      labelled with whose finding it is.

      The note comes FIRST, and the two positions differ on purpose. The engine's diagnostic
      points at the slug between the quotes (column 11); the note is about the include
      OCCURRENCE, and an occurrence's column is where its consumed text begins -- the line
      start, indentation included -- which is the engine's own convention for directives,
      measured. Each is faithful to what it describes, so the panel sorts them apart by one
      line's worth of column and that is correct rather than tidy. }
    Check('rows/engine-verdict-and-studio-note-together',
          RowsOf('#include "Frag"', SpxContext('ru', nil, set1)),
          '<doc>/spx/note:note.case-mismatch@1:1 | ' +
          '<doc>/eng/error:include.unknown-target@1:11');
  finally
    set1.Free;
  end;

  { Wording comes from the code, and an unknown code is shown as itself -- a newer engine
    must appear in the panel, not vanish from it. }
  CheckTrue('rows/known-code-reads-as-text',
            SpxDiagText('plural.arity') <> 'plural.arity');
  Check('rows/unknown-code-falls-back-to-itself',
        SpxDiagText('something.new-in-v9'), 'something.new-in-v9');
  { And a note says what it is about, not just that it happened. }
  note.Kind := spxNoteCaseMismatch;
  note.Target := 'Intro';
  note.Hint := 'intro';
  CheckTrue('rows/note-text-carries-both-names',
            (Pos('Intro', SpxNoteText(note)) > 0) and (Pos('intro', SpxNoteText(note)) > 0));

  { Ordering, on a hand-built report because the engine will not produce this shape on
    demand: inside a file, by position, with the unlocated finding last -- a row you can
    jump to is worth more than one you cannot. }
  r := TSpxReport.Create;
  try
    diags := TSpDiagList.Create;
    d.Code := 'later'; d.Severity := 'error';
    d.Line := 5; d.Column := 2; d.EndLine := 5; d.EndColumn := 3;
    diags.Add(d);
    d.Code := 'nowhere'; d.Severity := 'error';
    d.Line := 0; d.Column := 0; d.EndLine := 0; d.EndColumn := 0;
    diags.Add(d);
    d.Code := 'earlier'; d.Severity := 'warning';
    d.Line := 1; d.Column := 9; d.EndLine := 1; d.EndColumn := 10;
    diags.Add(d);
    r.Files.Add(TSpxFileReport.Create('', diags));

    { A note about a file the walk never reported on: it must not be dropped, because it is
      the finding that explains why that file is missing. }
    note.Kind := spxNoteUnknownTarget;
    note.Slug := 'ghost';
    note.Target := 'ghost';
    note.Hint := '';
    note.Line := 0;
    note.Column := 0;
    r.Notes.Add(note);

    rows := SpxPanelRows(r);
    CheckTrue('rows/nothing-is-dropped', Length(rows) = 4);
    if Length(rows) = 4 then
    begin
      Check('rows/sorted-by-position-unlocated-last',
            rows[0].Code + ',' + rows[1].Code + ',' + rows[2].Code,
            'earlier,later,nowhere');
      Check('rows/note-for-a-file-with-no-report-survives', rows[3].Code, 'note.unknown-target');
    end;
  finally
    r.Free;
  end;

  { The sort is PER FILE, and only a fixture with findings in two files can say so: the
    document's finding sits later in its own buffer than the fragment's does in its, so one
    global sort by position would put the fragment first and quietly destroy the documented
    order -- document first, then each file in walk order. Without this check, replacing
    SortFrom(first) with SortFrom(0) passed everything. }
  r := TSpxReport.Create;
  try
    diags := TSpDiagList.Create;
    d.Code := 'in-the-document'; d.Severity := 'error';
    d.Line := 2; d.Column := 10; d.EndLine := 2; d.EndColumn := 11;
    diags.Add(d);
    r.Files.Add(TSpxFileReport.Create('', diags));

    diags := TSpDiagList.Create;
    d.Code := 'in-the-fragment'; d.Severity := 'error';
    d.Line := 1; d.Column := 8; d.EndLine := 1; d.EndColumn := 9;
    diags.Add(d);
    r.Files.Add(TSpxFileReport.Create('frag', diags));

    rows := SpxPanelRows(r);
    CheckTrue('rows/two-files-two-rows', Length(rows) = 2);
    if Length(rows) = 2 then
      Check('rows/files-keep-walk-order-across-positions',
            rows[0].Code + ',' + rows[1].Code, 'in-the-document,in-the-fragment');
  finally
    r.Free;
  end;
end;

{ ── 8ba. what the editor's selection means ───────────────────────────────── }

function Sel(Kind: TSpxSelKind; L1, C1, L2, C2: Integer; const Text: string): TSpxSelection;
begin
  Result.Kind := Kind;
  Result.Range := SpxRange(SpxPos(L1, C1), SpxPos(L2, C2));
  Result.Text := Text;
end;

function Jumped(L1, C1, L2, C2: Integer): TSpxJumpState;
begin
  Result.Valid := True;
  Result.Range := SpxRange(SpxPos(L1, C1), SpxPos(L2, C2));
end;

function NoJump: TSpxJumpState;
begin
  Result.Valid := False;
  Result.Range := SpxRange(SpxPos(0, 0), SpxPos(0, 0));
end;

function RangeSig(const R: TSpxRange): string;
begin
  Result := Format('%d:%d..%d:%d', [R.A.Line, R.A.Col, R.B.Line, R.B.Col]);
end;

procedure TestSelectionPolicy;
var
  st: TSpxJumpState;
  after: TSpxRange;
  frag: string;
begin
  { Nothing selected: the whole document, and whatever a jump left goes with it. }
  frag := SpxPreviewFragment(Sel(spxSelNone, 0, 0, 0, 0, ''), Jumped(2, 5, 2, 9), st);
  Check('policy/no-selection-previews-the-document', frag, '');
  CheckTrue('policy/no-selection-forgets-the-jump', not st.Valid);

  { A selection the user made previews on its own. }
  frag := SpxPreviewFragment(Sel(spxSelNormal, 2, 5, 2, 9, 'кусок'), NoJump, st);
  Check('policy/a-manual-selection-is-the-fragment', frag, 'кусок');
  CheckTrue('policy/a-manual-selection-carries-no-jump', not st.Valid);

  { The jump's OWN selection is not the user asking to preview it. }
  frag := SpxPreviewFragment(Sel(spxSelNormal, 2, 5, 2, 9, 'кусок'), Jumped(2, 5, 2, 9), st);
  Check('policy/the-jumps-own-selection-does-not-narrow', frag, '');
  CheckTrue('policy/and-stays-the-jumps', st.Valid);

  { Move the selection anywhere else and the jump stops being the jump. }
  frag := SpxPreviewFragment(Sel(spxSelNormal, 3, 1, 3, 4, 'другое'), Jumped(2, 5, 2, 9), st);
  Check('policy/a-different-selection-is-the-fragment', frag, 'другое');
  CheckTrue('policy/and-clears-the-jump', not st.Valid);

  { THE scenario an external review found: after moving away, selecting the SAME span by
    hand is the user's own selection and must narrow. It works because the state that comes
    back from the move is threaded into the next call -- one look at render time could not
    tell these two apart. }
  SpxPreviewFragment(Sel(spxSelNone, 0, 0, 0, 0, ''), Jumped(2, 5, 2, 9), st);
  frag := SpxPreviewFragment(Sel(spxSelNormal, 2, 5, 2, 9, 'кусок'), st, st);
  Check('policy/the-same-range-selected-by-hand-does-narrow', frag, 'кусок');

  { The convention the change-path relies on: without the text the fragment is empty, and
    the state still updates -- so a caller may skip copying a large selection while dragging. }
  frag := SpxPreviewFragment(Sel(spxSelNormal, 3, 1, 3, 4, ''), Jumped(2, 5, 2, 9), st);
  Check('policy/no-text-means-no-fragment', frag, '');
  CheckTrue('policy/but-the-state-still-moves', not st.Valid);

  { ── the geometry of a wrap ── }

  { One line: the opener pushes the end along too, so a one-character wrapper on each side of
    1:3..1:6 ends at column 8. }
  CheckTrue('wrap/single-line-is-allowed',
            SpxWrapRange(Sel(spxSelNormal, 1, 3, 1, 6, 'abc'), 1, 1, after));
  Check('wrap/single-line-range', RangeSig(after), '1:3..1:8');

  { Several lines: the opener sits on the FIRST one, so only the closer moves the end. }
  CheckTrue('wrap/multi-line-is-allowed',
            SpxWrapRange(Sel(spxSelNormal, 1, 3, 4, 6, 'a'#10'b'), 1, 1, after));
  Check('wrap/multi-line-range', RangeSig(after), '1:3..4:7');

  { Column and line selections are refused: SelText round-trips them shape-wise, so the
    opener would land on the first row and the closer on the last, swallowing text nobody
    selected. Measured on the real editor before this rule existed. }
  CheckTrue('wrap/a-column-selection-is-refused',
            not SpxWrapRange(Sel(spxSelColumn, 1, 3, 3, 6, 'AB'), 1, 1, after));
  CheckTrue('wrap/a-line-selection-is-refused',
            not SpxWrapRange(Sel(spxSelLine, 1, 1, 2, 1, 'one'), 1, 1, after));
  CheckTrue('wrap/no-selection-is-refused',
            not SpxWrapRange(Sel(spxSelNone, 0, 0, 0, 0, ''), 1, 1, after));
  { A refusal leaves the range alone rather than returning something half-computed. }
  Check('wrap/a-refusal-keeps-the-range', RangeSig(after), '0:0..0:0');

  { Wrappers longer than one character, because nothing says they must be one. }
  CheckTrue('wrap/longer-wrappers',
            SpxWrapRange(Sel(spxSelNormal, 2, 1, 2, 5, 'text'), 3, 2, after));
  Check('wrap/longer-wrappers-range', RangeSig(after), '2:1..2:10');
end;

{ ── 8baa. what the page view may be handed ───────────────────────────────── }

{ How the renderer behaves -- black on a document with no element, text before the first tag
  dropped, an unterminated `<!` looping forever, `<body>` attributes read off the first body
  it meets -- is measured against the real parser and cannot be re-measured here; there is no
  window in this suite and no dependency on IPro.

  So what is gated is the FUNCTION those measurements produced: what it wraps, what it leaves
  alone, and that the text inside comes through untouched. Not the call site -- nothing here
  would fail if the pane went back to handing the renderer a raw string; the guard against
  that is the comment sitting on the call. }
procedure TestPageDocument;
begin
  { Every output is a document -- that is the whole point, and the case that black came
    from is just one of these. }
  Check('page/prose-becomes-a-document', SpxPageDocument('просто текст'),
        '<html><body>просто текст</body></html>');
  Check('page/empty-becomes-a-document', SpxPageDocument(''),
        '<html><body></body></html>');
  Check('page/an-entity-becomes-a-document', SpxPageDocument('&nbsp;'),
        '<html><body>&nbsp;</body></html>');
  Check('page/a-comment-becomes-a-document', SpxPageDocument('<!-- ничего -->'),
        '<html><body><!-- ничего --></body></html>');

  { A fragment WITH markup is wrapped too -- being passed bare is what lost the text in front
    of the first tag. }
  Check('page/a-fragment-is-wrapped-too', SpxPageDocument('раз<br>два'),
        '<html><body>раз<br>два</body></html>');

  { ── but output that already opens a document is left alone ── }

  { Because the wrapper's own <body> would be the one the renderer reads attributes off, and
    the document's would be dropped: measured, bgcolor and link survive bare and are gone
    wrapped. }
  Check('page/a-whole-document-is-untouched',
        SpxPageDocument('<html><body bgcolor="#101010"><h3>Заголовок</h3></body></html>'),
        '<html><body bgcolor="#101010"><h3>Заголовок</h3></body></html>');
  Check('page/a-bare-body-is-untouched',
        SpxPageDocument('<body background="bg.png">текст</body>'),
        '<body background="bg.png">текст</body>');
  { Case and leading whitespace are the author's business, not a different shape. }
  CheckTrue('page/opens-uppercase', SpxOpensDocument('<HTML><BODY>x</BODY></HTML>'));
  CheckTrue('page/opens-after-a-newline', SpxOpensDocument(#10'  <html>x</html>'));
  CheckTrue('page/opens-with-attributes', SpxOpensDocument('<body bgcolor="#fff">x'));
  { The tag has to end where the keyword does. }
  CheckTrue('page/htmlfoo-does-not-open', not SpxOpensDocument('<htmlfoo>x'));
  CheckTrue('page/bodyguard-does-not-open', not SpxOpensDocument('<bodyguard>x'));
  { And everything the fix is for stays a fragment. }
  CheckTrue('page/prose-does-not-open', not SpxOpensDocument('просто проза'));
  CheckTrue('page/a-paragraph-does-not-open', not SpxOpensDocument('<p>текст</p>'));
  CheckTrue('page/empty-does-not-open', not SpxOpensDocument(''));
  CheckTrue('page/whitespace-only-does-not-open', not SpxOpensDocument('   '#10));
  { A doctype in front is not the shape this recognises: it gets wrapped, which costs a
    styled body its colours but keeps every failure above impossible. Stated so the next
    reader knows it was a choice. }
  CheckTrue('page/a-doctype-prefix-does-not-open',
            not SpxOpensDocument('<!DOCTYPE html><html><body>x</body></html>'));

  { Nothing is escaped or normalised on the way through: a comparison keeps its `<`, and the
    newlines of a multi-line fragment stay where the engine put them. }
  Check('page/a-comparison-keeps-its-bracket', SpxPageDocument('5 < 6'),
        '<html><body>5 < 6</body></html>');
  Check('page/lines-are-kept', SpxPageDocument('раз'#10'два'),
        '<html><body>раз'#10'два</body></html>');

  { ── and what counts as "this fragment shows nothing" ── }
  CheckTrue('blank/empty', SpxIsBlankOutput(''));
  CheckTrue('blank/spaces-and-newlines', SpxIsBlankOutput('  '#13#10' '#9));
  { The ones Trim would have missed: a non-breaking space, and the two separators the
    engine's own line model counts as line ends. }
  CheckTrue('blank/a-non-breaking-space', SpxIsBlankOutput(#$C2#$A0));
  CheckTrue('blank/u2028', SpxIsBlankOutput(#$E2#$80#$A8));
  CheckTrue('blank/u2029-among-spaces', SpxIsBlankOutput(' '#$E2#$80#$A9' '));
  { An entity is output: the source view shows it, so claiming nothing came out would lie. }
  CheckTrue('blank/an-entity-is-not-blank', not SpxIsBlankOutput('&nbsp;'));
  CheckTrue('blank/text-is-not-blank', not SpxIsBlankOutput(' текст '));
  { A truncated UTF-8 lead byte is not whitespace and must not be read past the end. }
  CheckTrue('blank/a-lone-lead-byte-is-not-blank', not SpxIsBlankOutput(#$C2));
  CheckTrue('blank/a-cut-separator-is-not-blank', not SpxIsBlankOutput(#$E2#$80));
end;

{ ── 8bb. editing a directive where it sits ───────────────────────────────── }

function EditValue(const Doc: string; Idx: Integer; const V: string): string;
begin
  if not SpxSetDirectiveValue(Doc, Idx, V, Result) then Result := '<refused>';
end;

function EditName(const Doc: string; Idx: Integer; const N: string): string;
begin
  if not SpxSetDirectiveName(Doc, Idx, N, Result) then Result := '<refused>';
end;

function EditKind(const Doc: string; Idx: Integer; const K: string): string;
begin
  if not SpxSetDirectiveKind(Doc, Idx, K, Result) then Result := '<refused>';
end;

function DropDirective(const Doc: string; Idx: Integer): string;
begin
  if not SpxDeleteDirective(Doc, Idx, Result) then Result := '<refused>';
end;

{ What the ENGINE reads back from a document -- the only opinion that matters about whether
  an edit produced the directive it promised. }
function DirSig(const Doc: string): string;
var dirs: TSpDirectiveList; i: Integer;
begin
  Result := '';
  dirs := SpExtractDirectives(Doc);
  try
    for i := 0 to dirs.Count - 1 do
      Result := Result + Format('%s:%s=%s;', [dirs[i].Kind, dirs[i].Name, dirs[i].Value]);
  finally
    dirs.Free;
  end;
end;

procedure TestDirectiveEditing;
var doc, out_: string;
begin
  { Setting a value to what it already is must not move one byte. This is the check that
    catches a rewrite that "only" normalises formatting. }
  doc := '   #set  %Brand%   =   Акме   ' + '/# хвостовой #/'#10'<p>%Brand%</p>';
  Check('edit/value-round-trip', EditValue(doc, 0, 'Акме'), doc);

  { A real edit touches the value and nothing else: indentation, the doubled spaces, the
    name's own case and the trailing comment all survive. }
  Check('edit/value-preserves-everything-around-it', EditValue(doc, 0, 'Новое'),
        '   #set  %Brand%   =   Новое   ' + '/# хвостовой #/'#10'<p>%Brand%</p>');
  Check('edit/the-engine-reads-back-the-new-value', DirSig(EditValue(doc, 0, 'Новое')),
        'set:brand=Новое;');

  { Line endings are the document's, not ours. }
  doc := '#set %x% = A'#13#10'#def %y% = B'#13#10'текст';
  Check('edit/crlf-survives-an-edit', EditValue(doc, 1, 'Б'),
        '#set %x% = A'#13#10'#def %y% = Б'#13#10'текст');

  { Two directives on ONE editor line, split by U+2028: editing the second must leave the
    first alone -- this is where a byte offset computed on the wrong line model goes wrong. }
  doc := '#set %x% = A'#$E2#$80#$A8'#set %y% = B'#10'хвост';
  Check('edit/u2028-second-directive', EditValue(doc, 1, 'Б'),
        '#set %x% = A'#$E2#$80#$A8'#set %y% = Б'#10'хвост');
  Check('edit/u2028-both-still-read-back', DirSig(EditValue(doc, 1, 'Б')),
        'set:x=A;set:y=Б;');

  { Cyrillic before the directive on its line: code-point columns, byte offsets. }
  doc := '/# примечание #/#set %x% = A'#10'текст';
  Check('edit/cyrillic-before-the-directive', EditValue(doc, 0, 'Б'),
        '/# примечание #/#set %x% = Б'#10'текст');

  { The name, and only the name. }
  doc := '#set %old% = значение'#10'%old%';
  Check('edit/name-changes-only-the-name', EditName(doc, 0, 'renamed'),
        '#set %renamed% = значение'#10'%old%');
  { A macro name is ASCII by the family's grammar (`%\w+%`), so a Cyrillic one is not a name
    at all: the engine would stop seeing a directive there and the line would become body
    text. Refused -- and this check exists because the first version of the test above asked
    for exactly that rename and the read-back caught it. }
  Check('edit/a-cyrillic-name-is-refused', EditName(doc, 0, 'новое'), '<refused>');

  { #set and #def differ by three bytes and by when the value is rolled -- an explicit act,
    never a silent normalisation. }
  doc := '   #set %x% = {a|b}'#10;
  Check('edit/kind-set-to-def', EditKind(doc, 0, 'def'), '   #def %x% = {a|b}'#10);
  Check('edit/kind-already-so-is-a-no-op', EditKind(doc, 0, 'set'), doc);

  { An include is not a macro: it has no value, and it does not become one by swapping four
    characters. }
  doc := '#include "frag"'#10;
  Check('edit/include-has-no-value', EditValue(doc, 0, 'что-то'), '<refused>');
  Check('edit/include-is-not-a-macro-kind', EditKind(doc, 0, 'set'), '<refused>');
  { Its target, though, is a name. }
  Check('edit/include-target-is-editable', EditName(doc, 0, 'другой'),
        '#include "другой"'#10);

  { Deleting takes the line with it -- an empty line where a definition used to be is not
    what the user asked for. }
  doc := '#set %a% = 1'#10'#set %b% = 2'#10'текст';
  Check('edit/delete-takes-the-line', DropDirective(doc, 0), '#set %b% = 2'#10'текст');
  Check('edit/delete-the-last-of-them', DropDirective(doc, 1), '#set %a% = 1'#10'текст');

  { ...but a line with a comment on it has something else to say, so the line stays. }
  doc := '/# зачем #/#set %a% = 1'#10'текст';
  Check('edit/delete-keeps-a-line-that-carries-a-comment', DropDirective(doc, 0),
        '/# зачем #/'#10'текст');

  { The refusal that matters: a comment INSIDE the directive swallowed the terminator, so
    the span carries text the renderer never consumed. Rewriting it would delete the
    comment, and the panel shows such a row read-only instead. }
  doc := '#set %x% = A /# c'#10'still #/ хвост'#10'текст';
  Check('edit/refuses-a-comment-that-swallowed-the-terminator', EditValue(doc, 0, 'Б'),
        '<refused>');
  Check('edit/refuses-to-delete-it-too', DropDirective(doc, 0), '<refused>');

  { Out of range is refused, not clamped: silently editing a different directive is worse
    than doing nothing. }
  doc := '#set %x% = A'#10;
  Check('edit/index-past-the-end', EditValue(doc, 7, 'Б'), '<refused>');
  Check('edit/negative-index', EditValue(doc, -1, 'Б'), '<refused>');
  CheckTrue('edit/a-refusal-leaves-the-document-alone',
            (not SpxSetDirectiveValue(doc, 7, 'Б', out_)) and (out_ = doc));

  { An empty value is a value: `#set %x% = ` defines an empty macro, and the engine agrees. }
  doc := '#set %x% = A'#10;
  Check('edit/value-can-be-emptied', EditValue(doc, 0, ''), '#set %x% = '#10);
  Check('edit/the-engine-reads-the-empty-value', DirSig(EditValue(doc, 0, '')), 'set:x=;');

  { THE WRITTEN TEXT IS NOT TRUSTED. Each of these spliced happily and reported success
    until the edit was read back through the engine. The first is the worst: an unterminated
    comment swallows the rest of the file, and the render collapses to nothing. }
  doc := '#set %x% = A'#10'корпус текста'#10'%x% и ещё'#10;
  Check('edit/a-value-that-opens-a-comment', EditValue(doc, 0, 'A /# oops'), '<refused>');
  Check('edit/a-value-with-a-line-break', EditValue(doc, 0, 'один'#10'два'), '<refused>');
  Check('edit/a-value-with-a-carriage-return', EditValue(doc, 0, 'один'#13'два'), '<refused>');
  Check('edit/an-empty-name', EditName(doc, 0, ''), '<refused>');
  Check('edit/a-name-with-a-space', EditName(doc, 0, 'a b'), '<refused>');
  Check('edit/a-name-with-a-percent', EditName(doc, 0, 'a%b'), '<refused>');
  doc := '#include "frag"'#10;
  Check('edit/an-empty-include-target', EditName(doc, 0, ''), '<refused>');
  Check('edit/an-include-target-with-a-quote', EditName(doc, 0, 'a"b'), '<refused>');

  { A comment inside the directive is refused even when it closes on the same line: Text
    comes from comment-stripped source, the span from the source, so rewriting the span
    would delete a comment the author wrote. }
  doc := '#set %x% = A /# заметка #/ B'#10;
  Check('edit/refuses-an-inner-comment-that-closes', EditValue(doc, 0, 'C'), '<refused>');

  { Tabs are whitespace too -- in the indentation the kind edit steps over, and in the blank
    remainder deletion widens across. }
  doc := #9'#set %x% = A'#10;
  Check('edit/kind-on-a-tab-indented-directive', EditKind(doc, 0, 'def'), #9'#def %x% = A'#10);
  doc := #9'#set %a% = 1'#9#10'текст';
  Check('edit/delete-widens-over-tabs', DropDirective(doc, 0), 'текст');

  { CRLF deletion takes both bytes of the terminator, not just the LF. }
  doc := '#set %a% = 1'#13#10'#set %b% = 2'#13#10'текст';
  Check('edit/delete-takes-a-crlf-line', DropDirective(doc, 0), '#set %b% = 2'#13#10'текст');

  { An #include's span is greedy to the end of its line, so it already carries a terminator.
    Deleting it must not take a SECOND one -- these two shapes have to behave the same. }
  doc := '#include "a"'#10#10'после'#10;
  Check('edit/delete-an-include-keeps-the-blank-line', DropDirective(doc, 0), #10'после'#10);
  doc := '#set %a% = 1'#10#10'после'#10;
  Check('edit/delete-a-set-keeps-the-blank-line', DropDirective(doc, 0), #10'после'#10);

  { SpxDocOffset is public and its contract is its own, so it is checked directly rather
    than only through the edits above. }
  doc := 'ab'#10'cdef'#10'ghij';
  CheckTrue('offset/first-byte', SpxDocOffset(doc, 1, 1) = 1);
  CheckTrue('offset/start-of-the-second-line', SpxDocOffset(doc, 2, 1) = 4);
  { A column past the end of a SHORT line stops at that line's end -- it does not walk on
    into the next one. }
  CheckTrue('offset/column-past-the-line-stops-there', SpxDocOffset(doc, 1, 9) = 3);
  CheckTrue('offset/line-past-the-end-clamps', SpxDocOffset(doc, 99, 1) = Length(doc) + 1);
  CheckTrue('offset/line-below-one', SpxDocOffset(doc, 0, 5) = 1);
  CheckTrue('offset/crlf-is-one-line-break', SpxDocOffset('ab'#13#10'cd', 2, 1) = 5);
  CheckTrue('offset/a-lone-cr-ends-a-line', SpxDocOffset('ab'#13, 2, 1) = 4);
end;

{ ── 8bc. the model's link back to the document ───────────────────────────── }

procedure TestModelDirIndex;
var
  m: TSpxModel;
  doc, edited: string;
  i, seen: Integer;
begin
  { A panel row must know WHICH occurrence it stands for. Matching by name cannot do it --
    duplicates are kept on purpose, because two definitions of one name is what the engine
    calls definition.duplicate-name and a panel that showed one row would hide half of it. }
  doc := '#set %a% = 1'#10'#include "frag"'#10'#def %b% = 2'#10'#set %a% = 3'#10'%runtime%';
  m := SpxExtractModel(doc, SpxContext('ru', nil));
  try
    CheckTrue('model/three-macros-and-one-runtime', m.Vars.Count = 4);
    CheckTrue('model/the-include-is-its-own-list', m.Includes.Count = 1);
    { Occurrence order is the engine's: the include is number 1, so the #def is number 2. }
    Check('model/dir-index-of-each-macro',
          Format('%d,%d,%d', [m.Vars[0].DirIndex, m.Vars[1].DirIndex, m.Vars[2].DirIndex]),
          '0,2,3');
    CheckTrue('model/the-include-carries-its-index', m.Includes[0].DirIndex = 1);

    { A runtime variable has no directive at all, and says so rather than pointing at one. }
    seen := -2;
    for i := 0 to m.Vars.Count - 1 do
      if m.Vars[i].Kind = spxVarRuntime then seen := m.Vars[i].DirIndex;
    CheckTrue('model/a-runtime-variable-has-no-directive', seen = -1);

    { THE point of the field: the index it reports is the one the edit functions take. This
      is the check that fails if the two orders ever drift apart. }
    CheckTrue('model/the-index-is-the-one-the-editors-take',
              SpxSetDirectiveValue(doc, m.Vars[2].DirIndex, '99', edited));
    Check('model/and-it-edited-the-right-occurrence', DirSig(edited),
          'set:a=1;include:frag=;def:b=2;set:a=99;');
  finally
    m.Free;
  end;
end;

{ ── 8bd. the session's values, pruned ────────────────────────────────────── }

function Pairs(const NamesAndValues: array of string): TSpxVarPairs;
var i: Integer;
begin
  Result := nil;
  SetLength(Result, Length(NamesAndValues) div 2);
  for i := 0 to High(Result) do
  begin
    Result[i].Name := NamesAndValues[i * 2];
    Result[i].Value := NamesAndValues[i * 2 + 1];
  end;
end;

function PairSig(const P: TSpxVarPairs): string;
var i: Integer;
begin
  Result := '';
  for i := 0 to High(P) do Result := Result + P[i].Name + '=' + P[i].Value + ';';
  if Result = '' then Result := '<none>';
end;

procedure TestKeepRuntime;
var
  m: TSpxModel;
  vars: TSpxVarInfos;
  i: Integer;
begin
  { The model of a document that DEFINES brand and REFERENCES city. }
  m := SpxExtractModel('#set %brand% = Акме'#10'<p>%brand% в %city%</p>', SpxContext('ru', nil));
  try
    SetLength(vars, m.Vars.Count);
    for i := 0 to m.Vars.Count - 1 do vars[i] := m.Vars[i];
  finally
    m.Free;
  end;

  { A value for a name the document references and nothing defines survives. }
  Check('runtime/keeps-a-value-for-a-referenced-name',
        PairSig(SpxKeepRuntime(vars, Pairs(['city', 'Тверь']))), 'city=Тверь;');

  { A value for a name the document DEFINES is a ghost: sending it would suppress a
    variable.undefined the macro no longer earns. }
  Check('runtime/drops-a-value-for-a-defined-name',
        PairSig(SpxKeepRuntime(vars, Pairs(['brand', 'Другое']))), '<none>');

  { And so is a value for a name the document does not mention at all. }
  Check('runtime/drops-a-value-nothing-references',
        PairSig(SpxKeepRuntime(vars, Pairs(['nowhere', 'x']))), '<none>');

  { The engine matches runtime names case-insensitively and keys them lower-cased, so a
    value typed as CITY belongs to %city% -- and comes back in the spelling the next render
    will match. }
  Check('runtime/matches-case-insensitively-and-returns-the-model-spelling',
        PairSig(SpxKeepRuntime(vars, Pairs(['CITY', 'Тверь']))), 'city=Тверь;');

  { One value per name, and the mixture of live and dead entries keeps its order. }
  Check('runtime/one-value-per-name',
        PairSig(SpxKeepRuntime(vars, Pairs(['city', 'первое', 'city', 'второе']))),
        'city=первое;');
  Check('runtime/empty-session', PairSig(SpxKeepRuntime(vars, nil)), '<none>');
end;

{ ── 8c. the validation cache ─────────────────────────────────────────────── }

{ Everything the caller can observe about a report, in one string: what a cached round must
  reproduce exactly. }
function ReportSig(const Doc: string; const Ctx: TSpxContext;
  Cache: TSpxValidationCache): string;
var r: TSpxReport; rows: TSpxPanelRows; i: Integer;
begin
  Result := '';
  r := SpxHealthReport(Doc, Ctx, 0, '', Cache);
  try
    rows := SpxPanelRows(r);
    for i := 0 to High(rows) do
      Result := Result + Format('%s/%s/%s@%d:%d;',
        [rows[i].Slug, rows[i].Severity, rows[i].Code, rows[i].Line, rows[i].Column]);
    Result := Result + Format('|E%d W%d', [r.Errors, r.Warnings]);
  finally
    r.Free;
  end;
end;

procedure TestValidationCache;
var
  tset: TStrMap;
  runtime: TStrMap;
  cache: TSpxValidationCache;
  ctx: TSpxContext;
  bigger: TStrMap;
  plain, cached: string;
  doc, doc2, slugA, slugB: string;
  hits0, misses0: Integer;
begin
  doc := '#include "frag"'#10'#include "other"'#10'{незакрытая';
  doc2 := '#include "frag"'#10'#include "other"'#10'{незакрытая и правка';
  tset := Vars(['frag', 'фрагмент {a|b', 'other', 'текст %undefinedName% тут']);
  cache := TSpxValidationCache.Create;
  try
    ctx := SpxContext('ru', nil, tset);

    { THE check. A cache that changes a verdict is worse than a slow one, so the same
      document is reported identically with and without it -- codes, severities, positions,
      counts and all. }
    plain := ReportSig(doc, ctx, nil);
    cached := ReportSig(doc, ctx, cache);
    Check('cache/report-is-identical-to-the-uncached-one', cached, plain);
    CheckTrue('cache/first-round-is-all-misses', (cache.Hits = 0) and (cache.Misses = 3));

    { A second identical round validates nothing at all. }
    hits0 := cache.Hits; misses0 := cache.Misses;
    Check('cache/second-round-still-identical', ReportSig(doc, ctx, cache), plain);
    CheckTrue('cache/second-round-is-all-hits',
              (cache.Hits - hits0 = 3) and (cache.Misses - misses0 = 0));

    { A keystroke in the DOCUMENT must not re-validate the fragments -- that is the whole
      point -- and must still re-validate the document. }
    hits0 := cache.Hits; misses0 := cache.Misses;
    ReportSig(doc2, ctx, cache);
    CheckTrue('cache/an-edit-revalidates-only-the-edited-file',
              (cache.Misses - misses0 = 1) and (cache.Hits - hits0 = 2));

    { The verdict depends on the locale, so the locale is part of the key: plural arity and
      more hang off it, and serving a `ru` answer for an `en` question would be silent. }
    hits0 := cache.Hits; misses0 := cache.Misses;
    ReportSig(doc, SpxContext('en', nil, tset), cache);
    CheckTrue('cache/locale-is-part-of-the-key', cache.Misses - misses0 = 3);

    { So do the host-supplied variable names: they suppress variable.undefined. Run at the
      SAME locale as the round before, or the misses prove nothing -- a locale change alone
      would have caused them, which is how the first version of this check passed while the
      variable list was absent from the key entirely (found by mutation testing). }
    ReportSig(doc, ctx, cache);                       { back to `ru`, everything warm }
    runtime := Vars(['undefinedName', 'значение']);
    try
      hits0 := cache.Hits; misses0 := cache.Misses;
      plain := ReportSig(doc, SpxContext('ru', runtime, tset), nil);
      cached := ReportSig(doc, SpxContext('ru', runtime, tset), cache);
      Check('cache/known-variables-are-part-of-the-key', cached, plain);
      CheckTrue('cache/known-variables-cause-a-miss',
                (cache.Misses - misses0 = 3) and (cache.Hits - hits0 = 0));
    finally
      runtime.Free;
    end;

    { And the known-INCLUDE list, which decides include.unknown-target. Same document, same
      locale: only the set grows. }
    bigger := Vars(['frag', 'фрагмент {a|b', 'other', 'текст %undefinedName% тут',
                    'third', 'ещё один']);
    try
      ReportSig(doc, ctx, cache);
      hits0 := cache.Hits; misses0 := cache.Misses;
      ReportSig(doc, SpxContext('ru', nil, bigger), cache);
      CheckTrue('cache/known-includes-are-part-of-the-key',
                (cache.Misses - misses0 = 3) and (cache.Hits - hits0 = 0));
    finally
      bigger.Free;
    end;

    { The key's fields cannot run together. Without the length prefixes ('ab' + 'c' and
      'a' + 'bc' spell one string), the second call would hit the first one's entry. }
    hits0 := cache.Hits; misses0 := cache.Misses;
    cache.Validate('ab', 'c', 'ru', nil, nil).Free;
    cache.Validate('a', 'bc', 'ru', nil, nil).Free;
    CheckTrue('cache/key-fields-cannot-run-together',
              (cache.Misses - misses0 = 2) and (cache.Hits - hits0 = 0));

    { Entries live one round: a fragment the document no longer includes is dropped rather
      than kept for a text the user may never type again. }
    ReportSig('#include "frag"'#10'{незакрытая', ctx, cache);
    CheckTrue('cache/round-drops-what-it-did-not-touch', cache.Count = 2);
  finally
    cache.Free;
    tset.Free;
  end;

  { A HIT MUST BE BYTE-EXACT, and this is the check that says so. U+082D and U+0B60 are
    distinct code points that the Windows collation gives equal weight, so a cache keyed
    through TStringList (whose CaseSensitive comparison is AnsiCompareStr) serves the first
    document's verdict for the second: one is a known include target, the other is not.
    Silent, and different on machines with different collation tables -- the exact drift
    this project bans. Two texts of the same length, so nothing else can tell them apart. }
  slugA := 'frag' + #$E0#$A0#$AD;
  slugB := 'frag' + #$E0#$AD#$A0;
  tset := Vars([slugA, 'известный фрагмент']);
  cache := TSpxValidationCache.Create;
  try
    ctx := SpxContext('ru', nil, tset);
    plain := ReportSig('#include "' + slugA + '"', ctx, cache);
    cached := ReportSig('#include "' + slugB + '"', ctx, cache);
    CheckTrue('cache/a-hit-is-byte-exact', cached <> plain);
    CheckTrue('cache/the-unknown-target-is-still-reported',
              Pos('include.unknown-target', cached) > 0);
  finally
    cache.Free;
    tset.Free;
  end;

  { The same defect one level up, and it predates the cache: the closure walk decides
    "already visited" with the same fuzzy comparison, so a second fragment whose slug the
    collation calls equal to the first would be skipped and its errors never reported. }
  tset := Vars([slugA, 'первый {незакрытый', slugB, 'второй ]лишний']);
  try
    plain := ReportSig('#include "' + slugA + '"'#10'#include "' + slugB + '"',
                       SpxContext('ru', nil, tset), nil);
    CheckTrue('closure/two-slugs-the-collation-calls-equal',
              (Pos('bracket.unclosed', plain) > 0) and
              (Pos('bracket.unexpected-closing', plain) > 0));
  finally
    tset.Free;
  end;
end;

{ ── 8d. near-duplicates, and a batch that avoids them ────────────────────── }

function SimOf(const A, B: string; K: Integer): Double;
begin
  Result := SpxSimilarity(SpxShingles(A, K), SpxShingles(B, K));
end;

{ A paragraph-sized text with one word swappable -- the length a real variant has, which is
  what the default threshold is calibrated for. One changed word then moves four shingles out
  of a hundred, instead of four out of nine.

  The filler VARIES from sentence to sentence, and it has to: shingles are deduplicated, so
  repeating one sentence eight times adds no mass to the fingerprint at all. Written the
  obvious way first, it made a hundred-word text weigh the same as a twelve-word one -- and
  the assertion below then failed for a reason that had nothing to do with the measure. }
function Para(const Verb: string): string;
var i: Integer;
begin
  Result := 'the quick brown fox ' + Verb + ' over the lazy dog';
  for i := 1 to 8 do
    Result := Result + Format(' in section %d the report notes that field %d stayed quiet ' +
                              'until the %dth morning of the survey', [i, i, i]);
end;

{ A signature of what came back, so a set can be asserted whole rather than field by
  field. }
function BatchSig(const R: TSpxBatchReport): string;
begin
  { R.Tried, not NextSeed - SeedBase: the subtraction is the same number only until the seed
    range wraps, and then it raises under -Cr. The report carries the count for that reason. }
  Result := Format('req=%d gen=%d drop=%d tried=%d%s',
    [R.Requested, R.Generated, R.Dropped, R.Tried,
     BoolToStr(R.Exhausted, ' exhausted', '')]);
end;

{ The invariant the whole unit is for, asserted directly instead of through counts: no two
  variants that came back are within the threshold of each other. }
function NoTwoAreClose(L: TSpxVariantList; const Opts: TSpxDedupeOpts): Boolean;
var i, j: Integer; fps: array of TSpxHashes;
begin
  SetLength(fps, L.Count);
  for i := 0 to L.Count - 1 do fps[i] := SpxShingles(L[i].Text, Opts.ShingleSize);
  for i := 0 to L.Count - 1 do
    for j := 0 to i - 1 do
      if SpxSimilarity(fps[i], fps[j]) >= Opts.Threshold then Exit(False);
  Result := True;
end;

procedure TestDedupe;
var
  fp: TSpxHashes;
  ctx: TSpxContext;
  rep: TSpxBatchReport;
  opts: TSpxDedupeOpts;
  list, uniq: TSpxVariantList;
  v: TSpxVariant;
  dense: string;
  i, dropped: Integer;
begin
  { ── the fingerprint ── }

  { Four words, k=3: two shingles, and they are what the sliding window says they are. }
  fp := SpxShingles('one two three four', 3);
  CheckTrue('shingle/two-shingles-from-four-words', Length(fp) = 2);
  { Shorter than k is one shingle, not none -- otherwise every short variant would have an
    empty fingerprint and compare equal to every other. }
  fp := SpxShingles('one two', 5);
  CheckTrue('shingle/a-short-text-is-one-shingle', Length(fp) = 1);
  fp := SpxShingles('', 4);
  CheckTrue('shingle/nothing-has-no-fingerprint', Length(fp) = 0);
  fp := SpxShingles('   '#10#9, 4);
  CheckTrue('shingle/whitespace-has-no-fingerprint', Length(fp) = 0);
  { A repeated phrase counts once, or a text that says the same thing twice would inflate
    its own overlap with everything. }
  { Six words, k=2: five shingles, but only two distinct ones. }
  fp := SpxShingles('раз два раз два раз два', 2);
  CheckTrue('shingle/a-repeated-phrase-counts-once', Length(fp) = 2);
  { Whitespace between words is not part of the words. }
  CheckTrue('shingle/spacing-does-not-matter',
            SimOf('one two three', 'one   two'#10'three', 2) = 1.0);
  CheckTrue('shingle/ascii-case-folds', SimOf('One Two Three', 'one two three', 2) = 1.0);
  { AND CYRILLIC CASE FOLDS, which an ASCII-only fold got wrong -- it scored this pair 0.00.
    Not academic: Studio renders with PostProcess on, so the engine re-cases the word after a
    sentence end, and an alternation that moves that boundary changes the case of the next
    word. Understated similarity lets near-duplicates through, so this is the direction of
    error that matters. }
  CheckTrue('shingle/cyrillic-case-folds-too',
            SimOf('Привет Мир Друг Сосед', 'привет мир друг сосед', 2) = 1.0);
  { The shape the engine's capitalisation actually produces: one word re-cased mid-text. }
  CheckTrue('shingle/one-recased-word-does-not-split-a-text',
            SimOf('тарифы меняются с первого числа новая цена уже указана',
                  'тарифы меняются с первого числа Новая цена уже указана', 4) = 1.0);
  { Folding is the engine's own table, so anything it upper-cases, this folds. }
  CheckTrue('shingle/folding-follows-the-engine',
            SimOf('ÉCOLE ÜBER ŽIVOT', 'école über život', 2) = 1.0);

  { ── the measure ── }

  CheckTrue('sim/identical-is-one', SimOf('a b c d e', 'a b c d e', 3) = 1.0);
  CheckTrue('sim/nothing-shared-is-zero',
            SimOf('раз два три четыре', 'five six seven eight', 3) = 0.0);
  CheckTrue('sim/two-empties-are-identical', SimOf('', '', 3) = 1.0);
  CheckTrue('sim/empty-against-text-shares-nothing', SimOf('', 'a b c', 3) = 0.0);
  { THE case the unit exists for: a paragraph with one word changed. Exact comparison calls
    these two texts unique; to a reader they are one text, and the default threshold agrees
    -- 0.87, measured, so the second one is dropped. }
  CheckTrue('sim/one-word-in-a-paragraph-is-still-the-same-text',
            SimOf(Para('jumps'), Para('leaps'), 4) > SpxDefaultDedupeOpts.Threshold);
  { And the SAME edit in a short text is not the same text: four of nine shingles change,
    which is a third of a sentence rather than a word in a paragraph. The measure is
    length-relative on purpose, and this is the pair that says so -- a threshold that drops
    the paragraph above must not also drop these two. }
  CheckTrue('sim/the-same-edit-in-a-sentence-is-a-difference',
            SimOf('the quick brown fox jumps over the lazy dog',
                  'the quick brown fox leaps over the lazy dog', 4)
            < SpxDefaultDedupeOpts.Threshold);
  { And a genuinely different paragraph is nowhere near. }
  CheckTrue('sim/a-different-text-is-not',
            SimOf(Para('jumps'),
                  'наши новые тарифы вступают в силу с первого числа каждого месяца', 4)
            < 0.1);

  { ── the batch ── }

  ctx := SpxContext('en', nil, nil);
  opts := SpxDefaultDedupeOpts;

  { A template with exactly two outcomes, asked for five. Two come back, the rest are
    duplicates, and the report says so rather than leaving a short list to explain itself. }
  uniq := SpxGenerateUnique('{раз|два}', ctx, 5, 1, opts, rep);
  try
    CheckTrue('batch/a-thin-template-yields-what-it-has', uniq.Count = 2);
    CheckTrue('batch/and-says-it-ran-out', rep.Exhausted);
    Check('batch/the-report-adds-up', IntToStr(rep.Generated + rep.Dropped),
          IntToStr(rep.Tried));
    { The seeds are still the ones the plain derivation would have used. }
    CheckTrue('batch/and-the-seed-span-matches-what-was-tried',
              rep.NextSeed - rep.SeedBase = LongWord(rep.Tried));
  finally
    uniq.Free;
  end;

  { Asked for none: no renders, no seeds spent, nothing claimed. }
  uniq := SpxGenerateUnique('{раз|два}', ctx, 0, 7, opts, rep);
  try
    CheckTrue('batch/zero-asks-for-nothing', uniq.Count = 0);
    Check('batch/zero-spends-no-seeds', BatchSig(rep), 'req=0 gen=0 drop=0 tried=0');
  finally
    uniq.Free;
  end;

  { The budget is a bound on RENDERS, not on drops: N seeds for the set plus the budget for
    replacements, so a budget of zero means "try exactly N and keep what is unique among
    them". The first version stopped at the first duplicate instead -- which contradicted its
    own documentation, and threw away variants the first N seeds did contain. }
  opts.RetryBudget := 0;
  uniq := SpxGenerateUnique('всегда одно и то же', ctx, 4, 1, opts, rep);
  try
    CheckTrue('batch/no-budget-still-tries-the-whole-request', uniq.Count = 1);
    Check('batch/no-budget-spends-exactly-n-seeds', BatchSig(rep),
          'req=4 gen=1 drop=3 tried=4 exhausted');
  finally
    uniq.Free;
  end;

  { And with a template that HAS a second outcome inside those N seeds, no budget still finds
    it -- the case the old loop lost. }
  opts.RetryBudget := 0;
  uniq := SpxGenerateUnique('{alpha beta gamma delta|epsilon zeta eta theta}', ctx, 8, 1,
                            opts, rep);
  try
    CheckTrue('batch/no-budget-finds-what-the-first-n-seeds-hold', uniq.Count = 2);
  finally
    uniq.Free;
  end;

  { Seeds are the ones a plain batch would have used, and every variant keeps its own -- the
    set stays reproducible one variant at a time even after replacements. }
  opts := SpxDefaultDedupeOpts;
  uniq := SpxGenerateUnique('{a|b|c|d|e|f|g|h}', ctx, 3, 100, opts, rep);
  try
    { Asserted before anything conditional on the count, so an empty batch fails here rather
      than passing every check below it vacuously. }
    CheckTrue('batch/the-set-is-not-empty', uniq.Count = 3);
    CheckTrue('batch/seeds-start-where-asked', uniq[0].Seed = 100);
    for i := 0 to uniq.Count - 1 do
      CheckTrue('batch/every-variant-carries-a-seed-in-range',
                (uniq[i].Seed >= 100) and (uniq[i].Seed < rep.NextSeed));
    CheckTrue('batch/the-next-batch-continues', rep.NextSeed >= 100 + LongWord(uniq.Count));
    { THE invariant, asserted directly rather than inferred from counts. }
    CheckTrue('batch/no-two-kept-variants-are-close', NoTwoAreClose(uniq, opts));
  finally
    uniq.Free;
  end;

  { ── the settings are clamped rather than obeyed into nonsense ── }

  { A shingle size below one is meaningless; it becomes one word per shingle. }
  opts := SpxDefaultDedupeOpts;
  opts.ShingleSize := 0;
  CheckTrue('opts/a-zero-shingle-size-still-fingerprints',
            Length(SpxShingles('раз два три', 0)) = 3);
  { A threshold of zero would call every pair a duplicate and return one variant whatever the
    template; refusing it is kinder than obeying it. }
  opts.Threshold := 0;
  uniq := SpxGenerateUnique('{a|b|c|d|e|f|g|h}', ctx, 3, 1, opts, rep);
  try
    CheckTrue('opts/a-zero-threshold-does-not-collapse-the-set', uniq.Count >= 1);
  finally
    uniq.Free;
  end;
  { Above one it is clamped to one, which is "identical fingerprints only". }
  opts := SpxDefaultDedupeOpts;
  opts.Threshold := 5;
  uniq := SpxGenerateUnique('{a|b|c|d|e|f|g|h}', ctx, 3, 1, opts, rep);
  try
    CheckTrue('opts/a-threshold-above-one-is-clamped', uniq.Count = 3);
  finally
    uniq.Free;
  end;

  { The top of the seed range. LongWord wrapping is the intended behaviour here -- a seed is
    an identifier for regenerating one row, not a counter -- but "intended" has to be proved
    by the CHECKED twin of this suite, which is where an EIntOverflow would surface. It
    already surfaced once in this unit, in the hash. }
  opts := SpxDefaultDedupeOpts;
  uniq := SpxGenerateUnique('{a|b|c|d}', ctx, 3, $FFFFFFFE, opts, rep);
  try
    CheckTrue('batch/seeds-wrap-at-the-top-of-the-range', uniq.Count >= 1);
    CheckTrue('batch/and-the-wrapped-seeds-are-recorded',
              (uniq.Count < 2) or (uniq[1].Seed = $FFFFFFFF));
  finally
    uniq.Free;
  end;

  { The plain batch has the same derivation and had never been asked to cross the top: it
    raised too, under the same checked build, and for the same reason. }
  list := SpxRenderBatch('{a|b}', ctx, 4, $FFFFFFFE);
  try
    CheckTrue('batch/a-plain-batch-crosses-the-top-too', list.Count = 4);
    CheckTrue('batch/and-wraps-to-zero', list[2].Seed = 0);
    CheckTrue('batch/and-keeps-going', list[3].Seed = 1);
  finally
    list.Free;
  end;

  { ── markup is not words ── }

  { THE case this is for: a listing whose tags carry no whitespace. Counting them, the whole
    document is one "word" and the fingerprint collapses to a single shingle -- measured, and
    the dedup then reports every variant as unique at any threshold. }
  dense := '<table>';
  for i := 1 to 30 do
    dense := dense + '<tr><td>товар' + IntToStr(i) + '</td><td>в наличии</td></tr>';
  dense := dense + '</table>';
  fp := SpxShingles(dense, 4);
  CheckTrue('markup/a-tagged-listing-still-has-a-fingerprint', Length(fp) > 20);
  { A tag becomes a SEPARATOR, not nothing: `a</b><b>b` is two words. }
  CheckTrue('markup/tags-separate-words',
            SimOf('раз</b><b>два', 'раз два', 1) = 1.0);
  { And markup adds nothing of its own to the comparison. }
  CheckTrue('markup/tags-do-not-count-as-content',
            SimOf('<p>текст письма</p>', 'текст письма', 2) = 1.0);
  CheckTrue('markup/different-tags-around-the-same-text-are-the-same-text',
            SimOf('<h1>заголовок статьи</h1>', '<div class="x">заголовок статьи</div>', 2)
            = 1.0);
  { A comparison is not a tag: `5 < 6` keeps its bracket instead of swallowing the rest of
    the sentence, which is what a naive "delete from < to >" does. }
  CheckTrue('markup/a-comparison-is-not-a-tag',
            SimOf('пять < шесть и семь > шесть', 'пять < шесть и семь > шесть', 2) = 1.0);
  fp := SpxShingles('если 5 < 6 то всё хорошо', 1);
  CheckTrue('markup/and-its-words-survive', Length(fp) = 7);
  { An unterminated tag at the very end is text, not a tag that ate the tail. }
  fp := SpxShingles('конец строки <b', 1);
  CheckTrue('markup/an-unterminated-tag-is-text', Length(fp) = 3);

  { ── the three modes ── }

  list := TSpxVariantList.Create;
  try
    v.Seed := 1; v.Text := Para('jumps'); list.Add(v);
    v.Seed := 2; v.Text := Para('leaps'); list.Add(v);      { near-copy, not identical }
    v.Seed := 3; v.Text := Para('jumps'); list.Add(v);      { byte-identical to the first }

    { Shingles: the near-copy goes too. }
    opts := SpxDefaultDedupeOpts;
    uniq := SpxDedupeList(list, opts, dropped);
    try
      CheckTrue('mode/shingles-drop-the-near-copy', uniq.Count = 1);
    finally
      uniq.Free;
    end;

    { Exact: only the literal repeat. This is what GTW's "удаление точных совпадений" does,
      and it is NOT the same as shingles at 1.0 -- a fingerprint is a set, so a text whose
      sentences are shuffled has the same fingerprint and different bytes. }
    opts.Mode := spxDedupeExact;
    uniq := SpxDedupeList(list, opts, dropped);
    try
      CheckTrue('mode/exact-keeps-the-near-copy', uniq.Count = 2);
      CheckTrue('mode/exact-drops-the-identical-one', dropped = 1);
    finally
      uniq.Free;
    end;

    { Off: everything survives, including the literal repeat. }
    opts.Mode := spxDedupeOff;
    uniq := SpxDedupeList(list, opts, dropped);
    try
      CheckTrue('mode/off-keeps-everything', uniq.Count = 3);
      CheckTrue('mode/off-drops-nothing', dropped = 0);
    finally
      uniq.Free;
    end;
  finally
    list.Free;
  end;

  { The distinction the exact mode exists for, stated as a check: same shingles, different
    bytes. Two texts made of the same sentences in the other order. }
  CheckTrue('mode/shuffled-sentences-share-a-fingerprint',
            SimOf('раз два три. четыре пять шесть.', 'четыре пять шесть. раз два три.', 2)
            > 0.6);

  { ── the same filter over a set that already exists ── }

  list := TSpxVariantList.Create;
  try
    { Variant-sized texts, because that is what the threshold is for -- the same four texts
      as sentences would all be "different enough" and prove nothing. }
    v.Seed := 1; v.Text := Para('jumps');
    list.Add(v);
    v.Seed := 2; v.Text := Para('leaps');                          { one word changed }
    list.Add(v);
    v.Seed := 3; v.Text := 'наши тарифы меняются с первого числа каждого месяца';
    list.Add(v);
    v.Seed := 4; v.Text := Para('jumps');                          { exact copy }
    list.Add(v);

    uniq := SpxDedupeList(list, SpxDefaultDedupeOpts, dropped);
    try
      CheckTrue('list/keeps-the-two-that-differ', uniq.Count = 2);
      CheckTrue('list/drops-the-near-copy-and-the-exact-one', dropped = 2);
      { The FIRST of a group survives, so the set keeps its earliest seeds. }
      CheckTrue('list/keeps-the-first-of-a-group', uniq[0].Seed = 1);
      CheckTrue('list/and-the-input-is-left-alone', list.Count = 4);
    finally
      uniq.Free;
    end;

    { A threshold of 1.0 is the closest this gets to exact comparison: the near-copy
      survives, the exact one does not. }
    opts := SpxDefaultDedupeOpts;
    opts.Threshold := 1.0;
    uniq := SpxDedupeList(list, opts, dropped);
    try
      CheckTrue('list/threshold-one-keeps-the-near-copy', uniq.Count = 3);
      CheckTrue('list/threshold-one-still-drops-an-identical-text', dropped = 1);
    finally
      uniq.Free;
    end;
  finally
    list.Free;
  end;

  { Nothing to filter is not an error: the export tab will call this before the user has
    generated anything. }
  uniq := SpxDedupeList(nil, SpxDefaultDedupeOpts, dropped);
  try
    CheckTrue('list/nil-is-an-empty-result', uniq.Count = 0);
    CheckTrue('list/nil-drops-nothing', dropped = 0);
  finally
    uniq.Free;
  end;
end;

{ ── temp folders, shared by the two sections that write real files ───────── }

function TempFolder: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
            'spx-files-' + IntToStr(GetProcessID);
end;

{ Paths joined the platform's way. This suite runs on Windows AND on ubuntu in CI, where a
  hardcoded backslash is not a separator at all: the files land beside the folder with a
  backslash in their names, the scan finds nothing, and the failure reads as "the loader is
  broken" rather than "the test is". }
function InDir(const D, Name: string): string;
begin
  Result := IncludeTrailingPathDelimiter(D) + Name;
end;

{ RECURSIVE, which it was not: RemoveDir fails silently on a folder that still has anything
  in it, so an unzipped OOXML tree (xl/worksheets/, xl/_rels/, _rels/) survived every run and
  %TEMP% collected one per process id, forever. }
procedure WipeFolder(const Dir: string);
var sr: TSearchRec; base: string;
begin
  if not DirectoryExists(Dir) then Exit;
  base := IncludeTrailingPathDelimiter(Dir);
  if FindFirst(base + '*', faAnyFile, sr) = 0 then
  try
    repeat
      if (sr.Name = '.') or (sr.Name = '..') then Continue;
      if (sr.Attr and faDirectory) <> 0 then WipeFolder(base + sr.Name)
      else DeleteFile(base + sr.Name);
    until FindNext(sr) <> 0;
  finally
    FindClose(sr);
  end;
  RemoveDir(Dir);
end;

{ ── 8e. writing a set out ─────────────────────────────────────────────────── }

{ An exported part, PARSED rather than searched. A substring check cannot tell a well-formed
  document from one no reader will open, and both defects this suite now gates -- a quote in
  the sheet name, a byte that is not UTF-8 in a cell -- produce text that `Pos` is perfectly
  happy with. Returns '' when the XML is well-formed, or the parser's complaint. }
function XmlError(const Path: string): string;
var doc: TXMLDocument; ms: TStringStream;
begin
  Result := '';
  doc := nil;
  ms := TStringStream.Create(SpxReadTextFile(Path));
  try
    try
      ReadXMLFile(doc, ms);
    except
      on E: Exception do Result := E.ClassName + ': ' + E.Message;
    end;
  finally
    doc.Free;
    ms.Free;
  end;
end;

{ The text of the first `<v>` in a row, i.e. what a numeric cell carries. Empty when the row
  has no numeric cell at all, which is the state this suite is checking against. }
function FirstNumericCell(const SheetXml: string): string;
var p, q: Integer;
begin
  Result := '';
  p := Pos('<v>', SheetXml);
  if p = 0 then Exit;
  q := PosEx('</v>', SheetXml, p);
  if q = 0 then Exit;
  Result := Copy(SheetXml, p + 3, q - p - 3);
end;

{ Every writer here is checked by reading the file BACK, including the .xlsx: it is unzipped,
  its parts are PARSED, and the sheet is inspected. A writer tested only by "the call
  returned True" is a writer that has never been read by anything. }
procedure TestExport;
var
  dir, path, s: string;
  list: TSpxVariantList;
  v: TSpxVariant;
  opts: TSpxTxtOpts;
  rep: TSpxExportReport;
  txt: TStringList;
  unzip: TUnZipper;
  ok: Boolean;
  bad, empty: TSpxVariantList;
begin
  { ── the escaping, which is the part with no second chance: an invalid character makes the
    file invalid rather than damaged ── }
  Check('xml/ampersand', SpxXmlText('a & b'), 'a &amp; b');
  Check('xml/angles', SpxXmlText('<p>x</p>'), '&lt;p&gt;x&lt;/p&gt;');
  { A quote needs no escape in a text node, and escaping it would show up in the cell. }
  Check('xml/quotes-are-text', SpxXmlText('"тут" и ''там'''), '"тут" и ''там''');
  { Tab and LF are written literally -- XML allows them and leaves them alone. CR is the one
    that cannot be, see below. }
  Check('xml/tab-and-lf-survive-literally', SpxXmlText('a'#9'b'#10'c'), 'a'#9'b'#10'c');
  { The rest have no escape at all -- dropped, not encoded. }
  Check('xml/a-nul-is-dropped', SpxXmlText('a'#0'b'), 'ab');
  Check('xml/other-controls-are-dropped', SpxXmlText('a'#1#7#11#12#27'b'), 'ab');
  { UTF-8 goes through as bytes; the engine's own sentinels are private-use and legal. }
  Check('xml/utf8-passes', SpxXmlText('привет'), 'привет');
  Check('xml/a-sentinel-passes', SpxXmlText('a'#$EE#$80#$80'b'), 'a'#$EE#$80#$80'b');

  { A CARRIAGE RETURN IS A REFERENCE, not a raw byte: XML normalises a literal CR to LF on
    the way back, so writing it raw silently rewrites the cell -- and Windows templates are
    full of CRLF. }
  Check('xml/cr-becomes-a-reference', SpxXmlText('a'#13#10'b'), 'a&#13;'#10'b');
  Check('xml/a-lone-cr-too', SpxXmlText('a'#13'b'), 'a&#13;b');

  { BYTES THAT ARE NOT UTF-8 ARE DROPPED. The file layer reads bytes and transcodes nothing,
    so a template saved in a legacy Windows codepage arrives here as invalid UTF-8 -- and one
    such byte makes a workbook that nothing will open. This is "привет" in CP-1251. }
  Check('xml/legacy-bytes-are-dropped', SpxXmlText('a'#$EF#$F0#$E8#$E2#$E5#$F2'b'), 'ab');
  Check('xml/a-lone-continuation-byte-is-dropped', SpxXmlText('a'#$80'b'), 'ab');
  Check('xml/a-truncated-sequence-is-dropped', SpxXmlText('a'#$D0), 'a');
  { An overlong encoding is invalid UTF-8 and the classic way to smuggle a forbidden
    character past a filter that only looks at the first byte. }
  Check('xml/an-overlong-encoding-is-dropped', SpxXmlText('a'#$C0#$AF'b'), 'ab');
  { Legal UTF-8, but characters XML forbids. }
  Check('xml/uffff-is-dropped', SpxXmlText('a'#$EF#$BF#$BF'b'), 'ab');
  Check('xml/a-surrogate-half-is-dropped', SpxXmlText('a'#$ED#$A0#$80'b'), 'ab');
  { Four-byte sequences are ordinary text. }
  Check('xml/an-emoji-passes', SpxXmlText('a'#$F0#$9F#$99#$82'b'), 'a'#$F0#$9F#$99#$82'b');

  { ── and the ATTRIBUTE escaper, which needs more than the text one ── }

  { A quote ends an attribute. The sheet name went through the text escaper at first, so a
    sheet called `Акция "Лето"` produced a workbook no parser would open -- verified against
    fcl-xml, which rejects it outright. }
  Check('xmlattr/a-quote-is-escaped', SpxXmlAttr('Акция "Лето"'),
        'Акция &quot;Лето&quot;');
  { Tab and the line endings are normalised to spaces inside an attribute unless written as
    references, so "as given" needs them written out. }
  Check('xmlattr/tab-and-breaks-become-references', SpxXmlAttr('a'#9'b'#10'c'#13'd'),
        'a&#9;b&#10;c&#13;d');
  Check('xmlattr/angles-and-ampersand-too', SpxXmlAttr('a<b>&c'), 'a&lt;b&gt;&amp;c');

  dir := TempFolder + '-export';
  WipeFolder(dir);
  CreateDir(dir);
  list := TSpxVariantList.Create;
  try
    v.Seed := 10; v.Text := 'первый вариант';                       list.Add(v);
    v.Seed := 11; v.Text := 'второй'#10'в двух строках';            list.Add(v);
    v.Seed := 12; v.Text := '<p>третий</p> с & и "кавычками"';      list.Add(v);

    { ── .txt ── }

    opts := SpxDefaultTxtOpts;
    path := InDir(dir, 'plain.txt');
    CheckTrue('txt/writes', SpxWriteTxt(path, list, opts, rep));
    txt := TStringList.Create;
    try
      txt.LoadFromFile(path);
      { One line per variant is the format's promise, and the multi-line one is why the
        report has to say what it did. }
      CheckTrue('txt/one-line-per-variant', txt.Count = 3);
      Check('txt/first-line', txt[0], 'первый вариант');
      Check('txt/the-multiline-one-was-folded', txt[1], 'второй в двух строках');
      CheckTrue('txt/and-the-report-says-so', rep.Collapsed = 1);
      CheckTrue('txt/written-counts-them-all', rep.Written = 3);
    finally
      txt.Free;
    end;

    { The seed travels with the text when asked, because a line nobody can regenerate is a
      line nobody can fix. }
    opts.WithSeed := True;
    path := InDir(dir, 'seeded.txt');
    CheckTrue('txt/writes-with-seed', SpxWriteTxt(path, list, opts, rep));
    txt := TStringList.Create;
    try
      txt.LoadFromFile(path);
      Check('txt/seed-prefixes-the-line', txt[0], '10'#9'первый вариант');
    finally
      txt.Free;
    end;

    { Refusing is the other honest answer, and it must leave NO file rather than a partial
      one that looks like the export. }
    opts := SpxDefaultTxtOpts;
    opts.Breaks := spxTxtRefuse;
    path := InDir(dir, 'refused.txt');
    CheckTrue('txt/refuses-a-multiline-variant', not SpxWriteTxt(path, list, opts, rep));
    CheckTrue('txt/and-says-why', rep.Refused);
    CheckTrue('txt/and-leaves-no-file', not FileExists(path));

    { ── one file per variant ── }

    CheckTrue('perfile/writes', SpxWritePerFile(dir, 'v-', '.html', list, rep));
    CheckTrue('perfile/one-per-variant', rep.Written = 3);
    { Named by SEED, not by index: the name says what regenerates the file. }
    CheckTrue('perfile/named-by-seed', FileExists(InDir(dir, 'v-11.html')));
    txt := TStringList.Create;
    try
      txt.LoadFromFile(InDir(dir, 'v-11.html'));
      { And here the line break is KEPT -- this is the format that can hold it. }
      CheckTrue('perfile/keeps-the-line-break', txt.Count = 2);
    finally
      txt.Free;
    end;
    { A missing folder is refused rather than created behind the author's back. }
    CheckTrue('perfile/refuses-a-missing-folder',
              not SpxWritePerFile(InDir(dir, 'no-such-folder'), 'v-', '.txt', list, rep));

    { ── .xlsx, read back by unzipping it ── }

    path := InDir(dir, 'set.xlsx');
    CheckTrue('xlsx/writes', SpxWriteXlsx(path, 'Варианты', list, rep));
    CheckTrue('xlsx/file-exists', FileExists(path));

    ok := False;
    unzip := TUnZipper.Create;
    try
      unzip.FileName := path;
      unzip.OutputPath := InDir(dir, 'unzipped');
      CreateDir(unzip.OutputPath);
      unzip.UnZipAllFiles;
      ok := True;
    except
      { A zip that will not open is the one failure mode that needs no interpretation. }
      on E: Exception do ok := False;
    end;
    unzip.Free;
    CheckTrue('xlsx/is-a-readable-zip', ok);

    { The five parts a spreadsheet reader looks for. }
    CheckTrue('xlsx/has-content-types',
              FileExists(InDir(InDir(dir, 'unzipped'), '[Content_Types].xml')));
    CheckTrue('xlsx/has-a-workbook',
              FileExists(InDir(InDir(InDir(dir, 'unzipped'), 'xl'), 'workbook.xml')));
    CheckTrue('xlsx/has-a-sheet',
              FileExists(InDir(InDir(InDir(InDir(dir, 'unzipped'), 'xl'), 'worksheets'),
                               'sheet1.xml')));

    { Read VERBATIM, not through a TStringList: that one splits on the line breaks and rejoins
      with the platform's, so the #10 the writer put INSIDE a cell would come back as CRLF and
      the assertion below would fail for a reason that has nothing to do with the writer.
      (It did, on the first run.) }
    s := SpxReadTextFile(InDir(InDir(InDir(InDir(dir, 'unzipped'), 'xl'), 'worksheets'),
                               'sheet1.xml'));
    begin
      CheckTrue('xlsx/carries-the-seeds', (Pos('>10<', s) > 0) and (Pos('>12<', s) > 0));
      CheckTrue('xlsx/carries-the-text', Pos('первый вариант', s) > 0);
      { Markup arrives ESCAPED, not stripped: the cell shows the tags the engine produced. }
      CheckTrue('xlsx/escapes-markup', Pos('&lt;p&gt;третий&lt;/p&gt;', s) > 0);
      CheckTrue('xlsx/escapes-the-ampersand', Pos('&amp;', s) > 0);
      { The line break inside a variant is KEPT -- a cell holds it, which is what makes this
        the lossless format of the three. }
      CheckTrue('xlsx/keeps-a-line-break-in-a-cell', Pos('второй'#10'в двух строках', s) > 0);
      { Spaces at the edges of a cell are the author's, so the text node says so. }
      CheckTrue('xlsx/preserves-space', Pos('xml:space="preserve"', s) > 0);
      { The seed is a NUMBER. Written as a string, a spreadsheet sorts 10 before 9 and Excel
        flags every cell as a number stored as text -- so the check is the cell TYPE, not the
        digits, which a string cell would match just as well. }
      Check('xlsx/the-seed-is-a-number', FirstNumericCell(s), '10');
      CheckTrue('xlsx/and-not-a-string-cell', Pos('<is><t xml:space="preserve">10<', s) = 0);
    end;

    { PARSED, not searched. Both defects this section gates produce text a substring check is
      perfectly happy with. }
    Check('xlsx/the-sheet-part-is-well-formed',
          XmlError(InDir(InDir(InDir(InDir(dir, 'unzipped'), 'xl'), 'worksheets'),
                         'sheet1.xml')), '');
    Check('xlsx/the-workbook-part-is-well-formed',
          XmlError(InDir(InDir(InDir(dir, 'unzipped'), 'xl'), 'workbook.xml')), '');
    Check('xlsx/the-content-types-part-is-well-formed',
          XmlError(InDir(InDir(dir, 'unzipped'), '[Content_Types].xml')), '');

    s := SpxReadTextFile(InDir(InDir(InDir(dir, 'unzipped'), 'xl'), 'workbook.xml'));
    CheckTrue('xlsx/the-sheet-name-is-written-as-given', Pos('name="Варианты"', s) > 0);

    { ── the two shapes that used to produce a file nothing opens ── }

    { A sheet name with a quote in it, and a cell holding bytes that are not UTF-8. Written,
      unzipped, and PARSED -- the first version of this writer produced well-formed-looking
      text in both cases and a workbook no reader would accept. }
    bad := TSpxVariantList.Create;
    try
      v.Seed := 1; v.Text := 'легальный текст';                       bad.Add(v);
      { "привет" in CP-1251, i.e. what an untranscoded legacy template hands over. }
      v.Seed := 2; v.Text := 'a'#$EF#$F0#$E8#$E2#$E5#$F2'b';          bad.Add(v);
      v.Seed := 3; v.Text := 'строка'#13#10'с CRLF';                  bad.Add(v);
      path := InDir(dir, 'hostile.xlsx');
      CheckTrue('xlsx/writes-a-hostile-set', SpxWriteXlsx(path, 'Акция "Лето"', bad, rep));

      WipeFolder(InDir(dir, 'unzipped2'));
      CreateDir(InDir(dir, 'unzipped2'));
      unzip := TUnZipper.Create;
      try
        unzip.FileName := path;
        unzip.OutputPath := InDir(dir, 'unzipped2');
        unzip.UnZipAllFiles;
      finally
        unzip.Free;
      end;

      Check('xlsx/a-quoted-sheet-name-still-parses',
            XmlError(InDir(InDir(InDir(dir, 'unzipped2'), 'xl'), 'workbook.xml')), '');
      Check('xlsx/legacy-bytes-in-a-cell-still-parse',
            XmlError(InDir(InDir(InDir(InDir(dir, 'unzipped2'), 'xl'), 'worksheets'),
                           'sheet1.xml')), '');
      s := SpxReadTextFile(InDir(InDir(InDir(dir, 'unzipped2'), 'xl'), 'workbook.xml'));
      CheckTrue('xlsx/the-quote-is-escaped-not-dropped', Pos('&quot;Лето&quot;', s) > 0);
      { A CR survives as a reference, so the cell comes back with the break the engine
        produced rather than one the parser invented. }
      s := SpxReadTextFile(InDir(InDir(InDir(InDir(dir, 'unzipped2'), 'xl'), 'worksheets'),
                                 'sheet1.xml'));
      CheckTrue('xlsx/a-cr-survives-as-a-reference', Pos('&#13;', s) > 0);
    finally
      bad.Free;
    end;

    { An illegal tab name is repaired rather than passed on: Excel forbids these characters
      and openpyxl refuses the workbook outright. }
    CheckTrue('xlsx/an-illegal-sheet-name-is-repaired',
              SpxWriteXlsx(InDir(dir, 'named.xlsx'), 'a[b]c/d', list, rep));

    { ── names that are not names ── }

    { A prefix of `..\` wrote the export OUTSIDE the folder it was given, and on Windows a
      colon put the text into an alternate data stream behind a zero-byte file. Both measured
      before this guard existed. }
    CheckTrue('perfile/a-traversing-prefix-is-neutralised',
              SpxWritePerFile(dir, '..' + PathDelim + 'escaped-', '.txt', list, rep));
    CheckTrue('perfile/and-nothing-landed-outside-the-folder',
              not FileExists(InDir(ExtractFileDir(dir), 'escaped-10.txt')));
    CheckTrue('perfile/a-colon-prefix-is-neutralised',
              SpxWritePerFile(dir, 'a:b', '.txt', list, rep));
    CheckTrue('perfile/and-the-file-is-a-real-file',
              FileExists(InDir(dir, 'a_b10.txt')));

    { Nothing to write is not an error -- the tab will offer export before anything has been
      generated. }
    empty := TSpxVariantList.Create;
    try
      CheckTrue('export/an-empty-set-is-not-an-error',
                SpxWriteXlsx(InDir(dir, 'empty.xlsx'), 'x', empty, rep));
      Check('export/an-empty-xlsx-is-still-well-formed-once-unzipped',
            BoolToStr(FileExists(InDir(dir, 'empty.xlsx')), 'y', 'n'), 'y');
    finally
      empty.Free;
    end;
  finally
    list.Free;
    WipeFolder(dir);
  end;
end;

{ ── 9. the host's file layer ─────────────────────────────────────────────── }

procedure TestFileLayer;
var
  dir, s: string;
  tset: TSpxTemplateSet;
  ctx: TSpxContext;
begin
  { The pure rules first: they decide what a file MEANS, and they are the ones a call site
    would otherwise re-invent. }
  Check('files/eol-detects-crlf', SpxDetectEol('a'#13#10'b'), #13#10);
  Check('files/eol-detects-lf', SpxDetectEol('a'#10'b'), #10);
  Check('files/eol-detects-cr', SpxDetectEol('a'#13'b'), #13);
  { A lone CR at the very end must not read past the string looking for its LF. }
  Check('files/eol-cr-at-end', SpxDetectEol('a'#13), #13);
  Check('files/eol-none-is-lf', SpxDetectEol('one line, no terminator'), SPX_DEFAULT_EOL);

  CheckTrue('files/ends-with-eol', SpxEndsWithEol('a'#10));
  CheckTrue('files/no-trailing-eol', not SpxEndsWithEol('a'));
  CheckTrue('files/empty-has-no-eol', not SpxEndsWithEol(''));

  Check('files/normalize-mixed-to-lf', SpxNormalizeEol('a'#13#10'b'#13'c'#10'd', #10),
        'a'#10'b'#10'c'#10'd');
  Check('files/normalize-to-crlf', SpxNormalizeEol('a'#10'b', #13#10), 'a'#13#10'b');
  Check('files/normalize-touches-nothing-else', SpxNormalizeEol('Ёжик, «ёлка» — тире', #13#10),
        'Ёжик, «ёлка» — тире');

  Check('files/slug-keeps-case',
        SpxSlugOf('work' + PathDelim + 'Intro.spintax'), 'Intro');
  Check('files/slug-of-a-dotted-name', SpxSlugOf('intro.v2.spintax'), 'intro.v2');
  CheckTrue('files/ext-is-case-insensitive', SpxIsTemplateFile('X.SPINTAX'));
  { The 8.3 alias makes a `*.spintax` mask match this one; the filter must not. }
  CheckTrue('files/ext-not-a-longer-lookalike', not SpxIsTemplateFile('notes.spintaxbackup'));
  CheckTrue('files/ext-not-txt', not SpxIsTemplateFile('notes.txt'));

  { Then the bytes, against a real folder: mocking a filesystem would test the mock. }
  dir := TempFolder;
  WipeFolder(dir);
  ForceDirectories(dir);
  try
    { Round trip, including the two things an editor most easily breaks: a file with no
      trailing terminator, and non-ASCII text. }
    s := 'Ёжик'#10'вторая строка без хвоста';
    SpxWriteTextFile(InDir(dir, 'rt.spintax'), s);
    Check('files/round-trip-is-byte-identical', SpxReadTextFile(InDir(dir, 'rt.spintax')), s);

    SpxWriteTextFile(InDir(dir, 'bom.spintax'), #$EF#$BB#$BF + 'после метки');
    Check('files/bom-is-stripped-on-read', SpxReadTextFile(InDir(dir, 'bom.spintax')),
          'после метки');
    { And never written: the family's other engines read these files, and a BOM is a stray
      character to them. }
    SpxWriteTextFile(InDir(dir, 'nobom.spintax'), 'чистый');
    Check('files/no-bom-is-added-on-write', SpxReadTextFile(InDir(dir, 'nobom.spintax')), 'чистый');

    WipeFolder(dir);
    ForceDirectories(dir);
    SpxWriteTextFile(InDir(dir, 'Intro.spintax'), 'вступление {a|b}');
    SpxWriteTextFile(InDir(dir, 'frag.spintax'), 'ФРАГМЕНТ');
    SpxWriteTextFile(InDir(dir, 'notes.txt'), 'not a template');
    SpxWriteTextFile(InDir(dir, 'lookalike.spintaxbackup'), 'not a template either');
    ForceDirectories(InDir(dir, 'sub.spintax'));   { a DIRECTORY named like a member }

    tset := SpxLoadTemplateSet(dir);
    try
      CheckTrue('files/set-has-exactly-the-templates', tset.Count = 2);
      CheckTrue('files/set-keeps-the-name-case', tset.ContainsKey('Intro'));
      { The rule the whole ADR turns on: a slug is compared exactly, so the filesystem's
        idea of case cannot make the preview disagree with the other engines. }
      CheckTrue('files/set-lookup-is-exact', not tset.ContainsKey('intro'));
      CheckTrue('files/set-skips-other-extensions', not tset.ContainsKey('notes'));
      CheckTrue('files/set-skips-longer-lookalikes', not tset.ContainsKey('lookalike'));
      CheckTrue('files/set-skips-directories', not tset.ContainsKey('sub'));
      Check('files/set-carries-the-text', tset['frag'], 'ФРАГМЕНТ');

      { The loop closed: folder -> set -> engine. Everything above is a rule about names;
        this is the only check that proves an #include in a document actually reaches a
        file on disk. }
      ctx := SpxContext('en', nil, tset);
      s := SpxRenderSample('#include "frag"', ctx);
      CheckTrue('files/include-resolves-from-the-folder', Pos('ФРАГМЕНТ', s) > 0);
      s := SpxRenderSample('#include "Frag"', ctx);
      CheckTrue('files/include-target-is-case-exact', Pos('ФРАГМЕНТ', s) = 0);
    finally
      tset.Free;
    end;

    tset := SpxLoadTemplateSet('');
    try
      CheckTrue('files/no-folder-is-an-empty-set', tset.Count = 0);
    finally
      tset.Free;
    end;
  finally
    WipeFolder(dir);
  end;
end;

begin
  SpxInitHost;
  {$IFDEF FPC}
  SetTextCodePage(Output, CP_UTF8);
  {$ENDIF}

  TestHostContract;
  TestEngineBaseline;
  TestRenderPath;
  TestIncludeResolution;
  TestAnalysisPath;
  TestTokenizer;
  TestBracketMatching;
  TestDemoTemplate;
  TestDiagMarks;
  TestPanelRows;
  TestSelectionPolicy;
  TestPageDocument;
  TestDirectiveEditing;
  TestModelDirIndex;
  TestKeepRuntime;
  TestValidationCache;
  TestDedupe;
  TestExport;
  TestFileLayer;
  TestEngineThread;
  TestEngineBatch;

  Writeln(Format('studio tests: %d checks, %d failed', [Checks, Failures]));
  if Failures > 0 then ExitCode := 1;
end.
