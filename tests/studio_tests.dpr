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
  SysUtils, Classes, Generics.Collections,
  {$IFDEF FPC}
  Spintax, SpxStudio;
  {$ELSE}
  Spintax in '..\engine\src\Spintax.pas',
  SpxStudio in '..\src\SpxStudio.pas';
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

  Writeln(Format('studio tests: %d checks, %d failed', [Checks, Failures]));
  if Failures > 0 then ExitCode := 1;
end.
