(*
 * SpxToolRail -- the narrow strip of tools, on the side the user chose.
 *
 * DeepL's column sits beside the OUTPUT because its tools change the output. Ours change the
 * TEMPLATE -- variables, and the group editor that is coming -- so its home is the left, next
 * to the editor. The side is a setting, which is the user's call and costs nothing as long as
 * the layout asks this class rather than hardcoding an alignment.
 *
 * IT IS ACCESS, NOT WORKSPACE. The panels behind these buttons hold tables -- diagnostics,
 * variables, the variant list -- and a table in a narrow column is unreadable, so the rail
 * raises the panel where the data fits instead of trying to be that place. The exception is a
 * tool that is narrow BY NATURE (a group's variants are a list, one per line); when the group
 * editor lands it can live in the rail itself, which is why the width is a constant here
 * rather than a number sprinkled through the form.
 *
 * THE WIDTH IS FINAL, THE FACES ARE NOT. Buttons carry a letter today and an icon at step 4 of
 * the UX plan; icons are last on purpose, because their sizes follow the geometry rather than
 * the other way round. So the geometry is decided here, now, and the icon work will not move
 * anything.
 *)
unit SpxToolRail;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Graphics, SpxUi;

type
  { Which edge of the WINDOW the rail lives on. Not "which side of the editor": a user who
    moves it right expects it at the edge, the way every editor's side bar behaves. }
  TSpxRailSide = (spxRailLeft, spxRailRight);

  TSpxToolRail = class(TPanel)
  private
    FSide: TSpxRailSide;
    FButtons: array of TButton;
    procedure SetSide(AValue: TSpxRailSide);
    procedure Place;
  public
    constructor Create(AOwner: TComponent); override;
    { One tool. ALabel is the one or two characters shown until icons arrive; AHint is the
      tool's name, which is also what a translation changes. }
    function AddTool(const ALabel, AHint: string; AOnClick: TNotifyEvent): TButton;
    { The face and the name of the tool at AIndex, for a language switch. }
    procedure SetTool(AIndex: Integer; const ALabel, AHint: string);
    { Take the outer slot on the chosen edge. Two controls aligned to the same edge are laid
      out in the order the parent holds them, and creating the rail first is NOT enough --
      measured: at startup it landed between the editor and the preview, and only a change of
      side put it right. Called once the panes exist, and again whenever the side changes. }
    procedure Reassert;
    property Side: TSpxRailSide read FSide write SetSide;
  end;

const
  { Wide enough for a 36px square face plus the four pixels either side that keep it off the
    editor's text. Everything else in this unit is derived from it. }
  SPX_RAIL_W = 44;

implementation

constructor TSpxToolRail.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  { A shade off the window, so the strip reads as chrome rather than as content. Not a
    border: a line here would be one more frame in a layout whose whole point is not having
    them. }
  Color := $00F4F4F4;
  FSide := spxRailLeft;
  Align := alLeft;
  Width := Px(Self, SPX_RAIL_W);
end;

function TSpxToolRail.AddTool(const ALabel, AHint: string; AOnClick: TNotifyEvent): TButton;
var n: Integer;
begin
  n := Length(FButtons);
  SetLength(FButtons, n + 1);
  Result := TButton.Create(Self);
  Result.Parent := Self;
  Result.Caption := ALabel;
  Result.Hint := AHint;
  Result.ShowHint := True;
  Result.OnClick := AOnClick;
  FButtons[n] := Result;
  Place;
end;

procedure TSpxToolRail.SetTool(AIndex: Integer; const ALabel, AHint: string);
begin
  if (AIndex < 0) or (AIndex > High(FButtons)) then Exit;
  FButtons[AIndex].Caption := ALabel;
  FButtons[AIndex].Hint := AHint;
end;

procedure TSpxToolRail.Place;
var i, side_, y: Integer;
begin
  side_ := Px(Self, 36);
  y := Px(Self, 8);
  for i := 0 to High(FButtons) do
  begin
    FButtons[i].SetBounds(Px(Self, 4), y, side_, side_);
    Inc(y, side_ + Px(Self, 6));
  end;
end;

procedure TSpxToolRail.Reassert;
begin
  { The parent's CHILD ORDER decides which of two controls aligned to the same edge gets the
    outer slot, and creating the rail first does not settle it: measured, the window opened
    with the rail between the editor and the preview, and re-assigning Align alone did not
    move it either -- the layout is recomputed when the form is shown, from this list. }
  if Parent <> nil then Parent.SetControlIndex(Self, 0);
  Align := alNone;
  if FSide = spxRailLeft then
  begin
    Left := 0;
    Align := alLeft;
  end
  else
  begin
    if Parent <> nil then Left := Parent.ClientWidth - Width;
    Align := alRight;
  end;
  { The width is the rail's own, not the alignment's: LCL keeps it across the change, but an
    explicit assignment is what makes that true rather than lucky. }
  Width := Px(Self, SPX_RAIL_W);
  Place;
end;

procedure TSpxToolRail.SetSide(AValue: TSpxRailSide);
begin
  if AValue = FSide then Exit;
  FSide := AValue;
  Reassert;
end;

end.
