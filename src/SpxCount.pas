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
 * marked as a LOWER BOUND instead. Since engine v0.10.0 a value can also REMOVE texts -- a
 * permutation element the input blanks is dropped (`[{?f?|xx}|aa|bb]` makes 6 texts unset
 * and 2 set, measured) -- so the floor is taken with every input-decided element left out.
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
    (* DOES THIS TOKEN PUT ANYTHING IN THE OPTION IT SITS IN? A permutation option whose text
       trims empty is DROPPED by the engine, never rendered and never counted
       (`Spintax.pas/PhpTrim`: `trimmed := PhpTrim(part); if trimmed <> '' then ... Add`).
       So `[a||b]` is two options and two texts, where this walk counted three and reported
       six -- as exact.

       One bit rather than the option's characters, for the reason the Text field above is
       restricted: a 100 KB document must not be copied to answer it. Comments are not ink
       because `StripComments` has already run when the engine trims; a trailing `<...>` is
       not ink because `extractTrailingSep` lifts it out of the part BEFORE the trim, which is
       why `[a|<b>|c]` is two options and not three.

       Nor is the option's own PUNCTUATION ink -- the `|` that ends it or the `]` that ends
       the last one. Counting those was the first version of this, and it marked every empty
       option non-empty a moment before it was closed, so the fix did nothing at all and the
       measurement said so. *)
    HasInk: Boolean;
    { Synthesised beside a `[` whose config this walk could not read -- see the tell in
      TokeniseAll. The permutation then contributes 1, because an unread config moves the
      answer in BOTH directions: `maxsize=1` over three options is 3 where the plain reading
      is 6, and `minsize=2` is 12. }
    UnknownConfig: Boolean;
    { Made by this file rather than read from the document -- see the plural tell. }
    Synthetic: Boolean;
    { Which LINE this token came from, so a frame can tell whether an option was read on the
      line its own `[` opened. See TFrame.Suspect. }
    Line: Integer;
    (* THE WHOLE TOKEN IS `<...>`, so the engine may be lifting it out of the option as a
       trailing separator where this scan handed it over as ordinary text.

       `SpxTokens` only recognises a trailing separator while its permutation frame is open,
       and those frames are LINE-LOCAL by design -- the unit header calls that "a missing
       colour, never a wrong one", which was true until a token KIND started deciding a
       COUNT. `[a` LF `|<x>|b]` then kept an option the engine drops: 6, EXACT, against 2. *)
    LooksSep: Boolean;
    { Carries a `:` -- the engine's second condition for a plural head, which may be on a
      later line than the keyword. }
    HasColon: Boolean;
    { A permutation config or a trailing separator carrying a `%name%`: the engine puts the
      value in before it reads either (spec sec.5.13), so the text as written is not what is
      read. }
    HasRef: Boolean;
    { A text run whose first character is `<`: inside a SPLICED value the scanner had no
      bracket in sight, so what it hands over as text may be a separator or a config to the
      engine once the value is in place -- see Walk. }
    StartsAngle: Boolean;
    { ...and names minsize/maxsize before its first `>`: in the config position of a spliced
      value that is a config the engine will read and this walk cannot. }
    HeadSizeKey: Boolean;
    { A config or a separator whose text carries `|`, a brace or a bracket. Inside a HELD
      `#def` that is structure the def's RENDERED text will hand to the splice -- `sep="|"`
      makes the held text a two-way choice -- and this walk, which reads the def's source,
      cannot see it. }
    HasStructure: Boolean;
  end;
  TCTokList = specialize TList<TCTok>;

  { One macro definition, as the engine keeps it. }
  TCMacro = record
    Value: string;
    IsDef: Boolean;
    { For a `#def`, once counted: the source plus everything the count substituted into it,
      which is never less than the RENDERED text the engine charges at every reference. The
      engine charges that render, not the five-byte source of `#def %d% = %big%`. }
    Cost: Int64;
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
    (* A CLOSER OF THE WRONG KIND HAS BEEN SEEN INSIDE THIS FRAME, so the engine has stopped
       splitting its options and so must this walk. `SplitTopLevel` (`Spintax.pas/SplitTopLevel`)
       decrements the brace and bracket counters UNCONDITIONALLY -- they may go negative --
       and splits on `|` only while BOTH are zero. So a `]` inside `{...}` takes the bracket
       counter to -1 and every `|` after it stops being a separator. *)
    Broken: Boolean;
    { This permutation's config was there and unreadable. }
    ConfigUnknown: Boolean;
    { The line this frame's opener was on, and whether an option arrived that the scan could
      not have classified from here -- see TCTok.LooksSep. }
    OpenLine: Integer;
    Suspect: Boolean;
    { A `plural ` keyword was seen right after the brace, and whether the colon the engine also
      requires turned up anywhere inside. }
    MaybePlural, SawColon: Boolean;
    (* HOW MANY OF THE OPTION'S WAYS RENDER EMPTY, kept beside the ways themselves. A
       permutation drops an element that renders empty -- since engine v0.10.0 that is decided
       on the RENDERED text, so an option holding `{pp|}` is an element half the time -- while
       an enumeration keeps its empties, and an enumeration of two empties really is three.
       `Empties[k]` is this for the closed options, `CurrentEmpty` for the one being read: 1
       for an option nothing has been put into, 0 the moment ink arrives, and a product of the
       parts' own figures in between (see Absorb). Star-parens: braces above. *)
    Empties: array of Int64;
    CurrentEmpty: Int64;
    { Whether EVERY way of the option renders empty -- carried as a flag rather than read off
      `Empties = Options`, because both are saturating products: an option of twenty-six
      constructs saturates both to the ceiling and would read as "never an element". Review
      built that template; it counted one, exact, for 4^26 variants. }
    AllEmpty: array of Boolean;
    CurrentAllEmpty: Boolean;
    { Whether the option may render empty on the INPUT's say-so rather than by chance -- a
      conditional, a plural, an unresolved include -- or on a draw this arithmetic cannot
      separate (a held `#def`). Such an element is left out of a permutation's floor. }
    InputEmpty: array of Boolean;
    CurrentInputEmpty: Boolean;
    { Opened while walking a `#def` value spliced into a construct: its text is one draw
      already made, so the construct is worth one here (see Splice). }
    Held: Boolean;
    { The conditional's head as written -- `?name?` or `?!name?` -- so the close can ask
      which branch the session and the document's own definitions select. }
    CondHead: string;
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

   `Spintax.pas/PermMin`, and the four branches are NOT symmetric -- which is exactly what a
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
  fact: Int64;
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

  (* ▁▁▁ TWO EXITS BEFORE THE ARITHMETIC, BOTH EXACT ▁▁▁

     This ran to completion however large the permutation was, and the recurrence below is
     O(n * max). Measured on 50 000 options -- a 100 KB document of one list -- it took
     **56 seconds**, every one of them on TSpxEngineThread AFTER the render, so it blocked
     every following preview for that long while returning the same saturated ceiling it
     could have returned at once.

     FIRST: every count is at least 1, so e_k >= C(n, k) >= 1 for any k <= n. The answer
     includes k!*e_k for k = max_, and 15! = 1 307 674 368 000 is already past the ceiling
     (14! is not: 87 178 291 200). So a permutation allowed to take fifteen or more options
     IS saturated, whatever the counts are, and no arithmetic can say otherwise.

     SECOND: nothing above e_max_ is ever read, so the inner loop stops there instead of at n.
     That is what makes a big permutation with a small `maxsize` linear rather than quadratic.

     Neither is an estimate -- both drop terms that provably cannot change the answer. *)
  if max_ >= 15 then Exit(SPX_COUNT_CEILING);

  SetLength(e, max_ + 1);
  e[0] := 1;
  for i := 1 to max_ do e[i] := 0;
  for i := 0 to n - 1 do
  begin
    { e_k is still 0 for every k above the number of options read so far, so the full range
      is wasted work: 3 000 options measured 101 ms before this line, which is the quadratic
      term and not the arithmetic. }
    k := i + 1;
    if k > max_ then k := max_;
    for k := k downto 1 do
      e[k] := AddSat(e[k], MulSat(e[k - 1], Counts[i]));
  end;

  { The factorial is carried rather than rebuilt per term -- FactSat(k) walked 2..k again for
    every k, which is the same quadratic shape one loop later. }
  Result := 0;
  fact := FactSat(min_);
  for k := min_ to max_ do
  begin
    if k > min_ then fact := MulSat(fact, k);
    Result := AddSat(Result, MulSat(fact, e[k]));
  end;
  {$IFDEF SPX_COUNT_TRACE}
  Write('  PERM n=', n, ' min=', min_, ' max=', max_, ' counts=');
  for i := 0 to n - 1 do Write(Counts[i], ' ');
  WriteLn('-> ', Result);
  {$ENDIF}
  if Result < 1 then Result := 1;
end;

(* THE SAME ARITHMETIC WHEN AN ELEMENT MAY NOT BE THERE.

   Since engine v0.10.0 (spec sec.5.13) a permutation element is its RENDERED text, trimmed,
   and one that renders empty is no element: dropped with the separator it carried, before the
   size pick and before the shuffle. So `[{pp|}|aa]` is not 2 * 2! = 4 -- when the choice
   lands on its blank option there is ONE element and one ordering. Three texts, and this
   walk said four, exact. Measured at the v0.10.1 pin, with a dozen shapes beside it.

   `Ns[i]` is the number of ways element i renders NON-empty and `Es[i]` the ways it renders
   empty; an element with no empty way is the ordinary case and the sum below collapses to
   PermutationCount. Otherwise, with no config, every element that rendered is shown, so the
   size is the number that did, and the ways split by that number are the coefficients of

       Π (Es[i] + Ns[i]·z)

   -- W[m] is the number of ways exactly m elements are non-empty -- and the answer is
   Σ W[m]·m!. That is exact, and it is what the enumeration confirms.

   WITH a config the size range clamps on what remains, so the texts of two outcomes overlap
   (`[<maxsize=1>{pp|}|aa]` prints `aa` whether or not `pp` is there) and a sum would count
   the same text twice -- which breaks the floor, the one promise this unit makes. So a config
   over elements that may vanish answers with the LARGEST single outcome, every element there
   or every uncertain one gone, and says it is a bound. *)
function PermutationCountWithEmpties(const Ns, Es: array of Int64; AMin, AMax: Integer;
  var Exact: Boolean): Int64;
var
  n, i, m, k: Integer;
  w: array of Int64;
  sure: array of Int64;
  fact, alt: Int64;
  anyEmpty: Boolean;
begin
  n := Length(Ns);
  anyEmpty := False;
  for i := 0 to n - 1 do
    if Es[i] > 0 then anyEmpty := True;
  if not anyEmpty then Exit(PermutationCount(Ns, AMin, AMax));

  if (AMin < 0) and (AMax < 0) then
  begin
    { The term with every element present is n!·ΠNs, and 15! is past the ceiling on its
      own -- the same exit PermutationCount takes, for the same reason. }
    if n >= 15 then Exit(SPX_COUNT_CEILING);
    SetLength(w, n + 1);
    w[0] := 1;
    for m := 1 to n do w[m] := 0;
    for i := 0 to n - 1 do
    begin
      for m := i + 1 downto 1 do
        w[m] := AddSat(MulSat(w[m], Es[i]), MulSat(w[m - 1], Ns[i]));
      w[0] := MulSat(w[0], Es[i]);
    end;
    Result := 0;
    fact := 1;
    for m := 0 to n do
    begin
      if m > 1 then fact := MulSat(fact, m);
      Result := AddSat(Result, MulSat(w[m], fact));
    end;
    if Result < 1 then Result := 1;
    Exit;
  end;

  Exact := False;
  k := 0;
  SetLength(sure, n);
  for i := 0 to n - 1 do
    if Es[i] = 0 then
    begin
      sure[k] := Ns[i];
      Inc(k);
    end;
  SetLength(sure, k);
  Result := PermutationCount(sure, AMin, AMax);
  alt := PermutationCount(Ns, AMin, AMax);
  if alt > Result then Result := alt;
end;

(* THE PERMUTATION CONFIG, AND WHETHER IT IS ONE AT ALL.

   `<...>` right after `[` is always the config TOKEN -- the engine consumes it either way, and
   the scanner is right to paint it -- but its CONTENT is read as key/value only when a key is
   really there. Otherwise the whole thing is the separator and the permutation prints every
   option. Two engine functions, and this file used to mirror only the second:

     HasConfigKey (`Spintax.pas/HasConfigKey`) -- one of minsize / maxsize / sep / lastsep, at a WORD
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
   (`Spintax.pas/ExtractDirectives`) keeps `#set` and `#def` in separate maps, each `AddOrSetValue` so the
   LAST definition of a name wins; the render then lays the definitions over the sets
   (`3145-3184`), so a `#def` beats a `#set` of the same name however they are ordered in the
   text. Taking the FIRST match out of a flat list -- which is what this did before -- answered
   2 for a document that redefines its macro and renders 3. Redefinition is not exotic: it is
   the first question a reader of this project ever asked. *)
function BuildMacros(Dirs: TSpDirectiveList): TCMacros;
var i: Integer; m: TCMacro;
begin
  Result := TCMacros.Create;
  { Whole, not member by member: `Cost` is read only after MacroCount has set it, but a field
    left to the stack is the shape `UnknownConfig` once arrived in -- as garbage. }
  m := Default(TCMacro);
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
{ Whether S carries a `%name%` reference -- the engine's `%(\w+)%`, not a bare percent sign:
  `<50% off>` is a separator with a percent in it and nothing to resolve. }
function HasNameRef(const S: string): Boolean;
var p, q: Integer;
begin
  p := Pos('%', S);
  while p > 0 do
  begin
    q := p + 1;
    while (q <= Length(S)) and (S[q] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(q);
    if (q <= Length(S)) and (S[q] = '%') and (q > p + 1) then Exit(True);
    p := PosEx('%', S, p + 1);
  end;
  Result := False;
end;

{ Whether a text run that opens with `<` names a SIZE key before its first `>` -- the one thing
  a config can do to a count. A separator or an HTML tag in the same place leaves it alone. }
function HeadHasSizeKey(const S: string): Boolean;
var head: string; gt: Integer;
begin
  gt := Pos('>', S);
  if gt > 0 then head := LowerCase(Copy(S, 1, gt)) else head := LowerCase(S);
  Result := (Pos('minsize', head) > 0) or (Pos('maxsize', head) > 0);
end;

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
  lastCloserLine, bracketLine, braceLine: Integer;
  head: TCTok;
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
  bracketLine := -1;
  braceLine := -1;
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
    { Whether a `/#` opens a comment depends on a `#/` the line cannot see; the whole document
      is right here, so answer it exactly. Masked lines, not the raw ones: a `#/` inside a
      directive's span is not one the body's scan may close on. }
    lastCloserLine := SpxLastCloserLine(lines);
    for i := 0 to lines.Count - 1 do
    begin
      masked := lines[i];
      line.Clear;
      SpxScanLine(masked, state, line, i < lastCloserLine);
      { One Pos over the rare line that mentions the word at all -- see ALooseInclude below. }
      lineHasInclude := Pos('#include', masked) > 0;
      for j := 0 to line.Count - 1 do
      begin
        { Fresh each time: the record is reused across the loop, and a field that is only
          assigned on some paths otherwise carries the previous token's value -- which is how
          `UnknownConfig` first arrived as garbage and turned every same-line permutation into
          a floor of 1. }
        t := Default(TCTok);
        t.Kind := line[j].Kind;
        { Ink: see TCTok.HasInk. Only what is CERTAIN to leave characters in the option: a
          text run that is not all blank, a directive keyword, an include target. Not an
          opener -- the construct it opens may render empty, and says so at its close -- not
          a `%name%`, whose value decides (Splice), and not the two kinds the engine lifts
          out of a part before trimming it. }
        t.HasInk := t.Kind in [sptText, sptDirective, sptString];
        t.Line := i;
        if t.Kind = sptText then
        begin
          slice := Trim(Copy(masked, line[j].Start, line[j].Length));
          t.HasInk := slice <> '';
          { A whole `<...>`: the engine's per-element separator runs from `<` to the FIRST
            `>`, so a run whose first `>` is its last character is one separator and nothing
            else -- and `<a href="x">one</a>`, which also opens with `<` and ends with `>`, is
            not (its separator is the `</a>`, and `<a href="x">one` stays). }
          t.LooksSep := (Length(slice) >= 2) and (slice[1] = '<') and
                        (Pos('>', slice) = Length(slice));
          t.StartsAngle := (slice <> '') and (slice[1] = '<');
          if t.StartsAngle then t.HeadSizeKey := HeadHasSizeKey(slice);
          t.HasColon := Pos(':', slice) > 0;
        end;
        if t.Kind in [sptPermConfig, sptTrailingSep] then
        begin
          slice := Copy(masked, line[j].Start, line[j].Length);
          t.HasRef := HasNameRef(slice);
          t.HasStructure := (Pos('|', slice) > 0) or (Pos('{', slice) > 0) or
                            (Pos('}', slice) > 0) or (Pos('[', slice) > 0) or
                            (Pos(']', slice) > 0);
        end;
        { Only the kinds whose characters are read later; see TCTok. }
        if t.Kind in [sptVariable, sptString, sptPermConfig, sptCondHead, sptTrailingSep] then
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

            (* AND A CONFIG THAT BEGINS ON THE LINE AFTER THE `[`, which is a whole config and
               not a cut-off one, so the tell above never fires. The engine reaches it because
               `ParsePermConfig` runs `PhpLtrim` first and `PHP_WS` contains #10
               (`Spintax.pas/PHP_WS`, `Spintax.pas/PhpLtrim`) -- the newline is simply blank space before
               `<`. The scanner will not follow a config across a line and says so.

               Restricted to a DIFFERENT line on purpose. Same-line text beginning with `<`
               that the scanner declined -- `[<b>bold|x]` -- is markup the engine declines
               too, and the two already agree; widening this to every `<` would turn those
               into floors for nothing. *)
            if (bracketLine >= 0) and (i <> bracketLine) and
               (Copy(TrimLeft(slice), 1, 1) = '<') then
            begin
              AOpenConfig := True;
              head := Default(TCTok);
              head.Kind := sptPermConfig;
              head.UnknownConfig := True;
              Tokens.Add(head);
            end;
          end;
          (* A `{plural ...}` WHOSE HEAD THE SCANNER COULD NOT READ. `PluralHeadLength` wants
             the keyword and its `:` on one line with no `|` or `}` in between; the engine's
             gate is `Copy(content,1,7) = 'plural '` and a `:` ANYWHERE in the rest
             (`Spintax.pas/PLURAL_PREFIX`). So `{plural 2` LF `: one|many}` and
             `{plural 2|3: one|many}` are plurals to the engine -- one variant each, since a
             plural picks a form rather than offering a choice -- and arrived here as free
             choices worth 2 and 3, as exact.

             A synthetic head token rather than a new rule: the walk already knows what to do
             with one, including making the answer a floor. Requiring the trailing space is
             what keeps `{plural|other}` an ordinary two-way choice, which is what it is. *)
          (* SAME LINE AS THE BRACE. `prevKind` survives a line break, so `{` LF
             `plural 2: one|many}` fired this -- but the engine's gate is
             `Copy(content,1,7) = 'plural '` and that content STARTS WITH THE LF, so it is an
             ordinary choice of two and this reported "at least 1".

             The engine's SECOND condition -- a `:` anywhere after the keyword
             (`Spintax.pas/PLURAL_PREFIX`) -- is decided in the walk, not here: it may sit on a
             later line, and requiring it on THIS one broke the floor for
             `{plural 2` LF `: one|many}`, which the engine reads as a plural worth one. The
             suite caught that within the run. *)
          if (prevKind = sptBraceOpen) and (t.Kind = sptText) and (i = braceLine) and
             (Copy(masked, line[j].Start, 7) = 'plural ') then
          begin
            head := Default(TCTok);
            head.Kind := sptPluralHead;
            head.Synthetic := True;
            head.Line := i;
            Tokens.Add(head);
          end;
        end;
        (* WHAT COUNTS AS "THE TOKEN AFTER THE BRACKET". Blank and comments do NOT: the engine
           ltrims before parsing a config (`PhpLtrim`, `Spintax.pas/PhpLtrim`) and has already
           stripped comments, so `[ ` LF `<maxsize=1>a|b|c]` is a config to it. One space after
           the `[` used to consume this position and the next-line tell never ran -- 6, EXACT,
           against the engine's 3, which breaks the floor. Found by review. *)
        if not ((t.Kind = sptComment) or ((t.Kind = sptText) and not t.HasInk)) then
          prevKind := t.Kind;
        if t.Kind = sptBracketOpen then bracketLine := i;
        if t.Kind = sptBraceOpen then braceLine := i;
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
{ Whether a value can contribute anything to a count or fan anything out. Mirrors the engine's
  own HasConstructChar (`Spintax.pas/HasConstructChar`), and it is here for the same reason the
  engine has it: a value carrying no construct is substituted once and never expanded again, so
  it cannot be part of an explosion and must not be charged for one.

  Review measured what charging it costs: a plain `#set %x% = x` referenced 16322 times is an
  ordinary 65 KB template whose count is exactly one, and a flat per-expansion price turned it
  into a lower bound. The flat price was measured on the INCLUDE tree and applied to every path
  without asking what it was paying for. }
function CountsForBudget(const S: string): Boolean;
var i: Integer;
begin
  for i := 1 to Length(S) do
    if (S[i] = '{') or (S[i] = '[') or (S[i] = '%') then Exit(True);
  Result := False;
end;

{ THE BUDGET ONE COUNT MAY SPEND, in characters the walk is made to read AGAIN.

  `Stack` stops a macro that expands itself, the depth cap stops a long chain, and the include
  `Seen` list stops a cycle. None of the three bounds an ACYCLIC FAN OUT, where no name repeats
  on any path and no path is deep, yet the work is the product of the widths. Two were measured
  here at the v0.7.0 bump: a 2624 byte document of nested macros took 19156 ms, and twelve
  fragments each including the next ten times did not finish in 60 s. Both on the worker thread
  the window is waiting on.

  CHARACTERS, NOT CALLS: charging per call left the macro case at 15867 ms, because 40000
  expansions are cheap and 40000 expansions of a 1000 character value are not. Plus a flat cost
  per expansion, because a call also tokenizes, extracts directives and builds two lists, and
  charging the text alone left the WIDE include tree at 5613 ms. Both numbers are measurements
  of a fix that looked finished before them.

  Running out is not an error and enters no new answer into the language: the count stops
  expanding, keeps what it has and drops `Exact`, which the window already renders as a lower
  bound. Same shape as the engine's own render budget, which leaves a reference literal. }
const
  SPX_COUNT_STEPS = 4 * 1024 * 1024;
  { An expansion is not free even when its text is short: each one tokenizes, extracts the
    fragment's directives and builds two lists. Charging the text alone under-priced a WIDE
    tree -- twelve fragments each including the next ten times went from a hang past 60 s to
    5613 ms, which is termination and not an answer anyone waits for. Priced at 256 characters
    a call, measured rather than reasoned. }
  SPX_COUNT_CALL_COST = 256;

(* THE HOST'S TABLE IS KEYED AS THE AUTHOR TYPED THE NAME -- the window hands `OwnLang` over
   as `OwnLang` (SpxEngineThread copies `Vars[i].Name` verbatim) -- and the engine folds every
   key through LowerAscii before it overlays them (`Spintax.pas/RenderCompiled`). This unit
   looked the lower-cased name up in the un-folded table, so a session value whose name had a
   capital in it was never found here and counted as one, while the engine rolled it. Found
   at the v0.10.1 pin by a probe that happened to name its variable `L`.

   The table this reads is the FOLDED copy SpxCountVariants makes once per count, so a lookup
   stays one hash probe. The first fix fell through to a linear scan of the table for every
   name that was NOT a session value -- every `#set` name, every undefined one -- which at the
   GSA scale the charter measures (16 000 session values) was seconds per keystroke on the
   engine worker; review timed it, the suite could not see it because its counts hand over an
   empty table. *)
function HostValue(const Ctx: TSpxContext; const Name: string; out Value: string): Boolean;
begin
  Result := (Ctx.Vars <> nil) and Ctx.Vars.TryGetValue(LowerCase(Name), Value);
end;

function CountText(const Doc: string; const Ctx: TSpxContext; Defs: TCMacros;
  var Exact: Boolean; var Steps: Integer; var Purse: Int64; var DefTotal: Int64;
  Depth: Integer; Seen, Stack, DefsUsed: TStringList): Int64; forward;

{ 0 = the then-branch is taken, 1 = the else-branch, -1 = cannot be decided here. }
function CondBranchFor(const Head: string; const Ctx: TSpxContext; Defs: TCMacros): Integer;
var
  nm, val: string;
  inverted, found, truthy, decided: Boolean;
  mac: TCMacro;
  i: Integer;
begin
  Result := -1;
  nm := Head;
  if Copy(nm, 1, 1) = '?' then Delete(nm, 1, 1);
  inverted := Copy(nm, 1, 1) = '!';
  if inverted then Delete(nm, 1, 1);
  i := Pos('?', nm);
  if i > 0 then nm := Copy(nm, 1, i - 1);
  if nm = '' then Exit;
  found := HostValue(Ctx, nm, val);
  if (not found) and (Defs <> nil) and Defs.TryGetValue(LowerCase(nm), mac) then
  begin
    { The table holds a `#def` RENDERED, and a def that renders may render blank. }
    if mac.IsDef and CountsForBudget(mac.Value) then Exit;
    found := True;
    val := mac.Value;
  end;
  decided := True;
  truthy := False;
  if found then
  begin
    { An ASCII character above the space is outside every space class: truthy for sure. A
      value with nothing above the space at all is falsy for sure. Anything else -- only
      non-ASCII bytes beside blanks -- could be NBSP through and through, and is not
      decided here. }
    { PCRE2's blanks within ASCII are #9..#13 and the space; a control byte such as #1 is
      a character and makes the value truthy, which the first cut read as a blank. }
    decided := False;
    for i := 1 to Length(val) do
      if (val[i] < #128) and (not (val[i] in [#9, #10, #11, #12, #13, ' '])) then
      begin
        truthy := True;
        decided := True;
        Break;
      end;
    if not decided then
    begin
      decided := True;
      for i := 1 to Length(val) do
        if val[i] >= #128 then begin decided := False; Break; end;
    end;
  end;
  if not decided then Exit;
  if inverted then truthy := not truthy;
  if truthy then Result := 0 else Result := 1;
end;

(* THE ENGINE'S OWN BUDGET, MIRRORED. Every substitution the engine makes is charged against
   SP_RENDER_EXPANSION_BUDGET (`Spintax.pas/TakeBudget`), and once the purse is empty a
   reference stays LITERAL -- one way, not a choice. A counter that goes on expanding past
   that point answers more than the engine will ever produce: three and a half thousand
   references to a 300-byte `a|b` value inside one choice, and every one counted as two.
   Codex review found it. So a second purse rides beside `Steps` (which bounds this WALK's
   own work and is a different thing): charged in bytes the way the engine charges in
   units, which is never less, so this walk stops no later than the engine does and what it
   leaves literal the engine leaves literal too -- the floor holds, and Exact goes. Refused
   on an EMPTY purse, as the engine refuses, not on one the next value would overdraw. *)
const
  { The engine's `Spintax.pas/SP_RENDER_EXPANSION_BUDGET`, which its interface does not export:
    one mebibyte of substituted text per render. }
  SPX_ENGINE_EXPANSION_BUDGET = Int64(1024) * 1024;

function TakePurse(var Purse: Int64; const Value: string): Boolean;
begin
  if Purse <= 0 then Exit(False);
  Dec(Purse, Length(Value));
  Result := True;
end;

function TakePurseCost(var Purse: Int64; Cost: Int64): Boolean;
begin
  if Purse <= 0 then Exit(False);
  Dec(Purse, Cost);
  Result := True;
end;

(* A MACRO'S OWN COUNT, and WHOSE value it is.

   ---- A HOST VALUE OUTRANKS THE DOCUMENT. Measured, then confirmed in the engine's source:
   SpRender builds its table from the `#set` definitions and then overlays the runtime vars on
   top (`Spintax.pas/RenderCompiled`), and a `#def` whose name a runtime var carries is never rolled
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
   (`Spintax.pas/OrderDefinitions`, rolled by `Spintax.pas/RenderCompiled`). So it multiplies the
   DOCUMENT once, not the option it happens to
   be written in -- which is why its bookkeeping is a shared list and a shared product rather
   than anything held per construct. The version that multiplied it into the enclosing option
   answered 3 for a `#def` used in both alternatives of one choice: neither the four draws
   there are, nor the two texts that come out. *)
function MacroCount(Model: TCMacros; const Name: string; const Ctx: TSpxContext;
  var Exact: Boolean; var Steps: Integer; var Purse: Int64; var DefTotal: Int64;
  Depth: Integer; Seen, Stack, DefsUsed: TStringList; out IsDef: Boolean): Int64;
var hostVal: string; mac: TCMacro; purseBefore: Int64;
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
  { The engine stops expanding at MAX_VARIABLE_DEPTH = 50 (`Spintax.pas/MAX_VARIABLE_DEPTH`) and renders the
    unexpanded `%name%` as text. `Stack` IS that depth -- it holds exactly the macros being
    expanded right now -- so the guard costs nothing extra. }
  if Stack.Count >= 50 then
  begin
    Exact := False;
    Exit;
  end;

  (* ▁▁▁ AND A BUDGET, BECAUSE NEITHER GUARD ABOVE BOUNDS THE WORK ▁▁▁

     `Stack` stops a name that expands ITSELF and the depth cap stops a long chain. An ACYCLIC
     FAN OUT is neither: with `#set %b%` holding 200 choices, `#set %a%` naming %b% 200 times
     and a body naming %a% 200 times, no name ever repeats on a path and no path is deep, yet
     every occurrence recounts its value from scratch. Measured on a 2624 byte document: 19156
     ms, on the worker thread the window is waiting for, and it grows as the product of the
     three counts. Found by review at the v0.7.0 bump; it predates the bump, and it is the same
     shape the engine bounded on its own side that release, from the other direction.

     CHARGED IN CHARACTERS RE-WALKED, NOT IN CALLS, and the first cut got that wrong: a call
     counter left the same document at 15867 ms, because 40000 expansions is cheap and 40000
     expansions of a 1000 character value is not. The price of an expansion is the text it
     makes this walk read again, which is what the budget below buys, and it is the same unit
     the engine chose for the same reason.

     The refusal is the one this function already has -- count one, drop Exact -- so it enters
     no new answer into the language, exactly as the engine's budget leaves a reference literal
     rather than inventing an output. A cyclic bomb was measured at 0 ms and is NOT what this
     catches; that one Stack really does stop, which is why it was mistaken for the whole
     defence. *)

  { The host's table first, because the engine reads it last. }
  if HostValue(Ctx, Name, hostVal) then
  begin
    if hostVal = '' then Exit;
    if (Steps <= 0) or (not TakePurse(Purse, hostVal)) then
    begin
      Exact := False;
      Exit;
    end;
    Stack.Add(Name);
    try
      if CountsForBudget(hostVal) then
        Dec(Steps, Length(hostVal) + SPX_COUNT_CALL_COST);
      Result := CountText(hostVal, Ctx, Model, Exact, Steps, Purse, DefTotal, Depth, Seen, Stack, DefsUsed);
    finally
      Stack.Delete(Stack.IndexOf(Name));
    end;
    Exit;
  end;

  if Model = nil then Exit;
  if not Model.TryGetValue(LowerCase(Name), mac) then Exit;
  IsDef := mac.IsDef;
  if mac.Value = '' then Exit;

  { THE BUDGET GUARD SITS HERE, AFTER the lookups above and after the already-rolled test
    below, because refusing work that was never going to be done is how a gate reports a
    finding it did not have: an exhausted budget followed only by a def the caller has already
    multiplied in would have flipped Exact for nothing. Review found the ordering. }

  { A `#def` ALREADY ROLLED IS NOT RECOUNTED. The caller multiplies a def into the document's
    product exactly once and ignores the value it gets for every later reference -- so counting
    it again was work whose answer was thrown away, and once there was a budget it was work that
    could spend the budget and turn an ordinary template's exact count into a lower bound.
    Raised by review; the numeric answer never differed, which is why nothing noticed. }
  { A `#def` is charged HERE, once per reference and before the already-rolled exit, because
    the engine charges the rendered value at each reference and never the source it
    pre-renders; Splice, which calls this for every def it walks, does not charge it again
    -- a 600 KiB definition referenced twice was charged twice and lost Exact on the second.
    Codex review found it. }
  if IsDef and (DefsUsed.IndexOf(Name) >= 0) then
  begin
    { Already rolled: charge what its render is worth (see TCMacro.Cost) and answer one. }
    if not TakePurseCost(Purse, mac.Cost) then Exact := False;
    Exit;
  end;

  if Steps <= 0 then
  begin
    Exact := False;
    Exit;
  end;
  if (not IsDef) and (not TakePurse(Purse, mac.Value)) then
  begin
    Exact := False;
    Exit;
  end;

  Stack.Add(Name);
  purseBefore := Purse;
  try
    if CountsForBudget(mac.Value) then
      Dec(Steps, Length(mac.Value) + SPX_COUNT_CALL_COST);
    Result := CountText(mac.Value, Ctx, Model, Exact, Steps, Purse, DefTotal, Depth, Seen, Stack, DefsUsed);
  finally
    Stack.Delete(Stack.IndexOf(Name));
  end;
  if IsDef then
  begin
    { The pre-render's own substitutions were just charged, once, as the engine charges them;
      the reference itself is worth the render, which is at most the source plus what went
      into it. Remembered for every later reference. }
    mac.Cost := (purseBefore - Purse) + Length(mac.Value);
    if mac.Cost < 1 then mac.Cost := 1;
    Model.AddOrSetValue(LowerCase(Name), mac);
    if not TakePurseCost(Purse, mac.Cost) then Exact := False;
  end;
end;

function CountText(const Doc: string; const Ctx: TSpxContext; Defs: TCMacros;
  var Exact: Boolean; var Steps: Integer; var Purse: Int64; var DefTotal: Int64;
  Depth: Integer; Seen, Stack, DefsUsed: TStringList): Int64;
var
  tokens: TCTokList;
  frames: array of TFrame;
  top, i: Integer;
  owned: TCMacros;
  dirs: TSpDirectiveList;
  engineIncludes, tokenIncludes: Integer;
  openComment, looseInclude, openConfig, trustIncludes, ownScope: Boolean;
  ownDefsUsed, defsHere: TStringList;
  ownTotal, c: Int64;
  totalHere: PInt64;
  { The top of the frame stack when the current Splice began: frames at or below it were
    opened by the DOCUMENT and are resolved before the value lands (a pipe from the value is
    not their branch); frames above it were opened by the value's own text and are ordinary
    constructs, pipes included. -1 outside any splice. }
  spliceBase: Integer;

  { Record the option just read -- its ways, how many of them render empty, whether the
    input decides that, and whether EVERY way is empty (the flag, not `n = e` -- see
    TFrame.AllEmpty). A permutation option with nothing in it used to be skipped HERE; it is
    kept now and dropped at the close by that flag. }
  procedure CloseOption;
  var m: Integer;
  begin
    m := Length(frames[top].Options);
    SetLength(frames[top].Options, m + 1);
    SetLength(frames[top].Empties, m + 1);
    SetLength(frames[top].InputEmpty, m + 1);
    SetLength(frames[top].AllEmpty, m + 1);
    frames[top].Options[m] := frames[top].Current;
    { Both are saturating products, and a saturated empty count must not outrun the ways. }
    if frames[top].CurrentEmpty > frames[top].Current then
      frames[top].CurrentEmpty := frames[top].Current;
    frames[top].Empties[m] := frames[top].CurrentEmpty;
    frames[top].InputEmpty[m] := frames[top].CurrentInputEmpty;
    frames[top].AllEmpty[m] := frames[top].CurrentAllEmpty;
  end;

  procedure Push(AKind: TSpxTokenKind; AFree: Boolean; ALine: Integer; AHeld: Boolean);
  begin
    Inc(top);
    SetLength(frames, top + 1);
    frames[top] := Default(TFrame);
    frames[top].Kind := AKind;
    frames[top].Free := AFree;
    frames[top].OpenLine := ALine;
    frames[top].Held := AHeld;
    frames[top].Current := 1;
    frames[top].CurrentEmpty := 1;
    frames[top].CurrentAllEmpty := True;
    frames[top].MinSize := -1;
    frames[top].MaxSize := -1;
  end;

  { Fold a part into whatever is being read -- an option of an open construct, or the
    document. A part with N ways of which E render empty: the option is empty only when
    every part of it is, so the empties MULTIPLY like the ways do, and a part the input may
    blank makes the whole option one the input may blank. }
  procedure Absorb(N, E: Int64; IE, AE: Boolean);
  begin
    if top >= 0 then
    begin
      frames[top].Current := MulSat(frames[top].Current, N);
      frames[top].CurrentEmpty := MulSat(frames[top].CurrentEmpty, E);
      if IE then frames[top].CurrentInputEmpty := True;
      if not AE then frames[top].CurrentAllEmpty := False;
    end
    else
      Result := MulSat(Result, N);
  end;

  { Whether ANY open frame is a permutation -- an `#include` line inside a choice inside a
    shuffle is joined to the other elements on one line just the same (the element's rendered
    text is trimmed before the join, sec.5.13). The first cut asked the top frame only. }
  function InsideBracket: Boolean;
  var k: Integer;
  begin
    for k := 0 to top do
      if frames[k].Kind = sptBracketOpen then Exit(True);
    Result := False;
  end;

  { Characters that will be in the output whatever is drawn: the option can no longer
    render empty. }
  procedure Ink;
  begin
    if top >= 0 then
    begin
      frames[top].CurrentEmpty := 0;
      frames[top].CurrentAllEmpty := False;
    end;
  end;

  procedure Walk(List: TCTokList; Held: Boolean; LineOverride: Integer); forward;

  (* A `%name%` WRITTEN INSIDE A CONSTRUCT IS SPLICED IN AS TEXT, before the construct is split
     on `|` -- engine v0.9.0, spec sec.5.9, and the family's rule from the PHP engines on. So
     `#set %x% = aa|bb` with `{%x%}` is a two-way choice, `[%x%|cc]` is three elements, and a
     value that is EMPTY leaves an element that renders empty and is dropped (sec.5.13). The
     counter used to hand the value to MacroCount as a template of its own, which is right at
     top level -- there a `|` is not a separator, measured -- and wrong inside any bracket:
     seventeen shapes answered one where the engine makes two to twelve, every one marked
     EXACT. Measured at the v0.10.1 pin before being believed.

     So inside a frame the value's own tokens are walked in place, as if the reader had typed
     them there. That is what the engine does, and it is why no arithmetic is needed for the
     splice itself: a value carrying a pipe simply arrives as two options. A `#set` and a
     session value are re-rolled at every use, so their constructs count as they stand; a
     `#def` is rolled ONCE and its text held (MacroCount has the reasoning), so its tokens are
     walked HELD -- every construct in them is worth one here -- while the def multiplies the
     document once, exactly as before. The frames opened inside a held walk say so, and a held
     construct that could render empty is a correlated draw this arithmetic cannot separate,
     so it is reported as input-decided rather than counted as chance. *)
  procedure Splice(const AName: string; ALine: Integer; Held: Boolean);
  var
    val, lead: string;
    mac: TCMacro;
    isDef, found, rolled: Boolean;
    c: Int64;
    sub: TCTokList;
    none: TSpDirectiveList;
    inc2, savedBase: Integer;
    oc2, li2, ocf2: Boolean;
  begin
    isDef := False;
    { The host's table first, because the engine reads it last -- see MacroCount. }
    found := HostValue(Ctx, AName, val);
    if (not found) and (Defs <> nil) and Defs.TryGetValue(LowerCase(AName), mac) then
    begin
      found := True;
      val := mac.Value;
      isDef := mac.IsDef;
    end;
    { An undefined name renders as the literal `%name%`: one text, and it is ink. }
    if not found then begin Ink; Exit; end;

    { The engine's own guards, mirrored where MacroCount mirrors them: a name that expands
      itself, and a chain past MAX_VARIABLE_DEPTH, are left as the literal reference. BEFORE
      any bookkeeping: the first cut recorded the def as rolled and then bailed, and let
      MacroCount's cycle exit overwrite `isDef` through its out-parameter, so a def naming
      itself was walked as a `#set`. Review found both. }
    if (Stack.IndexOf(AName) >= 0) or (Stack.Count >= 50) then
    begin
      Exact := False;
      Ink;
      Exit;
    end;

    if isDef then
    begin
      { Once for the whole render, and into the DOCUMENT's product rather than this
        option's -- the engine rolls it before the body either way. }
      c := MacroCount(Defs, AName, Ctx, Exact, Steps, Purse, totalHere^, Depth, Seen, Stack,
                      defsHere, rolled);
      if defsHere.IndexOf(AName) < 0 then
      begin
        defsHere.Add(AName);
        totalHere^ := MulSat(totalHere^, c);
      end;
    end;

    { Charged as MacroCount charges: the text this walk reads again, plus the flat price,
      and only when the value can fan out. A plain value is substituted and never expanded
      again -- charging it turned a 300-character `#set` referenced sixteen thousand times
      into a floor, one brace away from the regression check that pins the top-level case. }
    if CountsForBudget(val) then Dec(Steps, Length(val) + SPX_COUNT_CALL_COST);
    if (Steps <= 0) or ((not isDef) and (not TakePurse(Purse, val))) then
    begin
      Exact := False;
      Ink;
      Exit;
    end;
    { A comment marker in a value is LITERAL to the engine: StripComments ran once over the
      source, and the re-read parses the substituted text without it. The scanner below
      strips, so anything the value hides behind `/#` is walked as a comment -- a floor. }
    if Pos('/#', val) > 0 then
    begin
      Exact := False;
      { ...and a closer, a pipe or an opener behind that marker is structure the engine will
        read and this walk has folded into an ink token -- `/# ] #/` closes the shuffle it
        sits in. Nothing here can place it, so the whole count collapses to one, which is
        what an empty purse does too (see SpxCountVariants). }
      if (Pos(']', val) > 0) or (Pos('}', val) > 0) or (Pos('|', val) > 0) or
         (Pos('[', val) > 0) or (Pos('{', val) > 0) or (Pos('<', val) > 0) or
         (Pos('>', val) > 0) then
        Purse := 0;
    end;

    (* THE VALUE'S FIRST CHARACTERS MAY BE A HEAD THE SCANNER CANNOT SEE FROM INSIDE THE VALUE.
       `{%q%f?aa|bb}` with `q = ?` is a conditional to the engine once the value is in -- the
       shape that bit the GSA converter, spec sec.5.9 -- and `{%x%}` with `x = plural 2: a|b`
       is a plural. Tokenised on its own the value is text, and the construct counted as a
       free choice: 2, exact, where the engine makes one. So a value that opens with a head,
       arriving as the first thing in a brace, makes the frame input-decided -- one, as a
       floor, which is what a plural is and a valid bound for a conditional. *)
    if (top >= 0) and (frames[top].Kind = sptBraceOpen) and frames[top].Free and
       (Length(frames[top].Options) = 0) and (frames[top].Current = 1) and
       frames[top].CurrentAllEmpty then
    begin
      lead := TrimLeft(val);
      if (Copy(lead, 1, 1) = '?') or (Copy(lead, 1, 7) = 'plural ') then
      begin
        frames[top].Free := False;
        frames[top].Cond := False;
        Exact := False;
      end;
    end;

    Stack.Add(AName);
    none := TSpDirectiveList.Create;
    sub := TCTokList.Create;
    savedBase := spliceBase;
    spliceBase := top;
    try
      { No directives: a value has none of its own, and an `#include` inside one is a line
        the engine may resolve AFTER rendering -- the loose-include tell, which the walk
        below turns into a floor. }
      TokeniseAll(val, none, sub, inc2, oc2, li2, ocf2);
      if oc2 or li2 or ocf2 then Exact := False;
      Walk(sub, Held or isDef, ALine);
    finally
      spliceBase := savedBase;
      sub.Free;
      none.Free;
      Stack.Delete(Stack.IndexOf(AName));
    end;
  end;

  (* A permutation config carrying a reference -- `<minsize=%n%>`, `<sep=%S%>` -- is read
     with the reference's PLAIN value put in (sec.5.13: the header is re-read raw). A value
     that is itself structure, or a name nothing defines, leaves the config unreadable, and an
     unreadable config already has its answer: one, as a floor. *)
  function CondBranch(const Head: string): Integer;
  begin
    Result := CondBranchFor(Head, Ctx, Defs);
  end;

  function ConfigWithRefs(const S: string): string;
  var
    p, q: Integer;
    nm, val: string;
    ok: Boolean;
    mac: TCMacro;
  begin
    Result := '';
    p := 1;
    while p <= Length(S) do
    begin
      if S[p] = '%' then
      begin
        q := p + 1;
        while (q <= Length(S)) and (S[q] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(q);
        if (q <= Length(S)) and (S[q] = '%') and (q > p + 1) then
        begin
          nm := LowerCase(Copy(S, p + 1, q - p - 1));
          ok := HostValue(Ctx, nm, val);
          if (not ok) and (Defs <> nil) and Defs.TryGetValue(nm, mac) then
          begin
            ok := True;
            val := mac.Value;
          end;
          { A closer in the value would close the permutation early in the engine's
            textual re-read (`n = ]` makes `[<maxsize=%n%>a|b|c]` one element and a literal
            tail); charged against the engine's purse like any substitution. }
          { Charged BEFORE it is judged: the engine substitutes and then re-reads, so a
            value it will refuse to make a config of still empties the purse. }
          if ok and (not TakePurse(Purse, val)) then ok := False;
          if ok and (not CountsForBudget(val)) and (Pos('<', val) = 0) and
             (Pos('>', val) = 0) and (Pos('|', val) = 0) and (Pos(']', val) = 0) and
             (Pos('}', val) = 0) then
          begin
            Result := Result + val;
            p := q + 1;
            Continue;
          end;
          { Refused, but RECOGNISED: kept whole, as the engine's `%(\w+)%` consumes it. The
            first cut advanced one character and read the closing percent as the start of
            the next name -- `%a%b%` became `%a` + `%b%`. Codex review found it. }
          Result := Result + Copy(S, p, q - p + 1);
          p := q + 1;
          Continue;
        end;
      end;
      Result := Result + S[p];
      Inc(p);
    end;
  end;

  procedure Walk(List: TCTokList; Held: Boolean; LineOverride: Integer);
  var
    i, j, k, mn, mx, m: Integer;
    wantKind: TSpxTokenKind;
    t: TCTok;
    name_, target, text_, cfg: string;
    c, e, mult: Int64;
    ie, ae, wasHeld, sat, fresh: Boolean;
    branch: Integer;
    ns, es: array of Int64;
  begin
    for i := 0 to List.Count - 1 do
    begin
      t := List[i];
      if LineOverride >= 0 then t.Line := LineOverride;
      { Whether this token is the first thing in its frame -- the config position -- decided
        BEFORE the token's own ink lands. }
      fresh := (top >= 0) and (Length(frames[top].Options) = 0) and
               (frames[top].Current = 1) and frames[top].CurrentAllEmpty;
      { Anything that puts characters in the option being read marks it as one that cannot
        render empty. Openers do NOT: the construct they open says at its close how many of
        its ways are empty, and that is what the option inherits. }
      if t.HasInk then Ink;
      { An option this scan could not have classified: see TFrame.Suspect. And a spliced
        value was scanned with no bracket in sight, so text of its opening `<` may be a
        per-element separator or a config to the engine once it is in place -- `[aa|%x%|bb]`
        with `x = <sep>` is two elements, `[%cfg%aa|bb|cc]` with `cfg = <maxsize=1>` is
        three texts; both counted six, exact. Review found the class. Suspect, which is one
        and a floor. }
      if (top >= 0) and (frames[top].Kind = sptBracketOpen) and t.LooksSep and
         ((t.Line <> frames[top].OpenLine) or (LineOverride >= 0)) then
        frames[top].Suspect := True;
      { ...and only a SIZE key in the config position can move the count: HTML in a value
        (`<a href="x">one</a>` per element, the link-list case) opens with `<` too, and the
        first cut of this tell turned that exact permutation into "at least 1". }
      if (top >= 0) and (frames[top].Kind = sptBracketOpen) and (LineOverride >= 0) and
         t.HeadSizeKey and fresh then
        frames[top].ConfigUnknown := True;
      if (top >= 0) and t.HasColon then frames[top].SawColon := True;
      case t.Kind of
        sptBraceOpen:
          { A conditional or a plural is decided by the input, so it is NOT a free choice: its
            head token arrives next and says which this is. Pushed as free, corrected below. }
          Push(sptBraceOpen, True, t.Line, Held);
        sptBracketOpen:
          Push(sptBracketOpen, True, t.Line, Held);
        sptCondHead, sptPluralHead:
          if top >= 0 then
          begin
            (* A SYNTHESISED head is a MAYBE: the keyword was there but the engine also wants a
               colon after it, which may be on a later line. The frame carries the question and
               the close answers it. A real head from the scanner has already been read whole,
               so it is not in doubt. *)
            if t.Synthetic then
              frames[top].MaybePlural := True
            else
            begin
              frames[top].Free := False;
              frames[top].Cond := t.Kind = sptCondHead;
              frames[top].CondHead := t.Text;
              Exact := False;
            end;
          end;
        sptPermConfig:
          if (top >= 0) and (frames[top].Kind = sptBracketOpen) then
          begin
            cfg := t.Text;
            { `<sep="|">` in a HELD def is a pipe in the def's rendered text -- structure the
              splice will split on and this walk of the def's source cannot see. A floor. }
            if Held and t.HasStructure then Exact := False;
            if t.HasRef then cfg := ConfigWithRefs(cfg);
            (* A reference nothing resolved, or a conditional written in the header
               (`<maxsize={?f?1|2}>` -- the engine resolves it before it reads the header,
               sec.5.13; ReadPermConfig sees no digits and answered the full n!, exact).
               Star-parens: it quotes a brace. *)
            if t.UnknownConfig or HasNameRef(cfg) or (Pos('{', cfg) > 0) then
              frames[top].ConfigUnknown := True
            else
            begin
              mn := -1; mx := -1;
              ReadPermConfig(cfg, mn, mx);
              frames[top].MinSize := mn;
              frames[top].MaxSize := mx;
            end;
          end;
        sptTrailingSep:
          (* A separator carrying a reference is text to the engine once the value is in, and
             the value may carry a pipe or a closer -- `<%s%>` with `s = ]` ends the
             permutation there, one element and a literal tail. Suspect, which is one and a
             floor; clearing Exact alone kept "at least 6" over one way. And inside a HELD def
             a separator that is itself structure (`<|>`) becomes structure in the def's
             rendered text, which this walk of the def's source cannot see. Star-parens. *)
          begin
            { Charged like the header's references: the engine puts the value in either way. }
            if t.HasRef then ConfigWithRefs(t.Text);
            if (top >= 0) and (frames[top].Kind = sptBracketOpen) and t.HasRef then
              frames[top].Suspect := True
            else if t.HasRef or (Held and t.HasStructure) then
              Exact := False;
          end;
        sptComment:
          { Literal to the engine inside a spliced value (see Splice), so it is ink there. }
          if LineOverride >= 0 then Ink;
        sptPipe:
          (* Not a separator once the frame is broken -- see TFrame.Broken. Its content goes
             on accumulating into Current, which is right: the chunk after the break is one
             option and whatever constructs it holds still render.

             A pipe ARRIVING FROM A VALUE inside a conditional or a plural is not a branch: the
             engine resolves the conditional BEFORE it expands the value (spec sec.5.13), so
             `[{?f?%x%}|cc]` with `x = aa|bb|dd` has no else whatever the value holds, renders
             empty unset, and the element is dropped. Splitting the frame gave it three
             branches and a certain presence -- "at least 2" for one text. Review found it.
             Only for a frame the DOCUMENT opened: a conditional the value's own text opens is
             an ordinary construct and its pipe is its branch -- the first cut skipped that one
             too and answered "at least 1" for `[%x%|cc]` over `x = {?f?aa|bb}`, which makes
             two texts under every input. Star-parens: braces above. *)
          if (top >= 0) and (not frames[top].Broken) then
          begin
            if (LineOverride >= 0) and (not frames[top].Free) and (top <= spliceBase) then
            begin
              Exact := False;
              Continue;
            end;
            CloseOption;
            frames[top].Current := 1;
            frames[top].CurrentEmpty := 1;
            frames[top].CurrentInputEmpty := False;
            frames[top].CurrentAllEmpty := True;
          end;
        sptBraceClose, sptBracketClose:
          (* WHICH FRAME A CLOSER CLOSES: the nearest open one OF ITS OWN KIND, which is not
             always the top one, and neither of the two things this walk used to do.

             `FindMatchingClose` (`Spintax.pas/FindMatchingClose`) counts only its own bracket kind, so
             a `]` reaches past an unclosed `{` and closes the `[` underneath -- and the frames
             it reached past were never constructs at all. Matching the top frame ONLY had two
             failure modes, both measured:

               `[aa|bb|cc|dd|ee}`   popped the bracket on a brace and reported 120 as a
                                    promise, where the engine renders one text
               `[a{b|c]d}`          closed the BRACE on the `]`, kept the split before it and
                                    said "at least 2" -- the engine's permutation content is
                                    `a{b|c`, whose `{` is literal, so it makes ONE

             The second broke the floor, which is this unit's one unconditional promise.

             And a closer with no frame of its kind open is not merely ignorable: the engine's
             `SplitTopLevel` drives a counter NEGATIVE on it and then splits no further, so
             the frame it lands in stops taking `|` as a separator (see TFrame.Broken).

             Written with star-parens because the examples it quotes are made of braces, and
             the charter has paid for that lesson twice. *)
          begin
            if t.Kind = sptBraceClose then wantKind := sptBraceOpen
                                      else wantKind := sptBracketOpen;
            j := top;
            while (j >= 0) and (frames[j].Kind <> wantKind) do Dec(j);

            if (j >= 0) and (j < top) then
            begin
              { Whatever the skipped frames accumulated is not a choice anybody makes. }
              top := j;
              SetLength(frames, top + 1);
              Exact := False;
            end;

            if j >= 0 then
            begin
            CloseOption;
            { The plural question, answered now that the whole construct has been read. }
            if frames[top].MaybePlural and frames[top].SawColon then
            begin
              frames[top].Free := False;
              frames[top].Cond := False;
              Exact := False;
            end;
            e := 0;
            ie := False;
            ae := False;
            for k := 0 to High(frames[top].Options) do
              if frames[top].InputEmpty[k] then ie := True;
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
                 floor is enumerated and not written down.

                 AND EITHER MAY RENDER EMPTY ON THE INPUT'S SAY-SO: a conditional whose taken
                 branch is blank, or has no else at all, and a plural whose count is not a
                 number. Inside a permutation that is an element the engine DROPS (sec.5.13),
                 so the option is marked input-decided and the close below leaves it out of the
                 floor. `[{?f?xx}|aa|bb]` said "at least 6" about a document that makes 2. *)
              c := 1;
              if frames[top].Cond then
              begin
                (* WHICH BRANCH, asked of the same table the engine asks. The engine tests the
                   RAW value of the name -- `#set %f% = {a|}` is truthy as written, whatever it
                   renders -- for one code point outside PCRE2's space class, and an undefined
                   name is falsy (`Spintax.pas/ConditionalTakesThen`). So most conditions are
                   DECIDED here: an undefined name takes the else, a plain value the then. The
                   biggest branch, which this used to answer, is not a floor for the input in
                   hand -- `{?f?{a|b}|x}` unset renders one way and said "at least 2"; Codex
                   review found it. What stays undecided -- a `#def` that renders, a value of
                   only non-ASCII bytes that may all be spaces -- takes the SMALLEST branch,
                   with a missing else worth one. *)
                branch := CondBranch(frames[top].CondHead);
                if branch = 0 then
                  c := frames[top].Options[0]
                else if (branch = 1) and (Length(frames[top].Options) >= 2) then
                  c := frames[top].Options[1]
                else if branch = 1 then
                  c := 1
                else
                begin
                  c := frames[top].Options[0];
                  for k := 1 to High(frames[top].Options) do
                    if frames[top].Options[k] < c then c := frames[top].Options[k];
                  if Length(frames[top].Options) < 2 then c := 1;
                end;
                { And whether the SELECTED branch may render empty -- that branch alone: the
                  `ie` gathered over every branch above is discarded when one is chosen, or
                  a plural in the branch NOT taken kept dropping the element. Undecided, any
                  branch may. }
                if branch = 0 then
                  ie := frames[top].InputEmpty[0] or (frames[top].Empties[0] > 0)
                else if branch = 1 then
                  ie := (Length(frames[top].Options) < 2) or frames[top].InputEmpty[1] or
                        (frames[top].Empties[1] > 0)
                else
                begin
                  if Length(frames[top].Options) < 2 then ie := True;
                  for k := 0 to High(frames[top].Options) do
                    if frames[top].Empties[k] > 0 then ie := True;
                end;
              end
              else
                ie := True;
            end
            else if frames[top].Kind = sptBracketOpen then
            begin
              if frames[top].ConfigUnknown or frames[top].Suspect then
              begin
                { One is the only number that cannot be wrong here -- and an unread config
                  may also be one that lets every element go, so the element it makes is
                  not promised to be there. }
                c := 1;
                ie := True;
                Exact := False;
              end
              else
              begin
                (* THE ELEMENTS, and which of them the engine will have when it shuffles. An
                   option whose every way renders empty was never an element (`[aa||bb]`,
                   `[aa|<bb>|cc]`, an empty value); one the INPUT may blank is left out of the
                   floor; the rest go to the arithmetic with their empty ways beside them. *)
                SetLength(ns, 0);
                SetLength(es, 0);
                e := 1;
                mult := 1;
                ae := True;
                sat := False;
                for k := 0 to High(frames[top].Options) do
                begin
                  if frames[top].InputEmpty[k] then
                  begin
                    Exact := False;
                    Continue;
                  end;
                  e := MulSat(e, frames[top].Empties[k]);
                  (* An option every way of which renders empty is never an element -- but
                     its WAYS are still drawn (the engine renders every child first), so they
                     multiply, as `{|}` is two ways in an enumeration. Star-parens: braces. *)
                  if frames[top].AllEmpty[k] then
                  begin
                    mult := MulSat(mult, frames[top].Options[k]);
                    Continue;
                  end;
                  ae := False;
                  { A saturated count of ways cannot be split into empty and not: the answer
                    is saturated whatever the split. }
                  if frames[top].Options[k] >= SPX_COUNT_CEILING then sat := True;
                  m := Length(ns);
                  SetLength(ns, m + 1);
                  SetLength(es, m + 1);
                  ns[m] := frames[top].Options[k] - frames[top].Empties[k];
                  es[m] := frames[top].Empties[k];
                end;
                if sat then
                  c := SPX_COUNT_CEILING
                else
                  c := MulSat(mult, PermutationCountWithEmpties(ns, es, frames[top].MinSize,
                                                                frames[top].MaxSize, Exact));
              end;
            end
            else
            begin
              c := 0;
              ae := True;
              for k := 0 to High(frames[top].Options) do
              begin
                c := AddSat(c, frames[top].Options[k]);
                e := AddSat(e, frames[top].Empties[k]);
                if not frames[top].AllEmpty[k] then ae := False;
              end;
            end;
            { A held construct is one text already drawn -- see Splice. One that is always
              empty stays so; one that may be is a correlated draw, reported as input-decided. }
            wasHeld := frames[top].Held;
            if wasHeld then
            begin
              c := 1;
              if ae then e := 1
              else
              begin
                if e > 0 then ie := True;
                e := 0;
              end;
            end;
            Dec(top);
            SetLength(frames, top + 1);
            Absorb(c, e, ie, ae);
            end
            else if top >= 0 then
            begin
              frames[top].Broken := True;
              { The engine refuses this document anyway -- the panel says
                `bracket.mismatched` -- so from here the number is a floor. }
              Exact := False;
            end;
          end;
        sptVariable:
          begin
            name_ := t.Text;
            name_ := StringReplace(name_, '%', '', [rfReplaceAll]);
            if name_ = '' then Continue;
            if top >= 0 then
              Splice(name_, t.Line, Held)
            else
            begin
              { At top level a value is a template of its own and a `|` in it is text --
                measured, and the reason the splice above is confined to a frame. }
              c := MacroCount(Defs, name_, Ctx, Exact, Steps, Purse, totalHere^, Depth, Seen,
                              Stack, defsHere, ie);
              if ie then
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
                Absorb(c, 0, False, False);
            end;
          end;
        sptString:
          begin
            { The `#include` target, quotes included. Inside a spliced VALUE it is text the
              engine may resolve after rendering, which nothing here can count: a floor. And
              inside a PERMUTATION the directive is one element of a line the engine joins
              with separators, so it never stands alone on its line and stays literal -- unless
              it is the only element, which is why this too is a floor and not a zero. Review
              measured `[` LF `#include "f"` LF `|aa]`: counted 4 exact, renders two literal
              texts. }
            if (LineOverride >= 0) or InsideBracket then
            begin
              Exact := False;
              Continue;
            end;
            Inc(tokenIncludes);
            target := t.Text;
            if (Length(target) >= 2) and (target[1] = '"') then
              target := Copy(target, 2, Length(target) - 2);
            if trustIncludes and (Ctx.Templates <> nil) and (target <> '') and
               (Seen.IndexOf(target) < 0) and Ctx.Templates.TryGetValue(target, text_) then
            begin
              Seen.Add(target);
              (* A child scope: the fragment's own prelude, its OWN `#def` rolls, and nothing
                 of this document's -- CountText owns a scope whenever it is handed no table.

                 AND IT PAYS THE SAME BUDGET, because `Seen` is a PATH guard: it is deleted
                 again below, so a fragment reached twice by different routes is expanded
                 twice. Twelve fragments each including the next ten times is acyclic, is
                 within the depth cap of 20, and HUNG -- measured, past 60 s with no answer,
                 on the worker thread. The macro budget alone did not cover it: that was
                 charged on the two macro paths only, and this is a third. Found by probing
                 the fix rather than by reading it, which is the only reason it is here. *)
              Dec(Steps, Length(text_) + SPX_COUNT_CALL_COST);
              if Steps <= 0 then
                Exact := False          { out of budget: this subtree is not walked at all }
              else
                Absorb(CountText(text_, Ctx, nil, Exact, Steps, Purse, ownTotal, Depth + 1, Seen,
                                 Stack, defsHere), 0, False, False);
              Seen.Delete(Seen.IndexOf(target));
            end
            else
            begin
              { An unknown target renders empty -- one text, and the answer becomes a bound
                because a set that gains the fragment would produce more; inside a
                permutation the empty element is dropped, so the option is input-decided. }
              Exact := False;
              Absorb(1, 1, True, False);
            end;
          end;
      end;
    end;
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
     render again per occurrence (`Spintax.pas/ResolveIncludes`), so a fragment's `#def` is rolled once
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
    spliceBase := -1;
    SetLength(frames, 0);

    Walk(tokens, False, -1);

    { An unclosed construct is a template the engine will refuse anyway; count what was read
      rather than throwing away the whole answer. }
    while top >= 0 do
    begin
      (* Into the PARENT: the first cut absorbed before popping, so an unclosed frame multiplied
         its count into itself and the document never saw it -- `{aa|bb} {cc {dd|ee}` said "at
         least 2" where the engine makes 4. Review found the regression. Star-parens: the
         example is unbalanced on purpose. *)
      c := frames[top].Current;
      Dec(top);
      SetLength(frames, top + 1);
      Absorb(c, 0, False, False);
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
       runs over the RENDERED text (`Spintax.pas/ResolveIncludes`), so `{pp|#include "f"}` resolves when
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

var
  seen, stack, defs: TStringList;
  defTotal, purse: Int64;
  steps_: Integer;
  folded: TStrMap;
  pair: specialize TPair<string, string>;
  ctx2: TSpxContext;
begin
  Result.Exact := True;
  Result.Saturated := False;
  seen := TStringList.Create;
  stack := TStringList.Create;
  defs := TStringList.Create;
  folded := nil;
  defTotal := 1;
  try
    { The session table with its keys folded the way the engine folds them -- once, here,
      so every lookup below is one probe. See HostValue. }
    ctx2 := Ctx;
    if (Ctx.Vars <> nil) and (Ctx.Vars.Count > 0) then
    begin
      folded := TStrMap.Create;
      for pair in Ctx.Vars do folded.AddOrSetValue(LowerCase(pair.Key), pair.Value);
      ctx2.Vars := folded;
    end;
    seen.CaseSensitive := True;      { include targets are compared exactly -- engine v0.2.2 }
    stack.CaseSensitive := False;    { macro names are keyed lower-cased by the engine }
    defs.CaseSensitive := False;
    { The `#def` product belongs to a document SCOPE and CountText owns one, so these two are
      placeholders the top-level call never reads. }
    steps_ := SPX_COUNT_STEPS;
    purse := SPX_ENGINE_EXPANSION_BUDGET;
    Result.Value := CountText(Doc, ctx2, nil, Result.Exact, steps_, purse, defTotal, 0, seen,
                              stack, defs);
  finally
    folded.Free;
    defs.Free;
    stack.Free;
    seen.Free;
  end;
  (* AN EMPTY PURSE COLLAPSES THE COUNT TO ONE. The engine substitutes in ITS order -- a
     fixpoint that replaces every reference already in the body before it looks at the ones a
     value brought in -- and this walk descends at once, so once the purse runs out the two
     have expanded different references: `{%a%%b%}` with `a = %x%`, `x = p|q` and a plain `b`
     past a mebibyte is one way in the engine, which left `%x%` literal on its second pass,
     and two here. No floor survives a different order, and a document the engine truncates
     has no count worth more than "at least one". Codex review found the shape. *)
  if (purse <= 0) or (steps_ <= 0) then
  begin
    { The walk's OWN budget too: past it a reference is left as ink here that the engine
      expands, and what the engine puts in may close a bracket or vanish -- the floor is
      gone either way. Codex review built the shape. }
    Result.Value := 1;
    Result.Exact := False;
    Result.Saturated := False;
    Exit;
  end;
  if Result.Value >= SPX_COUNT_CEILING then
  begin
    Result.Value := SPX_COUNT_CEILING;
    Result.Saturated := True;
  end;
  if Result.Value < 1 then Result.Value := 1;
end;

end.
