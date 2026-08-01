(*
 * SpxHelpPane -- the help itself, in the LEFT pane, where the template normally is.
 *
 * READ LEFT, RESULT RIGHT. The window is built so that what you edit is on the left and what it
 * produces is on the right, and the help is text about templates that produces outputs -- the
 * same shape. So it takes the same place, and the pane beside it goes on doing what it always
 * does. That is the whole design, and it adds no control the window did not already have.
 *
 * THE TEMPLATE OF EVERY EXAMPLE IS A LINK, the output beside it is not. Click the input, get the
 * output. With no DataProvider every link click falls through to OnHotClick with the href in
 * HotURL (iphtml.pas:7285-7302) -- measured before this was written, along with the two facts it
 * rests on: an anchor inside a <pre> IS a link, and the output half of the same line is not one.
 *
 * The pane carries NO chrome. The close button, the contents and the language selector live in
 * the topics panel; the page here is only the page.
 *
 * THE PAGE'S BACKGROUND IS THE SYSTEM'S, NOT THE EDITOR'S. It was the editor's, and the dark
 * theme showed the page in bands of black; system-coloured it does not. That is the whole of what
 * was measured, and the cause is deliberately not written down as fact -- the obvious story (that
 * IPro leaves its margins unpainted) is contradicted by its own source, where TIpHtmlNodeBody
 * .Render fills the WHOLE client rect with the body colour before drawing anything
 * (iphtml.pas:2554-2560). The likelier culprit is the one this project has already paid for on
 * the pane next door: EraseBackground is empty (iphtml.pas:5778, :7198) and IPro has no resize
 * handler, so a band exposed by a drag keeps the pixels that were there -- which is why Resize
 * below is the preview's, verbatim in intent.
 *
 * Either way the page belongs on the system's colours, and for a reason that does not depend on
 * the diagnosis: a themed editor is the WORK, and a rendered page is a DOCUMENT. The preview's
 * page has been system-coloured since its first commit for exactly that reason.
 *
 * THE LINK COLOUR IS STILL OURS -- the brand magenta, now a constant in SpxTheme rather than a
 * palette entry, since it no longer has a themed background to be picked for. A link is not a
 * background and had no part in the bands, so taking IPro's default blue with them would have
 * been a loss the fix did not need; found by review.
 *)
unit SpxHelpPane;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Graphics, IpHtml,
  SpxStudio, SpxUi, SpxTheme, SpxHelpText, SpxHelpNav;

type
  { The reader clicked an example: this is its number, which SpxHelpText turns into a template. }
  TSpxRunExample = procedure(AIndex: Integer) of object;

  TSpxHelpPane = class(TPanel)
  private
    FPage: TIpHtmlPanel;
    FLang: Integer;
    FPageNo: Integer;
    FAnchor: string;
    FOnRun: TSpxRunExample;
    { What the panel is already showing -- see Feed. }
    FShown: string;
    { The link's colour. Held rather than read from a constant so a contrast theme can change
      it; the feed cache keys on the whole document string, so a changed colour invalidates it
      by itself and nothing has to remember to. }
    FLink: TColor;
    procedure HotClicked(Sender: TObject);
    procedure Feed;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    { The link colour the page draws with -- SpxHelpLink answers it. Re-feeds when it changes,
      because IPro copies colours into the document at LOAD (iphtml.pas:6178-6204) -- but only
      once something has been shown; see the body. }
    procedure SetLinkColor(AValue: TColor);
    { Show a page and scroll to an article. Measured: MakeAnchorVisible finds an `id` on a
      heading with no DataProvider, and the name goes WITHOUT the leading '#'. }
    procedure ShowPage(ALang, APage: Integer; const AAnchor: string);
    property HelpLang: Integer read FLang;
    property CurrentPage: Integer read FPageNo;
    property CurrentAnchor: string read FAnchor;
    property OnRunExample: TSpxRunExample read FOnRun write FOnRun;
  end;

implementation

constructor TSpxHelpPane.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Color := clWindow;
  { The brand's magenta until the window says otherwise, so the page is right on its first feed
    even if nothing ever applies a theme to this pane. }
  FLink := SPX_HELP_LINK;
  FLang := 0;
  FPageNo := 0;

  FPage := TIpHtmlPanel.Create(Self);
  FPage.Parent := Self;
  FPage.Align := alClient;
  FPage.TabStop := True;
  { An example is code, and code does not want a rule drawn under it. The link colour carries
    the affordance on its own, and the hand cursor -- which IPro sets from the node -- does the
    rest. }
  FPage.LinksUnderlined := False;
  FPage.OnHotClick := @HotClicked;
end;

