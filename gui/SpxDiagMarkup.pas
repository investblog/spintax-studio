(*
 * SpxDiagMarkup -- the engine's diagnostics, underlined where the engine said they are.
 *
 * A red wave under an error, an amber one under a warning, on the exact span TSpDiag
 * reported. Nothing here decides WHAT is wrong or WHERE: the marks arrive from
 * SpxDocumentMarks (editor-core, tested) which in turn only reshapes what SpValidate said.
 * Two rules it inherits and must keep: a diagnostic with Line = 0 is not drawn at all --
 * the engine admitted it could not locate the finding, and the panel is the honest place
 * for it -- and a fragment's positions never reach this class, because they are coordinates
 * in another buffer.
 *
 * One instance per severity, because a markup carries one attribute. The form creates two.
 *)
unit SpxDiagMarkup;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, SynEditMarkup, SynEditMiscClasses, SynEditTypes,
  LazSynEditText, SpxStudio;

type
  TSpxDiagMarkup = class(TSynEditMarkup)
  private
    FMarks: TSpxDiagMarks;      // only those matching FErrors
    FErrors: Boolean;
    { The span this mark covers on ARow, or False when it does not touch that row. }
    function RangeOnRow(const M: TSpxDiagMark; ARow: Integer;
      out AFrom, ATo: Integer): Boolean;
  public
    constructor Create(ASynEdit: TSynEditBase; AErrors: Boolean); reintroduce;
    procedure SetMarks(const AMarks: TSpxDiagMarks);
    function GetMarkupAttributeAtRowCol(const aRow: Integer;
      const aStartCol: TLazSynDisplayTokenBound;
      const AnRtlInfo: TLazSynDisplayRtlInfo): TSynSelectedColor; override;
    procedure GetNextMarkupColAfterRowCol(const aRow: Integer;
      const aStartCol: TLazSynDisplayTokenBound; const AnRtlInfo: TLazSynDisplayRtlInfo;
      out ANextPhys, ANextLog: Integer); override;
  end;

implementation

constructor TSpxDiagMarkup.Create(ASynEdit: TSynEditBase; AErrors: Boolean);
begin
  inherited Create(ASynEdit);
  FErrors := AErrors;
  MarkupInfo.Clear;
  { A wave under the span, nothing else: the text keeps the colours the highlighter gave it,
    so an error does not repaint the syntax out of a line. }
  MarkupInfo.FrameEdges := sfeBottom;
  MarkupInfo.FrameStyle := slsWaved;
  if AErrors then MarkupInfo.FrameColor := clRed
  else MarkupInfo.FrameColor := $000080C0;   { amber -- a warning is not a failure }
end;

procedure TSpxDiagMarkup.SetMarks(const AMarks: TSpxDiagMarks);
var i, n: Integer;
begin
  FMarks := nil;
  n := 0;
  for i := 0 to High(AMarks) do
    if AMarks[i].IsError = FErrors then
    begin
      if n = Length(FMarks) then SetLength(FMarks, 8 + n * 2);
      FMarks[n] := AMarks[i];
      Inc(n);
    end;
  SetLength(FMarks, n);
end;

function TSpxDiagMarkup.RangeOnRow(const M: TSpxDiagMark; ARow: Integer;
  out AFrom, ATo: Integer): Boolean;
begin
  Result := (ARow >= M.Line) and (ARow <= M.EndLine);
  if not Result then Exit;
  if ARow = M.Line then AFrom := M.Col else AFrom := 1;
  if ARow = M.EndLine then ATo := M.EndCol else ATo := MaxInt;
  Result := ATo > AFrom;
end;

function TSpxDiagMarkup.GetMarkupAttributeAtRowCol(const aRow: Integer;
  const aStartCol: TLazSynDisplayTokenBound;
  const AnRtlInfo: TLazSynDisplayRtlInfo): TSynSelectedColor;
var i, f, t: Integer;
begin
  Result := nil;
  for i := 0 to High(FMarks) do
    if RangeOnRow(FMarks[i], aRow, f, t) and
       (aStartCol.Logical >= f) and (aStartCol.Logical < t) then
    begin
      Result := MarkupInfo;
      MarkupInfo.SetFrameBoundsLog(f, t);
      Exit;
    end;
end;

procedure TSpxDiagMarkup.GetNextMarkupColAfterRowCol(const aRow: Integer;
  const aStartCol: TLazSynDisplayTokenBound; const AnRtlInfo: TLazSynDisplayRtlInfo;
  out ANextPhys, ANextLog: Integer);
var i, f, t: Integer;

  procedure Consider(ACol: Integer);
  begin
    if (ACol > aStartCol.Logical) and ((ACol < ANextLog) or (ANextLog < 0)) then
      ANextLog := ACol;
  end;

begin
  ANextPhys := -1;
  ANextLog := -1;
  for i := 0 to High(FMarks) do
    if RangeOnRow(FMarks[i], aRow, f, t) then
    begin
      Consider(f);
      if t <> MaxInt then Consider(t);
    end;
end;

end.
