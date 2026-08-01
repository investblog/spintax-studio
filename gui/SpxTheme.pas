(*
 * SpxTheme -- the two colour tables the editor draws with.
 *
 * WHAT IS AND IS NOT THEMED. The template editor and the source view, and nothing else. The
 * preview shows the user's own HTML as it will be published, so darkening it would misreport
 * the work; the window's chrome is not themed because LCL has no dark mode on Windows and the
 * menu bar, the combo box and the status bar are drawn by the system -- a dark window with a
 * light menu over it looks worse than a light window.
 *
 * THE LIGHT TABLE IS THE SYSTEM'S WHEREVER IT CAN BE. Background, text, selection and gutter
 * are clWindow / clWindowText / clHighlight / clBtnFace rather than literals, so a person
 * running a high-contrast Windows theme gets their own colours and not our idea of white.
 * Only the syntax colours are ours in light, because there is no system colour for "this is a
 * directive". The dark table is entirely ours: Windows offers nothing to derive it from.
 *
 * The dark syntax colours are the ones VS Code's own dark theme uses for the same ROLES --
 * not because they are famous but because they are the set most people's eyes are already
 * trained on, and every one of them is contrast-checked against #1E1E1E by its authors.
 *)
unit SpxTheme;

{$mode objfpc}{$H+}

interface

uses
  Graphics, SpxSettings;

