(*
 * SpxVarsPane -- the variables panel: what the document DEFINES, and what the session
 * SUPPLIES.
 *
 * Two groups, and they must never merge into one list (spec §4.4, the M2 decision). A
 * definition is `#set`/`#def` text living in the document, committed to git and read by
 * every other engine in the family; a runtime value is not in the document at all -- it
 * feeds the render context and `knownVariables` for this session only. One flat list would
 * teach the user that typing a value edits their file, which is true for one group and
 * false for the other.
 *
 * The definitions group is READ-ONLY here. Writing back has to go through SynEdit's own
 * edit API or undo and the caret misbehave, and that is its own slice; editor-core already
 * has the span rewriting it will use -- the SpxSetDirective family -- and every row already
 * carries the occurrence index those functions take. Until then a row jumps to its definition, which is
 * the other half of what the panel is for: finding the macro inside a long line.
 *
 * The runtime group IS editable, because nothing about it touches the document.
 *)
unit SpxVarsPane;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Grids, Graphics, LCLType,
  SpxStudio, SpxUi, SpxStrIds, SpxStrings;

type
  TSpxJumpEvent = procedure(Line, Column: Integer) of object;
  { A session row has no position to offer -- `SpExtract` returns reference names WITHOUT
    positions (the engine's own contract), so the model carries Line = 0 for every one of them.
    The panel therefore asks by NAME and the window finds the place, which it can: the
    highlighter's scanner already reports `%name%` occurrences with their offsets, and knows
    which ones are inside a comment. }
  TSpxFindRefEvent = procedure(const AName: string) of object;
  { Ctrl+click: stop supplying this per session and WRITE IT INTO THE DOCUMENT. A session value
    dies with the window; a definition is in the file, in git, and read by every engine in the
    family -- and it is the only thing that silences variable.undefined for good. The value
    goes with it so the work already typed is not thrown away. }
  TSpxDefineEvent = procedure(const AName, AValue: string) of object;
  { The names as the DOCUMENT spells them. The model can only report them folded: the engine
    keys macros lower-cased and `SpExtract` answers in its own case, so `%CasinoPrefix%` comes
    back `casinoprefix` and the panel used to show that. The window can tell -- its scanner
    reads the real text -- so it fills in the spelling for the names it is handed. }
  TSpxSpellEvent = procedure(ANames: TStringList) of object;
  { A DEFINITION'S VALUE, edited in its row -- the first thing in this panel that rewrites the
    DOCUMENT rather than the session. Returns whether the edit was applied: editor-core reads
    every edit back through the engine and refuses one whose result would say something else,
    and a refused row has to go back to what the file actually holds. }
  TSpxSetDefValueEvent = function(ADirIndex: Integer; const AValue: string): Boolean of object;

  TSpxVarsPane = class(TPanel)
  private
    FDefs: TStringGrid;
    FRuntime: TStringGrid;
    FDefsLabel: TLabel;
    FRuntimeLabel: TLabel;
    FRuntimeBox: TPanel;
    FSplit: TSplitter;
    FRows: TSpxVarInfos;          // the definitions, in the order the grid shows them
    FModel: TSpxVarInfos;         // the last model, for filtering what is sent
    FValues: TStringList;         // name -> value, the session's own
    (* Which of those the author means LITERALLY. Kept beside the values rather than encoded
       into them, because what the panel shows must stay what was typed: neutralising is not
       reversible by stripping -- SpStripSentinels takes the marked characters with it, so a
       round trip through it turns `{a|b}` into `a|b`. *)
    FLiteral: TStringList;        // name -> '1' for the ones handed over as text
    FSig: string;                 // what the grids currently show
    FOnJump: TSpxJumpEvent;
    FOnFindRef: TSpxFindRefEvent;
    FOnDefine: TSpxDefineEvent;
    FOnSpell: TSpxSpellEvent;
    FOnSetDefValue: TSpxSetDefValueEvent;
    { What was held down when the click started. OnClick does not carry it, and OnMouseDown
      runs before the grid has moved its current cell -- so the modifier is caught in the one
      and used in the other. }
    FClickShift: TShiftState;
    FOnRuntimeChanged: TNotifyEvent;
    procedure DefsClicked(Sender: TObject);
    procedure DefsSelectEditor(Sender: TObject; ACol, ARow: Integer;
      var Editor: TWinControl);
    procedure DefsValidate(Sender: TObject; ACol, ARow: Integer;
      const OldValue: string; var NewValue: string);
    procedure DefsEditorKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    function CommitDefValue(AIdx: Integer; const AOld, ANew: string): string;
    procedure RuntimeClicked(Sender: TObject);
    procedure RuntimeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure RuntimeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure RuntimeEdited(Sender: TObject; ACol, ARow: Integer; const AValue: string);
    procedure LiteralToggled(Sender: TObject; ACol, ARow: Integer; AState: TCheckboxState);
    function KindName(Kind: TSpxVarKind): string;
    procedure FitLastColumn(AGrid: TStringGrid);
    procedure SetRuntimeHeaders;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Redraws both groups from one model. Keeps every value the user has typed: a render
      arrives on every keystroke, and a grid that forgot the session on each of them would
      be unusable. }
    procedure SetModel(const AVars: TSpxVarInfos);
    { Every caption re-read, after the interface language changes. }
    procedure Retranslate;
    { What the next job should carry. Only names the document actually references are sent:
      a value left over from a variable the user has since defined is not a runtime value
      any more. }
    function RuntimeValues: TSpxVarPairs;
    property OnJump: TSpxJumpEvent read FOnJump write FOnJump;
    { Clicking a session row's NAME asks for the first place the document references it. }
    property OnFindRef: TSpxFindRefEvent read FOnFindRef write FOnFindRef;
    { Ctrl+clicking it asks for a definition in the document instead. }
    property OnDefine: TSpxDefineEvent read FOnDefine write FOnDefine;
    { Asked once per rebuild, never per row: the answer costs a document scan. }
    property OnSpell: TSpxSpellEvent read FOnSpell write FOnSpell;
    { Editing a definition's value writes to the document; the window does the writing. }
    property OnSetDefValue: TSpxSetDefValueEvent read FOnSetDefValue write FOnSetDefValue;
    property OnRuntimeChanged: TNotifyEvent read FOnRuntimeChanged write FOnRuntimeChanged;
  end;

implementation

constructor TSpxVarsPane.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FValues := TStringList.Create;
  FLiteral := TStringList.Create;
  FLiteral.CaseSensitive := False;
  FLiteral.UseLocale := False;
  { Names are ASCII by the engine's grammar and it matches them case-insensitively, so BRAND
    and brand are one value here -- but the comparison is the RTL's byte one, never the OS
    collation (see SpxStudio). }
  FValues.CaseSensitive := False;
  FValues.UseLocale := False;

  FDefsLabel := TLabel.Create(Self);
  FDefsLabel.Parent := Self;
  FDefsLabel.Align := alTop;
  FDefsLabel.Caption := Tr(sVarsDefinitions);

  FDefs := TStringGrid.Create(Self);
  FDefs.Parent := Self;
  FDefs.Align := alClient;
  FDefs.RowCount := 1;
  FDefs.FixedRows := 1;
  FDefs.ColCount := 3;
  FDefs.Cells[0, 0] := Tr(sColKind);
  FDefs.Cells[1, 0] := Tr(sColName);
  FDefs.Cells[2, 0] := Tr(sColValue);
  FDefs.ColWidths[0] := Px(Self, 60);
  FDefs.ColWidths[1] := Px(Self, 140);
  FDefs.ColWidths[2] := Px(Self, 600);
  { Column 0 carries data -- the kind -- so it must not be a FIXED column, which is what a
    grid defaults to. LCL treats a click in the fixed zone as a header click and suppresses
    OnClick entirely, so a third of every row would have been dead to click-to-jump. }
  FDefs.FixedCols := 0;
  { THE VALUE COLUMN IS EDITABLE, the other two are not -- and the gate is OnSelectEditor
    rather than a per-column ReadOnly, because per-column needs the Columns collection and
    adding that here would walk straight back into the trap the session grid's own comment
    records: with Columns, LCL sizes the grid as FixedCols + Columns.Count and the default
    FixedCols of 1 shifts every data column by one.

    goRowSelect stays, and it is compatible: LCL's EditingAllowed asks about goEditing and the
    column, never about row selection (grids.pas:8652). }
  { goEditing WITHOUT goAlwaysShowEditor, and the difference decides when an edit lands.
    Validation happens when the editor HIDES; with the editor always open it never hides while
    the cell stays current, so Enter committed nothing -- measured: the cell read `AkmeZ` and the
    document was untouched. Without always-show, Enter closes the editor and the value is
    applied, Escape abandons it, and F2 or typing opens it.

    It is also the safer shape for an edit that rewrites the FILE: a text box standing open on
    every row invites a change nobody meant to make. The session group is the opposite case and
    keeps always-show, because a value there is the panel's own and commits per keystroke. }
  FDefs.Options := FDefs.Options + [goRowSelect, goEditing] - [goRangeSelect];
  FDefs.OnSelectEditor := @DefsSelectEditor;
  { OnValidateEntry, NOT OnEditingDone -- measured. EditingDone fires BEFORE the grid copies the
    editor's text into the cell, so a handler reading Cells there sees the OLD value and decides
    nothing happened; the first version of this did exactly that and silently did nothing.
    ValidateEntry is the hook built for it (grids.pas:8590): NewValue arrives holding what was
    typed, and a value written back into it is written back into the cell -- which is the
    revert-on-refusal, for free. }
  FDefs.OnValidateEntry := @DefsValidate;
  FDefs.OnClick := @DefsClicked;
  { Every row here jumps, so the whole grid gets the hand -- the same signal as the session
    group's name column, for the same action. }
  FDefs.Cursor := crHandPoint;

  { The session group lives in its own panel: a splitter grabs the nearest sibling on the
    side it is aligned to, and with the label as a bare sibling that could be the label --
    17 pixels against a minimum drag of 30, i.e. a splitter that does nothing. One container
    removes the question. }
  { Same rule as the form's bottom strips: bottom-aligned siblings stack by their Top, so it
    is stated rather than left to creation order -- the box below, the splitter above it. }
  FRuntimeBox := TPanel.Create(Self);
  FRuntimeBox.Parent := Self;
  FRuntimeBox.Top := 20000;
  FRuntimeBox.Align := alBottom;
  FRuntimeBox.Height := Px(Self, 110);
  FRuntimeBox.BevelOuter := bvNone;

  FSplit := TSplitter.Create(Self);
  FSplit.Parent := Self;
  FSplit.Top := 10000;
  FSplit.Align := alBottom;
  FSplit.MinSize := Px(Self, 60);   { neither group may be dragged out of existence }

  FRuntime := TStringGrid.Create(Self);
  FRuntime.Parent := FRuntimeBox;
  FRuntime.Align := alClient;
  FRuntime.RowCount := 1;
  FRuntime.FixedRows := 1;
  FRuntime.ColCount := 3;
  { NOT Cells[x, 0]: this grid uses Columns objects, and LCL then draws the header from
    Columns[i].Title -- the cells are simply not what is on screen. Three assignments here and
    two more in Retranslate wrote to them anyway, which is why the session group's headers
    stayed in the language the WINDOW WAS BUILT IN while every other caption switched.
    Measured: switching the interface to German turned Cells[1,0] from `Value` into `Wert` and
    changed nothing visible. The titles are set in one place now, used by both paths. }
  FRuntime.ColWidths[0] := Px(Self, 140);
  FRuntime.ColWidths[1] := Px(Self, 570);
  FRuntime.ColWidths[2] := Px(Self, 90);
  { Column 0 stays FIXED here, and that is load-bearing: it is what keeps the name column
    read-only while goEditing is on. RuntimeEdited keys off that cell, so an editable name
    would file a value under a name the model never had. }
  FRuntime.Options := FRuntime.Options + [goEditing, goAlwaysShowEditor] - [goRangeSelect];
  FRuntime.OnSetEditText := @RuntimeEdited;
  { The third column is a checkbox rather than a word, because it is a yes/no about the value
    beside it and a word would be one more thing to translate into a column this narrow. }
  FRuntime.Columns.Add;
  FRuntime.Columns.Add;
  with FRuntime.Columns.Add do
  begin
    ButtonStyle := cbsCheckboxColumn;
    ValueChecked := '1';
    ValueUnchecked := '';
  end;
  { WITH Columns objects LCL sizes the grid as FixedCols + Columns.Count, and the default
    FixedCols of 1 shifted every data column by one -- measured: the session grid came back
    with four columns and the name where the code looked for the fixed one. The name stays
    read-only through the column itself now, which is what the old comment about column 0
    being fixed was really relying on. }
  FRuntime.FixedCols := 0;
  FRuntime.Columns[0].ReadOnly := True;
  FRuntime.Columns[0].Width := Px(Self, 140);
  FRuntime.Columns[1].Width := Px(Self, 570);
  FRuntime.Columns[2].Width := Px(Self, 90);
  FRuntime.OnCheckboxToggled := @LiteralToggled;
  { THE NAME COLUMN JUMPS, THE VALUE COLUMN EDITS -- split by column rather than by a
    modifier, because the two cells already have different jobs. A session row's name is
    read-only, so a click on it has nothing else to do; the value beside it must keep starting
    an edit on the first click, which is why the jump cannot be the plain click for the whole
    row the way it is in the definitions group. }
  FRuntime.OnClick := @RuntimeClicked;
  { THE HINT THAT NEEDS NO WORDS. A name that jumps has to say so before it is clicked, and a
    hand cursor is how everything else on this desktop says it -- no new caption to translate
    into fourteen languages, and it points at the ONE column that does it rather than at the
    group as a whole. }
  FRuntime.OnMouseMove := @RuntimeMouseMove;
  FRuntime.OnMouseDown := @RuntimeMouseDown;

  FRuntimeLabel := TLabel.Create(Self);
  FRuntimeLabel.Parent := FRuntimeBox;
  FRuntimeLabel.Align := alTop;
  FRuntimeLabel.Caption := Tr(sVarsSession);
  SetRuntimeHeaders;
end;

{ The session grid's headers, in the only place LCL reads them from. All three, including the
  checkbox column -- Retranslate used to leave that one alone entirely. }
procedure TSpxVarsPane.SetRuntimeHeaders;
begin
  if FRuntime.Columns.Count < 3 then Exit;
  FRuntime.Columns[0].Title.Caption := Tr(sColName);
  FRuntime.Columns[1].Title.Caption := Tr(sColValue);
  FRuntime.Columns[2].Title.Caption := Tr(sColLiteral);
end;

procedure TSpxVarsPane.Retranslate;
begin
  FDefsLabel.Caption := Tr(sVarsDefinitions);
  FRuntimeLabel.Caption := Tr(sVarsSession);
  FDefs.Cells[0, 0] := Tr(sColKind);
  FDefs.Cells[1, 0] := Tr(sColName);
  FDefs.Cells[2, 0] := Tr(sColValue);
  SetRuntimeHeaders;
end;

destructor TSpxVarsPane.Destroy;
begin
  FValues.Free;
  FLiteral.Free;
  inherited Destroy;
end;

{ The value column takes whatever the fixed ones leave. A width chosen in pixels is right for
  exactly one window size: narrower and the column a user actually reads is cut off behind a
  horizontal scrollbar, wider and the grid ends in a dead strip. }
procedure TSpxVarsPane.FitLastColumn(AGrid: TStringGrid);
var used, i, last: Integer;
begin
  if AGrid.ColCount < 1 then Exit;
  last := AGrid.ColCount - 1;
  used := 0;
  for i := 0 to last - 1 do used := used + AGrid.ColWidths[i];
  { A floor, so the column stays usable even when the pane is dragged very narrow. }
  if AGrid.ClientWidth - used > 120 then
    AGrid.ColWidths[last] := AGrid.ClientWidth - used
  else
    AGrid.ColWidths[last] := Px(Self, 120);
end;

procedure TSpxVarsPane.Resize;
begin
  inherited Resize;
  if FDefs <> nil then FitLastColumn(FDefs);
  if FRuntime <> nil then FitLastColumn(FRuntime);
end;

function TSpxVarsPane.KindName(Kind: TSpxVarKind): string;
begin
  case Kind of
    spxVarSet: Result := '#set';
    spxVarDef: Result := '#def';
  else
    Result := '';
  end;
end;

procedure TSpxVarsPane.SetModel(const AVars: TSpxVarInfos);
var
  i, defRow, runRow: Integer;
  sig, shown: string;
  spell: TStringList;
begin
  FModel := AVars;

  { Nothing is rebuilt when nothing changed. A result arrives on every debounce tick, and
    rebuilding a grid takes the selection with it -- worse, setting RowCount tears down the
    cell editor and LCL re-shows it with the caret forced to the end of the text, so typing
    anywhere but at the end of a value would be impossible. The diagnostics panel guards the
    same way and for the same reason. }
  sig := '';
  for i := 0 to High(AVars) do
    { A SESSION ROW'S VALUE IS NOT PART OF THE SIGNATURE, and leaving it in made the group
      impossible to type into. The chain: a character reaches RuntimeEdited, which restarts the
      render debounce; 200 ms later the render lands with a model whose runtime value is the
      character just typed; the signature therefore differs; the grid is rebuilt; RowCount tears
      down the cell editor. The next character then arrives at a grid with no open editor, and a
      grid with goEditing starts a FRESH edit on a character key -- replacing the cell instead of
      appending to it. Measured, typing `Vulkan` one letter at a time with a human pause:
      `[V]`, `[u]`, `[l]`, `[k]` -- never `[Vu]`. The value the user was building never existed,
      which is what "you can type but nothing sticks" looks like from the outside.

      Dropping it loses nothing: the loop below already prefers FValues over the model for a
      runtime row, precisely because the panel's own store is the newer of the two. The model's
      runtime value can only ever be '' or what this panel already sent. The NAMES still count,
      so a variable appearing or disappearing rebuilds as it must. }
    if AVars[i].Kind = spxVarRuntime then
      sig := sig + 'R|' + AVars[i].Name + #10
    else
      sig := sig + IntToStr(Ord(AVars[i].Kind)) + '|' + AVars[i].Name + '|' + AVars[i].Value +
             '|' + IntToStr(AVars[i].Line) + #10;
  if sig = FSig then Exit;
  FSig := sig;

  { THE SPELLINGS, once per rebuild. Asked here rather than per row because the answer costs a
    scan of the document, and asked only on a rebuild because this whole routine exits early
    when nothing changed. The lower-cased name stays the KEY everywhere -- FValues and FLiteral
    are case-insensitive, so a row displayed as `CasinoPrefix` still finds the value filed under
    `casinoprefix` -- and only what is SHOWN follows the document. }
  spell := TStringList.Create;
  try
    spell.CaseSensitive := False;
    spell.UseLocale := False;
    for i := 0 to High(AVars) do
      { `name=` with an EMPTY value, which is the "not found yet" marker the window fills in.
        Seeding it with the folded name instead would break first-occurrence-wins: a document
        whose first `%casinoprefix%` is already lower-case would leave the value equal to the
        key, and a later `%CasinoPrefix%` would then overwrite it. }
      (* BOTH GROUPS. A definition's name is folded by the engine exactly as a reference's is
        -- `SpExtractDirectives` reports `casinoname` for `#set %CasinoName%` -- and the
        scanner marks the name inside the directive as a variable too (measured: position 6 of
        `#set %CasinoName% = {Vul}`), so one pass answers for both. A name that is defined and
        also referenced gets ONE spelling, the first in the document; two spellings of one
        variable in two tables would be worse than either. *)
      if spell.IndexOfName(AVars[i].Name) < 0 then spell.Add(AVars[i].Name + '=');
    if Assigned(FOnSpell) and (spell.Count > 0) then FOnSpell(spell);

  FRows := nil;
  SetLength(FRows, Length(AVars));
  defRow := 0;
  runRow := 0;

  { Two passes over one model, because the two groups are two different things. }
  FDefs.RowCount := 1;
  FRuntime.RowCount := 1;
  for i := 0 to High(AVars) do
  begin
    if AVars[i].Kind = spxVarRuntime then
    begin
      Inc(runRow);
      FRuntime.RowCount := runRow + 1;
      shown := spell.Values[AVars[i].Name];
      if shown = '' then shown := AVars[i].Name;
      FRuntime.Cells[0, runRow] := shown;
      { The model carries the value that was in force for THIS render; the panel's own store
        only differs while a newer render is still in flight. }
      if FValues.IndexOfName(AVars[i].Name) >= 0 then
        FRuntime.Cells[1, runRow] := FValues.Values[AVars[i].Name]
      else
        FRuntime.Cells[1, runRow] := AVars[i].Value;
      FRuntime.Cells[2, runRow] := FLiteral.Values[AVars[i].Name];
    end
    else
    begin
      Inc(defRow);
      FDefs.RowCount := defRow + 1;
      FDefs.Cells[0, defRow] := KindName(AVars[i].Kind);
      shown := spell.Values[AVars[i].Name];
      if shown = '' then shown := AVars[i].Name;
      FDefs.Cells[1, defRow] := shown;
      FDefs.Cells[2, defRow] := AVars[i].Value;
      FRows[defRow - 1] := AVars[i];
    end;
  end;
  SetLength(FRows, defRow);
  finally
    spell.Free;
  end;
end;

{ What the next job should carry: the session's values, filtered to the names the document
  still references and nothing defines.

  The filter runs HERE rather than over the store, so a value survives a document the user
  is in the middle of editing. Deleting `%city%` to paste it three lines down, or pausing
  mid-rename for longer than the debounce, would otherwise throw the typed value away with
  no undo and no notice -- while filtering at send time costs nothing: a value for a name
  that is not a runtime variable right now is simply not sent. }
function TSpxVarsPane.RuntimeValues: TSpxVarPairs;
var i, n: Integer; all: TSpxVarPairs;
begin
  all := nil;
  SetLength(all, FValues.Count);
  n := 0;
  for i := 0 to FValues.Count - 1 do
    if FValues.Names[i] <> '' then
    begin
      all[n].Name := FValues.Names[i];
      all[n].Value := FValues.ValueFromIndex[i];
      all[n].Literal := FLiteral.Values[FValues.Names[i]] = '1';
      Inc(n);
    end;
  SetLength(all, n);
  Result := SpxKeepRuntime(FModel, all);
end;

{ The author says this value is text, not a template. Recorded per NAME rather than per row,
  because the rows are rebuilt from the model on every render and a row index means nothing
  between two of them. }
procedure TSpxVarsPane.LiteralToggled(Sender: TObject; ACol, ARow: Integer;
  AState: TCheckboxState);
var name_: string;
begin
  if (ACol <> 2) or (ARow < 1) then Exit;
  name_ := FRuntime.Cells[0, ARow];
  if name_ = '' then Exit;
  if AState = cbChecked then FLiteral.Values[name_] := '1'
  else FLiteral.Values[name_] := '';
  { A value that changes what it MEANS has to reach the engine at once, the same as a value
    that changes what it says. }
  if Assigned(FOnRuntimeChanged) then FOnRuntimeChanged(Self);
end;

procedure TSpxVarsPane.RuntimeEdited(Sender: TObject; ACol, ARow: Integer;
  const AValue: string);
var name_: string; idx: Integer;
begin
  if (ACol <> 1) or (ARow < 1) then Exit;
  name_ := FRuntime.Cells[0, ARow];
  if name_ = '' then Exit;
  { Clearing the cell must REMOVE the value, and the removal has to be explicit. FPC's
    TStringList keeps `name=` for an empty assignment (Delphi is the one that deletes --
    measured), and an empty value is a DEFINED value to the engine: it silences the
    variable.undefined the user was trying to bring back, and renders as nothing. }
  idx := FValues.IndexOfName(name_);
  if AValue = '' then
  begin
    if idx < 0 then Exit;
    FValues.Delete(idx);
  end
  else
    FValues.Values[name_] := AValue;
  if Assigned(FOnRuntimeChanged) then FOnRuntimeChanged(Self);
end;

{ Only the name column, and only a real row. Col is where the click landed: LCL has already
  moved the current cell by the time OnClick runs, which is what the definitions group relies
  on too. }
procedure TSpxVarsPane.RuntimeMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FClickShift := Shift;
end;

procedure TSpxVarsPane.RuntimeClicked(Sender: TObject);
var name_: string;
begin
  if FRuntime.Col <> 0 then Exit;
  if FRuntime.Row < 1 then Exit;
  name_ := FRuntime.Cells[0, FRuntime.Row];
  if name_ = '' then Exit;
  if ssCtrl in FClickShift then
  begin
    { The value goes with the name: the point of the action is to keep what the user typed and
      move it somewhere that survives. }
    if Assigned(FOnDefine) then FOnDefine(name_, FValues.Values[name_]);
    Exit;
  end;
  if Assigned(FOnFindRef) then FOnFindRef(name_);
end;

{ The hand only over the column that jumps. MouseToCell answers in CELL coordinates, so this
  does not have to know the column widths -- and it stays right after a column is resized. }
procedure TSpxVarsPane.RuntimeMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var col, row: Integer;
begin
  FRuntime.MouseToCell(X, Y, col, row);
  if (col = 0) and (row >= 1) then FRuntime.Cursor := crHandPoint
  else FRuntime.Cursor := crDefault;
end;

procedure TSpxVarsPane.DefsSelectEditor(Sender: TObject; ACol, ARow: Integer;
  var Editor: TWinControl);
begin
  { Only the value. Changing the KIND or the NAME is a different edit with its own function in
    editor-core and its own reasons to be refused; this slice is the value. }
  if ACol <> 2 then
  begin
    Editor := nil;
    Exit;
  end;
  { AND ENTER HAS TO ACCEPT, which LCL's own cell editor does not do: TStringCellEditor.KeyDown
    has cases for F2, Delete, Backspace, the arrows and Escape -- and no VK_RETURN at all
    (grids.pas:10663). Measured before believing it: the cell took `AkmeZ`, Enter left the editor
    open, and the document did not change until the current cell moved. Typing a value and
    pressing Enter to no effect is the same defect this panel was just cured of.

    Hooked on the editor LCL has just handed us. Its OnKeyDown event is free -- the class does
    its own key work by overriding the METHOD, not through the event. }
  if Editor <> nil then Editor.OnKeyDown := @DefsEditorKey;
end;

procedure TSpxVarsPane.DefsEditorKey(Sender: TObject; var Key: Word; Shift: TShiftState);
var idx: Integer; kept: string;
begin
  if Key <> VK_RETURN then Exit;
  Key := 0;
  { THE COMMIT IS DONE HERE, not left to the grid. Closing the editor does NOT validate --
    measured, and then confirmed in the source: EditorHide never calls EditorGetValue, and the
    only public routes that do are a selection MOVE (grids.pas:7996) and ResetEditor. So Enter
    would have closed the editor and dropped the edit on the floor.

    The new text comes from the editor itself; the OLD value is the MODEL's, which is what the
    document holds -- not the cell, which the grid has already been updating as the user typed. }
  idx := FDefs.Row - 1;
  if (idx >= 0) and (idx <= High(FRows)) and (Sender is TCustomEdit) then
  begin
    kept := CommitDefValue(idx, FRows[idx].Value, TCustomEdit(Sender).Text);
    FDefs.Cells[2, FDefs.Row] := kept;
  end;
  { Hiding it after the commit cannot commit a second time: EditorGetValue needs a VISIBLE
    editor (grids.pas:8590), and a later selection move finds none. }
  FDefs.EditorMode := False;
end;

{ THE ONE PLACE A DEFINITION'S VALUE IS COMMITTED, because there are two ways in and they must
  not drift: leaving the cell (LCL validates on a selection MOVE) and pressing Enter (LCL does
  not, so the panel does it). Returns what the cell should show afterwards -- the new value when
  the document took it, the old one when it did not. }
function TSpxVarsPane.CommitDefValue(AIdx: Integer; const AOld, ANew: string): string;
begin
  Result := AOld;
  if (AIdx < 0) or (AIdx > High(FRows)) then Exit;
  { ONLY WHEN IT ACTUALLY CHANGED: applying an unchanged value would splice the document -- and
    spend an undo step -- for opening a cell and leaving it alone. }
  if ANew = AOld then Exit(ANew);
  { AND ONLY IF THE ROW IS STILL THE ROW IT WAS. A render can rebuild the grid while the editor
    is open; if it did, this index no longer means what it meant when editing began, and the safe
    answer is to change nothing. }
  if AOld <> FRows[AIdx].Value then Exit;
  if not Assigned(FOnSetDefValue) then Exit;
  { A refusal leaves the old value showing: the document still says what it said, and a row
    showing something the file does not contain is the worse of the two states. }
  if FOnSetDefValue(FRows[AIdx].DirIndex, ANew) then Result := ANew;
end;

procedure TSpxVarsPane.DefsValidate(Sender: TObject; ACol, ARow: Integer;
  const OldValue: string; var NewValue: string);
begin
  if ACol <> 2 then Exit;
  { Whatever survives goes back into NewValue, and LCL writes that into the cell for us
    (grids.pas:8596). }
  NewValue := CommitDefValue(ARow - 1, OldValue, NewValue);
end;

procedure TSpxVarsPane.DefsClicked(Sender: TObject);
var idx: Integer;
begin
  { The value column edits; the kind and the name jump. Same split as the session group, and for
    the same reason -- a cell cannot both open an editor and move the caret away from it. }
  if FDefs.Col = 2 then Exit;
  idx := FDefs.Row - 1;
  if (idx < 0) or (idx > High(FRows)) then Exit;
  if FRows[idx].Line <= 0 then Exit;
  if Assigned(FOnJump) then FOnJump(FRows[idx].Line, FRows[idx].Column);
end;

end.
