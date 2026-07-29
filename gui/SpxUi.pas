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
  Classes, SysUtils, Controls, Graphics, Forms, ImgList{$IFDEF WINDOWS}, Windows{$ENDIF};

{ A length in 96-dpi units, scaled to the control's display. }
function Px(AControl: TControl; AValue: Integer): Integer;

{ A sprite, sliced into an image list: AData and ALen are a PNG strip of ACount cells laid out
  in one row, ACellW by ACellH each -- which is what SpxIcons and SpxFlags hold and what
  TImageList.AddSliced takes. Width and height are separate because a flag is not a square.

  AList IS REFILLED WHEN IT EXISTS, and only created (owned by AOwner) when it is nil. That
  is not an optimisation: every control that shows an image holds a REFERENCE to the list, and
  freeing one to build a bigger one does not crash -- LCL nils the reference from the free
  notification, so the buttons simply go blank, which is worse than a crash because it looks
  like nothing happened. Changing the size in place keeps every reference valid, which is what
  makes rebuilding at a new scaling safe. }
function SpxImagesFrom(AOwner: TComponent; AList: TImageList; AData: Pointer;
  ALen, ACellW, ACellH, ACount: Integer): TImageList;

{ A fixed-pitch family, in a hurry: the first of these the system has, at the system's size.

  THIS IS NO LONGER THE POLICY -- SpxEditorFont chooses the family by asking whether it can
  draw the DOCUMENT, and the size is the editor's own. This remains only so an editor is never
  briefly proportional between its construction and the moment the settings are applied, which
  is a flash the eye catches.

  Ordered by how well they read at small sizes and by coverage: Cascadia ships with Windows
  Terminal and VS, Consolas with Windows itself, DejaVu is the usual Linux answer, Courier
  New is the last resort that always exists. All four carry Cyrillic. }
procedure SpxApplyMonoFont(AFont: TFont);

{ The inverse of Px: a length measured on THIS display, back in 96-dpi units. Anything a
  window writes down has to make this trip, or a size saved on a 150% display comes back half
  again as large on the next launch -- Px would scale a number that had already been scaled. }
function Un96(AControl: TControl; AValue: Integer): Integer;

{ Put the editor's family and size on a font. The family may be empty -- that is the chooser
  saying nothing on this machine could draw the document -- and then only the size is set and
  whatever family the control has is kept. }
procedure SpxApplyEditorFont(AFont: TFont; const AFamily: string; APoints: Integer);

{ Is this family on this machine -- under a name we can ASK for, which is the part that is not
  obvious. Screen.Fonts alone is not the answer and the menu must not use it either; the body
  says why at length. }
function SpxFontInstalled(const AFamily: string): Boolean;

{ Can this family draw this sample on THIS machine: installed, and carrying a glyph for every
  character. The second half is the one that matters -- Screen.Fonts answers "is it here",
  not "can it draw Japanese", and the difference is a page of boxes. This is the real probe
  SpxEditorFont's chooser is handed; it lives here because it needs a device context and that
  unit deliberately needs nothing. }
function SpxFontCanDraw(const AFamily, ASample: string): Boolean;

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

function SpxImagesFrom(AOwner: TComponent; AList: TImageList; AData: Pointer;
  ALen, ACellW, ACellH, ACount: Integer): TImageList;
var ms: TMemoryStream; png: TPortableNetworkGraphic;
begin
  Result := AList;
  if Result = nil then Result := TImageList.Create(AOwner);
  { Clear before the size: setting either dimension clears anyway, and doing it in one place
    says so. }
  Result.Clear;
  Result.Width := ACellW;
  Result.Height := ACellH;
  ms := TMemoryStream.Create;
  try
    { A copy of the strip, not a view onto it: TMemoryStream owns what it holds. Sixteen
      hundred bytes for the rail, four thousand for the flags, once per scaling change. }
    ms.Write(AData^, ALen);
    ms.Position := 0;
    png := TPortableNetworkGraphic.Create;
    try
      png.LoadFromStream(ms);
      { One row of ACount cells -- the sprite's whole layout, in one call. }
      Result.AddSliced(png, ACount, 1);
    finally
      png.Free;
    end;
  finally
    ms.Free;
  end;
end;

function Un96(AControl: TControl; AValue: Integer): Integer;
var f: TCustomForm; ppi: Integer;
begin
  { The same fallback chain as Px, for the same reason it has one. }
  ppi := Screen.PixelsPerInch;
  if AControl <> nil then
  begin
    f := GetParentForm(AControl);
    if f <> nil then ppi := f.PixelsPerInch;
  end;
  if ppi <= 0 then ppi := 96;
  Result := (AValue * 96 + ppi div 2) div ppi;
end;

{$IFDEF WINDOWS}
const
  { Without it a missing character comes back as the font's own "not defined" box, which is
    indistinguishable from a glyph the font really has. }
  GGI_MARK_NONEXISTING_GLYPHS = 1;

{ FPC's Windows unit does not declare it -- checked -- so it is imported rather than worked
  around. gdi32, present since Windows 2000. }
function GetGlyphIndicesW(dc: HDC; lpsz: PWideChar; c: Integer; pgi: PWord;
  fl: DWORD): DWORD; stdcall; external 'gdi32' name 'GetGlyphIndicesW';

const
  { A family no machine has. Asking for it realises whatever this machine's font mapper
    substitutes, which is the only way to recognise a substitution when it happens to a name
    we actually wanted. }
  SPX_NO_SUCH_FAMILY = 'Spx No Such Family 9x';

var
  { Computed once, on the UI thread, the first time anything asks. }
  GSubstitute: string = '';
  GSubstituteKnown: Boolean = False;

{ A logical font by name, and the face GDI ACTUALLY realised for it. The two differ exactly
  when the family is not on the machine -- measured here: DejaVu Sans Mono, Noto Sans Mono,
  GulimChe and MingLiU all came back `Arial`, while Cascadia Mono, Consolas, MS Gothic and
  NSimSun came back as themselves. }
function RealisedFace(const AFamily: string): string;
var dc: HDC; fnt, old: HFONT; lf: TLogFontW; face: array[0..63] of WideChar;
begin
  Result := '';
  FillChar(lf{%H-}, SizeOf(lf), 0);
  lf.lfHeight := -12;
  lf.lfCharSet := DEFAULT_CHARSET;
  if Length(AFamily) >= Length(lf.lfFaceName) then Exit;
  StringToWideChar(AFamily, @lf.lfFaceName[0], Length(lf.lfFaceName));
  fnt := CreateFontIndirectW(@lf);
  if fnt = 0 then Exit;
  dc := GetDC(0);
  try
    old := SelectObject(dc, fnt);
    try
      FillChar(face{%H-}, SizeOf(face), 0);
      if GetTextFaceW(dc, Length(face), @face[0]) > 0 then
        Result := UTF8Encode(WideString(PWideChar(@face[0])));
    finally
      SelectObject(dc, old);
    end;
  finally
    ReleaseDC(0, dc);
    DeleteObject(fnt);
  end;
end;

function SubstituteFace: string;
begin
  if not GSubstituteKnown then
  begin
    GSubstitute := RealisedFace(SPX_NO_SUCH_FAMILY);
    GSubstituteKnown := True;
  end;
  Result := GSubstitute;
end;
{$ENDIF}

function SpxFontInstalled(const AFamily: string): Boolean;
begin
  if AFamily = '' then Exit(False);
  Result := Screen.Fonts.IndexOf(AFamily) >= 0;
  {$IFDEF WINDOWS}
  if Result then Exit;
  { AND THE SECOND QUESTION, because Screen.Fonts answers a narrower one than it looks.
    LCL builds it from EnumFontFamiliesEx, which reports family names LOCALISED: on a Japanese
    desktop MS Gothic enumerates as its Japanese name, so IndexOf('MS Gothic') is -1 there and
    the four CJK families in the cascade would be unreachable on exactly the machines they
    exist for -- and absent from the View menu too. GDI itself accepts the English name.

    So GDI is asked instead: realise the family, and see whether it gave us that family or
    substituted. A machine that will not say what it substitutes gets the enumerated answer
    and nothing worse than today. }
  if SubstituteFace = '' then Exit;
  Result := RealisedFace(AFamily) <> SubstituteFace;
  {$ENDIF}
end;

procedure SpxApplyEditorFont(AFont: TFont; const AFamily: string; APoints: Integer);
begin
  if AFont = nil then Exit;
  if AFamily <> '' then AFont.Name := AFamily;
  if APoints > 0 then AFont.Size := APoints;
end;

function SpxFontCanDraw(const AFamily, ASample: string): Boolean;
{$IFDEF WINDOWS}
var
  dc: HDC;
  fnt, old: HFONT;
  wide, ask: WideString;
  glyphs: array of Word;
  i: Integer;
  u: Word;
  lf: TLogFontW;
{$ENDIF}
begin
  Result := SpxFontInstalled(AFamily);
  if not Result then Exit;
  {$IFDEF WINDOWS}
  if ASample = '' then Exit;
  wide := UTF8Decode(ASample);
  if wide = '' then Exit;

  { SURROGATES ARE NOT ASKED ABOUT, and leaving them in was a defect with teeth.
    GetGlyphIndicesW maps UTF-16 code UNITS, one cmap lookup each, and no font maps a lone
    surrogate -- so an astral character arrived as two units that both came back "missing" and
    every candidate was rejected. Measured: one emoji anywhere in a template, and all eight
    families answered no; the chooser returned '', the editors kept whatever family they had,
    and a Japanese document went on being drawn in a Latin font. A single emoji in a template
    is not an edge case in this product.

    Dropping them is the honest answer rather than a workaround: this API cannot speak for
    astral characters, so they do not get a vote. Nothing is lost by that -- a fixed-pitch
    editor font has no emoji anyway, and Windows font-links them regardless of what is
    selected. The characters that DO decide the family are the ones left in. }
  ask := '';
  for i := 1 to Length(wide) do
  begin
    u := Word(wide[i]);
    if (u >= $D800) and (u <= $DFFF) then Continue;
    ask := ask + wide[i];
  end;
  { Nothing but astral characters: no evidence either way, and the installed answer stands. }
  if ask = '' then Exit;
  wide := ask;

  FillChar(lf{%H-}, SizeOf(lf), 0);
  lf.lfHeight := -12;
  lf.lfCharSet := DEFAULT_CHARSET;
  { A name that does not fit LOGFONT cannot be asked for faithfully -- and cannot be APPLIED
    faithfully either, since the editor's font would be selected through the same truncated
    name and Windows would substitute. So it is a no, not a yes: saying yes here would answer
    for the substitute while naming the candidate. }
  if Length(AFamily) >= Length(lf.lfFaceName) then Exit(False);
  StringToWideChar(AFamily, @lf.lfFaceName[0], Length(lf.lfFaceName));
  fnt := CreateFontIndirectW(@lf);
  if fnt = 0 then Exit;
  dc := GetDC(0);
  try
    old := SelectObject(dc, fnt);
    try
      SetLength(glyphs, Length(wide));
      if GetGlyphIndicesW(dc, PWideChar(wide), Length(wide), @glyphs[0],
                          GGI_MARK_NONEXISTING_GLYPHS) = DWORD(GDI_ERROR) then
        { The call itself failed: say nothing rather than something wrong, and let the
          installed check stand. }
        Exit;
      for i := 0 to High(glyphs) do
        if glyphs[i] = $FFFF then Exit(False);
    finally
      SelectObject(dc, old);
    end;
  finally
    ReleaseDC(0, dc);
    DeleteObject(fnt);
  end;
  {$ENDIF}
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
    editor came out at 10 while Screen.SystemFont said 9. Both callers are SynEdits now (the
    template editor and the source view), so both need this; the sentence that used to be
    here about a control that inherits described the TMemo the source view no longer is. }
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
