(*
 * SpxHelpNav -- every DECISION the help viewer makes, with no LCL in sight.
 *
 * The window can only draw. Which document a fourteen-language interface gets, which page a
 * diagnostic code lands on, where the reader ends up when the interface language changes -- all
 * of it lives here, because the console suite compiles this unit and cannot compile a form. A
 * rule that lives in the panel is a rule nothing checks.
 *
 * WHAT A LINK MEANS is not here: every link in the help is `ex:N` and SpxHelpText answers it
 * from a table its generator filled, so nothing at run time parses anything.
 *
 * ONE PAGE IS ONE SECTION and the two documents run parallel, which SpxHelpText's generator
 * refuses to write unless true. That is what lets a slug name the same section in both.
 *)
unit SpxHelpNav;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, SpxStudio, SpxGroups, SpxTokens, SpxHelpText;

{ The help document for an interface language: itself when there is one, ENGLISH otherwise.

  English rather than "the nearest relative" for uk/be/sr/hr/bs, because that is already the
  product's rule -- SpxStrIn falls back to the English table for a language with no file of its
  own. A second, different fallback here would be a surprise, and deciding that a Ukrainian
  reads Russian is the kind of judgement this project refuses to make elsewhere (a flag is a
  country, a menu item is a language). One rule. }
function SpxHelpLangFor(ALang: TSpxLang): Integer;

{ Is there a document in the reader's own language, or did the line above fall back? The viewer
  has to SAY so -- fourteen interface languages and two documents means twelve readers are
  being shown something other than what they asked for, and being told is the difference
  between a limitation and a bug. }
function SpxHelpIsTranslated(ALang: TSpxLang): Boolean;

{ The article for a diagnostic code: the page it is on and the anchor to scroll to.

  False for a code with no article -- an empty code, or one from an engine newer than this
  build. The caller opens the contents rather than nothing, because a gesture that does nothing
  reads as broken. The suite proves the shipped codes all resolve, so False means genuinely
  new. }
function SpxHelpTargetFor(AHelpLang: Integer; const ACode: string;
  out APage: Integer; out AAnchor: string): Boolean;

{ WHAT THE CARET IS STANDING ON, as an article to open.

  Two levels, and the first is exact. A caret INSIDE A DIAGNOSTIC'S SPAN opens that diagnostic's
  article -- the rows already carry the code and the same span the squiggle is drawn from, so
  nothing is parsed and nothing is guessed. Standing on what is wrong and asking why is the case
  worth being exact about.

  With no diagnostic there, the CONSTRUCT decides: SpxGroupAt gives the innermost group the caret
  is inside and its kind, and a directive or a variable is read from the line's own tokens. Those
  point at a chapter rather than an article, which is the honest resolution -- the reader is on a
  brace, not on a fault.

  False when neither applies: an empty document, plain prose, a comment. The caller opens the
  contents, which is what "help me" means when there is nothing to be specific about.

  Here rather than in the window because it is a RULE, and the console suite compiles this.

  AText and AOffset must be the SAME text: the editor's own, with the editor's line endings.
  Handing over the normalised copy while counting the caret in the editor's put the offset a
  line-ending's difference out per line -- twenty bytes into a twenty-line document, silently,
  so the feature simply degraded with depth. The group editor pairs them correctly and is the
  shape to copy.

  ACol is a BYTE column, which is what SynEdit's logical coordinates are. The findings count
  CODE POINTS, so they are converted here rather than at the caller -- the caller had them in
  different units and compared them anyway, which worked in Latin and lost the article in every
  Cyrillic document. }
function SpxHelpForCaret(const AText: string; AOffset, ALine, ACol: Integer;
  const ARows: TSpxPanelRows; AHelpLang: Integer;
  out APage: Integer; out AAnchor: string): Boolean;

{ Where the reader lands when the help language changes under them: the same article if the new
  document has it -- and it does, for every code, by the generator's parallelism rule -- else
  the same section, else the beginning. Never a blank page and never a silent jump to page 0. }
procedure SpxHelpRelocate(AFromLang, AFromPage: Integer; const AFromAnchor: string;
  AToLang: Integer; out APage: Integer; out AAnchor: string);

