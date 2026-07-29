(*
 * SpxPreviewPane -- the right half: the engine's output as a page, or as the HTML it is.
 *
 * Two views of one string. The SOURCE view gets it VERBATIM -- that is the view that answers
 * "what markup came out", and it is a read-only editor with SynEdit's HTML highlighter
 * rather than a plain box, because unhighlighted markup is a wall of angle brackets and this
 * view exists to be read. The PAGE view gets it inside a minimal <html><body> document
 * (SpxPageDocument): IPro's parser wants a document, and a bare string is variously painted
 * black, shortened by the text in front of its first tag, or -- on an unterminated `<!` --
 * never finished at all. Nothing is hidden by that: the wrapper adds no charset, no styling
 * and no content, and the raw output is one click away (ADR 0004, revised).
 *
 * Why two views at all: the page answers "how does it look", the source answers "what
 * markup came out". Neither answers the other. A broken tag renders as slightly-off layout
 * that the eye slides over, and prose full of tags cannot be read as prose.
 *
 * The size guard is the one piece of policy here. IPro's parse is flat (~11 ms at any
 * size) but its first layout is quadratic: 35 ms at 1.5 KB, 255 ms at 23 KB, 3.4 s at
 * 86 KB, 12.9 s at 172 KB -- measured, ADR 0004. Below the limit the page follows every
 * debounce tick; above it the page would freeze the window mid-keystroke, so it waits for
 * the user to ask.
 *)
unit SpxPreviewPane;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics, Menus, IpHtml,
  SynEdit, SynEditTypes, SynEditWrappedView, SynEditMarkup, SynEditHighlighter,
  SynHighlighterHTML, SpxTheme,
  SpxStudio, SpxUi, SpxStrIds, SpxStrings, SpxSourceMarkup;

const
  { 16 KB is ~150 ms of layout on this machine -- still invisible between keystrokes, and
    an order of magnitude past a normal page (the demo renders to about 2 KB). }
  SPX_PAGE_AUTO_LIMIT = 16 * 1024;

  { Past this many bytes on ONE line, the source view stops wrapping. The wrap plugin's cost
    goes as the square of a line's length -- 156 ms at 100 KB, 14 500 ms at 1 MB, measured --
    so the limit is set where the pause is still a blink: 32 KB is about 17 ms. Total size is
    not the question, and a megabyte in ordinary lines stays wrapped at 94 ms. }
  SPX_WRAP_LINE_LIMIT = 32 * 1024;

type
  TSpxPreviewPane = class(TPanel)
  private
    FSourceMode: Boolean;
    FStale: TPanel;
    FStaleText: TLabel;
    FDraw: TButton;
    FPage: TIpHtmlPanel;
    { A read-only editor rather than a plain memo, for one reason: the markup is what this
      view is FOR, and unhighlighted markup is a wall of angle brackets. SynEdit's own HTML
      highlighter ships with it, and it colours what the engine actually emits -- tags,
      attributes, entities, comments -- checked against a real render before it was wired
      in. }
    FSource: TSynEdit;
    FSourceHl: TSynHTMLSyn;
    { What SynEdit's HTML highlighter shipped with, captured before anything recolours it, so
      the light theme can PUT THEM BACK rather than describe them a second time. }
    FHtmlDefault: array[0..6] of TColor;
    { The last theme and size, because the source editor is REBUILT when wrapping changes --
      the wrap plugin cannot be removed from a live one -- and a fresh TSynEdit knows nothing
      about either. Without this, one line over 32 KB turned a dark, zoomed source view back
      into a white one at the system size. }
    FPalette: TSpxPalette;
    FHasPalette: Boolean;
    FPoints: Integer;
    FFamily: string;
    { Paints back what the HTML highlighter mistook for a tag. It belongs to the editor, so
      it is created with each one and dies with it. }
    FTextBack: TSpxSourceMarkup;
    { Whether the view currently in place wraps. Not a plugin reference: the plugin cannot be
      detached, so this is what says a rebuild is needed. }
    FWrapped: Boolean;
    { A TMemo is a native EDIT and came with the system's Copy / Select all popup; SynEdit
      creates none, so right-clicking the source view did nothing at all. Two items, built
      here rather than borrowed, because they are also two strings to translate. They belong
      to the PANE so that rebuilding the editor does not take them with it. }
    FSourceMenu: TPopupMenu;
    FMenuCopy: TMenuItem;
    FMenuSelectAll: TMenuItem;
    FContent: string;     // what the engine last produced
    FShown: string;       // what the page is currently displaying
    FShownSource: string; // what was last PUT INTO the source view
    FHasShown: Boolean;
    procedure SetSourceMode(AValue: Boolean);
    procedure HideGutterPart(const AClass: string);
    procedure BuildSourceView(AWrap: Boolean);
    procedure CopyClicked(Sender: TObject);
    procedure SelectAllClicked(Sender: TObject);
    procedure DrawClicked(Sender: TObject);
    procedure DrawPage;
    procedure Sync;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    { The engine's output. Cheap to call on every debounce tick: the view that is hidden
      does no work, and the page redraws only when the text actually changed.

      APartial says this is a SELECTION rendered on its own. It is said out loud, because a
      preview that quietly shows one paragraph of a document looks like a preview that lost
      the rest of it. }
    procedure SetContent(const AHtml: string);
    { Say everything again in the language the window now speaks. The pane owns two
      sentences and two menu items, and all four are on screen long enough for a language
      switch to catch them. }
    procedure Retranslate;
    { Which of the two views is up. The controls that switch it live in the window's top
      strip: the pane is one of two panes, and a header of its own would put its content a
      row lower than the editor beside it. }
    property SourceMode: Boolean read FSourceMode write SetSourceMode;
    { The source view's colours and its size. The PAGE is deliberately left alone: it shows
      the user's own HTML as it will be published, and a preview that recolours the work is
      not a preview. }
    procedure ApplyTheme(const APalette: TSpxPalette);
    procedure ApplyEditorFont(const AFamily: string; APoints: Integer);
    property Content: string read FContent;
  end;

