(*
 * SpxHelpPane -- the help, read inside the window rather than beside it.
 *
 * A PANEL AND NOT A WINDOW. The recorded plan said a non-modal second form; the panel is the
 * better answer on the evidence. TSpxMainForm is the only TForm in this project, so a help
 * window would be the first secondary one and would drag in the caption trap (LCL owns a second
 * top-level window titled exactly Application.Title), caHide, Alt+Tab, focus return and a DPI
 * re-feed -- every one of them a thing to get wrong. The rail already takes a fifth tool in four
 * lines, and the group editor is a slide-out for exactly the reason a modal was rejected: a
 * dialog covers the document you are reading about.
 *
 * IT SHARES THE GROUP EDITOR'S SLOT AND ITS LATCH. Opening one closes the other, which is why
 * the clamp arithmetic never gains a third competitor -- and this window has already paid once
 * for a clamp that fought a drag.
 *
 * THE PANEL DECIDES NOTHING. Which document a fourteen-language interface gets, which page a
 * code is on, what an href means, where the reader lands after a language switch -- all of it is
 * in SpxHelpNav, which the console suite compiles and this unit never can be.
 *)
unit SpxHelpPane;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Buttons, Graphics, IpHtml,
  SpxStudio, SpxUi, SpxIcons, SpxTheme, SpxStrIds, SpxStrings, SpxHelpText, SpxHelpNav;

