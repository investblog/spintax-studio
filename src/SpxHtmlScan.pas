(*
 * SpxHtmlScan -- where the HTML highlighter is wrong about the output, and by how much.
 *
 * SynEdit's TSynHTMLSyn opens a tag at EVERY `<`. Measured on the pinned Lazarus: given
 * `<p>Цена < 100 рублей.</p>` it colours everything after the bare `<` as tag attributes and
 * does not recognise the real `</p>` that follows; given a `<` with no `>` for three lines,
 * all three lines go the colour of an attribute name. The rest of the family -- and HTML5's
 * own tokenizer -- opens a tag only when the `<` is followed by a letter, `/`, `!` or `?`;
 * anything else is text, which is why a browser shows `a < b` as `a < b`.
 *
 * The tokenizer cannot be corrected from outside: fProcTable, MakeMethodTables and
 * BraceOpenProc are all in TSynHTMLSyn's PRIVATE section, so a descendant cannot reach them,
 * and vendoring 2600 lines of LCL to change one branch is a maintenance debt out of all
 * proportion to a colour. So the spans it gets wrong are computed here and painted over --
 * which is also why this lives in editor-core rather than beside the markup: it is a rule
 * about text, the suite can gate it, and no window is needed to say what it does.
 *
 * POSITIONS ARE BYTES, not code points, and that is not the usual sloppiness: `<` and `>`
 * are ASCII, the caller is SynEdit, and SynEdit's logical columns are byte offsets. Nothing
 * here has to know what a code point is.
 *
 * Worth being honest about one thing: editor-core is GUI-free so that the toolkit choice stays
 * contained, and this unit is here entirely because of one LCL component. It earns its place
 * by being a rule about TEXT that the console suite can gate -- but if SynEdit ever goes, this
 * goes with it.
 *)
unit SpxHtmlScan;

{$mode objfpc}{$H+}

interface

type
  { Half-open, in the editor's own coordinates: 1-based line, 1-based byte column, EndCol
    exclusive. A span may cross lines -- one stray `<` before a paragraph of prose is
    precisely the case that hurts. }
  TSpxSpan = record
    Line, Col: Integer;
    EndLine, EndCol: Integer;
  end;
  TSpxSpans = array of TSpxSpan;

