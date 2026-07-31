(*
 * SpxAboutForm -- the About box: the mark, the two versions, and the attributions.
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
  SpxStrIds, SpxStrings, SpxAbout;

{ Open it. SYSTEM-COLOURED, like the rest of the chrome: SpxTheme states the rule -- LCL has no
  dark mode on Windows, so a dark window under a light menu bar looks worse than a light one --
  and the main window follows it, theming only the editor, the preview and the panels. A dark
  dialog with a light title bar and a light native button on it was the one surface in the
  application that did not. Found by review, and the comment that used to sit here argued the
  opposite in the same words. }
procedure SpxShowAbout(AOwner: TComponent);

implementation

type
  TSpxAboutForm = class(TForm)
  private
    FMark: TImage;
    FTitle: TLabel;
    FVersion: TLabel;
    FText: TMemo;
    FClose: TButton;
    procedure CloseClicked(Sender: TObject);
    procedure PickMark;
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

  FText := TMemo.Create(Self);
  FText.Parent := Self;
  FText.SetBounds(24, 100, 472, 296);
  FText.ReadOnly := True;
  FText.ScrollBars := ssAutoVertical;
  FText.WordWrap := True;
  FText.TabStop := True;

  FClose := TButton.Create(Self);
  FClose.Parent := Self;
  FClose.SetBounds(396, 410, 100, 28);
  FClose.Caption := Tr(sClose);
  FClose.OnClick := @CloseClicked;
  FClose.Cancel := True;
  FClose.Default := True;
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
var i: Integer; body: TStringList;
begin
  Caption := Tr(sMenuAbout);
  { The version line is the one thing set apart, and by the SYSTEM's grey rather than a
    palette's: it is a detail beside the name, not a heading. }
  FVersion.Font.Color := clGrayText;

  body := TStringList.Create;
  try
    for i := 0 to SpxAboutLineCount - 1 do body.Add(SpxAboutLine(i));
    FText.Lines.Assign(body);
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
