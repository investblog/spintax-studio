(*
 * SpxBracketMarkup -- the pair under the caret, found by spintax rules.
 *
 * It descends from SynEdit's own bracket markup and replaces exactly one thing: WHICH two
 * positions are a pair. Everything about painting, invalidating and repainting is inherited
 * and already proven; this file must not grow any of it back.
 *
 * SynEdit's matcher is wrong for this language on two counts -- it treats parentheses and
 * quotes as brackets, which in spintax are ordinary text, and it knows nothing about
 * block comments, so it pairs an opener inside one with a closer outside. The rule that
 * replaces it lives in src/SpxTokens.pas (SpxMatchBracket) and is gated by the console
 * suite; this class is the adapter.
 *
 * The document is cached as one LF-joined string with a line-start index, rebuilt only when
 * the text changes. A caret move then costs one lookup plus one scan, and never a fresh
 * copy of the buffer.
 *
 * IT ALSO MARKS THE CONSTRUCT'S SEPARATORS, which is the one thing added to the inherited
 * behaviour -- GTW's trick, and the user's request: stepping onto a bracket should show not just
 * its partner but every place the construct divides. Those positions are painted with the SAME
 * attribute as the pair, so nothing about the colours or the invalidation grows a second policy;
 * only the set of positions is larger. Which positions they are is a structural question and
 * therefore answered in src/SpxTokens.pas (SpxSeparatorsOf), gated by the console suite, exactly
 * as the pair itself is.
 *
 * AND IT WORKS FROM EITHER END OF THAT RELATION. A caret on a SEPARATOR lights the construct
 * the separator divides -- both its brackets and its other separators -- which is the half the
 * reader reported missing: the highlight ran from a bracket and not back from a `|`. The pair
 * it hands the parent is the construct's own, so the painting, the attribute and the
 * invalidation are the same ones the bracket case has always used; only the way the pair was
 * FOUND is different, and that rule is SpxConstructOf, beside the other two and gated with them.
 *)
unit SpxBracketMarkup;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, SynEditMarkup, SynEditMiscClasses, SynEditTypes,
  LazSynEditText, SynEditMarkupBracket, SpxTokens;

type
  TSpxBracketMarkup = class(TSynEditMarkupBracket)
  private
    FDoc: string;
    FLineStart: array of Integer;   // 1-based offset of each line in FDoc
    FDocValid: Boolean;
    { The construct's separators, as editor points, for as long as the pair under the caret
      stands. Empty whenever there is no pair. }
    FSeps: array of TPoint;
    procedure RebuildDoc;
    procedure ClearSeps;
    function IsSep(ARow, ALogCol: Integer): Boolean;
    function OffsetOf(ALine, ACol: Integer): Integer;
    function PointOf(AOffset: Integer): TPoint;
  protected
    procedure FindMatchingBracketPair(LogCaret: TPoint;
      var StartBracket, EndBracket: TPoint); override;
    procedure DoTextChanged(StartLine, EndLine, ACountDiff: Integer); override;
  public
    { The inherited pair, plus the separators. `inherited` answers first, so a bracket keeps
      exactly the attribute it had. }
    function GetMarkupAttributeAtRowCol(const aRow: Integer;
      const aStartCol: TLazSynDisplayTokenBound;
      const AnRtlInfo: TLazSynDisplayRtlInfo): TSynSelectedColor; override;
    procedure GetNextMarkupColAfterRowCol(const aRow: Integer;
      const aStartCol: TLazSynDisplayTokenBound; const AnRtlInfo: TLazSynDisplayRtlInfo;
      out ANextPhys, ANextLog: Integer); override;
  end;

implementation

procedure TSpxBracketMarkup.DoTextChanged(StartLine, EndLine, ACountDiff: Integer);
begin
  FDocValid := False;
  inherited DoTextChanged(StartLine, EndLine, ACountDiff);
end;

procedure TSpxBracketMarkup.RebuildDoc;
var i, at: Integer; sb: TStringList;
begin
  SetLength(FLineStart, Lines.Count);
  sb := TStringList.Create;
  try
    sb.LineBreak := #10;      { our own offsets, independent of the buffer's line ending }
    at := 1;
    for i := 0 to Lines.Count - 1 do
    begin
      FLineStart[i] := at;
      at := at + Length(Lines[i]) + 1;
      sb.Add(Lines[i]);
    end;
    FDoc := sb.Text;
  finally
    sb.Free;
  end;
  FDocValid := True;
