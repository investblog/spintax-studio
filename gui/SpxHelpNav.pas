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
  SysUtils, SpxStudio, SpxHelpText;

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
