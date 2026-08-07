(*
 * SpxTokens -- the spintax tokenizer the editor colours by.
 *
 * Pure and GUI-free on purpose. SynEdit's highlighter is a thin adapter over this
 * (gui/SpxSynHighlighter.pas), which keeps the scanning testable in the console suite and
 * keeps the toolkit choice contained -- the same split editor-core already makes.
 *
 * WHAT THIS IS NOT. It is a presentation scan, not a second validator: it never decides
 * whether a template is valid, never reports a diagnostic, and a `}` that closes nothing is
 * simply drawn as a brace. Verdicts come from `SpValidate`, positions from `TSpDiag`, and
 * this file must never grow an opinion about either (spec §4.1).
 *
 * Token classes follow the family's own grammar -- the same ones `vscode-spintax` and
 * `sublime-spintax` colour -- so a template looks like itself in every editor.
 *
 * ONE KNOWN GAP, and it is deliberate. The include anchor lets `[ \t\n\r\f\x0B]+` sit
 * between `#include` and its target, so the target may begin on the FOLLOWING line; the
 * engine resolves that, and this scanner leaves it plain text. Colouring it would mean
 * painting the keyword before knowing whether a quoted target ever arrives, and a wrong
 * colour is worse here than a missing one: this file's job is to never claim a construct
 * the engine does not see. The same-line members of that class (space, tab, VT, FF) are
 * matched. Measured, not assumed -- the differential lives in the suite.
 *
 * STATE BETWEEN LINES is a comment flag and a nesting depth, and that is the whole reason
 * unbounded nesting is not a problem here: depth is an integer, not a stack, so a template
 * nested three hundred deep costs one more increment rather than one more frame. Whether a
 * `}` matches the `{` that opened its level is a question this scan deliberately does not
 * ask -- the validator does.
 *
 * Bytes, not code points: every structural character is ASCII, and a UTF-8 continuation
 * byte can never be mistaken for one. That is what lets this scan step a byte at a time
 * over Cyrillic without a decoder.
 *)
unit SpxTokens;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  Classes, SysUtils, StrUtils, Generics.Collections;

type
  TSpxTokenKind = (
    sptText,          // anything with no meaning of its own
    sptComment,       // /# ... #/, markers included
    sptDirective,     // the #set / #def / #include keyword itself
    sptString,        // "target" of an #include
    sptVariable,      // %name%
    sptBraceOpen,     // { -- enumeration, conditional or plural
    sptBraceClose,    // }
    sptBracketOpen,   // [ -- permutation
    sptBracketClose,  // ]
    sptPipe,          // | between options
    sptCondHead,      // ?name? or ?!name? right after {
    sptPluralHead,    // plural %n%: -- keyword, count and colon
    sptPermConfig,    // <minsize=2;sep=", "> right after [
    sptTrailingSep    // <br> ending a permutation element: the separator before the next
  );

  { Everything the next line needs to know. Packed into an integer for SynEdit's range
    pointer, which is why depth is capped rather than unbounded -- 255 levels of nesting is
    already past anything a human writes, and the cap only affects the SHADE a brace gets. }
  TSpxScanState = record
    InComment: Boolean;
    { Nothing but comment (and whitespace) has appeared on the current LOGICAL line. The
      engine strips comments before it splits lines, so `/# n #/ #set %x% = 1` really is a
      directive to it and `before /# n #/ #set %x% = 1` really is not -- and a comment that
      opened on an earlier line keeps the logical line open, newline and all. Without this
      bit a highlighter confirms a macro definition the engine never made. }
    LineEmpty: Boolean;
    (* A line-leading `#include` is WAITING FOR ITS TARGET, which the family's anchor allows
       to begin on a later line: the gap is `[ \t\n\r\f\x0B]+`, newlines included, so
       `#include` LF `"frag"` is one directive to the engine (measured, and its span comes
       back as L1..L2). Any number of whitespace-only lines may sit in between.

       WHAT THIS DOES NOT DO, and it is a decision rather than an omission: it does not paint
       the KEYWORD. A scan that runs forward one line at a time cannot know, while it is
       looking at `#include`, whether a target ever arrives -- and SynEdit never re-scans a
       line backwards, so a keyword painted optimistically stays painted when the next line
       turns out to be prose. This file's contract is that it never claims a construct the
       engine does not see; it promises nothing in the other direction. So the keyword stays
       plain and the TARGET is painted, which is the half that carries the meaning -- which
       file -- and the half `SpxCount` needs to stop calling such a document a lower bound. *)
    IncludeOpen: Boolean;
    Depth: Integer;
  end;

  { Offsets are 1-based BYTE positions within the line, which is what both FPC strings and
    SynEdit use. Depth is the nesting level this token belongs to: an opener carries the
    level it creates, a closer the level it closes, everything else the level it sits in. }
  TSpxToken = record
    Kind: TSpxTokenKind;
    Start: Integer;
    Length: Integer;
    Depth: Integer;
  end;
  TSpxTokenList = TList<TSpxToken>;

const
  { The cap and the mask are separate on purpose: raising one used to silently corrupt the
    other, because a depth of 300 sets the bit the comment flag lives in. }
  SPX_MAX_DEPTH = 255;
  SPX_DEPTH_MASK = $FFFF;

{ Scan ONE line (without its terminator). State goes in as the previous line left it and
  comes out ready for the next. Tokens are appended, never cleared, so a caller can scan a
  document into one list. }
procedure SpxScanLine(const Line: string; var State: TSpxScanState; Tokens: TSpxTokenList);