end;

function TSpxBracketMarkup.OffsetOf(ALine, ACol: Integer): Integer;
begin
  if (ALine < 1) or (ALine > Length(FLineStart)) then Exit(0);
  Result := FLineStart[ALine - 1] + ACol - 1;
end;

function TSpxBracketMarkup.PointOf(AOffset: Integer): TPoint;
var lo, hi, mid: Integer;
begin
  Result := Point(-1, -1);
  if (AOffset < 1) or (Length(FLineStart) = 0) then Exit;
  lo := 0;
  hi := High(FLineStart);
  while lo < hi do
  begin
    mid := (lo + hi + 1) div 2;
    if FLineStart[mid] <= AOffset then lo := mid else hi := mid - 1;
  end;
  Result := Point(AOffset - FLineStart[lo] + 1, lo + 1);
end;

procedure TSpxBracketMarkup.FindMatchingBracketPair(LogCaret: TPoint;
  var StartBracket, EndBracket: TPoint);

  { The construct's separators, as points, from the offsets whoever found them already has. }
  procedure KeepSeps(const o: TSpxOffsets);
  var i, n: Integer; p: TPoint;
  begin
    n := 0;
    SetLength(FSeps, Length(o));
    for i := 0 to High(o) do
    begin
      p := PointOf(o[i]);
      if p.Y > 0 then
      begin
        FSeps[n] := p;
        Inc(n);
      end;
    end;
    SetLength(FSeps, n);
    { AND THE LINES THAT HAVE JUST GAINED ONE ARE TOLD. ClearSeps says the rule from the other
      side -- clearing a highlight means telling the editor, not only forgetting it -- and
      setting one is the same act. The parent invalidates the two BRACKET lines and no others,
      so a separator on a middle line of a construct spanning three had nothing to repaint it
      and appeared one caret move late. Raised by review, unmeasured there; the asymmetry is
      visible in the code either way and costs one loop to close. }
    for i := 0 to n - 1 do
      InvalidateSynLines(FSeps[i].Y, FSeps[i].Y);
  end;

  { The same, for a pair given in document order: the offsets have to be found first. }
  procedure TakeSeps(AFrom, ATo: Integer);
  begin
    KeepSeps(SpxSeparatorsOf(FDoc, AFrom, ATo));
  end;

  { Try the bracket at this position; returns True when a pair was found. }
  function TryAt(const P: TPoint): Boolean;
  var here, partner: Integer;
  begin
    Result := False;
    here := OffsetOf(P.Y, P.X);
    if here = 0 then Exit;
    partner := SpxMatchBracket(FDoc, here);
    if partner = 0 then Exit;
    StartBracket := P;
    EndBracket := PointOf(partner);
    Result := EndBracket.Y > 0;
    { Recorded for the pair that was ACCEPTED, and here rather than at the end, because this is
      the only place that knows both offsets. An opener may be either of the two, so the range
      is taken in order. }
    if Result then
      if here < partner then TakeSeps(here, partner)
      else TakeSeps(partner, here);
  end;

  { And the other direction: a SEPARATOR at this position lights the construct it divides. The
    pair handed back is the construct's own brackets, so everything downstream -- the parent's
    painting, the attribute, the invalidation -- is the bracket case unchanged. }
  function TrySepAt(const P: TPoint): Boolean;
  var here, o, c: Integer; seps: TSpxOffsets;
  begin
    Result := False;
    here := OffsetOf(P.Y, P.X);
    if here = 0 then Exit;
    if not SpxConstructOf(FDoc, here, o, c, seps) then Exit;
    StartBracket := PointOf(o);
    EndBracket := PointOf(c);
    Result := (StartBracket.Y > 0) and (EndBracket.Y > 0);
    { The offsets the rule already had -- scanning for them again would double the one
      expensive half of a caret move. }
    if Result then KeepSeps(seps);
  end;

var probe: TPoint;
begin
  StartBracket.Y := -1;
  EndBracket.Y := -1;
  ClearSeps;
  if (LogCaret.Y < 1) or (LogCaret.Y > Lines.Count) or (LogCaret.X < 1) then Exit;
  if not FDocValid then RebuildDoc;

  { Left of the caret first, then under it -- the order SynEdit's own markup uses, so the
    highlight behaves the way a user's hands already expect. }
  if LogCaret.X > 1 then
  begin
    probe := Point(LogCaret.X - 1, LogCaret.Y);
    if TryAt(probe) then Exit;
  end;
  if TryAt(LogCaret) then Exit;

  (* BRACKETS FIRST, ALWAYS. Where a bracket and a separator are both in reach -- an empty
     element, whose pipe sits against a brace -- the pair is the older and stronger reading, and
     a caret that used to light a pair must keep lighting it. The separator is tried only when
     there was no pair at all.

     Written in the parenthesis-star form because this comment quotes the language: a closing
     brace inside a brace comment ends it, which cost a hard "illegal character" here. Naming
     the two forms in words rather than writing them is the other half of the same lesson --
     spelling them out raised `Comment level 2 found`, and under the gate's -Sew that is
     fatal. *)
  if LogCaret.X > 1 then
  begin
    probe := Point(LogCaret.X - 1, LogCaret.Y);
    if TrySepAt(probe) then Exit;
  end;
  if not TrySepAt(LogCaret) then
  begin
    StartBracket.Y := -1;
    EndBracket.Y := -1;
  end;
end;

procedure TSpxBracketMarkup.ClearSeps;
var i: Integer;
begin
  { Every line that HAD a separator has to be repainted, or the mark stays on screen after the
    caret has left the construct -- the same lesson the jump flash taught: clearing a highlight
    means telling the editor, not only forgetting it. }
  for i := 0 to High(FSeps) do
    if FSeps[i].Y > 0 then InvalidateSynLines(FSeps[i].Y, FSeps[i].Y);
  SetLength(FSeps, 0);
end;

function TSpxBracketMarkup.IsSep(ARow, ALogCol: Integer): Boolean;
var i: Integer;
begin
  for i := 0 to High(FSeps) do
    if (FSeps[i].Y = ARow) and (FSeps[i].X = ALogCol) then Exit(True);
  Result := False;
end;

function TSpxBracketMarkup.GetMarkupAttributeAtRowCol(const aRow: Integer;
  const aStartCol: TLazSynDisplayTokenBound;
  const AnRtlInfo: TLazSynDisplayRtlInfo): TSynSelectedColor;
begin
  Result := inherited GetMarkupAttributeAtRowCol(aRow, aStartCol, AnRtlInfo);
  if Result <> nil then Exit;
  if not IsSep(aRow, aStartCol.Logical) then Exit;
  Result := MarkupInfo;
  { One byte, like the brackets: `|` is ASCII, and a permutation's `<br>` is marked at its first
    character for the same reason the parent marks a bracket at its own -- the frame is a hint
    about WHERE, not a measurement of the token. }
  MarkupInfo.SetFrameBoundsLog(aStartCol.Logical, aStartCol.Logical + 1);
end;

procedure TSpxBracketMarkup.GetNextMarkupColAfterRowCol(const aRow: Integer;
  const aStartCol: TLazSynDisplayTokenBound; const AnRtlInfo: TLazSynDisplayRtlInfo;
  out ANextPhys, ANextLog: Integer);
var i: Integer;

  { The smallest candidate greater than where the painter is now. -1 means "nothing left on this
    row", which is what the parent uses and what SynEdit expects. }
  procedure Offer(ACol: Integer);
  begin
    if ACol <= aStartCol.Logical then Exit;
    if (ANextLog < 0) or (ACol < ANextLog) then ANextLog := ACol;
  end;

begin
  inherited GetNextMarkupColAfterRowCol(aRow, aStartCol, AnRtlInfo, ANextPhys, ANextLog);
  { The separators have to be offered too, or SynEdit walks straight past the run they mark and
    the attribute above is never asked for. }
  for i := 0 to High(FSeps) do
    if FSeps[i].Y = aRow then
    begin
      Offer(FSeps[i].X);
      Offer(FSeps[i].X + 1);
    end;
end;

end.