procedure TSpxHelpPane.HotClicked(Sender: TObject);
var n: Integer;
begin
  { The one place an href is read, and `ex:N` is the only kind this help emits -- the generator
    refuses to write another. Anything else is ignored rather than guessed at: R0 is offline and
    packaged, and leaving a container for a browser is a decision of its own. }
  n := SpxHelpExampleOf(FPage.HotURL);
  if (n >= 0) and Assigned(FOnRun) then FOnRun(n);
end;

procedure TSpxHelpPane.SetLinkColor(AValue: TColor);
begin
  if FLink = AValue then Exit;
  FLink := AValue;
  { NOTHING SHOWN YET, NOTHING TO RE-COLOUR. Under a contrast theme the first ApplyTheme
    changes this colour, and feeding here would parse page 0 of a pane the reader has not
    opened -- 62-234 ms of startup, spent only by the users least able to absorb it.
    ShowPage feeds with the current colour when the help is actually opened.

    Otherwise no cache to clear: Feed builds the document with the colour written into it, so a
    changed link makes a different string and the FShown comparison re-feeds by itself. }
  if FShown = '' then Exit;
  Feed;
end;

procedure TSpxHelpPane.Feed;
var back, text_, link_, doc: string;
begin
  if FPage = nil then Exit;
  { THE SYSTEM'S BACKGROUND AND TEXT -- see the top of this unit -- and the brand's link on top
    of them. The link is a constant rather than a palette entry for the reason SpxTheme gives:
    the page it sits on no longer changes with the theme, so neither does it -- EXCEPT under a
    Windows contrast theme, where the brand magenta measures 2.25:1 on the page the system then
    supplies and SpxHelpLink hands back clHotLight instead.

    Set on the panel as well as written into the document: the panel's are what IPro copies in
    when a document has no colour of its own (TIpHtmlFrame.InitHtml, iphtml.pas:6178-6204), so
    the two agreeing is what keeps a future document that drops an attribute from surprising
    anyone. }
  back := SpxHtmlColor(clWindow);
  text_ := SpxHtmlColor(clWindowText);
  link_ := SpxHtmlColor(FLink);
  FPage.BgColor := clWindow;
  FPage.TextColor := clWindowText;
  FPage.LinkColor := FLink;
  FPage.Color := clWindow;
  { THE SAME DOCUMENT IS NOT FED TWICE. IPro's parse is flat but its first layout is quadratic
    (ADR 0004), and measured here a help page costs 62-234 ms -- so a second feed of a string
    the panel is already showing is a fifth of a second the reader watches for nothing. Opening
    the help fed TWICE (measured: two per open), and re-opening on the same page fed again.

    The ANCHOR stays outside the cache: the same page with a different article is a scroll and
    not a reload, which is the case the search bar makes on almost every step.

    The preview pane has had this cache since it was written and gives the same reason; this one
    was written without it. }
  doc := SpxHelpDocument(SpxHelpPageHtml(FLang, FPageNo), back, text_, link_);
  if doc <> FShown then
  begin
    FShown := doc;
    FPage.SetHtmlFromStr(doc);
  end;
  if FAnchor <> '' then FPage.MakeAnchorVisible(FAnchor);
end;

{ THE BAND A DRAG LEAVES. TIpHtmlCustomPanel.EraseBackground is empty on purpose -- IPro paints
  its own content and skips the erase to avoid flicker -- and it has no resize handler, so the
  strip a widening pane has just exposed keeps whatever pixels stood there. The preview pane
  carries the same three lines and the measurement behind them (SpxPreviewPane.Resize): a
  splitter drag left a stripe standing beside the page. This pane is alClient in a slot the same
  splitter resizes. }
procedure TSpxHelpPane.Resize;
var i: Integer;
begin
  inherited Resize;
  if (FPage = nil) or not FPage.Visible then Exit;
  FPage.Invalidate;
  { The drawing is done by an internal CHILD of that panel and a parent's invalidation does not
    reach a clipped child, so the children go too -- by shape rather than by name, which keeps
    this free of IPro's internals. }
  for i := 0 to FPage.ControlCount - 1 do
    if FPage.Controls[i] is TWinControl then TWinControl(FPage.Controls[i]).Invalidate;
end;

procedure TSpxHelpPane.ShowPage(ALang, APage: Integer; const AAnchor: string);
begin
  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) then ALang := 0;
  { The count is the LANGUAGE's now: a language has documents, and its pages are all of
    their sections in order. }
  if (APage < 0) or (APage >= SpxHelpPageCount(ALang)) then APage := 0;
  FLang := ALang;
  FPageNo := APage;
  FAnchor := AAnchor;
  Feed;
end;

end.