{ A page fragment made into a document the renderer will accept.

  A BARE FRAGMENT MUST NEVER REACH IT (ADR 0004): with no element the panel goes black, and text
  before the first tag is silently lost -- worse than black, because black gets reported. The
  colours ride on <body> because a document that opens itself KEEPS its body attributes, which is
  the same measurement that decided the preview's wrapping rule.

  Here rather than in the panel because it is a RULE, and a rule in a panel is a rule the suite
  cannot reach. Not an extension of SpxPageDocument, deliberately: the preview's redraw cache is
  keyed on that function staying pure of settings and themes, and its own comment says so. No
  <head> either -- nothing to gain, and a charset there is a way to lose. }
function SpxHelpDocument(const ABody, ABack, AText, ALink: string): string;

{ FNV-1a, 64-bit, of a string's bytes -- the drift check between a help document and the unit
  generated from it. Not sha1: `hash` is an FPC package rather than the RTL, and a check that
  fails to COMPILE somewhere would be the gate breaking for a reason unrelated to the help.
  scripts/make-help.py holds the same eight lines, and the suite pins a vector so the two
  cannot drift from each other while checking that nothing else does. }
function SpxHelpDigest(const AText: string): string;

implementation

function SpxHelpLangFor(ALang: TSpxLang): Integer;
begin
  Result := SpxHelpLangIndex(SpxLangCode(ALang));
  if Result < 0 then Result := SpxHelpLangIndex('en');
  if Result < 0 then Result := 0;
end;

function SpxHelpIsTranslated(ALang: TSpxLang): Boolean;
begin
  Result := SpxHelpLangIndex(SpxLangCode(ALang)) >= 0;
end;

function SpxHelpTargetFor(AHelpLang: Integer; const ACode: string;
  out APage: Integer; out AAnchor: string): Boolean;
var i: Integer;
begin
  APage := -1;
  AAnchor := '';
  Result := False;
  if ACode = '' then Exit;
  for i := 0 to SpxHelpAnchorCount(AHelpLang) - 1 do
    if SpxHelpAnchorIsCode(AHelpLang, i) and (SpxHelpAnchorId(AHelpLang, i) = ACode) then
    begin
      APage := SpxHelpAnchorPage(AHelpLang, i);
      AAnchor := ACode;
      Exit(True);
    end;
end;

procedure SpxHelpRelocate(AFromLang, AFromPage: Integer; const AFromAnchor: string;
  AToLang: Integer; out APage: Integer; out AAnchor: string);
var i: Integer; slug: string;
begin
  APage := 0;
  AAnchor := '';
  if AFromAnchor <> '' then
    for i := 0 to SpxHelpAnchorCount(AToLang) - 1 do
      if SpxHelpAnchorId(AToLang, i) = AFromAnchor then
      begin
        APage := SpxHelpAnchorPage(AToLang, i);
        AAnchor := AFromAnchor;
        Exit;
      end;
  { The article is gone -- a prose heading, whose id is positional and may not survive an edit.
    The SECTION still exists, because the two documents are parallel by construction. }
  slug := SpxHelpPageSlug(AFromPage);
  if slug <> '' then
  begin
    i := SpxHelpPageIndex(slug);
    if i >= 0 then APage := i;
  end;
end;

function SpxHelpDocument(const ABody, ABack, AText, ALink: string): string;
begin
  Result := '<html><body bgcolor="' + ABack + '" text="' + AText + '" link="' + ALink + '">' +
            ABody + '</body></html>';
end;

