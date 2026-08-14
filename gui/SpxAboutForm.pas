(*
 * SpxAboutForm -- the About box: what this program is, and what it is obliged to credit.
 *
 * IT USED TO BE THE SECOND HALF ONLY, and the reader said so: "it tells you nothing about the
 * product and looks broken -- just technical". Three separate causes, all of them here or in
 * the generator, none of them in NOTICE.md:
 *   - the loudest thing in the window was `REQUIRES ATTRIBUTION IN THE SHIPPED APPLICATION`,
 *     a rubric for an audit shouted at somebody who wanted to know what the program does;
 *   - the text was wrapped once in the file at ~95 columns and again by the memo, which is
 *     what left `SynEdit and`, `IPro)` and `glyphs.` alone on lines;
 *   - and nothing said what Studio IS.
 * So the box now leads with a sentence in the READER's language, then the licence and the two
 * addresses, and only then the notice -- which is still in full, on the same screen, because
 * NOTICE.md asks for exactly that and a second click would weaken it.
 *
 * WHY THIS IS THE ONE SECONDARY WINDOW. ADR 0008 argued the help out of a window and into a
 * panel, and the reasoning holds for anything a reader keeps open while working. This is the
 * opposite case: it is short, it is opened deliberately, it is read once and dismissed, and it
 * has to show a picture -- which the help panel cannot do at all, because the renderer has no
 * data provider and the link routing depends on there being none (ADR 0004).
 *
 * Created, shown modally, freed. Nothing about it survives the call, so none of the traps a
 * long-lived second form brings -- Alt+Tab order, focus return, a caption that outlives the
 * document, a DPI change while hidden -- can reach it.
 *
 * WHAT IT SAYS IS NOT WRITTEN HERE. `SpxAbout` is generated from NOTICE.md, VERSION and the
 * engine submodule's tag, because NOTICE.md asks for exactly that and two copies of a licence
 * text drift silently. This unit is a window; the words are the other file's.
 *)
unit SpxAboutForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  LCLIntf, LCLType,
  SpxStrIds, SpxStrings, SpxAbout;

{ Open it. SYSTEM-COLOURED, like the rest of the chrome: SpxTheme states the rule -- LCL has no
  dark mode on Windows, so a dark window under a light menu bar looks worse than a light one --
  and the main window follows it, theming only the editor, the preview and the panels. A dark
  dialog with a light title bar and a light native button on it was the one surface in the
  application that did not. Found by review, and the comment that used to sit here argued the
  opposite in the same words. }
procedure SpxShowAbout(AOwner: TComponent);

implementation

const
  { THE REPORT CHANNEL (Store policy 11.16), a line of plain text since 2026-08-14 -- the
    owner's call: it lived in the Help menu as a mailto item, and the licence block here is
    where the obligations already sit. PLAIN TEXT on purpose: nothing is handed to the
    shell, so the privacy policy's link count moved from three to two when this moved in.
    The suite pins this string to the same address the three policy copies and the listing
    name, because an address living in five documents is an address that drifts. }
  SPX_SUPPORT_EMAIL = 'support@301.st';

