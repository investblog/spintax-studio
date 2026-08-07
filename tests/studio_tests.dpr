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
  {$IFDEF DARWIN}BaseUnix,{$ENDIF}
  { zipper for reading an exported .xlsx back apart -- the writer is only worth as much as
    the check that opens what it wrote. }
  SysUtils, Classes, Generics.Collections, zipper, StrUtils, DOM, XMLRead,
  {$IFDEF FPC}
  Spintax, SpxStudio, SpxTokens, SpxGroups, SpxDemo, SpxDedupe, SpxExport, SpxHtmlScan,
  SpxGsaImport, SpxCount,
  SpxFiles, SpxEngineThread, SpxStrIds, SpxStrings, SpxIcons, SpxFlags, SpxSettings,
  SpxEditorFont, SpxHelpText, SpxHelpNav, SpxAbout, SpxBrandMark, SpxCompanyMark, SpxSevIcons;
  {$ELSE}
  Spintax in '..\engine\src\Spintax.pas',
  SpxStudio in '..\src\SpxStudio.pas',
  SpxTokens in '..\src\SpxTokens.pas',
  SpxDemo in '..\src\SpxDemo.pas',
  SpxDedupe in '..\src\SpxDedupe.pas',
  SpxExport in '..\src\SpxExport.pas',
  SpxHtmlScan in '..\src\SpxHtmlScan.pas',
  SpxGroups in '..\src\SpxGroups.pas',
  SpxGsaImport in '..\src\SpxGsaImport.pas',
  SpxCount in '..\src\SpxCount.pas',
  SpxFiles in '..\gui\SpxFiles.pas',
  SpxEngineThread in '..\gui\SpxEngineThread.pas',
  SpxStrings in '..\gui\SpxStrings.pas',
  SpxIcons in '..\gui\SpxIcons.pas',
  SpxFlags in '..\gui\SpxFlags.pas',
  SpxSettings in '..\gui\SpxSettings.pas',
  SpxEditorFont in '..\gui\SpxEditorFont.pas',
  SpxHelpText in '..\gui\SpxHelpText.pas',
  SpxHelpNav in '..\gui\SpxHelpNav.pas',
  SpxAbout in '..\gui\SpxAbout.pas',
  SpxBrandMark in '..\gui\SpxBrandMark.pas',
  SpxCompanyMark in '..\gui\SpxCompanyMark.pas',
  SpxSevIcons in '..\gui\SpxSevIcons.pas';
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
  { The bytes settle a whitespace bug and nothing else. Most of what this suite compares is
    now sentences -- a caption that overflowed its budget, a diagnostic in the wrong language
    -- and reading those as hex is a puzzle nobody should have to solve at a red build. }
  Writeln('     want "', Copy(want, 1, 200), '"');
  Writeln('     got  "', Copy(got, 1, 200), '"');
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

  { ── THE LINE ENDINGS OF THE DOCUMENT ARE PART OF THE DOCUMENT ──

    A directive line ending in LF disappears whole; the same line ending in CRLF leaves its
    LF behind, i.e. a blank line. So the same template rendered with the two endings is not
    the same output, and a host that hands the engine its editor's platform endings previews
    a file that does not exist.

    Measured the hard way: a 116 KB template with a hundred and fifty `#set` lines, LF on
    disk, produced one blank line at the top as itself and thirty-five once normalised to
    CRLF -- and the source view then opened on a screenful of nothing, reported twice as
    "the source view is broken". The window sends SpxNormalizeEol(editor, the file's ending)
    because of this. }
  { A directive in the PRELUDE -- before any content -- is consumed whole, either way. This
    is why a small example shows nothing: put two directives at the top of a document and the
    two endings agree. }
  Check('eol/a-leading-directive-block-is-consumed-lf',
        SpxRenderSample('#set %a% = 1'#10'#set %b% = 2'#10'Текст',
                        SpxSeededContext('ru', nil, 1)), 'Текст');
  Check('eol/a-leading-directive-block-is-consumed-crlf',
        SpxRenderSample('#set %a% = 1'#13#10'#set %b% = 2'#13#10'Текст',
                        SpxSeededContext('ru', nil, 1)), 'Текст');

  { A directive AFTER content is where they part company: with LF nothing of it remains, with
    CRLF its LF does -- one blank line per directive. Reduced by delta debugging from a real
    116 KB template down to four lines. }
  Check('eol/a-directive-after-content-leaves-nothing-on-lf',
        SpxRenderSample('Раз'#10#10'#set %a% = 1'#10'Два', SpxSeededContext('ru', nil, 1)),
        'Раз'#10#10'Два');
  Check('eol/but-leaves-a-blank-line-on-crlf',
        SpxRenderSample(SpxNormalizeEol('Раз'#10#10'#set %a% = 1'#10'Два', #13#10),
                        SpxSeededContext('ru', nil, 1)),
        'Раз'#13#10#13#10#10'Два');
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

  (* ---- AND THE TARGET ON A LATER LINE IS NOW READ, which is what the state above is for.

     The keyword is still `text`, deliberately and permanently: a forward-only scan cannot know
     while it looks at `#include` whether a target ever arrives, and SynEdit does not re-paint a
     line backwards. What changed is that the TARGET is claimed once it does arrive -- the half
     that says which file, and the half SpxCount needed to stop calling these documents a lower
     bound. ---- *)
  st := Default(TSpxScanState); st.LineEmpty := True;
  Check('scan/include-keyword-alone-waits', Scan('#include', st), 'text(#include)0');
  CheckTrue('scan/include-keyword-alone-sets-the-wait', st.IncludeOpen);
  Check('scan/include-target-on-the-next-line', Scan('"frag"', st), 'str("frag")0');
  CheckTrue('scan/include-target-ends-the-wait', not st.IncludeOpen);

  { Leading gap on the target's line is part of the anchor's run, not content. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('#include', st);
  Check('scan/include-target-after-indent', Scan('   "frag"', st), 'text(   )0 str("frag")0');

  { A whitespace-only line between the two keeps the wait: the anchor's class is `+`. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('#include', st);
  Scan('  ', st);
  CheckTrue('scan/include-wait-survives-a-blank-line', st.IncludeOpen);
  Check('scan/include-target-after-a-blank-line', Scan('"frag"', st), 'str("frag")0');

  { Anything else ends the wait and was never an include -- measured, the engine reports none. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('#include', st);
  Check('scan/include-then-prose-is-text', Scan('x "frag"', st), 'text(x "frag")0');
  CheckTrue('scan/include-then-prose-ends-the-wait', not st.IncludeOpen);

  { The engine allows only gap behind the target -- `#include` LF `"frag" junk` is no include
    at all -- so a target with prose behind it is not claimed either. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('#include', st);
  Check('scan/include-target-with-junk-is-text', Scan('"frag" junk', st),
        'text("frag" junk)0');

  { A trailing tab is gap and does not spoil it. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('#include', st);
  Check('scan/include-target-with-trailing-gap', Scan('"frag"'#9, st),
        'str("frag")0 text('#9')0');

  { Not line-leading is not a directive, so nothing waits. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('text #include', st);
  CheckTrue('scan/mid-line-include-does-not-wait', not st.IncludeOpen);

  { The wait crosses SynEdit's range pointer, or it does not survive a repaint. }
  st := Default(TSpxScanState); st.LineEmpty := True;
  Scan('#include', st);
  Check('scan/the-wait-packs-and-unpacks',
        BoolToStr(SpxUnpackState(SpxPackState(st)).IncludeOpen, True), BoolToStr(True, True));

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

{ The construct's separators as `a,b,c`, so a wrong set is a wrong string. }
function Seps(const Text: string; AOpen, AClose: Integer): string;
var o: TSpxOffsets; i: Integer;
begin
  o := SpxSeparatorsOf(Text, AOpen, AClose);
  Result := '';
  for i := 0 to High(o) do
  begin
    if Result <> '' then Result := Result + ',';
    Result := Result + IntToStr(o[i]);
  end;
end;

{ And what stands at those offsets, which is the readable half of the same fact. }
function SepChars(const Text: string; AOpen, AClose: Integer): string;
var o: TSpxOffsets; i: Integer;
begin
  o := SpxSeparatorsOf(Text, AOpen, AClose);
  Result := '';
  for i := 0 to High(o) do Result := Result + '[' + Copy(Text, o[i], 1) + ']';
end;

{ The construct a separator belongs to, as `open..close`, or `-` when the offset is not one.
  A string, so a wrong construct is a wrong answer rather than a pair of numbers to compare by
  hand. }
function ConstructAt(const Text: string; AOffset: Integer): string;
var o, c: Integer; seps: TSpxOffsets;
begin
  if SpxConstructOf(Text, AOffset, o, c, seps) then
    Result := IntToStr(o) + '..' + IntToStr(c)
  else
    Result := '-';
end;

{ And the separators it handed back with the pair -- the caller draws THESE, so they are the
  half worth checking separately from the pair. }
function ConstructSeps(const Text: string; AOffset: Integer): string;
var o, c, i: Integer; seps: TSpxOffsets;
begin
  Result := '';
  if not SpxConstructOf(Text, AOffset, o, c, seps) then Exit('-');
  for i := 0 to High(seps) do
  begin
    if Result <> '' then Result := Result + ',';
    Result := Result + IntToStr(seps[i]);
  end;
end;

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
  { ── the construct's own separators, for the highlight that shows where it divides ── }

  Check('seps/a-brace-groups-pipes', Seps('{a|b|c}', 1, 7), '3,5');
  { NOT the nested group's. Depth is what tells them apart, measured on the scanner: the outer
    pipes are depth 1 and the inner one depth 2. }
  Check('seps/nested-pipes-are-not-ours', Seps('{a|{x|y}|c}', 1, 11), '3,9');
  { ...and asked about the INNER pair, only the inner one is. }
  Check('seps/the-inner-pair-gets-its-own', Seps('{a|{x|y}|c}', 4, 8), '6');
  { A head is not a separator, whatever it contains -- the token kinds decide, so a
    conditional's flag, a plural's count and a permutation's config are all skipped for free. }
  Check('seps/a-conditional-head-is-not-one', Seps('{?flag?a|b}', 1, 11), '9');
  Check('seps/a-plural-head-is-not-one', Seps('{plural %n%: one|few|many}', 1, 26), '17,21');
  Check('seps/a-permutation-config-is-not-one', Seps('[<sep=", ">a|b]', 1, 15), '13');
  { A permutation's trailing `<br>` IS a separator -- the engine reads it as the one placed
    before the next element, which is why the highlighter paints it as config and not as text. }
  Check('seps/a-trailing-separator-counts', SepChars('[a<br>|b]', 1, 9), '[<][|]');
  { A single variant divides nowhere. }
  Check('seps/one-variant-has-no-separator', Seps('{only}', 1, 6), '');
  { Across lines, where the state has to carry: an offset must not drift on the terminator. }
  { The closing brace's REAL offset, so these pin the boundary rather than merely sitting
    inside it: 9 with two LFs, 7 with one CRLF. }
  Check('seps/across-lines', SepChars('{a'#10'|b'#10'|c}', 1, 9), '[|][|]');
  Check('seps/across-crlf', SepChars('{a'#13#10'|b}', 1, 7), '[|]');
  { A pipe inside a COMMENT is not a separator, because it is not a pipe. }
  { 12, not 11: 11 is the `/` that CLOSES the comment. The first version of this check said 11
    and the function said 12 -- the function was right, and the miscount is worth the note
    because a separator list is exactly the kind of answer nobody verifies by hand twice. }
  Check('seps/a-pipe-in-a-comment-is-not-one', Seps('{a/# x|y #/|b}', 1, 14), '12');
  { Nonsense in, nothing out -- never a guess. }
  Check('seps/not-a-bracket-gives-nothing', Seps('plain text', 3, 7), '');
  Check('seps/a-reversed-pair-gives-nothing', Seps('{a|b}', 5, 1), '');
  Check('seps/out-of-range-gives-nothing', Seps('{a|b}', 1, 99), '');

  (* ── and back the other way: the construct a SEPARATOR divides ─────────────────────
     The reader reported this half missing: the highlight ran from a bracket and not from a
     `|`. Measured before it was written -- a caret on either pipe of `{a|b|c}` found nothing
     at all, because the matcher exits unless the character under it is a bracket.

     Written in the parenthesis-star form, because this quotes the language and a closing
     brace inside a brace comment ends it -- which it did, twice in one afternoon. Nor may
     the two forms be nested: FPC ends this comment at the first star-paren it meets. *)

  Check('construct/a-pipe-finds-its-braces', ConstructAt('{a|b|c}', 3), '1..7');
  Check('construct/the-second-pipe-too', ConstructAt('{a|b|c}', 5), '1..7');
  { And it hands back the same separators the bracket case draws, which is the point: the
    construct lights whole, from either end of the relation. }
  Check('construct/it-brings-the-separators', ConstructSeps('{a|b|c}', 3), '3,5');
  Check('construct/the-same-set-as-from-the-bracket', ConstructSeps('{a|b|c}', 3),
        Seps('{a|b|c}', 1, 7));

  { NESTING, from the inside out: a pipe answers with the construct it divides and not with
    the one around it. }
  Check('construct/an-inner-pipe-gets-the-inner-pair', ConstructAt('{a|{x|y}|c}', 6), '4..8');
  Check('construct/an-outer-pipe-gets-the-outer-pair', ConstructAt('{a|{x|y}|c}', 3), '1..11');
  Check('construct/and-the-outer-one-after-it', ConstructAt('{a|{x|y}|c}', 9), '1..11');
  Check('construct/the-inner-pair-brings-its-own', ConstructSeps('{a|{x|y}|c}', 6), '6');

  { A permutation's trailing separator is one, at its `<` -- the same token the bracket case
    already marks. }
  Check('construct/a-trailing-separator-counts', ConstructAt('[a<br>|b]', 3), '1..9');
  { A permutation's CONFIG is not, though it also starts with `<`. }
  Check('construct/a-config-is-not-a-separator', ConstructAt('[<sep=", ">a|b]', 2), '-');

  { Not a separator, not an answer. A caret merely inside a group lights nothing: the
    highlight is about structure the caret stands on. }
  Check('construct/ordinary-text-inside-gets-nothing', ConstructAt('{a|b|c}', 2), '-');
  Check('construct/a-brace-is-the-other-rule''s-business', ConstructAt('{a|b|c}', 1), '-');
  Check('construct/a-pipe-outside-anything-gets-nothing', ConstructAt('a | b', 3), '-');
  Check('construct/a-pipe-in-a-comment-gets-nothing', ConstructAt('{a/# x|y #/|b}', 7), '-');
  { The comment's own pipe is not one; the pipe AFTER the comment still is. }
  Check('construct/the-pipe-after-a-comment-still-is', ConstructAt('{a/# x|y #/|b}', 12),
        '1..14');

  { A mismatched pair answers nothing and does not climb to the construct outside it -- the
    same rule SpxMatchBracket states for a brace closed by a square bracket. }
  Check('construct/a-mismatched-pair-gives-nothing', ConstructAt('{a|b]', 3), '-');
  Check('construct/and-does-not-climb-out-of-one', ConstructAt('{x{a|b]y}', 5), '-');

  (* A PERMUTATION'S CONFIG IS NOT CODE, and the brackets inside it open nothing. Found by
     fuzzing eighty thousand documents in review: `[x|[<sep="{">a|b]|y]` made the matcher
     disagree with its own tokenizer -- the brace in the quoted separator was counted as an
     opener, and the phantom pair swallowed the `]` that really closes the inner permutation,
     so the editor lit `4..20` and painted a separator this rule then declined to answer for.
     Both walks now ask the tokenizer's own PermConfigLength and skip the config whole. *)
  Check('construct/a-brace-in-a-config-does-not-move-the-pair',
        IntToStr(SpxMatchBracket('[x|[<sep="{">a|b]|y]', 4)), '17');
  Check('construct/nor-a-brace-in-a-config-of-its-own',
        IntToStr(SpxMatchBracket('[<sep="}">a|b]', 1)), '14');
  { AND A BLANK BEFORE THE `<` DOES NOT REVIVE IT. The engine left-trims a permutation's first
    part before asking whether it opens a config, and so does the tokenizer -- a walk that
    wanted the `<` against the `[` left the whole defect alive behind one space. Found by
    review, after the first fix's own comment claimed to ask the tokenizer rather than decide
    again. }
  Check('construct/a-space-before-the-config-changes-nothing',
        IntToStr(SpxMatchBracket('[x|[ <sep="{">a|b]|y]', 4)), '18');
  Check('construct/nor-does-it-for-a-closing-bracket-in-one',
        IntToStr(SpxMatchBracket('[ <sep="]">a|b]', 1)), '15');
  Check('construct/and-the-spaced-inner-pipe-still-lands',
        ConstructAt('[x|[ <sep="{">a|b]|y]', 16), '4..18');
  { And the two rules agree about every pipe in it, which is the disagreement itself. }
  Check('construct/the-inner-pipe-gets-the-inner-permutation',
        ConstructAt('[x|[<sep="{">a|b]|y]', 15), '4..17');
  Check('construct/and-the-outer-ones-the-outer',
        ConstructAt('[x|[<sep="{">a|b]|y]', 3) + ' ' + ConstructAt('[x|[<sep="{">a|b]|y]', 18),
        '1..20 1..20');

  { Nonsense in, nothing out. }
  Check('construct/before-the-text-gives-nothing', ConstructAt('{a|b}', 0), '-');
  Check('construct/past-the-text-gives-nothing', ConstructAt('{a|b}', 99), '-');
  Check('construct/an-unclosed-construct-gives-nothing', ConstructAt('{a|b', 3), '-');

  { Across lines, where the offsets have to survive the terminator -- the same boundary the
    separator checks above pin, asked from the other side. }
  Check('construct/across-lines', ConstructAt('{a'#10'|b'#10'|c}', 4), '1..9');
  Check('construct/across-crlf', ConstructAt('{a'#13#10'|b}', 5), '1..7');
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
    { Which batch's rows to keep, and how many arrived from another one. The thread delivers
      the render already in flight when a batch is replaced -- by design -- so a probe that
      kept everything was counting two batches as one, which is what made this test fail one
      run in sixteen. }
    Want: Integer;
    Strays: Integer;
    StrayIds: string;
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
    if (Want <> 0) and (P.Id <> Want) then
    begin
      Inc(Strays);
      if Pos(IntToStr(P.Id), StrayIds) = 0 then StrayIds := StrayIds + IntToStr(P.Id) + ' ';
    end
    else
    begin
      if Kept = nil then Kept := TSpxVariantList.Create;
      Kept.Add(P.Variant);
    end;
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

    (* WHOSE ANSWER IS THIS? The window decides the help's insert offer when a result lands,
       and it used to decide it from what was on SCREEN at that moment -- so a document render
       still in flight when the reader opened the help and clicked a broken example set that
       example's offer from the document's own clean verdict. Measured by review: the offer
       stood for 16 ms over a template with an unclosed brace.

       So the identity travels with the answer. These two checks are that round trip, and the
       THIRD is why HelpSet is read with it: `Default` zeroes HelpExample, and zero is a real
       example -- the same trap this record's own comment describes, one field along. *)
    job.Id := 8;
    job.Text := 'документ';
    job.HelpSet := False;
    job.HelpExample := -1;
    th.Post(job);
    CheckTrue('thread/delivers-the-eighth', PumpUntil(probe, 8, 5000));
    CheckTrue('thread/a-document-answer-says-it-is-not-about-the-help',
              not probe.Last.HelpSet);

    job.Id := 9;
    job.HelpSet := True;
    job.HelpLang := 0;
    job.HelpExample := 4;
    SpxHelpExample(0, 4, job.Text);
    th.Post(job);
    CheckTrue('thread/delivers-the-ninth', PumpUntil(probe, 9, 5000));
    CheckTrue('thread/a-help-answer-carries-the-example-it-rendered',
              probe.Last.HelpSet and (probe.Last.HelpExample = 4));

    CheckTrue('thread/a-defaulted-result-is-about-no-example',
              not Default(TSpxJobResult).HelpSet);

    (* AND THE COSMETIC STAGE, THROUGH THE WORKER RATHER THAN BESIDE IT. An outside review on
       2026-08-06 pointed at the gap and was right about it: the GSA checks call the engine
       directly, so nothing gated the one hop that actually decides a converted template's
       fate -- the window sets NoPostProcess on the job, and the worker has to turn that into
       `TSpContext.PostProcess`.

       Written NEGATIVE for the reason the field is: these records are filled by hand, and a
       Boolean nobody set is False. The first check is the default -- an ordinary job is
       post-processed -- and the second is the GSA document's. `a,b` is the smallest text that
       tells them apart: the typographer gives it a space AND a capital, and neither happens
       when the stage is off. *)
    job.Id := 10;
    job.Text := 'a,b';
    job.Fragment := '';
    job.HelpSet := False;
    job.HelpExample := -1;
    job.Seeded := False;
    job.NoPostProcess := False;
    th.Post(job);
    CheckTrue('thread/delivers-the-tenth', PumpUntil(probe, 10, 5000));
    Check('thread/an ordinary job is post-processed', probe.Last.Preview, 'A, b');

    job.Id := 11;
    job.NoPostProcess := True;
    th.Post(job);
    CheckTrue('thread/delivers-the-eleventh', PumpUntil(probe, 11, 5000));
    Check('thread/a GSA job is rendered verbatim', probe.Last.Preview, 'a,b');
    job.NoPostProcess := False;

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
    probe.Want := 5;
    probe.Strays := 0;
    probe.StrayIds := '';
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
    CheckTrue('batchthread/and-the-seeds-start-at-the-new-base',
              (probe.Kept <> nil) and (probe.Kept.Count > 0) and (probe.Kept[0].Seed = 900));
    { AND ANY ROW THAT DID ARRIVE FROM THE REPLACED BATCH CARRIED ITS OWN ID. The thread
      finishes the render in flight, so a straggler is expected rather than wrong -- what
      would be wrong is a straggler indistinguishable from the new batch's rows, since the
      window tells them apart by exactly this. }
    Check('batchthread/a-straggler-carries-the-replaced-id [' + probe.StrayIds + ']',
          StringReplace(probe.StrayIds, '4 ', '', [rfReplaceAll]), '');
    { RESET, so the scenarios below fill Kept again. Without it the id-6 and id-8 requests
      accumulated into Strays and the next check added here would have measured nothing. }
    probe.Want := 0;

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
    rows := SpxPanelRows(r, spxLangRu);
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
            SpxDiagText('plural.arity', spxLangEn) <> 'plural.arity');
  Check('rows/unknown-code-falls-back-to-itself',
        SpxDiagText('something.new-in-v9', spxLangEn), 'something.new-in-v9');
  { And a note says what it is about, not just that it happened. }
  note.Kind := spxNoteCaseMismatch;
  note.Target := 'Intro';
  note.Hint := 'intro';
  CheckTrue('rows/note-text-carries-both-names',
            (Pos('Intro', SpxNoteText(note, spxLangEn)) > 0) and
            (Pos('intro', SpxNoteText(note, spxLangEn)) > 0));
  CheckTrue('rows/note-text-carries-both-names-ru',
            (Pos('Intro', SpxNoteText(note, spxLangRu)) > 0) and
            (Pos('intro', SpxNoteText(note, spxLangRu)) > 0));

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

    rows := SpxPanelRows(r, spxLangRu);
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

    rows := SpxPanelRows(r, spxLangRu);
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

  { ── when a selection change is worth a render at all ── }

  { A jump does not narrow the preview, so two jumps in a row ask for the same thing -- and
    the second must not restart the render. This is what made stepping through search hits
    re-render the whole document on every press of Enter. }
  CheckTrue('ask/a-jump-does-not-narrow',
            not SpxPreviewAsk(Sel(spxSelNormal, 2, 5, 2, 9, ''), Jumped(2, 5, 2, 9)).Narrowed);
  CheckTrue('ask/two-different-jumps-ask-for-the-same-thing',
            SpxPreviewSame(SpxPreviewAsk(Sel(spxSelNormal, 2, 5, 2, 9, ''), Jumped(2, 5, 2, 9)),
                           SpxPreviewAsk(Sel(spxSelNormal, 7, 1, 7, 4, ''), Jumped(7, 1, 7, 4))));
  { A selection the user made DOES narrow, and asking for a different span is a different
    ask. }
  CheckTrue('ask/a-manual-selection-narrows',
            SpxPreviewAsk(Sel(spxSelNormal, 2, 5, 2, 9, 'кусок'), NoJump).Narrowed);
  CheckTrue('ask/a-different-span-is-a-different-ask',
            not SpxPreviewSame(SpxPreviewAsk(Sel(spxSelNormal, 2, 5, 2, 9, 'a'), NoJump),
                               SpxPreviewAsk(Sel(spxSelNormal, 3, 1, 3, 6, 'b'), NoJump)));
  { The same span twice is the same ask -- a re-selection of what is already shown needs no
    work. }
  CheckTrue('ask/the-same-span-twice-is-the-same-ask',
            SpxPreviewSame(SpxPreviewAsk(Sel(spxSelNormal, 2, 5, 2, 9, 'a'), NoJump),
                           SpxPreviewAsk(Sel(spxSelNormal, 2, 5, 2, 9, 'a'), NoJump)));
  { And going from a fragment back to the whole document IS a change. }
  CheckTrue('ask/leaving-a-fragment-is-a-change',
            not SpxPreviewSame(SpxPreviewAsk(Sel(spxSelNormal, 2, 5, 2, 9, 'a'), NoJump),
                               SpxPreviewAsk(Sel(spxSelNone, 0, 0, 0, 0, ''), NoJump)));
  { An empty span is not a fragment however it was made. }
  CheckTrue('ask/an-empty-span-does-not-narrow',
            not SpxPreviewAsk(Sel(spxSelNormal, 4, 2, 4, 2, ''), NoJump).Narrowed);

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

{ ── 8az. the words the window says ───────────────────────────────────────── }

{ Length in CODE POINTS, which is what a caption's width is about -- `Сохранить` is nine
  characters and eighteen bytes, and a budget counted in bytes would reject every Russian
  string in the table. }
function CpLength(const S: string): Integer;
var i, n: Integer;
begin
  Result := 0;
  i := 1;
  while i <= Length(S) do
  begin
    SpCodePointAt(S, i, n);
    Inc(i, n);
    Inc(Result);
  end;
end;

{ The specifiers a format string carries, IN ARGUMENT ORDER: '%d of %s' -> 'd,s,'. A doubled
  '%%' is a literal percent sign and no specifier at all, so it is stepped over rather than
  read.

  Argument order, not textual order, because a translation may need the arguments the other
  way round -- Turkish says "%s dosyasına %d satır yazıldı" where English says "wrote %d rows
  to %s" -- and FPC writes that as `%1:s ... %0:d`. Comparing what is written left to right
  would call the correct translation wrong and the broken one right; comparing what lands in
  argument 0 and argument 1 is the thing that actually has to match. }
function Specifiers(const S: string): string;
var i, n, arg: Integer; types: array[0..15] of Char;
begin
  Result := '';
  for i := 0 to High(types) do types[i] := #0;
  arg := 0;
  i := 1;
  while i < Length(S) do
  begin
    if S[i] <> '%' then
    begin
      Inc(i);
      Continue;
    end;
    { An escaped percent consumes BOTH characters and produces nothing. Stepping by three,
      as this did, walked past a specifier standing right behind one -- '%%%d' recorded
      nothing at all. }
    if S[i + 1] = '%' then
    begin
      Inc(i, 2);
      Continue;
    end;
    Inc(i);
    { an explicit argument index, `%1:s`, which also moves the implicit counter after it }
    n := 0;
    while (i <= Length(S)) and (S[i] >= '0') and (S[i] <= '9') do
    begin
      n := n * 10 + (Ord(S[i]) - Ord('0'));
      Inc(i);
    end;
    if (i <= Length(S)) and (S[i] = ':') then
    begin
      arg := n;
      Inc(i);
    end;
    if (i <= Length(S)) and (arg <= High(types)) then types[arg] := S[i];
    Inc(arg);
    Inc(i);
  end;
  for i := 0 to High(types) do
    if types[i] <> #0 then Result := Result + types[i] + ',';
end;

{ The two generated sprites. Nothing here draws -- that needs a window -- but three things
  can be settled without one: that there is a flag for every language and not one more, that
  the picker never returns a strip too big for the space asked for (an image list draws at its
  own size, so a bigger one is CLIPPED), and that every size it can return has bytes behind it.
  The count is the one that would rot silently: a fifteenth language is an edit in one file and
  a flag strip that is still fourteen wide, with the last language showing the wrong flag. }
{ Every frame of the application icon, by the two fields that decide who can read it. }
procedure CheckIconFrames;
const ICO = 'assets/brand/spintax.ico';
var f: TMemoryStream; n, i, at: Integer; w, h: Byte; size_, offset: LongWord; sig: array[0..3] of Byte;
begin
  if not FileExists(ICO) then
  begin
    CheckTrue('icon/the file is where the suite expects it', False);
    Exit;
  end;
  f := TMemoryStream.Create;
  try
    f.LoadFromFile(ICO);
    f.Position := 4;
    n := 0;
    f.Read(n, 2);
    CheckTrue('icon/has frames', n > 0);
    for i := 0 to n - 1 do
    begin
      at := 6 + i * 16;
      f.Position := at;
      f.Read(w, 1);
      f.Read(h, 1);
      f.Position := at + 8;
      f.Read(size_, 4);
      f.Read(offset, 4);
      f.Position := offset;
      f.Read(sig, 4);
      { A PNG frame is legal only where the entry says width 0. Anywhere else LCL reads it as
        a DIB and the application does not start. }
      if (sig[0] = $89) and (sig[1] = Ord('P')) and (sig[2] = Ord('N')) and (sig[3] = Ord('G')) then
        Check(Format('icon/frame-%d-is-a-dib-not-a-png', [i]),
          Format('PNG at %dx%d', [w, h]), 'DIB')
      else
        { and a DIB starts with a 40-byte BITMAPINFOHEADER }
        Check(Format('icon/frame-%d-has-a-bitmapinfoheader', [i]),
          IntToStr(sig[0] + sig[1] * 256 + sig[2] * 65536 + sig[3] * 16777216), '40');
      CheckTrue(Format('icon/frame-%d-is-inside-the-file', [i]),
        (offset > 0) and (offset + size_ <= LongWord(f.Size)));
    end;
  finally
    f.Free;
  end;
end;

(* THE SETTINGS FILE. Everything here runs against a temporary path, so the suite never
   touches the profile of whoever runs it. What is worth checking is not the happy round trip
   -- it is that a file which has been edited by hand, half written, or written by a later
   version cannot stop the program from starting or silently change a setting nobody chose. *)
(* THE EDITOR'S FONT. The choice is a pure function over a cascade and a callback, so this
   drives it with a fake that answers from a table -- no fonts, no window, no Windows. What is
   worth pinning is not that a list is walked in order: it is that "installed" and "can draw
   this text" are different questions, and that a family the user NAMED is not kept when the
   machine can no longer honour it. *)
var
  FontsHere: string;      { families the fake says are installed, separated by | }
  CjkHere: string;        { of those, the ones that can draw non-Latin }
  FontAsked: string;      { every family the chooser asked about, in order }

function FakeProbe(const AFamily, ASample: string): Boolean;
var needsCjk: Boolean; i: Integer;
begin
  FontAsked := FontAsked + AFamily + '|';
  Result := Pos('|' + AFamily + '|', '|' + FontsHere + '|') > 0;
  if not Result then Exit;
  { "CJK" here is any byte above the Latin range -- enough for a table-driven fake. }
  needsCjk := False;
  for i := 1 to Length(ASample) do
    if Ord(ASample[i]) >= $E0 then needsCjk := True;
  if needsCjk then
    Result := Pos('|' + AFamily + '|', '|' + CjkHere + '|') > 0;
end;

procedure TestEditorFont;
const
  CASCADE: array[0..3] of string = ('Cascadia Mono', 'Consolas', 'MS Gothic', 'NSimSun');
  { Two characters above U+FFFF, as their UTF-8 bytes: a grinning face and a CJK extension-B
    ideograph. Written as bytes rather than as literals so the file's own encoding cannot
    quietly change what is being tested. }
  EMOJI = #$F0#$9F#$98#$80;   { U+1F600 }
  EXT_B = #$F0#$A0#$80#$80;   { U+20000 }
var s: string;
begin
  { ── the sample ── }
  Check('editorfont/ascii-samples-to-one-letter', SpxFontSample('hello, world!'), 'A');
  Check('editorfont/nothing-still-samples-to-something', SpxFontSample(''), 'A');
  { Distinct characters only, and ASCII collapsed -- so a megabyte of prose and a line of it
    give the same answer. }
  Check('editorfont/cyrillic-is-deduplicated', SpxFontSample('аа бб аа'), 'A' + 'аб');
  Check('editorfont/a-long-run-is-still-short',
        IntToStr(Length(SpxFontSample(StringOfChar('x', 100000) + 'ё'))), '3');
  { A malformed byte does not hang or eat the rest. }
  CheckTrue('editorfont/a-stray-byte-does-not-hang',
            Length(SpxFontSample('ab' + Chr($80) + 'cd')) > 0);

  { A CHARACTER ABOVE U+FFFF IS A CHARACTER. It is sampled, deduplicated and counted like any
    other -- which sounds too obvious to test until you know what it cost: the Windows probe
    asks GDI about UTF-16 code units, an astral character is two of them, no font maps a lone
    surrogate, and so ONE emoji anywhere in a template made every family in the cascade answer
    "cannot draw this". The chooser returned nothing, the editors kept whatever family they
    had, and a Japanese document went on being drawn in a Latin one. The probe drops surrogates
    now; the sampler's side of the contract is that they arrive whole in the first place. }
  Check('editorfont/an-emoji-is-sampled', SpxFontSample('a' + EMOJI), 'A' + EMOJI);
  { No 'A' on these two: the letter stands in for ASCII the document HAS, and neither of these
    documents has any. }
  Check('editorfont/an-emoji-is-deduplicated', SpxFontSample(EMOJI + EMOJI), EMOJI);
  Check('editorfont/two-astral-characters-are-two',
        SpxFontSample(EMOJI + EXT_B), EMOJI + EXT_B);

  { MEMBERSHIP IS BY CHARACTER, not by byte string. The first version cut each character out
    and searched the answer for it, which on malformed input could match ACROSS a boundary and
    drop a character it had never seen -- measured on exactly this input, where the third
    sequence was found inside the first two and lost. The rewrite compares numbers, and it was
    not made for this: it was made because the search cost 64 ms per render on a 1.1 MB
    Cyrillic template (3 ms now, same answers). This is the correctness that came with it. }
  Check('editorfont/malformed-input-loses-nothing',
        SpxFontSample(#$E3#$E3#$81#$E3#$81#$C3#$E3#$81#$E3),
        #$E3#$E3#$81#$E3#$81#$C3#$E3#$81#$E3);
  { A sequence cut off by the end of the buffer stops the walk rather than reading past it. }
  Check('editorfont/a-truncated-tail-is-dropped', SpxFontSample('abc' + #$E3#$81), 'A');

  { ── the choice ── }
  FontsHere := 'Consolas|MS Gothic';
  CjkHere := 'MS Gothic';
  FontAsked := '';
  Check('editorfont/skips-what-is-not-installed',
        SpxChooseEditorFont('', 'A', CASCADE, @FakeProbe), 'Consolas');
  Check('editorfont/and-asked-in-cascade-order', FontAsked, 'Cascadia Mono|Consolas|');

  { The whole point of probing rather than listing: Consolas IS installed and cannot draw
    this, so the cascade must walk past it. }
  Check('editorfont/skips-what-cannot-draw-the-text',
        SpxChooseEditorFont('', SpxFontSample('日本語'), CASCADE, @FakeProbe), 'MS Gothic');

  { A named family wins ... }
  Check('editorfont/a-named-family-wins',
        SpxChooseEditorFont('MS Gothic', 'A', CASCADE, @FakeProbe), 'MS Gothic');
  { ... but not when the machine cannot honour it any more. }
  Check('editorfont/a-named-family-that-is-gone-falls-back',
        SpxChooseEditorFont('Menlo', 'A', CASCADE, @FakeProbe), 'Consolas');
  Check('editorfont/a-named-family-that-cannot-draw-falls-back',
        SpxChooseEditorFont('Consolas', SpxFontSample('日本語'), CASCADE, @FakeProbe),
        'MS Gothic');

  { Nothing acceptable is not a crash and not a wrong answer: it is an empty answer, which
    the window reads as "leave the font alone". }
  FontsHere := '';
  CjkHere := '';
  Check('editorfont/nothing-installed-gives-nothing',
        SpxChooseEditorFont('', 'A', CASCADE, @FakeProbe), '');
  s := SpxChooseEditorFont('', 'A', CASCADE, nil);
  Check('editorfont/no-probe-gives-nothing', s, '');

  { ── the size ── }
  Check('editorfont/the-default-is-twelve', IntToStr(SPX_EDITOR_SIZE), '12');
  { The point of a fixed default: a desktop at 9 pt does not decide how big a template is. }
  CheckTrue('editorfont/the-default-beats-a-small-desktop-font', SPX_EDITOR_SIZE >= 11);
  Check('editorfont/a-huge-size-is-clamped',
        IntToStr(SpxClampEditorSize(999)), IntToStr(SPX_EDITOR_SIZE_MAX));
  Check('editorfont/a-tiny-size-is-clamped',
        IntToStr(SpxClampEditorSize(-5)), IntToStr(SPX_EDITOR_SIZE_MIN));
  Check('editorfont/a-sensible-size-is-left-alone', IntToStr(SpxClampEditorSize(14)), '14');

  { The shipped cascade ends where the comment says it does. }
  Check('editorfont/the-cascade-starts-with-cascadia', SPX_EDITOR_FONTS[0], 'Cascadia Mono');
  Check('editorfont/and-ends-with-a-cjk-family',
        SPX_EDITOR_FONTS[High(SPX_EDITOR_FONTS)], 'MingLiU');
end;

procedure TestSettings;
var path: string; p, q: TSpxPrefs; f: TStringList;

  procedure Put(const AText: string);
  begin
    f.Text := AText;
    f.SaveToFile(path);
  end;

begin
  path := IncludeTrailingPathDelimiter(GetTempDir) + 'spx-prefs-test.txt';
  if FileExists(path) then DeleteFile(path);
  f := TStringList.Create;
  try
    { a file that is not there is not an error }
    p := SpxLoadPrefsFrom(path);
    q := SpxDefaultPrefs;
    CheckTrue('settings/absent-file-gives-the-defaults',
      (p.Lang = q.Lang) and (p.Panel = q.Panel) and (p.FontSize = q.FontSize) and
      (p.FontFamily = q.FontFamily) and
      (p.Theme = q.Theme) and (p.LangFollow = q.LangFollow) and
      (p.RailRight = q.RailRight) and (p.PreviewSource = q.PreviewSource) and
      (p.SlideWidth = q.SlideWidth));

    { the round trip, with every field away from its default }
    p.Lang := 'tr';
    p.LangFollow := True;
    p.RailRight := True;
    p.PreviewSource := True;
    p.Panel := 2;
    p.FontSize := 15;
    p.FontFamily := 'Consolas';
    p.Theme := spxThemeDark;
    p.SlideWidth := 420;
    p.GsaImport := True;
    CheckTrue('settings/saving-says-it-worked', SpxSavePrefsTo(path, p));
    q := SpxLoadPrefsFrom(path);
    Check('settings/lang-survives', q.Lang, 'tr');
    CheckTrue('settings/follow-survives', q.LangFollow);
    CheckTrue('settings/rail-side-survives', q.RailRight);
    CheckTrue('settings/preview-mode-survives', q.PreviewSource);
    Check('settings/panel-survives', IntToStr(q.Panel), '2');
    Check('settings/font-size-survives', IntToStr(q.FontSize), '15');
    Check('settings/font-family-survives', q.FontFamily, 'Consolas');
    CheckTrue('settings/theme-survives', q.Theme = spxThemeDark);
    Check('settings/slide-width-survives', IntToStr(q.SlideWidth), '420');
    CheckTrue('settings/gsa-import-survives', q.GsaImport);
    { AND IT IS OFF UNTIL SOMEBODY ASKS. A reader who has never used GSA must not find its
      import in their File menu, so the default is the one thing about this setting that a
      later edit must not quietly change. }
    CheckTrue('settings/gsa-import-is-off-by-default', not SpxDefaultPrefs.GsaImport);

    { a collapsed block is -1 and must not be clamped away }
    p.Panel := -1;
    SpxSavePrefsTo(path, p);
    Check('settings/collapsed-is-a-real-value', IntToStr(SpxLoadPrefsFrom(path).Panel), '-1');

    { NOISE. None of these may raise, and none may change a setting to something nobody
      chose -- an unreadable value means the default for that key and nothing else. }
    Put('');
    Check('settings/an-empty-file-is-the-defaults',
      IntToStr(SpxLoadPrefsFrom(path).Panel), '0');
    Put('this is not a settings file at all' + LineEnding + '{"json": true}' + LineEnding +
        '=' + LineEnding + '=nokey' + LineEnding + 'nokey');
    Check('settings/noise-is-the-defaults',
      IntToStr(SpxLoadPrefsFrom(path).FontSize), IntToStr(SPX_EDITOR_SIZE));
    Put('panel=banana' + LineEnding + 'font.size=' + LineEnding + 'theme=chartreuse' +
        LineEnding + 'rail.right=maybe');
    p := SpxLoadPrefsFrom(path);
    CheckTrue('settings/unreadable-values-fall-back',
      (p.Panel = 0) and (p.FontSize = SPX_EDITOR_SIZE) and (p.Theme = spxThemeLight) and
      (not p.RailRight));

    { the range is a promise: a hand-edited 999 must not make the editor a poster }
    Put('font.size=999');
    Check('settings/an-absurd-size-is-clamped',
      IntToStr(SpxLoadPrefsFrom(path).FontSize), IntToStr(SPX_EDITOR_SIZE_MAX));
    Put('font.size=-999');
    Check('settings/and-clamped-the-other-way',
      IntToStr(SpxLoadPrefsFrom(path).FontSize), IntToStr(SPX_EDITOR_SIZE_MIN));
    { A family is carried verbatim: this unit does not know which families exist, and the
      chooser already falls back when one cannot be honoured. }
    Put('font.family=Menlo');
    Check('settings/a-family-is-carried-verbatim',
      SpxLoadPrefsFrom(path).FontFamily, 'Menlo');
    Put('panel=7');
    Check('settings/a-panel-that-does-not-exist-is-clamped',
      IntToStr(SpxLoadPrefsFrom(path).Panel), '2');
    { The panel's width has the same promise: a hand-edited number cannot make it swallow the
      editor or shrink to a sliver. }
    Put('slide.width=5000');
    Check('settings/a-panel-wider-than-the-window-is-clamped',
      IntToStr(SpxLoadPrefsFrom(path).SlideWidth), IntToStr(SPX_SLIDE_MAX));
    Put('slide.width=1');
    Check('settings/and-narrower-than-useful',
      IntToStr(SpxLoadPrefsFrom(path).SlideWidth), IntToStr(SPX_SLIDE_MIN));
    Put('slide.width=banana');
    Check('settings/an-unreadable-width-is-the-default',
      IntToStr(SpxLoadPrefsFrom(path).SlideWidth), IntToStr(SPX_SLIDE_DEFAULT));

    { a key this build has never heard of is left alone rather than treated as a mistake --
      a file written by a later version must not lose its settings by being opened here }
    Put('theme=dark' + LineEnding + 'spellcheck=yes' + LineEnding + 'font.size=14');
    p := SpxLoadPrefsFrom(path);
    CheckTrue('settings/an-unknown-key-does-not-spoil-the-known-ones',
      (p.Theme = spxThemeDark) and (p.FontSize = 14));

    { comments and stray spacing, because a person edits this by hand }
    Put('# a comment' + LineEnding + '   theme  =  dark   ' + LineEnding + '  # another');
    CheckTrue('settings/comments-and-spacing-are-tolerated',
      SpxLoadPrefsFrom(path).Theme = spxThemeDark);

    { The real path: under the user's profile and never beside the .exe (spec §11), and its
      folder is a FIXED name. The second half is the one that bit -- with GetAppConfigDir the
      folder was Application.Title, a string that exists to be displayed, so renaming the
      window would have thrown away everyone's settings. }
    CheckTrue('settings/the-real-path-is-in-the-profile',
      (SpxPrefsPath <> '') and (Pos(LowerCase(ExtractFilePath(ParamStr(0))),
                                    LowerCase(SpxPrefsPath)) = 0));
    CheckTrue('settings/the-folder-is-a-fixed-name-not-a-caption',
      Pos('spintax-studio', LowerCase(SpxPrefsPath)) > 0);
  finally
    f.Free;
    if FileExists(path) then DeleteFile(path);
  end;
end;

{ A PNG's declared size, from IHDR: the first chunk, always, and its width and height are two
  big-endian 32-bit numbers at a fixed offset. Eight bytes of signature, four of chunk length,
  four of type, then the pair. No decoder needed to answer "how many cells is this". }
function PngDim(AData: Pointer; ALen, AOffset: Integer): Integer;
var b: PByte;
begin
  Result := -1;
  if (AData = nil) or (ALen < 24) then Exit;
  b := PByte(AData);
  Result := (Integer(b[AOffset]) shl 24) or (Integer(b[AOffset + 1]) shl 16) or
            (Integer(b[AOffset + 2]) shl 8) or Integer(b[AOffset + 3]);
end;

function PngWidth(AData: Pointer; ALen: Integer): Integer;
begin
  Result := PngDim(AData, ALen, 16);
end;

function PngHeight(AData: Pointer; ALen: Integer): Integer;
begin
  Result := PngDim(AData, ALen, 20);
end;

procedure TestSprites;
var i, w, h, len, wanted: Integer; p: Pointer;
begin
  Check('sprites/a-flag-for-every-language',
    IntToStr(SPX_FLAG_COUNT), IntToStr(Ord(High(TSpxLang)) - Ord(Low(TSpxLang)) + 1));

  { From the smallest strip up, what comes back must fit -- an image list draws at its own
    size, so one pixel too wide is a clipped glyph. Below the smallest strip there is nothing
    to return but the smallest strip, and the generated units say so; that floor is checked
    separately rather than folded in, because a picker that quietly returned something too
    big at 24 would otherwise hide behind the same rule. }
  for wanted := SPX_ICON_SIZES[Low(SPX_ICON_SIZES)] to 200 do
  begin
    if SpxIconPickSize(wanted) > wanted then
      Check(Format('sprites/icon-strip-fits-a-%dpx-face', [wanted]),
        IntToStr(SpxIconPickSize(wanted)), IntToStr(wanted));
    SpxFlagPickSize(wanted, w, h);
    if w > wanted then
      Check(Format('sprites/flag-strip-fits-a-%dpx-cell', [wanted]), IntToStr(w),
        IntToStr(wanted));
  end;

  { THE SEVERITY GLYPHS, held to the same account as the two strips above. What a drifted one
    does here is worse than a wrong toolbar picture: an image list slices a strip into
    SPX_SEV_COUNT columns whatever its real width, so a strip one cell short paints the ERROR
    glyph on a warning -- a list that lies about the level, silently, in the one panel whose
    whole job is to say it. }
  Check('sprites/a-glyph-for-every-level', IntToStr(SPX_SEV_COUNT), '3');
  Check('sprites/the-levels-are-in-the-order-the-panel-indexes-by',
        Format('%d,%d,%d', [SPX_SEV_ERROR, SPX_SEV_WARN, SPX_SEV_NOTE]), '0,1,2');
  for i := Low(SPX_SEV_SIZES) to High(SPX_SEV_SIZES) do
  begin
    p := SpxSevStrip(SPX_SEV_SIZES[i], len);
    CheckTrue(Format('sprites/severity-%d-is-a-png', [SPX_SEV_SIZES[i]]),
      (p <> nil) and (len > 8) and (PByte(p)[0] = $89) and (PByte(p)[1] = Ord('P')));
    Check(Format('sprites/severity-%d-is-%d-cells-wide', [SPX_SEV_SIZES[i], SPX_SEV_COUNT]),
      IntToStr(PngWidth(p, len)), IntToStr(SPX_SEV_SIZES[i] * SPX_SEV_COUNT));
    Check(Format('sprites/severity-%d-is-one-row-tall', [SPX_SEV_SIZES[i]]),
      IntToStr(PngHeight(p, len)), IntToStr(SPX_SEV_SIZES[i]));
  end;
  { The picker never hands back something BIGGER than the row it is for. }
  for wanted := SPX_SEV_SIZES[Low(SPX_SEV_SIZES)] to 200 do
    if SpxSevPickSize(wanted) > wanted then
      Check(Format('sprites/severity-strip-fits-a-%dpx-row', [wanted]),
        IntToStr(SpxSevPickSize(wanted)), IntToStr(wanted));
  Check('sprites/under-the-floor-gets-the-smallest-severity-strip',
    IntToStr(SpxSevPickSize(1)), IntToStr(SPX_SEV_SIZES[Low(SPX_SEV_SIZES)]));
  { And a size nobody generated still gets bytes rather than nil: the window would otherwise
    show no glyph at all, which is the failure that looks like the feature was never built. }
  p := SpxSevStrip(SPX_SEV_SIZES[High(SPX_SEV_SIZES)] + 1, len);
  CheckTrue('sprites/an-unknown-severity-size-still-gets-a-strip', (p <> nil) and (len > 8));

  CheckTrue('sprites/under-the-floor-gets-the-smallest-icon',
    SpxIconPickSize(1) = SPX_ICON_SIZES[Low(SPX_ICON_SIZES)]);
  SpxFlagPickSize(1, w, h);
  CheckTrue('sprites/under-the-floor-gets-the-smallest-flag',
    w = SPX_FLAG_WIDTHS[Low(SPX_FLAG_WIDTHS)]);

  { PNG, in the length the array says, for every size either picker can hand back. }
  for i := Low(SPX_ICON_SIZES) to High(SPX_ICON_SIZES) do
  begin
    p := SpxIconStrip(SPX_ICON_SIZES[i], len);
    CheckTrue(Format('sprites/icon-%d-is-a-png', [SPX_ICON_SIZES[i]]),
      (p <> nil) and (len > 8) and (PByte(p)[0] = $89) and (PByte(p)[1] = Ord('P')));
    { AND IT HOLDS EXACTLY SPX_ICON_COUNT CELLS. The strip and the constant are generated
      together but consumed apart: SpxImagesFrom slices the PNG into SPX_ICON_COUNT columns,
      so a strip one cell short does not fail -- it silently redraws every icon a fraction
      narrower and shifts each one onto its neighbour's glyph. Nothing else here would notice.
      Read from the PNG's own IHDR, which is the only description of the strip that cannot
      drift from the strip. }
    Check(Format('sprites/icon-%d-is-%d-cells-wide', [SPX_ICON_SIZES[i], SPX_ICON_COUNT]),
      IntToStr(PngWidth(p, len)), IntToStr(SPX_ICON_SIZES[i] * SPX_ICON_COUNT));
    Check(Format('sprites/icon-%d-is-one-row-tall', [SPX_ICON_SIZES[i]]),
      IntToStr(PngHeight(p, len)), IntToStr(SPX_ICON_SIZES[i]));
  end;
  for i := Low(SPX_FLAG_WIDTHS) to High(SPX_FLAG_WIDTHS) do
  begin
    p := SpxFlagStrip(SPX_FLAG_WIDTHS[i], len);
    CheckTrue(Format('sprites/flag-%d-is-a-png', [SPX_FLAG_WIDTHS[i]]),
      (p <> nil) and (len > 8) and (PByte(p)[0] = $89) and (PByte(p)[1] = Ord('P')));
    CheckTrue(Format('sprites/flag-%d-is-wider-than-tall', [SPX_FLAG_WIDTHS[i]]),
      SPX_FLAG_WIDTHS[i] > SPX_FLAG_HEIGHTS[i]);
  end;

  { THE APP ICON, read as bytes rather than as a picture. Pillow will write every frame of an
    .ico as a PNG, which Windows reads everywhere -- Explorer, the taskbar,
    ExtractAssociatedIcon -- and LCL does not: TIcon only looks for a PNG where the directory
    entry's width is 0, the 256x256 convention (icon.inc:880-897), and reads everything else
    as a DIB. A PNG read as a DIB was a modal "Bitmap with unknown compression (268435456)"
    on startup, from an icon that had been verified through Windows and never launched. The
    generator refuses to write one now; this refuses to ship one. }
  CheckIconFrames;

  { A size nobody has a strip for still gets one rather than nil. }
  p := SpxIconStrip(999, len);
  CheckTrue('sprites/an-unknown-icon-size-still-gets-bytes', (p <> nil) and (len > 8));
  p := SpxFlagStrip(999, len);
  CheckTrue('sprites/an-unknown-flag-size-still-gets-bytes', (p <> nil) and (len > 8));
end;

const
  { Every code the pinned engine can emit, from its own sources -- the panel's coverage and the
    help's are only as honest as this list, so it is spelled out rather than derived. At program
    scope because two tests need it: the panel's wording and the help's article inventory. }
  ENGINE_CODES: array[0..16] of string = (
    'bracket.unclosed', 'bracket.mismatched', 'bracket.unexpected-closing',
    'set.malformed', 'def.malformed', 'def.include-in-value', 'definition.duplicate-name',
    'include.unknown-target', 'variable.undefined', 'variable.self-reference',
    'variable.circular-reference', 'plural.arity', 'plural.count-macro',
    'plural.nested-brackets', 'permutation.unknown-key', 'permutation.minsize-not-integer',
    'permutation.maxsize-not-integer');

procedure TestStrings;
var
  id: TSpxStr;
  lang: TSpxLang;
  kind: TSpxNoteKind;
  note: TSpxNote;
  budget, over, i: Integer;
  worst, shown: string;
begin
  { Every id says something in every language. A blank is worse than an untranslated
    string: the control simply disappears. }
  for lang := Low(TSpxLang) to High(TSpxLang) do
    for id := Low(TSpxStr) to High(TSpxStr) do
      CheckTrue('strings/nothing-is-blank', SpxStrIn(lang, id) <> '');

  { THE LENGTH CONTRACT. A caption that sits in a computed position has a budget, and every
    language is held to it -- this is why the base language is the short one: a layout built
    to fit English does not fit Russian by accident, and without this check the first
    translation would silently overflow the strip. }
  over := 0;
  worst := '';
  for lang := Low(TSpxLang) to High(TSpxLang) do
    for id := Low(TSpxStr) to High(TSpxStr) do
    begin
      budget := SpxStrBudget(id);
      { AS RENDERED, not as written: 'matches: %d' is eleven characters and 'matches:
        128 000' is sixteen, and it is the second one that has to fit the label. Six digits
        is the widest a count worth reading gets. }
      shown := StringReplace(SpxStrIn(lang, id), '%d', '999999', [rfReplaceAll]);
      if (budget > 0) and (CpLength(shown) > budget) then
      begin
        Inc(over);
        if worst = '' then
          worst := Format('%s (%d > %d)', [shown, CpLength(shown), budget]);
      end;
      { And a budgeted string may not carry a %s: its width would then depend on a file name
        or a folder, and no fixed slot can promise room for one. }
      if (budget > 0) and (Pos('%s', SpxStrIn(lang, id)) > 0) then
      begin
        Inc(over);
        if worst = '' then worst := SpxStrIn(lang, id) + ' (%s in a budgeted string)';
      end;
    end;
  Check('strings/every-caption-fits-its-budget', IntToStr(over) + ' ' + worst, '0 ');

  { A format string keeps its placeholders in translation, or the text arrives with the
    numbers missing and no error anywhere. The whole SEQUENCE is compared, not how many of
    each: '%d of %d' and '%s of %d' have the same number of specifiers and would hand Format
    a string where it wants an integer -- which is a crash, in the translated build only. }
  { EVERY language, not only Russian. This was ru-vs-en until a string was appended to all
    fourteen positional arrays by script: a slip in the tenth file would have shifted every
    caption after it there and left every check green, because the counts still match and
    Russian still lines up. Comparing the whole sequence in every language is what makes a
    shift impossible to hide -- a moved array puts a '%d' where English has none within a
    line or two. }
  for lang := Low(TSpxLang) to High(TSpxLang) do
    for id := Low(TSpxStr) to High(TSpxStr) do
      Check('strings/format-placeholders-survive-translation',
            Format('lang %d: %s', [Ord(lang), Specifiers(SpxStrIn(lang, id))]),
            Format('lang %d: %s', [Ord(lang), Specifiers(SpxStrIn(spxLangEn, id))]));

  { ANCHORS. Both tables are positional array constants, so a reorder inside TSpxStr with
    count-preserving edits in the wrong order would move every string one place and no
    check above would notice: the counts still match and RU still lines up with EN. These
    pin the two ends and the middle of the enum to what they are supposed to say. }
  Check('strings/anchor-first-id', SpxStrIn(spxLangEn, sMenuFile), 'File');
  Check('strings/anchor-first-id-ru', SpxStrIn(spxLangRu, sMenuFile), 'Файл');
  Check('strings/anchor-middle-id', SpxStrIn(spxLangEn, sGenerate), 'Generate');
  Check('strings/anchor-last-id', SpxStrIn(spxLangEn, sSplitEvenHint),
        'Double-click: even panes');
  Check('strings/anchor-last-id-ru', SpxStrIn(spxLangRu, sSplitEvenHint),
        'Двойной клик — поровну');
  Check('strings/anchor-the-wave-before', SpxStrIn(spxLangEn, sThemeDark), 'Dark');
  { The ones before it, so an append that landed a place early is caught as well. Every wave
    of new ids moves these down by its own length -- that is the point of them. }
  Check('strings/anchor-next-to-last', SpxStrIn(spxLangEn, sThemeLight), 'Light');
  Check('strings/anchor-before-the-last-wave', SpxStrIn(spxLangEn, sClose), 'Close');
  Check('strings/anchor-before-that', SpxStrIn(spxLangEn, sTooLargeToDraw),
        'Output is %d KB — the page does not redraw itself');
  { The sentence that made the check above worth widening: Turkish puts the file name first
    and the count second, which is its word order, and Format is positional -- so before the
    indices it handed a number where the text wanted a name. }
  Check('strings/tr-export-line-keeps-its-arguments',
        Format(SpxStrIn(spxLangTr, sWroteRows), [12, 'a.txt']),
        'a.txt dosyasına 12 satır yazıldı');
  Check('strings/en-export-line-is-unchanged',
        Format(SpxStrIn(spxLangEn, sWroteRows), [12, 'a.txt']),
        'wrote 12 rows to a.txt');

  Check('strings/anchor-a-budget', IntToStr(SpxStrBudget(sSeed)), '5');
  Check('strings/anchor-a-free-string', IntToStr(SpxStrBudget(sMenuFile)), '0');

  { Tr is what every caption in the window actually calls, and nothing here had ever run it:
    a Tr that ignored the current language would have left all these checks green. }
  SpxSetUiLang(spxLangRu);
  CheckTrue('strings/tr-follows-the-current-language', Tr(sSeed) = SpxStrIn(spxLangRu, sSeed));
  CheckTrue('strings/and-the-getter-agrees', SpxUiLang = spxLangRu);
  SpxSetUiLang(spxLangEn);
  CheckTrue('strings/tr-follows-it-back', Tr(sSeed) = SpxStrIn(spxLangEn, sSeed));

  (* HOW MANY LANGUAGES ACTUALLY HAVE THEIR OWN WORDS. Every language answers every id --
     the ones without a file fall back to English -- so "nothing is blank" cannot tell a
     translation from a fallback, and this can: a language whose every string equals the
     English one has no table of its own yet. The number is a ratchet, updated deliberately
     as each language lands, so a translation that silently disappears fails the build. *)
  over := 0;
  for lang := Low(TSpxLang) to High(TSpxLang) do
  begin
    worst := '';
    for id := Low(TSpxStr) to High(TSpxStr) do
      if SpxStrIn(lang, id) <> SpxStrIn(spxLangEn, id) then
      begin
        worst := 'own';
        Break;
      end;
    if (worst <> '') or (lang = spxLangEn) then Inc(over);
  end;
  Check('strings/languages-with-words-of-their-own', IntToStr(over), '14');

  { The window follows the document's language, and only a language it actually has. }
  CheckTrue('strings/ru-selects-russian', SpxUiLangFor('ru') = spxLangRu);
  CheckTrue('strings/ru-RU-too', SpxUiLangFor('ru-RU') = spxLangRu);
  CheckTrue('strings/en-selects-the-base', SpxUiLangFor('en') = spxLangEn);
  { A locale outside the wave falls back to the base rather than to a half-empty window.
    Japanese is deliberate: it is one of the four the site ships that this product does not
    yet, because they need right-to-left layout or a width model that is not seven pixels
    per code point. }
  CheckTrue('strings/a-locale-outside-the-wave-falls-back',
            SpxUiLangFor('ja') = spxLangEn);
  CheckTrue('strings/and-a-language-in-it-does-not', SpxUiLangFor('de') = spxLangDe);
  CheckTrue('strings/the-balkan-group-is-in-it', SpxUiLangFor('hr') = spxLangHr);
  CheckTrue('strings/and-so-does-nonsense', SpxUiLangFor('') = spxLangEn);

  (* THE LOCALE BOX, AND WHAT A SCREEN READER HEARS FROM IT. The list used to hold bare tags
     and paint the endonym beside them, so the name existed only as pixels and the box
     reported itself as `ru`.

     WHAT THESE CHECKS DO NOT REACH, said plainly because the gap is the interesting part:
     this suite compiles no LCL unit, so it cannot see the WINDOW. Restore the old
     `Items.CommaText := 'ru,uk,be,...'` in SpxMainForm and every check below stays green --
     CurrentLocale reads this table by index and would still answer correctly, the app would
     behave identically, and only a screen reader would know. What gates that one line is
     docs/accessibility-baseline.txt, which is a measurement rather than a build step.
     So these hold the TABLE to its contract and nothing more. Mutation-tested: collapsing
     SpxLocaleLabel back to the bare tag fails twelve of them. *)
  for i := 0 to SpxLocaleCount - 1 do
  begin
    { A tag the engine can use. Not the label, and this is the one that matters: a locale of
      'Русский (ru)' would send PluralArity to a language nobody named, and the preview would
      then disagree with every other engine in the family without a diagnostic. }
    CheckTrue('locale/every-tag-is-two-letters', Length(SpxLocaleTag(i)) = 2);
    { The round trip SpxLocaleEndonym relies on. Break it and every name silently becomes
      'English', because SpxLangFor answers the base for whatever it does not know. }
    CheckTrue('locale/every-tag-round-trips',
              SpxLangCode(SpxLangFor(SpxLocaleTag(i))) = SpxLocaleTag(i));
    { THE SCREEN-READER ASSERTION: a label equal to its own tag is a list that says 'ru' out
      loud, which is the state this slice ended. }
    CheckTrue('locale/label-is-not-the-bare-tag', SpxLocaleLabel(i) <> SpxLocaleTag(i));
    { ...and the tag is still in it, so the code is spoken as well as the name. }
    CheckTrue('locale/label-carries-the-tag', Pos(SpxLocaleTag(i), SpxLocaleLabel(i)) > 0);
    CheckTrue('locale/index-of-round-trips', SpxLocaleIndexOf(SpxLocaleTag(i)) = i);
  end;
  { The window looks 'en' up by name to pick the box's opening value, so a missing one would
    leave the box on whatever happened to be first. }
  CheckTrue('locale/english-is-in-the-list', SpxLocaleIndexOf('en') >= 0);
  CheckTrue('locale/an-absent-tag-answers-minus-one', SpxLocaleIndexOf('ja') = -1);
  { Out of range answers empty rather than raising: the draw handler is called by Windows with
    whatever index the list has, and a paint that raises takes the window with it. }
  Check('locale/below-the-range-is-empty', SpxLocaleTag(-1), '');
  Check('locale/above-the-range-is-empty', SpxLocaleTag(SpxLocaleCount), '');
  { Anchors, because the box's order is NOT TSpxLang's -- it leads with the languages this
    product's readers write in, and a reorder would move every ItemIndex silently. }
  Check('locale/anchor-first-is-russian', SpxLocaleLabel(0), 'Русский (ru)');
  Check('locale/anchor-english-sits-fourth', SpxLocaleTag(3), 'en');
  Check('locale/anchor-last-is-bosnian', SpxLocaleLabel(SpxLocaleCount - 1), 'Bosanski (bs)');
  Check('locale/the-list-is-ten-long', IntToStr(SpxLocaleCount), '10');

  { The diagnostics panel is the largest body of prose in the window and the one place its
    words come from editor-core. Every code the engine can emit must read as a sentence in
    BOTH languages -- a code that is translated in one and bare in the other gives a panel
    with English headers over Russian rows, which is what this pair of loops exists to
    prevent. }
  over := 0;
  worst := '';
  for lang := Low(TSpxLang) to High(TSpxLang) do
    for i := 0 to High(ENGINE_CODES) do
      if SpxDiagText(ENGINE_CODES[i], lang) = ENGINE_CODES[i] then
      begin
        Inc(over);
        if worst = '' then worst := ENGINE_CODES[i];
      end;
  Check('strings/every-engine-code-reads-as-a-sentence', IntToStr(over) + ' ' + worst, '0 ');

  for lang := Low(TSpxLang) to High(TSpxLang) do
    for kind := Low(TSpxNoteKind) to High(TSpxNoteKind) do
    begin
      note.Kind := kind;
      note.Target := 'Frag';
      note.Hint := 'frag';
      CheckTrue('strings/every-note-kind-reads-as-a-sentence',
                Length(SpxNoteText(note, lang)) > 10);
    end;

  { The specifier reader itself, since a fault in it would silently pass every string above. }
  Check('strings/specifiers-in-order', Specifiers('%d of %s'), 'd,s,');
  Check('strings/specifiers-ignore-an-escaped-percent', Specifiers('100%% done'), '');
  Check('strings/specifiers-see-past-an-escaped-percent', Specifiers('%%%d'), 'd,');
  Check('strings/specifiers-of-a-plain-string', Specifiers('nothing here'), '');
  { An indexed specifier reports what lands in each ARGUMENT, so a translation that reorders
    them reads the same as the original. FPC really does honour the index -- measured:
    Format('%1:s / %0:d', [7, 'x']) is 'x / 7'. }
  Check('strings/specifiers-follow-an-explicit-index', Specifiers('%1:s and %0:d'), 'd,s,');
  Check('strings/specifiers-count-past-an-index', Specifiers('%1:s %d'), ',s,d,'[2..5]);
  Check('strings/indexed-format-really-reorders', Format('%1:s / %0:d', [7, 'x']), 'x / 7');
end;

{ Spans as text, so a wrong one is readable rather than inferred. }
function SpanSig(const S: TSpxSpans): string;
var i: Integer;
begin
  Result := '';
  for i := 0 to High(S) do
    Result := Result + Format('%d:%d..%d:%d ',
      [S[i].Line, S[i].Col, S[i].EndLine, S[i].EndCol]);
  Result := Trim(Result);
end;

{ Ordered by start, non-overlapping, and every span well-formed. The markup's bisect assumes
  all three; nothing else would notice if the scanner stopped delivering them. }
function SpansAreOrdered(const S: TSpxSpans): Boolean;
var i: Integer;
begin
  Result := True;
  for i := 0 to High(S) do
  begin
    if (S[i].EndLine < S[i].Line) or
       ((S[i].EndLine = S[i].Line) and (S[i].EndCol <= S[i].Col)) then Exit(False);
    if i > 0 then
      if (S[i].Line < S[i - 1].EndLine) or
         ((S[i].Line = S[i - 1].EndLine) and (S[i].Col < S[i - 1].EndCol)) then Exit(False);
  end;
end;

{ The group under the caret, as text: kind, head and variants separated by a bar that cannot
  be confused with the language's own. }
function GroupSig(const Text: string; Offset: Integer): string;
const KINDS: array[TSpxGroupKind] of string = ('choice', 'cond', 'plural', 'perm');
var g: TSpxGroup; i: Integer;
begin
  if not SpxGroupAt(Text, Offset, g) then Exit('none');
  Result := Format('%s %d..%d [%s]', [KINDS[g.Kind], g.Start, g.Stop, g.Head]);
  for i := 0 to High(g.Variants) do Result := Result + ' <' + g.Variants[i] + '>';
end;

{ The document with the group at Offset rewritten with its own variants. Must equal the
  document it started from -- see the checks that use it. }
function RoundTrip(const Text: string; Offset: Integer): string;
var g: TSpxGroup;
begin
  if not SpxGroupAt(Text, Offset, g) then Exit('no group');
  if not SpxSetGroupVariants(Text, g, g.Variants, Result) then Result := 'refused';
end;

{ The document after an edit, or 'refused' when the write would not say what was asked. }
function WriteVariants(const Text: string; Offset: Integer;
  const Variants: array of string): string;
var g: TSpxGroup;
begin
  if not SpxGroupAt(Text, Offset, g) then Exit('no group');
  if not SpxSetGroupVariants(Text, g, Variants, Result) then Result := 'refused';
end;

(* THE HELP IS A FIXTURE. Every example in docs/help that carries an arrow is a CLAIM about
   what the engine does, and a claim in this project is checked. The suite reads the document
   itself rather than a copy of it, so a sentence edited in the help and nowhere else fails
   the build instead of quietly becoming untrue.

   Only single-line examples are read automatically -- the arrow says where the document ends
   and the expected output begins. The few multi-line ones are gated by hand below, and the
   count assertion at the end is what stops examples from silently disappearing. *)
(* A session value the author means LITERALLY. The engine renders a host-supplied value
   exactly as it renders a `#set` one -- that is the family's contract and the default here,
   because a production host passes its values raw and the preview has to agree with it. The
   flag is the author's escape hatch, and what it costs is one call on the way past. *)
procedure TestSessionValues;
var
  p_: TSpxVarPair;
  vars_: TStrMap;
  ctx: TSpxContext;
  session_, kept: TSpxVarPairs;
  model_: TSpxVarInfos;
begin
  p_.Name := 'x';
  p_.Value := '{дёшево|дорого}';

  p_.Literal := False;
  Check('session/a template value is handed over as typed',
        SpxValueForEngine(p_), '{дёшево|дорого}');
  p_.Literal := True;
  CheckTrue('session/a literal value is not',
            SpxValueForEngine(p_) <> '{дёшево|дорого}');
  { Plain text has nothing to neutralise, so the two are the same string. }
  p_.Value := 'Москва';
  Check('session/plain text is untouched either way', SpxValueForEngine(p_), 'Москва');

  { THE FLAG HAS TO SURVIVE THE JOURNEY. It is set on the panel, filtered through
    SpxKeepRuntime on the way to the job, and read by the worker -- and the first cut of that
    filter copied the name and the value and dropped this, so the checkbox did nothing at all
    and nothing said so. }
  begin
    SetLength(session_, 1);
    session_[0].Name := 'price';
    session_[0].Value := '{дёшево|дорого}';
    session_[0].Literal := True;
    SetLength(model_, 1);
    model_[0].Name := 'price';
    model_[0].Kind := spxVarRuntime;
    kept := SpxKeepRuntime(model_, session_);
    CheckTrue('session/the filter keeps the value', (Length(kept) = 1) and
              (kept[0].Value = '{дёшево|дорого}'));
    CheckTrue('session/and the flag with it', (Length(kept) = 1) and kept[0].Literal);
  end;

  { AND WHAT IT MEANS, through the engine rather than by inspection of the bytes. }
  vars_ := TStrMap.Create;
  try
    p_.Name := 'x';
    p_.Value := '{дёшево|дорого}';

    p_.Literal := False;
    vars_.AddOrSetValue('x', SpxValueForEngine(p_));
    ctx := SpxSeededContext('ru', vars_, 5, nil);
    CheckTrue('session/without the flag the engine chooses',
              SpxRenderSample('%x%', ctx) <> '{дёшево|дорого}');

    p_.Literal := True;
    vars_.AddOrSetValue('x', SpxValueForEngine(p_));
    ctx := SpxSeededContext('ru', vars_, 5, nil);
    Check('session/with the flag the braces are text',
          SpxRenderSample('%x%', ctx), '{дёшево|дорого}');

    { A percent sign in a literal value must not start a variable reference either. }
    p_.Value := 'скидка %off% сегодня';
    p_.Literal := True;
    vars_.AddOrSetValue('x', SpxValueForEngine(p_));
    ctx := SpxSeededContext('ru', vars_, 5, nil);
    Check('session/and a percent stays a percent',
          SpxRenderSample('%x%', ctx), 'Скидка %off% сегодня');
  finally
    vars_.Free;
  end;
end;

const
  ARROW = #$E2#$86#$92;      { → }
  ELLIPSIS = #$E2#$80#$A6;   { … marks an output too long to print in full }
  RETURN_ = #$E2#$8F#$8E;    { ⏎ stands for a line break in an expected output }

type
  (* One verified help document. TWO FIELDS, and the shortness is the point: everything the
     examples DEPEND on -- the locale, the seed, the template set, the word the document uses for
     "nothing" -- is declared inside the document itself, where its reader can see it. What stays
     here is only what the SUITE must expect and the document must not be trusted to say about
     itself.

     Both fields announce their own errors: a wrong path fails FileExists loudly, and a wrong
     count fails the ratchet loudly. That is why this is a table in the source rather than a
     manifest on disk -- a manifest is an unverified input to the verifier, its natural parser
     skips what it does not understand, and a silently skipped document is exactly the failure
     this whole arrangement exists to prevent. *)
  THelpDoc = record
    Path: string;
    Examples: Integer;   { exact, not a floor: an example that disappears must fail the build }
    { WHETHER THIS DOCUMENT ANSWERS THE PANEL. Exactly one document per language does, and it
      is the one the double-click on a diagnostics row opens -- so it must carry an article for
      every code and note the panel can show. The language reference carries none: it is about
      constructs that work, and holding it to the same list demanded 22 articles it has no
      business having. Named as an obligation rather than derived from the file name, because
      the obligation is the thing the check is about. }
    Codes: Boolean;
    Good: Integer;       { how many of them CLAIM to be clean -- exact for the same reason:
                           deleting the word `spx-good` from a fence, or putting it on the
                           CLOSING one where both parsers ignore it, turns the claim back into
                           an ordinary block and stops it being checked. Measured by review:
                           ten checks disappeared and the build stayed green. }
  end;

const
  HELP_DOCS: array[0..41] of THelpDoc = (
    (Path: 'docs/help/en/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/ru/diagnostics.md'; Examples: 38; Codes: True;  Good: 8),
    (Path: 'docs/help/en/syntax.md';      Examples: 38; Codes: False; Good: 34),
    (Path: 'docs/help/ru/syntax.md';      Examples: 41; Codes: False; Good: 37),
    { The product itself, added 2026-08-06 -- a reader who opens the help was being told how
      the LANGUAGE works and never what this program is. It carries one example, because it is
      about the window rather than the syntax, and that one is gated like every other. }
    (Path: 'docs/help/en/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/de/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/de/syntax.md';      Examples: 39; Codes: False; Good: 35),
    (Path: 'docs/help/de/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/fr/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/fr/syntax.md';      Examples: 41; Codes: False; Good: 37),
    (Path: 'docs/help/fr/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/es/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/es/syntax.md';      Examples: 41; Codes: False; Good: 37),
    (Path: 'docs/help/es/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/it/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/it/syntax.md';      Examples: 41; Codes: False; Good: 37),
    (Path: 'docs/help/it/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/pt/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/pt/syntax.md';      Examples: 42; Codes: False; Good: 38),
    (Path: 'docs/help/pt/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/nl/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/nl/syntax.md';      Examples: 39; Codes: False; Good: 35),
    (Path: 'docs/help/nl/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/tr/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/tr/syntax.md';      Examples: 40; Codes: False; Good: 36),
    (Path: 'docs/help/tr/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/uk/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/uk/syntax.md';      Examples: 42; Codes: False; Good: 38),
    (Path: 'docs/help/uk/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/be/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/be/syntax.md';      Examples: 42; Codes: False; Good: 38),
    (Path: 'docs/help/be/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/sr/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/sr/syntax.md';      Examples: 43; Codes: False; Good: 39),
    (Path: 'docs/help/sr/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/hr/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/hr/syntax.md';      Examples: 41; Codes: False; Good: 37),
    (Path: 'docs/help/hr/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/bs/diagnostics.md'; Examples: 35; Codes: True;  Good: 6),
    (Path: 'docs/help/bs/syntax.md';      Examples: 41; Codes: False; Good: 37),
    (Path: 'docs/help/bs/studio.md';      Examples: 1;  Codes: False; Good: 1),
    (Path: 'docs/help/ru/studio.md';      Examples: 1;  Codes: False; Good: 1));

{ `docs/help/ru/diagnostics.md` -> `ru/diagnostics`, for check names that say which document. }
function HelpLabel(const APath: string): string;
begin
  Result := APath;
  if Copy(Result, 1, 10) = 'docs/help/' then Delete(Result, 1, 10);
  if Copy(Result, Length(Result) - 2, 3) = '.md' then SetLength(Result, Length(Result) - 3);
end;

{ Every help document ON DISK, sorted -- the other half of the registration check. }
{ EVERY `.md` anywhere under `docs/help`, at any depth. The first version walked exactly
  `docs/help/<lang>/*.md`, which left two ways to put unchecked prose in the tree and have it
  look gated: a file at the top level (`docs/help/README.md`) and a subfolder (which the planned
  page generator will create the day help stops being one document per language). Measured: with
  both present the suite stayed green. }
procedure CollectHelpDocs(const ADir: string; AFound: TStringList);
var rec: TSearchRec;
begin
  if FindFirst(ADir + '/*', faAnyFile, rec) <> 0 then Exit;
  try
    repeat
      if (rec.Name = '.') or (rec.Name = '..') then Continue;
      if (rec.Attr and faDirectory) <> 0 then
        CollectHelpDocs(ADir + '/' + rec.Name, AFound)
      else if (LowerCase(ExtractFileExt(rec.Name)) = '.md') or
              (LowerCase(ExtractFileExt(rec.Name)) = '.markdown') then
        AFound.Add(ADir + '/' + rec.Name);
    until FindNext(rec) <> 0;
  finally
    FindClose(rec);
  end;
end;

function HelpDocsOnDisk: string;
var found: TStringList;
begin
  found := TStringList.Create;
  try
    CollectHelpDocs('docs/help', found);
    found.Sort;
    Result := found.CommaText;
  finally
    found.Free;
  end;
end;

(* THE MEASUREMENT, printed rather than written.

   An author cannot run the engine from inside a markdown file, and an expected output must never
   be guessed -- least of all in a language whose post-processing has rules the other document
   cannot show. So on a mismatch the suite prints the line to paste, in the document's own
   notation.

   NOT a write-back mode, and deliberately: a flag that rewrote the expectations would turn this
   fixture into a snapshot of whatever the engine currently does, so an engine regression would
   quietly rewrite the help instead of breaking the build. Printing is measurement; writing is
   laundering.

   It also refuses to print what it cannot round-trip -- the parser would read those back as
   something else. *)
{ Does what the engine returned fit an ABBREVIATED expectation? The pieces around the ellipses
  must occur in order, the first at the very start and the last at the very end. Answers 'fits'
  or says where it stopped, so a failure reads as a sentence rather than as two walls of text.

  AN ABBREVIATION MAY HIDE THE MIDDLE AND NEVER AN END. The first version let the want begin or
  end with an ellipsis, which cleared the corresponding anchor -- so `…` alone fitted ANY output,
  and `A a a … b b …` said nothing whatever about how the render ends. That is not a weak check,
  it is the thing this fixture exists to forbid: an author who does not know what the engine
  returns could type one character and get a green build. It also cost a real defect. The
  self-reference article's `… b b b …` let the prose claim fifty b's while the engine produces
  fifty-one, because the trailing ellipsis made the end unverifiable.

  Greedy, deliberately: `Pos` takes the first occurrence and consumes through it, so a want whose
  pieces overlap (`aa…aab` against `aaab`) can be reported as not fitting although some other
  alignment would satisfy it. It fails loudly rather than passing wrongly, and the shape does not
  occur in prose written for a reader. }
function PartialVerdict(const AGot, AWant: string): string;
var rest, piece, tail: string; at, cut: Integer; first: Boolean;
begin
  rest := AGot;
  tail := AWant;
  first := True;
  if (Copy(tail, 1, Length(ELLIPSIS)) = ELLIPSIS) or
     (Copy(tail, Length(tail) - Length(ELLIPSIS) + 1, Length(ELLIPSIS)) = ELLIPSIS) then
    Exit('an abbreviation must show both ends: <' + AWant + '>');
  while True do
  begin
    cut := Pos(ELLIPSIS, tail);
    if cut = 0 then Break;
    piece := Copy(tail, 1, cut - 1);
    Delete(tail, 1, cut + Length(ELLIPSIS) - 1);
    if piece <> '' then
    begin
      at := Pos(piece, rest);
      if at = 0 then Exit('missing piece <' + piece + '>');
      if first and (at <> 1) then Exit('does not start with <' + piece + '>');
      Delete(rest, 1, at + Length(piece) - 1);
    end;
    first := False;
  end;
  { What follows the last ellipsis must end the output. }
  if tail <> '' then
  begin
    if Length(rest) < Length(tail) then Exit('too short to end with <' + tail + '>');
    if Copy(rest, Length(rest) - Length(tail) + 1, Length(tail)) <> tail then
      Exit('does not end with <' + tail + '>');
  end;
  Result := 'fits';
end;

procedure ReportMeasured(const APath, ATemplate, AGot, AEmpty: string; ALine: Integer);
var shown, why: string;
begin
  shown := StringReplace(AGot, #10, ' ' + RETURN_ + ' ', [rfReplaceAll]);
  if shown = '' then shown := AEmpty;
  why := '';
  if Pos('   ', shown) > 0 then why := 'it contains three spaces, which the parser reads as the '
    + 'start of a prose note'
  else if Pos(ELLIPSIS, shown) > 0 then why := 'it contains an ellipsis, which would skip the '
    + 'example AND stop it being counted'
  { AGot, not `shown`: when the engine literally returns the empty-output word, `shown` equals it
    and the old test let it through -- and pasting that line would make the parser read it as
    "empty" instead of as those characters. }
  else if (AEmpty <> '') and (Pos(AEmpty, AGot) > 0) then
    why := 'it contains the empty-output word, which the parser would misread';
  if why <> '' then
  begin
    WriteLn('     measured at ', APath, ':', ALine, ' but NOT pastable -- ', why);
    WriteLn('     the engine returned: <', shown, '>');
    Exit;
  end;
  WriteLn('     measured, paste at ', APath, ':', ALine);
  WriteLn('       ', StringReplace(ATemplate, #10, ' / ', [rfReplaceAll]), '   ', ARROW, '  ',
          shown);
end;

{ Is this one of the codes a panel row can actually carry? Asked of the lists themselves, and
  that is the point: a heading may open with a backticked CONSTRUCT rather than a code --
  ``### `#include` работает только с начала строки`` -- and a parser that took any backticked
  token for a code demanded that `#include` produce a diagnostic named `#include`. }
function IsKnownCode(const ACode: string): Boolean;
var i: Integer; k: TSpxNoteKind;
begin
  for i := Low(ENGINE_CODES) to High(ENGINE_CODES) do
    if ENGINE_CODES[i] = ACode then Exit(True);
  for k := Low(TSpxNoteKind) to High(TSpxNoteKind) do
    if SpxNoteCode(k) = ACode then Exit(True);
  Result := False;
end;

{ Does this line look like an EXAMPLE -- bare template, arrow, bare output -- rather than prose
  that mentions the arrow? Everything inside `backticks` is prose's way of quoting, so it is
  removed first; what remains has to carry the arrow with real text on both sides. }
function BareExampleShape(const ALine: string): Boolean;
var i, at: Integer; inSpan: Boolean; bare: string;
begin
  bare := '';
  inSpan := False;
  for i := 1 to Length(ALine) do
    if ALine[i] = '`' then inSpan := not inSpan
    else if not inSpan then bare := bare + ALine[i];
  at := Pos(ARROW, bare);
  Result := (at > 0) and (Trim(Copy(bare, 1, at - 1)) <> '') and
            (Trim(Copy(bare, at + Length(ARROW), MaxInt)) <> '');
end;

{ Any heading, at any level. Spelling out `# `/`## `/`### ` left `#### ` and deeper open, so a
  sub-sub-heading would have gone on collecting examples for the article above it. }
function IsHeading(const ALine: string): Boolean;
var n: Integer;
begin
  n := 1;
  while (n <= Length(ALine)) and (ALine[n] = '#') do Inc(n);
  Result := (n > 1) and (n <= Length(ALine)) and (ALine[n] = ' ');
end;

{ The code a `### ` heading is about, or '' when it is about something else -- three headings in
  the Russian document are prose and have no code to demonstrate. }
function HeadingCode(const AHeading: string): string;
var t: string; b: Integer;
begin
  Result := '';
  t := Trim(Copy(AHeading, 5, MaxInt));
  if Copy(t, 1, 1) <> '`' then Exit;
  b := 2;
  while (b <= Length(t)) and (t[b] <> '`') do Inc(b);
  if b > Length(t) then Exit;
  Result := Copy(t, 2, b - 2);
  if not IsKnownCode(Result) then Result := '';
end;

(* WHAT THE WINDOW RUNS MUST BE WHAT THIS SUITE RAN. Every example's template is collected
   here as the markdown is walked, and TestHelpUnit compares the list against the table the
   generator built -- so a click in the help cannot render anything but the text whose output
   was rendered through the real engine and byte-compared a few lines below.

   Keyed by the document's path, because the two languages are walked one after the other. *)
var
  GRanTemplates: TStringList = nil;

{ How many fragments a document's fixture declared. Recorded rather than asserted, so the
  unit's table can be compared against the suite's own reading of the same block -- two parsers,
  one document, which is the shape every other claim about the help is checked in. }
var GFixtureIncludes: TStringList = nil;

procedure NoteFixtureIncludes(const APath: string; ACount: Integer);
begin
  if GFixtureIncludes = nil then GFixtureIncludes := TStringList.Create;
  GFixtureIncludes.Values[APath] := IntToStr(ACount);
end;

function FixtureIncludesFor(const APath: string): Integer;
begin
  Result := -1;
  if GFixtureIncludes = nil then Exit;
  if GFixtureIncludes.IndexOfName(APath) < 0 then Exit;
  Result := StrToIntDef(GFixtureIncludes.Values[APath], -1);
end;

procedure NoteTemplate(const APath, ATemplate: string);
begin
  if GRanTemplates = nil then GRanTemplates := TStringList.Create;
  GRanTemplates.Add(APath + #1 + ATemplate);
end;

function TemplatesRunFor(const APath: string): TStringList;
var i: Integer; head: string;
begin
  Result := TStringList.Create;
  if GRanTemplates = nil then Exit;
  head := APath + #1;
  for i := 0 to GRanTemplates.Count - 1 do
    if Copy(GRanTemplates[i], 1, Length(head)) = head then
      Result.Add(Copy(GRanTemplates[i], Length(head) + 1, MaxInt));
end;

(* ▁▁▁ AND THE LIST ITSELF, HELD AGAINST THE ENGINE ▁▁▁

   `ENGINE_CODES` above is spelled out by hand, which is right -- deriving it at RUNTIME would
   mean the help's obligation moved whenever the engine did, silently, which is the opposite of
   what a ratchet is for. But a hand-written list has its own hole: a code the engine gains and
   nobody transcribes is enforced NOWHERE. The suite would not ask for an article, the generator
   has no notion of codes, and the first sign of it would be a reader double-clicking a
   diagnostic row and landing on the contents page.

   So the list is compared against the pinned engine's own source. Every string literal in it
   shaped like a code -- `word.word-word` -- must be in the list, and every entry of the list
   must be somewhere in that file. Both directions matter: the first catches a code the engine
   added, the second catches one it dropped while the help went on documenting it.

   It reads the engine as TEXT rather than calling it, because there is no API that enumerates
   the codes and inventing one in the engine for the sake of a consumer's test would be the
   wrong way round. The cost is a false positive if the engine ever holds an unrelated literal
   of that shape; that is a red build with a name on it, which is the safe direction. *)
procedure TestEngineCodeList;
const SRC = 'engine/src/Spintax.pas';
var
  txt, lit: string;
  found, missing, extra: TStringList;
  i, j, k: Integer;

  function LooksLikeACode(const S: string): Boolean;
  var d, n: Integer;
  begin
    Result := False;
    d := Pos('.', S);
    if (d < 2) or (d = Length(S)) then Exit;
    for n := 1 to Length(S) do
      if not ((S[n] in ['a'..'z']) or (S[n] = '.') or (S[n] = '-')) then Exit;
    { one dot, and nothing doubled }
    if Pos('.', Copy(S, d + 1, MaxInt)) > 0 then Exit;
    Result := True;
  end;

begin
  if not FileExists(SRC) then
  begin
    { A clone without `--recurse-submodules`. Say so rather than passing quietly. }
    CheckTrue('engine/codes/the engine source is here to compare against', False);
    Exit;
  end;
  found := TStringList.Create;
  missing := TStringList.Create;
  extra := TStringList.Create;
  try
    missing.LoadFromFile(SRC);      { borrowed as a reader; cleared right back }
    txt := missing.Text;
    missing.Clear;
    found.Sorted := True;
    found.Duplicates := dupIgnore;
    (* NOT by pairing quotes. The first version walked the file opening a literal at every `'`
       and closing it at the next one -- and this source is mostly PROSE, whose apostrophes
       ("does not", "the engine's") desynchronise the pairing at once: it found six codes of
       seventeen and reported the other eleven as dropped. What is looked for instead is a RUN
       of the code alphabet with a quote hard against each end, which needs no pairing at all
       and cannot drift. *)
    i := 1;
    while i <= Length(txt) do
    begin
      if txt[i] in ['a'..'z'] then
      begin
        j := i;
        while (j <= Length(txt)) and (txt[j] in ['a'..'z', '.', '-']) do Inc(j);
        lit := Copy(txt, i, j - i);
        if (i > 1) and (txt[i - 1] = #39) and (j <= Length(txt)) and (txt[j] = #39) and
           LooksLikeACode(lit) then
          found.Add(lit);
        i := j;
      end
      else Inc(i);
    end;

    for i := 0 to found.Count - 1 do
    begin
      k := -1;
      for j := Low(ENGINE_CODES) to High(ENGINE_CODES) do
        if ENGINE_CODES[j] = found[i] then k := j;
      if k < 0 then missing.Add(found[i]);
    end;
    for j := Low(ENGINE_CODES) to High(ENGINE_CODES) do
      if found.IndexOf(ENGINE_CODES[j]) < 0 then extra.Add(ENGINE_CODES[j]);

    Check('engine/codes/the engine emits none this list has not got',
          missing.CommaText, '');
    Check('engine/codes/this list names none the engine has dropped',
          extra.CommaText, '');
    CheckTrue('engine/codes/there were codes to compare', found.Count > 0);
  finally
    extra.Free;
    missing.Free;
    found.Free;
  end;
end;

(* ▁▁▁ ONE ROW PER HELP LANGUAGE, AND ADDING A LANGUAGE EDITS NOTHING ELSE HERE ▁▁▁

   These two numbers were spelled into the middle of two different checks, one of them as
   `if code = 'en' then 47 else 54` -- which does not fail for a third language, it quietly
   hands it Russian's number and passes. The other was `array[0..1]`, which skipped a third
   language altogether. Both are the same mistake in opposite directions: a per-language fact
   written where only two languages could ever be meant.

   Twelve more languages are the next slice, so the shape has to be a table keyed by the
   language's own code, with a NAMED failure for a language that has no row. Both numbers stay
   exact ratchets -- a new counter-example must be counted, not absorbed. *)
type
  THelpLangFacts = record
    Code: string;
    { Examples that draw no diagnostic row at all, across every document of the language. }
    CleanExamples: Integer;
    { Bolded claims in the `silences` chapter. Legitimately different per language: two of the
      Russian silences are about Cyrillic text and have no English counterpart. }
    Silences: Integer;
  end;

const
  HELP_LANG_FACTS: array[0..13] of THelpLangFacts = (
    (Code: 'en'; CleanExamples: 47; Silences: 5),
    (Code: 'ru'; CleanExamples: 54; Silences: 7),
    (Code: 'de'; CleanExamples: 48; Silences: 6),
    (Code: 'fr'; CleanExamples: 50; Silences: 6),
    (Code: 'es'; CleanExamples: 50; Silences: 6),
    (Code: 'it'; CleanExamples: 50; Silences: 6),
    (Code: 'pt'; CleanExamples: 51; Silences: 6),
    (Code: 'nl'; CleanExamples: 48; Silences: 6),
    (Code: 'tr'; CleanExamples: 49; Silences: 8),
    (Code: 'uk'; CleanExamples: 52; Silences: 8),
    (Code: 'be'; CleanExamples: 52; Silences: 8),
    (Code: 'sr'; CleanExamples: 53; Silences: 8),
    (Code: 'hr'; CleanExamples: 51; Silences: 7),
    (Code: 'bs'; CleanExamples: 51; Silences: 7));

function HelpFactsFor(const ACode: string; out AFacts: THelpLangFacts): Boolean;
var i: Integer;
begin
  for i := Low(HELP_LANG_FACTS) to High(HELP_LANG_FACTS) do
    if HELP_LANG_FACTS[i].Code = ACode then
    begin
      AFacts := HELP_LANG_FACTS[i];
      Exit(True);
    end;
  AFacts := Default(THelpLangFacts);
  Result := False;
end;

{ Whether an interface language has a help document of its OWN, rather than falling back. The
  answer is the shipped unit's, not a list of codes written here. }
function HelpHasOwnDocument(const ACode: string): Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to SPX_HELP_LANG_COUNT - 1 do
    if SpxHelpLangCode(i) = ACode then Exit(True);
end;

procedure CheckHelpDoc(const ADoc: THelpDoc);
var
  line, want, doc_, got, tag, key, val, label_, locale, empty_: string;
  section, undemonstrated: string;
  seedInt: Integer;
  lines: TStringList;
  set_: TSpxTemplateSet;
  ctx: TSpxContext;
  i, p, checked, good, seed, exampleLine: Integer;
  inFence, isFixture, isGood, skip, haveFixture, ctxReady, sectionShown,
  sectionHadExamples: Boolean;
begin
  label_ := HelpLabel(ADoc.Path);
  if not FileExists(ADoc.Path) then
  begin
    CheckTrue('help/' + label_ + '/the document is where the table says', False);
    Exit;
  end;
  set_ := TSpxTemplateSet.Create;
  lines := TStringList.Create;
  try
    lines.Text := SpxReadTextFile(ADoc.Path);
    checked := 0;
    good := 0;
    seed := 0;
    locale := '';
    empty_ := '';
    inFence := False;
    isFixture := False;
    isGood := False;
    haveFixture := False;
    ctxReady := False;
    section := '';
    sectionShown := False;
    sectionHadExamples := False;
    undemonstrated := '';
    doc_ := '';
    skip := False;
    for i := 0 to lines.Count - 1 do
    begin
      line := lines[i];
      { The article this example belongs to, remembered as the walk passes its heading. ANY
        heading closes the previous article, not only a `###` one: a `##` that follows the last
        article of a group would otherwise leave it open, and the next section's examples would
        be counted as its. }
      if (not inFence) and IsHeading(Trim(line)) then
      begin
        if (section <> '') and sectionHadExamples and (not sectionShown) then
          undemonstrated := undemonstrated + section + ' ';
        if Copy(Trim(line), 1, 4) = '### ' then section := HeadingCode(Trim(line))
        else section := '';
        sectionShown := False;
        sectionHadExamples := False;
      end;
      if Copy(Trim(line), 1, 3) = '```' then
      begin
        { The INFO STRING on the opening fence says what kind of block this is. }
        if not inFence then
        begin
          tag := Trim(Copy(Trim(line), 4, MaxInt));
          isFixture := tag = 'spx-fixture';
          { A `spx-good` fence CLAIMS the examples in it are clean, and the claim is checked
            below rather than believed. Without it the chapter about correct forms proved
            nothing: the causation check works per article, and that chapter has none. }
          isGood := tag = 'spx-good';
          CheckTrue('help/' + label_ + '/the fence tag is one this suite knows [' + tag + ']',
                    (tag = '') or isFixture or isGood);
          { A SECOND BLOCK IS A FAILURE, not a merge. Measured on the first version: a late block
            had three different scopes at once -- `seed` ignored (the context is built at the
            first example and frozen), `include` keys applied (the set is held by reference), the
            empty-output word re-read per example. The nastiest was `locale`, ignored for
            rendering but still deciding the folder check, so a document could fail "the locale
            matches its folder" having been verified under the other one. One block, and it must
            come before anything it governs. }
          if isFixture then
          begin
            CheckTrue('help/' + label_ + '/the conditions block appears once, before the examples',
                      (not haveFixture) and (checked = 0));
            haveFixture := True;
          end;
        end
        else
        begin
          isFixture := False;
          isGood := False;
        end;
        inFence := not inFence;
        doc_ := '';
        skip := False;
        Continue;
      end;
      if not inFence then
      begin
        (* AN ARROW OUTSIDE A FENCE IS INVISIBLE TO EVERY GATE and looks, in the markdown
           source, exactly like an example: not rendered, not compared, not counted, and --
           unlike a DELETED example -- it does not disturb the exact ratchet either. Planted
           between two headings, `a price {cheap|dear} -> A price frobnicated` left the suite
           green. Prose legitimately mentions the arrow (the legend explains it), so the rule
           is that an EXAMPLE is bare text on both sides of the arrow. The legend's own
           sentence -- `#include "frag"` -> `Fragment` would rest on ... -- has the arrow bare
           but both operands in code spans, and it is prose, so it must not be flagged. *)
        if BareExampleShape(line) then
          CheckTrue('help/' + label_ + '/an example outside a fence at line ' +
                    IntToStr(i + 1) + ' [' + Trim(line) + ']', False);
        Continue;
      end;

      if isFixture then
      begin
        if Trim(line) = '' then Continue;
        { TRIMMED FIRST, because the generator trims the whole line before it splits one
          (`t = raw.strip()`), and these two must read the same block the same way. They did
          not: a fragment whose value ended in a space was VERIFIED here with the space and
          SHIPPED without it, so the suite would have been checking a text the reader never
          gets. Nothing in the two documents triggers it today, which is exactly why it was
          worth closing before something did. }
        line := Trim(line);
        p := Pos(': ', line);
        if p = 0 then
        begin
          CheckTrue('help/' + label_ + '/fixture line is `key: value` [' + line + ']',
                    False);
          Continue;
        end;
        { The FIRST `: ` only, so a value may contain colons of its own. }
        key := Trim(Copy(line, 1, p - 1));
        val := Copy(line, p + 2, MaxInt);
        if key = 'locale' then locale := Trim(val)
        else if key = 'seed' then
        begin
          { `StrToIntDef(.., 0)` alone made a typo'd seed indistinguishable from a missing one,
            and reported as "declares a seed". Seed 0 is not expressible and does not need to be
            -- what matters is that a value which is not a number fails saying that. }
          CheckTrue('help/' + label_ + '/seed is a number [' + Trim(val) + ']',
                    TryStrToInt(Trim(val), seedInt) and (seedInt <> 0));
          seed := StrToIntDef(Trim(val), 0);
        end
        else if key = 'empty' then empty_ := Trim(val)
        else if Copy(key, 1, 8) = 'include ' then
          set_.AddOrSetValue(Trim(Copy(key, 9, MaxInt)), val)
        else
          { An unrecognised key FAILS rather than reverting to a default. A typo'd `locale`
            that silently fell back would verify the document against the wrong engine. }
          CheckTrue('help/' + label_ + '/fixture key is one this suite knows [' + key + ']',
                    False);
        Continue;
      end;

      if not haveFixture then
      begin
        CheckTrue('help/' + label_ + '/the fixture block comes before the first example ' +
                  '(the rest of this document goes unverified)', False);
        Exit;
      end;
      { Built once, from what the document declared -- and only now, because the block is read by
        the same pass that reads the examples. }
      if not ctxReady then
      begin
        ctx := SpxSeededContext(locale, nil, seed, set_);
        ctxReady := True;
      end;

      { a blank line separates one example from the next }
      if Trim(line) = '' then
      begin
        doc_ := '';
        skip := False;
        Continue;
      end;
      p := Pos(ARROW, line);
      if p = 0 then
      begin
        { another line of the same document }
        if doc_ <> '' then doc_ := doc_ + #10;
        doc_ := doc_ + TrimRight(line);
        Continue;
      end;
      want := Trim(Copy(line, p + Length(ARROW), MaxInt));
      { What sits before the arrow is the LAST line of the template -- unless there is nothing
        there, which is how a multi-line example puts its output on a line of its own. Appending
        it anyway added a trailing blank line, so the suite verified a three-line template while
        the reader saw two. Harmless in both live cases, and exactly the kind of drift between
        the shown example and the checked one that this fixture exists to prevent. }
      line := TrimRight(Copy(line, 1, p - 1));
      if line = '' then
        { nothing to append }
      else if doc_ <> '' then doc_ := doc_ + #10 + line
      else doc_ := line;
      exampleLine := i + 1;
      { a note after the output, set off by three spaces, is prose and not part of it }
      p := Pos('   ', want);
      if p > 0 then want := TrimRight(Copy(want, 1, p - 1));
      if want = empty_ then want := '';
      want := StringReplace(want, ' ' + RETURN_ + ' ', #10, [rfReplaceAll]);
      { A TEMPLATE cannot be abbreviated -- there is nothing to render. Fails rather than
        skips, because an abbreviated template is an example that can never be verified. }
      skip := Pos(ELLIPSIS, doc_) > 0;
      CheckTrue('help/' + label_ + '/no template is abbreviated at line ' +
                IntToStr(exampleLine), not skip);
      if not skip then
      begin
        got := SpxRenderSample(doc_, ctx);
        NoteTemplate(ADoc.Path, doc_);
        (* AN ELLIPSIS IN THE OUTPUT IS A PARTIAL CLAIM, not an exemption. It used to skip the
           example entirely: unrendered, uncompared, uncounted, and -- because the counter and
           the causation flag lived in the same block -- it exempted the whole article too. The
           `variable.self-reference` article had exactly one example, with an ellipsis, so it was
           unverified prose; and anyone could walk around the ratchet by typing one character.

           What an abbreviated output still says is true at its two ends and in order, so that is
           what is checked: the pieces between the ellipses must appear in the render, in
           sequence, starting at the beginning and finishing at the end unless the last piece is
           empty. *)
        if Pos(ELLIPSIS, want) > 0 then
          Check('help/' + label_ + '/example (abbreviated): ' +
                StringReplace(doc_, #10, ' / ', [rfReplaceAll]),
                PartialVerdict(got, want), 'fits')
        else
        begin
          Check('help/' + label_ + '/example: ' +
                StringReplace(doc_, #10, ' / ', [rfReplaceAll]), got, want);
          { Only on a mismatch, and after Check has printed why. }
          if got <> want then ReportMeasured(ADoc.Path, doc_, got, empty_, exampleLine);
        end;
        { AND IS IT AN INSTANCE OF WHAT THE ARTICLE IS ABOUT? The byte comparison proves the
          output and says nothing about the cause -- which is exactly how a section about
          `plural.arity` came to demonstrate a non-integer count instead, and stayed green for
          a week. At least ONE example per article must actually produce the article's code;
          the others are free to be counter-examples, which is what that section needed. }
        if section <> '' then
        begin
          sectionHadExamples := True;
          if Pos(':' + section + '@', RowsOf(doc_, ctx)) > 0 then sectionShown := True;
        end;
        { THE `spx-good` CLAIM, held to. An example that says it is correct and draws a row is
          the same class of defect as an article that demonstrates the wrong code -- plausible
          prose, green bytes, and untrue. }
        if isGood then
        begin
          Check('help/' + label_ + '/a good example draws nothing: ' +
                StringReplace(doc_, #10, ' / ', [rfReplaceAll]),
                RowsOf(doc_, ctx), '<none>');
          Inc(good);
        end;
        Inc(checked);
      end;
      doc_ := '';
      skip := False;
    end;

    { The last article, which no following heading closed. }
    if (section <> '') and sectionHadExamples and (not sectionShown) then
      undemonstrated := undemonstrated + section;
    { An article with NO example is allowed and says why in its own prose -- three of them do.
      An article WITH examples that demonstrates something else is the defect this catches. }
    Check('help/' + label_ + '/every article with examples demonstrates its own code',
          Trim(undemonstrated), '');

    { ── what the document declared about itself, before trusting any of it ── }
    CheckTrue('help/' + label_ + '/declares a fixture block', haveFixture);
    { The folder IS the claim about language, so the two must agree -- through the engine's own
      normaliser, so `docs/help/en/` can never be verified under `ru`. }
    Check('help/' + label_ + '/locale matches the folder',
          NormalizeBaseLang(locale), Copy(label_, 1, Pos('/', label_ + '/') - 1));
    CheckTrue('help/' + label_ + '/declares a seed', seed <> 0);
    CheckTrue('help/' + label_ + '/declares a word for empty output', empty_ <> '');
    { EXACT, not a floor. A shared floor let one document satisfy it for another, and ten
      examples could vanish from this one without a word. }
    Check('help/' + label_ + '/example count', IntToStr(checked), IntToStr(ADoc.Examples));
    NoteFixtureIncludes(ADoc.Path, set_.Count);
    { The same ratchet over the claims. Without it the `spx-good` contract is opt-in in the one
      direction that matters: removing the tag removes the check, and green means nothing. }
    Check('help/' + label_ + '/good-example count', IntToStr(good), IntToStr(ADoc.Good));
  finally
    lines.Free;
    set_.Free;
  end;
end;

(* ONE ARTICLE PER CODE, and the check that keeps it.

   The diagnostics panel is to open the article for a row's code on a double click. That entry
   point rests entirely on every code having a heading of its own -- and when this check was
   first written the document had fifteen articles for seventeen engine codes, because two
   headings carried two codes each and one of the pair was abbreviated, so the string
   `permutation.maxsize-not-integer` appeared nowhere in the help at all. A door that silently
   leads nowhere for three codes is worse than no door.

   The rule: a `###` heading whose first token is a backticked code IS that code's article, and
   there must be exactly one per code -- seventeen from the engine and five Studio notes, which
   the panel shows in the same list and whose rows carry codes just the same. *)
function HelpArticles(const APath: string): TStringList;
var lines: TStringList; i, a, b: Integer; t: string;
begin
  Result := TStringList.Create;
  lines := TStringList.Create;
  try
    lines.Text := SpxReadTextFile(APath);
    for i := 0 to lines.Count - 1 do
    begin
      t := Trim(lines[i]);
      if Copy(t, 1, 4) <> '### ' then Continue;
      t := Trim(Copy(t, 5, MaxInt));
      if Copy(t, 1, 1) <> '`' then Continue;
      a := 2;
      b := a;
      while (b <= Length(t)) and (t[b] <> '`') do Inc(b);
      if b > Length(t) then Continue;
      Result.Add(Copy(t, a, b - a));
    end;
  finally
    lines.Free;
  end;
end;

procedure CheckHelpArticles(const APath: string);
var arts: TStringList; label_, missing, doubled: string; i: Integer; k: TSpxNoteKind;
  { Measured: without this, a document that moved raised EFOpenError out of SpxReadTextFile and
    killed the run -- fifteen later procedures never ran and no summary printed. A missing
    document must FAIL, which CheckHelpDoc already reports, not take the suite with it. }

  procedure Want(const ACode: string);
  var n, j: Integer;
  begin
    n := 0;
    for j := 0 to arts.Count - 1 do
      if arts[j] = ACode then Inc(n);
    if n = 0 then missing := missing + ACode + ' '
    else if n > 1 then doubled := doubled + ACode + ' ';
  end;

begin
  if not FileExists(APath) then Exit;
  label_ := HelpLabel(APath);
  arts := HelpArticles(APath);
  try
    missing := '';
    doubled := '';
    for i := Low(ENGINE_CODES) to High(ENGINE_CODES) do Want(ENGINE_CODES[i]);
    { The notes are the panel's rows too, and their slugs come from the one function that
      mints them -- restating the list here would be a second source to drift. }
    for k := Low(TSpxNoteKind) to High(TSpxNoteKind) do Want(SpxNoteCode(k));
    Check('help/' + label_ + '/every code has an article', Trim(missing), '');
    Check('help/' + label_ + '/no code has two articles', Trim(doubled), '');
  finally
    arts.Free;
  end;
end;

(* THE UNIT THAT SHIPS, checked against the markdown that was verified.

   TestHelpExamples proves the DOCUMENTS are true: every example rendered through the real
   engine, byte-compared, each article demonstrating its own code. This proves the .exe carries
   those same documents -- which is a different claim, and the one a reader actually depends on.
   A help window showing last week's text would pass every check above this line.

   Three independent grips, because each leaves a hole the others close:
     * the DIGEST catches a markdown edit with no regeneration -- the everyday case;
     * the STRUCTURE catches a generator that emitted the wrong thing, which a digest cannot
       see because the digest is of the input;
     * RE-DERIVATION from the emitted HTML catches a table that drifted from its own bytes,
       which is the discipline TestSprites already uses on the sprite's IHDR. *)
{ The digits of an XML attribute value, which is all the version check wants from a line. }
function Digits(const ALine: string): string;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(ALine) do
    if (ALine[i] >= '0') and (ALine[i] <= '9') then Result := Result + ALine[i];
end;

(* THE ABOUT BOX IS A LICENCE OBLIGATION, and NOTICE.md says so in its own words: "anything
   here that requires attribution must also appear in the application's About box -- the About
   box is the copy a user can actually read, and this file is the copy an audit can."

   So the two are held to each other. Not by eye: the unit is generated from the file, and these
   checks are what make the generation load-bearing rather than a convenience. *)
(* THE SILENCES CHAPTER, held to two rules.

   A silence is a behaviour that produces no diagnostic at all -- a `#include` that is not alone
   on its line is plain text, an unclosed comment eats the rest of the file -- and the reader
   meets it only by being told. Nothing else in this suite can catch one: a silence has no code
   to enumerate, which is why the chapter exists.

   WHAT CAN BE HELD IS THE CHAPTER'S OWN DISCIPLINE. Every claim it makes must be SHOWN --
   followed by an example that ran through the real engine -- and the number of claims is a
   ratchet, so a silence added or removed is a deliberate edit of a number rather than a quiet
   change to a document nobody diffs.

   THE COUNTS DIFFER BY LANGUAGE, AND THAT IS CORRECT rather than a gap. Two of the Russian
   silences are about Cyrillic -- a bare `.рф` domain is not shielded, `т.е.` is not recognised
   as an abbreviation -- because the engine's word-boundary check is ASCII. They are not English
   readers' silences, and a shared list would have forced one language to carry the other's. *)
procedure TestHelpSilences;
var lang, page, at, nextAt, claims, shown, ex: Integer; html: string;
    facts: THelpLangFacts;
begin
  for lang := 0 to SPX_HELP_LANG_COUNT - 1 do
  begin
    page := SpxHelpPageIndex(lang, 'silences');
    CheckTrue('help/silences/' + SpxHelpLangCode(lang) + '/the chapter is where the slug says',
              page >= 0);
    if page < 0 then Continue;
    html := SpxHelpPageHtml(lang, page);
    claims := 0;
    shown := 0;
    at := Pos('<p><b>', html);
    while at > 0 do
    begin
      Inc(claims);
      nextAt := PosEx('<p><b>', html, at + 6);
      if nextAt = 0 then nextAt := Length(html) + 1;
      { Demonstrated before the next claim begins -- an example further down the page belongs
        to a different silence. }
      ex := PosEx('<small><tt>', html, at);
      if (ex > 0) and (ex < nextAt) then Inc(shown);
      if nextAt > Length(html) then Break;
      at := nextAt;
    end;
    Check('help/silences/' + SpxHelpLangCode(lang) + '/every claim is shown, not just made',
          IntToStr(shown), IntToStr(claims));
    { A number, deliberately: see above. Per language, because two of the Russian silences are
      about Cyrillic text and have no English counterpart. }
    if HelpFactsFor(SpxHelpLangCode(lang), facts) then
      Check('help/silences/' + SpxHelpLangCode(lang) + '/the chapter still names this many',
            IntToStr(claims), IntToStr(facts.Silences))
    else
      Check('help/silences/' + SpxHelpLangCode(lang) + '/has a row in HELP_LANG_FACTS',
            'missing', 'present');
  end;
end;

(* THE OFFLINE CLAIM, WHICH IS NOW A PUBLISHED ONE. docs/privacy.md tells the Store and its
   readers that this application collects nothing and sends nothing, and a promise of that kind
   is exactly the sort that stops being true by accident: one `uses fphttpclient` in a later
   version and the page is a lie nobody edited.

   So the claim is held the way the help's examples are held -- to the code, mechanically. The
   uses clause of every unit that ships is read, and a network unit in any of them fails the
   build. Read from the SOURCE rather than from a list kept beside it, because a list would be
   the thing that goes stale.

   The links are counted too, and counting them is NOT a claim that they are network traffic:
   handing an address to the shell is the user's own act, and the request that follows is their
   browser's. What the count defends is the ENUMERATION -- the policy names each mark, so a
   third one would make the page's list false while every other check stayed green. *)
procedure TestOfflineClaim;
const
  { Unit names that mean a socket is being opened. Whole words, matched inside a uses clause
    only, so a comment mentioning one of them is not a failure. }
  NET_UNITS: array[0..9] of string = (
    'fphttpclient', 'httpsend', 'ftpsend', 'smtpsend', 'ssockets', 'sockets',
    'winsock', 'winsock2', 'opensslsockets', 'netdb');
var
  dirs: array[0..2] of string;
  d, i: Integer;
  rec: TSearchRec;
  text_, low_, clause, name_: string;
  at, stop, opens: Integer;

  { Every uses clause in the file, joined -- a unit may have one in the interface and one in
    the implementation. }
  function UsesClauses(const ASource: string): string;
  var p_, q_: Integer;
  begin
    Result := '';
    p_ := 1;
    repeat
      p_ := PosEx('uses', ASource, p_);
      if p_ = 0 then Break;
      q_ := PosEx(';', ASource, p_);
      if q_ = 0 then q_ := Length(ASource);
      Result := Result + ' ' + Copy(ASource, p_, q_ - p_ + 1);
      p_ := q_ + 1;
    until False;
  end;

  { A whole-word search, so `Sockets` matches and `SpxSocketsDemo` would not. }
  function HasWord(const AHay, ANeedle: string): Boolean;
  var k: Integer; before_, after_: Char;
  begin
    Result := False;
    k := 1;
    repeat
      k := PosEx(ANeedle, AHay, k);
      if k = 0 then Exit;
      if k = 1 then before_ := ' ' else before_ := AHay[k - 1];
      if k + Length(ANeedle) > Length(AHay) then after_ := ' '
      else after_ := AHay[k + Length(ANeedle)];
      if not (before_ in ['a'..'z', 'A'..'Z', '0'..'9', '_', '.']) and
         not (after_ in ['a'..'z', 'A'..'Z', '0'..'9', '_', '.']) then Exit(True);
      Inc(k, Length(ANeedle));
    until False;
  end;

begin
  { The page exists and still says the thing the checks below defend. }
  text_ := SpxReadTextFile('docs/privacy.md');
  CheckTrue('offline/the privacy policy is where the Store will point', Length(text_) > 400);
  CheckTrue('offline/and it still promises nothing is collected',
            Pos('collect, transmit or store any', text_) > 0);
  { AND NAMES EVERY MARK THAT LEAVES. The count below would go on passing if a link were moved
    from one brand to another, so the page is asked for both by name -- a reader checking the
    policy against the window has to find what they clicked in it. }
  CheckTrue('offline/the policy names the spintax.net mark', Pos('spintax.net', text_) > 0);
  CheckTrue('offline/the policy names the 301.st mark', Pos('301.st', text_) > 0);

  dirs[0] := 'src';
  dirs[1] := 'gui';
  dirs[2] := 'gui/lang';
  opens := 0;
  for d := 0 to High(dirs) do
  begin
    if FindFirst(dirs[d] + '/*.pas', faAnyFile, rec) <> 0 then
    begin
      Check('offline/' + dirs[d] + ' has units to read', 'found', 'none');
      Continue;
    end;
    try
      repeat
        if (rec.Attr and faDirectory) <> 0 then Continue;
        text_ := SpxReadTextFile(dirs[d] + '/' + rec.Name);
        low_ := LowerCase(text_);
        clause := LowerCase(UsesClauses(low_));
        { ONE CHECK PER FILE, naming the unit it found. Per file AND per name would be five
          hundred lines of green saying one thing, and a suite whose count is mostly noise is
          a suite nobody reads the count of. }
        name_ := '';
        for i := Low(NET_UNITS) to High(NET_UNITS) do
          if HasWord(clause, NET_UNITS[i]) then name_ := NET_UNITS[i];
        Check('offline/' + rec.Name + ' opens no socket', name_, '');
        { And the one outbound call, counted across the whole product. }
        at := 1;
        repeat
          at := PosEx('openurl(', low_, at);
          if at = 0 then Break;
          Inc(opens);
          Inc(at, 8);
        until False;
      until FindNext(rec) <> 0;
    finally
      FindClose(rec);
    end;
  end;
  { EXACTLY TWO, because the policy names two -- the spintax.net ribbon on the rail and the
    301.st mark in the status bar. A third is not a defect in itself; it is a list in a
    published document becoming incomplete, which is why this number moves only together with
    the page. It read one until 2026-08-04, and the count is what forced the page to be edited
    when the second link was added rather than after somebody noticed. }
  Check('offline/exactly two links hand an address to the shell', IntToStr(opens), '2');
  { Belt and braces: nothing in the product opens a process either. }
  stop := 0;
  for d := 0 to High(dirs) do
  begin
    if FindFirst(dirs[d] + '/*.pas', faAnyFile, rec) <> 0 then Continue;
    try
      repeat
        low_ := LowerCase(SpxReadTextFile(dirs[d] + '/' + rec.Name));
        if (Pos('createprocess(', low_) > 0) or (Pos('shellexecute(', low_) > 0) then
        begin
          Inc(stop);
          name_ := rec.Name;
        end;
      until FindNext(rec) <> 0;
    finally
      FindClose(rec);
    end;
  end;
  Check('offline/and nothing launches a process [' + name_ + ']', IntToStr(stop), '0');
end;

procedure TestAbout;
var i, j, dots, at, stop, seen_: Integer; text_, name_: string; found: Boolean;
    body: TStringList;
begin
  { A version at all, and in the shape a Store package manifest wants -- four numbers. The
    reader sees this string and so does Partner Center; there is one line behind both. }
  CheckTrue('about/there is a version', SPX_VERSION <> '');
  dots := 0;
  for i := 1 to Length(SPX_VERSION) do
    if SPX_VERSION[i] = '.' then Inc(dots);
  Check('about/the version has four parts', IntToStr(dots), '3');
  for i := 1 to Length(SPX_VERSION) do
    CheckTrue('about/the version is digits and dots [' + SPX_VERSION + ']',
              (SPX_VERSION[i] = '.') or ((SPX_VERSION[i] >= '0') and (SPX_VERSION[i] <= '9')));

  { The engine's version, said out loud, because this is one of four implementations held to a
    shared corpus and a difference between them is reported against a build. }
  CheckTrue('about/the engine version is named', Copy(SPX_ENGINE_VERSION, 1, 1) = 'v');

  { AND THE SAME NUMBER IN THE EXECUTABLE'S OWN RESOURCE. `VERSION` is what the reader sees;
    `<VersionInfo>` in the project file is what Partner Center, Explorer's Details tab and a
    crash report read. Two places, so they are compared -- the generator's docstring says "the
    manifest and the screen cannot disagree" and this is what makes that true rather than
    aspirational. Review found the resource missing entirely. }
  body := TStringList.Create;
  try
    body.Text := SpxReadTextFile('gui/SpintaxStudio.lpi');
    at := Pos('<VersionInfo>', body.Text);
    CheckTrue('about/the project declares a version resource', at > 0);
    name_ := '';
    for i := 0 to body.Count - 1 do
    begin
      if Pos('<MajorVersionNr Value="', body[i]) > 0 then name_ := name_ + Digits(body[i]) + '.';
      if Pos('<MinorVersionNr Value="', body[i]) > 0 then name_ := name_ + Digits(body[i]) + '.';
      if Pos('<RevisionNr Value="', body[i]) > 0 then name_ := name_ + Digits(body[i]) + '.';
      if Pos('<BuildNr Value="', body[i]) > 0 then name_ := name_ + Digits(body[i]);
    end;
    Check('about/the resource carries the version the box shows', name_, SPX_VERSION);
    CheckTrue('about/and its string table repeats it',
              Pos('ProductVersion="' + SPX_VERSION + '"', body.Text) > 0);

    { AND ITS COPYRIGHT FIELD NAMES A HOLDER, NOT A LICENCE. `LegalCopyright` is what Explorer's
      Details tab shows, and the shipped 0.1.0.0 carried the bare word `MIT` there while LICENSE
      said Apache-2.0 and the About box agreed with LICENSE: three answers about one product, and
      the only one a user can see was the wrong one. The wording is not pinned -- the holder is,
      against the About box, so a relicence cannot leave the executable behind again. }
    at := Pos('LegalCopyright="', body.Text);
    CheckTrue('about/the resource declares a copyright', at > 0);
    name_ := Copy(body.Text, at + Length('LegalCopyright="'), 300);
    name_ := Copy(name_, 1, Pos('"', name_) - 1);
    CheckTrue('about/the copyright field names the holder [' + name_ + ']',
              Pos('301.st', name_) > 0);
  finally
    body.Free;
  end;

  text_ := '';
  for i := 0 to SpxAboutLineCount - 1 do text_ := text_ + SpxAboutLine(i) + #10;
  CheckTrue('about/there is something to read', Length(text_) > 200);

  { EVERY LICENCE THE FILE NAMES IS IN THE TEXT THAT SHIPS. The generator collected them while
    reading NOTICE.md; this asks the shipped lines for each one. }
  CheckTrue('about/licences were collected', SpxAboutLicenceCount > 0);
  for i := 0 to SpxAboutLicenceCount - 1 do
    CheckTrue('about/the shipped text names ' + SpxAboutLicence(i),
              Pos(SpxAboutLicence(i), text_) > 0);

  { AND EVERY ENTRY THE FILE OBLIGES US TO SHOW. This half is a legal requirement rather than
    good manners. }
  CheckTrue('about/obliged entries were collected', SpxAboutObligedCount > 0);
  for i := 0 to SpxAboutObligedCount - 1 do
    CheckTrue('about/the shipped text names ' + SpxAboutObliged(i),
              Pos(SpxAboutObliged(i), text_) > 0);

  { THE OTHER DIRECTION, and it is the one that catches the drift the generator cannot see:
    NOTICE.md gained an entry and nobody re-ran the script. Read from the file on disk, over
    the obliging section only -- the sections below it name libraries the licences do not
    require us to attribute. }
  { BY LINES, and that is the whole of the fix. The first version searched the text for `## ` and
    for `**` anywhere: a code span naming a heading inside an entry's prose cut the section short,
    and the check then stopped running -- measured by review, a planted failure DISAPPEARED and
    took the Twemoji check with it, 7213 checks and 0 failed. A check that goes quiet is worse
    than one that fails, so the count it found is asserted too. }
  body := TStringList.Create;
  try
    body.Text := SpxReadTextFile('NOTICE.md');
    CheckTrue('about/NOTICE.md is where it was', body.Count > 20);
    at := -1;
    for i := 0 to body.Count - 1 do
      if Trim(body[i]) = '## Requires attribution in the shipped application' then at := i;
    CheckTrue('about/NOTICE.md still has the obliging section', at >= 0);
    seen_ := 0;
    if at >= 0 then
      for i := at + 1 to body.Count - 1 do
      begin
        if Copy(body[i], 1, 3) = '## ' then Break;
        { An entry starts a line with `**`; bold inside prose does not. }
        if Copy(body[i], 1, 2) <> '**' then Continue;
        stop := PosEx('**', body[i], 3);
        if stop = 0 then Continue;
        name_ := Copy(body[i], 3, stop - 3);
        Inc(seen_);
        found := False;
        for j := 0 to SpxAboutObligedCount - 1 do
          if SpxAboutObliged(j) = name_ then found := True;
        CheckTrue('about/NOTICE.md''s obliged entry [' + name_ + '] reached the About box',
                  found);
      end;
    { The number of entries this check actually looked at, so it cannot pass by not running. }
    Check('about/as many obliged entries in the file as in the box',
          IntToStr(seen_), IntToStr(SpxAboutObligedCount));
  finally
    body.Free;
  end;
end;

(* THE BRAND MARK, read back out of the executable. The rail draws it through an image list,
   which takes the frame's WIDTH and HEIGHT as arguments and stretches whatever it is given --
   so a frame whose real size drifted from the table beside it would not fail, it would draw
   the ribbon squashed and nothing here would notice. Hence the PNG's own IHDR: the one
   description of a frame that cannot drift from the frame.

   The same discipline as TestSprites, which checks the language flags the same way for the same
   reason: they are 4:3, so their height is a fact rather than a copy of their width, and this
   mark is 2.25:1. Square glyphs are the icon strip's case, not the product's rule. *)
(* THE GSA IMPORT, and what is checked is CONVERT-THEN-RENDER rather than the converted text.
   The engine's own suite makes that point and paid for it: a converter's output looks right in
   a diff and is wrong in a renderer, which is the only place it matters. So every case here
   renders the document with the variables the import produced, exactly the way the window
   will, and compares the OUTPUT with the GSA template's meaning.

   The values are checked too, and they are the reason this unit exists: what the panel shows a
   reader must be the readable text (`[`, `/#`), while what the engine receives must be the
   neutralised form the converter meant. `SpxValueForEngine` is what makes the second true, so
   the round trip is asserted rather than assumed. *)
(* ---------------------------------------------------------------------------
   THE VARIANT COUNT, CHECKED BY ENUMERATION.

   The counter is arithmetic over the editor's own token scan, and arithmetic is exactly the
   kind of thing that is convincingly wrong. So nothing here is compared against a number
   this file believes: every small template below is RENDERED with thousands of seeds through
   the real engine, the distinct outputs are collected, and the count has to equal how many
   there were. When the two disagree the engine is right by construction.

   Post-processing is off for the enumeration, and deliberately: it capitalizes and re-spaces,
   so it can MERGE two structurally different results into one text and make an honest count
   look too big. The window shows the structural number -- how many ways the template can be
   filled in -- which is what an author is asking when they ask how thin the template is.
   --------------------------------------------------------------------------- *)
procedure TestVariantCount;
var
  ctx: TSpxContext;
  vars: TStrMap;
  set_: TSpxTemplateSet;
  lit: TSpxVarPair;
  big: string;
  i: Integer;

  { Every distinct text this template makes, over enough seeds that missing one is not a
    realistic outcome: for a construct of n variants the seeds needed to see them all is
    about n·ln n, and n here is at most a few dozen against 20 000 seeds. }
  function Enumerate(const Tmpl: string): Integer;
  var
    list: TSpxVariantList;
    seen: TStringList;
    i: Integer;
  begin
    seen := TStringList.Create;
    list := SpxRenderBatch(Tmpl, ctx, 20000, 1);
    try
      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      seen.CaseSensitive := True;
      for i := 0 to list.Count - 1 do seen.Add(list[i].Text);
      Result := seen.Count;
    finally
      list.Free;
      seen.Free;
    end;
  end;

  procedure CheckCounted(const name, Tmpl: string);
  var c: TSpxCount; n: Integer;
  begin
    c := SpxCountVariants(Tmpl, ctx);
    n := Enumerate(Tmpl);
    Check('count/' + name, IntToStr(c.Value), IntToStr(n));
    CheckTrue('count/' + name + '/exact', c.Exact);
  end;

  (* THE PROMISE, GATED INSTEAD OF ASSERTED. When the panel says "at least N" the only thing
     that makes the sentence true is N <= what the template really produces, and a written-down
     number cannot check that -- it only records what the counter said on the day. So these
     enumerate too, and compare with <= rather than =.

     A review found the counter reporting "at least 2" about a document that makes 1
     (`#include "f" junk`, which is not an include at all), so this is the check that class of
     defect fails against. It also insists the answer is NOT marked exact: a case that lands
     here is one the counter has admitted it cannot promise. *)
  procedure CheckFloor(const name, Tmpl: string);
  var c: TSpxCount; n: Integer;
  begin
    c := SpxCountVariants(Tmpl, ctx);
    n := Enumerate(Tmpl);
    Inc(Checks);
    if c.Value > n then
    begin
      Inc(Failures);
      Writeln('FAIL count/', name, ': said at least ', c.Value, ', engine makes ', n);
    end;
    Check('count/' + name + '/is-a-bound', BoolToStr(c.Exact, True), BoolToStr(False, True));
  end;

  procedure CheckSays(const name, Tmpl: string; want: Int64; wantExact: Boolean);
  var c: TSpxCount;
  begin
    c := SpxCountVariants(Tmpl, ctx);
    Check('count/' + name, IntToStr(c.Value), IntToStr(want));
    Check('count/' + name + '/exact', BoolToStr(c.Exact, True), BoolToStr(wantExact, True));
  end;

begin
  vars := TStrMap.Create;
  try
    ctx := SpxContext('en', vars);
    ctx.PostProcess := False;

    { ---- what the count means, every line of it enumerated ---- }
    CheckCounted('plain', 'no constructs at all');
    CheckCounted('choice', '{aa|bb|cc}');
    CheckCounted('two-choices', '{aa|bb} and {cc|dd}');
    { The help says this one makes four, in both languages. It says so because this line
      renders it and counts what came out. }
    CheckCounted('help-example', '{a|b} and {c|d}');
    CheckCounted('nested', '{aa|bb{cc|dd|ee}}');
    CheckCounted('empty-option', '{aa|}');
    CheckCounted('perm', '[aa|bb|cc]');
    CheckCounted('perm-subset', '[<minsize=2>aa|bb|cc]');
    CheckCounted('perm-inner', '[aa|{bb|cc}]');
    CheckCounted('set-twice', '#set %x% = {aa|bb}' + LineEnding + '%x% %x%');
    { One draw used twice: here ways and texts agree, so it can be enumerated. }
    CheckCounted('def-twice', '#def %x% = {aa|bb}' + LineEnding + '%x% %x%');
    CheckCounted('comment-hides', '/# {aa|bb} #/ {cc|dd|ee}');

    { A permutation inside a choice and the other way round: the arithmetic composes, or it
      is not arithmetic. }
    CheckCounted('perm-in-choice', '{aa|[bb|cc]}');
    CheckCounted('choice-in-perm', '[{aa|bb}|{cc|dd}]');
    CheckCounted('perm-max', '[<minsize=1;maxsize=2>aa|bb|cc]');
    CheckCounted('set-in-set', '#set %a% = {aa|bb}' + LineEnding +
                               '#set %b% = %a% {cc|dd}' + LineEnding + '%b%');

    { A resolved `#include` counts the fragment, and the answer stays a promise -- the set
      knows the target, so nothing is unknown about it. }
    set_ := TSpxTemplateSet.Create;
    try
      set_.AddOrSetValue('frag', '{cc|dd|ee}');
      ctx := SpxContext('en', vars, set_);
      ctx.PostProcess := False;
      CheckSays('include-known', '#include "frag"' + LineEnding + '{aa|bb}', 6, True);
      { Twice, and each occurrence rolls again -- the same rule as `#set`. }
      CheckSays('include-twice', '#include "frag"' + LineEnding + '#include "frag"', 9, True);
    finally
      ctx := SpxContext('en', vars);
      ctx.PostProcess := False;
      set_.Free;
    end;

    (* WHAT THE NUMBER COUNTS, stated as a check because it is a decision and not an
       accident: it counts the WAYS the template can be filled in, not how many different
       texts come out. `{aa|aa}` is two ways and one text. Collapsing them would mean
       rendering every combination, which is the thing the number exists to avoid doing, and
       it would also lie in the other direction -- two options that happen to match here can
       stop matching after one edit. GTW's «Max возможных вариантов» counts the same way. *)
    CheckSays('duplicate-options', '{aa|aa}', 2, True);

    (* ---- WHAT AN OUTSIDE REVIEW FOUND, each reproduced before it was believed and each a
       failure of this file's own coverage: every one of them was invisible to a suite that
       only ever asked the counter about templates the counter's author had in mind. ---- *)

    { The permutation's SIZE RANGE is four asymmetric branches in the engine
      (`Spintax.pas:1830-1837`), not one rule with defaults. Only-maxsize starts at ONE;
      minsize=0 is a value and not an absence; and a contradictory pair WIDENS. }
    CheckCounted('perm-maxsize-only', '[<maxsize=2>aa|bb|cc]');
    CheckCounted('perm-minsize-zero', '[<minsize=0>aa|bb|cc]');
    CheckCounted('perm-min-over-max', '[<minsize=3;maxsize=2>aa|bb|cc]');
    CheckCounted('perm-both', '[<minsize=1;maxsize=2>aa|bb|cc]');

    { A directive ends at any of FIVE terminators; the editor counts THREE. So this is one
      editor line carrying a directive AND a choice, and masking the line threw the choice
      away. U+2028 is E2 80 A8. }
    CheckCounted('u2028-then-body', '#set %x% = qq'#$E2#$80#$A8'{aa|bb} %x%');

    { An `#include` whose target is on the next line: the engine resolves it, the presentation
      scanner does not see it, and the honest answer is a floor rather than a wrong promise. }
    set_ := TSpxTemplateSet.Create;
    try
      set_.AddOrSetValue('frag', '{cc|dd|ee}');
      ctx := SpxContext('en', vars, set_);
      ctx.PostProcess := False;
      (* An `#include` whose target is on the next line. This was the counter's own reason to
         call a document a lower bound, and it is exact now: the scanner carries the wait, so
         the target arrives as a target. What is NOT claimed is the keyword's colour -- see
         SpxTokens -- which the count never needed. *)
      CheckCounted('include-next-line', '#include' + LineEnding + '"frag"' + LineEnding +
                                        '{aa|bb}');
      CheckCounted('include-next-line-indented', '#include' + LineEnding + '   "frag"');
      CheckCounted('include-after-a-blank-line', '#include' + LineEnding + LineEnding +
                                                 '"frag"');
      { And the shapes that are not includes are counted as the one text they are. }
      CheckCounted('include-then-prose', '#include' + LineEnding + 'x "frag"');
      CheckCounted('include-alone', '#include');
      (* Measured and deliberately not claimed: the engine strips comments before it looks for
         directives, so this IS an include to it and the scanner does not follow it there.
         A floor, not a wrong promise. *)
      CheckFloor('include-target-behind-a-comment', '#include' + LineEnding + '/# c #/ "frag"');
    finally
      ctx := SpxContext('en', vars);
      ctx.PostProcess := False;
      set_.Free;
    end;
    (* ---- A SESSION VALUE IS A TEMPLATE, AND IT OUTRANKS THE DOCUMENT ----

       Both measured against the engine, which overlays the host's table on top of the `#set`
       definitions (`Spintax.pas:3145-3151`). The counter used to skip runtime variables
       altogether, so a reader who typed `{aa|bb}` into the Variables panel was told the
       template had half the variants it has. *)
    vars.AddOrSetValue('x', '{aa|bb}');
    ctx := SpxContext('en', vars);
    ctx.PostProcess := False;
    CheckCounted('session-value', '%x% and {cc|dd}');
    { And re-rolled at every use, exactly like a `#set`. }
    CheckCounted('session-twice', '%x% %x%');
    { The document says `qq`; the session says otherwise, and the session is what renders. }
    vars.AddOrSetValue('y', '{ee|ff}');
    CheckCounted('session-outranks-set', '#set %y% = qq' + LineEnding + '%y%');
    (* A LITERAL session value means itself, and needs no special case here: the window hands
       it over neutralised, so its braces are already sentinels by the time anything counts
       them. This check is the proof that the absence of a special case is correct rather than
       an oversight -- it goes through SpxValueForEngine exactly as the window does. *)
    lit.Name := 'z';
    lit.Value := '{gg|hh}';
    lit.Literal := True;
    vars.AddOrSetValue('z', SpxValueForEngine(lit));
    CheckCounted('session-literal', '%z% and {cc|dd}');
    vars.Clear;
    ctx := SpxContext('en', vars);
    ctx.PostProcess := False;
    (* ---- A `#def` IS ONE DRAW FOR THE DOCUMENT, wherever it is written ----

       The engine rolls every definition once, before the body, dependencies first, and
       whether the body uses it or not (`Spintax.pas:3162-3184`). So it multiplies the
       document once and NOT the option it happens to sit in. These two cannot be enumerated
       against the engine, because they are the case where ways and distinct texts genuinely
       differ: the second makes three texts and the first two, while both have four draws.
       That is the same rule `duplicate-options` records, seen from the other side.

       The version that multiplied a `#def` into the enclosing option answered 3 for the
       first of these -- neither the draws nor the texts, which is how an outside review
       found it. *)
    CheckSays('def-both-alts', '#def %d% = {aa|bb}' + LineEnding + '{%d%|%d%}', 4, True);
    CheckSays('def-one-alt', '#def %d% = {aa|bb}' + LineEnding + '{%d%|plain}', 4, True);
    { A definition nothing references is not a draw the reader can see, so it is not counted. }
    CheckSays('def-unused', '#def %d% = {aa|bb}' + LineEnding + '{cc|dd}', 2, True);

    (* ---- A REDEFINED MACRO IS THE LAST ONE, and a `#def` beats a `#set` ----

       `ExtractDirectives` keeps the two kinds in separate maps, each last-wins
       (`Spintax.pas:1227`), and the render lays the definitions over the sets. Reading the
       FIRST match out of a flat list answered 2 where the engine makes 3 -- found here, not
       by review, while replacing that list with the engine's own two layers. Redefining a
       variable is the first question a reader of this project ever asked, so it is not an
       exotic shape. *)
    CheckCounted('redefined-set', '#set %x% = {aa|bb}' + LineEnding +
                                  '#set %x% = {cc|dd|ee}' + LineEnding + '%x%');
    CheckCounted('redefined-def', '#def %x% = {aa|bb}' + LineEnding +
                                  '#def %x% = {cc|dd|ee}' + LineEnding + '%x%');
    { Whichever order they are written in: the `#def` is rolled after the sets are laid down. }
    CheckCounted('def-beats-set', '#set %x% = {aa|bb}' + LineEnding +
                                  '#def %x% = {cc|dd|ee}' + LineEnding + '%x%');
    CheckCounted('def-beats-set-reversed', '#def %x% = {cc|dd|ee}' + LineEnding +
                                           '#set %x% = {aa|bb}' + LineEnding + '%x%');

    (* ---- WHAT THE SECOND REVIEW FOUND. Every one reproduced against the engine before it
       was believed, and every one the same shape: `SpxTokens` is a PRESENTATION scan whose own
       header only promises never to claim a construct the engine does not see -- it promises
       nothing in the other direction, and this file had been reading its opinion as engine
       truth. Where the two can disagree, the answer is now a floor. ---- *)

    { An unterminated `/#` is ordinary text to the engine since v0.5.0 and still a comment to
      the scanner, so everything below it vanished from the count -- which is the state of the
      document for every keystroke between typing the opener and the closer. }
    CheckFloor('open-comment', '{aa|bb}' + LineEnding + '/# note' + LineEnding + '{cc|dd}');
    CheckFloor('open-comment-inline', 'xx /# note {cc|dd}');
    { A terminated one is not affected: the engine drops it too. }
    CheckCounted('closed-comment', '/# {aa|bb} #/ {cc|dd|ee}');

    { A closer of the wrong kind is not a closer. This reported 120 for a template the engine
      renders verbatim as one text. }
    CheckFloor('bracket-closed-by-brace', '[aa|bb|cc|dd|ee}');
    CheckFloor('brace-closed-by-bracket', '{aa|bb|cc]');

    { A macro chain deeper than the engine's MAX_VARIABLE_DEPTH renders the unexpanded name. }
    big := '#set %v0% = {aa|bb}' + LineEnding;
    for i := 1 to 60 do
      big := big + '#set %v' + IntToStr(i) + '% = %v' + IntToStr(i - 1) + '%' + LineEnding;
    CheckFloor('macro-chain-past-50', big + '%v60%');

    { The input picks the branch, but the branch still holds what is inside it. This answered
      one, which is what a whole document wrapped in a single conditional would have shown. }
    CheckFloor('conditional-branch-contents', '{?v?{aa|bb}|{cc|dd}}');
    { And a plural is NOT a conditional: a form holding a construct makes the engine print the
      whole thing verbatim, so the biggest form is not a floor there. Measured; this line is
      what failed when the first fix treated the two alike. }
    CheckFloor('plural-form-contents', '{plural 2: {aa|bb}|{cc|dd}}');
    CheckFloor('plural-plain-forms', '{plural 2: one|many}');

    set_ := TSpxTemplateSet.Create;
    try
      set_.AddOrSetValue('f', '{aa|bb}');
      set_.AddOrSetValue('frag', '#def %d% = {aa|bb}' + LineEnding + '%d%');
      set_.AddOrSetValue('frag2', '#def %d% = {cc|dd|ee}' + LineEnding + '%d%');
      ctx := SpxContext('en', vars, set_);
      ctx.PostProcess := False;

      (* A FRAGMENT IS ITS OWN DOCUMENT. `ResolveIncludes` renders the whole thing again per
         occurrence, so a `#def` inside a fragment is rolled once PER INCLUDE -- and two
         fragments that both define `%d%` do not share a macro. One flat name-keyed list
         across the whole recursion answered 2 for each of these. *)
      CheckCounted('def-in-fragment-twice', '#include "frag"' + LineEnding + '#include "frag"');
      CheckCounted('def-in-two-fragments', '#include "frag"' + LineEnding + '#include "frag2"');

      { Trailing junk is not an include -- the engine's anchor allows only whitespace -- so the
        line is one literal text. Resolving the fragment anyway put the count ABOVE the truth,
        which is the one thing a floor may never do. }
      CheckFloor('include-with-junk', '#include "f" junk');
      { And an include can resolve without being a directive in the source at all:
        ResolveIncludes runs over the RENDERED text. }
      CheckFloor('include-inside-an-option', '{pp|#include "f"}');
    finally
      ctx := SpxContext('en', vars);
      ctx.PostProcess := False;
      set_.Free;
    end;

    (* ---- THE PERMUTATION CONFIG, WHICH THE ENGINE CORRECTED IN v0.5.1 ----

       Three of these are rules that MOVED with the pin, and this file was a release behind on
       all of them the moment the submodule advanced; two more were wrong before it and neither
       review caught them, because the counter mirrored the engine's `FindInt` and not its
       `HasConfigKey`. A `<...>` after `[` is always the config TOKEN -- the scanner is right to
       paint it -- but it is read as key/value only when a key is really there. *)

    { No key at all: the whole thing is the separator and every option is printed. }
    CheckCounted('perm-no-key', '[<maxsize 2>aa|bb|cc]');
    { A key glued to a prefix is not a key -- the engine's boundary check. }
    CheckCounted('perm-glued-key', '[<xmaxsize=1>aa|bb|cc]');
    { The `=` is REQUIRED now. With `sep=` present this IS a config, and `maxsize 2` in it used
      to cut the set to two; it prints all three. }
    CheckCounted('perm-key-needs-equals', '[<sep="-" maxsize 2>aa|bb|cc]');
    CheckCounted('perm-key-with-equals', '[<sep="-" maxsize=2>aa|bb|cc]');
    { A failed candidate retries at the next position, the way a regex does. }
    CheckCounted('perm-key-retries', '[<minsize foo minsize=1>aa|bb|cc]');
    { And a wart mirrored on purpose: a plain Pos finds a key inside a quoted separator, so
      this really is maxsize=1 in the engine too. }
    CheckCounted('perm-key-in-quoted-sep', '[<sep="maxsize=1">aa|bb|cc]');
    { An unterminated quote is not a separator match, and the config is not one either. }
    CheckCounted('perm-unclosed-quote', '[<sep="X>aa|bb|cc]');
    { HTML content is content, and must not be downgraded by the open-config detector. }
    CheckCounted('perm-html-content', '[<li>aa|bb</li>]');
    CheckCounted('perm-single-separator', '[<->aa|bb]');
    { A config the line-at-a-time scan cannot finish reading: the engine looks through the whole
      permutation, so this is a floor rather than a promise. }
    CheckFloor('perm-config-across-lines', '[<minsize' + LineEnding + '=2>aa|bb|cc]');

    { ---- and what it refuses to promise ---- }

    { A conditional is decided by the value, not by chance: with the variable unset the
      template makes ONE text, and setting it can only add. So one, and a bound. }
    CheckSays('conditional', '{?v?yes|no}', 1, False);
    CheckSays('plural', '{plural 2: one|many}', 1, False);
    { An include the set cannot resolve renders empty -- one text now, more if the fragment
      ever arrives. }
    CheckSays('unknown-include', '#include "gone"' + LineEnding + '{aa|bb}', 2, False);
    { A construct multiplied by an unpromised one keeps the bound. }
    CheckSays('mixed', '{aa|bb}{?v?yes|no}{cc|dd}', 4, False);

    { Neither of these renders -- the engine refuses them -- but both used to be a way to hang
      the window while it counted. One text, and not a promise. }
    CheckSays('macro-self', '#set %a% = %a% x' + LineEnding + '%a%', 1, False);
    CheckSays('macro-mutual', '#set %a% = %b%' + LineEnding + '#set %b% = %a%' +
                              LineEnding + '%a%', 1, False);

    { The ceiling is not a wrap: fifty three-way choices is 3^50, far past Int64 if it were
      allowed to run, and the answer has to stay a number the window can print. }
    big := '';
    for i := 1 to 50 do big := big + '{aa|bb|cc}';
    CheckSays('ceiling', big, SPX_COUNT_CEILING, True);
  finally
    vars.Free;
  end;
end;

procedure TestGsaImport;
var
  res: TSpxGsaResult;
  ctx: TSpContext;
  vars: TStrMap;
  rng: TFirstRng;
  i, lifted: Integer;
  out_, v: string;

  { The window's own path: session values through SpxValueForEngine into TSpContext.Vars. }
  function RenderWith(const ADoc: string; const APairs: TSpxVarPairs;
                      APost: Boolean): string;
  var k: Integer;
  begin
    vars := TStrMap.Create;
    rng := TFirstRng.Create;
    try
      for k := 0 to High(APairs) do
        vars.AddOrSetValue(APairs[k].Name, SpxValueForEngine(APairs[k]));
      ctx := Default(TSpContext);
      ctx.PostProcess := APost;
      ctx.Vars := vars;
      ctx.Rng := rng;
      Result := SpRender(ADoc, ctx);
    finally
      rng.Free;
      vars.Free;
    end;
  end;

begin
  { NOTHING IN, NOTHING OUT -- and no exception either: the window will call this on whatever
    file the reader picked. }
  res := SpxImportGsa('');
  Check('gsa/empty source gives an empty document', res.Doc, '');
  Check('gsa/empty source lifts nothing', IntToStr(Length(res.Vars)), '0');
  { THE RULE, AS DATA. A converted GSA template renders with the cosmetic stage off, and the
    result says so rather than leaving it to a caller who read a comment. Asserted even on the
    empty import, because that is the call a window makes on a file it could not parse. }
  CheckTrue('gsa/an import always says post-process is off', not res.PostProcess);

  { A template with no GSA construct at all comes back as itself, with nothing lifted: the
    import must not rewrite what it does not have to. }
  res := SpxImportGsa('Plain {a|b} text.');
  Check('gsa/a plain template is untouched', res.Doc, 'Plain {a|b} text.');
  Check('gsa/and lifts nothing', IntToStr(Length(res.Vars)), '0');

  { THE FOUR SHAPES THE ENGINE'S RELEASE NOTES NAME, in one template. Post-process OFF, because
    this asserts what the conversion preserves and the post-processor is prose typography --
    it rewrites even a neutralised value, which is recorded as a defect to report. }
  res := SpxImportGsa('Read [b]this[/b]. See http://x.io/#top and #file[l.txt,1,S].');
  CheckTrue('gsa/the result asks for no post-processing', not res.PostProcess);
  out_ := RenderWith(res.Doc, res.Vars, res.PostProcess);
  Check('gsa/BBCode, a fragment URL and a macro all survive a render',
        out_, 'Read [b]this[/b]. See http://x.io/#top and #file[l.txt,1,S].');
  CheckTrue('gsa/and something was lifted to do it', Length(res.Vars) > 0);

  { WITHOUT the variables the same document shows placeholders -- visibly incomplete, never
    plausible and wrong. That is the engine's design and the reason the dialog warns. }
  out_ := RenderWith(res.Doc, nil, res.PostProcess);
  CheckTrue('gsa/without its variables the document shows a placeholder',
            Pos('%', out_) > 0);
  CheckTrue('gsa/and does not silently lose the brackets', out_ <> 'Read [b]this[/b].');

  { The values are READABLE in the panel and NEUTRALISED at the engine. }
  lifted := 0;
  for i := 0 to High(res.Vars) do
  begin
    v := res.Vars[i].Value;
    CheckTrue('gsa/a lifted value carries no raw sentinel [' + res.Vars[i].Name + ']',
              v = SpSafetyRestore(v));
    CheckTrue('gsa/a lifted value is literal [' + res.Vars[i].Name + ']', res.Vars[i].Literal);
    Check('gsa/and reaches the engine neutralised [' + res.Vars[i].Name + ']',
          SpxValueForEngine(res.Vars[i]), SpNeutralize(v));
    Inc(lifted);
  end;
  CheckTrue('gsa/every lifted value was checked', lifted > 0);

  { A REFUSAL IS REPORTED, NOT TRANSLATED. A domain-bound block selects on the target URL,
    which is host context and not a spin, so the engine hands it back -- and its original text
    survives as the variable's value. }
  res := SpxImportGsa('Ship to {#.de|#.com} today.');
  Check('gsa/the refused block is reported', IntToStr(Length(res.Refused)), '1');
  CheckTrue('gsa/and it names the variable it became', res.Refused[0].Name <> '');
  Check('gsa/the original text is kept verbatim', res.Refused[0].Original, '{#.de|#.com}');
  out_ := RenderWith(res.Doc, res.Vars, res.PostProcess);
  Check('gsa/a refusal renders as the GSA text it was', out_, 'Ship to {#.de|#.com} today.');

  { AND WHY THE RULE EXISTS, pinned so nobody turns the stage back on as a tidy-up. The same
    document, rendered WITH post-processing, is edited: this is the engine defect reported in
    docs/TODO.md, and if the engine fixes it this check is what will say so. }
  res := SpxImportGsa('A #file[l.txt,1,S] B');
  CheckTrue('gsa/post-processing would rewrite the macro',
            RenderWith(res.Doc, res.Vars, True) <> RenderWith(res.Doc, res.Vars, False));
  Check('gsa/and with the stage off it is verbatim',
        RenderWith(res.Doc, res.Vars, res.PostProcess), 'A #file[l.txt,1,S] B');

  (* TWO MACROS THAT DIFFER ONLY IN CASE ARE TWO MACROS. Found by an outside review on
     2026-08-06 and reproduced here before it was believed: on engine `v0.4.0` these two
     `#file` macros shared one variable, and the render answered `A.txt` for BOTH -- a SER
     template that pulls from two lists came back pulling twice from one, silently. Fixed in
     `v0.4.1` by keying the lifted text case-sensitively.

     It is a Studio test and not only the engine's because this suite is what stands between
     the pin and a reader: the version can move under us, and a check that only ever tried one
     `#file[l.txt,…]` could not tell the two engines apart. It could not, and did not -- 8163
     checks passed over the defect. *)
  res := SpxImportGsa('A: #file[A.txt,1,S] and B: #file[a.txt,1,S]');
  Check('gsa/two macros differing only in case are two variables',
        IntToStr(Length(res.Vars)), '2');
  out_ := RenderWith(res.Doc, res.Vars, res.PostProcess);
  Check('gsa/and each keeps its own file name', out_,
        'A: #file[A.txt,1,S] and B: #file[a.txt,1,S]');

  (* AND A CONVERSION THAT CANNOT BE FAITHFUL IS REFUSED, NOT GUESSED. Tag sets that only
     PARTIALLY overlap -- `#A` in both blocks, `#B` and `#C` in one each -- describe a
     correlation this syntax cannot express, and `v0.4.0` translated them anyway, into two
     independent groups: it rendered `a then c` with nothing reported. `v0.4.1` hands both
     blocks back untranslated, which is the converter's stated contract and the reason a
     refusal list exists at all. *)
  res := SpxImportGsa('{#A a|#B b} then {#A c|#C d}');
  Check('gsa/partially overlapping tag sets are refused',
        IntToStr(Length(res.Refused)), '2');
  out_ := RenderWith(res.Doc, res.Vars, res.PostProcess);
  Check('gsa/and the GSA text survives verbatim', out_, '{#A a|#B b} then {#A c|#C d}');

  { ORDER IS STABLE, because a dictionary's is not: two imports of one template must give the
    panel the same rows in the same places. }
  res := SpxImportGsa('[b]a[/b] [i]b[/i] #file[x.txt,1,S]');
  for i := 1 to High(res.Vars) do
    CheckTrue('gsa/variables come back sorted [' + res.Vars[i].Name + ']',
              CompareStr(res.Vars[i - 1].Name, res.Vars[i].Name) < 0);
end;

procedure TestBrandMark;
var i, w, h, len, wanted, prevW: Integer; p: Pointer; ratio, srcRatio: Double;
begin
  CheckTrue('brand/there are frames', Length(SPX_MARK_WIDTHS) > 0);

  { ASCENDING, which is what the picker's one-pass rule depends on: it walks the table keeping
    the last entry that fits, so an out-of-order table would hand back something too wide. }
  prevW := 0;
  for i := Low(SPX_MARK_WIDTHS) to High(SPX_MARK_WIDTHS) do
  begin
    CheckTrue(Format('brand/width %d comes after %d', [SPX_MARK_WIDTHS[i], prevW]),
              SPX_MARK_WIDTHS[i] > prevW);
    prevW := SPX_MARK_WIDTHS[i];
  end;

  { The ribbon's aspect, from the widest frame, and every other frame held to it within a
    pixel's worth of rounding. A frame that lost the aspect is a squashed logo. }
  srcRatio := SPX_MARK_WIDTHS[High(SPX_MARK_WIDTHS)] /
              SpxMarkHeight(SPX_MARK_WIDTHS[High(SPX_MARK_WIDTHS)]);
  CheckTrue(Format('brand/the mark is the ribbon, not a square [%.3f]', [srcRatio]),
            (srcRatio > 2.0) and (srcRatio < 2.5));

  for i := Low(SPX_MARK_WIDTHS) to High(SPX_MARK_WIDTHS) do
  begin
    w := SPX_MARK_WIDTHS[i];
    h := SpxMarkHeight(w);
    CheckTrue(Format('brand/%d has a height', [w]), h > 0);
    p := SpxMarkPng(w, len);
    CheckTrue(Format('brand/%d is a png', [w]),
              (p <> nil) and (len > 8) and (PByte(p)[0] = $89) and (PByte(p)[1] = Ord('P')));
    { The bytes' OWN account of themselves, against the table. }
    Check(Format('brand/%d is %d px wide', [w, w]), IntToStr(PngWidth(p, len)), IntToStr(w));
    Check(Format('brand/%d is %d px tall', [w, h]), IntToStr(PngHeight(p, len)), IntToStr(h));
    ratio := w / h;
    CheckTrue(Format('brand/%d keeps the aspect [%.3f vs %.3f]', [w, ratio, srcRatio]),
              Abs(ratio - srcRatio) < 0.15);
  end;

  { A width nobody generated answers with nothing rather than with something else's bytes --
    the rail checks for nil and would otherwise draw a frame of the wrong size. }
  p := SpxMarkPng(SPX_MARK_WIDTHS[High(SPX_MARK_WIDTHS)] + 1, len);
  CheckTrue('brand/an unknown width has no frame', (p = nil) and (len = 0));
  Check('brand/and no height either',
        IntToStr(SpxMarkHeight(SPX_MARK_WIDTHS[High(SPX_MARK_WIDTHS)] + 1)), '0');

  { The picker never hands back something WIDER than asked for -- an image list draws at its
    own size, so one pixel too wide is a clipped mark. Below the floor there is nothing to
    return but the floor, and that is checked on its own. }
  for wanted := SPX_MARK_WIDTHS[Low(SPX_MARK_WIDTHS)] to 200 do
    if SpxMarkPickWidth(wanted) > wanted then
      Check(Format('brand/the frame fits a %dpx face', [wanted]),
            IntToStr(SpxMarkPickWidth(wanted)), IntToStr(wanted));
  Check('brand/under the floor gets the narrowest frame',
        IntToStr(SpxMarkPickWidth(1)), IntToStr(SPX_MARK_WIDTHS[Low(SPX_MARK_WIDTHS)]));

  { And the rail's own face, at every scaling Windows offers, has a frame that fits it: this is
    the number the rail actually asks for (Px of 36), so a table that stopped covering the
    display someone has would be found here rather than on their screen. }
  for i := 100 to 200 do
    if (i mod 25) = 0 then
      CheckTrue(Format('brand/a frame fits the rail at %d%%', [i]),
                SpxMarkPickWidth(Round(36 * i / 100)) <= Round(36 * i / 100));
end;

(* THE COMPANY MARK, held the same way and for the same reason -- with the axes swapped. This
   one hangs in a status bar, whose HEIGHT the system font decides, so a frame is named by its
   height and the width follows. Everything below is TestBrandMark's argument read in the other
   direction, and it is written out rather than shared because the two differ in exactly the
   thing a shared helper would have had to be told. *)
procedure TestCompanyMark;
var i, w, h, len, wanted, prevH: Integer; p: Pointer; ratio, srcRatio: Double;
begin
  CheckTrue('company/there are frames', Length(SPX_CO_HEIGHTS) > 0);

  prevH := 0;
  for i := Low(SPX_CO_HEIGHTS) to High(SPX_CO_HEIGHTS) do
  begin
    CheckTrue(Format('company/height %d comes after %d', [SPX_CO_HEIGHTS[i], prevH]),
              SPX_CO_HEIGHTS[i] > prevH);
    prevH := SPX_CO_HEIGHTS[i];
  end;

  { Near-square, which is what says the vendored render is the 301 mark and not the ribbon --
    the two generators write the same shape of unit and a swapped source would otherwise ship. }
  srcRatio := SpxCompanyWidth(SPX_CO_HEIGHTS[High(SPX_CO_HEIGHTS)]) /
              SPX_CO_HEIGHTS[High(SPX_CO_HEIGHTS)];
  CheckTrue(Format('company/the mark is near-square, not the ribbon [%.3f]', [srcRatio]),
            (srcRatio > 0.9) and (srcRatio < 1.3));

  for i := Low(SPX_CO_HEIGHTS) to High(SPX_CO_HEIGHTS) do
  begin
    h := SPX_CO_HEIGHTS[i];
    w := SpxCompanyWidth(h);
    CheckTrue(Format('company/%d has a width', [h]), w > 0);
    p := SpxCompanyPng(h, len);
    CheckTrue(Format('company/%d is a png', [h]),
              (p <> nil) and (len > 8) and (PByte(p)[0] = $89) and (PByte(p)[1] = Ord('P')));
    { The bytes' OWN account of themselves, against the table. }
    Check(Format('company/%d is %d px wide', [h, w]), IntToStr(PngWidth(p, len)), IntToStr(w));
    Check(Format('company/%d is %d px tall', [h, h]), IntToStr(PngHeight(p, len)), IntToStr(h));
    ratio := w / h;
    CheckTrue(Format('company/%d keeps the aspect [%.3f vs %.3f]', [h, ratio, srcRatio]),
              Abs(ratio - srcRatio) < 0.15);
  end;

  p := SpxCompanyPng(SPX_CO_HEIGHTS[High(SPX_CO_HEIGHTS)] + 1, len);
  CheckTrue('company/an unknown height has no frame', (p = nil) and (len = 0));
  Check('company/and no width either',
        IntToStr(SpxCompanyWidth(SPX_CO_HEIGHTS[High(SPX_CO_HEIGHTS)] + 1)), '0');

  { Never TALLER than asked for: the bar's height is not negotiable, and one pixel proud of it
    is a clipped mark. }
  for wanted := SPX_CO_HEIGHTS[Low(SPX_CO_HEIGHTS)] to 100 do
    if SpxCompanyPickHeight(wanted) > wanted then
      Check(Format('company/the frame fits a %dpx bar', [wanted]),
            IntToStr(SpxCompanyPickHeight(wanted)), IntToStr(wanted));
  Check('company/under the floor gets the shortest frame',
        IntToStr(SpxCompanyPickHeight(1)), IntToStr(SPX_CO_HEIGHTS[Low(SPX_CO_HEIGHTS)]));

  { A status bar is about 23 px at 100% and scales with the system font; the window asks for
    that less 7 px of air. Every scaling Windows offers has a frame for it. }
  for i := 100 to 200 do
    if (i mod 25) = 0 then
      CheckTrue(Format('company/a frame fits the bar at %d%%', [i]),
                SpxCompanyPickHeight(Round(23 * i / 100) - Round(7 * i / 100)) <=
                Round(23 * i / 100) - Round(7 * i / 100));
end;

procedure TestHelpUnit;
var
  lang, page, i, seen, p_, page_: Integer;
  facts: THelpLangFacts;
  html, ids, want, got, s_: string;
  k: TSpxNoteKind;
  arts, hrefs: TStringList;
  j, n, want_ex, ins, d: Integer;
  t_, doc_: string;
  ran: TStringList;
  ctxDoc: string;
  ctxRep: TSpxReport;
  ctxRows: TSpxPanelRows;
  hits: TSpxHelpHits;
  hint: TSpxHelpHint;

  { How many rows an example draws under ITS OWN document's conditions -- the locale, the seed
    and the fragment set the fixture declared. Which is what the window has when it decides
    whether to offer the example, so this asks the same question the same way. }
  function RowsOfHelpExample(ALang, AIndex: Integer): Integer;
  var rep: TSpxReport; rws: TSpxPanelRows; set_: TSpxTemplateSet; e, doc: Integer;
      tmpl: string;
  begin
    { The conditions belong to the DOCUMENT the example came from, not to the language: each
      declares its own locale, seed and fragments, so the example is looked up along with the
      document it lives in. }
    doc := SpxHelpExampleDoc(ALang, AIndex);
    SpxHelpExample(ALang, AIndex, tmpl);
    set_ := nil;
    if SpxHelpIncludeCount(ALang, doc) > 0 then
    begin
      set_ := TSpxTemplateSet.Create;
      for e := 0 to SpxHelpIncludeCount(ALang, doc) - 1 do
        set_.AddOrSetValue(SpxHelpIncludeName(ALang, doc, e),
                           SpxHelpIncludeText(ALang, doc, e));
    end;
    try
      { THE WORKER'S CALL, ARGUMENT FOR ARGUMENT (SpxEngineThread:575). The first version
        wrote `SpxContext(locale, set_)` -- and SpxContext is (Locale, Vars, Templates) with
        TSpxTemplateSet an alias of TStrMap, so the set bound to VARS and Templates stayed nil:
        every example was validated with no fragments at all, and the three `#include` examples
        counted as clean. The seed went into `Probes` by the same slip. Both compile. }
      rep := SpxHealthReport(tmpl,
               SpxSeededContext(SpxHelpLocale(ALang, doc), nil,
                                SpxHelpSeed(ALang, doc), set_), 0);
      try
        rws := SpxPanelRows(rep, spxLangEn);
        Result := Length(rws);
      finally
        rep.Free;
      end;
    finally
      set_.Free;
    end;
  end;

  { THE WIDTH THE PAGE WILL DEMAND, in characters: the longest run the layout has no place to
    break. This is the number that decides whether a panel can show a page or cuts it, and it is
    not visible in any other check -- a page whose longest run is 95 characters renders its PROSE
    clipped mid-sentence, because the run sets the layout width for everything on the page.

    Counted the way a layout counts: a tag is nothing, `<br>` and the block tags end a run, an
    ordinary space is a break, `&nbsp;` is a character that is not one, and a UTF-8 continuation
    byte is not a character at all -- Cyrillic would otherwise count double and the ratchet would
    be measuring the language rather than the width.

    `<th` is in the list although the generator emits no header cell today: a cell that does not
    end a run joins the one beside it, which OVERSTATES the width and would be read as a page
    that needs more room than it does. The newline between a page's lines is a break for the same
    reason -- it is where SpxHelpPageHtml joined them, not something a reader sees. }
  function LongestUnbreakable(const AHtml: string): Integer;
  var i, j, run: Integer; tag: string;
  begin
    Result := 0; run := 0; i := 1;
    while i <= Length(AHtml) do
    begin
      if AHtml[i] = '<' then
      begin
        j := PosEx('>', AHtml, i);
        if j = 0 then j := Length(AHtml);
        tag := LowerCase(Copy(AHtml, i, j - i + 1));
        if (tag = '<br>') or (Copy(tag, 1, 2) = '<p') or (Copy(tag, 1, 3) = '</p') or
           (Copy(tag, 1, 3) = '<li') or (Copy(tag, 1, 3) = '<td') or (Copy(tag, 1, 3) = '<th') or
           (Copy(tag, 1, 3) = '<h1') or (Copy(tag, 1, 3) = '<h2') or (Copy(tag, 1, 3) = '<h3') or
           (Copy(tag, 1, 3) = '<tr') then
          run := 0;
        i := j + 1;
        Continue;
      end;
      if AHtml[i] = '&' then
      begin
        j := PosEx(';', AHtml, i);
        if (j > 0) and (j - i <= 6) then
        begin
          Inc(run);
          if run > Result then Result := run;
          i := j + 1;
          Continue;
        end;
      end;
      if (AHtml[i] = ' ') or (AHtml[i] = #10) or (AHtml[i] = #13) then
      begin
        run := 0;
        Inc(i);
        Continue;
      end;
      { A continuation byte belongs to the character before it and is not one of its own. }
      if (Ord(AHtml[i]) and $C0) <> $80 then
      begin
        Inc(run);
        if run > Result then Result := run;
      end;
      Inc(i);
    end;
  end;

  { The first example that spans lines -- and there MUST be one, or the ending check below is
    about nothing. `-1` is returned rather than guessed at, and the caller fails on it. }
  function MultiLineExample(ALang: Integer): Integer;
  var e: Integer; t: string;
  begin
    Result := -1;
    for e := 0 to SpxHelpExampleCount(ALang) - 1 do
      if SpxHelpExample(ALang, e, t) and (Pos(#10, t) > 0) then Exit(e);
  end;

  { Every href="..." in a page's HTML. Read from the EMITTED BYTES for the same reason. }
  function HrefsIn(const AHtml: string): TStringList;
  var at, close_: Integer; rest: string;
  begin
    Result := TStringList.Create;
    rest := AHtml;
    repeat
      at := Pos('href="', rest);
      if at = 0 then Break;
      Delete(rest, 1, at + 5);
      close_ := Pos('"', rest);
      if close_ = 0 then Break;
      Result.Add(Copy(rest, 1, close_ - 1));
      Delete(rest, 1, close_);
    until False;
  end;

  { Every id="..." in a page's HTML, in order, space-separated. Read from the EMITTED BYTES and
    not from the anchor table beside them -- a table that agrees with itself proves nothing. }
  function IdsIn(const AHtml: string): string;
  var at, close_: Integer; rest: string;
  begin
    Result := '';
    rest := AHtml;
    repeat
      at := Pos('id="', rest);
      if at = 0 then Break;
      Delete(rest, 1, at + 3);
      close_ := Pos('"', rest);
      if close_ = 0 then Break;
      Result := Result + Copy(rest, 1, close_ - 1) + ' ';
      Delete(rest, 1, close_);
    until False;
    Result := Trim(Result);
  end;

begin
  { The two implementations of the digest agree. Pinned vectors, because the whole drift check
    rests on the Pascal here and the Python in scripts/make-help.py computing the same number,
    and nothing else would notice if they stopped. }
  { A DEFAULT JOB IS NOT A HELP JOB, and this one line is the whole of the invariant that a
    field's zero value must be its safe one. It used to be an index where 0 meant the English
    help, so `Default(TSpxJob)` -- which is how the batch builds its job -- made every export
    render against the help's own fragments. The help declares one called `frag`, so a document
    with a fragment of that name exported the help's text instead of its own. }
  CheckTrue('engine/a default job asks for no help set', not Default(TSpxJob).HelpSet);

  Check('help/unit/digest-of-empty', SpxHelpDigest(''), 'cbf29ce484222325');
  Check('help/unit/digest-of-a', SpxHelpDigest('a'), 'af63dc4c8601ec8c');
  Check('help/unit/digest-of-spintax', SpxHelpDigest('spintax'), 'dfd4591713134a8e');

  CheckTrue('help/unit/there-are-languages', SPX_HELP_LANG_COUNT > 0);
  CheckTrue('help/unit/there-are-pages', SpxHelpPageCount(0) > 0);

  for lang := 0 to SPX_HELP_LANG_COUNT - 1 do
  begin
    { EVERY DOCUMENT OF THE LANGUAGE, one at a time: a language has documents now, and each
      carries its own source, its own digest and its own conditions. }
    CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/has documents',
              SpxHelpDocCount(lang) > 0);
    for d := 0 to SpxHelpDocCount(lang) - 1 do
    begin
      doc_ := SpxHelpLangCode(lang) + '/' + SpxHelpKindSlug(SpxHelpDocKind(lang, d));

      { THE DRIFT GATE. Someone edited the markdown and did not re-run the generator: the window
        would ship the old text while the suite went on verifying the new. }
      Check('help/unit/' + doc_ + '/matches its source document',
            SpxHelpDigest(SpxReadTextFile(SpxHelpSourcePath(lang, d))),
            SpxHelpSourceDigest(lang, d));

      { The document it was built from is one the suite verifies. Closes the loop with
        HELP_DOCS -- prose that ships but is not gated would otherwise be possible again. }
      CheckTrue('help/unit/' + doc_ + '/its source is a registered document',
                Pos(SpxHelpSourcePath(lang, d), HelpDocsOnDisk) > 0);

      { And its file name is the kind it claims to be, so a document cannot be registered under
        another one's name and quietly take its slugs. }
      CheckTrue('help/unit/' + doc_ + '/is the file its kind names',
                Pos('/' + SpxHelpKindSlug(SpxHelpDocKind(lang, d)) + '.md',
                    SpxHelpSourcePath(lang, d)) > 0);

      { THE CONDITIONS CAME WITH THE DOCUMENT. Render a clicked example under anything else and
        the arrow printed beside it disagrees with the pane -- the one thing this document may
        never do. }
      Check('help/unit/' + doc_ + '/carries its own locale',
            SpxHelpLocale(lang, d), SpxHelpLangCode(lang));
      CheckTrue('help/unit/' + doc_ + '/carries a seed', SpxHelpSeed(lang, d) > 0);
      { AS MANY FRAGMENTS AS THE DOCUMENT DECLARED -- not "at least one". The first version
        demanded one of every document, which the generator never did: `read_fixture` treats
        `include` as optional, so a language reference needing no fragments could not be
        registered without inventing one. Found by review, which registered exactly that. }
      CheckTrue('help/unit/' + doc_ + '/was read by the suite as well as by the generator',
                FixtureIncludesFor(SpxHelpSourcePath(lang, d)) >= 0);
      Check('help/unit/' + doc_ + '/carries the fragments its fixture declared',
            IntToStr(SpxHelpIncludeCount(lang, d)),
            IntToStr(FixtureIncludesFor(SpxHelpSourcePath(lang, d))));
      for i := 0 to SpxHelpIncludeCount(lang, d) - 1 do
        CheckTrue('help/unit/' + doc_ + '/include ' + IntToStr(i) + ' is named',
                  SpxHelpIncludeName(lang, d, i) <> '');
    end;

    { AND THEY ARE THE SAME EXAMPLES, not merely as many. Each template the window can run is
      compared against the one this suite actually put through the engine -- so a click cannot
      render text whose output was never verified. }
    { CONCATENATED OVER THE LANGUAGE'S DOCUMENTS, in the order the unit numbers them: `ex:N`
      is one flat table per language, so the templates that were run must line up the same way. }
    arts := TStringList.Create;
    try
      for d := 0 to SpxHelpDocCount(lang) - 1 do
      begin
        ran := TemplatesRunFor(SpxHelpSourcePath(lang, d));
        try
          arts.AddStrings(ran);
        finally
          ran.Free;
        end;
      end;
      { THE COLLECTOR MUST HAVE RUN. It is filled while TestHelpExamples walks the markdown, so
        this comparison is silent and vacuous if the two ever run in the other order -- measured
        by review: swapping them dropped sixty-seven checks and reported nothing. An empty list
        compared against anything passes, which is the worst way for a check to fail. }
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/the templates that were run were collected',
                arts.Count > 0);
      Check('help/unit/' + SpxHelpLangCode(lang) + '/as many collected as the unit carries',
            IntToStr(arts.Count), IntToStr(SpxHelpExampleCount(lang)));
      for i := 0 to arts.Count - 1 do
      begin
        SpxHelpExample(lang, i, got);
        Check('help/unit/' + SpxHelpLangCode(lang) + '/example ' + IntToStr(i) +
              ' is the one that was run', got, arts[i]);
      end;
    finally
      arts.Free;
    end;

    { AS MANY EXAMPLES AS THE FIXTURE RENDERED. HELP_DOCS carries the count this suite measured
      by running every one of them through the engine; the generator counted independently while
      building the table the window clicks through. Two parsers, one document. }
    want_ex := 0;
    for d := 0 to SpxHelpDocCount(lang) - 1 do
      for i := Low(HELP_DOCS) to High(HELP_DOCS) do
        if HELP_DOCS[i].Path = SpxHelpSourcePath(lang, d) then
          Inc(want_ex, HELP_DOCS[i].Examples);
    Check('help/unit/' + SpxHelpLangCode(lang) + '/as many examples as the fixture rendered',
          IntToStr(SpxHelpExampleCount(lang)), IntToStr(want_ex));

    { EVERY CODE THE PANEL CAN SHOW HAS AN ARTICLE TO OPEN. This is the check the whole
      double-click entry point rests on, and the reason CheckHelpArticles exists one level up. }
    for i := Low(ENGINE_CODES) to High(ENGINE_CODES) do
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/an article for ' + ENGINE_CODES[i],
                SpxHelpTargetFor(lang, ENGINE_CODES[i], p_, s_));
    for k := Low(TSpxNoteKind) to High(TSpxNoteKind) do
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/an article for ' + SpxNoteCode(k),
                SpxHelpTargetFor(lang, SpxNoteCode(k), p_, s_));

    { TWO PARSERS, ONE DOCUMENT. HelpArticles reads the markdown by the suite's own rules; the
      generator read it by its own. Where they disagree, one of them is wrong -- and neither is
      in a position to notice alone. }
    arts := TStringList.Create;
    try
      for d := 0 to SpxHelpDocCount(lang) - 1 do
      begin
        ran := HelpArticles(SpxHelpSourcePath(lang, d));
        try
          arts.AddStrings(ran);
        finally
          ran.Free;
        end;
      end;
      { FILTERED BY IsKnownCode, which is the authority on what a code is -- it asks
        ENGINE_CODES and SpxNoteCode rather than judging by shape. HelpArticles returns the
        first backticked token of every `###` heading, and one of them is `#include`, a heading
        about the syntax and not a diagnostic at all. The generator judges by shape and calls it
        prose; both are right about their own question, and this comparison is about codes. }
      want := '';
      for i := 0 to arts.Count - 1 do
        if IsKnownCode(arts[i]) then want := want + arts[i] + ' ';
      got := '';
      for i := 0 to SpxHelpAnchorCount(lang) - 1 do
        if SpxHelpAnchorIsCode(lang, i) then got := got + SpxHelpAnchorId(lang, i) + ' ';
      Check('help/unit/' + SpxHelpLangCode(lang) + '/the generator and the suite read the same articles',
            Trim(got), Trim(want));
    finally
      arts.Free;
    end;

    seen := 0;
    for page := 0 to SpxHelpPageCount(lang) - 1 do
    begin
      html := SpxHelpPageHtml(lang, page);
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) + ' has a title',
                SpxHelpPageTitle(lang, page) <> '');
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) + ' has a body',
                Length(html) > 40);

      { THE RENDERER'S HAZARDS, over the shipped bytes. The generator refuses to write any of
        these; this is the second pair of eyes, because a generator checking only itself is one
        bug away from checking nothing. }
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                ' has no <! (IPro never finishes parsing one, on the UI thread)',
                Pos('<!', html) = 0);
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                ' has no image (there is no data provider)', Pos('<img', html) = 0);
      { EVERY LINK LEADS SOMEWHERE. The template of each example is an `ex:N` anchor and N is
        what the window looks the template up by -- a link to nothing would be a click that
        silently does nothing, which reads as a broken feature rather than as prose. Scraped
        from the EMITTED HTML, not from the table beside it. }
      hrefs := HrefsIn(html);
      try
        for j := 0 to hrefs.Count - 1 do
        begin
          n := SpxHelpExampleOf(hrefs[j]);
          CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                    ' link [' + hrefs[j] + '] is an example number', n >= 0);
          CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                    ' link [' + hrefs[j] + '] leads to a template',
                    SpxHelpExample(lang, n, got) and (Trim(got) <> ''));
        end;
      finally
        hrefs.Free;
      end;
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                ' does not end with a bare < (it would eat the closing tag)',
                Copy(html, Length(html), 1) <> '<');
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                ' is under the layout ceiling', Length(html) <= 24 * 1024);

      { A DOCUMENT, never a fragment: with no element the panel goes black, and text before the
        first tag is silently lost (ADR 0004). Asked of the function that DEFINES that rule. }
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                ' wraps into something the renderer opens',
                SpxOpensDocument(SpxHelpDocument(html, '#FFFFFF', '#000000', '#0000FF')));

      { RE-DERIVATION: the ids in the HTML are the ids in the table, in the same order. }
      ids := IdsIn(html);
      want := SpxHelpPageSlug(lang, page);
      for i := 0 to SpxHelpAnchorCount(lang) - 1 do
        if SpxHelpAnchorPage(lang, i) = page then
        begin
          want := want + ' ' + SpxHelpAnchorId(lang, i);
          Inc(seen);
        end;
      Check('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
            ' declares the anchors its HTML carries', ids, want);
    end;
    Check('help/unit/' + SpxHelpLangCode(lang) + '/every anchor sits on a page it claims',
          IntToStr(seen), IntToStr(SpxHelpAnchorCount(lang)));

    { The escaping regression, named because it is the one that would be invisible: the article
      about an unknown permutation key shows an output whose CAUSE is the `<foo=1>` in the
      template, and the renderer eats that as a tag unless it arrives escaped. }
    html := SpxHelpPageHtml(lang, SpxHelpPageIndex(lang, 'permutations'));
    CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/the permutation key survives escaping',
              (Pos('&lt;foo=1&gt;', html) > 0) and (Pos('<foo=1>', html) = 0));

    { AND THE ESCAPING MUST BE SOMEWHERE THAT DECODES IT. Escaping alone was not enough: IPro puts
      a token inside a <pre> into ANSIText, whose setter escapes it a second time
      (iphtmlparser.pas:1965-1968), so `&lt;foo=1&gt;` was DRAWN as `&lt;foo=1&gt;` -- the reader
      reported it as an encoding fault and it was in both languages. Example blocks are <tt> in a
      paragraph now; the tag that eats entities may not come back. }
    for page := 0 to SpxHelpPageCount(lang) - 1 do
    begin
      html := SpxHelpPageHtml(lang, page);
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                ' uses no <pre> (IPro would show its entities raw)',
                Pos('<pre', LowerCase(html)) = 0);
      { A RUN OF SPACES KEEPS ITS WIDTH: the extra ones non-breaking and the last one not, which
        is what lets a narrow panel break the line where the author put a space. Asked as the
        FAILURE looks -- two ordinary spaces inside an example, which IPro's TrimFormatting
        (iphtml.pas:2790) collapses into one and the alignment narrows in silence.

        Asking instead for the PRESENCE of `&nbsp;` is what this replaced, and it was measured to
        be nearly blind: with runs of two emitted as two ordinary spaces -- 136 of the 141 runs
        the two documents have -- 45 of 48 pages lost every non-breaking space and a per-language
        `some page still has one` check stayed green. }
      p_ := Pos('<small><tt>', html);
      while p_ > 0 do
      begin
        i := PosEx('</tt>', html, p_);
        if i = 0 then i := Length(html);
        CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                  ' keeps the spacing of its example blocks',
                  Pos('  ', Copy(html, p_, i - p_)) = 0);
        p_ := PosEx('<small><tt>', html, i);
      end;
      { And at the size a PRE gave them: <tt> sets the typeface, <small> the two points a PRE
        subtracts. Without it every example is a quarter wider and the widest one drags the whole
        page -- headings and prose included -- past the panel. }
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                ' keeps the size of its example blocks',
                (Pos('<tt>', html) = 0) or (Pos('<small><tt>', html) > 0));
      { AND NO PAGE MAY DEMAND MORE WIDTH THAN A PANEL CAN GIVE. The longest unbreakable run sets
        the layout width for the WHOLE page, prose included -- so while the examples were one run
        of non-breaking spaces from template to output, a 503 px panel clipped the PARAGRAPHS
        beside them mid-sentence and the reader reported the page as not displaying at all.

        Ratcheted at what the two documents actually need: 44, and it is `[<minsize=2;maxsize=2>
        красный|зелёный|синий]` (docs/help/ru/syntax.md:104) -- one construct with no space in
        it, which is the one thing here that SHOULD NOT break. Anything wider has to earn it
        rather than take the width from the prose. }
      CheckTrue('help/unit/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
                ' can be broken to a narrow panel [' + IntToStr(LongestUnbreakable(html)) + ']',
                LongestUnbreakable(html) <= 44);
    end;
  end;

  (* EVERY EMPTY-PANEL LINK RESOLVES, IN EVERY HELP LANGUAGE. A slug no document has would open
     the front page instead of the chapter -- a failure that looks like a decision, so nobody
     reports it. Held here beside the codes and for the same reason. *)
  for lang := 0 to SPX_HELP_LANG_COUNT - 1 do
    for hint := Low(TSpxHelpHint) to High(TSpxHelpHint) do
    begin
      CheckTrue('help/hint/' + SpxHelpLangCode(lang) + '/' + SpxHelpHintSlug(hint) +
                ' is a slug at all', SpxHelpHintSlug(hint) <> '');
      CheckTrue('help/hint/' + SpxHelpLangCode(lang) + '/' + SpxHelpHintSlug(hint) +
                ' names a chapter', SpxHelpPageIndex(lang, SpxHelpHintSlug(hint)) >= 0);
    end;

  { A slug names the same section in every language -- which is what lets the viewer keep the
    reader's place across a language switch. }
  for lang := 0 to SPX_HELP_LANG_COUNT - 1 do
  begin
    Check('help/nav/' + SpxHelpLangCode(lang) + '/as many pages as the first language',
          IntToStr(SpxHelpPageCount(lang)), IntToStr(SpxHelpPageCount(0)));
    for page := 0 to SpxHelpPageCount(lang) - 1 do
    begin
      CheckTrue('help/nav/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) + ' has a slug',
                SpxHelpPageSlug(lang, page) <> '');
      Check('help/nav/' + SpxHelpLangCode(lang) + '/the slug finds its own page',
            IntToStr(SpxHelpPageIndex(lang, SpxHelpPageSlug(lang, page))), IntToStr(page));
      { THE SAME SECTION IN EVERY LANGUAGE, by name and by position -- which is what lets the
        viewer keep the reader's place when the language changes under them. }
      Check('help/nav/' + SpxHelpLangCode(lang) + '/page ' + IntToStr(page) +
            ' is the same section as in the first language',
            SpxHelpPageSlug(lang, page), SpxHelpPageSlug(0, page));
    end;
  end;
  Check('help/nav/an unknown slug is -1', IntToStr(SpxHelpPageIndex(0, 'no-such-section')), '-1');

  { THE FALLBACK, all fourteen. Two documents and fourteen interface languages means twelve
    readers see something other than what they asked for; the rule is English, the same one the
    interface strings already use, and the viewer must be able to SAY which case applies. }
  for i := Ord(Low(TSpxLang)) to Ord(High(TSpxLang)) do
  begin
    lang := SpxHelpLangFor(TSpxLang(i));
    CheckTrue('help/nav/' + SpxLangCode(TSpxLang(i)) + ' resolves to a document',
              (lang >= 0) and (lang < SPX_HELP_LANG_COUNT));
    { Which languages have their own document is the UNIT's answer, not a pair of literals:
      with `de` registered, the old form asserted that German falls back to English. }
    if HelpHasOwnDocument(SpxLangCode(TSpxLang(i))) then
    begin
      Check('help/nav/' + SpxLangCode(TSpxLang(i)) + ' gets its own document',
            SpxHelpLangCode(lang), SpxLangCode(TSpxLang(i)));
      CheckTrue('help/nav/' + SpxLangCode(TSpxLang(i)) + ' is translated',
                SpxHelpIsTranslated(TSpxLang(i)));
    end
    else
    begin
      Check('help/nav/' + SpxLangCode(TSpxLang(i)) + ' falls back to the first language',
            SpxHelpLangCode(lang), SpxHelpLangCode(0));
      CheckTrue('help/nav/' + SpxLangCode(TSpxLang(i)) + ' is NOT translated, and says so',
                not SpxHelpIsTranslated(TSpxLang(i)));
    end;
  end;

  { THE HREF PARSER, which is the only place the link form is known. }
  Check('help/nav/ex:0 is example 0', IntToStr(SpxHelpExampleOf('ex:0')), '0');
  Check('help/nav/ex:12 is example 12', IntToStr(SpxHelpExampleOf('ex:12')), '12');
  Check('help/nav/a bare number is not an href', IntToStr(SpxHelpExampleOf('12')), '-1');
  Check('help/nav/an empty href is nothing', IntToStr(SpxHelpExampleOf('')), '-1');
  Check('help/nav/ex: with no number is nothing', IntToStr(SpxHelpExampleOf('ex:')), '-1');
  Check('help/nav/a url is not an example', IntToStr(SpxHelpExampleOf('https://x/')), '-1');
  Check('help/nav/ex:1x is nothing', IntToStr(SpxHelpExampleOf('ex:1x')), '-1');
  CheckTrue('help/nav/an example past the end has no template',
            not SpxHelpExample(0, 99999, got));
  CheckTrue('help/nav/a negative example has no template', not SpxHelpExample(0, -1, got));

  { A code with no article must answer False rather than a page nobody meant. }
  CheckTrue('help/nav/an empty code has no article', not SpxHelpTargetFor(0, '', p_, s_));
  CheckTrue('help/nav/a future engine code has no article',
            not SpxHelpTargetFor(0, 'something.new-in-v9', p_, s_));

  (* WHAT THE CARET IS STANDING ON. The window asks this when the reader presses F1 or the
     rail's tool, and it is the whole of the decision -- the panel only draws what comes back.

     The rows are REAL ones, out of the engine, rather than a record filled in by hand: a span
     the suite invents is a span nothing else agrees with, and the caret test is exactly about
     agreeing with the squiggle the user can see. *)
  ctxDoc := 'цена {дешёвая|дорогая';
  ctxRep := SpxHealthReport(ctxDoc, SpxContext('ru', nil), 0);
  try
    ctxRows := SpxPanelRows(ctxRep, spxLangRu);
  finally
    ctxRep.Free;
  end;
  CheckTrue('help/caret/the broken document really has a finding', Length(ctxRows) > 0);

  { INSIDE THE FINDING: its own article, exactly. }
  CheckTrue('help/caret/on an unclosed brace opens its article',
            SpxHelpForCaret(ctxDoc, 12, 1, 12, ctxRows, 0, p_, s_) and (s_ = 'bracket.unclosed'));

  { BEFORE the finding, in a document whose characters are two bytes each. The caret's column
    is BYTES and the finding's is CODE POINTS: `цена ` is five characters and nine bytes, so a
    caret at byte 9 is still left of the brace the finding names. Comparing the two units
    directly -- which is what the first version did -- made this look covered. }
  CheckTrue('help/caret/left of the finding, in a two-byte alphabet, is not on it',
            not SpxHelpForCaret(ctxDoc, 9, 1, 9, ctxRows, 0, p_, s_));
  CheckTrue('help/caret/right of it still is',
            SpxHelpForCaret(ctxDoc, 12, 1, 12, ctxRows, 0, p_, s_) and (s_ = 'bracket.unclosed'));

  { THE OFFSET AND THE TEXT MUST BE THE SAME TEXT. With CRLF endings the offset of line two's
    content is two bytes further on than an LF copy would put it, and handing over the LF copy
    while counting in the CRLF one is what the window did. }
  ctxRows := nil;
  CheckTrue('help/caret/line two of a CRLF document is found',
            SpxHelpForCaret('плоский текст'#13#10'#include "frag"', 30, 2, 4, ctxRows, 0,
                            p_, s_) and (p_ = SpxHelpPageIndex(0, 'includes')));

  { No finding at the caret: the CONSTRUCT decides, and it names a chapter rather than
    pretending to know which of its articles was meant. }
  ctxRows := nil;
  CheckTrue('help/caret/in a choice opens the brackets chapter',
            SpxHelpForCaret('цена {дешёвая|дорогая}', 12, 1, 12, ctxRows, 0, p_, s_) and
            (p_ = SpxHelpPageIndex(0, 'brackets')) and (s_ = ''));
  CheckTrue('help/caret/in a permutation opens the permutations chapter',
            SpxHelpForCaret('[a|b|c]', 3, 1, 3, ctxRows, 0, p_, s_) and
            (p_ = SpxHelpPageIndex(0, 'permutations')));
  CheckTrue('help/caret/in a plural opens the plurals chapter',
            SpxHelpForCaret('{plural %n%: товар|товара|товаров}', 20, 1, 20, ctxRows, 0,
                            p_, s_) and (p_ = SpxHelpPageIndex(0, 'plurals')));
  CheckTrue('help/caret/in a conditional opens the brackets chapter',
            SpxHelpForCaret('{?vip?да|нет}', 8, 1, 8, ctxRows, 0, p_, s_) and
            (p_ = SpxHelpPageIndex(0, 'brackets')));

  { A directive is line-anchored in this language, so the line's head is the whole question. }
  CheckTrue('help/caret/on a #set line opens the definitions chapter',
            SpxHelpForCaret('#set %x% = 1', 3, 1, 3, ctxRows, 0, p_, s_) and
            (p_ = SpxHelpPageIndex(0, 'definitions')));
  CheckTrue('help/caret/on a #def line opens the definitions chapter',
            SpxHelpForCaret('#def %x% = 1', 3, 1, 3, ctxRows, 0, p_, s_) and
            (p_ = SpxHelpPageIndex(0, 'definitions')));
  CheckTrue('help/caret/on an #include line opens the includes chapter',
            SpxHelpForCaret('#include "frag"', 4, 1, 4, ctxRows, 0, p_, s_) and
            (p_ = SpxHelpPageIndex(0, 'includes')));
  CheckTrue('help/caret/on the second line of a document, not the first',
            SpxHelpForCaret('плоский текст'#10'#include "frag"', 30, 2, 4, ctxRows, 0,
                            p_, s_) and (p_ = SpxHelpPageIndex(0, 'includes')));

  { A variable is the one thing that is NOT line-anchored, so it is looked for around the
    caret rather than at the head of the line. }
  CheckTrue('help/caret/in a variable opens the variables chapter',
            SpxHelpForCaret('привет %имя% и всё', 16, 1, 10, ctxRows, 0, p_, s_) and
            (p_ = SpxHelpPageIndex(0, 'variables')));

  { A KEYWORD MUST END. All four of these are plain text to the engine -- it narrowed
    `#include` to the family's anchor in v0.2.1 -- so a chapter about directives would be
    teaching the reader something untrue about their own line. }
  CheckTrue('help/caret/#includes is not #include',
            not SpxHelpForCaret('#includes "frag"', 4, 1, 4, ctxRows, 0, p_, s_));
  CheckTrue('help/caret/#setting is not #set',
            not SpxHelpForCaret('#setting up the shop', 4, 1, 4, ctxRows, 0, p_, s_));
  CheckTrue('help/caret/#definitely is not #def',
            not SpxHelpForCaret('#definitely not a directive', 4, 1, 4, ctxRows, 0, p_, s_));
  CheckTrue('help/caret/a tab after the keyword still counts',
            SpxHelpForCaret('#set'#9'%x% = 1', 3, 1, 3, ctxRows, 0, p_, s_) and
            (p_ = SpxHelpPageIndex(0, 'definitions')));

  { A CR-ONLY document is one SpxDetectEol supports, so a scan that only knows LF looks for the
    variable's opening per cent sign on the line above. }
  CheckTrue('help/caret/a CR-only line is a line',
            not SpxHelpForCaret('a%b'#13'cd', 6, 2, 2, ctxRows, 0, p_, s_));

  { NOTHING TO BE SPECIFIC ABOUT -- the caller opens the contents, which is what "help me"
    means with an empty document or a caret in plain prose. }
  CheckTrue('help/caret/in plain text asks for nothing',
            not SpxHelpForCaret('просто текст без конструкций', 5, 1, 5, ctxRows, 0, p_, s_));
  CheckTrue('help/caret/an empty document asks for nothing',
            not SpxHelpForCaret('', 1, 1, 1, ctxRows, 0, p_, s_));
  CheckTrue('help/caret/past the end asks for nothing',
            not SpxHelpForCaret('текст', 9999, 1, 9999, ctxRows, 0, p_, s_));

  { Relocation across a language switch: the article if it exists there -- and for a code it
    always does -- else the section, never a blank. }
  SpxHelpTargetFor(0, 'plural.arity', page, s_);
  SpxHelpRelocate(0, page, 'plural.arity', SPX_HELP_LANG_COUNT - 1, p_, s_);
  Check('help/nav/a code keeps its article across languages', s_, 'plural.arity');
  SpxHelpRelocate(0, SpxHelpPageIndex(0, 'includes'), 'no-such-anchor',
                  SPX_HELP_LANG_COUNT - 1, p_, s_);
  Check('help/nav/a lost anchor keeps the section', IntToStr(p_),
        IntToStr(SpxHelpPageIndex(0, 'includes')));
  Check('help/nav/a lost anchor has no anchor', s_, '');

  (* WHAT "PUT THIS IN MY DOCUMENT" ACTUALLY PUTS THERE. The reader sees the page, and the page
     is HTML: the examples this matters for most are the ones the tokenizer would eat, and they
     are drawn escaped. So the text must come from the TABLE the fixture ran, and that is what
     is checked here -- for every example in every language, not for a sample. *)
  for lang := 0 to SPX_HELP_LANG_COUNT - 1 do
  begin
    ins := 0;
    for i := 0 to SpxHelpExampleCount(lang) - 1 do
    begin
      SpxHelpExample(lang, i, s_);
      CheckTrue('help/insert/' + SpxHelpLangCode(lang) + '/#' + IntToStr(i) + ' is the fixture''s',
                SpxHelpInsertText(lang, i, #10, t_) and (t_ = s_) and (t_ <> ''));
      { An entity that survived into the insert text would mean it came off the page. }
      CheckTrue('help/insert/' + SpxHelpLangCode(lang) + '/#' + IntToStr(i) + ' carries no markup',
                (Pos('&lt;', t_) = 0) and (Pos('&gt;', t_) = 0) and (Pos('&amp;', t_) = 0));
      Inc(ins);
    end;
    { `ins = SpxHelpExampleCount(lang)` was the first form and it cannot fail: it compares the
      counter with the bound of the loop that raised it. What is worth asserting is that the
      loop ran at all -- an empty table would otherwise take all 134 checks above with it in
      silence. }
    CheckTrue('help/insert/' + SpxHelpLangCode(lang) + '/there were examples to offer',
              ins > 0);
  end;

  { The editor joins its lines with the platform's ending, so the template arrives in that
    shape -- and a template with no line break is untouched either way. }
  CheckTrue('help/insert/there is a multi-line example to check the endings on',
            MultiLineExample(0) >= 0);
  SpxHelpInsertText(0, MultiLineExample(0), #13#10, t_);
  CheckTrue('help/insert/a multi-line example arrives with the editor''s endings',
            (Pos(#13#10, t_) > 0) and (Pos(#10#10, t_) = 0));
  SpxHelpInsertText(0, MultiLineExample(0), #10, s_);
  Check('help/insert/and is otherwise the same text',
        StringReplace(t_, #13#10, #10, [rfReplaceAll]), s_);
  CheckTrue('help/insert/an index that is not one gives nothing',
            (not SpxHelpInsertText(0, 9999, #10, t_)) and (t_ = ''));

  { WHEN THE OFFER IS MADE. Most of the help's examples are counter-examples -- written to make a
    diagnostic appear -- and offering to put one in the reader's document was the objection that
    produced this rule. It reads the ENGINE's answer about that very render, so the three ways of
    having nothing to offer are one condition each. }
  (* SEARCHING THE DOCUMENTATION. The help pane's own bar runs this, and a hit is a place the
     viewer can go: a page and the article inside it. *)
  hits := SpxHelpFind(0, 'plural.arity', False);
  CheckTrue('help/find/a code is found', Length(hits) > 0);
  SpxHelpTargetFor(0, 'plural.arity', p_, s_);
  CheckTrue('help/find/and lands on its own article',
            (hits[0].Anchor = s_) or (hits[0].Page = p_));

  { THE TITLE IS SEARCHABLE. The first version of this check proved nothing and its comment was
    wrong with it: it claimed the title is not in the page's HTML, and the generator writes it as
    the page's `<h1>` -- measured, StripTags of the first line equals SpxHelpPageTitle on 48 of
    48 pages. So a title query matches through the body anyway, and guarding the title branch
    left the suite green. What is asserted now is the OUTCOME the reader depends on -- the
    chapter is found by the name the contents tree shows, and it is that chapter. }
  { By SLUG, not by position: a page inserted anywhere before this one used to move the
    number, and the check would then be about whichever chapter had slid into index 3. }
  page_ := SpxHelpPageIndex(0, 'groups');
  hits := SpxHelpFind(0, SpxHelpPageTitle(0, page_), False);
  CheckTrue('help/find/a page is found by its title', Length(hits) > 0);
  Check('help/find/and that page is the first hit', IntToStr(hits[0].Page), IntToStr(page_));
  Check('help/find/on the page itself, not inside an article', hits[0].Anchor, '');

  { ENTITIES ARE DECODED BEFORE THE MATCH. `<foo=1>` is stored as `&lt;foo=1&gt;` and drawn as
    `<foo=1>`; the reader searches for what they see. }
  hits := SpxHelpFind(0, '<foo=1>', False);
  CheckTrue('help/find/text the page escapes is found as it is drawn', Length(hits) > 0);
  hits := SpxHelpFind(0, '&lt;foo=1&gt;', False);
  CheckTrue('help/find/and not by the bytes behind it', Length(hits) = 0);

  { ONE HIT PER ARTICLE. Two matches in the same one would scroll to the same place, so
    stepping between them would move nothing.

    ASSERTED AGAINST THE RAW COUNT, because the first version counted hits equal to hits[0] --
    which cannot exceed one by construction, since pages are scanned in order and the dedup only
    looks at the hit before. Guarding the dedup left the suite green. Here the two numbers are
    measured independently: how many LINES of the whole help hold the word, and how many places
    the arrows visit. }
  hits := SpxHelpFind(0, 'plural', False);
  n := 0;
  for i := 0 to SpxHelpPageCount(0) - 1 do
  begin
    s_ := SpxHelpPlainText(0, i);
    j := 1;
    while j <= Length(s_) do
    begin
      if Length(SpxFindAll(Copy(s_, j, Pos(#10, Copy(s_, j, MaxInt) + #10) - 1),
                           'plural', False)) > 0 then Inc(n);
      Inc(j, Pos(#10, Copy(s_, j, MaxInt) + #10));
    end;
  end;
  CheckTrue('help/find/more lines hold the word than there are hits',
            (n > Length(hits)) and (Length(hits) > 0));

  CheckTrue('help/find/nothing is not a search', Length(SpxHelpFind(0, '   ', False)) = 0);
  CheckTrue('help/find/a word no document has is not found',
            Length(SpxHelpFind(0, 'zzqqxx', False)) = 0);

  { CASE. The switch is the find bar's own, and it is the editor's matcher underneath. }
  CheckTrue('help/find/case-insensitive finds the other case',
            Length(SpxHelpFind(0, 'PLURAL.ARITY', False)) > 0);
  CheckTrue('help/find/case-sensitive does not',
            Length(SpxHelpFind(0, 'PLURAL.ARITY', True)) = 0);

  { The stripping must not eat the text it walks past. }
  for i := 0 to SpxHelpPageCount(0) - 1 do
  begin
    s_ := SpxHelpPlainText(0, i);
    CheckTrue('help/find/page ' + IntToStr(i) + ' has readable text', Length(Trim(s_)) > 20);
    { WHICH TAGS, AND WHY ONLY THESE. `Pos('<') = 0` was the first version and four pages failed
      it, rightly: after decoding, `&lt;foo=1&gt;` IS a `<` in the text. Then `<br>` failed on
      the silences chapter, also rightly -- that chapter is ABOUT `<br>` and `</b>` and says so
      in prose. What is left are the three the documentation never writes as text and the
      generator writes on every page: a paragraph, an article heading, and the non-breaking
      space that holds an example's columns. }
    CheckTrue('help/find/page ' + IntToStr(i) + ' kept no markup',
              (Pos('<p>', s_) = 0) and (Pos('<h3 id=', s_) = 0) and (Pos('&nbsp;', s_) = 0));
  end;

  CheckTrue('help/offer/a clean example is offered', SpxHelpOffersInsert(True, 0, 0));
  CheckTrue('help/offer/one that drew a row is not', not SpxHelpOffersInsert(True, 0, 1));
  CheckTrue('help/offer/no example clicked, no offer', not SpxHelpOffersInsert(True, -1, 0));
  CheckTrue('help/offer/with the help shut, nothing is offered',
            not SpxHelpOffersInsert(False, 0, 0));

  { And the counts the rule exists for -- EXACT, like every other count in this file. The first
    version asserted `(ins > 0) and (ins < count)`, which passes for anything from 1 to 32:
    review changed the helper so the numbers moved by three per language and the suite reported
    the same 6010 checks, 0 failed. A check indifferent to a fifth of its subject is not one. }
  { Derived, so registering a language cannot leave a number behind. }
  Check('help/offer/every shipped language has a row in HELP_LANG_FACTS',
        IntToStr(SPX_HELP_LANG_COUNT), IntToStr(Length(HELP_LANG_FACTS)));
  for i := 0 to SPX_HELP_LANG_COUNT - 1 do
  begin
    ins := 0;
    for j := 0 to SpxHelpExampleCount(i) - 1 do
    begin
      if RowsOfHelpExample(i, j) = 0 then Inc(ins);
    end;
    { Across ALL of the language's documents. The diagnostics document is mostly
      counter-examples -- 11 of its 33 are clean in English, 15 of 36 in Russian -- and the
      language reference is the other way round, because it demonstrates constructs that work.
      The product guide adds exactly one, which is clean. Exact, so a new counter-example
      cannot arrive without being counted. }
    if HelpFactsFor(SpxHelpLangCode(i), facts) then
      Check('help/offer/' + SpxHelpLangCode(i) + '/clean example count',
            IntToStr(ins), IntToStr(facts.CleanExamples))
    else
      Check('help/offer/' + SpxHelpLangCode(i) + '/has a row in HELP_LANG_FACTS',
            'missing', 'present');
  end;
end;

procedure TestHelpExamples;
var i: Integer; arts: TStringList; registered: TStringList;
begin
  registered := TStringList.Create;
  try
    for i := Low(HELP_DOCS) to High(HELP_DOCS) do registered.Add(HELP_DOCS[i].Path);
    registered.Sort;
    { A help document nobody registered is prose that LOOKS gated and is not -- the same arrows,
      the same aligned output column, and no check behind any of it. This is the one assertion
      that makes that impossible in any order of work. }
    Check('help/every document on disk is registered', HelpDocsOnDisk, registered.CommaText);
  finally
    registered.Free;
  end;
  for i := Low(HELP_DOCS) to High(HELP_DOCS) do
  begin
    CheckHelpDoc(HELP_DOCS[i]);
    { Only the document the panel opens on a diagnostic row owes an article per code -- the next
      help page (a language reference, the app description) must not have to repeat all 22. But
      that is DERIVED, not declared: a hand-set flag is an opt-out nobody verifies, and a
      copy-pasted table row with it off would ship three articles of twenty-two and stay green.
      A document that names even one code in a heading is claiming to be that document. }
    arts := HelpArticles(HELP_DOCS[i].Path);
    try
      { ...and a file NAMED diagnostics owes them whatever its headings say, which closes the one
        way the derivation could still be silenced: strip every coded heading and the obligation
        would evaporate with them. }
      if (arts.Count > 0) or
         (LowerCase(ChangeFileExt(ExtractFileName(HELP_DOCS[i].Path), '')) = 'diagnostics') then
        if HELP_DOCS[i].Codes then CheckHelpArticles(HELP_DOCS[i].Path);
    finally
      arts.Free;
    end;
  end;
end;

procedure TestGroups;
var g: TSpxGroup;
begin
  { The everyday one, and every position that counts as being in it: inside, on the opening
    bracket, on the closing one. }
  Check('groups/plain-choice', GroupSig('{a|b}', 2), 'choice 1..5 [] <a> <b>');
  Check('groups/caret-on-the-opener', GroupSig('{a|b}', 1), 'choice 1..5 [] <a> <b>');
  Check('groups/caret-on-the-closer', GroupSig('{a|b}', 5), 'choice 1..5 [] <a> <b>');
  Check('groups/caret-outside', GroupSig('x {a|b} y', 1), 'none');
  Check('groups/no-group-at-all', GroupSig('just prose', 3), 'none');

  { Nesting. The caret decides which group is offered, and a nested one stays VERBATIM inside
    its variant -- rewriting the outer group must not flatten the inner. }
  Check('groups/outer-of-a-nest',
        GroupSig('{a|{b|c}|d}', 2), 'choice 1..11 [] <a> <{b|c}> <d>');
  Check('groups/inner-of-a-nest',
        GroupSig('{a|{b|c}|d}', 5), 'choice 4..8 [] <b> <c>');

  { The three heads. Each is kept whole and none of them is a variant. }
  Check('groups/conditional',
        GroupSig('{?flag?yes|no}', 9), 'cond 1..14 [?flag?] <yes> <no>');
  { The plural head carries the count and the colon; the forms after it are the variants, and
    the locale decides how many there should be (the engine's plural.arity says when there
    are not). }
  Check('groups/plural', GroupSig('{plural %n%: one|few|many}', 16),
        'plural 1..26 [plural %n%:] < one> <few> <many>');
  Check('groups/permutation', GroupSig('[a|b|c]', 3), 'perm 1..7 [] <a> <b> <c>');
  Check('groups/permutation-with-config',
        GroupSig('[<minsize=2>a|b]', 14), 'perm 1..16 [<minsize=2>] <a> <b>');

  { Brackets the validator has already refused are not editable groups. }
  Check('groups/mismatched-kinds', GroupSig('{a]', 2), 'none');
  Check('groups/unclosed', GroupSig('{a|b', 2), 'none');
  { A comment is not code -- the scanner says so, and this asks the scanner. }
  Check('groups/inside-a-comment', GroupSig('x /# {a|b} #/ y', 8), 'none');

  { A group that spans lines keeps the line ending inside the variant it belongs to. }
  Check('groups/across-a-line', GroupSig('{a|'#10'b}', 2), 'choice 1..6 [] <a> <'#10'b>');
  { An empty group is one empty variant, not none -- a brace closed immediately is legal and
    renders nothing. }
  Check('groups/empty-group', GroupSig('{}', 1), 'choice 1..2 [] <>');

  { Bytes, not code points: the offsets are what SynEdit hands over. }
  { Six Cyrillic letters are twelve bytes, so the closing brace is at 23 and not at 13. }
  Check('groups/cyrillic', GroupSig('{привет|пока}', 4),
        'choice 1..23 [] <привет> <пока>');

  { ── writing it back ── }

  Check('groups/write-replaces-the-variants',
        WriteVariants('x {a|b} y', 4, ['one', 'two', 'three']), 'x {one|two|three} y');
  Check('groups/write-one-variant', WriteVariants('x {a|b} y', 4, ['only']), 'x {only} y');
  Check('groups/write-keeps-the-head',
        WriteVariants('{?flag?yes|no}', 9, ['да', 'нет']), '{?flag?да|нет}');
  Check('groups/write-keeps-the-config',
        WriteVariants('[<minsize=2>a|b]', 14, ['x', 'y']), '[<minsize=2>x|y]');
  { A nested group survives being written back as part of its variant. }
  CheckTrue('groups/found-an-outer', SpxGroupAt('{a|{b|c}|d}', 2, g));
  Check('groups/write-keeps-a-nested-group',
        WriteVariants('{a|{b|c}|d}', 2, g.Variants), '{a|{b|c}|d}');

  { ── AND WHAT IT REFUSES. The edit is read back, so a result that parses but says something
    other than what was asked leaves the document alone. Every one of these parses. ── }

  { There is no escape for `|`, so one inside a variant would silently become two variants. }
  Check('groups/refuses-a-pipe-in-a-variant',
        WriteVariants('{a|b}', 2, ['x|y', 'z']), 'refused');
  (* A closing brace would end the group early and strand the rest. *)
  Check('groups/refuses-a-closing-brace',
        WriteVariants('{a|b}', 2, ['x}y', 'z']), 'refused');
  { An opening brace starts a nested group that swallows the pipe after it. }
  Check('groups/refuses-an-opening-brace',
        WriteVariants('{a|b}', 2, ['x{y', 'z']), 'refused');
  { `/#` opens a comment that eats the closer and everything after it. }
  Check('groups/refuses-a-comment-opener',
        WriteVariants('{a|b}', 2, ['x/#y', 'z']), 'refused');
  { Asking for NO variants is not expressible: an empty group is one empty variant. }
  Check('groups/refuses-an-empty-list', WriteVariants('{a|b}', 2, []), 'refused');
  (* An empty variant is fine, though: a choice between nothing and b. *)
  Check('groups/allows-an-empty-variant', WriteVariants('{a|b}', 2, ['', 'b']), '{|b}');

  { ── the invariant, rather than another hand-written expectation ──

    Writing a group's OWN variants back must reproduce the document byte for byte. It is the
    one check that gates the whole class the body-start belongs to: a head that is read from
    one position and written at another passes every hand-written case that reads and writes
    consistently, and fails this. }
  Check('groups/roundtrip-choice', RoundTrip('x {a|b} y', 4), 'x {a|b} y');
  Check('groups/roundtrip-conditional', RoundTrip('{?flag?yes|no}', 9), '{?flag?yes|no}');
  Check('groups/roundtrip-plural', RoundTrip('{plural %n%: one|few}', 16),
        '{plural %n%: one|few}');
  Check('groups/roundtrip-permutation', RoundTrip('[a|b|c]', 3), '[a|b|c]');
  Check('groups/roundtrip-config', RoundTrip('[<minsize=2>a|b]', 14), '[<minsize=2>a|b]');
  { The config with a blank before it: the scanner skips that blank on purpose, and reading
    the head at a fixed offset used to miss it and DELETE the config on write. }
  Check('groups/roundtrip-config-after-a-blank', RoundTrip('[ <minsize=2>a|b]', 15),
        '[ <minsize=2>a|b]');
  Check('groups/roundtrip-nested', RoundTrip('{a|{b|c}|d}', 2), '{a|{b|c}|d}');
  Check('groups/roundtrip-across-lines', RoundTrip('{a|'#13#10'b}', 2), '{a|'#13#10'b}');
  Check('groups/roundtrip-cyrillic', RoundTrip('{привет|пока}', 4), '{привет|пока}');
  Check('groups/roundtrip-empty', RoundTrip('{}', 1), '{}');

  { ── what the review found, pinned ── }

  (* A closer of the WRONG kind pops its opener, as the engine does -- and the pair that
     closes afterwards is NOT a group. Measured on the engine: `{x|{a]b}|y}` renders as
     literal text and reports bracket.mismatched AND bracket.unexpected-closing. Offering an
     edit there rewrote the span 1..8 and left the rest of the line stranded behind it. *)
  Check('groups/mismatch-inside-a-pair', GroupSig('{x|{a]b}|y}', 2), 'none');
  Check('groups/mismatch-the-other-way-round', GroupSig('{x|[a}b]|y}', 2), 'none');

  { The head is read where the SCANNER puts it, blanks and all. }
  Check('groups/config-after-a-blank', GroupSig('[ <minsize=2>a|b]', 15),
        'perm 1..17 [<minsize=2>] <a> <b>');

  (* A span read in isolation is truncated at the closing bracket, and the scanner's html-ish
     lookahead reads to the end of the LINE -- so an isolated scan called `<li>` a permutation
    config where the document scan calls it prose. Replaying over the document's own lines is
    what keeps the panel and the colours in agreement. *)
  Check('groups/html-looking-text-after-the-group', GroupSig('[<li>a|b]</li>', 6),
        'perm 1..9 [] <<li>a> <b>');

  (* A comment INSIDE a group hides a brace from the scanner, so the group ends where the
     scanner says and not at the first `}` a naive reader would find. *)
  Check('groups/comment-inside-a-group', GroupSig('{a /# } #/ |b}', 2),
        'choice 1..14 [] <a /# } #/ > <b>');
  (* The braces in an #include target are inside a string token, so they open nothing. *)
  Check('groups/braces-in-an-include-target',
        GroupSig('#include "{a|b}"', 13), 'none');
  { A permutation element's trailing separator is part of the element, verbatim. }
  Check('groups/trailing-separator', GroupSig('[a<br>|b]', 3),
        'perm 1..9 [] <a<br>> <b>');

  { Line endings: all three of the editor's, since each has its own branch. }
  Check('groups/across-a-crlf', GroupSig('{a|'#13#10'b}', 2), 'choice 1..7 [] <a> <'#13#10'b>');
  Check('groups/across-a-lone-cr', GroupSig('{a|'#13'b}', 2), 'choice 1..6 [] <a> <'#13'b>');

  { Offsets no caret can produce, because a panel will produce them anyway. }
  Check('groups/offset-zero', GroupSig('{a|b}', 0), 'none');
  Check('groups/offset-negative', GroupSig('{a|b}', -5), 'none');
  Check('groups/offset-past-the-end', GroupSig('{a|b}', 99), 'none');
  Check('groups/empty-text', GroupSig('', 1), 'none');


end;

procedure TestHtmlScan;
begin
  { Where SynEdit's HTML highlighter is wrong about the output. It opens a tag at EVERY `<`,
    so a comparison in prose turns the rest of the paragraph into attribute colours; the rest
    of the family, and every browser, opens a tag only when a letter, `/`, `!` or `?`
    follows. These are the runs to paint back. }
  Check('htmlscan/clean-html-has-nothing-to-fix',
        SpanSig(SpxHtmlPhantomTags('<p class="x">Text.</p>')), '');
  { A `>` inside a quoted attribute value does not end the tag, so it starts nothing. }
  Check('htmlscan/gt-inside-a-value',
        SpanSig(SpxHtmlPhantomTags('<a title="1>2">t</a>')), '');
  Check('htmlscan/empty', SpanSig(SpxHtmlPhantomTags('')), '');
  Check('htmlscan/prose-without-tags', SpanSig(SpxHtmlPhantomTags('just prose')), '');

  { The everyday case, and the one that settles the rule. The run goes THROUGH the closing
    `</p>`, because the highlighter does not recognise it: in a tag's parameter range IdentProc
    stops on `[#0..#32, '=', '"', '>']` and `<` is not in that set, so `rub.</p` arrives as a
    single identifier token. Measured; an earlier version stopped at the `<` and left those
    four characters coloured as an attribute name. }
  Check('htmlscan/bare-lt-in-prose',
        SpanSig(SpxHtmlPhantomTags('<p>a < 100 rub.</p>')), '1:6..1:20');
  { A tag AT A TOKEN BOUNDARY is recognised, so the run stops before it and its colours stay. }
  Check('htmlscan/stops-at-a-tag-that-follows-a-space',
        SpanSig(SpxHtmlPhantomTags('a < b <p>c')), '1:3..1:7');
  { With no `>` for three lines the highlighter takes all three; so does the run. }
  Check('htmlscan/crosses-lines',
        SpanSig(SpxHtmlPhantomTags('a < b'#10'two'#10'three'#10'<p>x</p>')), '1:3..4:1');
  Check('htmlscan/crlf-is-one-ending',
        SpanSig(SpxHtmlPhantomTags('a < b'#13#10'<p>x</p>')), '1:3..2:1');
  Check('htmlscan/lone-cr-is-a-line-too',
        SpanSig(SpxHtmlPhantomTags('a < b'#13'<p>x</p>')), '1:3..2:1');
  Check('htmlscan/lt-at-the-very-end', SpanSig(SpxHtmlPhantomTags('price <')), '1:7..1:8');
  { The `>` that lets the highlighter out is part of the wrongly-coloured run. }
  Check('htmlscan/closed-by-a-later-gt',
        SpanSig(SpxHtmlPhantomTags('a < b > c')), '1:3..1:8');
  Check('htmlscan/two-of-them',
        SpanSig(SpxHtmlPhantomTags('a < b > c < d > e')), '1:3..1:8 1:11..1:16');

  { An `&` ends it too: AmpersandProc sets fRange := rsText whatever range it was called in,
    so from there the highlighter is right again. Running past it would repaint the entity --
    which is green and bold in this scheme, and this project's demo template opens with one. }
  Check('htmlscan/an-ampersand-ends-the-run',
        SpanSig(SpxHtmlPhantomTags('a < b & c > d')), '1:3..1:7');
  Check('htmlscan/an-entity-keeps-its-colour',
        SpanSig(SpxHtmlPhantomTags('price < 100 &nbsp; rub')), '1:7..1:13');

  { Constructs the highlighter reads as ONE token are none of this unit's business. Each has
    its own terminator, and stopping at the first `>` -- as this used to -- drops the scan
    back inside them and invents a phantom there. }
  Check('htmlscan/a-comment-with-a-gt-inside',
        SpanSig(SpxHtmlPhantomTags('<!-- if a > b then c < d -->')), '');
  Check('htmlscan/cdata-with-a-gt-inside',
        SpanSig(SpxHtmlPhantomTags('<![CDATA[ a > b < c ]]>')), '');
  Check('htmlscan/an-asp-block-is-deliberate',
        SpanSig(SpxHtmlPhantomTags('<% if a > b %>')), '');
  Check('htmlscan/php-is-an-ordinary-tag-to-it',
        SpanSig(SpxHtmlPhantomTags('<?php echo "x" ?>')), '');

  { An apostrophe is NOT a string to this highlighter -- only `"` is mapped to StringProc --
    and treating it as one used to swallow the rest of the document, silently turning the
    whole feature off for any output with `don't` in a comment. }
  Check('htmlscan/an-apostrophe-is-not-a-quote',
        SpanSig(SpxHtmlPhantomTags('<!-- don''t edit --><p>a < b</p>')), '1:25..1:32');
  { And an unterminated `"` ends at the line, as StringProc does. }
  Check('htmlscan/an-unterminated-quote-stops-at-the-line',
        SpanSig(SpxHtmlPhantomTags('<a title="oops'#10'a < b'#10'<p>x</p>')), '2:3..3:1');
  { The documented limitation, pinned so it changes on purpose rather than by accident: a
    quoted value inside a PHANTOM tag is not modelled. }
  Check('htmlscan/a-quoted-value-inside-a-phantom-is-not-modelled',
        SpanSig(SpxHtmlPhantomTags('a < b="x>y" c')), '1:3..1:10');

  { What opens a tag and what does not -- ASCII letters only, exactly as HTML5 says. }
  Check('htmlscan/a-digit-does-not', SpanSig(SpxHtmlPhantomTags('<5')), '1:1..1:3');
  Check('htmlscan/a-slash-does', SpanSig(SpxHtmlPhantomTags('</p>')), '');
  Check('htmlscan/a-bang-does', SpanSig(SpxHtmlPhantomTags('<!-- c -->')), '');
  { A Cyrillic letter opens nothing in any browser either -- and it is two BYTES, which is
    what the editor's columns count. }
  Check('htmlscan/a-cyrillic-letter-does-not', SpanSig(SpxHtmlPhantomTags('<р')), '1:1..1:4');
  Check('htmlscan/columns-are-bytes',
        SpanSig(SpxHtmlPhantomTags('ЦЕНА < 5')), '1:10..1:13');

  { THE INVARIANT THE MARKUP RESTS ON. It bisects the span array, which is only sound if the
    spans come out ordered and non-overlapping -- so that is asserted here rather than assumed
    over there, on the nastiest input this file has. }
  CheckTrue('htmlscan/spans-are-ordered-and-do-not-overlap',
            SpansAreOrdered(SpxHtmlPhantomTags(
              '<p>a < b</p>'#13#10'<!-- don''t > --> c < d & e'#10'<a href="x<y">z < 5')));
end;

procedure TestLongestLine;
begin
  { What the source view asks before deciding to wrap. The number is in bytes and the three
    editor line endings all end a line. }
  Check('longest/empty', IntToStr(SpxLongestLine('')), '0');
  Check('longest/one-line', IntToStr(SpxLongestLine('abcde')), '5');
  Check('longest/lf', IntToStr(SpxLongestLine('ab' + #10 + 'abcd')), '4');
  Check('longest/cr', IntToStr(SpxLongestLine('abc' + #13 + 'ab')), '3');
  { CRLF is ONE ending: counting it as two would report a phantom empty line and, worse,
    could halve a genuinely long line's measured length. }
  Check('longest/crlf', IntToStr(SpxLongestLine('abcdef' + #13#10 + 'ab')), '6');
  Check('longest/trailing-break', IntToStr(SpxLongestLine('abc' + #10)), '3');
  Check('longest/the-last-line-counts', IntToStr(SpxLongestLine('a' + #10 + 'bbbb')), '4');
  { Bytes, like every other column this unit hands the editor. }
  Check('longest/bytes-not-code-points', IntToStr(SpxLongestLine('цена')), '8');
end;

{ ── 8b0. finding text in the template ─────────────────────────────────────── }

function MatchSig(const M: TSpxMatches): string;
var i: Integer;
begin
  Result := '';
  for i := 0 to High(M) do
    Result := Result + Format('%d:%d..%d:%d ', [M[i].Line, M[i].Col, M[i].EndLine, M[i].EndCol]);
  Result := Trim(Result);
end;

procedure TestFind;
var m: TSpxMatches; i: Integer; ok: Boolean;
begin
  { Positions are the EDITOR's: 1-based lines, 1-based code-point columns, end exclusive --
    the same model a diagnostic uses, so a match can be selected by the machinery that
    already exists. }
  m := SpxFindAll('раз два раз', 'раз', True);
  Check('find/two-on-one-line', MatchSig(m), '1:1..1:4 1:9..1:12');

  { Code POINTS, not bytes: a Cyrillic line would put every column after the first match in
    the wrong place if this counted bytes. }
  m := SpxFindAll('ααα казино', 'казино', True);
  Check('find/columns-are-code-points', MatchSig(m), '1:5..1:11');

  { Lines are the editor's three terminators. }
  m := SpxFindAll('раз'#10'два'#13#10'раз'#13'два', 'раз', True);
  Check('find/across-lines', MatchSig(m), '1:1..1:4 3:1..3:4');

  { ── case ── }
  m := SpxFindAll('Казино КАЗИНО казино', 'казино', True);
  Check('find/case-sensitive-finds-one', MatchSig(m), '1:15..1:21');
  m := SpxFindAll('Казино КАЗИНО казино', 'казино', False);
  Check('find/case-insensitive-finds-all', MatchSig(m), '1:1..1:7 1:8..1:14 1:15..1:21');
  { The fold is the engine's own table, so it covers what the engine covers. }
  m := SpxFindAll('ÉCOLE école', 'École', False);
  Check('find/folding-follows-the-engine', MatchSig(m), '1:1..1:6 1:7..1:12');

  { Folding must not move a POSITION. A character that changes length when folded (ß -> SS)
    is the case that breaks a search written the easy way -- fold both strings, then search.
    Every column after it would be reported one byte too far. }
  m := SpxFindAll('straße und weg', 'und', False);
  Check('find/a-folding-character-does-not-shift-positions', MatchSig(m), '1:8..1:11');

  { ── the edges ── }
  m := SpxFindAll('текст', '', False);
  CheckTrue('find/an-empty-needle-matches-nothing', Length(m) = 0);
  m := SpxFindAll('', 'что-то', False);
  CheckTrue('find/an-empty-text-has-nothing', Length(m) = 0);
  m := SpxFindAll('раз', 'раз два', False);
  CheckTrue('find/a-needle-longer-than-the-text', Length(m) = 0);
  { Overlapping occurrences are occurrences: stepping through `аа` in `ааа` must stop
    twice. }
  m := SpxFindAll('ааа', 'аа', True);
  Check('find/overlapping-matches-count', MatchSig(m), '1:1..1:3 1:2..1:4');
  { A needle with a line break in it reports the row it really ends on. }
  m := SpxFindAll('раз'#10'два', 'раз'#10'два', True);
  Check('find/a-multiline-needle', MatchSig(m), '1:1..2:4');
  { AND WITH CRLF, which is the case that was wrong: the LF was counted a second time, so a
    two-line needle reported a row past the end of a two-line document -- a span the editor
    cannot select. This is the check that would have caught it. }
  m := SpxFindAll('раз'#13#10'два', 'раз'#13#10'два', True);
  Check('find/a-multiline-needle-with-crlf', MatchSig(m), '1:1..2:4');
  m := SpxFindAll('a'#13#10'b', #13#10, True);
  Check('find/a-needle-that-is-just-a-crlf', MatchSig(m), '1:2..2:1');

  { The property behind both: no match may end past the document. A span the editor cannot
    select is worse than no match at all. }
  m := SpxFindAll('раз'#13#10'два'#13#10'три', 'два'#13#10'три', True);
  CheckTrue('find/no-match-ends-past-the-document', (Length(m) = 1) and (m[0].EndLine = 3));

  { Malformed UTF-8 in either argument is text like any other: it must not hang, read past
    the end, or match INSIDE a well-formed character. }
  m := SpxFindAll('аб'#$FF'вг', #$FF, True);
  CheckTrue('find/a-stray-byte-is-findable', Length(m) = 1);
  m := SpxFindAll('аб', #$B0, True);
  CheckTrue('find/a-continuation-byte-does-not-match-inside-a-character', Length(m) = 0);

  { The deliberate limit of folding one code point at a time: an expansion cannot cross the
    boundary, so `STRASSE` does not find `straße`. The whole-string fold in SpxDedupe DOES
    call those equal -- the disagreement is the price of a span that is always exactly the
    needle's length, and it is gated here so it stays a decision rather than a surprise. }
  m := SpxFindAll('straße', 'STRASSE', False);
  CheckTrue('find/an-expanding-fold-does-not-match-across-code-points', Length(m) = 0);
  { What it does do: the same letter in the other case, one code point for one. }
  m := SpxFindAll('straße', 'STRAßE', False);
  CheckTrue('find/but-the-same-letter-in-either-case-does', Length(m) = 1);

  { The fast case-folding path is hand-rolled arithmetic for ASCII and Cyrillic, so it is
    checked against the ENGINE's table for every code point in the ranges it claims. A search
    that disagreed with the engine about a letter would be a search nobody could explain. }
  begin
    { The exact property the shortcut relies on: for every code point it claims, the ENGINE's
      uppercase IS the single code point the arithmetic produces. That is what makes "folded
      values differ" a final answer for those, with no table lookup -- and it is a stronger
      claim than "the fold does not change the engine's answer". }
    ok := True;
    for i := 32 to 127 do
      if SpUpperCodePoint(LongWord(i)) <> SpCodePointToStr(SpxTestFastUpper(LongWord(i))) then
        ok := False;
    for i := $400 to $45F do
      if SpUpperCodePoint(LongWord(i)) <> SpCodePointToStr(SpxTestFastUpper(LongWord(i))) then
        ok := False;
    CheckTrue('find/the-fast-fold-is-the-engines-answer-for-what-it-claims', ok);
    { And outside those ranges it claims nothing: the value comes back untouched, so the
      table decides. }
    ok := True;
    for i := $460 to $50F do
      if SpxTestFastUpper(LongWord(i)) <> LongWord(i) then ok := False;
    CheckTrue('find/and-nothing-outside-them', ok);
  end;

  { ── a byte column back to a code-point one ── }

  { The editor's LOGICAL caret is a byte offset; every position here is a code point. The
    conversion has to go both ways or a caret handed back to core means something else. }
  CheckTrue('col/byte-1-is-code-point-1', SpxCodePointColumn('казино', 1) = 1);
  { `казино` is two bytes per letter: byte 7 is the fourth letter. }
  CheckTrue('col/mid-string', SpxCodePointColumn('казино', 7) = 4);
  CheckTrue('col/past-the-end-clamps', SpxCodePointColumn('казино', 999) = 7);
  CheckTrue('col/round-trips-with-the-other-direction',
            SpxCodePointColumn('казино', SpxByteColumn('казино', 5)) = 5);
  CheckTrue('col/an-empty-line', SpxCodePointColumn('', 1) = 1);

  { ── stepping ── }
  m := SpxFindAll('раз два раз три раз', 'раз', True);
  { AT-or-after, not strictly after. Opening a document parks the caret at 1:1, so with a
    strict comparison the first press of Enter landed on the SECOND occurrence whenever the
    first was at the top of the file -- and the name of this check said the opposite of what
    it asserted, which is how it stayed that way. }
  CheckTrue('step/from-the-top-goes-to-the-first', SpxStepMatch(m, 1, 1, False) = 0);
  { Standing exactly on a match, "next" is that match -- the caller steps by index rather
    than asking again from where it stands, so this cannot leave anyone stuck. }
  CheckTrue('step/standing-on-a-match-finds-it', SpxStepMatch(m, 1, 9, False) = 1);
  CheckTrue('step/forward-from-between-matches', SpxStepMatch(m, 1, 10, False) = 2);
  { Past the last one it wraps, rather than leaving the user to scroll back by hand. }
  CheckTrue('step/forward-past-the-end-wraps', SpxStepMatch(m, 1, 99, False) = 0);
  CheckTrue('step/backwards-from-the-end', SpxStepMatch(m, 1, 99, True) = 2);
  CheckTrue('step/backwards-past-the-start-wraps', SpxStepMatch(m, 1, 1, True) = 2);
  m := nil;
  CheckTrue('step/nothing-to-step-through', SpxStepMatch(m, 1, 1, False) = -1);
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

  (* THE COLOURS THE WRAPPER CAN CARRY, and why it carries them at all: the ink has to travel
     with the document, which is what the help page has always done and what was measured to
     work here. (The panel's own TextColor property was tried first and changed nothing on
     screen -- but both attempts changed the property without changing the content, and the
     feed was keyed on the content, so it was never re-fed. Review caught the confound; the
     document route is kept because it is the one that was measured, not because the other was
     disproven.)

     What it closes: the preview took its BACKGROUND from the system and left the text to the
     renderer's default black. On a light desktop the pair agrees by luck; under a Windows
     contrast theme the page is #202020 and the text is still #000000 -- 1.29:1, measured off a
     PrintWindow photograph in which the brightest pixel in the whole pane was the background.
     It is 16.29:1 now. *)
  Check('page/colours-become-body-attributes',
        SpxPageDocument('текст', '#202020', '#ffffff'),
        '<html><body bgcolor="#202020" text="#ffffff">текст</body></html>');
  { BOTH OR NEITHER, because one of the two is exactly the defect above. }
  Check('page/a-background-alone-is-ignored', SpxPageDocument('текст', '#202020', ''),
        '<html><body>текст</body></html>');
  Check('page/an-ink-alone-is-ignored', SpxPageDocument('текст', '', '#ffffff'),
        '<html><body>текст</body></html>');
  { Default arguments, so every caller and every check above keeps the document it had. }
  Check('page/no-colours-is-what-it-always-was', SpxPageDocument('текст'),
        '<html><body>текст</body></html>');
  { A document that opens its own still passes through: it brought its colours with it, and
    the whole point of the pass-through is not to argue with them. }
  Check('page/a-real-document-keeps-its-own-colours',
        SpxPageDocument('<html><body bgcolor="#101010">своё</body></html>', '#202020', '#ffffff'),
        '<html><body bgcolor="#101010">своё</body></html>');

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

{ The region the edit replaced, as `A..B` -- or a refusal. A host applies THIS rather than a
  whole new document, so it is the half of the answer the GUI actually consumes. }
function EditSpan(const Doc: string; Idx: Integer; const V: string): string;
var out_: string; a, b: Integer;
begin
  { THE NUMBERS EVEN ON A REFUSAL, and that is deliberate. Reporting only the boolean here made
    the refusal checks unfalsifiable: a mutation that leaked a real span while still returning
    False passed every one of them. The span is what a caller would splice, so the span is what
    a refusal has to be checked on. }
  if SpxSetDirectiveValue(Doc, Idx, V, out_, a, b) then
    Result := IntToStr(a) + '..' + IntToStr(b)
  else
    Result := 'refused ' + IntToStr(a) + '..' + IntToStr(b);
end;

{ And what that region actually covered in the ORIGINAL document -- the readable form of the
  same fact, so a wrong span is a wrong string rather than two numbers to check by hand. }
function EditSpanText(const Doc: string; Idx: Integer; const V: string): string;
var out_: string; a, b: Integer;
begin
  if not SpxSetDirectiveValue(Doc, Idx, V, out_, a, b) then Exit('<refused>');
  Result := '[' + Copy(Doc, a, b - a) + ']';
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

{ Splice the reported region by hand, the way the window does it through the editor. }
function SpliceByHand(const Doc: string; Idx: Integer; const V: string): string;
var out_: string; a, b: Integer;
begin
  if not SpxSetDirectiveValue(Doc, Idx, V, out_, a, b) then Exit('<refused>');
  Result := Copy(Doc, 1, a - 1) + V + Copy(Doc, b, MaxInt);
end;

procedure TestDirectiveEditing;
var doc, doc2, out_: string;
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

  { ── the jump lands on the KEYWORD, not on the line's edge ── }

  { Indentation IS part of what a directive consumes, so the engine reports column 1 here and a
    jump to it puts the caret in the margin. }
  Check('edit/keyword-past-spaces',
        IntToStr(SpxFirstNonBlankColumn('   #set %a% = 1', 1)), '4');
  Check('edit/keyword-past-tabs',
        IntToStr(SpxFirstNonBlankColumn(#9#9'#def %a% = 1', 1)), '3');
  { A comment is NOT consumed, so the engine already points at the `#` and there is nothing to
    skip -- the adjustment must not move it. }
  Check('edit/keyword-already-there',
        IntToStr(SpxFirstNonBlankColumn('/# c #/#set %a% = 1', 8)), '8');
  { CODE POINTS, not bytes: Cyrillic before the directive is where a byte count goes wrong. }
  Check('edit/keyword-past-cyrillic-and-spaces',
        IntToStr(SpxFirstNonBlankColumn('привет   #set %a% = 1', 7)), '10');
  { Nothing but blanks after it, and a column past the end: unchanged rather than out of range. }
  Check('edit/keyword-blank-line-is-unchanged',
        IntToStr(SpxFirstNonBlankColumn('    ', 2)), '2');
  Check('edit/keyword-past-the-end-is-unchanged',
        IntToStr(SpxFirstNonBlankColumn('#set', 9)), '9');

  { ── THE SPAN, which is what the panel applies ── }

  { It covers the VALUE and nothing else: not the keyword, not the name, not the spacing that
    leads to it, and not the trailing blanks or the comment after it. Read as text rather than
    as two numbers, because a span off by one is then a visible string. }
  Check('edit/span-covers-the-value-only', EditSpanText(doc, 0, 'Новое'), '[Акме]');
  { Half-open, exactly as Splice takes it and as the group editor's write-back already speaks:
    replacing [A, B) with the new value reproduces what the function returned. }
  doc2 := doc;
  Check('edit/span-applied-by-hand-matches-the-function',
        SpliceByHand(doc2, 0, 'Новое'), EditValue(doc, 0, 'Новое'));
  { A value that was empty still has a place to be written -- an empty span at the right point,
    not a refusal. }
  Check('edit/an-empty-value-still-reports-a-place',
        EditSpanText('#set %x% =' + #10 + 'т', 0, 'A'), '[]');
  { A REFUSAL REPORTS NO PLACE -- 0..0, asserted on the NUMBERS. A caller that spliced a leaked
    span after a False would write into a document the function had just refused to change. }
  { The refused case is a value whose comment can PAIR with a closer further down: engine
    `v0.5.0` made an unterminated `/#` ordinary text, so a lone one is no longer a refusal --
    see the note where that is measured. }
  Check('edit/a-refused-value-reports-no-span',
        EditSpan('#set %x% = A'#10'т #/ у', 0, 'A /# oops'), 'refused 0..0');
  Check('edit/a-refused-index-reports-no-span', EditSpan('#set %x% = A'#10'т', 9, 'Б'),
        'refused 0..0');
  { An include has a target, not a value -- and therefore no value span. }
  Check('edit/an-include-has-no-value-span',
        EditSpan('#include "frag"'#10'т', 0, 'Б'), 'refused 0..0');

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

  (* THE WRITTEN TEXT IS NOT TRUSTED. Each of these spliced happily and reported success until
     the edit was read back through the engine.

     AND THAT CHECK SURVIVED THE ENGINE CHANGING UNDER IT, which is the reason it is written
     this way rather than as a list of forbidden characters. Until `v0.5.0` an unterminated
     `/#` swallowed the rest of the file, so a value carrying one was always a refusal; in
     `v0.5.0` it is ordinary text. Nothing here was edited to follow — the read-back simply
     started accepting the harmless case and goes on refusing the harmful one, which is a
     property of the document rather than of the value:

       `#set %x% = A /# oops` with no `#/` later   -> accepted, and the value means itself
       the same edit with a `#/` further down      -> refused, because the two would pair and
                                                      eat the group and everything between

     Both measured on `v0.5.0` before this was rewritten. *)
  doc := '#set %x% = A'#10'корпус текста'#10'%x% и ещё'#10;
  CheckTrue('edit/a lone unterminated comment is now harmless text',
            EditValue(doc, 0, 'A /# oops') <> '<refused>');
  doc := '#set %x% = A'#10'корпус #/ текста'#10'%x% и ещё'#10;
  Check('edit/a-value-that-opens-a-comment', EditValue(doc, 0, 'A /# oops'), '<refused>');
  doc := '#set %x% = A'#10'корпус текста'#10'%x% и ещё'#10;
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
    rows := SpxPanelRows(r, spxLangRu);
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

{$IFDEF DARWIN}
{ FPC 3.2.2's Darwin unzipper reads the central-directory Unix attributes without
  undoing the 16-bit shift made by its zipper. It extracts files as mode 000. The
  export assertion is about archive contents, so normalize only this test tree. }
procedure MakeTreeReadable(const Dir: string);
var sr: TSearchRec; base: string;
begin
  if not DirectoryExists(Dir) then Exit;
  base := IncludeTrailingPathDelimiter(Dir);
  if FindFirst(base + '*', faAnyFile, sr) = 0 then
  try
    repeat
      if (sr.Name = '.') or (sr.Name = '..') then Continue;
      if (sr.Attr and faDirectory) <> 0 then
        MakeTreeReadable(base + sr.Name)
      else
        FpChmod(base + sr.Name, 420);
    until FindNext(sr) <> 0;
  finally
    FindClose(sr);
  end;
end;
{$ENDIF}

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
    CheckTrue('xlsx/writes', SpxWriteXlsx(path, 'Варианты', 'сид', 'вариант', list, rep));
    CheckTrue('xlsx/file-exists', FileExists(path));

    ok := False;
    unzip := TUnZipper.Create;
    try
      unzip.FileName := path;
      unzip.OutputPath := InDir(dir, 'unzipped');
      CreateDir(unzip.OutputPath);
      unzip.UnZipAllFiles;
      {$IFDEF DARWIN}MakeTreeReadable(unzip.OutputPath);{$ENDIF}
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
      { The two column headings are the caller's words, in the caller's language: a workbook
        whose tab says «Варианты» over columns saying `seed` and `variant` is a translation
        half-done, so they travel with the sheet name rather than being baked in. }
      CheckTrue('xlsx/heads-the-columns-in-the-callers-language',
                (Pos('>сид<', s) > 0) and (Pos('>вариант<', s) > 0));
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
      CheckTrue('xlsx/writes-a-hostile-set', SpxWriteXlsx(path, 'Акция "Лето"', 'сид', 'вариант', bad, rep));

      WipeFolder(InDir(dir, 'unzipped2'));
      CreateDir(InDir(dir, 'unzipped2'));
      unzip := TUnZipper.Create;
      try
        unzip.FileName := path;
        unzip.OutputPath := InDir(dir, 'unzipped2');
        unzip.UnZipAllFiles;
        {$IFDEF DARWIN}MakeTreeReadable(unzip.OutputPath);{$ENDIF}
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
              SpxWriteXlsx(InDir(dir, 'named.xlsx'), 'a[b]c/d', 'seed', 'variant', list, rep));

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
                SpxWriteXlsx(InDir(dir, 'empty.xlsx'), 'x', 'seed', 'variant', empty, rep));
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
  TestStrings;
  TestSprites;
  TestSettings;
  TestEditorFont;
  TestLongestLine;
  TestHtmlScan;
  TestGroups;
  TestEngineCodeList;
  TestHelpExamples;
  TestHelpSilences;
  TestOfflineClaim;
  TestAbout;
  TestGsaImport;
  TestVariantCount;
  TestBrandMark;
  TestCompanyMark;
  TestHelpUnit;
  TestSessionValues;
  TestFind;
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
