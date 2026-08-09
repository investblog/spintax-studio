(*
 * SpxStrings -- what the window says, in the language it was asked for.
 *
 * The TEXT lives one language to a file (gui/lang/SpxTextsXx.pas) and the ids live in
 * SpxStrIds; this unit is what ties them together, holds the LENGTH BUDGETS, and remembers
 * which language is current. It used to be one array with two languages in it and said so:
 * "two fit comfortably; if a fifth arrives, this becomes a file". The site ships in fourteen,
 * so the fifth arrived.
 *
 * ENGLISH IS THE BASE, and that is a decision rather than a habit: it is the language the
 * spec's terms are already in (`seed`, `spintax`, `shingle`), it is the shorter of the two
 * almost everywhere, and a layout that fits the English will not fit the Russian by accident
 * -- the other way round it would, and the first translation would then break the strip. It
 * is also what a language with no file yet falls back to.
 *
 * LENGTH IS PART OF THE CONTRACT. A caption that sits in a computed position has a BUDGET in
 * code points, and the suite checks every language against it. Without that, a translation
 * silently overflows its control and the person who added it has no way to know; with it,
 * the build says so. Budget 0 means the string has room to be as long as it needs -- a
 * status line, a message box, a dialog title.
 *)
unit SpxStrings;

{$mode objfpc}{$H+}

interface

uses
  SpxStudio, SpxStrIds, SpxTextsEn, SpxTextsRu, SpxTextsDe, SpxTextsFr, SpxTextsEs, SpxTextsIt,
  SpxTextsPt, SpxTextsNl, SpxTextsTr, SpxTextsUk, SpxTextsBe,
  SpxTextsSr, SpxTextsHr, SpxTextsBs;

type
  { One language for the whole product. The enum itself lives in editor-core because the
    diagnostics panel's sentences are built there, on the worker thread; this is the same
    type, not a parallel one that has to be kept in step by hand. }
  TSpxLang = SpxStudio.TSpxLang;
  TSpxStr = SpxStrIds.TSpxStr;

{ The text for this id in the current language. Named Tr rather than S because Pascal does
  not distinguish case in identifiers, and half the procedures in the window keep a local
  `s` -- which silently shadowed the function and turned every call into a syntax error at
  best. }
function Tr(Id: TSpxStr): string;

(* Which language the window speaks. It is the USER'S setting and nothing else's: an
   interface that changed language because the document did was a surprise every time the
   locale box was touched, so the tie is now one of the choices rather than the rule. The
   default comes from the operating system, which is what a desktop application is expected
   to do; `spxUiFollow` is the setting that restores the old behaviour for someone who wants
   it. *)
procedure SpxSetUiLang(ALang: TSpxLang);
function SpxUiLang: TSpxLang;
function SpxUiLangFor(const Locale: string): TSpxLang;

{ What each language calls ITSELF. Endonyms are not translated -- a menu that offered
  "German" to a German is a menu written for someone else -- so this is one list rather than
  fourteen, and it is the only string table in the product with no language of its own. }
function SpxLangName(ALang: TSpxLang): string;

(* THE LOCALE BOX'S LIST, and it lives here rather than in the window for one reason: what a
   screen reader hears is a STRING, and a string the suite cannot read is a string nothing
   checks. The box used to hold bare tags -- `ru`, `en` -- and paint the endonym beside them,
   so the name was pixels and the box reported itself as two letters. The readable name moves
   into the item; the painting stays exactly as it was, because the drawing takes the tag from
   this table rather than from the item.

   THE ORDER IS THE BOX'S, NOT TSpxLang'S. The enum leads with English because English is the
   fallback; the box leads with Russian because these are the locales this product's readers
   write IN, and the list is a list of documents rather than of interfaces. Ten of them
   against the interface's fourteen, for the same reason.

   `SpxLocaleTag` is the one the ENGINE gets. Nothing may hand it a label: a locale of
   `Русский (ru)` is not a locale, `PluralArity` would answer for a language nobody named, and
   the preview would diverge from every other engine in the family with no diagnostic at all. *)