implementation

type
  { The markup manager is protected on TSynEditBase; a descendant declared here reaches it
    without patching SynEdit -- the same accessor the main form uses for the editor's own
    markups. }
  TSynEditReach = class(TSynEdit);

constructor TSpxPreviewPane.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;

  { Shown only when the output is too large to redraw on its own. It sits above the page
    rather than replacing it: the last drawing stays readable while it is out of date. }
  FStale := TPanel.Create(Self);
  FStale.Parent := Self;
  FStale.Align := alTop;
  FStale.Height := Px(Self, 30);
  FStale.BevelOuter := bvNone;
  FStale.Color := $00E1F0FF;
  FStale.Visible := False;

  FStaleText := TLabel.Create(Self);
  FStaleText.Parent := FStale;
  FStaleText.SetBounds(Px(Self, 8), Px(Self, 8), Px(Self, 400), Px(Self, 16));

  FDraw := TButton.Create(Self);
  FDraw.Parent := FStale;
  FDraw.Caption := Tr(sShowLarge);
  FDraw.SetBounds(Px(Self, 420), Px(Self, 3), Px(Self, 90), Px(Self, 24));
  FDraw.OnClick := @DrawClicked;

  FPage := TIpHtmlPanel.Create(Self);
  FPage.Parent := Self;
  FPage.Align := alClient;
  FPage.Color := clWindow;
  FPage.BgColor := clWindow;

  FSourceHl := TSynHTMLSyn.Create(Self);
  FHtmlDefault[0] := FSourceHl.TextAttri.Foreground;
  FHtmlDefault[1] := FSourceHl.KeyAttri.Foreground;
  FHtmlDefault[2] := FSourceHl.SymbolAttri.Foreground;
  FHtmlDefault[3] := FSourceHl.IdentifierAttri.Foreground;
  FHtmlDefault[4] := FSourceHl.ValueAttri.Foreground;
  FHtmlDefault[5] := FSourceHl.CommentAttri.Foreground;
  FHtmlDefault[6] := FSourceHl.UndefKeyAttri.Foreground;
  FHasPalette := False;
  FPoints := 0;
  { The source view shows the markup the engine produced, so it reads like the editor:
    fixed pitch, system size. }
  FSourceMenu := TPopupMenu.Create(Self);
  FMenuCopy := TMenuItem.Create(FSourceMenu);
  FMenuCopy.Caption := Tr(sCopy);
  FMenuCopy.OnClick := @CopyClicked;
  FSourceMenu.Items.Add(FMenuCopy);
  FMenuSelectAll := TMenuItem.Create(FSourceMenu);
  FMenuSelectAll.Caption := Tr(sMenuSelectAll);
  FMenuSelectAll.OnClick := @SelectAllClicked;
  FSourceMenu.Items.Add(FMenuSelectAll);
  BuildSourceView(True);