type
  TSpxHelpPane = class(TPanel)
  private
    FTop: TPanel;
    FClose: TSpeedButton;
    FSections: TComboBox;
    FPage: TIpHtmlPanel;
    FFoot: TPanel;
    FNote: TLabel;
    FLangLabel: TLabel;
    FLangBox: TComboBox;
    FLang: Integer;          { index into SpxHelpText's languages }
    FPageNo: Integer;
    FAnchor: string;
    FPal: TSpxPalette;
    FHasPal: Boolean;
    FFilling: Boolean;       { a combo being refilled must not act on its own OnChange }
    FOnClose: TNotifyEvent;
    procedure CloseClicked(Sender: TObject);
    procedure SectionPicked(Sender: TObject);
    procedure LangPicked(Sender: TObject);
    procedure PageHotClick(Sender: TObject);
    procedure FillSections;
    procedure FillLanguages;
    procedure LayoutFoot;
    procedure Feed;
  public
    constructor Create(AOwner: TComponent); override;
    { Show a page, and scroll to an anchor when there is one. The window's single entry point:
      F1, the menu and a double click on a diagnostics row all arrive here. }
    procedure GoToPage(APage: Integer; const AAnchor: string);
    { The article for a diagnostic code, or the contents when the code has none -- a gesture
      that does nothing reads as broken, and a code from a newer engine is not the reader's
      fault. }
    procedure GoToCode(const ACode: string);
    { The interface language changed. The help language may change with it, and the reader is
      put back on the same article -- SpxHelpNav decides where, because that is a rule and not
      an improvisation. }
    procedure Retranslate;
    procedure ApplyTheme(const APalette: TSpxPalette);
    { The panel cannot hide itself: the window owns the slot and the rail's latch. }
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    { What the reader is looking at. Read-only, and honest state rather than a test hook: a
      probe cannot photograph a windowed child usefully, and these are the same two numbers
      the panel navigates by. }
    property CurrentPage: Integer read FPageNo;
    property CurrentAnchor: string read FAnchor;
  end;

const
  { Wider than the group editor's 300: that panel holds one short line per variant, this one
    holds prose. Still within the same 200..900 the slot allows. }
  SPX_HELP_W = 420;

implementation

{ TColor is $00BBGGRR and HTML wants #RRGGBB, and the light palette's entries are SYSTEM
  colours (clWindow, clWindowText) whose ordinal carries no channels at all -- so ColorToRGB
  first is mandatory, not tidiness. }
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
  FAnchor := '';

  FTop := TPanel.Create(Self);
  FTop.Parent := Self;
  FTop.Align := alTop;
  FTop.BevelOuter := bvNone;
  FTop.Height := Px(Self, 30);

  { The close button first and anchored, so the combo below can take what is left. Same
    gesture and same icon as the group editor's, because it is the same slot. }
  FClose := TSpeedButton.Create(Self);
  FClose.Parent := FTop;
  FClose.Anchors := [akTop, akRight];
  FClose.SetBounds(FTop.Width - Px(Self, 28), Px(Self, 2), Px(Self, 26), Px(Self, 26));
  FClose.Flat := True;
  FClose.OnClick := @CloseClicked;

  { A COMBO AND NOT A TREE. Twelve sections and two levels would want a column of its own, and
    this panel's whole width is the reading column. }
  FSections := TComboBox.Create(Self);
  FSections.Parent := FTop;
  FSections.Align := alClient;
  FSections.BorderSpacing.Right := Px(Self, 32);
  FSections.BorderSpacing.Around := Px(Self, 2);
  FSections.Style := csDropDownList;
  FSections.OnChange := @SectionPicked;

  FFoot := TPanel.Create(Self);
  FFoot.Parent := Self;
  FFoot.Align := alBottom;
  FFoot.BevelOuter := bvNone;
  FFoot.Height := Px(Self, 30);

  { Shown only when the reader's own language has no document -- there is nothing to say when
    the two agree, and a permanent notice about a language you do not use is noise. }
  FNote := TLabel.Create(Self);
  FNote.Parent := FFoot;
  FNote.WordWrap := True;
  FNote.Visible := False;

  FLangLabel := TLabel.Create(Self);
  FLangLabel.Parent := FFoot;

  { By ENDONYM, from the one table that has no language of its own -- so a Russian speaker
    running an English interface can reach the Russian document, which the fallback rule alone
    would deny them. }
  FLangBox := TComboBox.Create(Self);
  FLangBox.Parent := FFoot;
  FLangBox.Style := csDropDownList;
  FLangBox.OnChange := @LangPicked;

  FPage := TIpHtmlPanel.Create(Self);
  FPage.Parent := Self;
  FPage.Align := alClient;
  FPage.TabStop := True;
  { With no DataProvider every link click falls through to OnHotClick with HotURL already set
    (iphtml.pas:7285-7302). Nothing emits a link today -- the generator refuses one and the
    suite asserts no page contains `<a ` -- so this is wiring that is provably dead until the
    day it is not, and that day fails a test rather than doing nothing quietly. }
  FPage.OnHotClick := @PageHotClick;

  FLang := SpxHelpLangFor(SpxUiLang);
  FillLanguages;
  FillSections;
  Retranslate;
end;

procedure TSpxHelpPane.CloseClicked(Sender: TObject);
begin
  if Assigned(FOnClose) then FOnClose(Self);
end;

procedure TSpxHelpPane.FillSections;
var i, keep: Integer;
begin
  FFilling := True;
  try
    keep := FPageNo;
    FSections.Items.BeginUpdate;
    try
      FSections.Items.Clear;
      for i := 0 to SPX_HELP_PAGE_COUNT - 1 do
        FSections.Items.Add(SpxHelpPageTitle(FLang, i));
    finally
      FSections.Items.EndUpdate;
    end;
    if (keep >= 0) and (keep < FSections.Items.Count) then FSections.ItemIndex := keep;
  finally
    FFilling := False;
  end;
end;

procedure TSpxHelpPane.FillLanguages;
var i: Integer;
begin
  FFilling := True;
  try
    FLangBox.Items.BeginUpdate;
    try
      FLangBox.Items.Clear;
      for i := 0 to SPX_HELP_LANG_COUNT - 1 do
        FLangBox.Items.Add(SpxLangName(SpxLangFor(SpxHelpLangCode(i))));
    finally
      FLangBox.Items.EndUpdate;
    end;
    if (FLang >= 0) and (FLang < FLangBox.Items.Count) then FLangBox.ItemIndex := FLang;
  finally
    FFilling := False;
  end;
end;

{ A LABEL DOES NOT KNOW ITS OWN WIDTH WHEN YOU ASK: AutoSize is a no-op on a TLabel (it is born
  with it) so Width still describes the previous caption, and AdjustSize from a layout path is
  an ELayoutException. Measured offscreen and set here, the way the rest of this window does it. }
procedure TSpxHelpPane.LayoutFoot;
var bmp: TBitmap; w: Integer;
begin
  if FLangLabel = nil then Exit;
  bmp := TBitmap.Create;
  try
    bmp.Canvas.Font.Assign(FLangLabel.Font);
    w := bmp.Canvas.TextWidth(FLangLabel.Caption);
  finally
    bmp.Free;
  end;
  FLangLabel.AutoSize := False;
  FLangLabel.SetBounds(Px(Self, 4), Px(Self, 7), w, Px(Self, 16));
  FLangBox.SetBounds(Px(Self, 8) + w, Px(Self, 3),
                     FFoot.ClientWidth - Px(Self, 12) - w, Px(Self, 24));
  FNote.AutoSize := False;
  FNote.SetBounds(Px(Self, 4), Px(Self, 2), FFoot.ClientWidth - Px(Self, 8), Px(Self, 26));
end;

procedure TSpxHelpPane.SectionPicked(Sender: TObject);
begin
  if FFilling then Exit;
  if FSections.ItemIndex < 0 then Exit;
  GoToPage(FSections.ItemIndex, '');
end;

procedure TSpxHelpPane.LangPicked(Sender: TObject);
var page: Integer; anchor: string;
begin
  if FFilling then Exit;
  if (FLangBox.ItemIndex < 0) or (FLangBox.ItemIndex = FLang) then Exit;
  SpxHelpRelocate(FLang, FPageNo, FAnchor, FLangBox.ItemIndex, page, anchor);
  FLang := FLangBox.ItemIndex;
  FillSections;
  GoToPage(page, anchor);
end;

procedure TSpxHelpPane.PageHotClick(Sender: TObject);
var kind: TSpxHrefKind; page: Integer; anchor: string;
begin
  if not SpxHelpResolveHref(FLang, FPageNo, FPage.HotURL, kind, page, anchor) then Exit;
  case kind of
    spxHrefSamePage: FPage.MakeAnchorVisible(anchor);   { without the '#' -- iphtml.pas:6541 }
    spxHrefOtherPage: GoToPage(page, anchor);
    { spxHrefExternal: named and ignored. R0 is offline and packaged, and leaving a container
      to open a browser is a decision of its own rather than a line added here. }
  end;
end;

procedure TSpxHelpPane.Feed;
var back, text_, link: string;
begin
  if FPage = nil then Exit;
  if FHasPal then
  begin
    back := HtmlColor(FPal.Back);
    text_ := HtmlColor(FPal.Text);
    link := HtmlColor(FPal.Link);
  end
  else
  begin
    back := HtmlColor(clWindow);
    text_ := HtmlColor(clWindowText);
    link := HtmlColor(clHotLight);
  end;
  { The panel's own colours are copied INTO the document when it loads (TIpHtmlFrame.InitHtml,
    iphtml.pas:6178-6204), so they are set before the feed and not after -- and a theme change
    means feeding again, which is what ApplyTheme does. }
  FPage.BgColor := FPal.Back;
  FPage.TextColor := FPal.Text;
  FPage.LinkColor := FPal.Link;
  FPage.Color := FPal.Back;
  FPage.SetHtmlFromStr(SpxHelpDocument(SpxHelpPageHtml(FLang, FPageNo), back, text_, link));
  if FAnchor <> '' then FPage.MakeAnchorVisible(FAnchor);
end;

procedure TSpxHelpPane.GoToPage(APage: Integer; const AAnchor: string);
begin
  if (APage < 0) or (APage >= SPX_HELP_PAGE_COUNT) then APage := 0;
  FPageNo := APage;
  FAnchor := AAnchor;
  FFilling := True;
  try
    FSections.ItemIndex := FPageNo;
  finally
    FFilling := False;
  end;
  Feed;
end;

procedure TSpxHelpPane.GoToCode(const ACode: string);
var page: Integer; anchor: string;
begin
  if SpxHelpTargetFor(FLang, ACode, page, anchor) then GoToPage(page, anchor)
  else GoToPage(0, '');
end;

procedure TSpxHelpPane.Retranslate;
var page: Integer; anchor: string; want: Integer;
begin
  if FLangLabel = nil then Exit;
  FLangLabel.Caption := Tr(sHelpLanguage);
  FClose.Hint := Tr(sClose);
  FClose.ShowHint := True;

  { The interface language moved; the help language may have to follow it. Where the reader
    lands is SpxHelpNav's rule. }
  want := SpxHelpLangFor(SpxUiLang);
  if want <> FLang then
  begin
    SpxHelpRelocate(FLang, FPageNo, FAnchor, want, page, anchor);
    FLang := want;
    FillLanguages;
    FillSections;
    GoToPage(page, anchor);
  end
  else
  begin
    FillLanguages;
    FillSections;
  end;

  FNote.Visible := not SpxHelpIsTranslated(SpxUiLang);
  if FNote.Visible then
    FNote.Caption := Format(Tr(sHelpNotTranslated), [SpxLangName(SpxUiLang)]);
  FLangLabel.Visible := not FNote.Visible;
  FLangBox.Visible := not FNote.Visible;
  { Both rows want the same strip, so the note takes it when there is one to make and the
    language picker takes it otherwise. The picker is still reachable: the note is one line
    and the reader who wants the other document opens the panel's own combo -- which is why
    the note goes away as soon as the interface language has a document of its own. }
  if FNote.Visible then FFoot.Height := Px(Self, 34) else FFoot.Height := Px(Self, 30);
  LayoutFoot;
end;

procedure TSpxHelpPane.ApplyTheme(const APalette: TSpxPalette);
begin
  FPal := APalette;
  FHasPal := True;
  Color := APalette.Back;
  if FTop <> nil then FTop.Color := APalette.Back;
  if FFoot <> nil then FFoot.Color := APalette.Back;
  if FNote <> nil then FNote.Font.Color := APalette.Text;
  if FLangLabel <> nil then FLangLabel.Font.Color := APalette.Text;
  { A theme change is a RE-FEED: the colours live in the loaded document, not on the panel. The
    scroll position is lost and the anchor is where the reader comes back to. }
  Feed;
end;

end.
