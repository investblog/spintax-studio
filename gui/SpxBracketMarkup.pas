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
 *)
unit SpxBracketMarkup;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, SynEditMarkupBracket, SpxTokens;

type
  TSpxBracketMarkup = class(TSynEditMarkupBracket)
  private
    FDoc: string;
    FLineStart: array of Integer;   // 1-based offset of each line in FDoc
    FDocValid: Boolean;
    procedure RebuildDoc;
    function OffsetOf(ALine, ACol: Integer): Integer;
    function PointOf(AOffset: Integer): TPoint;
  protected
    procedure FindMatchingBracketPair(LogCaret: TPoint;
      var StartBracket, EndBracket: TPoint); override;
    procedure DoTextChanged(StartLine, EndLine, ACountDiff: Integer); override;
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
  end;

var probe: TPoint;
begin
  StartBracket.Y := -1;
  EndBracket.Y := -1;
  if (LogCaret.Y < 1) or (LogCaret.Y > Lines.Count) or (LogCaret.X < 1) then Exit;
  if not FDocValid then RebuildDoc;

  { Left of the caret first, then under it -- the order SynEdit's own markup uses, so the
    highlight behaves the way a user's hands already expect. }
  if LogCaret.X > 1 then
  begin
    probe := Point(LogCaret.X - 1, LogCaret.Y);
    if TryAt(probe) then Exit;
  end;
  if not TryAt(LogCaret) then
  begin
    StartBracket.Y := -1;
    EndBracket.Y := -1;
  end;
end;

end.