type
  TSpxAboutForm = class(TForm)
  private
    FMark: TImage;
    FTitle: TLabel;
    FVersion: TLabel;
    FWhat: TLabel;
    FMeta: TLabel;
    FReport: TLabel;
    FRule: TBevel;
    FCredits: TLabel;
    FText: TMemo;
    FClose: TButton;
    procedure CloseClicked(Sender: TObject);
    procedure PickMark;
    { A wrapped label's height, measured on an offscreen canvas rather than read back off the
      control: a label does not know its own size until a layout pass it has not had yet, and
      this window places everything below the paragraph relative to its bottom. }
    function WrapHeight(const AText: string; AWidth: Integer; AFont: TFont): Integer;
    { And the notice's own wrapping, done here rather than left to the memo -- see Fill. }
    procedure WrapInto(ADest: TStrings; const AText, AIndent: string; AWidth: Integer);
  protected
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Fill;
  end;

constructor TSpxAboutForm.Create(AOwner: TComponent);
begin
  { CreateNew, not Create: there is no .lfm resource to load, the same as every other form
    here. }
  inherited CreateNew(AOwner);
  Position := poOwnerFormCenter;
  BorderStyle := bsDialog;
  Width := 520;
  { The height is computed in Fill, once the paragraph has been measured in the language the
    window is being shown in. This is only what the form is born with. }
  Height := 460;

  FMark := TImage.Create(Self);
  FMark.Parent := Self;
  FMark.SetBounds(24, 20, 64, 64);
  FMark.Proportional := True;
  FMark.Stretch := True;
  FMark.Center := True;
  { THE APPLICATION'S OWN ICON, not a second copy of the mark. It is already in the executable
    -- make-appicon.py puts it there as a resource, nine frames from 16 to 128 -- and a second
    embedded bitmap would be a second thing to keep in step with the brand.

    THE FRAME IS CHOSEN, not left to default. A TIcon draws its CURRENT frame and TImage does not
    pick one for you: assigning the icon and stopping there drew the 16 px frame blown up to 64,
    which looks like a mistake because it is one. Measured before this line existed. }
  PickMark;

  FTitle := TLabel.Create(Self);
  FTitle.Parent := Self;
  FTitle.SetBounds(104, 26, 380, 28);
  FTitle.Font.Size := 14;
  FTitle.Font.Style := [fsBold];
  FTitle.Caption := 'Spintax Studio';

  FVersion := TLabel.Create(Self);
  FVersion.Parent := Self;
  FVersion.SetBounds(104, 58, 380, 20);
  { Both versions on one line, and the engine's said out loud: this application is one of four
    implementations held to a shared corpus, and someone reporting a difference between them
    needs to know which engine answered here. }
  FVersion.Caption := SPX_VERSION + '  ·  spintax-win ' + SPX_ENGINE_VERSION;

  { WHAT THE PROGRAM IS, in the reader's own language and first on the screen. Everything
    below it is English by necessity -- a licence text is not translated -- and that is the
    line this window was missing entirely. }
  FWhat := TLabel.Create(Self);
  FWhat.Parent := Self;
  FWhat.WordWrap := True;
  FWhat.AutoSize := False;

  { The licence and the two addresses, in the system's grey: a detail line, not a heading. The
    licence NAME comes from the generated table rather than from a literal here -- there is one
    copy of it, in NOTICE.md, and this window is not going to become the second. }
  FMeta := TLabel.Create(Self);
  FMeta.Parent := Self;
  FMeta.WordWrap := True;
  FMeta.AutoSize := False;
  FMeta.Font.Color := clGrayText;

  { The report line, same grey, same rank: a detail among the obligations, in the reader's
    language (the menu caption it descends from is already in all fourteen). }
  FReport := TLabel.Create(Self);
  FReport.Parent := Self;
  FReport.WordWrap := True;
  FReport.AutoSize := False;
  FReport.Font.Color := clGrayText;

  FRule := TBevel.Create(Self);
  FRule.Parent := Self;
  FRule.Shape := bsTopLine;

  FCredits := TLabel.Create(Self);
  FCredits.Parent := Self;
  FCredits.Font.Color := clGrayText;

  FText := TMemo.Create(Self);
  FText.Parent := Self;
  FText.ReadOnly := True;
  FText.ScrollBars := ssAutoVertical;
  FText.WordWrap := True;
  FText.TabStop := True;

  FClose := TButton.Create(Self);
  FClose.Parent := Self;
  FClose.Caption := Tr(sClose);
  FClose.OnClick := @CloseClicked;
  FClose.Cancel := True;
  FClose.Default := True;
end;

function TSpxAboutForm.WrapHeight(const AText: string; AWidth: Integer; AFont: TFont): Integer;
var bmp: TBitmap; r: TRect;
begin
  bmp := TBitmap.Create;
  try
    bmp.Canvas.Font.Assign(AFont);
    r := Rect(0, 0, AWidth, 10000);
    { DT_CALCRECT measures instead of drawing, and DT_WORDBREAK makes it measure the wrap this
      label will do rather than one long line. }
    DrawText(bmp.Canvas.Handle, PChar(AText), Length(AText), r,
             DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
    Result := r.Bottom - r.Top;
  finally
    bmp.Free;
  end;
end;

(* THE NOTICE IS WRAPPED HERE, not by the memo, and the reason is one the memo cannot fix: a
   TMemo has no hanging indent. An entry's body is written with two leading spaces so it sits
   under its heading, and when the memo broke that paragraph the SECOND line came back flush
   left -- under the entry's NAME rather than under its text, which is what the reader saw as
   the lines falling apart.

   So the wrap is greedy, by measured word widths, into a width the window knows and the memo
   does not have to guess at, and EVERY line of the paragraph carries the indent -- the block
   sits under its heading instead of sliding out from under it on the second line. WordWrap
   stays ON as a net: if a measurement is ever a few pixels optimistic the memo still breaks
   the line rather than clipping it, and the only loss is the indent on that one line.

   A word longer than the whole width -- a URL -- is placed alone and left to the memo, which
   is the one case where breaking mid-word beats a line that runs off the edge. *)
procedure TSpxAboutForm.WrapInto(ADest: TStrings; const AText, AIndent: string;
  AWidth: Integer);
var
  bmp: TBitmap;
  p, q, indentW: Integer;
  word_, line, cand: string;
begin
  bmp := TBitmap.Create;
  try
    bmp.Canvas.Font.Assign(FText.Font);
    indentW := bmp.Canvas.TextWidth(AIndent);
    line := '';
    p := 1;
    { SPLIT BY HAND, on spaces and nothing else, because TStringList.DelimitedText EDITS THE
      TEXT. `StrictDelimiter` does not turn quoting off: measured on this very sentence,
      `headers offer "GPL Version 2 or later" as an alternative` comes back as six items of
      which one is `GPL Version 2 or later` -- the run merged and **the quotation marks gone**.
      A routine that lays text out is not allowed to alter it, and this text is a licence
      notice. Nothing about the wrapping needs a parser, so it does not have one. }
    while p <= Length(AText) do
    begin
      q := p;
      while (q <= Length(AText)) and (AText[q] <> ' ') do Inc(q);
      word_ := Copy(AText, p, q - p);
      p := q + 1;
      if word_ = '' then Continue;
      if line = '' then cand := word_ else cand := line + ' ' + word_;
      if (line <> '') and (bmp.Canvas.TextWidth(cand) + indentW > AWidth) then
      begin
        ADest.Add(AIndent + line);
        line := word_;
      end
      else
        line := cand;
    end;
    if line <> '' then ADest.Add(AIndent + line);
  finally
    bmp.Free;
  end;
end;

{ AND PICKED AGAIN WHEN THE SIZE CHANGES. The .ico carries nine frames from 16 to 128 and a
  form is CONSTRUCTED at 96 dpi -- LCL applies the monitor's afterwards, which is the lesson the
  main window's AutoAdjustLayout already records. Picked once for a literal 64, a 150% desktop
  stretched the 64 frame into a 96 box and the hexagon came out jagged, with a 96 frame sitting
  unused in the same file. Measured through LCL's own rescale. }
procedure TSpxAboutForm.PickMark;
var mark: TIcon;
begin
  if (Application.Icon = nil) or (Application.Icon.Count = 0) then Exit;
  mark := TIcon.Create;
  try
    mark.Assign(Application.Icon);
    mark.Current := mark.GetBestIndexForSize(Size(FMark.Width, FMark.Height));
    FMark.Picture.Assign(mark);
  finally
    mark.Free;
  end;
end;

procedure TSpxAboutForm.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
begin
  inherited DoAutoAdjustLayout(AMode, AXProportion, AYProportion);
  { After, not before: the image has its new size by now, and that is what decides the frame. }
  PickMark;
end;

procedure TSpxAboutForm.CloseClicked(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TSpxAboutForm.Fill;
const
  L = 24;                 { the left margin every block shares }
  W = 472;                { and the width, which is the form's less both margins }
var
  i, y, h: Integer;
  body: TStringList;
  what_: string;
begin
  Caption := Tr(sMenuAbout);
  { The version line is the one thing set apart, and by the SYSTEM's grey rather than a
    palette's: it is a detail beside the name, not a heading. }
  FVersion.Font.Color := clGrayText;

  { THE TEXT FIRST, THE GEOMETRY AFTER IT, because the paragraph's height is the language's:
    the same sentence is three lines in German and two in English, and every block below it
    starts where it ends. Nothing here is a guess at a line count. }
  FWhat.Caption := Tr(sAboutWhat);
  FMeta.Caption := SpxAboutLicence(0) + '   ·   spintax.net   ·   301.st';
  { The menu caption this line descends from ends in an ellipsis -- the mark of an item
    that OPENS something. This line opens nothing, so the ellipsis goes. }
  what_ := Tr(sMenuReportAi);
  if Copy(what_, Length(what_) - 2, 3) = '…' then
    SetLength(what_, Length(what_) - 3);
  FReport.Caption := what_ + ': ' + SPX_SUPPORT_EMAIL;
  FCredits.Caption := Tr(sAboutCredits);

  y := 100;
  h := WrapHeight(FWhat.Caption, W, FWhat.Font);
  FWhat.SetBounds(L, y, W, h);

  y := y + h + 10;
  h := WrapHeight(FMeta.Caption, W, FMeta.Font);
  FMeta.SetBounds(L, y, W, h);

  y := y + h + 4;
  h := WrapHeight(FReport.Caption, W, FReport.Font);
  FReport.SetBounds(L, y, W, h);

  y := y + h + 14;
  FRule.SetBounds(L, y, W, 2);

  y := y + 10;
  h := WrapHeight(FCredits.Caption, W, FCredits.Font);
  FCredits.SetBounds(L, y, W, h);

  { The notice takes what is left, and the window grows to keep it a fixed size rather than
    letting a long translation eat it. }
  y := y + h + 6;
  FText.SetBounds(L, y, W, 230);
  ClientHeight := y + 230 + 58;
  FClose.SetBounds(ClientWidth - L - 100, ClientHeight - 44, 100, 28);

  { THE WIDTH THE NOTICE IS WRAPPED TO, and it is the memo's INSIDE: the frame takes a couple
    of pixels each side and the vertical scroll bar is always there, because this text has never
    fitted without one. Asked of the system rather than assumed, and then a few pixels of slack,
    so a measurement that is optimistic by a hair does not hand the line back to the memo. }
  body := TStringList.Create;
  try
    h := FText.Width - GetSystemMetrics(SM_CXVSCROLL) - 12;
    for i := 0 to SpxAboutLineCount - 1 do
    begin
      { A body paragraph is the one thing that needs breaking; a heading or a `Name -- Licence`
        line is short by construction and goes through as it is. }
      if Copy(SpxAboutLine(i), 1, 2) = '  ' then
        WrapInto(body, Trim(SpxAboutLine(i)), '  ', h)
      else
        body.Add(SpxAboutLine(i));
    end;
    FText.Lines.Assign(body);
    {$IFDEF SPX_ABOUT_TRACE}
    { What the box will actually show, written where a GUI-subsystem probe can read it: this
      window has no console at all, and the question -- whose wrap is on screen, mine or the
      memo's -- cannot be answered from the outside. }
    body.Insert(0, Format('-- wrap width %d px, memo %d px, scrollbar %d px --',
                          [h, FText.Width, GetSystemMetrics(SM_CXVSCROLL)]));
    body.SaveToFile(GetEnvironmentVariable('SPX_ABOUT_TRACE'));
    {$ENDIF}
  finally
    body.Free;
  end;
  { At the top, whatever the memo did while it was being filled. }
  FText.SelStart := 0;
end;

procedure SpxShowAbout(AOwner: TComponent);
var f: TSpxAboutForm;
begin
  f := TSpxAboutForm.Create(AOwner);
  try
    f.Fill;
    f.ShowModal;
  finally
    f.Free;
  end;
end;

end.