{ For SynEdit's Range pointer, which is where a highlighter's between-line state must live. }
function SpxPackState(const State: TSpxScanState): PtrInt;
function SpxUnpackState(Value: PtrInt): TSpxScanState;

{ The partner of the bracket at Offset (1-based, into the whole document), or 0 when there
  is none. Spec §4.1 asks for the pair under the caret; this is the half that can be tested
  without a window, and the editor draws what it returns.

  SynEdit ships a matcher and it is wrong for this language in two ways, which is why this
  exists: it counts parentheses and quotes as brackets -- ordinary text in spintax, so the
  demo's "(spin syntax)" would sprout a pair that means nothing -- and it knows nothing
  about block comments, so it happily pairs an opener inside one with a closer outside it.

  A closer of the WRONG kind is not a partner: an opening brace closed by a square bracket
  returns 0 rather than pointing at it. That shape is what the validator calls
  bracket.mismatched, and drawing a pair the engine rejects would be the editor arguing
  with the verdict.

  One forward pass over the text per call, which is what a caret move costs. }
function SpxMatchBracket(const Text: string; Offset: Integer): Integer;

type
  TSpxOffsets = array of Integer;

(* THE CONSTRUCT'S OWN SEPARATORS, between a bracket and its partner.

  What GTW shows when the caret steps onto a bracket: not just the pair, but every place the
  construct divides. `|` is one, and so is a permutation's trailing `<br>` -- the engine reads
  that as the separator placed before the next element, which is why the highlighter already
  paints it as config rather than as text.

  ITS OWN, and depth is what says so. The scanner gives an opener the level it CREATES and
  everything inside it that level, so a separator belonging to this construct carries the
  opener's depth and one inside a nested group carries more: measured on `{a|{x|y}|c}`, the outer
  pipes are depth 1 and the inner one depth 2. Filtering by depth is therefore exact, and it
  needs no knowledge of what KIND of construct this is -- a conditional's head, a plural's count
  and a permutation's config are all skipped for free, because none of them is a separator token.

  AOpen and AClose are 1-based byte offsets and must be a real pair; anything else returns
  nothing rather than a guess. Scanning starts at the document's beginning because the scanner's
  state does -- a comment three lines up is still open, and the depth here is only meaningful
  counted from the top. *)
function SpxSeparatorsOf(const Text: string; AOpen, AClose: Integer): TSpxOffsets;

(* THE CONSTRUCT A SEPARATOR BELONGS TO -- the other half of the rule above.

  Stepping onto a bracket shows the pair AND every place the construct divides. The reverse was
  missing, and the reader reported it: stepping onto a `|` showed nothing at all. Measured
  before this existed, on `{a|b|c}` -- a caret on the brace found its partner and both pipes, a
  caret on either pipe found nothing, because the matcher exits unless the character under it is
  a bracket.

  THE CONSTRUCT IS THE INNERMOST PAIR AROUND THE OFFSET, and the scan gets that for free:
  closers are matched innermost first, so the first completed pair that encloses the offset IS
  the innermost one.

  AND THE OFFSET MUST BE ONE OF THAT PAIR'S OWN SEPARATORS -- its own by depth, which is the
  question SpxSeparatorsOf already answers. A caret merely INSIDE a group lights nothing: the
  highlight is about structure the caret is standing on, and lighting a construct because the
  caret is somewhere within it would light one on almost every keystroke.

  A MISMATCHED PAIR ANSWERS NOTHING, and does not climb to the construct outside it -- the same
  rule SpxMatchBracket states for a brace closed by a square bracket. That shape is
  bracket.mismatched, and drawing a construct the engine rejects would be the editor arguing
  with the verdict.

  Comments are skipped as SpxMatchBracket skips them, and an offset INSIDE one answers nothing:
  a `|` in `/# ... #/` divides nothing.

  The offset must be the separator's FIRST byte, which is where the markup draws it. `|` is one
  byte, so the reported case is exact; a permutation's trailing `<br>` answers from its `<` and
  not from inside it.

  THE SEPARATORS COME BACK WITH THE PAIR because finding them is how the question is answered:
  a caller that asked SpxSeparatorsOf again would pay the same scan twice, and it is the more
  expensive of the two. Measured on a 466 KB document, with the caret on a pipe halfway down
  it: the enclosing pass costs 1.1 ms and the separators 5.1 ms, which is exactly what the
  BRACKET case has always paid at the same place -- so this adds no new order of cost, and
  returning them keeps it from doubling.

  WHICH LEAVES THE GATE, and it has two halves because the two characters are nothing alike. A
  `|` is a separator often enough to be worth a scan. A `<` almost never is: measured on a
  466 KB template written the way one really is, 25 291 angle brackets and NOT ONE of them a
  separator -- they are `<p>`, `<b>`, `</i>`. Admitting them cost 4.5 ms on average and 13 ms
  at worst per caret move, on a character an HTML template is made of. So a `<` is put to the
  scanner's OWN line-local rule first (TrailingSepLength, the same function the tokenizer uses
  to decide the very same thing), which rejected all 25 291 in 0.00002 ms and lets every real
  trailing separator through. Found by review, after this file claimed the gate made ordinary
  text free -- true of every character but the one HTML is full of. *)
function SpxConstructOf(const Text: string; Offset: Integer;
  out AOpen, AClose: Integer; out ASeps: TSpxOffsets): Boolean;

implementation

function SpxPackState(const State: TSpxScanState): PtrInt;
begin
  Result := State.Depth and SPX_DEPTH_MASK;
  if State.InComment then Result := Result or (1 shl 16);
  if State.LineEmpty then Result := Result or (1 shl 17);
  if State.IncludeOpen then Result := Result or (1 shl 18);