{ Every run of text the HTML highlighter will colour as a tag although the family reads it as
  text. The span starts at the bare `<` and ends where the highlighter itself returns to
  text -- which, measured against the real tokenizer, is one of three places:

    * the `>` that closes the phantom tag (inclusive: that `>` is coloured as a symbol);
    * an `&`, because AmpersandProc ends `fRange := rsText` unconditionally, whatever range it
      was called in. Running past it would repaint the entity -- `&nbsp;` is green and bold in
      this scheme, and this project's own demo template opens with one -- so the run stops
      BEFORE the `&`;
    * a `<` that opens a real tag AND stands at a token boundary. The boundary matters: in a
      tag's parameter range IdentProc scans `until fLine[Run] in [#0..#32, '=', '"', '>']`,
      and `<` is not in that set, so `rub.</p` is swallowed into one identifier and the tag is
      NOT recognised. An earlier version of this stopped at every `<`, which left exactly that
      `</p` mis-coloured -- in the change's own headline example.

  What it does not model, deliberately: the first identifier after a phantom `<` is scanned by
  IdentKind, which DOES stop at `<`, so `a < b<br>c` recovers at `<br>` and this reports the
  run as continuing to the `>`. The cost is one tag painted as text; the alternative is a
  second copy of the tokenizer's range machine living here. }
function SpxHtmlPhantomTags(const Text: string): TSpxSpans;

implementation

{ HTML5 section 13.2.5.6: after `<`, a letter opens a start tag, `/` an end tag, `!` a markup
  declaration and `?` a bogus comment. Everything else -- a digit, a space, `=`, the end of
  the line -- is a literal `<`. Deliberately ASCII-only: a Cyrillic letter after `<` does not
  open a tag in any browser either.

  `%` is in the list although HTML5 says otherwise: `<%` is SynEdit's ASP branch, which it
  colours on purpose, and this unit exists to undo what the highlighter gets WRONG rather than
  to argue with what it does deliberately. }
function OpensTag(C: Char): Boolean;
begin
  Result := ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
            (C = '/') or (C = '!') or (C = '?') or (C = '%');
end;

function SpxHtmlPhantomTags(const Text: string): TSpxSpans;
var
  i, n, line, col, count_: Integer;

  { One step through the text, keeping line and column with it. The editor's three line
    endings -- LF, CRLF, CR -- because these positions are handed to SynEdit and it counts
    those three (the engine's five-terminator rule is for directives, a different question
    and a different consumer). }
  procedure Step;
  begin
    if (Text[i] = #13) or (Text[i] = #10) then
    begin
      if (Text[i] = #13) and (i < n) and (Text[i + 1] = #10) then Inc(i);
      Inc(line);
      col := 1;
      Inc(i);
    end
    else
    begin
      Inc(i);
      Inc(col);
    end;
  end;

  procedure Add(ALine, ACol, AEndLine, AEndCol: Integer);
  begin
    if count_ = Length(Result) then SetLength(Result, 8 + count_ * 2);
    Result[count_].Line := ALine;
    Result[count_].Col := ACol;
    Result[count_].EndLine := AEndLine;
    Result[count_].EndCol := AEndCol;
    Inc(count_);
  end;

  function Matches(P: Integer; const What: string): Boolean;
  var k: Integer;
  begin
    Result := P + Length(What) - 1 <= n;
    if not Result then Exit;
    for k := 1 to Length(What) do
      if Text[P + k - 1] <> What[k] then Exit(False);
  end;

  { Past a terminator that is more than one character -- `-->`, `]]>`, `%>`. Ending such a
    construct at the first `>`, as this used to, drops the scan back INTO a comment and the
    next `<` there becomes a phantom that is not one: `<!-- if a > b then c < d -->` is a
    single comment token to the highlighter. }
  procedure StepPast(const Term: string);
  var k: Integer;
  begin
    while (i <= n) and not Matches(i, Term) do Step;
    for k := 1 to Length(Term) do
      if i <= n then Step;
  end;

  { Does a token end just before P? The highlighter recognises a tag only where its scan
    stopped, and IdentProc stops on exactly this set. }
  function AtTokenBoundary(P: Integer): Boolean;
  begin
    Result := (P <= 1) or (Text[P - 1] in [#0..#32, '=', '"', '>']);
  end;

  { A `<` the highlighter opens something at. Everything between it and its terminator is
    that construct's own business, and none of it is a phantom. }
  procedure SkipMarkup;
  begin
    if Matches(i + 1, '!--') then
    begin
      StepPast('-->');
      Exit;
    end;
    if Matches(i + 1, '![CDATA[') then
    begin
      StepPast(']]>');
      Exit;
    end;
    if Text[i + 1] = '%' then
    begin
      StepPast('%>');
      Exit;
    end;
    { An ordinary tag, or a declaration: to its `>`, honouring a double-quoted value on the
      way. Only DOUBLE quotes, and only to the end of the line -- StringProc is mapped to `"`
      alone and stops at #10/#13, so a lone apostrophe in `<!-- don't -->` is not a string and
      an unterminated `"` does not swallow the document. Both of those used to. }
    Step;
    while i <= n do
    begin
      if Text[i] = '"' then
      begin
        Step;
        while (i <= n) and (Text[i] <> '"') and (Text[i] <> #10) and (Text[i] <> #13) do Step;
        if (i <= n) and (Text[i] = '"') then Step;
      end
      else if Text[i] = '>' then
      begin
        Step;
        Exit;
      end
      else if (Text[i] = '<') and AtTokenBoundary(i) then
        { `<` at a token boundary goes to BraceOpenProc whatever range the highlighter is in,
          so an unterminated tag does not run on forever: `<a title="oops` followed by a line
          of prose leaves that prose mis-coloured, and the run has to start again there. }
        Exit
      else
        Step;
    end;
  end;

var
  startLine, startCol: Integer;
begin
  Result := nil;
  count_ := 0;
  n := Length(Text);
  i := 1;
  line := 1;
  col := 1;
  while i <= n do
  begin
    if Text[i] <> '<' then
    begin
      Step;
      Continue;
    end;

    if (i < n) and OpensTag(Text[i + 1]) then
    begin
      SkipMarkup;
      Continue;
    end;

    startLine := line;
    startCol := col;
    Step;
    while i <= n do
    begin
      if Text[i] = '>' then
      begin
        Step;   { the `>` itself is inside the wrongly-coloured run }
        Break;
      end;
      { the highlighter is back to text from here -- see the header }
      if Text[i] = '&' then Break;
      if (Text[i] = '<') and (i < n) and OpensTag(Text[i + 1]) and AtTokenBoundary(i) then
        Break;
      Step;
    end;
    Add(startLine, startCol, line, col);
  end;
  SetLength(Result, count_);
end;

end.
