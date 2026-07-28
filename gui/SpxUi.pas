(*
 * SpxUi -- the app's fonts and its unit of length.
 *
 * TWO RULES, both of them the user's settings rather than ours.
 *
 * THE FONT IS THE SYSTEM'S. Everything that is chrome -- labels, buttons, grids, panels --
 * inherits the font the person configured for their desktop, in their size. The first
 * version hard-coded `Segoe UI 11` and `Consolas 11`, which ignores a user who set a larger
 * system font for a reason, ignores a non-Latin desktop whose default UI font is not Segoe,
 * and ignores DPI. The editor and the source view are the exception and only in the FAMILY:
 * a template is markup, and markup wants a fixed pitch. Their SIZE still comes from the
 * system.
 *
 * LENGTH IS RELATIVE TO 96 DPI. Every literal that used to be a pixel goes through Px(),
 * which is the LCL's Scale96ToForm: on a 100% display it returns the number unchanged, on a
 * 150% one it returns half again as much. Without it a window laid out in code is a window
 * that fits exactly one display -- and the app is not even DPI-aware without the manifest,
 * so Windows would stretch it as a bitmap and blur every glyph.
 *
 * What this does NOT fix, and the chrome rework will: positions computed from a caption's
 * length in Russian. The interface is going to be switchable between languages, and a
 * German caption is a third longer than its Russian original -- so a row of controls has to
 * be laid out from their own widths, not from numbers measured once by hand.
 *)
unit SpxUi;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Forms;

{ A length in 96-dpi units, scaled to the control's display. }
function Px(AControl: TControl; AValue: Integer): Integer;

{ The fixed-pitch family for the editor and the source view: the first of these the system
  actually has. The SIZE is deliberately left alone, so it stays the system's.

  Ordered by how well they read at small sizes and by coverage: Cascadia ships with Windows
  Terminal and VS, Consolas with Windows itself, DejaVu is the usual Linux answer, Courier
  New is the last resort that always exists. All four carry Cyrillic. }
procedure SpxApplyMonoFont(AFont: TFont);

implementation

function Px(AControl: TControl; AValue: Integer): Integer;
var f: TCustomForm; ppi: Integer;
begin
  { The screen's dpi is the fallback, and it is not a detail: a panel computes its layout in
    its OWN constructor, before anything has given it a Parent, and TControl.Scale96ToForm
    raises "has no parent form" at that moment. The first version called it directly and the
    application died on startup -- caught by a probe rather than by reading, again.

    Once the control is parented the two agree: the form's dpi is the screen's until the
    window is dragged to a display with a different one, and per-monitor awareness then
    re-lays the form out through the same numbers. }
  ppi := Screen.PixelsPerInch;
  if AControl <> nil then
  begin
    f := GetParentForm(AControl);
    if f <> nil then ppi := f.PixelsPerInch;
  end;
  if ppi <= 0 then ppi := 96;
  Result := (AValue * ppi + 48) div 96;
end;

procedure SpxApplyMonoFont(AFont: TFont);
const
  CANDIDATES: array[0..3] of string =
    ('Cascadia Mono', 'Consolas', 'DejaVu Sans Mono', 'Courier New');
var i: Integer;
begin
  { The size is taken from the system rather than left inherited, because SynEdit does not
    inherit it: it pins its own 10 pt, which on a desktop configured for 9 is a percent too
    big and on one configured for 14 is half the size the person asked for. Measured -- the
    editor came out at 10 while Screen.SystemFont said 9. A control that DOES inherit (the
    source view) is unaffected: assigning the same number changes nothing. }
  if Screen.SystemFont.Size > 0 then AFont.Size := Screen.SystemFont.Size;

  for i := Low(CANDIDATES) to High(CANDIDATES) do
    if Screen.Fonts.IndexOf(CANDIDATES[i]) >= 0 then
    begin
      AFont.Name := CANDIDATES[i];
      Exit;
    end;
  { None of them installed: the inherited font stays. A proportional editor is worse than a
    fixed-pitch one, but naming a family the system does not have is worse than both -- it
    substitutes silently, and the substitute is usually proportional anyway. }
end;

end.
