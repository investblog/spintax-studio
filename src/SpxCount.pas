(*
 * SpxCount -- how many VARIANTS this template can produce.
 *
 * A variant is one filled-in template: one choice made at every construct, one draw for every
 * macro. It is NOT the same as a distinct text, and the word is chosen on purpose --
 * `{a|a}` is two variants and one text. Saying "texts" here would be a claim this file does
 * not check and cannot make without rendering every combination, which is the work the number
 * exists to save. An outside review caught the comment saying it; the checks had said
 * otherwise since the day they were written (`duplicate-options`).
 *
 * The number an author actually asks for. GTW puts «Max возможных вариантов: 241 864 704»
 * beside «Сгенерировано: 50», and that pair is what tells someone their template is thin
 * before they export a thousand rows and find out by reading them.
 *
 * NO SECOND PARSER. The structure comes from `SpxTokens` -- the same scanner the highlighter
 * paints from and the group editor edits by -- so a construct is whatever the editor already
 * thinks it is. The macro VALUES and the directive spans both come from ONE
 * `SpExtractDirectives` pass, never from reading `#set` lines here, for the reason the charter
 * gives: a hand-parsed directive list disagrees with the renderer sooner or later.
 *
 * ONE PASS, not two. This asked `SpxExtractModel` for the macros and `SpExtractDirectives` for
 * the spans -- two walks of the whole document for one question -- and the model is a
 * structure the PANEL needs, flattened and deduplicated, which is also how the first version
 * came to read the FIRST definition of a redefined macro where the engine takes the last.
 * Removing the second pass halved the cost (18.2 ms to 8.2 ms on 100 KB) and fixed that at the
 * same time, which is the usual shape: the redundant thing was also the wrong thing.
 *
 * ▁▁▁ WHAT MULTIPLIES, MEASURED BY ENUMERATION RATHER THAN REASONED ABOUT ▁▁▁
 *
 * Every rule below was checked by rendering the template with hundreds of seeds and counting
 * the distinct outputs (2026-08-07, engine v0.5.0):
 *
 *   {a|b|c}                  3        a free choice: the options add up
 *   {a|b}{c|d}               4        independent constructs multiply
 *   [a|b|c]                  6 = 3!   a permutation prints EVERY option, in a random order
 *   [<minsize=2>a|b|c]      12        ordered subsets: P(3,2) + P(3,3)
 *   #set %x% = {a|b}, %x%%x%  4       a macro is re-rolled at EVERY use
 *   #def %x% = {a|b}, %x%%x%  2       a definition is resolved once and held
 *   {?V?yes|no}, V unset      1       a conditional is not a choice -- the input picks
 *   {plural 2: one|many}      1       the number picks the form
 *
 * So conditionals and plurals do not multiply anything on their own: they are decided by the
 * session's values and the document's locale. Counting them as 2 or 3 would produce a number
 * bigger than the template can actually make. They are counted as ONE, and the answer is
 * marked as a LOWER BOUND instead -- setting a variable can only add texts, never remove any.
 *
 * The same goes for an `#include` whose target the template set cannot resolve: it renders
 * empty, contributes one, and makes the answer a bound rather than a promise.
 *)
unit SpxCount;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Generics.Collections, Spintax, SpxTokens, SpxStudio;

const
  { Past this the number stops being information and starts being a row of digits: an author
    who sees it knows the template is not thin, which is the whole question. Saturating also
    keeps the arithmetic inside Int64 -- two counts below the ceiling can always be multiplied
    without overflow. }
  SPX_COUNT_CEILING = Int64(1000) * 1000 * 1000 * 1000;   { 10^12 }

type
  TSpxCount = record
    { How many variants -- see the unit header for why that word and not "texts" -- or
      SPX_COUNT_CEILING when the real number is larger. }
    Value: Int64;
    { False when something in the document is decided by input rather than by chance -- a
      conditional, a plural, or an include the set could not resolve. Then Value is a LOWER
      bound: the template makes at least this many. }
    Exact: Boolean;
    { The count reached the ceiling and stopped. Value is then "this many or more" in a second
      sense, and a caller that prints a number should say so. }
    Saturated: Boolean;
  end;