function SpxLocaleCount: Integer;
function SpxLocaleTag(AIndex: Integer): string;       { 'ru' -- what the engine is told }
function SpxLocaleEndonym(AIndex: Integer): string;   { 'Русский', or '' for a tag we cannot name }
function SpxLocaleLabel(AIndex: Integer): string;     { 'Русский (ru)' -- what the list SAYS }
function SpxLocaleIndexOf(const ATag: string): Integer;  { -1 when absent }

{ What the machine is set to, mapped onto the languages this product speaks. }
function SpxSystemLang: TSpxLang;

{ How many code points this id is allowed, or 0 for "as long as it needs". Exposed so the
  suite can check every language against it. }
function SpxStrBudget(Id: TSpxStr): Integer;

{ The raw text of an id in a NAMED language, for the suite. }
function SpxStrIn(ALang: TSpxLang; Id: TSpxStr): string;

implementation

uses
  { gettext is the RTL's, not the LCL's: this unit is compiled by plain fpc for the console
    suite as well as by lazbuild for the window, and Translations would be reachable to only
    one of the two. }
  SysUtils, gettext, Spintax;

var
  GLang: TSpxLang = spxLangEn;

const
  { What fits where. These are the strings placed by LayoutTopStrip and by the panels' own
    fixed coordinates; everything else is 0 and free to grow.

    A budget is the CONTROL's usable width divided by 7 px per code point, not the control's
    width: a check box spends about 18 px on its indicator and a button about 8 px on
    padding, so a 90 px check box holds ten characters and not thirteen. The earlier numbers
    were the outer widths, which is why several of them blessed a caption that overlapped its
    neighbour on screen.

    A string with a `%d` is measured with the digits SUBSTITUTED (six of them -- past that a
    variant count is not a caption problem), because 'matches: %d' fitting proves nothing
    about 'matches: 128 000'. A budgeted string must not carry `%s`: its width would then
    depend on a file name, and no fixed slot can promise that. The suite checks both rules. }
  BUDGETS: array[TSpxStr] of Integer = (
    { menus -- a menu grows to fit its longest item }
    0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0,
    { the View menu, then the language submenu }
    0, 0, 0,
    0, 0, 0, 0,
    { the group editor: its four rail faces are ICONS now, so the letters that used to be
      drawn on them are unread and their budget is 0 -- a translator asked for a two-character
      abbreviation of something nothing draws would be answering a question we stopped asking.
      The ids stay because this is a positional array and removing four of them means editing
      fourteen files to no visible end; the suite still checks the rest of the row. The panel
      is 300px wide and its labels wrap, so only the kind names are held to a width }
    0, 0, 0, 0, 0, 0,
    20, 20, 20, 20,
    0, 0, 0,
    0, 0, 0, 0, 0,

    { top strip, output half. The seed box is a 55px check box. Reroll and Copy are ICONS
      now and these two strings are their TOOLTIPS -- a tooltip sizes itself, so a budget
      there would only forbid a translator the natural phrase ('Neu würfeln', 'Opnieuw
      rollen') for no gain on screen. The two view names still have one, for the opposite
      reason: the switch that shows them cannot clip: it WIDENS, and every control to its
      left shifts along. 10 code points keeps that shift bounded. }
    5, 0, 0, 10, 10,
    { the fragment captions size themselves and sit between the chain and the switch }
    28, 32,

    { top strip, template half: the case box is 90px, the counter a 110px label -- and the
      counter's three captions are what a six-digit match count has to fit into }
    10, 15, 15, 15, 2,

    { tabs, the diagnostics columns (130/130/70px), and what a row says in the first two of
      them -- an item caption is indented about six pixels, a subitem is not. The level
      column was widened from 110 for the Slavic wave: "Studio напомена" needs fifteen and
      the distinction it carries -- the engine's finding or Studio's own -- is not something
      to abbreviate away. }
    14, 14, 14,
    17, 18, 10, 0,
    17, 17, 17, 18,

    { the variables panel: two headings above full-width grids, then its columns. The
      literal column is a checkbox with a title above it, and 90px holds ten characters }
    0, 0, 8, 10, 0, 10,

    { the variants panel. The three labels that name a field are hung off that field by
      PlaceLabels, so their room is the gap before it rather than a coordinate. }
    8, 4, 10, 14, 10,
    26, 26, 26, 7, 7,
    14, 14, 20, 17,
    { BOTH lines of this panel -- the progress line above the grid and the report below it --
      stretch to the pane's edge and keep their full text in a hint, so their sentences are
      free to be sentences. At the window's minimum width they still clip; the hint is what
      makes that recoverable. }
    0, 0, 0,
    0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,
    4, 8, 10, 0,

    { dialogs -- a title bar, a filter and a column heading all have room }
    0, 0, 0, 0, 0,
    0, 0, 0, 28, 0, 0,
    0, 0, 20, 0,

    { the status bar, then the preview's own two: the button is 90px and the line beside it
      runs from x=8 to the button at x=420 }
    0, 0, 0, 0, 0, 0,
    11, 57,
    { the close button's tooltip -- a tooltip sizes itself }
    0,
    { menu items, and a menu grows to fit its longest }
    0, 0, 0, 0, 0,
    { a menu item and a tooltip -- both size themselves }
    0, 0,
    { a submenu and its first entry }
    0, 0,
    { a status-bar sentence: the bar is the window's width and clips nothing }
    0,
    { the include group: a heading over a full-width grid, then a 140px target column and a
      110px state column. 12 rather than 10 because the state has to hold both a title and its
      widest value in every language -- French wants eleven for "Dans le jeu" and Spanish twelve
      for "sin conjunto", and the suite said so rather than the column finding out on screen }
    0, 12, 12, 10, 10, 12,
    { the help: a menu that grows to fit, its one item, a label the strip MEASURES rather than
      budgets (a TLabel does not know its own width when you ask), and a sentence that must
      carry %s -- which a budgeted string may not do at all }
    0, 0, 0, 0,
    { the offer strip: both are MEASURED and placed from the measurement, for the same
      reason -- and the button holds a whole verb phrase in fourteen languages }
    0, 0,
    { the About box: a menu item and a dialog caption, both of which size themselves }
    0,
    { the empty-group hints: whole sentences, wrapped in a panel that is as wide as it is }
    0, 0,

    { the About box: a paragraph that wraps in a label as wide as the dialog, and a heading
      over the attributions. Neither sits in a computed slot, so neither has a width to keep }
    0, 0,

    { the GSA import: two menu items (a menu grows to fit), a dialog filter that Windows
      parses rather than lays out, and four sentences in a message box that wraps them }
    0, 0, 0, 0, 0, 0, 0,

    { the possible-variant count: both carry %s, which a budgeted string may not do at all,
      and both are drawn into a label the strip already sizes }
    0, 0,

    { THE AI PANEL. Every caption here is either measured before it is placed (the labels over
      the three columns, and the three field names in the top strip), drawn into a button that
      is sized to its own text, or written into a status line that spans the panel. None sits
      in a slot fixed at a number, which is the only thing a budget protects against -- so
      giving these one would be a number that fails a translation for no reason on screen.
      The three columns of the allow-list grid ARE sized in code, but the grid scrolls and its
      columns are stretched to what is in them. }
    0, 0, 0, 0, 0, 0, 0,
    0, 0, 0,
    0, 0,
    0, 0, 0,
    0, 0, 0,
    0, 0, 0, 0, 0,
    0, 0, 0,
    0, 0, 0, 0, 0, 0, 0
  );

(* The table for a language, or English when that language has no file yet. The fallback is
   the point of the shape: a language is added by writing gui/lang/SpxTextsXx.pas and naming
   it here, and until then the window is English rather than blank. *)
function SpxStrIn(ALang: TSpxLang; Id: TSpxStr): string;
begin
  case ALang of
    spxLangRu: Result := TEXTS_RU[Id];
    spxLangDe: Result := TEXTS_DE[Id];
    spxLangFr: Result := TEXTS_FR[Id];
    spxLangEs: Result := TEXTS_ES[Id];
    spxLangIt: Result := TEXTS_IT[Id];
    spxLangPt: Result := TEXTS_PT[Id];
    spxLangNl: Result := TEXTS_NL[Id];
    spxLangTr: Result := TEXTS_TR[Id];
    spxLangUk: Result := TEXTS_UK[Id];
    spxLangBe: Result := TEXTS_BE[Id];
    spxLangSr: Result := TEXTS_SR[Id];
    spxLangHr: Result := TEXTS_HR[Id];
    spxLangBs: Result := TEXTS_BS[Id];
  else
    Result := TEXTS_EN[Id];
  end;
end;

function Tr(Id: TSpxStr): string;
begin
  Result := SpxStrIn(GLang, Id);
end;

procedure SpxSetUiLang(ALang: TSpxLang);
begin
  GLang := ALang;
end;

function SpxUiLang: TSpxLang;
begin
  Result := GLang;
end;

function SpxUiLangFor(const Locale: string): TSpxLang;
begin
  { editor-core's rule, not a second copy of it: the panel's sentences and the window's
    captions must never disagree about what language a document is in. }
  Result := SpxLangFor(Locale);
end;

function SpxLangName(ALang: TSpxLang): string;
const
  NAMES: array[TSpxLang] of string =
    ('English', 'Русский', 'Українська', 'Беларуская', 'Српски', 'Hrvatski', 'Bosanski',
     'Deutsch', 'Français', 'Español', 'Italiano', 'Português', 'Nederlands', 'Türkçe');
begin
  Result := NAMES[ALang];
end;

const
  SPX_LOCALES: array[0..9] of string =
    ('ru', 'uk', 'be', 'en', 'de', 'fr', 'es', 'sr', 'hr', 'bs');

function SpxLocaleCount: Integer;
begin
  Result := Length(SPX_LOCALES);
end;

function SpxLocaleTag(AIndex: Integer): string;
begin
  if (AIndex < Low(SPX_LOCALES)) or (AIndex > High(SPX_LOCALES)) then Exit('');
  Result := SPX_LOCALES[AIndex];
end;

function SpxLocaleEndonym(AIndex: Integer): string;
var tag: string; lang: TSpxLang;
begin
  Result := '';
  tag := SpxLocaleTag(AIndex);
  if tag = '' then Exit;
  lang := SpxLangFor(tag);
  { THE ROUND TRIP IS THE GUARD, not decoration. SpxLangFor answers spxLangEn for everything
    it does not recognise, so asking it for a tag the interface has no language for would
    gloss that tag `English`. Comparing the code back catches exactly that: a locale this
    product cannot name is shown bare, which is the same thing an unknown one does. }
  if SameText(SpxLangCode(lang), tag) then Result := SpxLangName(lang);
end;

function SpxLocaleLabel(AIndex: Integer): string;
var tag, name_: string;
begin
  tag := SpxLocaleTag(AIndex);
  if tag = '' then Exit('');
  name_ := SpxLocaleEndonym(AIndex);
  { The tag is in the label as well as the name, and both orders were considered: a reader
    hears the language first and the code as a qualifier, which is the way round a person
    asks the question. The box still DRAWS the tag alone when it is closed. }
  if name_ = '' then Result := tag else Result := name_ + ' (' + tag + ')';
end;

function SpxLocaleIndexOf(const ATag: string): Integer;
var i: Integer;
begin
  for i := Low(SPX_LOCALES) to High(SPX_LOCALES) do
    if SameText(SPX_LOCALES[i], ATag) then Exit(i);
  Result := -1;
end;

function SpxSystemLang: TSpxLang;
var lang, fallback: string;
begin
  { The engine's own normalisation over the OS's code, so `ru_RU` and `ru` land in one place
    the same way a document's locale does. }
  GetLanguageIDs(lang, fallback);
  if lang = '' then lang := fallback;
  Result := SpxLangFor(lang);
end;

function SpxStrBudget(Id: TSpxStr): Integer;
begin
  Result := BUDGETS[Id];
end;

end.
