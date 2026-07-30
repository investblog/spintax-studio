(*
 * SpxHelpNav -- every DECISION the help viewer makes, with no LCL in sight.
 *
 * The window can only draw. Which document a fourteen-language interface gets, which page a
 * diagnostic code lands on, what an href means, where the reader ends up when the interface
 * language changes, how a page fragment becomes a document the renderer will accept -- all of it
 * lives here, because the console suite compiles this unit and cannot compile a form. A rule
 * that lives in the panel is a rule nothing checks.
 *
 * ONE PAGE IS ONE SECTION and the two documents run parallel, which SpxHelpText's generator
 * refuses to write unless true. That is what lets a slug name the same section in both.
 *)
unit SpxHelpNav;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, SpxStudio, SpxHelpText;

type
  { What an href in a help page turns out to be. `hkNone` is the answer for anything this
    version does not route, which is deliberately most things. }
  TSpxHrefKind = (spxHrefNone, spxHrefSamePage, spxHrefOtherPage, spxHrefExternal);

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

{ What a clicked href means. `#a` is only ever same-page when this page really has that anchor:
  MakeAnchorVisible on an id whose element has no draw area reaches
  TIpHtmlNodeCore.MakeVisible's unguarded FAreaList[0] (iphtml.pas:4701-4715), and the panel
  should not find that out at runtime.

  Nothing emits a link today -- the generator refuses one and the suite checks no page contains
  `<a `. This exists so that the day one arrives, a test fails and points at the handler that
  has to grow, instead of the link silently doing nothing. }
function SpxHelpResolveHref(AHelpLang, AFromPage: Integer; const AHref: string;
  out AKind: TSpxHrefKind; out APage: Integer; out AAnchor: string): Boolean;

{ Where the reader lands when the help language changes under them: the same article if the new
  document has it -- and it does, for every code, by the generator's parallelism rule -- else
  the same section, else the beginning. Never a blank page and never a silent jump to page 0. }
procedure SpxHelpRelocate(AFromLang, AFromPage: Integer; const AFromAnchor: string;
  AToLang: Integer; out APage: Integer; out AAnchor: string);

{ A page fragment made into a document the renderer will accept.

  A BARE FRAGMENT MUST NEVER REACH IT (ADR 0004): with no element the panel goes black, and text
  before the first tag is silently lost -- worse than black, because black gets reported. The
  colours ride on <body> because a document that opens itself KEEPS its body attributes, which
  is the same measurement that decided the preview's wrapping rule.

  Not an extension of SpxPageDocument, deliberately: the preview pane's redraw cache is keyed on
  that function being a pure function of its argument, and its own comment says a theme would
  break that. No <head> either -- nothing to gain, and a charset there is a way to lose. }
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

{ Does this page carry that anchor? The guard SpxHelpResolveHref's comment explains. }
function PageHasAnchor(AHelpLang, APage: Integer; const AAnchor: string): Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to SpxHelpAnchorCount(AHelpLang) - 1 do
    if (SpxHelpAnchorPage(AHelpLang, i) = APage) and
       (SpxHelpAnchorId(AHelpLang, i) = AAnchor) then Exit(True);
end;

function SpxHelpResolveHref(AHelpLang, AFromPage: Integer; const AHref: string;
  out AKind: TSpxHrefKind; out APage: Integer; out AAnchor: string): Boolean;
var hash_: Integer; slug: string;
begin
  AKind := spxHrefNone;
  APage := -1;
  AAnchor := '';
  Result := False;
  if AHref = '' then Exit;

  { Anything with a scheme is somebody else's business. R0 is offline and packaged for the
    Store, and shelling out of a container is a decision of its own -- so it is named and
    ignored rather than half-done. }
  if (Pos('http://', LowerCase(AHref)) = 1) or (Pos('https://', LowerCase(AHref)) = 1) or
     (Pos('mailto:', LowerCase(AHref)) = 1) then
  begin
    AKind := spxHrefExternal;
    Exit(True);
  end;

  hash_ := Pos('#', AHref);
  if hash_ = 1 then
  begin
    AAnchor := Copy(AHref, 2, MaxInt);
    if not PageHasAnchor(AHelpLang, AFromPage, AAnchor) then
    begin
      AAnchor := '';
      Exit;
    end;
    AKind := spxHrefSamePage;
    APage := AFromPage;
    Exit(True);
  end;

  if hash_ > 1 then
  begin
    slug := Copy(AHref, 1, hash_ - 1);
    AAnchor := Copy(AHref, hash_ + 1, MaxInt);
  end
  else
  begin
    slug := AHref;
    AAnchor := '';
  end;
  APage := SpxHelpPageIndex(slug);
  if APage < 0 then
  begin
    AAnchor := '';
    Exit;
  end;
  if (AAnchor <> '') and not PageHasAnchor(AHelpLang, APage, AAnchor) then AAnchor := '';
  AKind := spxHrefOtherPage;
  Result := True;
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