(* Is the caret ON this finding?

  A FINDING IS USUALLY A POINT, not a span -- measured: `цена {дешёвая|дорогая` reports
  bracket.unclosed at 1:6..1:7, the brace and nothing else, because that is where the engine can
  say the construct BEGINS. It has no end to report: an unclosed group runs to the end of the
  text by definition, and SpxGroupAt refuses an unpaired bracket outright (it is the validator's
  finding, not something to offer an edit for).

  So a point finding covers the rest of its line. A caret two words into the unclosed group is
  standing on that group, and answering "nothing here" would be answering about the letter under
  the caret rather than about the construct. A finding with a real span is honoured as a span.

  A row with no position covers nothing, and a row belonging to another FILE covers nothing
  here: the caret is in this document.

  This comment is a star-paren one because it QUOTES the language, and this language is made of
  braces -- an opening brace inside a brace comment ends it at the first closing one, and FPC
  counts the nesting rather than refusing. Third time in this project. *)
{ Does the line begin with this directive AS A WORD? The engine takes anything else as plain
  text, so a chapter about directives would be the wrong answer about the reader's own line. }
function Keyword(const AHead, AWord: string): Boolean;
var after: Char;
begin
  Result := False;
  if Copy(AHead, 1, Length(AWord)) <> AWord then Exit;
  if Length(AHead) = Length(AWord) then Exit(True);
  after := AHead[Length(AWord) + 1];
  Result := (after = ' ') or (after = #9);
end;

{ One line of a document, by number, 1-based. The three terminators the editor counts. }
function LineOf(const AText: string; ALine: Integer): string;
var i, n: Integer;
begin
  Result := '';
  if (ALine < 1) or (AText = '') then Exit;
  i := 1;
  n := 1;
  while (i <= Length(AText)) and (n < ALine) do
  begin
    if AText[i] = #13 then
    begin
      Inc(n);
      if (i < Length(AText)) and (AText[i + 1] = #10) then Inc(i);
    end
    else if AText[i] = #10 then Inc(n);
    Inc(i);
  end;
  if n <> ALine then Exit;
  while (i <= Length(AText)) and (AText[i] <> #13) and (AText[i] <> #10) do
  begin
    Result := Result + AText[i];
    Inc(i);
  end;
end;

function RowCovers(const AText: string; const ARow: TSpxPanelRow;
  ALine, ACol: Integer): Boolean;
var pointOnly: Boolean; startCol, endCol: Integer;
begin
  Result := False;
  if (ARow.Line <= 0) or (ARow.Slug <> '') then Exit;
  if ALine < ARow.Line then Exit;
  { The finding's columns are CODE POINTS and the caret's is BYTES -- converted here, on the
    finding's own line, because that is the line its column counts along. }
  startCol := SpxByteColumn(LineOf(AText, ARow.Line), ARow.Column);
  if ARow.EndLine > 0 then
    endCol := SpxByteColumn(LineOf(AText, ARow.EndLine), ARow.EndColumn)
  else
    endCol := 0;
  pointOnly := (ARow.EndLine <= ARow.Line) and (ARow.EndColumn <= ARow.Column + 1);
  if pointOnly then
  begin
    Result := (ALine = ARow.Line) and (ACol >= startCol);
    Exit;
  end;
  if (ARow.EndLine > 0) and (ALine > ARow.EndLine) then Exit;
  if (ALine = ARow.Line) and (ACol < startCol) then Exit;
  if (ARow.EndLine = ALine) and (endCol > 0) and (ACol > endCol) then Exit;
  Result := True;
end;

{ The chapter a construct belongs to. A slug rather than an article: the reader is standing on a
  brace, not on a fault, and pretending to know which of the brace articles they meant would be
  worse than opening the chapter that holds all three. }
function SlugForCaret(const AText: string; AOffset: Integer): string;
var group: TSpxGroup; line, head: string; i, from_: Integer;
begin
  Result := '';
  if SpxGroupAt(AText, AOffset, group) then
  begin
    case group.Kind of
      spxGroupPlural: Result := 'plurals';
      spxGroupPermutation: Result := 'permutations';
    else
      { A choice and a conditional are both braces, and the brackets chapter is what explains
        what a brace is and how it fails. }
      Result := 'brackets';
    end;
    Exit;
  end;

  { Not in a group. The LINE decides: a directive is line-anchored in this language, so what
    the line starts with is the whole question. }
  { CLAMPED AT BOTH ENDS. The top end was there from the start; the bottom was not, and an
    EMPTY document drove it to zero and read AText[0]. Two access violations from one habit --
    guarding the end a caret can run past and forgetting the one it can run before. }
  if AText = '' then Exit;
  from_ := AOffset;
  if from_ > Length(AText) then from_ := Length(AText);
  if from_ < 1 then from_ := 1;
  i := from_;
  while (i > 1) and (AText[i - 1] <> #10) and (AText[i - 1] <> #13) do Dec(i);
  line := '';
  head := '';
  while (i <= Length(AText)) and (AText[i] <> #10) and (AText[i] <> #13) do
  begin
    line := line + AText[i];
    Inc(i);
  end;
  { THE KEYWORD MUST END, not merely start the line. `#includes "x"`, `#setting up the shop`
    and `#definitely not a directive` are all plain text to the engine, and answering with a
    chapter about directives would be teaching the reader something untrue about their own
    line. The engine narrowed `#include` to the family's anchor in v0.2.1 for the same reason. }
  head := LowerCase(TrimLeft(line));
  if Keyword(head, '#include') then Exit('includes');
  if Keyword(head, '#set') or Keyword(head, '#def') then Exit('definitions');
  { A variable is not line-anchored, so it is the only one that has to be looked for around the
    caret rather than at the line's head.

    FROM THE CLAMPED OFFSET, not the caller's: the first version scanned back from AOffset
    itself, and a caret past the end of the text -- which the suite asks about, because a window
    can hand one over -- walked off the string. An access violation, found by the check that
    exists for exactly that. }
  i := from_;
  if (i >= 1) and (i <= Length(AText)) and (AText[i] = '%') then Exit('variables');
  { BOTH terminators, like the line-head scan above. Treating only LF as a barrier made a
    CR-only file -- which SpxDetectEol supports -- look for the opening per cent sign on the
    previous line. Measured. }
  while (i > 1) and (AText[i - 1] <> '%') and (AText[i - 1] <> #10) and
        (AText[i - 1] <> #13) do Dec(i);
  if (i > 1) and (AText[i - 1] = '%') then
  begin
    while (i <= Length(AText)) and (AText[i] <> #10) and (AText[i] <> #13) do
    begin
      if AText[i] = '%' then Exit('variables');
      Inc(i);
    end;
  end;
end;

function SpxHelpForCaret(const AText: string; AOffset, ALine, ACol: Integer;
  const ARows: TSpxPanelRows; AHelpLang: Integer;
  out APage: Integer; out AAnchor: string): Boolean;
var i, best: Integer; slug: string; tried: array of Boolean;
begin
  APage := -1;
  AAnchor := '';
  Result := False;

  { THE EXACT CASE FIRST, and the NEAREST of them: two findings can cover one caret when both
    are points on the same line, and the one that starts closer to the left is the one the caret
    is actually standing inside. }
  { THE NEAREST COVERING ROW WINS, and if its code has no article the NEXT nearest is tried
    rather than the whole exact case being abandoned -- a caret covered by both a known finding
    and one from a newer engine used to answer nothing at all. }
  SetLength(tried, Length(ARows));
  repeat
    best := -1;
    for i := Low(ARows) to High(ARows) do
      if (not tried[i]) and RowCovers(AText, ARows[i], ALine, ACol) and
         ((best < 0) or (ARows[i].Column > ARows[best].Column)) then best := i;
    if best < 0 then Break;
    if SpxHelpTargetFor(AHelpLang, ARows[best].Code, APage, AAnchor) then Exit(True);
    tried[best] := True;
  until False;

  slug := SlugForCaret(AText, AOffset);
  if slug = '' then Exit;
  APage := SpxHelpPageIndex(slug);
  if APage < 0 then Exit;
  Result := True;
end;

{ THE WRAPAROUND IS THE ALGORITHM. FNV multiplies modulo 2^64, so overflow is not a mistake to
  be caught -- and the suite's second binary is built with -Co -Cr, which turned the first
  multiplication into an EIntOverflow and killed the run. Off for these four lines only, which
  is why it is push/pop rather than a switch at the top of the unit. }
{$push}{$Q-}{$R-}
function SpxHelpDigest(const AText: string): string;
const
  FNV_OFFSET = QWord($CBF29CE484222325);
  FNV_PRIME  = QWord($100000001B3);
var i: Integer; h: QWord;
begin
  h := FNV_OFFSET;
  for i := 1 to Length(AText) do
  begin
    h := h xor QWord(Byte(AText[i]));
    h := h * FNV_PRIME;
  end;
  Result := LowerCase(IntToHex(h, 16));
end;
{$pop}

end.
