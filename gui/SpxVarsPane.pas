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
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Grids, Graphics, SpxStudio, SpxUi, SpxStrings;

type
  TSpxJumpEvent = procedure(Line, Column: Integer) of object;

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
    FSig: string;                 // what the grids currently show
    FOnJump: TSpxJumpEvent;
    FOnRuntimeChanged: TNotifyEvent;
    procedure DefsClicked(Sender: TObject);
    procedure RuntimeEdited(Sender: TObject; ACol, ARow: Integer; const AValue: string);
    function KindName(Kind: TSpxVarKind): string;
    procedure FitLastColumn(AGrid: TStringGrid);
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
    property OnRuntimeChanged: TNotifyEvent read FOnRuntimeChanged write FOnRuntimeChanged;
  end;

implementation

constructor TSpxVarsPane.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FValues := TStringList.Create;
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
  FDefs.Options := FDefs.Options + [goRowSelect] - [goEditing, goRangeSelect];
  FDefs.OnClick := @DefsClicked;

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
  FRuntime.ColCount := 2;
  FRuntime.Cells[0, 0] := Tr(sColName);
  FRuntime.Cells[1, 0] := Tr(sColValue);
  FRuntime.ColWidths[0] := Px(Self, 140);
  FRuntime.ColWidths[1] := Px(Self, 660);
  { Column 0 stays FIXED here, and that is load-bearing: it is what keeps the name column
    read-only while goEditing is on. RuntimeEdited keys off that cell, so an editable name
    would file a value under a name the model never had. }
  FRuntime.Options := FRuntime.Options + [goEditing, goAlwaysShowEditor] - [goRangeSelect];
  FRuntime.OnSetEditText := @RuntimeEdited;

  FRuntimeLabel := TLabel.Create(Self);
  FRuntimeLabel.Parent := FRuntimeBox;
  FRuntimeLabel.Align := alTop;
  FRuntimeLabel.Caption := Tr(sVarsSession);
end;

procedure TSpxVarsPane.Retranslate;
begin
  FDefsLabel.Caption := Tr(sVarsDefinitions);
  FRuntimeLabel.Caption := Tr(sVarsSession);
  FDefs.Cells[0, 0] := Tr(sColKind);
  FDefs.Cells[1, 0] := Tr(sColName);
  FDefs.Cells[2, 0] := Tr(sColValue);
  FRuntime.Cells[0, 0] := Tr(sColName);
  FRuntime.Cells[1, 0] := Tr(sColValue);
end;

destructor TSpxVarsPane.Destroy;
begin
  FValues.Free;
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
  sig: string;
begin
  FModel := AVars;

  { Nothing is rebuilt when nothing changed. A result arrives on every debounce tick, and
    rebuilding a grid takes the selection with it -- worse, setting RowCount tears down the
    cell editor and LCL re-shows it with the caret forced to the end of the text, so typing
    anywhere but at the end of a value would be impossible. The diagnostics panel guards the
    same way and for the same reason. }
  sig := '';
  for i := 0 to High(AVars) do
    sig := sig + IntToStr(Ord(AVars[i].Kind)) + '|' + AVars[i].Name + '|' + AVars[i].Value +
           '|' + IntToStr(AVars[i].Line) + #10;
  if sig = FSig then Exit;
  FSig := sig;

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
      FRuntime.Cells[0, runRow] := AVars[i].Name;
      { The model carries the value that was in force for THIS render; the panel's own store
        only differs while a newer render is still in flight. }
      if FValues.IndexOfName(AVars[i].Name) >= 0 then
        FRuntime.Cells[1, runRow] := FValues.Values[AVars[i].Name]
      else
        FRuntime.Cells[1, runRow] := AVars[i].Value;
    end
    else
    begin
      Inc(defRow);
      FDefs.RowCount := defRow + 1;
      FDefs.Cells[0, defRow] := KindName(AVars[i].Kind);
      FDefs.Cells[1, defRow] := AVars[i].Name;
      FDefs.Cells[2, defRow] := AVars[i].Value;
      FRows[defRow - 1] := AVars[i];
    end;
  end;
  SetLength(FRows, defRow);
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
      Inc(n);
    end;
  SetLength(all, n);
  Result := SpxKeepRuntime(FModel, all);
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

procedure TSpxVarsPane.DefsClicked(Sender: TObject);
var idx: Integer;
begin
  idx := FDefs.Row - 1;
  if (idx < 0) or (idx > High(FRows)) then Exit;
  if FRows[idx].Line <= 0 then Exit;
  if Assigned(FOnJump) then FOnJump(FRows[idx].Line, FRows[idx].Column);
end;

end.
