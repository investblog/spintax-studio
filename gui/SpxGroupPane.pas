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
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Buttons, Graphics, ImgList, LCLType,
  SynEdit, SynEditTypes, SynEditWrappedView, SynGutter,
  SpxStudio, SpxGroups, SpxUi, SpxIcons, SpxSettings, SpxTheme, SpxStrIds, SpxStrings;

type
  { What the panel asks the window to do: replace the body of the group at [BodyStart, Stop)
    with this text. The window owns the editor, so it applies the change there -- through the
    editor's own text so undo keeps working -- rather than being handed a whole document. }
  TSpxGroupApply = procedure(BodyStart, Stop: Integer; const Body: string) of object;

  TSpxGroupPane = class(TPanel)
  private
    FClose: TSpeedButton;
    FWhat: TLabel;
    FList: TSynEdit;
    FApply: TButton;
    FSaid: TLabel;
    FGroup: TSpxGroup;
    FHas: Boolean;
    FReadOnly: Boolean;
    FDoc: string;
    FOnApply: TSpxGroupApply;
    FOnClose: TNotifyEvent;
    procedure ApplyClicked(Sender: TObject);
    procedure CloseClicked(Sender: TObject);
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HideGutterPart(const AClass: string);
    procedure Say(const AText: string);
    { The header line, from the group this panel is showing. One routine, so a language change
      can rebuild it as well as a move of the caret. }
    procedure SayWhat;
  public
    constructor Create(AOwner: TComponent); override;
    { The document and where the caret is in it, in bytes. Cheap to call on a caret move: the
      panel does the work only when it is visible, and the window is what decides that. }
    procedure ShowGroupAt(const ADoc: string; AOffset: Integer);
    { The list is an editor now, so it takes the theme and the zoom like the other two. }
    procedure ApplyTheme(const APalette: TSpxPalette);
    procedure ApplyEditorFont(const AFamily: string; APoints: Integer);
    procedure Retranslate;
    { Put the keyboard in the list. The window calls this when it opens the panel: the rail's
      tool cannot take focus itself (a TSpeedButton is a TGraphicControl), so without it the
      panel opens with the keyboard still in the editor and its own Escape is unreachable. }
    procedure FocusList;
    { The window's own 16px list, handed over rather than built here: it is refilled in place
      when the display's scaling changes, so this reference stays good (SpxUi.SpxImagesFrom). }
    procedure SetIcons(AImages: TCustomImageList);
    property OnApply: TSpxGroupApply read FOnApply write FOnApply;
    { The panel cannot hide itself -- the window owns the slot it lives in and the rail's
      button that opens it. }
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
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

  { THE CLOSE BUTTON FLOATS IN THE CORNER rather than taking a row of its own. A row cost
    26 px above the heading, which put this panel's first line lower than the editor's --
    every pane in the window is meant to start at the same height. Anchored top-right instead,
    with the heading given a matching right margin so a long one wraps BEFORE the button
    instead of under it: that is what keeps the wrapping (a permutation's heading is its whole
    configuration) and the alignment at the same time. }
  FClose := TSpeedButton.Create(Self);
  FClose.Parent := Self;
  FClose.Anchors := [akTop, akRight];
  FClose.SetBounds(Width - Px(Self, 30), Px(Self, 4), Px(Self, 26), Px(Self, 26));
  FClose.Flat := True;
  FClose.ImageIndex := SPX_ICON_CLOSE;
  FClose.ShowHint := True;
  FClose.OnClick := @CloseClicked;

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
  { Room for the button that floats over this row. }
  FWhat.BorderSpacing.Right := Px(Self, 8 + 30);
  FWhat.WordWrap := True;
  { The WEIGHT is not set here: this label is a heading in one state and a sentence in the
    other, so SayWhat decides it along with the words. One label rather than two, because the
    kind and its head are one sentence and splitting them would cost this panel a wrapping
    layout for no gain. }

  { One variant per line, and the editor's own font: these are pieces of the template, and
    reading them in a proportional face next to a monospaced editor is a small lie about
    what they are. }
  { A SYNEDIT, NOT A MEMO, and the gutter is the reason. A variant can be longer than any
    panel, and the two ways out of that both cost something: clipping hides text, wrapping
    makes one variant look like two -- which breaks the only promise this panel makes. A
    numbered gutter settles it: a wrapped continuation has NO number, so the eye reads the
    numbers and knows where each variant begins. That is worth a heavier control for a list
    of five short lines. }
  FList := TSynEdit.Create(Self);
  FList.Parent := Self;
  FList.Top := 100;
  FList.Align := alTop;
  FList.Height := Px(Self, 220);
  FList.BorderSpacing.Around := Px(Self, 8);
  { The gutter carries the numbers and nothing else. Marks, folding and the change stripe
    are for a document with bookmarks, foldable structure and a saved version -- none of
    which a five-line list of alternatives has. Measured on the main editor: those three plus
    the separator are 40 of the 55 px a default gutter takes. }
  FList.Gutter.Visible := True;
  HideGutterPart('TSynGutterMarks');
  HideGutterPart('TSynGutterChanges');
  HideGutterPart('TSynGutterSeparator');
  HideGutterPart('TSynGutterCodeFolding');

  { WRAPPING IS DECIDED ONCE, here, and never toggled: SynEdit's wrap plugin cannot be
    removed from a live editor -- freeing it access-violates and nilling its Editor leaves a
    dead line-mapping view (recorded in the charter). With wrapping on there is nothing to
    the right to scroll to, so the horizontal bar goes. }
  TLazSynEditLineWrapPlugin.Create(FList);
  FList.ScrollBars := ssAutoVertical;
  FList.Options := FList.Options - [eoScrollPastEol];
  FList.OnKeyDown := @ListKeyDown;
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

{ One of SynEdit's gutter parts, by class name: the gutter is a list whose membership is
  SynEdit's business, so a part is found rather than indexed, and a name this build does not
  ship is simply not there. }
procedure TSpxGroupPane.HideGutterPart(const AClass: string);
var i: Integer;
begin
  for i := 0 to FList.Gutter.Parts.Count - 1 do
    if FList.Gutter.Parts[i].ClassName = AClass then
      FList.Gutter.Parts[i].Visible := False;
end;

procedure TSpxGroupPane.ApplyTheme(const APalette: TSpxPalette);
var i: Integer;
begin
  if FList = nil then Exit;
  FList.Color := APalette.Back;
  FList.Font.Color := APalette.Text;
  FList.Gutter.Color := APalette.Gutter;
  { Every part, not just the numbers: a part left alone keeps a system colour and stays light
    on a dark page -- the way the main editor's marks column announced itself. }
  for i := 0 to FList.Gutter.Parts.Count - 1 do
  begin
    FList.Gutter.Parts[i].MarkupInfo.Background := APalette.Gutter;
    FList.Gutter.Parts[i].MarkupInfo.Foreground := APalette.GutterText;
  end;
  FList.SelectedColor.Background := APalette.Sel;
  FList.SelectedColor.Foreground := APalette.SelText;
  { THE PANEL AROUND IT DOES NOT FOLLOW, and that is the rule this window already has: the
    chrome is the system's and the EDITORS are themed. Painting the panel dark as well was
    tried and undone -- it left the close button, whose icon is a fixed dark grey, all but
    invisible on it, and it made this one panel disagree with every other surface in the
    window. A dark list inside light chrome is what the main editor already looks like. }
  Invalidate;
end;

procedure TSpxGroupPane.ApplyEditorFont(const AFamily: string; APoints: Integer);
begin
  if FList <> nil then SpxApplyEditorFont(FList.Font, AFamily, APoints);
end;

procedure TSpxGroupPane.FocusList;
begin
  if FList.CanSetFocus then FList.SetFocus;
end;

procedure TSpxGroupPane.SetIcons(AImages: TCustomImageList);
begin
  FClose.Images := AImages;
end;

procedure TSpxGroupPane.CloseClicked(Sender: TObject);
begin
  if Assigned(FOnClose) then FOnClose(Self);
end;

{ Escape closes it. The list is where the keyboard is while the panel is open -- FocusList
  puts it there, and that is what makes this reachable at all. A slide-out that can only be
  dismissed by the button that opened it is a slide-out people leave open. }
procedure TSpxGroupPane.ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    CloseClicked(Sender);
  end;
end;

procedure TSpxGroupPane.Retranslate;
begin
  FApply.Caption := Tr(sGroupApply);
  FClose.Hint := Tr(sClose);
  { THE HEADER TOO, and it did not before: the old line refreshed it only when there was NO
    group, so switching the interface language with one open left the kind's name in the
    previous language until the caret moved to another construct. Pre-existing, found by review
    of the line above it, and the same silent half-translation this project keeps catching --
    cheap to close now that one routine builds the caption. }
  SayWhat;
end;

procedure TSpxGroupPane.SayWhat;
const
  KIND: array[TSpxGroupKind] of TSpxStr =
    (sGroupChoice, sGroupConditional, sGroupPlural, sGroupPermutation);
  (* THE BRACKETS THE AUTHOR ACTUALLY TYPED, in front of the kind's name.

     The four kinds were named in plain text at the same weight as everything else in the
     header, and a reader reported that they read alike -- which matters because the LIST
     below means different things under each. Under a choice the lines are interchangeable
     alternatives; under a permutation they are a set that gets picked from AND ordered.
     Editing one as if it were the other is a mistake the panel was doing nothing to prevent.

     Nothing is invented here: `{a|b}` and `[a|b]` are how this language writes the two, so the
     mark is a fact of the syntax rather than an icon somebody has to learn. It also costs no
     string id -- which in this product is seventeen files -- and no sprite. A plural is braced
     like a choice because it IS braced like a choice; what separates those two is the head
     (`plural %n%:`), and the head is already on this line. *)
  MARK: array[TSpxGroupKind] of string = ('{|}', '{?|}', '{|}', '[|]');
var head: string;
begin
  { A HEADING IS BOLD; A SENTENCE IS NOT. The empty state is not a heading, it is the panel
    saying the caret is not inside a group -- and bolding that would be the message raising its
    voice for no reason. Found by review, which noticed the effect was wider than the reason. }
  if not FHas then
  begin
    FWhat.Font.Style := [];
    FWhat.Caption := Tr(sGroupNone);
    Exit;
  end;
  FWhat.Font.Style := [fsBold];
  head := FGroup.Head;
  if head <> '' then head := '  ' + head;
  FWhat.Caption := MARK[FGroup.Kind] + '  ' + Tr(KIND[FGroup.Kind]) + head;
end;

procedure TSpxGroupPane.ShowGroupAt(const ADoc: string; AOffset: Integer);
var
  i: Integer;
begin
  FDoc := ADoc;
  FHas := SpxGroupAt(ADoc, AOffset, FGroup);
  Say('');
  SayWhat;
  if not FHas then
  begin
    FList.Lines.Clear;
    FList.ReadOnly := True;
    FApply.Enabled := False;
    Exit;
  end;

  SayWhat;

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