type
  TSpxPalette = record
    { the page }
    Back, Text: TColor;
    { the syntax }
    Comment, Directive, Str, Variable, Pipe, Cond, Plural, Config: TColor;
    Nest: array[0..3] of TColor;
    { the furniture }
    Gutter, GutterText, Sel, SelText, BracketBack, BracketText: TColor;
    { The wash a jump leaves on the line it landed on, for as long as it takes to notice. It
      is the whole ROW, not the text -- SynEdit's own current-line highlight, the one the IDE
      uses -- so it has to be faint: a background strong enough to read as a state would make
      the editor look like it had selected something. }
    Flash: TColor;
    { the source view's HTML }
    HtmlTag, HtmlAttr, HtmlValue, HtmlComment, HtmlEntity: TColor;
  end;

(* THE THEME THE USER PICKED, unless the DESKTOP has asked for something louder.

   AHighContrast overrides both tables rather than sitting beside them: a Windows contrast
   theme is an accessibility setting, not a colour preference, and an application that
   answered it with its own idea of dark would be answering a different question. It is
   computed at runtime (SpxHighContrast) and never stored -- TSpxTheme stays the two values
   that go in the settings file, so turning the desktop's contrast off cannot leave this
   application stranded in a theme nobody chose, on a settings file that crosses machines. *)
function SpxPalette(ATheme: TSpxTheme; AHighContrast: Boolean = False): TSpxPalette;

(* THE WINDOW'S OWN PAINTED FURNITURE, which is not the editor's palette and is themed by a
   different rule. The editor follows the reader's light/dark choice; these follow the SYSTEM,
   because they are chrome and chrome belongs to the desktop. Off high contrast they are the
   literals this window has always drawn, to the byte, so "nothing changed" is provable with a
   pixel diff rather than an argument. *)
type
  TSpxChrome = record
    { the tool rail's background }
    RailBack: TColor;
    { the Page/Source switch: its track, the lit segment, and the two inks }
    TrackBack, TrackEdge, OnBack, OnEdge, HotBack, OnText, OffText: TColor;
    { the preview's "this output is stale" banner }
    BannerBack, BannerText: TColor;
  end;

function SpxChrome(AHighContrast: Boolean): TSpxChrome;

{ The help page's link. Brand magenta normally; under a contrast theme the system's own
  hyperlink colour, because #a91455 on a contrast theme's page measures 2.25:1 and the
  threshold is 4.5. }
function SpxHelpLink(AHighContrast: Boolean): TColor;

{ A LINK IN THE HELP PAGE, and it is NOT part of the palette: the page it sits on is the
  system's window colour whatever theme the editor is in (SpxHelpPane says why), so a link that
  changed with the theme would be picking a colour for a background it no longer has. This is
  the deep magenta -- brand, rather than the browser blue IPro defaults to, because the help is
  the one page in this window that is ours. TColor is $00BBGGRR, so this is #a91455.

  The palette used to carry a second, lighter magenta for the dark theme; it existed to sit on
  #1E1E1E and there is no longer a #1E1E1E page for it to sit on. }
const
  SPX_HELP_LINK = $005514A9;

implementation

function SpxHelpLink(AHighContrast: Boolean): TColor;
begin
  if AHighContrast then Result := clHotLight else Result := SPX_HELP_LINK;
end;

function SpxChrome(AHighContrast: Boolean): TSpxChrome;
begin
  if AHighContrast then
  begin
    { The rail and the switch are surfaces the system has names for. The lit segment is the
      one that was actually BROKEN rather than merely unthemed: it drew clWindowText on a
      hardcoded #FFFFFF, so a contrast theme's white ink landed on white. }
    Result.RailBack := clBtnFace;
    Result.TrackBack := clBtnFace;
    Result.TrackEdge := clWindowText;
    Result.OnBack := clHighlight;
    Result.OnEdge := clHighlight;
    { THE HOVER GOES SILENT, and it is named rather than worked around: a contrast theme has
      no shade between its surfaces, so the hot segment fills with the same colour as the track
      and nothing is drawn. clHighlight would show, and would read as "this one is selected" on
      a control whose whole job is to say which one is. Off contrast this is $E8E8E8 on
      $F4F4F4 and visible as intended. }
    Result.HotBack := clBtnFace;
    Result.OnText := clHighlightText;
    Result.OffText := clBtnText;
    Result.BannerBack := clBtnFace;
    Result.BannerText := clBtnText;
  end
  else
  begin
    { EXACTLY what these controls drew before there was a record to hold it. The values are
      copied rather than adjusted, so any pixel difference off high contrast is a defect. }
    Result.RailBack := $00F4F4F4;
    Result.TrackBack := $00F4F4F4;
    Result.TrackEdge := $00DEDEDE;
    Result.OnBack := $00FFFFFF;
    Result.OnEdge := $00C8C8C8;
    Result.HotBack := $00E8E8E8;
    Result.OnText := clWindowText;
    Result.OffText := $00606060;
    Result.BannerBack := $00E1F0FF;
    Result.BannerText := clWindowText;
  end;
end;

function SpxPalette(ATheme: TSpxTheme; AHighContrast: Boolean = False): TSpxPalette;
begin
  if AHighContrast then
  begin
    (* THREE INKS, NOT NINE, AND THAT IS THE ANSWER RATHER THAN A SHORTFALL. A contrast theme
       offers very little that is guaranteed legible ON the window: clWindowText, clGrayText and
       clHotLight are the three a theme promises to make readable there. Measured on this
       machine's theme, against its #202020 page: white 16.3:1, grey #A6A6A6 6.7:1, hot-light
       #75E9FC 11.5:1. clHighlight and clActiveCaption are BACKGROUND colours -- nothing
       promises they can be read as ink, so neither is used as one.

       So the nine syntax roles collapse into four visual classes, and the styles that separate
       them are already in the highlighter's constructor rather than here: comment is italic,
       structure is bold. What a reader gets is text, structure, comments and NAMED THINGS
       (strings, variables, config keys) -- which is the distinction worth keeping when the
       desktop has asked for fewer colours, and it is honest about giving up the rest.

       What this replaces was not a compromise, it was invisible: the light table's directive
       colour is rgb(0,51,153), which on that #202020 page is 1.50:1 against a 4.5 threshold.
       (1.93:1 was the first number written here and it is the ratio against pure BLACK, not
       against the page the sentence names -- caught by review. The conclusion is unchanged and
       the real figure is worse.) *)
    Result.Back := clWindow;
    Result.Text := clWindowText;

    Result.Comment := clGrayText;
    Result.Directive := clWindowText;
    Result.Str := clHotLight;
    Result.Variable := clHotLight;
    Result.Pipe := clWindowText;
    Result.Cond := clWindowText;
    Result.Plural := clWindowText;
    Result.Config := clHotLight;

    { Alternating rather than four shades: depth still reads as a change at each level, and
      there is no fourth legible ink to spend on it. }
    Result.Nest[0] := clWindowText;
    Result.Nest[1] := clHotLight;
    Result.Nest[2] := clWindowText;
    Result.Nest[3] := clHotLight;

    Result.Gutter := clBtnFace;
    Result.GutterText := clGrayText;
    Result.Sel := clHighlight;
    Result.SelText := clHighlightText;
    { The bracket highlight becomes the selection's pair, which is the only fill/ink couple a
      contrast theme guarantees can be read together. }
    Result.BracketBack := clHighlight;
    Result.BracketText := clHighlightText;
    { A JUMP MAY LAND SILENTLY HERE, and that is stated rather than worked around. The flash is
      a faint wash, and a contrast theme has no faint anything -- clBtnFace is the nearest
      honest answer, and on this machine's theme it is #202020, the same as the page, so the
      wash does not show. The caret still moves and the preview still follows; inventing a
      colour the theme did not offer would be the louder mistake. }
    Result.Flash := clBtnFace;

    Result.HtmlTag := clWindowText;
    Result.HtmlAttr := clHotLight;
    Result.HtmlValue := clHotLight;
    Result.HtmlComment := clGrayText;
    Result.HtmlEntity := clHotLight;
  end
  else if ATheme = spxThemeDark then
  begin
    Result.Back := $001E1E1E;
    Result.Text := $00D4D4D4;

    Result.Comment := $0055996A;      { green -- the one role every editor agrees on }
    Result.Directive := $00D69C56;    { blue: a directive is this language's keyword }
    Result.Str := $007891CE;          { the string colour, for a quoted include target }
    Result.Variable := $00C086C5;
    Result.Pipe := $007DBAD7;         { the separator has to be found at a glance }
    Result.Cond := $00B0C94E;
    Result.Plural := $00B0C94E;
    Result.Config := $00A8CEB5;

    { Four for nesting, cycling. Gold, orchid and blue are the three VS Code settled on for
      bracket pairs after trying rainbows; the fourth is the teal above. }
    Result.Nest[0] := $0000D7FF;
    Result.Nest[1] := $00D670DA;
    Result.Nest[2] := $00FF9F17;
    Result.Nest[3] := $00B0C94E;

    Result.Gutter := $00262525;
    Result.GutterText := $00858585;
    Result.Sel := $00784F26;
    { clNone leaves a selected token its own colour, which is what a syntax-coloured editor
      wants: painting selected text one flat colour throws the highlighting away. }
    Result.SelText := clNone;
    { BRAND MAGENTA, deep end -- `--magenta-900` (#6e0c38) from spintax.net's own token file.
      What was here, $00404040, is RGB(64,64,64) against a page of RGB(30,30,30): a lift of
      thirty-four on every channel, which the user reported as "practically invisible" and which
      is exactly what a neutral grey does on a neutral background. A hue does what a shade could
      not. The deepest of the four magentas rather than a brighter one, because this is a FILL
      behind text: `--magenta-300` is what the brand puts on dark as a FOREGROUND (its docs
      colour variables and conditionals with it), and a fill in that strength would drown the
      syntax it sits under. }
    Result.BracketBack := $00380C6E;
    Result.BracketText := $0000D7FF;
    { A lift off #1E1E1E rather than a hue: on dark, any tint at this strength reads as a
      colour cast over the syntax, and the point is "look here", not "this is special". }
    Result.Flash := $00332F2B;

    Result.HtmlTag := $00D69C56;
    Result.HtmlAttr := $00FEDC9C;
    Result.HtmlValue := $007891CE;
    Result.HtmlComment := $0055996A;
    Result.HtmlEntity := $00A8CEB5;
  end
  else
  begin
    { The system's, so a high-contrast desktop is honoured rather than overridden. }
    Result.Back := clWindow;
    Result.Text := clWindowText;
    Result.Gutter := clBtnFace;
    Result.GutterText := clGrayText;
    Result.Sel := clHighlight;
    Result.SelText := clHighlightText;

    { Ours, because no system colour means "directive". These are the values the editor has
      shipped with; light must look exactly as it did before there were two tables. }
    Result.Comment := clGray;
    Result.Directive := $00993300;
    Result.Str := $00107C10;
    Result.Variable := $00A03070;
    Result.Pipe := $000060C0;
    Result.Cond := $000080C0;
    Result.Plural := $000080C0;
    Result.Config := $00808000;

    Result.Nest[0] := $00B04000;
    Result.Nest[1] := $00206090;
    Result.Nest[2] := $00107040;
    Result.Nest[3] := $00A02090;

    { A REAL BACKGROUND, not clNone. SynEdit's bracket markup defaults to bolding the character
      (`MarkupInfo.Style := [fsBold]`, syneditmarkupbracket.pp:82) and nothing else, which is
      enough for a brace and far too little for the construct's separators -- a bold `|` on white
      is not a highlight.

      THE SAME BRAND MAGENTA as the dark theme, so one thing means one thing in both -- a soft
      fill of `--magenta-500` (#cc2070) over white, built the way spintax.net builds its own
      `--accent-soft`: a percentage of the hue rather than a colour picked beside it. It replaces
      a pale yellow that was nothing but my taste. Distinct from the selection's blue and from the
      jump flash's pale blue, so the three never read as the same thing. }
    Result.BracketBack := $00E0CEF4;
    Result.BracketText := clNone;
    { NOT a system colour, and not derived from clHighlight: the selection's colour means "the
      user selected this" everywhere else in the window, and a jump did not. A pale warm wash
      is distinct from both the selection and the amber a warning wears. }
    Result.Flash := $00D9F0FF;

    { clNone means "leave SynEdit's own HTML colours alone" -- they were chosen for a light
      background and there is nothing to improve there. }
    Result.HtmlTag := clNone;
    Result.HtmlAttr := clNone;
    Result.HtmlValue := clNone;
    Result.HtmlComment := clNone;
    Result.HtmlEntity := clNone;
  end;
end;

end.