end;

{ THE STRIPE. TIpHtmlCustomPanel.EraseBackground is deliberately EMPTY -- it paints its own
  content and skips the erase to avoid flicker -- and it has no resize handler of its own. So
  when the pane widens, the band that has just been exposed keeps whatever pixels were there
  before: dragging the splitter left left a grey stripe standing between the editor and the
  page, which reads as a broken layout and is not one. Invalidate makes the panel repaint the
  whole of itself, the new band included. }
procedure TSpxPreviewPane.Resize;
var i: Integer;
begin
  inherited Resize;
  if (FPage = nil) or not FPage.Visible then Exit;
  FPage.Invalidate;
  { The rendering is done by an internal CHILD of that panel, and a parent's invalidation
    does not reach a clipped child -- so the children are invalidated too, by shape rather
    than by name, which keeps this free of IPro's internals. }
  for i := 0 to FPage.ControlCount - 1 do
    if FPage.Controls[i] is TWinControl then TWinControl(FPage.Controls[i]).Invalidate;
end;

procedure TSpxPreviewPane.SetContent(const AHtml: string);
begin
  FContent := AHtml;
  Sync;
end;

{ Every colour the SOURCE view draws with. TSynHTMLSyn's own defaults were chosen for a light
  background -- dark blue tags on #1E1E1E are unreadable -- so in a dark theme its attributes
  are reassigned too, and in a light one the palette says clNone and they are left exactly as
  SynEdit shipped them. }
{ One of SynEdit's gutter parts, by class name -- the gutter is a list whose membership is
  SynEdit's business, so a part is found rather than indexed. }
procedure TSpxPreviewPane.HideGutterPart(const AClass: string);
var i: Integer;
begin
  for i := 0 to FSource.Gutter.Parts.Count - 1 do
    if FSource.Gutter.Parts[i].ClassName = AClass then
      FSource.Gutter.Parts[i].Visible := False;
end;

procedure TSpxPreviewPane.ApplyTheme(const APalette: TSpxPalette);
var i: Integer;

  { clNone in the table means "SynEdit's own", not "leave whatever is there now" -- those are
    the same thing only until a theme has been applied once. Skipping the assignment left the
    HTML tags painted in the dark theme's peach on a white page after switching back, which a
    restart cleared and a two-process probe therefore could not see. The defaults are captured
    at construction rather than written out here, so this does not hardcode SynEdit's palette
    in a second place. }
  procedure Recolour(AAttr: TSynHighlighterAttributes; AColour, ADefault: TColor);
  begin
    if AAttr = nil then Exit;
    if AColour <> clNone then AAttr.Foreground := AColour else AAttr.Foreground := ADefault;
  end;

begin
  if FSource = nil then Exit;
  { Remembered, so a rebuild of the editor (the wrap plugin cannot be removed from a live one)
    can put them back. }
  FPalette := APalette;
  FHasPalette := True;
  FSource.Color := APalette.Back;
  FSource.Font.Color := APalette.Text;
  FSource.SelectedColor.Background := APalette.Sel;
  FSource.SelectedColor.Foreground := APalette.SelText;
  { The gutter too, every part of it: one left alone keeps a system colour and stays light on
    a dark page, which is how the main editor's marks column announced itself. }
  FSource.Gutter.Color := APalette.Gutter;
  for i := 0 to FSource.Gutter.Parts.Count - 1 do
  begin
    FSource.Gutter.Parts[i].MarkupInfo.Background := APalette.Gutter;
    FSource.Gutter.Parts[i].MarkupInfo.Foreground := APalette.GutterText;
  end;

  Recolour(FSourceHl.TextAttri, APalette.Text, FHtmlDefault[0]);
  Recolour(FSourceHl.KeyAttri, APalette.HtmlTag, FHtmlDefault[1]);
  Recolour(FSourceHl.SymbolAttri, APalette.HtmlTag, FHtmlDefault[2]);
  Recolour(FSourceHl.IdentifierAttri, APalette.HtmlAttr, FHtmlDefault[3]);
  Recolour(FSourceHl.ValueAttri, APalette.HtmlValue, FHtmlDefault[4]);
  Recolour(FSourceHl.CommentAttri, APalette.HtmlComment, FHtmlDefault[5]);
  Recolour(FSourceHl.UndefKeyAttri, APalette.HtmlAttr, FHtmlDefault[6]);

  { The overlay that paints a bare `<` back to plain text has to follow, or it would repaint
    prose in the OLD theme's text colour -- which is the exact bug it exists to fix, upside
    down. }
  if APalette.Text <> clNone then FTextBack.SetTextColour(APalette.Text)
  else FTextBack.SetTextColour(FSourceHl.TextAttri.Foreground);
  FSource.Invalidate;
end;

procedure TSpxPreviewPane.ApplyEditorFont(const AFamily: string; APoints: Integer);
begin
  { Remembered, because the source editor is rebuilt when wrapping changes and a fresh one
    knows nothing about either. }
  FPoints := APoints;
  FFamily := AFamily;
  if FSource <> nil then SpxApplyEditorFont(FSource.Font, AFamily, APoints);
end;

procedure TSpxPreviewPane.SetSourceMode(AValue: Boolean);
begin
  if FSourceMode = AValue then Exit;
  FSourceMode := AValue;
  Sync;
end;

procedure TSpxPreviewPane.DrawClicked(Sender: TObject);
begin
  DrawPage;
end;

procedure TSpxPreviewPane.DrawPage;
begin
  { The same text twice is the common case while the user types elsewhere in the settings;
    redrawing it would cost the full layout for no change on screen. }
  if FHasShown and (FShown = FContent) then
  begin
    FStale.Visible := False;
    Exit;
  end;
  { SpxPageDocument, never the raw string: the renderer needs a document, and a bare one goes
    black, loses the text before the first tag, or hangs on an unterminated `<!` (the
    measurements are with the function). FShown tracks the RAW output, so the redraw check
    above still compares what the engine produced, not what was wrapped around it -- which
    holds only while SpxPageDocument is a pure function of that string. Give it a setting, a
    theme or a charset one day and FShown stops being a valid key for what is on screen. }
  FPage.SetHtmlFromStr(SpxPageDocument(FContent));
  FShown := FContent;
  FHasShown := True;
  FStale.Visible := False;
end;

{ The source view, wrapped or not. It is REBUILT rather than reconfigured because SynEdit's
  wrap plugin cannot be taken off a live editor -- measured, both documented ways: freeing it
  access-violates on the spot, and detaching it (`Editor := nil`) leaves the editor holding a
  dead line-mapping view, so the next assignment to Text raises EObjectCheck. Building a
  fresh editor is a few milliseconds and happens only when a document crosses the line-length
  limit, which for ordinary output is never.

  Why bother: wrapping a line of a million characters takes fourteen and a half seconds --
  and the cost is the plugin's alone, since the same text unwrapped is 16 ms and the HTML
  highlighter over it is 32. A render is not obliged to contain a single line break, so on
  that shape the view scrolls sideways instead of freezing. The text is all there, which a
  "too large to show" panel could not say. }
procedure TSpxPreviewPane.BuildSourceView(AWrap: Boolean);
begin
  { The highlighter and the popup menu belong to the PANE, not to the editor, so they outlive
    this and are simply re-attached. }
  FreeAndNil(FSource);
  FSource := TSynEdit.Create(Self);
  FSource.Parent := Self;
  FSource.Align := alClient;
  FSource.ReadOnly := True;
  { NUMBERS, EVEN THOUGH NOTHING HERE IS EDITED -- numbers are for READING. This view answers
    "what markup came out", and the output's LINE STRUCTURE is part of that answer: this
    project has already paid for it once, when a CRLF template left one blank line per
    directive and the source view opened on a screenful of nothing. With wrapping on, a line
    boundary is otherwise invisible -- the same blindness the group editor's list was given
    numbers to cure.

    The gutter is numbers and nothing else: marks, folding, the change stripe and the
    separator are for a document with bookmarks, structure and a saved version, and this one
    is regenerated on every keystroke. Measured on the main editor: those four are 40 px of
    the 55 a default gutter takes. }
  FSource.Gutter.Visible := True;
  HideGutterPart('TSynGutterMarks');
  HideGutterPart('TSynGutterChanges');
  HideGutterPart('TSynGutterSeparator');
  HideGutterPart('TSynGutterCodeFolding');
  FSource.Options := FSource.Options - [eoScrollPastEol] + [eoHideRightMargin];
  FSource.Highlighter := FSourceHl;
  FSource.PopupMenu := FSourceMenu;
  { TSynHTMLSyn opens a tag at every `<`, so one `Цена < 100` in the output colours the rest
    of the paragraph as attributes. The rule the rest of the family follows is in
    SpxHtmlPhantomTags; this puts the text colour back over the runs it names. }
  FTextBack := TSpxSourceMarkup.Create(FSource);
  FTextBack.SetTextColour(FSourceHl.TextAttri.Foreground);
  TSynEditMarkupManager(TSynEditReach(FSource).MarkupMgr).AddMarkUp(FTextBack);
  SpxApplyMonoFont(FSource.Font);
  FSource.Color := clWindow;
  FSource.Visible := FSourceMode;
  if AWrap then
  begin
    { The same pair as the editor, and for the same measured reason: with wrapping on there is
      nothing to the right to scroll to, and SynEdit's default ssBoth offers a bar whose range
      comes from eoScrollPastEol rather than from the text. }
    TLazSynEditLineWrapPlugin.Create(FSource);
    FSource.ScrollBars := ssAutoVertical;
  end
  else
    FSource.ScrollBars := ssAutoBoth;
  FWrapped := AWrap;
  { A fresh control holds nothing, whatever the old one was showing. }
  FShownSource := '';
  { And it knows nothing about the theme or the zoom either. Reapplying them here is what
    keeps a wrap rebuild -- which happens on its own, when one output line crosses 32 KB --
    from throwing a dark, zoomed source view back to white at the system size. }
  if FHasPalette then ApplyTheme(FPalette);
  SpxApplyEditorFont(FSource.Font, FFamily, FPoints);
end;

procedure TSpxPreviewPane.CopyClicked(Sender: TObject);
begin
  { Whatever is selected; with nothing selected SynEdit copies the current line, which is
    what every other editor does. }
  FSource.CopyToClipboard;
end;

procedure TSpxPreviewPane.SelectAllClicked(Sender: TObject);
begin
  FSource.SelectAll;
end;

procedure TSpxPreviewPane.Retranslate;
begin
  FDraw.Caption := Tr(sShowLarge);
  FMenuCopy.Caption := Tr(sCopy);
  FMenuSelectAll.Caption := Tr(sMenuSelectAll);
  { The line carries a size, so it is rebuilt rather than translated in place -- and only
    when it is the one on screen, because Sync owns when it appears. }
  if FStale.Visible then
    FStaleText.Caption := Format(Tr(sTooLargeToDraw), [Length(FContent) div 1024]);
end;

procedure TSpxPreviewPane.Sync;
begin
  FPage.Visible := not FSourceMode;
  FSource.Visible := FSourceMode;

  if FSourceMode then
  begin
    FStale.Visible := False;
    { Compared against what was PUT IN, never against what the control gives back. A native
      control returns its text with the platform's line endings, and the engine's output has
      bare LFs -- so `FSource.Text <> FContent` was true on every single delivery, the view
      was refilled on every debounce tick, and it snapped back to the top each time.
      On a document that takes half a second to render, that made the source view unreadable
      past its first line -- which in a template beginning with `&nbsp;` looked exactly like
      a source view that had failed to generate. }
    if FShownSource <> FContent then
    begin
      { Decided BEFORE the text goes in: a rebuild afterwards would pay the wrap cost this
        exists to avoid, and then throw the result away. }
      if (SpxLongestLine(FContent) <= SPX_WRAP_LINE_LIMIT) <> FWrapped then
        BuildSourceView(not FWrapped);
      FTextBack.SetText(FContent);
      FSource.Text := FContent;
      FShownSource := FContent;
    end;
    Exit;
  end;

  if Length(FContent) <= SPX_PAGE_AUTO_LIMIT then
    DrawPage
  else
  begin
    FStaleText.Caption := Format(Tr(sTooLargeToDraw), [Length(FContent) div 1024]);
    FStale.Visible := (not FHasShown) or (FShown <> FContent);
  end;
end;

end.
