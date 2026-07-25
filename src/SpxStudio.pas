{**
 * SpxStudio -- editor-core (spec §5, layer 2): a GUI- and network-free orchestration
 * seam over `unit Spintax`, the layer both the GUI and the LLM loop hang off.
 *
 * What lives here is the Studio-side CONTEXT -- locale, runtime variable values, the RNG
 * mode -- and the handful of calls that turn it into engine calls. What does NOT live here
 * is a second implementation of anything the engine already does: no rescanning, no
 * re-deriving of verdicts, no include expansion (spec §4.2, ADR 0003).
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

  { Everything an engine call needs that is not the template text. The variable map is the
    CALLER's -- this layer never frees it -- matching `TSpContext.Vars`, which the engine
    documents the same way. }
  TSpxContext = record
    Locale: string;
    Vars: TStrMap;
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

{ A context that draws fresh every render -- the preview's default (spec §4.2). }
function SpxContext(const Locale: string; Vars: TStrMap): TSpxContext;

{ A context pinned to a seed: the same template renders the same text every time, which is
  what makes a preview stable while an edit is compared against it, and what lets an
  exported row be regenerated. }
function SpxSeededContext(const Locale: string; Vars: TStrMap; Seed: LongWord): TSpxContext;

{ One rendered example. PostProcess is always on: the right pane is WYSIWYG against the
  engines that ship the text, and a preview without the cosmetic stage lies about spacing
  and capitalization. }
function SpxRenderSample(const Tmpl: string; const Ctx: TSpxContext): string;

{ Count variants with reproducible seeds: `seed_i = SeedBase + i`, recorded on each variant.
  TMulberry32Rng mixes its seed internally (add-constant, then xorshift-multiply), so
  consecutive seeds give uncorrelated streams and the derivation needs nothing cleverer
  (spec §4.6).

  Ctx.RngMode is deliberately IGNORED here: a batch is always seeded, or the set it produces
  cannot be regenerated. Count <= 0 yields an empty list. The caller frees the list. }
function SpxRenderBatch(const Tmpl: string; const Ctx: TSpxContext;
  Count: Integer; SeedBase: LongWord): TSpxVariantList;

implementation

procedure SpxInitHost;
begin
  {$IFDEF FPC}
  DefaultSystemCodePage := CP_UTF8;
  {$ENDIF}
end;

function SpxContext(const Locale: string; Vars: TStrMap): TSpxContext;
begin
  Result.Locale := Locale;
  Result.Vars := Vars;
  Result.RngMode := spxRandom;
  Result.Seed := 0;
end;

function SpxSeededContext(const Locale: string; Vars: TStrMap; Seed: LongWord): TSpxContext;
begin
  Result := SpxContext(Locale, Vars);
  Result.RngMode := spxSeeded;
  Result.Seed := Seed;
end;

{ The engine context for one call. Rng = nil is not an oversight: the engine then builds its
  own default generator, which is the analogue of the reference rendering with no seed.

  When the engine grows the family's `#include` resolver seam (ADR 0003), the resolver is
  one more field filled in here -- no signature above changes, and no caller learns about
  it. }
function EngineContext(const Ctx: TSpxContext; Rng: TSpRng): TSpContext;
begin
  Result := Default(TSpContext);
  Result.Locale := Ctx.Locale;
  Result.Vars := Ctx.Vars;
  Result.PostProcess := True;   // never left to the record's zeroed default (spec §7)
  Result.Rng := Rng;
end;

{ One render with the seed the caller asked for, or with none. Whatever this creates, it
  frees: the engine never takes ownership of a caller's RNG. }
function RenderWith(const Tmpl: string; const Ctx: TSpxContext;
  Seeded: Boolean; Seed: LongWord): string;
var rng: TSpRng;
begin
  if Seeded then rng := TMulberry32Rng.Create(Seed) else rng := nil;
  try
    Result := SpRender(Tmpl, EngineContext(Ctx, rng));
  finally
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

end.
