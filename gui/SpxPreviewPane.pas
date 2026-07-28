(*
 * SpxPreviewPane -- the right half: the engine's output as a page, or as the HTML it is.
 *
 * Two views of one string. The SOURCE view gets it VERBATIM -- that is the view that answers
 * "what markup came out". The PAGE view gets it inside a minimal <html><body> document
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
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics, IpHtml, SpxStudio;

const
  { 16 KB is ~150 ms of layout on this machine -- still invisible between keystrokes, and
    an order of magnitude past a normal page (the demo renders to about 2 KB). }
  SPX_PAGE_AUTO_LIMIT = 16 * 1024;

type
  TSpxPreviewPane = class(TPanel)
  private
    FSourceMode: Boolean;
    FStale: TPanel;
    FStaleText: TLabel;
    FDraw: TButton;
    FPage: TIpHtmlPanel;
    FSource: TMemo;
    FContent: string;     // what the engine last produced
    FShown: string;       // what the page is currently displaying
    FShownSource: string; // what was last PUT INTO the memo
    FHasShown: Boolean;
    procedure SetSourceMode(AValue: Boolean);
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
    { Which of the two views is up. The controls that switch it live in the window's top
      strip: the pane is one of two panes, and a header of its own would put its content a
      row lower than the editor beside it. }
    property SourceMode: Boolean read FSourceMode write SetSourceMode;
    property Content: string read FContent;
  end;

implementation

constructor TSpxPreviewPane.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;

  { Shown only when the output is too large to redraw on its own. It sits above the page
    rather than replacing it: the last drawing stays readable while it is out of date. }
  FStale := TPanel.Create(Self);
  FStale.Parent := Self;
  FStale.Align := alTop;
  FStale.Height := 30;
  FStale.BevelOuter := bvNone;
  FStale.Color := $00E1F0FF;
  FStale.Visible := False;

  FStaleText := TLabel.Create(Self);
  FStaleText.Parent := FStale;
  FStaleText.SetBounds(8, 8, 400, 16);

  FDraw := TButton.Create(Self);
  FDraw.Parent := FStale;
  FDraw.Caption := 'Показать';
  FDraw.SetBounds(420, 3, 90, 24);
  FDraw.OnClick := @DrawClicked;

  FPage := TIpHtmlPanel.Create(Self);
  FPage.Parent := Self;
  FPage.Align := alClient;
  FPage.Color := clWindow;
  FPage.BgColor := clWindow;

  FSource := TMemo.Create(Self);
  FSource.Parent := Self;
  FSource.Align := alClient;
  FSource.ReadOnly := True;
  FSource.ScrollBars := ssAutoVertical;
  FSource.WordWrap := True;
  FSource.Font.Name := 'Segoe UI';
  FSource.Font.Size := 11;
  FSource.Color := clWindow;
  FSource.Visible := False;
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

procedure TSpxPreviewPane.Sync;
begin
  FPage.Visible := not FSourceMode;
  FSource.Visible := FSourceMode;

  if FSourceMode then
  begin
    FStale.Visible := False;
    { Compared against what was PUT IN, never against what the control gives back. A native
      memo returns its text with the platform's line endings, and the engine's output has
      bare LFs -- so `FSource.Text <> FContent` was true on every single delivery, the memo
      was refilled on every debounce tick, and the view snapped back to the top each time.
      On a document that takes half a second to render, that made the source view unreadable
      past its first line -- which in a template beginning with `&nbsp;` looked exactly like
      a source view that had failed to generate. }
    if FShownSource <> FContent then
    begin
      FSource.Text := FContent;
      FShownSource := FContent;
    end;
    Exit;
  end;

  if Length(FContent) <= SPX_PAGE_AUTO_LIMIT then
    DrawPage
  else
  begin
    FStaleText.Caption := Format('Вывод %d КБ — страница не обновляется сама',
      [Length(FContent) div 1024]);
    FStale.Visible := (not FHasShown) or (FShown <> FContent);
  end;
end;

end.