{ Count what the document can produce, in the context that will render it. The context matters
  twice over: its template set resolves `#include`, and its `Vars` are the session values,
  which OUTRANK the document's own `#set` and are templates in their own right. }
function SpxCountVariants(const Doc: string; const Ctx: TSpxContext): TSpxCount;

implementation

type
  (* A token with its own TEXT rather than a position in the document.

     The first version carried the scanner's offsets and rebuilt document positions by adding
     up line lengths -- which is one byte short per line the moment the file uses CRLF, so
     every `%x%` on line two was read a byte off, no macro was ever found, and a template that
     makes four texts counted as one. It passed a probe written with #10 and failed the suite
     written with LineEnding, which is the whole lesson: a document with the line ending the
     APP will hand it, or the measurement is of a file nobody has.

     Carrying the text removes the arithmetic instead of correcting it. *)
  TCTok = record
    Kind: TSpxTokenKind;
    { Only for the three kinds that carry a name: a variable, an include target and a
      permutation config. Copying every TEXT token's characters as well was most of a 100 KB
      document copied into twenty thousand short strings, for nothing. }
    Text: string;
  end;
  TCTokList = specialize TList<TCTok>;

  { One macro definition, as the engine keeps it. }
  TCMacro = record
    Value: string;
    IsDef: Boolean;
  end;
  TCMacros = specialize TDictionary<string, TCMacro>;

  { One construct being counted. `Options` holds each finished option's own count; `Current`
    is the option being read. A permutation also remembers the subset limits its config asked
    for. }
  TFrame = record
    Kind: TSpxTokenKind;      { sptBraceOpen or sptBracketOpen }
    Free: Boolean;            { a plain choice or permutation -- a conditional or plural is not }
    Cond: Boolean;            { a conditional, whose branches are rendered -- see the close }
    Options: array of Int64;
    Current: Int64;
    MinSize, MaxSize: Integer;   { permutation subset limits; -1 = unset, as the engine }
  end;

{ Multiply, and stop at the ceiling rather than wrapping.

  ZERO MULTIPLIES TO ZERO, and that line is here because the first version said `if A <= 0
  then Exit(1)` -- defensive nonsense reasoned from "a count is never zero". It is never zero
  for a VARIANT count, but this routine is also used on the symmetric polynomial below, where
  e_k is legitimately 0 until k options have been read. Treating that 0 as 1 made every
  permutation too big by a factor that grew with n: `[aa|bb]` came out 4 against the engine's
  2, and `[aa|bb|cc]` 24 against 6. }
function MulSat(A, B: Int64): Int64;
begin
  if (A = 0) or (B = 0) then Exit(0);
  if (A < 0) or (B < 0) then Exit(0);
  if A > SPX_COUNT_CEILING div B then Exit(SPX_COUNT_CEILING);
  Result := A * B;
end;

function AddSat(A, B: Int64): Int64;
begin
  Result := A + B;
  if (Result > SPX_COUNT_CEILING) or (Result < 0) then Result := SPX_COUNT_CEILING;
end;

{ k! , saturating. }
function FactSat(K: Integer): Int64;
var i: Integer;
begin
  Result := 1;
  for i := 2 to K do Result := MulSat(Result, i);
end;

(* THE PERMUTATION'S ARITHMETIC, and it is not `n!` once the options carry their own variants.

   A permutation prints a SUBSET of the options, of a size its config allows, in a random
   order. For a subset S of size k the number of texts is k! times the product of the counts
   inside S -- k! for the orderings, the product for what each option can itself say. Summed
   over every subset of every allowed size:

       Σ(k = min..max)  k! · e_k(c₁..c_n)

   where e_k is the elementary symmetric polynomial -- the sum of the products of every
   k-subset. It is built here by the usual one-line recurrence rather than by enumerating
   subsets, which would be 2^n. With every cᵢ = 1 it degenerates to Σ k!·C(n,k) = Σ P(n,k),
   which is the 12 measured for `[<minsize=2>a|b|c]`.

   ▁▁▁ THE RANGE IS THE ENGINE'S, COPIED FROM ITS SOURCE AND NOT INFERRED ▁▁▁

   `Spintax.pas:1830-1837`, and the four branches are NOT symmetric -- which is exactly what a
   reasonable-looking guess gets wrong:

     both given   -> min, max as written
     only minsize -> max is the whole set
     only maxsize -> **min is 1**, not the whole set
     neither      -> the whole set, both ends

   then min is clamped up to 1 and down to n, and only THEN `if max < min then max := min` --
   so a contradictory `<minsize=3;maxsize=2>` widens to the full permutation rather than
   narrowing. The first version of this file collapsed all four into "absent means n" and then
   clamped min DOWN to max, which answered 6 for `[<maxsize=2>a|b|c]` where the engine makes 9
   and 6 for `[<minsize=0>a|b|c]` where it makes 15. Absent is -1 here for the same reason it
   is in the engine: 0 is a value a reader can write, and `minsize=0` means one, not all. *)
function PermutationCount(const Counts: array of Int64; AMin, AMax: Integer): Int64;
var
  e: array of Int64;
  n, i, k, min_, max_: Integer;
begin
  n := Length(Counts);
  if n = 0 then Exit(1);

  if (AMin >= 0) and (AMax >= 0) then begin min_ := AMin; max_ := AMax; end
  else if AMin >= 0 then begin min_ := AMin; max_ := n; end
  else if AMax >= 0 then begin min_ := 1; max_ := AMax; end
  else begin min_ := n; max_ := n; end;
  if min_ < 1 then min_ := 1;
  if min_ > n then min_ := n;
  if max_ < min_ then max_ := min_;
  if max_ > n then max_ := n;

  SetLength(e, n + 1);
  e[0] := 1;
  for i := 1 to n do e[i] := 0;
  for i := 0 to n - 1 do
  begin
    { e_k is still 0 for every k above the number of options read so far, so the full range
      is wasted work: 3 000 options measured 101 ms before this line, which is the quadratic
      term and not the arithmetic. }
    k := i + 1;
    if k > n then k := n;
    for k := k downto 1 do
      e[k] := AddSat(e[k], MulSat(e[k - 1], Counts[i]));
  end;

  Result := 0;
  for k := min_ to max_ do
    Result := AddSat(Result, MulSat(FactSat(k), e[k]));
  {$IFDEF SPX_COUNT_TRACE}
  Write('  PERM n=', n, ' min=', min_, ' max=', max_, ' counts=');
  for i := 0 to n - 1 do Write(Counts[i], ' ');
  WriteLn('-> ', Result);
  {$ENDIF}
  if Result < 1 then Result := 1;
end;

(* THE PERMUTATION CONFIG, AND WHETHER IT IS ONE AT ALL.

   `<...>` right after `[` is always the config TOKEN -- the engine consumes it either way, and
   the scanner is right to paint it -- but its CONTENT is read as key/value only when a key is
   really there. Otherwise the whole thing is the separator and the permutation prints every
   option. Two engine functions, and this file used to mirror only the second:

     HasConfigKey (`Spintax.pas:1397`) -- one of minsize / maxsize / sep / lastsep, at a WORD
     BOUNDARY, followed after whitespace by `=`. Without it, no key is read at all. Skipping
     this gate answered 9 for `[<maxsize 2>a|b|c]` and 3 for `[<xmaxsize=1>a|b|c]`, both of
     which the engine renders as full permutations of 6 -- a separator that happens to contain
     a key word is not a config, and a key word glued to a prefix is not a key.

     FindInt -- `/(min|max)size\s*=\s*(\d+)/i`, and v0.5.1 corrected three things in it, all
     measured against the JS reference: the `=` is REQUIRED (`[<sep="-" maxsize 2>a|b|c]` used
     to cut the set to two and now prints all three), the whitespace class is JS `\s` within
     ASCII rather than space-and-tab (so `minsize` LF `=2` is a config), and a failed candidate
     RETRIES at the next position the way a regex does (`[<minsize foo minsize=1>…]` finds the
     second one). Studio was one release behind on all three the moment the pin moved.

   Deliberately NOT corrected: `FindInt` searches with a plain `Pos`, so a key word inside a
   quoted separator is found -- `[<sep="maxsize=1">a|b|c]` really is maxsize=1 in the engine,
   which is 3 in both. Mirroring means mirroring the warts. *)
const
  { JS `\s` within ASCII, which is what the engine spells out "for PHP parity". VT and FF are
    IN it, and leaving them out is simply a wrong port -- the engine's own comment. }
  CFG_WS = [' ', #9, #10, #11, #12, #13];

function PermConfigHasKey(const S: string): Boolean;
const KEYS: array[0..3] of string = ('minsize', 'maxsize', 'sep', 'lastsep');
var low: string; k, j, e: Integer;
begin
  Result := False;
  low := LowerCase(S);
  for k := 1 to Length(low) do
  begin
    if (k > 1) and (low[k - 1] in ['a'..'z', '0'..'9', '_']) then Continue;
    for j := 0 to High(KEYS) do
      if Copy(low, k, Length(KEYS[j])) = KEYS[j] then
      begin
        e := k + Length(KEYS[j]);
        while (e <= Length(low)) and (low[e] in CFG_WS) do Inc(e);
        if (e <= Length(low)) and (low[e] = '=') then Exit(True);
      end;
  end;
end;

procedure ReadPermConfig(const S: string; out AMin, AMax: Integer);

  function Num(const Key: string): Integer;
  var low, d: string; k, j: Integer;
  begin
    Result := -1;
    low := LowerCase(S);
    k := 1;
    while True do
    begin
      k := PosEx(Key, low, k);
      if k = 0 then Exit;
      j := k + Length(Key);
      while (j <= Length(S)) and (S[j] in CFG_WS) do Inc(j);
      if (j <= Length(S)) and (S[j] = '=') then
      begin
        Inc(j);
        while (j <= Length(S)) and (S[j] in CFG_WS) do Inc(j);
        d := '';
        while (j <= Length(S)) and (S[j] in ['0'..'9']) do
        begin
          d := d + S[j];
          Inc(j);
        end;
        if d <> '' then Exit(StrToIntDef(d, -1));
      end;
      { A regex retries at the next position; stopping at the first candidate reported
        nothing for a config that names the key twice. }
      Inc(k);
    end;
  end;

begin
  AMin := -1;
  AMax := -1;
  { No key means the whole `<...>` is the separator, and every option is printed. }
  if not PermConfigHasKey(S) then Exit;
  AMin := Num('minsize');
  AMax := Num('maxsize');
end;

(* THE DOCUMENT'S MACROS, LAYERED THE WAY THE ENGINE LAYERS THEM.

   Built straight from the directive list this file already has, which is the charter's rule
   stated exactly (values come from `SpExtractDirectives`) and one whole engine pass cheaper
   than asking `SpxExtractModel` for a structure the panel needs and the counter does not:
   5.75 ms of the 18 it took to count a 100 KB document.

   TWO LAYERS, NOT ONE LIST, and they are not interchangeable. `ExtractDirectives`
   (`Spintax.pas:1227`) keeps `#set` and `#def` in separate maps, each `AddOrSetValue` so the
   LAST definition of a name wins; the render then lays the definitions over the sets
   (`3145-3184`), so a `#def` beats a `#set` of the same name however they are ordered in the
   text. Taking the FIRST match out of a flat list -- which is what this did before -- answered
   2 for a document that redefines its macro and renders 3. Redefinition is not exotic: it is
   the first question a reader of this project ever asked. *)
function BuildMacros(Dirs: TSpDirectiveList): TCMacros;
var i: Integer; m: TCMacro;
begin
  Result := TCMacros.Create;
  m.IsDef := False;
  for i := 0 to Dirs.Count - 1 do
    if Dirs[i].Kind = 'set' then
    begin
      m.Value := Dirs[i].Value;
      Result.AddOrSetValue(LowerCase(Dirs[i].Name), m);
    end;
  m.IsDef := True;
  for i := 0 to Dirs.Count - 1 do
    if Dirs[i].Kind = 'def' then
    begin
      m.Value := Dirs[i].Value;
      Result.AddOrSetValue(LowerCase(Dirs[i].Name), m);
    end;
end;

{ Code point N of a line, as a byte index into it. The engine reports directive columns in
  CODE POINTS (its own comment says so) and the scanner works in bytes, so one Cyrillic letter
  is the difference between masking a directive and masking half of it. }
function ByteOfCodePoint(const Line: string; CP: Integer): Integer;
var i, n: Integer;
begin
  i := 1;
  n := 1;
  while (i <= Length(Line)) and (n < CP) do
  begin
    Inc(i);
    while (i <= Length(Line)) and (Byte(Line[i]) and $C0 = $80) do Inc(i);   { UTF-8 tail }
    Inc(n);
  end;
  Result := i;
end;

{ Every token of the document, in order, with the scanner's own state carried across lines --
  the same walk the highlighter does, so a comment three lines up is still open here too.
  `AIncludes` comes back with how many `#include` occurrences the ENGINE found, for the
  reconciliation in CountText. }
procedure TokeniseAll(const Doc: string; Dirs: TSpDirectiveList; Tokens: TCTokList;
  out AIncludes: Integer; out AOpenComment, ALooseInclude, AOpenConfig: Boolean);
var
  lines: TStringList;
  state: TSpxScanState;
  line: TSpxTokenList;
  masked: string;
  i, j, k, b1, b2: Integer;
  lineHasInclude: Boolean;
  prevKind: TSpxTokenKind;
  slice: string;
  t: TCTok;

  { Blank the directive's own characters, keeping the line's length: a deletion could join
    two constructs that were never adjacent. }
  procedure MaskOn(ALine, AFromCP, AToCP: Integer);
  var m: string; c: Integer;
  begin
    if (ALine < 1) or (ALine > lines.Count) then Exit;
    m := lines[ALine - 1];
    if AFromCP < 1 then AFromCP := 1;
    b1 := ByteOfCodePoint(m, AFromCP);
    if AToCP < 0 then b2 := Length(m) + 1 else b2 := ByteOfCodePoint(m, AToCP);
    if b2 > Length(m) + 1 then b2 := Length(m) + 1;
    for c := b1 to b2 - 1 do m[c] := ' ';
    lines[ALine - 1] := m;
  end;

begin
  AIncludes := 0;
  AOpenComment := False;
  ALooseInclude := False;
  AOpenConfig := False;
  prevKind := sptText;
  lines := TStringList.Create;
  line := TSpxTokenList.Create;
  try
    lines.Text := Doc;

    (* A `#set` OR `#def` IS NOT OUTPUT, and the scanner has no reason to know that: it paints
       `#set %x% = {aa|bb}` as a directive, a variable and a choice, all of which are real
       tokens and none of which the reader ever sees. Counting them multiplied the value into
       the document twice over -- `#set %x% = {aa|bb}` used twice measured 16 against the
       engine's 4.

       WHAT IS MASKED IS THE DIRECTIVE'S OWN SPAN, not the editor line it starts on, and the
       two are not the same thing. Directives end at any of FIVE terminators and the editor
       counts THREE (the charter's "two line models"), so `#set %x% = qq` U+2028 `{aa|bb}` is a
       directive and a choice on ONE editor line -- and blanking the line threw the choice away:
       the engine makes two texts there and the counter said one. The engine reports the span,
       so the span is what goes.

       `#include` is deliberately NOT masked -- it is the one directive whose result IS
       output. Its occurrences are counted here for the reconciliation instead. *)
    for i := 0 to Dirs.Count - 1 do
      if Dirs[i].Kind = 'include' then Inc(AIncludes)
      else if (Dirs[i].Kind = 'set') or (Dirs[i].Kind = 'def') then
      begin
        if Dirs[i].EndLine = Dirs[i].Line then
          MaskOn(Dirs[i].Line, Dirs[i].Column, Dirs[i].EndColumn)
        else
        begin
          MaskOn(Dirs[i].Line, Dirs[i].Column, -1);
          for k := Dirs[i].Line + 1 to Dirs[i].EndLine - 1 do MaskOn(k, 1, -1);
          MaskOn(Dirs[i].EndLine, 1, Dirs[i].EndColumn);
        end;
      end;

    state := Default(TSpxScanState);
    for i := 0 to lines.Count - 1 do
    begin
      masked := lines[i];
      line.Clear;
      SpxScanLine(masked, state, line);
      { One Pos over the rare line that mentions the word at all -- see ALooseInclude below. }
      lineHasInclude := Pos('#include', masked) > 0;
      for j := 0 to line.Count - 1 do
      begin
        t.Kind := line[j].Kind;
        { Only the kinds whose characters are read later; see TCTok. }
        if t.Kind in [sptVariable, sptString, sptPermConfig] then
          t.Text := Copy(masked, line[j].Start, line[j].Length)
        else
        begin
          t.Text := '';
          (* ...and NOT the keyword of an include still waiting for its target. Since
             `SpxTokens` learned to carry that wait, a line-leading `#include` with the target
             further down arrives here as ordinary text on purpose -- the scanner will not
             paint a keyword it cannot yet confirm -- and reading it as a loose mention made
             every such document a lower bound again. The state says which it is: the scan
             leaves IncludeOpen set exactly when this line was that keyword. *)
          if lineHasInclude and (t.Kind = sptText) and (not state.IncludeOpen) and
             (Pos('#include', Copy(masked, line[j].Start, line[j].Length)) > 0) then
            ALooseInclude := True;
          (* A PERMUTATION CONFIG THAT RUNS PAST THE END OF THE LINE. The scanner wants the
             closing `>` on the line it started (it says so), and the engine looks through the
             whole permutation -- so `[<minsize` LF `=2>a|b|c]` is a config of 12 to the engine
             and three plain options of 6 here. The tell is exact and needs one slice: the
             token right after `[` opens an angle bracket it does not close. Real HTML content
             closes its own -- `[<li>a|b</li>]` arrives as `<li>a`, which has its `>`. *)
          if (prevKind = sptBracketOpen) and (t.Kind = sptText) then
          begin
            slice := Copy(masked, line[j].Start, line[j].Length);
            if (Pos('<', slice) > 0) and (Pos('>', slice) = 0) then AOpenConfig := True;
          end;
        end;
        prevKind := t.Kind;
        Tokens.Add(t);
      end;
    end;
    AOpenComment := state.InComment;
  finally
    line.Free;
    lines.Free;
  end;
end;

(* SCOPE, WHICH IS THE ENGINE'S AND NOT A CONVENIENCE.

   `Defs` is the macro table a `%name%` is resolved against, and it is passed rather than
   re-derived because the two nestings here have DIFFERENT scopes:

     - a macro's VALUE is expanded in the document's own scope, so `#set %b% = %a% ...`
       resolves `%a%` from the same table. Extracting a fresh model from the value alone made
       `%a%` an undefined runtime variable worth 1, and the count came out 2 against the
       engine's 4;
     - an INCLUDED fragment gets a CHILD scope without the parent's `#set` (the family's rule,
       and the engine's since v0.3.0), so its own model is extracted and the parent's is not
       handed down.

   `Stack` holds the macros currently being expanded: `#set %a% = %a%` is a template the engine
   refuses, and this must not hang before it gets there.

   `DefTotal` is the product of every `#def` that anything references, shared across the whole
   recursion rather than kept per document -- see the note over MacroCount. *)
function CountText(const Doc: string; const Ctx: TSpxContext; Defs: TCMacros;
  var Exact: Boolean; var DefTotal: Int64; Depth: Integer;
  Seen, Stack, DefsUsed: TStringList): Int64; forward;

(* A MACRO'S OWN COUNT, and WHOSE value it is.

   ---- A HOST VALUE OUTRANKS THE DOCUMENT. Measured, then confirmed in the engine's source:
   SpRender builds its table from the `#set` definitions and then overlays the runtime vars on
   top (`Spintax.pas:3145-3151`), and a `#def` whose name a runtime var carries is never rolled
   at all -- the comment there says so in as many words. So a session value the reader typed
   into the Variables panel is what renders, and the `#set` in the document is dead. Measured
   before it was believed: `#set %y% = qq` with a session `y = {ee|ff}` renders `ee` or `ff`,
   two texts, where this counter used to answer one.

   ---- AND A SESSION VALUE IS A TEMPLATE. It is rendered like any other macro value -- a
   choice picks, a `%name%` expands -- which is the family's contract and why the panel has a
   Literal tick at all. A literal one arrives here already neutralised (SpxValueForEngine), so
   its braces are sentinels and it counts as the one text it is, with no special case needed.
   The first version of this file skipped `spxVarRuntime` outright and answered 2 where the
   engine makes 4.

   ---- `#set` VERSUS `#def` IS A DIFFERENCE IN WHEN THE DRAW HAPPENS. A `#set`, and a session
   value with it (measured: `%x% %x%` with `x = {aa|bb}` gives four), is re-rolled at every
   use, so it multiplies once per occurrence. A `#def` is rolled ONCE for the whole render,
   before the body, dependencies first, whether the body ends up using it or not
   (`Spintax.pas:3162-3184`). So it multiplies the DOCUMENT once, not the option it happens to
   be written in -- which is why its bookkeeping is a shared list and a shared product rather
   than anything held per construct. The version that multiplied it into the enclosing option
   answered 3 for a `#def` used in both alternatives of one choice: neither the four draws
   there are, nor the two texts that come out. *)
function MacroCount(Model: TCMacros; const Name: string; const Ctx: TSpxContext;
  var Exact: Boolean; var DefTotal: Int64; Depth: Integer;
  Seen, Stack, DefsUsed: TStringList; out IsDef: Boolean): Int64;
var hostVal: string; mac: TCMacro;
begin
  Result := 1;
  IsDef := False;
  if Stack.IndexOf(Name) >= 0 then
  begin
    { A macro that expands itself. The engine will not render this; count one and say the
      answer is not a promise. }
    Exact := False;
    Exit;
  end;
  { The engine stops expanding at MAX_VARIABLE_DEPTH = 50 (`Spintax.pas:273`) and renders the
    unexpanded `%name%` as text. `Stack` IS that depth -- it holds exactly the macros being
    expanded right now -- so the guard costs nothing extra. }
  if Stack.Count >= 50 then
  begin
    Exact := False;
    Exit;
  end;

  { The host's table first, because the engine reads it last. }
  if (Ctx.Vars <> nil) and Ctx.Vars.TryGetValue(LowerCase(Name), hostVal) then
  begin
    if hostVal = '' then Exit;
    Stack.Add(Name);
    try
      Result := CountText(hostVal, Ctx, Model, Exact, DefTotal, Depth, Seen, Stack, DefsUsed);
    finally
      Stack.Delete(Stack.IndexOf(Name));
    end;
    Exit;
  end;

  if Model = nil then Exit;
  if not Model.TryGetValue(LowerCase(Name), mac) then Exit;
  IsDef := mac.IsDef;
  if mac.Value = '' then Exit;
  Stack.Add(Name);
  try
    Result := CountText(mac.Value, Ctx, Model, Exact, DefTotal, Depth, Seen, Stack, DefsUsed);
  finally
    Stack.Delete(Stack.IndexOf(Name));
  end;
end;

function CountText(const Doc: string; const Ctx: TSpxContext; Defs: TCMacros;
  var Exact: Boolean; var DefTotal: Int64; Depth: Integer;
  Seen, Stack, DefsUsed: TStringList): Int64;
var
  tokens: TCTokList;
  frames: array of TFrame;
  top, i, k, mn, mx: Integer;
  owned: TCMacros;
  dirs: TSpDirectiveList;
  t: TCTok;
  name_, target, text_: string;
  isDef: Boolean;
  engineIncludes, tokenIncludes: Integer;
  openComment, looseInclude, openConfig, trustIncludes, ownScope: Boolean;
  ownDefsUsed, defsHere: TStringList;
  ownTotal: Int64;
  totalHere: PInt64;
  c: Int64;

  procedure Push(AKind: TSpxTokenKind; AFree: Boolean);
  begin
    Inc(top);
    SetLength(frames, top + 1);
    frames[top] := Default(TFrame);
    frames[top].Kind := AKind;
    frames[top].Free := AFree;
    frames[top].Current := 1;
    frames[top].MinSize := -1;
    frames[top].MaxSize := -1;
  end;

  { Multiply into whatever is being read -- an option of an open construct, or the document. }
  procedure Into(AValue: Int64);
  begin
    if top >= 0 then frames[top].Current := MulSat(frames[top].Current, AValue)
    else Result := MulSat(Result, AValue);
  end;

begin
  Result := 1;
  if Doc = '' then Exit;
  { The include guard is the engine's: twenty deep, and a target already on the stack renders
    empty rather than recursing. }
  if Depth > 20 then
  begin
    Exact := False;
    Exit;
  end;

  { ONE directive pass for both jobs -- the masking spans and the macro table. Everything the
    `finally` frees is nil until the `try` owns it, so an exception between the two cannot
    strand a half-built scope; `dirs` is the one allocation outside it, hence its own guard. }
  owned := nil;
  ownDefsUsed := nil;
  tokens := nil;
  ownTotal := 1;
  dirs := SpExtractDirectives(Doc);
  try
  (* A DOCUMENT SCOPE, and an included fragment is one. `ResolveIncludes` calls the whole
     render again per occurrence (`Spintax.pas:3195`), so a fragment's `#def` is rolled once
     PER INCLUDE, not once for the outer document -- and two fragments may each define `%d%`
     without meaning the same macro. Sharing one flat, name-keyed list across the recursion
     answered 2 for a document that includes one such fragment twice and renders 4, and 2 for
     two different fragments that render 6. Found by review; the suite's own include-twice
     case used a fragment with no definition in it, which is why it was green. *)
  ownScope := Defs = nil;
  if ownScope then
  begin
    owned := BuildMacros(dirs);
    Defs := owned;
    ownDefsUsed := TStringList.Create;
    ownDefsUsed.CaseSensitive := False;
    defsHere := ownDefsUsed;
    totalHere := @ownTotal;
  end
  else
  begin
    defsHere := DefsUsed;
    totalHere := @DefTotal;
  end;
  tokens := TCTokList.Create;
    TokeniseAll(Doc, dirs, tokens, engineIncludes, openComment, looseInclude, openConfig);

    (* WHETHER AN INCLUDE MAY BE RESOLVED AT ALL, decided before the walk rather than reported
       after it. The reconciliation used to run at the end and only downgrade `Exact`, which
       cannot repair an OVER-count: `#include "f" junk` is not an include at all (the engine's
       anchor allows only trailing whitespace) and renders as one literal line, but the scanner
       emits a target, the fragment got multiplied in, and the panel said "at least 2" about a
       document that makes 1. A floor that is above the real answer is worse than no floor.

       So when the two disagree about how many includes there are, no include is resolved: each
       counts as the one text it might be, and the answer is a floor for real this time. *)
    tokenIncludes := 0;
    for i := 0 to tokens.Count - 1 do
      if tokens[i].Kind = sptString then Inc(tokenIncludes);
    trustIncludes := tokenIncludes = engineIncludes;
    if not trustIncludes then Exact := False;
    tokenIncludes := 0;
    top := -1;
    SetLength(frames, 0);

    for i := 0 to tokens.Count - 1 do
    begin
      t := tokens[i];
      case t.Kind of
        sptBraceOpen:
          { A conditional or a plural is decided by the input, so it is NOT a free choice: its
            head token arrives next and says which this is. Pushed as free, corrected below. }
          Push(sptBraceOpen, True);
        sptBracketOpen:
          Push(sptBracketOpen, True);
        sptCondHead, sptPluralHead:
          if top >= 0 then
          begin
            frames[top].Free := False;
            frames[top].Cond := t.Kind = sptCondHead;
            Exact := False;
          end;
        sptPermConfig:
          if (top >= 0) and (frames[top].Kind = sptBracketOpen) then
          begin
            mn := -1; mx := -1;
            ReadPermConfig(t.Text, mn, mx);
            frames[top].MinSize := mn;
            frames[top].MaxSize := mx;
          end;
        sptPipe:
          if top >= 0 then
          begin
            k := Length(frames[top].Options);
            SetLength(frames[top].Options, k + 1);
            frames[top].Options[k] := frames[top].Current;
            frames[top].Current := 1;
          end;
        sptBraceClose, sptBracketClose:
          (* A CLOSER OF THE WRONG KIND IS NOT A CLOSER. A bracket opened and closed by a
             brace is five options and a brace, which the engine renders verbatim as one text
             -- and this popped the bracket frame anyway and reported 120, as a promise.
             `SpxTokens.SpxMatchBracket` is careful about exactly this ("mismatched kinds: the
             validator's business, not a pair to draw") and the walk was not. Ignore it: the
             frame stays open, and the leftover handling below makes the answer a floor.

             Written with star-parens because the example it wants to quote is made of braces,
             and the charter has paid for that lesson twice. *)
          if (top >= 0) and
             (((t.Kind = sptBraceClose) and (frames[top].Kind = sptBraceOpen)) or
              ((t.Kind = sptBracketClose) and (frames[top].Kind = sptBracketOpen))) then
          begin
            k := Length(frames[top].Options);
            SetLength(frames[top].Options, k + 1);
            frames[top].Options[k] := frames[top].Current;
            if not frames[top].Free then
            begin
              (* A CONDITIONAL'S INPUT PICKS THE BRANCH -- but the branch still has whatever is
                 inside it, and answering 1 threw that away: a conditional holding two choices
                 reported one where the engine makes two, and a document wrapped in a single
                 conditional reported "at least 1" however large it was. The BIGGEST branch is
                 the honest floor: some value selects it, and then the template really does make
                 that many. Summing them would not be a floor -- no single input reaches two.

                 A PLURAL IS NOT THAT, and the difference is measured rather than assumed. A
                 form holding a construct makes the engine refuse the whole thing and print it
                 verbatim: `plural 2` over two choices renders the literal source, one text, and
                 the same shape written as a conditional renders two. So a plural counts one,
                 and the first version of this fix -- max over branches for both -- reported
                 "at least 2" for a template that makes 1. The suite caught it because the
                 floor is enumerated and not written down. *)
              c := 1;
              if frames[top].Cond then
                for k := 0 to High(frames[top].Options) do
                  if frames[top].Options[k] > c then c := frames[top].Options[k];
            end
            else if frames[top].Kind = sptBracketOpen then
              c := PermutationCount(frames[top].Options,
                                    frames[top].MinSize, frames[top].MaxSize)
            else
            begin
              c := 0;
              for k := 0 to High(frames[top].Options) do
                c := AddSat(c, frames[top].Options[k]);
            end;
            Dec(top);
            SetLength(frames, top + 1);
            Into(c);
          end;
        sptVariable:
          begin
            name_ := t.Text;
            name_ := StringReplace(name_, '%', '', [rfReplaceAll]);
            if name_ <> '' then
            begin
              c := MacroCount(Defs, name_, Ctx, Exact, totalHere^, Depth, Seen, Stack,
                              defsHere, isDef);
              if isDef then
              begin
                { Once for the whole render, and into the DOCUMENT's product rather than this
                  option's -- the engine rolls it before the body either way. }
                if defsHere.IndexOf(name_) < 0 then
                begin
                  defsHere.Add(name_);
                  totalHere^ := MulSat(totalHere^, c);
                end;
              end
              else
                Into(c);
            end;
          end;
        sptString:
          begin
            { The `#include` target, quotes included. }
            Inc(tokenIncludes);
            target := t.Text;
            if (Length(target) >= 2) and (target[1] = '"') then
              target := Copy(target, 2, Length(target) - 2);
            if trustIncludes and (Ctx.Templates <> nil) and (target <> '') and
               (Seen.IndexOf(target) < 0) and Ctx.Templates.TryGetValue(target, text_) then
            begin
              Seen.Add(target);
              (* A child scope: the fragment's own prelude, its OWN `#def` rolls, and nothing
                 of this document's -- CountText owns a scope whenever it is handed no table. *)
              Into(CountText(text_, Ctx, nil, Exact, ownTotal, Depth + 1, Seen, Stack,
                             defsHere));
              Seen.Delete(Seen.IndexOf(target));
            end
            else
              { An unknown target renders empty -- one text, and the answer becomes a bound
                because a set that gains the fragment would produce more. }
              Exact := False;
          end;
      end;
    end;

    { An unclosed construct is a template the engine will refuse anyway; count what was read
      rather than throwing away the whole answer. }
    while top >= 0 do
    begin
      c := frames[top].Current;
      Dec(top);
      SetLength(frames, top + 1);
      Into(c);
      Exact := False;
    end;
    (* AN UNTERMINATED `/#` IS TEXT TO THE ENGINE AND A COMMENT TO THE SCANNER, and that is
       not an edge case -- it is the state of the document for every keystroke between typing
       `/#` and typing `#/`. The engine changed here in v0.5.0 (the charter records it): the
       rest of the document used to be swallowed and is now ordinary text. The scanner still
       swallows it, so everything below the caret vanished from the count and the panel said
       so exactly. The scan's own final state says when this happened. *)
    if openComment then Exact := False;

    (* AND AN `#include` CAN RESOLVE WITHOUT BEING A DIRECTIVE IN THE SOURCE. `ResolveIncludes`
       runs over the RENDERED text (`Spintax.pas:3194`), so `{pp|#include "f"}` resolves when
       that option is the one drawn -- the engine reports no directive, the scanner sees plain
       text, the two agree, and both are looking at the wrong thing. Nothing short of rendering
       can settle it, so what is detected is the possibility: body text carrying the word. A
       commented-out `#include` is a COMMENT token and does not trip this, which is the case
       that rules out a plain textual search over the document. *)
    if looseInclude then Exact := False;

    { And a permutation whose config the line-at-a-time scan could not finish reading. }
    if openConfig then Exact := False;

    (* WHAT THE SCANNER CANNOT SEE, ADMITTED RATHER THAN GUESSED.

       The token scan is a presentation scan and it does not recognise an `#include` whose
       target sits on the NEXT line -- its own header says so. The engine does: the directive
       split across two lines resolves, and the counter walked straight past the fragment and
       still called the answer exact (2 where the engine makes 6). Rather than grow a second
       rule about where a target may sit -- the thing this file exists not to do -- the two
       are COUNTED and compared. They disagree, something is being included that was not
       counted, and the number becomes a floor. Which holds for every future divergence as
       well, not only this one. *)
    if tokenIncludes <> engineIncludes then Exact := False;

    { Every `#def` THIS scope referenced, once each: the engine rolls them before this
      document's body, and an included fragment is its own document. }
    if ownScope then Result := MulSat(Result, ownTotal);
  finally
    tokens.Free;
    ownDefsUsed.Free;
    owned.Free;
    dirs.Free;
  end;
end;

function SpxCountVariants(const Doc: string; const Ctx: TSpxContext): TSpxCount;
var seen, stack, defs: TStringList; defTotal: Int64;
begin
  Result.Exact := True;
  Result.Saturated := False;
  seen := TStringList.Create;
  stack := TStringList.Create;
  defs := TStringList.Create;
  defTotal := 1;
  try
    seen.CaseSensitive := True;      { include targets are compared exactly -- engine v0.2.2 }
    stack.CaseSensitive := False;    { macro names are keyed lower-cased by the engine }
    defs.CaseSensitive := False;
    { The `#def` product belongs to a document SCOPE and CountText owns one, so these two are
      placeholders the top-level call never reads. }
    Result.Value := CountText(Doc, Ctx, nil, Result.Exact, defTotal, 0, seen, stack, defs);
  finally
    defs.Free;
    stack.Free;
    seen.Free;
  end;
  if Result.Value >= SPX_COUNT_CEILING then
  begin
    Result.Value := SPX_COUNT_CEILING;
    Result.Saturated := True;
  end;
  if Result.Value < 1 then Result.Value := 1;
end;

end.
