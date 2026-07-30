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
    { A link in the HELP page. Brand magenta rather than the browser blue IPro defaults to:
      the help is the one page in this window that is ours, and blue-on-dark is the least
      readable pair the default palette offers. Not used by the preview, which shows the
      user's own HTML and is deliberately not themed at all. }
    Link: TColor;
    { the source view's HTML }
    HtmlTag, HtmlAttr, HtmlValue, HtmlComment, HtmlEntity: TColor;
  end;

function SpxPalette(ATheme: TSpxTheme): TSpxPalette;

implementation

function SpxPalette(ATheme: TSpxTheme): TSpxPalette;
begin
  if ATheme = spxThemeDark then
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
    Result.Link := $009040E0;   { #e04090 -- the brand's light magenta, on dark }

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
    Result.Link := $005514A9;   { #a91455 -- the brand's deep magenta, on light }

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
