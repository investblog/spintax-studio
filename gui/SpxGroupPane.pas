(*
 * SpxGroupPane -- the group under the caret, as a list you can edit.
 *
 * Editing `{a|b|c}` inside a long line of prose is the pain this solves: the alternatives are
 * a list, one per line, instead of a run of text with bars in it. The panel slides out of the
 * tool rail rather than opening as a dialog, for the reason the tool it borrows from proves:
 * GTW's «Мастер формул» carried its own preview precisely because a modal covered the
 * document, and this window already has a live one on the right.
 *
 * IT DECIDES NOTHING ABOUT SPINTAX. Which group the caret is in and what its variants are
 * come from `SpxGroups` (editor-core, gated by the suite), which in turn asks the scanner the
 * highlighter runs. Writing back goes through the same unit, which READS THE EDIT BACK and
 * refuses anything whose result would say something other than what was asked -- a variant
 * carrying `|`, `}`, `{` or `/#` all parse and all mean something else. When the write is
 * refused this panel says so and changes nothing; it does not try to be clever about why.
 *
 * A VARIANT WITH A LINE BREAK IN IT cannot be a line in a list, so a group that has one is
 * shown read-only rather than mangled. That is rare enough to be worth saying out loud and
 * common enough to be worth not corrupting.
 *)
unit SpxGroupPane;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Graphics, SpxStudio, SpxGroups, SpxUi,
  SpxStrings;

type
  { What the panel asks the window to do: replace the body of the group at [BodyStart, Stop)
    with this text. The window owns the editor, so it applies the change there -- through the
    editor's own text so undo keeps working -- rather than being handed a whole document. }
  TSpxGroupApply = procedure(BodyStart, Stop: Integer; const Body: string) of object;

  TSpxGroupPane = class(TPanel)
  private
    FWhat: TLabel;
    FList: TMemo;
    FApply: TButton;
    FSaid: TLabel;
    FGroup: TSpxGroup;
    FHas: Boolean;
    FReadOnly: Boolean;
    FDoc: string;
    FOnApply: TSpxGroupApply;
    procedure ApplyClicked(Sender: TObject);
    procedure Say(const AText: string);
  public
    constructor Create(AOwner: TComponent); override;
    { The document and where the caret is in it, in bytes. Cheap to call on a caret move: the
      panel does the work only when it is visible, and the window is what decides that. }
    procedure ShowGroupAt(const ADoc: string; AOffset: Integer);
    procedure Retranslate;
    property OnApply: TSpxGroupApply read FOnApply write FOnApply;
  end;

const
  { Wide enough for a variant of ordinary length and narrow enough to leave the editor its
    text. The rail's own width is separate -- this is the panel that slides out beside it. }
  SPX_SLIDE_W = 300;

implementation

constructor TSpxGroupPane.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Color := clWindow;

  { A STACK FROM THE TOP, not a client-filled panel. The rail is full height and the list is
    usually five short lines, so stretching it put the Apply button eight hundred pixels
    below the heading -- measured. Everything sits together at the top, and the space that
    is left is where the kind switch and a permutation's config fields will go. }
  FWhat := TLabel.Create(Self);
  FWhat.Parent := Self;
  { The Top is set BEFORE the alignment and only to order them: LCL sorts controls aligned
    to the same edge by that coordinate, and created-in-order was not enough -- the button
    came out above the list it applies. }
  FWhat.Top := 0;
  FWhat.Align := alTop;
  FWhat.BorderSpacing.Around := Px(Self, 8);
  FWhat.WordWrap := True;

  { One variant per line, and the editor's own font: these are pieces of the template, and
    reading them in a proportional face next to a monospaced editor is a small lie about
    what they are. }
  FList := TMemo.Create(Self);
  FList.Parent := Self;
  FList.Top := 100;
  FList.Align := alTop;
  FList.Height := Px(Self, 220);
  FList.BorderSpacing.Around := Px(Self, 8);
  FList.ScrollBars := ssAutoVertical;
  FList.WordWrap := False;
  SpxApplyMonoFont(FList.Font);

  FApply := TButton.Create(Self);
  FApply.Parent := Self;
  FApply.Top := 400;
  FApply.Align := alTop;
  FApply.BorderSpacing.Around := Px(Self, 8);
  FApply.Height := Px(Self, 26);
  FApply.OnClick := @ApplyClicked;

  FSaid := TLabel.Create(Self);
  FSaid.Parent := Self;
  FSaid.Top := 500;
  FSaid.Align := alTop;
  FSaid.BorderSpacing.Around := Px(Self, 8);
  FSaid.WordWrap := True;

  Retranslate;
end;

procedure TSpxGroupPane.Say(const AText: string);
begin
  FSaid.Caption := AText;
  FSaid.Visible := AText <> '';
end;

procedure TSpxGroupPane.Retranslate;
begin
  FApply.Caption := Tr(sGroupApply);
  if not FHas then FWhat.Caption := Tr(sGroupNone);
end;

procedure TSpxGroupPane.ShowGroupAt(const ADoc: string; AOffset: Integer);
const
  KIND: array[TSpxGroupKind] of TSpxStr =
    (sGroupChoice, sGroupConditional, sGroupPlural, sGroupPermutation);
var
  i: Integer;
  head: string;
begin
  FDoc := ADoc;
  FHas := SpxGroupAt(ADoc, AOffset, FGroup);
  Say('');
  if not FHas then
  begin
    FWhat.Caption := Tr(sGroupNone);
    FList.Lines.Clear;
    FList.ReadOnly := True;
    FApply.Enabled := False;
    Exit;
  end;

  head := FGroup.Head;
  if head <> '' then head := '  ' + head;
  FWhat.Caption := Tr(KIND[FGroup.Kind]) + head;

  { A variant that carries a line break cannot be a line in this list. Shown, not edited. }
  FReadOnly := False;
  for i := 0 to High(FGroup.Variants) do
    if (Pos(#10, FGroup.Variants[i]) > 0) or (Pos(#13, FGroup.Variants[i]) > 0) then
      FReadOnly := True;

  FList.Lines.BeginUpdate;
  try
    FList.Lines.Clear;
    for i := 0 to High(FGroup.Variants) do
      FList.Lines.Add(StringReplace(StringReplace(FGroup.Variants[i], #13#10, ' ',
        [rfReplaceAll]), #10, ' ', [rfReplaceAll]));
  finally
    FList.Lines.EndUpdate;
  end;
  FList.ReadOnly := FReadOnly;
  FApply.Enabled := not FReadOnly;
  if FReadOnly then Say(Tr(sGroupMultiline));
end;

procedure TSpxGroupPane.ApplyClicked(Sender: TObject);
var
  want: array of string;
  i: Integer;
  newDoc, body: string;
begin
  if (not FHas) or FReadOnly then Exit;
  SetLength(want, FList.Lines.Count);
  for i := 0 to FList.Lines.Count - 1 do want[i] := FList.Lines[i];

  { editor-core writes it and reads it back; a result that would say something else than
    this list leaves the document alone, and the panel says so rather than pretending. }
  if not SpxSetGroupVariants(FDoc, FGroup, want, newDoc) then
  begin
    Say(Tr(sGroupRefused));
    Exit;
  end;
  Say('');

  { Only the BODY goes to the editor, not the whole document: replacing everything would
    throw away the undo history and the caret with it. }
  body := '';
  for i := 0 to High(want) do
  begin
    if i > 0 then body := body + '|';
    body := body + want[i];
  end;
  if Assigned(FOnApply) then FOnApply(FGroup.BodyStart, FGroup.Stop, body);
end;

end.