end;

function SpxUnpackState(Value: PtrInt): TSpxScanState;
begin
  Result.Depth := Value and SPX_DEPTH_MASK;
  Result.InComment := (Value and (1 shl 16)) <> 0;
  Result.LineEmpty := (Value and (1 shl 17)) <> 0;
  Result.IncludeOpen := (Value and (1 shl 18)) <> 0;
end;

function SpxSeparatorsOf(const Text: string; AOpen, AClose: Integer): TSpxOffsets;
var
  state: TSpxScanState;
  toks: TSpxTokenList;
  at, nl, n, i, want: Integer;
  line: string;
  absStart: Integer;
begin
  Result := nil;
  n := 0;
  want := -1;
  if (AOpen < 1) or (AClose <= AOpen) or (AClose > Length(Text)) then Exit;
  state := Default(TSpxScanState);
  toks := TSpxTokenList.Create;
  try
    at := 1;
    while at <= Length(Text) do
    begin
      nl := at;
      while (nl <= Length(Text)) and (Text[nl] <> #10) and (Text[nl] <> #13) do Inc(nl);
      line := Copy(Text, at, nl - at);
      absStart := at;
      toks.Clear;
      SpxScanLine(line, state, toks);
      for i := 0 to toks.Count - 1 do
      begin
        { The token's offset in the DOCUMENT, which is the only coordinate a caller has. }
        at := absStart + toks[i].Start - 1;
        if at = AOpen then want := toks[i].Depth;
        if (want >= 0) and (at > AOpen) and (at < AClose)
           and (toks[i].Depth = want)
           and (toks[i].Kind in [sptPipe, sptTrailingSep]) then
        begin
          SetLength(Result, n + 1);
          Result[n] := at;
          Inc(n);
        end;
      end;
      { Past the closing bracket there is nothing left to find. }
      if absStart + Length(line) >= AClose then Break;
      at := absStart + Length(line);
      { One terminator, CRLF counted as one -- the same two-character step the rest of this unit
        takes so an offset never lands between them. }
      if (at <= Length(Text)) and (Text[at] = #13) then Inc(at);
      if (at <= Length(Text)) and (Text[at] = #10) then Inc(at);
    end;
  finally
    toks.Free;
  end;
  { An opener that was never seen means the caller did not hand us a bracket. }
  if want < 0 then Result := nil;
end;

{ The tokenizer's own rules, declared ahead of their definitions because the two things below
  need them: SpxConstructOf puts an angle bracket to TrailingSepLength before paying for a
  scan, and ConfigSkip asks PermConfigLength where a permutation's config ends. One rule, one
  place: a second copy here would be a second thing to keep in step with the engine. }
function TrailingSepLength(const Line: string; p: Integer): Integer; forward;
function PermConfigLength(const Line: string; p: Integer): Integer; forward;

(* HOW MANY BYTES A PERMUTATION'S CONFIG TAKES AT AAt, or 0 when there is no config there.

  A config is not code, and the brackets inside it open nothing: `[<sep="{">a|b]` carries a
  brace that belongs to a quoted string. Both walks below used to count it, so the phantom
  pair swallowed the `]` that really closes the permutation -- measured by fuzzing, four shapes
  in eighty thousand documents, and the tokenizer disagreed with the matcher about every one of
  them. The tokenizer is the side that was right, so this asks IT rather than deciding again.

  Line-local because the rule is: PermConfigLength wants the config's `>` on the same line.

  AND BLANKS BEFORE THE `<` ARE PART OF IT. The engine left-trims a permutation's first part
  before asking whether it opens with `<` (Spintax.pas:1258), the tokenizer does the same
  (SpxScanLine, and its comment says the space may not disable the colouring), so a walk that
  required the `<` to sit against the `[` left the whole defect alive behind one space:
  measured on `[ <sep="{">a|b]`, the opener matched nothing and the inner permutation took the
  outer `]`. Found by review, after this comment already claimed to ask the tokenizer rather
  than decide again. *)
function ConfigSkip(const Text: string; AAt: Integer): Integer;
var from_, stop, blanks: Integer;
begin
  Result := 0;
  if (AAt < 1) or (AAt > Length(Text)) then Exit;
  blanks := 0;
  while (AAt + blanks <= Length(Text)) and
        (Text[AAt + blanks] in [' ', #9, #11, #12]) do Inc(blanks);
  Inc(AAt, blanks);
  if (AAt > Length(Text)) or (Text[AAt] <> '<') then Exit;
  from_ := AAt;
  while (from_ > 1) and (Text[from_ - 1] <> #10) and (Text[from_ - 1] <> #13) do Dec(from_);
  stop := AAt;
  while (stop <= Length(Text)) and (Text[stop] <> #10) and (Text[stop] <> #13) do Inc(stop);
  Result := PermConfigLength(Copy(Text, from_, stop - from_), AAt - from_ + 1);
  { The blanks are skipped with it, or the caller lands back on them. }
  if Result > 0 then Inc(Result, blanks);
end;

function SpxMatchBracket(const Text: string; Offset: Integer): Integer;
type
  TOpen = record Pos: Integer; Ch: Char; end;
var
  stack: array of TOpen;
  top, i, n: Integer;
  c: Char;

  function Partner(Opener, Closer: Char): Boolean;
  begin
    Result := ((Opener = '{') and (Closer = '}')) or ((Opener = '[') and (Closer = ']'));
  end;

begin
  Result := 0;
  n := Length(Text);
  if (Offset < 1) or (Offset > n) then Exit;
  if not (Text[Offset] in ['{', '}', '[', ']']) then Exit;

  SetLength(stack, 32);
  top := 0;
  i := 1;
  while i <= n do
  begin
    { A comment is not code: brackets inside it belong to no pair, and the offset itself
      being inside one means there is nothing to match. }
    if (Text[i] = '/') and (i < n) and (Text[i + 1] = '#') then
    begin
      Inc(i, 2);
      while (i < n) and not ((Text[i] = '#') and (Text[i + 1] = '/')) do Inc(i);
      Inc(i, 2);
      Continue;
    end;

    c := Text[i];
    if (c = '{') or (c = '[') then
    begin
      if top = Length(stack) then SetLength(stack, top * 2);
      stack[top].Pos := i;
      stack[top].Ch := c;
      Inc(top);
      { A permutation's config is skipped whole: the brackets in it open nothing, and counting
        them let a phantom pair swallow the `]` that really closes the permutation. }
      if c = '[' then Inc(i, ConfigSkip(Text, i + 1));
    end
    else if (c = '}') or (c = ']') then
    begin
      if top > 0 then
      begin
        Dec(top);
        if Partner(stack[top].Ch, c) then
        begin
          if stack[top].Pos = Offset then Exit(i);
          if i = Offset then Exit(stack[top].Pos);
        end
        else if (stack[top].Pos = Offset) or (i = Offset) then
          Exit(0);   { mismatched kinds: the validator's business, not a pair to draw }
      end
      else if i = Offset then
        Exit(0);     { a closer with nothing open }
    end;
    Inc(i);
  end;
end;

function SpxConstructOf(const Text: string; Offset: Integer;
  out AOpen, AClose: Integer; out ASeps: TSpxOffsets): Boolean;
type
  TOpen = record Pos: Integer; Ch: Char; end;
var
  stack: array of TOpen;
  top, i, n, k, from_: Integer;
  c: Char;

  function Partner(Opener, Closer: Char): Boolean;
  begin
    Result := ((Opener = '{') and (Closer = '}')) or ((Opener = '[') and (Closer = ']'));
  end;

begin
  Result := False;
  AOpen := 0;
  AClose := 0;
  ASeps := nil;
  n := Length(Text);
  if (Offset < 1) or (Offset > n) then Exit;
  { THE GATE -- see the header. Everything below is a pass over the document and then a
    tokenising one, and a separator is either a `|` or the `<` that opens a trailing one. }
  if not (Text[Offset] in ['|', '<']) then Exit;
  if Text[Offset] = '<' then
  begin
    { An angle bracket answers to the tokenizer's own rule for a trailing separator, on ITS
      line and nothing more: the rule needs a `>` and then a `|`, which `<p>` and `</b>` fail
      at once. This is a pre-filter and not the answer -- whether the separator belongs to the
      construct is still decided below -- but it is what keeps an HTML template's twenty-five
      thousand tags off the cost of a document scan apiece. }
    from_ := Offset;
    while (from_ > 1) and (Text[from_ - 1] <> #10) and (Text[from_ - 1] <> #13) do Dec(from_);
    k := Offset;
    while (k <= n) and (Text[k] <> #10) and (Text[k] <> #13) do Inc(k);
    if TrailingSepLength(Copy(Text, from_, k - from_), Offset - from_ + 1) = 0 then Exit;
  end;

  SetLength(stack, 32);
  top := 0;
  i := 1;
  while i <= n do
  begin
    if (Text[i] = '/') and (i < n) and (Text[i + 1] = '#') then
    begin
      from_ := i;
      Inc(i, 2);
      while (i < n) and not ((Text[i] = '#') and (Text[i + 1] = '/')) do Inc(i);
      Inc(i, 2);
      { An offset inside the comment divides nothing, and there is no point scanning on. }
      if (Offset >= from_) and (Offset < i) then Exit;
      Continue;
    end;

    c := Text[i];
    if (c = '{') or (c = '[') then
    begin
      if top = Length(stack) then SetLength(stack, top * 2);
      stack[top].Pos := i;
      stack[top].Ch := c;
      Inc(top);
      { A permutation's config is skipped whole: the brackets in it open nothing, and counting
        them let a phantom pair swallow the `]` that really closes the permutation. }
      if c = '[' then Inc(i, ConfigSkip(Text, i + 1));
    end
    else if (c = '}') or (c = ']') then
    begin
      if top > 0 then
      begin
        Dec(top);
        if (stack[top].Pos < Offset) and (Offset < i) then
        begin
          { The innermost pair around the offset -- or, when the kinds do not match, the answer
            that there is no construct here to draw. }
          if not Partner(stack[top].Ch, c) then Exit;
          AOpen := stack[top].Pos;
          AClose := i;
          Break;
        end;
      end;
    end;
    Inc(i);
  end;

  if AOpen = 0 then Exit;
  { And it has to be one of THIS construct's separators. Asked of the rule that already knows,
    rather than of a second copy of it here -- and handed back, so the caller that is about to
    draw them does not run the same scan again. }
  ASeps := SpxSeparatorsOf(Text, AOpen, AClose);
  for k := 0 to High(ASeps) do
    if ASeps[k] = Offset then Exit(True);
  AOpen := 0;
  AClose := 0;
  ASeps := nil;
end;

function IsWordByte(c: Char): Boolean;
begin
  Result := (c in ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

procedure Emit(Tokens: TSpxTokenList; Kind: TSpxTokenKind; Start, Len, Depth: Integer);
var t: TSpxToken;
begin
  if Len <= 0 then Exit;
  t.Kind := Kind;
  t.Start := Start;
  t.Length := Len;
  t.Depth := Depth;
  Tokens.Add(t);
end;

{ `%name%` at p, or 0. The engine's variable names are ASCII word characters, so this agrees
  with it without borrowing its scanner. }
function VariableLength(const Line: string; p: Integer): Integer;
var i, n: Integer;
begin
  Result := 0;
  n := Length(Line);
  if (p > n) or (Line[p] <> '%') then Exit;
  i := p + 1;
  while (i <= n) and IsWordByte(Line[i]) do Inc(i);
  if (i > p + 1) and (i <= n) and (Line[i] = '%') then Result := i - p + 1;
end;

{ A per-element trailing separator: the `<...>` that ends a permutation element, which the
  engine takes as the separator to place before the NEXT element. Returns its length,
  brackets included, or 0.

  The rule is the engine's, measured against it rather than read off a grammar:
    * it must be followed -- blanks skipped -- by a `|`. A `<...>` before the closing `]`
      belongs to the LAST element, and the engine leaves it as text;
    * its inner text must not look like HTML: starting or ending with `/`, or a tag name
      followed by whitespace.
  So `<br>` and `<, >` ARE separators, while `<br/>`, `<br />`, `</b>` and
  `<span class="x">` are not -- which is exactly what the engine renders. }
{ The engine's blank class for trimming a part and its separator: space, tab, LF, CR, NUL and
  VERTICAL TAB -- and not form feed. Pascal's Trim takes everything <= #32, which differs on
  exactly those edges, so the class is spelled out here as DirectiveKeywordLength spells out
  its own. }
function IsSepBlank(c: Char): Boolean;
begin
  Result := (c = ' ') or (c = #9) or (c = #10) or (c = #13) or (c = #0) or (c = #11);
end;

function SepTrim(const S: string): string;
var a, b: Integer;
begin
  a := 1;
  b := Length(S);
  while (a <= b) and IsSepBlank(S[a]) do Inc(a);
  while (b >= a) and IsSepBlank(S[b]) do Dec(b);
  Result := Copy(S, a, b - a + 1);
end;

function TrailingSepLength(const Line: string; p: Integer): Integer;
var i, n, q, braces, brackets: Integer; inner: string;
begin
  Result := 0;
  n := Length(Line);
  if (p > n) or (Line[p] <> '<') then Exit;

  { Walk to the closing `>`, and refuse the moment the candidate contains something that
    would have ENDED THE PART before this `<` ever came up. The engine splits a permutation
    into parts first -- SplitTopLevel, signed brace and bracket counters, a split only where
    both are zero -- and looks for a trailing separator afterwards. A forward scan that
    ignores that paints a construct the engine does not see, and worse, swallows the very
    characters that carry the structure: the top-level `|` in `[a< | >|b]` (three options to
    the engine, no separator) and the `]` that actually closes the permutation in
    `[A<]>|B]`. Measured against the engine on both. }
  braces := 0;
  brackets := 0;
  i := p + 1;
  while i <= n do
  begin
    case Line[i] of
      '>': if (braces = 0) and (brackets = 0) then Break else Exit;
      '<': Exit;                      { the separator is the LAST `<...>`, not this one }
      '|': if (braces = 0) and (brackets = 0) then Exit;
      '{': Inc(braces);
      '}': begin Dec(braces); if braces < 0 then Exit; end;
      '[': Inc(brackets);
      ']': begin Dec(brackets); if brackets < 0 then Exit; end;
    end;
    Inc(i);
  end;
  if (i > n) or (Line[i] <> '>') then Exit;

  inner := SepTrim(Copy(Line, p + 1, i - p - 1));
  if (inner <> '') and ((inner[1] = '/') or (inner[Length(inner)] = '/')) then Exit;
  { `^[A-Za-z][A-Za-z0-9]*\s` -- a tag name followed by whitespace. The engine's class HERE
    is the narrower one, four characters, and that is not the same class as the trim above. }
  if (Length(inner) >= 2) and (inner[1] in ['A'..'Z', 'a'..'z']) then
  begin
    q := 2;
    while (q <= Length(inner)) and (inner[q] in ['A'..'Z', 'a'..'z', '0'..'9']) do Inc(q);
    if (q <= Length(inner)) and (inner[q] in [' ', #9, #10, #13]) then Exit;
  end;

  { And the `|` that makes this element not the last one. The engine reaches it by rtrimming
    the part, so its blank class applies. }
  q := i + 1;
  while (q <= n) and IsSepBlank(Line[q]) do Inc(q);
  if (q > n) or (Line[q] <> '|') then Exit;
  Result := i - p + 1;
end;

{ `?name?` or `?!name?` directly after a `{`. }
function CondHeadLength(const Line: string; p: Integer): Integer;
var i, n: Integer;
begin
  Result := 0;
  n := Length(Line);
  if (p > n) or (Line[p] <> '?') then Exit;
  i := p + 1;
  if (i <= n) and (Line[i] = '!') then Inc(i);
  { The first byte must be a letter or underscore, and there must be one: a digit-leading
    name, or no name at all, is NOT a conditional to the engine -- it falls through to a
    plain enumeration whose first option happens to start with a question mark. Colouring
    it as a conditional would show a branch that does not exist. }
  if (i > n) or not (Line[i] in ['A'..'Z', 'a'..'z', '_']) then Exit;
  Inc(i);
  while (i <= n) and IsWordByte(Line[i]) do Inc(i);
  if (i <= n) and (Line[i] = '?') then Result := i - p + 1;
end;

{ `plural <count>:` directly after a `{`, where the count is a macro or a number. The colon
  is part of the head; the forms after it are ordinary content. }
function PluralHeadLength(const Line: string; p: Integer): Integer;
var i, n: Integer;
begin
  Result := 0;
  n := Length(Line);
  if Copy(Line, p, 7) <> 'plural ' then Exit;
  i := p + 7;
  while (i <= n) and (Line[i] <> ':') and (Line[i] <> '|') and (Line[i] <> '}') do Inc(i);
  if (i <= n) and (Line[i] = ':') then Result := i - p + 1;
end;

{ Ported from the engine's own gate (ParsePermConfig, v0.3.3), because getting this wrong
  colours a user's HTML as configuration or their configuration as HTML. Two rules:

    * the closing `>` is found RESPECTING QUOTES, so `<sep="a>b">` is one config whose
      separator contains a `>`;
    * a leading HTML START TAG is content, not config -- `<li>…</li>` and `<br/>` stay in
      the permutation's text. Everything else is config: the key form (`minsize=`, `sep=`…)
      and the single-separator form (`<->`, `<separator>`, even `<xminsize=2>`) both are.

  ONE APPROXIMATION, and it is bounded: the engine looks for the closing `</name>` in the
  whole permutation, which may run past this line; a line-at-a-time scan can only look at
  the rest of THIS line. A multi-line `[<li>…` therefore colours as config where the engine
  would call it content. The self-closing and same-line cases -- which is how HTML inside a
  permutation is actually written -- are exact. }
function LooksLikeHtmlStartTag(const ConfigStr, Remaining: string): Boolean;
const WS = [' ', #9, #10, #11, #12, #13];   { JS \s restricted to ASCII, as the engine has it }
var t, nameLow, remLow: string; n, j, k: Integer;
begin
  Result := False;
  t := Trim(ConfigStr);
  if (t = '') or not (t[1] in ['A'..'Z', 'a'..'z']) then Exit;

  n := 1;
  while (n < Length(t)) and (t[n + 1] in ['A'..'Z', 'a'..'z', '0'..'9', '-']) do Inc(n);
  if n < Length(t) then
  begin
    if (t[n + 1] = '/') and (n + 1 = Length(t)) then
      { a bare self-closing tag }
    else if t[n + 1] in WS then
    begin
      { attributes, but a `>` among them means this was never one tag }
      for j := n + 2 to Length(t) do
        if t[j] = '>' then Exit;
    end
    else
      Exit;
  end;

  if t[Length(t)] = '/' then Exit(True);   { self-closing: no partner needed }

  { A start tag counts as HTML only when its closing partner follows. }
  nameLow := LowerCase(Copy(t, 1, n));
  remLow := LowerCase(Remaining);
  k := 1;
  repeat
    k := PosEx('</' + nameLow, remLow, k);
    if k = 0 then Exit;
    j := k + 2 + Length(nameLow);
    while (j <= Length(remLow)) and (remLow[j] in WS) do Inc(j);
    if (j <= Length(remLow)) and (remLow[j] = '>') then Exit(True);
    Inc(k);
  until False;
end;

function PermConfigLength(const Line: string; p: Integer): Integer;
var i, n: Integer; inQuote: Boolean;
begin
  Result := 0;
  n := Length(Line);
  if (p > n) or (Line[p] <> '<') then Exit;

  inQuote := False;
  i := p + 1;
  while i <= n do
  begin
    if Line[i] = '"' then inQuote := not inQuote
    else if (Line[i] = '>') and not inQuote then Break;
    Inc(i);
  end;
  if i > n then Exit;   { no closing '>' on this line }

  if LooksLikeHtmlStartTag(Copy(Line, p + 1, i - p - 1), Copy(Line, i + 1, MaxInt)) then Exit;
  Result := i - p + 1;
end;

{ The include anchor's gap class, `[ \t\n\r\f\x0B]` minus the newline members -- those are
  what the line split already consumed. }
function IsIncludeGap(c: Char): Boolean;
begin
  Result := (c = ' ') or (c = #9) or (c = #11) or (c = #12);
end;

{ True when everything from `from` to the end of the line is gap, so an `#include` before it
  is still waiting rather than finished or spoiled. An empty remainder counts. }
function GapToEnd(const Line: string; from: Integer): Boolean;
var i: Integer;
begin
  for i := from to Length(Line) do
    if not IsIncludeGap(Line[i]) then Exit(False);
  Result := True;
end;

{ The `#set` / `#def` / `#include` head, if this line starts with one. Returns the length of
  the keyword and leaves the rest of the line to the ordinary scan -- a directive VALUE is
  spintax like any other text, and colouring it as one is the point. }
function DirectiveKeywordLength(const Line: string; p: Integer): Integer;
var i, n: Integer;
begin
  Result := 0;
  n := Length(Line);
  { The family's include anchor allows `[ \t\n\r\f\x0B]+` between the keyword and its
    target, which is WIDER than the gap anywhere else in the language -- measured against
    the engine, `#include`+VT+`"frag"` and `#include`+FF+`"frag"` resolve, while `#set`+VT
    is not a directive at all. So the wide class is spelled out here and nowhere else.
    The newline members of that class are a KNOWN GAP: a target on the following line is an
    include to the engine and plain text to this scanner (see the unit header). }
  if (Copy(Line, p, 8) = '#include') and (p + 8 <= n) and
     (Line[p + 8] in [' ', #9, #11, #12]) then
    Exit(8);   { the target's own shape is gated by the quote rule below }

  if (Copy(Line, p, 5) = '#set ') or (Copy(Line, p, 5) = '#set'#9) or
     (Copy(Line, p, 5) = '#def ') or (Copy(Line, p, 5) = '#def'#9) then
  begin
    { A keyword alone is not a directive. `#set brand = Acme` -- the `%` forgotten -- is
      literal text to the engine, and the likeliest of all directive typos: colouring it
      bold blue would tell the user it worked. Require %name% and the `=` before saying so. }
    i := p + 4;
    while (i <= n) and ((Line[i] = ' ') or (Line[i] = #9)) do Inc(i);
    if VariableLength(Line, i) = 0 then Exit;
    Inc(i, VariableLength(Line, i));
    while (i <= n) and ((Line[i] = ' ') or (Line[i] = #9)) do Inc(i);
    if (i <= n) and (Line[i] = '=') then Result := 4;
  end;
end;

procedure SpxScanLine(const Line: string; var State: TSpxScanState; Tokens: TSpxTokenList);
var
  p, n, runStart, len, q: Integer;
  { The SPLIT level, counted the way the engine's SplitTopLevel counts it, for this line
    only: a signed brace depth, and one frame per `[` open on this line remembering the brace
    depth it was opened at. A trailing separator belongs to the innermost permutation at its
    own split level -- frame present AND the brace depth back where that frame started --
    which is what tells a separator in a permutation from the same text inside a brace group
    nested in one, where the pipe is not a part boundary at all.
    Line-local on purpose: what crosses a line stays a depth, which is what makes unbounded
    nesting free. }
  braceDepth, permTop: Integer;
  permFrames: array of Integer;

  procedure FlushText(upTo: Integer);
  var i: Integer;
  begin
    if upTo > runStart then
    begin
      Emit(Tokens, sptText, runStart, upTo - runStart, State.Depth);
      { Whitespace does not open a logical line; anything else does. }
      for i := runStart to upTo - 1 do
        if (Line[i] <> ' ') and (Line[i] <> #9) then
        begin
          State.LineEmpty := False;
          Break;
        end;
    end;
    runStart := upTo;
  end;

  { Emitting anything that is not a comment means the logical line has content, so a later
    `#set` on the same line is not a directive. }
  procedure Mark(Kind: TSpxTokenKind; Start, Len: Integer);
  begin
    Emit(Tokens, Kind, Start, Len, State.Depth);
    if Kind <> sptComment then State.LineEmpty := False;
  end;

  { A directive is anchored to the LOGICAL line -- the one that survives comment removal,
    because the engine scans comment-stripped text (SpExtractDirectives). So it is tried
    twice: at the head of the line, and again the moment a comment closes mid-line, while
    nothing but comments and blanks has been seen. Measured against the engine:
    `/# c #/#set %a% = 1` IS set(a), and so is `  /# c #/ #set %a% = 1`, while
    `text /# c #/#set %a% = 1` is not a directive on either side. }
  procedure TryDirectiveHead;
  var q, klen: Integer;
  begin
    if not State.LineEmpty then Exit;
    q := p;
    while (q <= n) and ((Line[q] = ' ') or (Line[q] = #9)) do Inc(q);
    if (q > n) or (Line[q] <> '#') then Exit;
    { `#include` with nothing but gap behind it on this line: the target is allowed to begin
      further down, so remember the wait and leave the keyword unpainted (see IncludeOpen). }
    if (Copy(Line, q, 8) = '#include') and GapToEnd(Line, q + 8) then
    begin
      State.IncludeOpen := True;
      Exit;
    end;
    klen := DirectiveKeywordLength(Line, q);
    if klen = 0 then Exit;
    FlushText(q);
    Mark(sptDirective, q, klen);
    p := q + klen;
    runStart := p;
  end;

  procedure Push;
  begin
    if State.Depth < SPX_MAX_DEPTH then Inc(State.Depth);
  end;

  procedure Pop;
  begin
    if State.Depth > 0 then Dec(State.Depth);
  end;

begin
  n := Length(Line);
  p := 1;
  runStart := 1;
  braceDepth := 0;
  permTop := 0;
  SetLength(permFrames, 8);

  { A source line that does not continue a comment starts a new LOGICAL line; one that does
    continues the old one, because the newline inside a comment is removed with it. }
  if not State.InComment then State.LineEmpty := True;

  { A comment carried over from an earlier line: everything up to `#/` belongs to it. }
  if State.InComment then
  begin
    while (p <= n) and not ((Line[p] = '#') and (p < n) and (Line[p + 1] = '/')) do Inc(p);
    if p <= n then
    begin
      Mark(sptComment, 1, p + 1);   // through the closing #/
      State.InComment := False;
      p := p + 2;
      runStart := p;
    end
    else
    begin
      Mark(sptComment, 1, n);
      Exit;
    end;
  end;

  (* THE WAITING INCLUDE'S TARGET, if this line carries it.

     Three outcomes, and the middle one is why this is a state and not a look-ahead: the line
     is all gap and the wait continues; the line opens with the quoted target and the wait is
     over; or the line is something else and there was never an include at all.

     After the target the engine allows only gap before the directive ends -- `#include` LF
     `"frag" junk` is NOT an include, measured -- so a target with anything else behind it is
     not claimed either.

     MEASURED AND DELIBERATELY NOT CLAIMED: the engine strips comments before it looks for
     directives, so `#include` LF `/# c #/ "frag"` and `#include` LF `"frag" /# c #/` are both
     real includes to it and neither is painted here. Claiming them would mean running the
     comment scanner inside this decision, and a comment that opens without closing carries
     the question onto further lines. Under-claiming is what this file is allowed to do;
     `SpxCount` reconciles its own count against the engine's and calls such a document a
     lower bound rather than a wrong promise. *)
  if State.IncludeOpen then
  begin
    q := p;
    while (q <= n) and IsIncludeGap(Line[q]) do Inc(q);
    if q > n then
    begin
      { All gap: still waiting. The line is ordinary text and the state survives it. }
      FlushText(n + 1);
      Exit;
    end;
    State.IncludeOpen := False;
    if Line[q] = '"' then
    begin
      len := q + 1;
      while (len <= n) and (Line[len] <> '"') do Inc(len);
      if (len <= n) and GapToEnd(Line, len + 1) then
      begin
        FlushText(q);
        Mark(sptString, q, len - q + 1);
        p := len + 1;
        runStart := p;
        FlushText(n + 1);
        Exit;
      end;
    end;
  end;

  TryDirectiveHead;
  p := runStart;

  while p <= n do
  begin
    case Line[p] of
      '/':
        if (p < n) and (Line[p + 1] = '#') then
        begin
          FlushText(p);
          { Runs to `#/` or to the end of the line, and then the next line continues it. }
          len := p + 2;
          while (len <= n) and not ((Line[len] = '#') and (len < n) and (Line[len + 1] = '/')) do
            Inc(len);
          if len <= n then
          begin
            Mark(sptComment, p, len + 2 - p);
            p := len + 2;
          end
          else
          begin
            Mark(sptComment, p, n - p + 1);
            State.InComment := True;
            p := n + 1;
          end;
          runStart := p;
          { The comment is gone from the logical line, so what follows may still be its
            head. Harmless when the comment ran to the end of the line: there is nothing
            left to test. }
          TryDirectiveHead;
          Continue;
        end;
      '%':
        begin
          len := VariableLength(Line, p);
          if len > 0 then
          begin
            FlushText(p);
            Mark(sptVariable, p, len);
            p := p + len;
            runStart := p;
            Continue;
          end;
        end;
      '"':
        begin
          { Only inside an #include head, where the target is the string. Elsewhere a quote
            is ordinary text and falls through. }
          if (Tokens.Count > 0) and (Tokens[Tokens.Count - 1].Kind = sptDirective) then
          begin
            len := p + 1;
            while (len <= n) and (Line[len] <> '"') do Inc(len);
            if len <= n then
            begin
              FlushText(p);
              Mark(sptString, p, len - p + 1);
              p := len + 1;
              runStart := p;
              Continue;
            end;
          end;
        end;
      '{':
        begin
          FlushText(p);
          Push;
          Inc(braceDepth);
          Mark(sptBraceOpen, p, 1);
          Inc(p);
          runStart := p;
          len := CondHeadLength(Line, p);
          if len > 0 then
          begin
            Mark(sptCondHead, p, len);
            p := p + len;
            runStart := p;
          end
          else
          begin
            len := PluralHeadLength(Line, p);
            if len > 0 then
            begin
              Mark(sptPluralHead, p, len);
              p := p + len;
              runStart := p;
            end;
          end;
          Continue;
        end;
      '}':
        begin
          FlushText(p);
          Mark(sptBraceClose, p, 1);
          Pop;
          { Signed, like the engine's own counter: an unmatched closer takes it below zero,
            and a pipe at a negative level is not a part boundary. }
          Dec(braceDepth);
          Inc(p);
          runStart := p;
          Continue;
        end;
      '<':
        { A trailing separator is a permutation's construct, so it is only coloured when the
          innermost bracket still open is a square one -- inside a brace group the engine
          leaves the same text alone, measured. Kinds are tracked for THIS LINE only: the state carried
          between lines is a depth, not a stack of kinds, and that is what keeps unbounded
          nesting free. So a permutation opened on an earlier line does not get this colour
          -- a missing colour, never a wrong one (see the unit header). }
        if (permTop > 0) and (braceDepth = permFrames[permTop - 1]) then
        begin
          len := TrailingSepLength(Line, p);
          if len > 0 then
          begin
            FlushText(p);
            Mark(sptTrailingSep, p, len);
            p := p + len;
            runStart := p;
            Continue;
          end;
        end;
      '[':
        begin
          FlushText(p);
          Push;
          if permTop = Length(permFrames) then SetLength(permFrames, permTop * 2);
          permFrames[permTop] := braceDepth;
          Inc(permTop);
          Mark(sptBracketOpen, p, 1);
          Inc(p);
          runStart := p;
          { `[ <minsize=2>a|b]` -- the engine left-trims before parsing the config, so the
            space does not disable it, and neither may the colouring. }
          q := p;
          while (q <= n) and (Line[q] in [' ', #9, #10, #11, #12, #13]) do Inc(q);
          len := PermConfigLength(Line, q);
          if len > 0 then
          begin
            FlushText(q);
            Mark(sptPermConfig, q, len);
            p := q + len;
            runStart := p;
          end;
          Continue;
        end;
      ']':
        begin
          FlushText(p);
          Mark(sptBracketClose, p, 1);
          Pop;
          if permTop > 0 then Dec(permTop);
          Inc(p);
          runStart := p;
          Continue;
        end;
      '|':
        begin
          FlushText(p);
          Mark(sptPipe, p, 1);
          Inc(p);
          runStart := p;
          Continue;
        end;
    end;
    Inc(p);
  end;

  FlushText(n + 1);
end;

end.
