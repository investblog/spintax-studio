(*
 * SpxSourceMarkup -- paints back the text that the HTML highlighter mistook for a tag.
 *
 * TSynHTMLSyn opens a tag at every `<`, so `Цена < 100` turns the rest of the line -- and, if
 * no `>` follows, the rest of the paragraph -- into attribute colours. The rule it should
 * follow, and the one the whole family and every browser follows, is in SpxHtmlScan; this
 * class is only the brush. WHERE the wrong colours are is editor-core's answer, gated by the
 * suite; nothing here decides it.
 *
 * Why an overlay instead of a corrected highlighter: fProcTable, MakeMethodTables and
 * BraceOpenProc are PRIVATE in TSynHTMLSyn, so a descendant cannot reach them, and copying
 * 2600 lines of LCL into this repo to change one branch would be a permanent maintenance
 * cost for a colour. The markup manager already composes over the highlighter -- that is what
 * SpxDiagMarkup does for the wavy underlines -- so this is the seam the toolkit offers.
 *)
unit SpxSourceMarkup;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, SynEditMarkup, SynEditMiscClasses, SynEditTypes,
  LazSynEditText, SpxHtmlScan;

type
  TSpxSourceMarkup = class(TSynEditMarkup)
  private
    FSpans: TSpxSpans;
    FScanned: string;
    function RangeOnRow(const S: TSpxSpan; ARow: Integer;
      out AFrom, ATo: Integer): Boolean;
    { The first span whose END is beyond (ARow, ACol) -- and therefore the ONLY one that can
      cover that position, since the spans come out of the scan in document order and do not
      overlap (the suite asserts it). Bisecting on the row alone was not enough: a 828 KB
      output on ONE line puts all 12 000 spans on row 1, measured at 55 ms per 300 queries --
      a stutter on exactly the document shape the pane already treats as special. }
    function FirstFrom(ARow, ACol: Integer): Integer;
  public
    constructor Create(ASynEdit: TSynEditBase); reintroduce;
    { The text the view is showing. Rescans only when it actually changed: the preview calls
      this on every debounce tick, and the scan is a pass over the whole output. }
    procedure SetText(const AText: string);
    { What plain text looks like in this editor. Taken from the highlighter's own text
      attribute rather than assumed, so the overlay agrees with the colour scheme instead of
      hardcoding black. }
    procedure SetTextColour(AColour: TColor);
    function GetMarkupAttributeAtRowCol(const aRow: Integer;
      const aStartCol: TLazSynDisplayTokenBound;
      const AnRtlInfo: TLazSynDisplayRtlInfo): TSynSelectedColor; override;
    procedure GetNextMarkupColAfterRowCol(const aRow: Integer;
      const aStartCol: TLazSynDisplayTokenBound; const AnRtlInfo: TLazSynDisplayRtlInfo;
      out ANextPhys, ANextLog: Integer); override;
  end;

implementation

constructor TSpxSourceMarkup.Create(ASynEdit: TSynEditBase);
begin
  inherited Create(ASynEdit);
  MarkupInfo.Clear;
  MarkupInfo.Foreground := clWindowText;
  { The WEIGHT as well as the colour. Every attribute this overlay paints over -- symbol,
    identifier, key, undefined key -- is [fsBold] in TSynHTMLSyn, so recolouring alone left
    the prose black and still bold, which is not what text looks like. A markup clears a style
    by naming it in the mask and leaving it out of the style itself. }
  MarkupInfo.Style := [];
  MarkupInfo.StyleMask := [fsBold, fsItalic, fsUnderline];
  { And it has to outrank what it is painting over. TSynSelectedColorMergeResult.Merge keeps
    the existing style for any bit whose incoming priority is LOWER
    (syneditmiscclasses.pp:1369), so a mask alone changes nothing -- measured: the prose came
    out black and still bold. }
  MarkupInfo.StylePriority[fsBold] := 100;
  MarkupInfo.StylePriority[fsItalic] := 100;
  MarkupInfo.StylePriority[fsUnderline] := 100;
  { Background is left alone on purpose: the run is TEXT, and text here has no background of
    its own. Setting one would put a grey box round the very thing the fix is trying to make
    unremarkable. }
end;

procedure TSpxSourceMarkup.SetTextColour(AColour: TColor);
begin
  if AColour = clNone then AColour := clWindowText;
  MarkupInfo.Foreground := AColour;
end;

procedure TSpxSourceMarkup.SetText(const AText: string);
begin
  if AText = FScanned then Exit;
  FScanned := AText;
  FSpans := SpxHtmlPhantomTags(AText);
end;

function TSpxSourceMarkup.FirstFrom(ARow, ACol: Integer): Integer;
var lo, hi, mid: Integer;
begin
  lo := 0;
  hi := Length(FSpans);
  while lo < hi do
  begin
    mid := (lo + hi) div 2;
    if (FSpans[mid].EndLine < ARow) or
       ((FSpans[mid].EndLine = ARow) and (FSpans[mid].EndCol <= ACol)) then lo := mid + 1
    else hi := mid;
  end;
  Result := lo;
end;

function TSpxSourceMarkup.RangeOnRow(const S: TSpxSpan; ARow: Integer;
  out AFrom, ATo: Integer): Boolean;
begin
  Result := (ARow >= S.Line) and (ARow <= S.EndLine);
  if not Result then Exit;
  if ARow = S.Line then AFrom := S.Col else AFrom := 1;
  if ARow = S.EndLine then ATo := S.EndCol else ATo := MaxInt;
  Result := ATo > AFrom;
end;

function TSpxSourceMarkup.GetMarkupAttributeAtRowCol(const aRow: Integer;
  const aStartCol: TLazSynDisplayTokenBound;
  const AnRtlInfo: TLazSynDisplayRtlInfo): TSynSelectedColor;
var i, f, t: Integer;
begin
  Result := nil;
  { One candidate, not a walk: spans do not overlap, so the first one ending past this
    position either covers it or starts after it. }
  i := FirstFrom(aRow, aStartCol.Logical);
  if (i <= High(FSpans)) and RangeOnRow(FSpans[i], aRow, f, t) and
     (aStartCol.Logical >= f) and (aStartCol.Logical < t) then
  begin
    Result := MarkupInfo;
    MarkupInfo.SetFrameBoundsLog(f, t);
  end;
end;

procedure TSpxSourceMarkup.GetNextMarkupColAfterRowCol(const aRow: Integer;
  const aStartCol: TLazSynDisplayTokenBound; const AnRtlInfo: TLazSynDisplayRtlInfo;
  out ANextPhys, ANextLog: Integer);
var i, f, t: Integer;
begin
  ANextPhys := -1;
  ANextLog := -1;
  { The same single candidate. Its start is the next boundary if it lies ahead; otherwise the
    position is inside it and its end is. Nothing later on this row can be nearer, because
    the spans are ordered and do not overlap. }
  i := FirstFrom(aRow, aStartCol.Logical);
  if (i > High(FSpans)) or not RangeOnRow(FSpans[i], aRow, f, t) then Exit;
  if f > aStartCol.Logical then ANextLog := f
  else if (t <> MaxInt) and (t > aStartCol.Logical) then ANextLog := t;
end;

end.
