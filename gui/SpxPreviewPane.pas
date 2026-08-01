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
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics, Menus, IpHtml, Buttons, ImgList,
  SynEdit, SynEditTypes, SynEditWrappedView, SynEditMarkup, SynEditHighlighter,
  SynHighlighterHTML, SpxTheme,
  SpxStudio, SpxUi, SpxStrIds, SpxStrings, SpxSourceMarkup, SpxIcons;

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
    { THE OFFER. Shown while the pane is drawing an example out of the help rather than the
      reader's own document -- it says which, and offers to make it theirs. It lives here and
      not on the example itself because IPro draws no buttons: everything clickable in a page
      is a link, and a second link on the template would put two magenta things on one line
      where one of them means "render this" and the other "keep this". }
    FOffer: TPanel;
    FOfferInsert: TSpeedButton;
    FOfferReroll: TSpeedButton;
    FOfferHelp: TPaintBox;
    { What the strip was last laid out for -- see LayOutOffer. }
    FOfferFor: Integer;
    FOfferSide: Integer;
    FOnInsert: TNotifyEvent;
    FOnReroll: TNotifyEvent;
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
    FShown: string;       // the RAW output the page was last fed from -- the stale test
    FShownDoc: string;    // the DOCUMENT actually fed, colours and all -- the redraw test
    FShownSource: string; // what was last PUT INTO the source view
    FHasShown: Boolean;
    procedure SetSourceMode(AValue: Boolean);
    procedure SetOffering(AValue: Boolean);
    function GetOffering: Boolean;
    procedure LayOutOffer;
    procedure OfferClicked(Sender: TObject);
    procedure OfferRerollClicked(Sender: TObject);
    procedure OfferHelpPaint(Sender: TObject);
    procedure HideGutterPart(const AClass: string);
    procedure BuildSourceView(AWrap: Boolean);
    procedure CopyClicked(Sender: TObject);
    procedure SelectAllClicked(Sender: TObject);
    procedure DrawClicked(Sender: TObject);
    procedure DrawPage;
    { Feed the page again with the system's current colours, without drawing anything new. }
    procedure RefeedShown;
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
    { The window's chrome colours. Only the stale banner needs them here -- its pale blue was
      chosen when there was one theme, and on a contrast theme it is a pale slab under the
      system's own white ink. Off high contrast the value is that same pale blue. }
    procedure ApplyChrome(const AChrome: TSpxChrome);
    procedure ApplyEditorFont(const AFamily: string; APoints: Integer);
    { The window's own 16px list, handed over rather than built here: it is refilled in place
      when the display's scaling changes, so this reference stays good (SpxUi.SpxImagesFrom). }
    procedure SetIcons(AImages: TCustomImageList);
    property Content: string read FContent;
    { Whether the strip above the page is up. The window sets it; the pane holds no idea of
      what the help is, only that what it is drawing came from somewhere else. }
    property Offering: Boolean read GetOffering write SetOffering;
    property OnInsert: TNotifyEvent read FOnInsert write FOnInsert;
    property OnReroll: TNotifyEvent read FOnReroll write FOnReroll;
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

  { ABOVE the stale strip, so that when both are up the reader is told whose text this is
    before being told it is out of date. Both are alTop, and LCL stacks alTop children in
    creation order, so this order is the statement. }
  FOffer := TPanel.Create(Self);
  FOffer.Parent := Self;
  FOffer.Align := alTop;
  FOffer.Height := Px(Self, 30);
  FOffer.BevelOuter := bvNone;
  FOffer.Visible := False;

  FOfferInsert := TSpeedButton.Create(Self);
  FOfferInsert.Parent := FOffer;
  FOfferInsert.Flat := True;
  FOfferInsert.ImageIndex := SPX_ICON_INSERT;
  FOfferInsert.ShowHint := True;
  FOfferInsert.OnClick := @OfferClicked;

  FOfferReroll := TSpeedButton.Create(Self);
  FOfferReroll.Parent := FOffer;
  FOfferReroll.Flat := True;
  FOfferReroll.ImageIndex := SPX_ICON_REROLL;
  FOfferReroll.ShowHint := True;
  FOfferReroll.OnClick := @OfferRerollClicked;

  (* A MARK, NOT A BUTTON -- and it was a button, with no OnClick, since the strip was written.
     It depressed when clicked and did nothing, which is the same complaint as a border that
     offers a drag it will not perform: an affordance the control cannot honour.

     Nor should it become one. The strip is on screen only while the help is open on an
     example, so "go to the help" would mean "stay where you are", and there is no example-to-
     page map to navigate with even if it did. What the glyph says is where this preview came
     FROM, which its hint has always said in words.

     A TPaintBox drawing through the same image list, so the pixels are the ones the button
     drew -- rather than a TImage, which would need the glyph copied out of the list and would
     be a second chance to lose its alpha. It still cannot take the keyboard, but nothing in
     the strip can, and this one no longer pretends it has anything to give. *)
  FOfferHelp := TPaintBox.Create(Self);
  FOfferHelp.Parent := FOffer;
  FOfferHelp.ShowHint := True;
  FOfferHelp.OnPaint := @OfferHelpPaint;

  { HERE, not only in Retranslate. The window sets the language BEFORE it builds anything, so
    every control reads its own hint in its own constructor -- and RetranslateUi runs only
    when the language CHANGES. The offer used to have captions; now the text lives in the
    hints, where icon buttons put translated verbs without spending strip width. }
  FOfferInsert.Hint := Tr(sHelpExampleInsert);
  FOfferReroll.Hint := Tr(sReroll);
  FOfferHelp.Hint := Tr(sHelpExampleFrom);

  FPage := TIpHtmlPanel.Create(Self);
  FPage.Parent := Self;
  FPage.Align := alClient;
  FPage.Color := clWindow;
  FPage.BgColor := clWindow;
  (* AND THE INK, which was missing -- the half of a pair that only looks complete while the
     two halves happen to agree.

     The background was taken from the system and the text was not, so the renderer supplied
     its own default: black. On a light desktop that is right by coincidence. Turn on a Windows
     contrast theme and clWindow becomes #202020 while the text stays #000000, and the whole
     preview goes to 1.29:1 -- measured from a PrintWindow photograph, where the brightest
     pixel in the entire pane was the background itself.

     Worth recording HOW it was missed: the screenshot was on the screen and read as light text
     on dark. The eye was the faulty instrument and the number is what caught it.

     WHAT REACHES THE TEXT is the `text=` attribute the wrapper writes, which is how the help
     page has always done it and what the 16.29:1 above was measured with. The panel property
     is set as well, because InitHtml copies it into the document object (iphtml.pas:6182) and
     agreeing costs nothing -- but it is NOT established that the property alone would fail.
     Two attempts at it changed nothing on screen; both changed the property without changing
     the content, and the feed was keyed on the content, so nothing was ever fed again. Review
     caught that, and the claim is left as what is known rather than what was concluded. *)
  FPage.TextColor := ColorToRGB(clWindowText);

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
  { The sentence is clamped to the room left beside the button, so a pane that got wider has
    room the last layout did not know about. Only while the strip is up, and only the two
    controls inside it -- neither is AutoSize and neither is negotiated by the layout system,
    which is what the two `loop detected` exceptions in this project were about. }
  if (FOffer <> nil) and FOffer.Visible then LayOutOffer;
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
  { The offer strip is CHROME, not the user's HTML, so it follows the theme -- and it is
    coloured before the early return below, which exists for a source view that has not been
    built yet and has nothing to do with the strip. Gutter/Text rather than a literal: the
    stale strip's fixed pale blue was chosen when there was only a light theme, and it is the
    one thing in this pane that goes on glowing after the lights are turned off. }
  if FOffer <> nil then
  begin
    FOffer.Color := APalette.Gutter;
  end;

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

(* RECOLOUR WHAT IS ON SCREEN -- which is NOT the same as drawing what the engine last
   produced, and the difference is the size guard.

   The first version of this called DrawPage, guarded by FHasShown. But FHasShown means "a page
   was drawn at some time", and DrawPage always builds from FContent. So on a document past
   SPX_PAGE_AUTO_LIMIT -- where Sync deliberately shows the stale banner and does not draw --
   picking a theme from the View menu would have rendered the whole thing anyway: ADR 0004
   measures that at 3.4 s for 86 KB and 12.9 s for 172 KB, the exact freeze the threshold
   exists to prevent, reachable in two clicks. It would also have hidden the banner and the
   button that offers the draw, leaving nothing to say the page had ever been held back.

   So this feeds FShown -- the output the page is actually displaying -- with the system's new
   pair around it. The guard's decision stands, the banner stays up if it was up, and the
   colours are right for whatever is there. Found by review. *)
procedure TSpxPreviewPane.RefeedShown;
var doc: string;
begin
  if (FPage = nil) or (not FHasShown) or FSourceMode then Exit;
  doc := SpxPageDocument(FShown, SpxHtmlColor(clWindow), SpxHtmlColor(clWindowText));
  if doc = FShownDoc then Exit;
  FPage.SetHtmlFromStr(doc);
  FShownDoc := doc;
end;

procedure TSpxPreviewPane.DrawPage;
var doc: string;
begin
  { SpxPageDocument, never the raw string: the renderer needs a document, and a bare one goes
    black, loses the text before the first tag, or hangs on an unterminated `<!` (the
    measurements are with the function).

    THE COLOURS GO IN THE DOCUMENT. The comment that used to stand here warned that FShown
    tracks the RAW output and that this holds only while SpxPageDocument is a pure function of
    that string -- "give it a setting, a theme or a charset one day and FShown stops being a
    valid key for what is on screen". That day is this one, so the key moved with it: FShownDoc
    holds what was actually fed. FShown keeps tracking the raw output, because the STALE
    indicator asks a different question -- is the engine's answer newer than the drawn one.

    Building the document first costs a string concatenation; the layout it might avoid costs
    35 ms to 12.9 s (ADR 0004), so the order is the cheap test first. }
  doc := SpxPageDocument(FContent, SpxHtmlColor(clWindow), SpxHtmlColor(clWindowText));
  if FHasShown and (FShownDoc = doc) then
  begin
    FStale.Visible := False;
    Exit;
  end;
  FPage.SetHtmlFromStr(doc);
  FShown := FContent;
  FShownDoc := doc;
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

procedure TSpxPreviewPane.OfferClicked(Sender: TObject);
begin
  if Assigned(FOnInsert) then FOnInsert(Self);
end;

procedure TSpxPreviewPane.OfferRerollClicked(Sender: TObject);
begin
  if Assigned(FOnReroll) then FOnReroll(Self);
end;

function TSpxPreviewPane.GetOffering: Boolean;
begin
  Result := FOffer.Visible;
end;

procedure TSpxPreviewPane.SetOffering(AValue: Boolean);
begin
  if FOffer.Visible = AValue then Exit;
  FOffer.Visible := AValue;
  if AValue then LayOutOffer;
end;

procedure TSpxPreviewPane.LayOutOffer;
var pad, gap, x, side: Integer;
begin
  pad := Px(Self, 8);
  gap := Px(Self, 4);
  side := Px(Self, 26);
  { NOTHING TO DO WHEN NOTHING MOVED, and that is what stops the strip blinking on a reroll.
    Resize fires for every layout ripple in the form, not only when this pane changed size
    (AGENTS.md records the same trap on the window's own clamp) -- and a reroll delivers a
    render, which ripples. Re-setting the three buttons' bounds to the values they already
    have still repaints them, so the reader saw the glyphs flick on every click of a button
    that has nothing to do with them. The face size and the pane's width are the only inputs
    this layout has; if neither changed, neither did the answer. }
  if (FOfferFor = ClientWidth) and (FOfferSide = side) then Exit;
  FOfferFor := ClientWidth;
  FOfferSide := side;
  x := pad;
  FOfferInsert.SetBounds(x, Px(Self, 2), side, side);
  Inc(x, side + gap);
  FOfferReroll.SetBounds(x, Px(Self, 2), side, side);
  Inc(x, side + gap);
  FOfferHelp.SetBounds(x, Px(Self, 2), side, side);
end;

procedure TSpxPreviewPane.Retranslate;
begin
  FDraw.Caption := Tr(sShowLarge);
  FOfferInsert.Hint := Tr(sHelpExampleInsert);
  FOfferReroll.Hint := Tr(sReroll);
  FOfferHelp.Hint := Tr(sHelpExampleFrom);
  LayOutOffer;
  FMenuCopy.Caption := Tr(sCopy);
  FMenuSelectAll.Caption := Tr(sMenuSelectAll);
  { The line carries a size, so it is rebuilt rather than translated in place -- and only
    when it is the one on screen, because Sync owns when it appears. }
  if FStale.Visible then
    FStaleText.Caption := Format(Tr(sTooLargeToDraw), [Length(FContent) div 1024]);
end;

procedure TSpxPreviewPane.ApplyChrome(const AChrome: TSpxChrome);
begin
  { The page's own pair, re-stated because a contrast theme can arrive while the window is
    open and these were assigned once in the constructor. Both halves together, always: the
    defect this closes was setting one of them. }
  if FPage <> nil then
  begin
    FPage.Color := clWindow;
    FPage.BgColor := ColorToRGB(clWindow);
    FPage.TextColor := ColorToRGB(clWindowText);
    { And fed again, because the colours live in the DOCUMENT. RefeedShown, never DrawPage:
      the two differ exactly when it matters. }
    RefeedShown;
  end;
  if FStale <> nil then FStale.Color := AChrome.BannerBack;
  { The label's ink too: it was the system's on a fixed pale blue, which is legible only while
    the system's ink stays dark. }
  if FStaleText <> nil then FStaleText.Font.Color := AChrome.BannerText;
end;

procedure TSpxPreviewPane.SetIcons(AImages: TCustomImageList);
begin
  FOfferInsert.Images := AImages;
  FOfferReroll.Images := AImages;
  { The buttons repaint themselves when their Images change; the mark has to be told. }
  if FOfferHelp <> nil then FOfferHelp.Invalidate;
end;

{ Centred the way the image list centres a glyph in a flat speed button of the same side, so
  the mark sits where the button's glyph sat.

  THE LIST IS READ OFF THE BUTTON BESIDE IT rather than kept in a field of its own, and that is
  the point: TSpeedButton.Images is nil'd through Notification if the list is ever freed, so
  borrowing it means this cannot outlive it. A raw field would have been a dangling pointer
  waiting for the one day something frees the list -- latent today only because SpxImagesFrom
  refills the same object in place. It also means a refill at a new DPI reaches the mark and
  the two buttons through exactly one reference. }
procedure TSpxPreviewPane.OfferHelpPaint(Sender: TObject);
var x, y: Integer; list_: TCustomImageList;
begin
  if FOfferHelp = nil then Exit;
  list_ := FOfferInsert.Images;
  if list_ = nil then Exit;
  x := (FOfferHelp.Width - list_.Width) div 2;
  y := (FOfferHelp.Height - list_.Height) div 2;
  list_.Draw(FOfferHelp.Canvas, x, y, SPX_ICON_HELP);
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
    { Held back by the size guard -- but the page still on screen may be carrying the colours
      of a theme that has since changed, and this is the one path back to the page view that
      never redraws. Recolouring it costs one feed of what is already there. }
    RefeedShown;
    FStaleText.Caption := Format(Tr(sTooLargeToDraw), [Length(FContent) div 1024]);
    FStale.Visible := (not FHasShown) or (FShown <> FContent);
  end;
end;

end.
