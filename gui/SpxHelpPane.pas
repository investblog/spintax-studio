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
    FPal: TSpxPalette;
    FHasPal: Boolean;
    FOnRun: TSpxRunExample;
    procedure HotClicked(Sender: TObject);
    procedure Feed;
  public
    constructor Create(AOwner: TComponent); override;
    { Show a page and scroll to an article. Measured: MakeAnchorVisible finds an `id` on a
      heading with no DataProvider, and the name goes WITHOUT the leading '#'. }
    procedure ShowPage(ALang, APage: Integer; const AAnchor: string);
    procedure ApplyTheme(const APalette: TSpxPalette);
    property HelpLang: Integer read FLang;
    property CurrentPage: Integer read FPageNo;
    property CurrentAnchor: string read FAnchor;
    property OnRunExample: TSpxRunExample read FOnRun write FOnRun;
  end;

implementation

{ TColor is $00BBGGRR and HTML wants #RRGGBB, and the light palette's entries are SYSTEM colours
  (clWindow, clWindowText) whose ordinal carries no channels at all -- so ColorToRGB first is
  mandatory, not tidiness. }
function HtmlColor(AColor: TColor): string;
var rgb_: LongInt;
begin
  rgb_ := ColorToRGB(AColor);
  Result := Format('#%.2x%.2x%.2x', [rgb_ and $FF, (rgb_ shr 8) and $FF, (rgb_ shr 16) and $FF]);
end;

constructor TSpxHelpPane.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Color := clWindow;
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

procedure TSpxHelpPane.Feed;
var back, text_, link_: string;
begin
  if FPage = nil then Exit;
  if FHasPal then
  begin
    back := HtmlColor(FPal.Back);
    text_ := HtmlColor(FPal.Text);
    link_ := HtmlColor(FPal.Link);
    { The panel's own colours are copied INTO the document when it loads
      (TIpHtmlFrame.InitHtml, iphtml.pas:6178-6204), so they are set before the feed and not
      after -- and a theme change means feeding again, which is what ApplyTheme does. }
    FPage.BgColor := FPal.Back;
    FPage.TextColor := FPal.Text;
    FPage.LinkColor := FPal.Link;
    FPage.Color := FPal.Back;
  end
  else
  begin
    back := HtmlColor(clWindow);
    text_ := HtmlColor(clWindowText);
    link_ := HtmlColor(clHotLight);
  end;
  FPage.SetHtmlFromStr(SpxHelpDocument(SpxHelpPageHtml(FLang, FPageNo), back, text_, link_));
  if FAnchor <> '' then FPage.MakeAnchorVisible(FAnchor);
end;

procedure TSpxHelpPane.ShowPage(ALang, APage: Integer; const AAnchor: string);
begin
  if (ALang < 0) or (ALang >= SPX_HELP_LANG_COUNT) then ALang := 0;
  if (APage < 0) or (APage >= SPX_HELP_PAGE_COUNT) then APage := 0;
  FLang := ALang;
  FPageNo := APage;
  FAnchor := AAnchor;
  Feed;
end;

procedure TSpxHelpPane.ApplyTheme(const APalette: TSpxPalette);
begin
  FPal := APalette;
  FHasPal := True;
  Color := APalette.Back;
  { A theme change is a RE-FEED: the colours live in the loaded document, not on the panel. The
    scroll position is lost and the anchor is where the reader comes back to. }
  Feed;
end;

end.
