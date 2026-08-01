(*
 * SpxSegmented -- a segmented switch: one control, N choices, exactly one of them on.
 *
 * WHY NOT TWO RADIO BUTTONS, which is what the preview's Page/Source pair used to be. Two
 * radios say "these are two settings that happen to be linked"; a segmented control says "this
 * is one setting with two positions", which is what a view mode is. It is also what every
 * current interface uses for exactly this -- and it costs less width, which the top strip does
 * not have to spare (the search field already takes a second row at 820 px).
 *
 * IT MEASURES ITSELF. A caption in fourteen languages is fourteen widths, and the layout used
 * to hand each radio a fixed 90 px it had to fit inside. Here the control asks for what its
 * text needs (MeasureWidth) and the strip gives it that -- so a language cannot clip a caption,
 * only make the switch a little wider.
 *
 * IT TAKES THE KEYBOARD. A TCustomControl rather than a TGraphicControl, for a window handle,
 * a tab stop and arrow keys -- the same accessibility the rail's speed buttons cannot have and
 * which a view mode, unlike a panel, has no other way to reach.
 *)
unit SpxSegmented;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, LCLType, LCLIntf, ImgList, SpxUi, SpxTheme;

type
  TSpxSegment = record
    Caption: string;
    Icon: Integer;     { an index into Images, or -1 }
  end;

  TSpxSegmented = class(TCustomControl)
  private
    FSegments: array of TSpxSegment;
    FIndex: Integer;
    FHot: Integer;
    FImages: TCustomImageList;
    { Seeded in the constructor with the literals this control has always drawn, so it is
      correct before anything applies a theme to it. }
    FChrome: TSpxChrome;
    FOnChange: TNotifyEvent;
    procedure SetItemIndex(AValue: Integer);
    procedure SetImages(AValue: TCustomImageList);
    function SegmentAt(X: Integer): Integer;
    function SegmentWidth: Integer;
    function ContentWidth(ACanvas: TCanvas; AIndex: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    { The window's chrome colours; see TSpxChrome. Off high contrast these are the literals the
      constructor already holds, so calling it changes nothing. }
    procedure ApplyChrome(const AChrome: TSpxChrome);
    { One position. AIcon is an index into Images, or -1 for text alone. }
    procedure Add(const ACaption: string; AIcon: Integer = -1);
    { A language changed. }
    procedure SetCaption(AIndex: Integer; const ACaption: string);
    { The width this wants for the captions it has now. Measured on an offscreen bitmap and
      not on Self.Canvas: a control has no canvas to measure with before its handle exists,
      and the strip lays itself out during construction. }
    function MeasureWidth: Integer;
    property ItemIndex: Integer read FIndex write SetItemIndex;
    property Images: TCustomImageList read FImages write SetImages;
    { TCustomControl has no OnChange to republish -- this is the control's own. }
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

const
  { The six colours the switch draws with are no longer constants -- they arrive as a
    TSpxChrome, seeded with exactly these literals so nothing moves off high contrast:

      TRACK_BG $F4F4F4  TRACK_EDGE $DEDEDE  ON_BG $FFFFFF
      ON_EDGE  $C8C8C8  HOT_BG     $E8E8E8  OFF_TEXT $606060

    The switch reads as one object with a lit position inside it, so the track is the shade
    that already means "chrome" here (the tool rail's), and the lit segment is the window's own
    background lifted out of it. Both were literal rather than clBtnFace/clWindow because the
    rail was literal: two greys that must match cannot be one system colour and one constant --
    and now they are one record, which is how they keep matching under a contrast theme too.

    THE LIT SEGMENT WAS THE BUG. Its caption was clWindowText on a hardcoded $FFFFFF, so a
    contrast theme's white ink landed on white and the current view's name disappeared. }

  PAD_X = 10;      { either side of a segment's content }
  GAP = 6;         { between an icon and its caption }
  RADIUS = 6;      { the track's corners -- a pill would read as a toggle, not a chooser }

constructor TSpxSegmented.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIndex := 0;
  FHot := -1;
  TabStop := True;
  { Painted whole, every time: without this LCL clears to the parent's colour first and the
    track flickers on every hover. }
  ControlStyle := ControlStyle + [csOpaque];
  { The colours this control drew with before there was a record to hold them, so it is right
    from its first paint whether or not the window ever applies a theme to it. }
  FChrome := SpxChrome(False);
end;

procedure TSpxSegmented.ApplyChrome(const AChrome: TSpxChrome);
begin
  FChrome := AChrome;
  Invalidate;
end;

procedure TSpxSegmented.Add(const ACaption: string; AIcon: Integer);
var n: Integer;
begin
  n := Length(FSegments);
  SetLength(FSegments, n + 1);
  FSegments[n].Caption := ACaption;
  FSegments[n].Icon := AIcon;
  Invalidate;
end;

procedure TSpxSegmented.SetCaption(AIndex: Integer; const ACaption: string);
begin
  if (AIndex < 0) or (AIndex > High(FSegments)) then Exit;
  FSegments[AIndex].Caption := ACaption;
  Invalidate;
end;

procedure TSpxSegmented.SetItemIndex(AValue: Integer);
begin
  if (AValue < 0) or (AValue > High(FSegments)) or (AValue = FIndex) then Exit;
  FIndex := AValue;
  Invalidate;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TSpxSegmented.SetImages(AValue: TCustomImageList);
begin
  FImages := AValue;
  { The list belongs to somebody else. TSpeedButton registers the same notification for the
    same reason: the app refills its lists in place today and never frees one, but a control
    that assumed that and was wrong would access-violate on the next paint rather than simply
    lose its pictures. }
  if FImages <> nil then FImages.FreeNotification(Self);
  Invalidate;
end;

procedure TSpxSegmented.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then
  begin
    FImages := nil;
    Invalidate;
  end;
end;

{ What one segment's content is wide: its icon, its gap, its text. ACanvas is the caller's --
  Paint has one already, and SegmentWidth makes ONE for its whole loop. Measuring on a bitmap
  created and freed per call cost a memory DC and a font realisation six times per resize
  frame; passing the canvas costs nothing and keeps no state that could go stale. }
function TSpxSegmented.ContentWidth(ACanvas: TCanvas; AIndex: Integer): Integer;
begin
  Result := 0;
  if (AIndex < 0) or (AIndex > High(FSegments)) then Exit;
  Result := ACanvas.TextWidth(FSegments[AIndex].Caption);
  if (FImages <> nil) and (FSegments[AIndex].Icon >= 0) then
    Inc(Result, FImages.Width + Px(Self, GAP));
end;

{ Every segment the same width -- the widest one's. Two positions of visibly different sizes
  read as two buttons again, which is the thing this control exists not to be.

  The measuring canvas is an offscreen bitmap's and not Self.Canvas: a control has no canvas
  to measure with before its handle exists, and the top strip lays itself out during
  construction. }
function TSpxSegmented.SegmentWidth: Integer;
var i, w: Integer; bmp: TBitmap;
begin
  Result := 0;
  bmp := TBitmap.Create;
  try
    bmp.Canvas.Font.Assign(Font);
    for i := 0 to High(FSegments) do
    begin
      w := ContentWidth(bmp.Canvas, i) + 2 * Px(Self, PAD_X);
      if w > Result then Result := w;
    end;
  finally
    bmp.Free;
  end;
end;

function TSpxSegmented.MeasureWidth: Integer;
begin
  Result := SegmentWidth * Length(FSegments) + 2;   { +2 for the track's own edge }
end;

function TSpxSegmented.SegmentAt(X: Integer): Integer;
var w: Integer;
begin
  Result := -1;
  w := SegmentWidth;
  if (w <= 0) or (Length(FSegments) = 0) then Exit;
  Result := (X - 1) div w;
  if Result < 0 then Result := 0;
  if Result > High(FSegments) then Result := High(FSegments);
end;

procedure TSpxSegmented.Paint;
var i, w, x, cx, ty, tw: Integer; r: TRect; on_: Boolean;
begin
  w := SegmentWidth;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  { the track }
  Canvas.Brush.Color := FChrome.TrackBack;
  Canvas.Pen.Color := FChrome.TrackEdge;
  Canvas.RoundRect(0, 0, w * Length(FSegments) + 2, Height,
    Px(Self, RADIUS) * 2, Px(Self, RADIUS) * 2);

  for i := 0 to High(FSegments) do
  begin
    x := 1 + i * w;
    on_ := (i = FIndex);
    r := Rect(x, 1, x + w, Height - 1);

    if on_ then
    begin
      Canvas.Brush.Color := FChrome.OnBack;
      Canvas.Pen.Color := FChrome.OnEdge;
      Canvas.RoundRect(r.Left, r.Top, r.Right, r.Bottom,
        Px(Self, RADIUS) * 2, Px(Self, RADIUS) * 2);
    end
    else if i = FHot then
    begin
      Canvas.Brush.Color := FChrome.HotBack;
      Canvas.Pen.Color := FChrome.HotBack;
      Canvas.RoundRect(r.Left, r.Top, r.Right, r.Bottom,
        Px(Self, RADIUS) * 2, Px(Self, RADIUS) * 2);
    end;

    { the content, centred in the segment }
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Assign(Font);
    if on_ then Canvas.Font.Color := FChrome.OnText else Canvas.Font.Color := FChrome.OffText;
    tw := ContentWidth(Canvas, i);
    cx := x + (w - tw) div 2;
    if (FImages <> nil) and (FSegments[i].Icon >= 0) then
    begin
      FImages.Draw(Canvas, cx, (Height - FImages.Height) div 2, FSegments[i].Icon, on_);
      Inc(cx, FImages.Width + Px(Self, GAP));
    end;
    ty := (Height - Canvas.TextHeight('Ag')) div 2;
    Canvas.TextOut(cx, ty, FSegments[i].Caption);
    Canvas.Brush.Style := bsSolid;

    { focus is shown on the LIT segment, not on the whole track: the track is not what the
      arrow keys move. }
    if Focused and on_ then
    begin
      Canvas.Pen.Color := FChrome.OnEdge;
      InflateRect(r, -3, -3);
      Canvas.DrawFocusRect(r);
    end;
  end;
end;

procedure TSpxSegmented.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    if CanFocus then SetFocus;
    ItemIndex := SegmentAt(X);
  end;
end;

procedure TSpxSegmented.MouseMove(Shift: TShiftState; X, Y: Integer);
var was: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  was := FHot;
  FHot := SegmentAt(X);
  if FHot <> was then Invalidate;
end;

procedure TSpxSegmented.MouseLeave;
begin
  inherited MouseLeave;
  if FHot <> -1 then
  begin
    FHot := -1;
    Invalidate;
  end;
end;

procedure TSpxSegmented.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  case Key of
    VK_LEFT, VK_UP: begin ItemIndex := FIndex - 1; Key := 0; end;
    VK_RIGHT, VK_DOWN: begin ItemIndex := FIndex + 1; Key := 0; end;
    VK_HOME: begin ItemIndex := 0; Key := 0; end;
    VK_END: begin ItemIndex := High(FSegments); Key := 0; end;
  end;
end;

procedure TSpxSegmented.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TSpxSegmented.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

end.
