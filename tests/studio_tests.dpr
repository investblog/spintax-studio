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

begin
  SpxInitHost;
  {$IFDEF FPC}
  SetTextCodePage(Output, CP_UTF8);
  {$ENDIF}

  TestHostContract;
  TestEngineBaseline;
  TestRenderPath;

  Writeln(Format('studio tests: %d checks, %d failed', [Checks, Failures]));
  if Failures > 0 then ExitCode := 1;
end.
