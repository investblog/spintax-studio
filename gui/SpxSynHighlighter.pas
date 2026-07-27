(*
 * SpxSynHighlighter -- SynEdit's view of SpxTokens, and nothing more.
 *
 * All the scanning lives in src/SpxTokens.pas, which knows nothing about SynEdit and is
 * gated by the console suite. This file is the adapter: it hands SynEdit one token at a
 * time and picks a colour. Keep it that way -- the moment a scanning rule appears here it
 * stops being testable without a window.
 *
 * Nesting is coloured by depth cycling through four shades, so a reader can see which
 * closing brace belongs to which opening one without counting. The tokenizer caps depth at
 * 255, which only means very deep nesting reuses a shade -- no state is lost.
 *
 * SynEdit's contract, in the order it calls: SetRange with the previous line's state,
 * SetLine, then Next until GetEol, then GetRange for the line after. That is why the whole
 * line is scanned in SetLine and the state is packed into the range pointer.
 *)
unit SpxSynHighlighter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, SynEditHighlighter, SpxTokens;

type
  TSpxSynHighlighter = class(TSynCustomHighlighter)
  private
    FLineText: string;
    FTokens: TSpxTokenList;
    FIndex: Integer;
    FState: TSpxScanState;
    FTextAttr: TSynHighlighterAttributes;
    FCommentAttr: TSynHighlighterAttributes;
    FDirectiveAttr: TSynHighlighterAttributes;
    FStringAttr: TSynHighlighterAttributes;
    FVariableAttr: TSynHighlighterAttributes;
    FPipeAttr: TSynHighlighterAttributes;
    FCondAttr: TSynHighlighterAttributes;
    FPluralAttr: TSynHighlighterAttributes;
    FConfigAttr: TSynHighlighterAttributes;
    FNestAttr: array[0..3] of TSynHighlighterAttributes;
    function CurrentToken: TSpxToken;
  protected
    function GetDefaultAttribute(Index: integer): TSynHighlighterAttributes; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetLine(const NewValue: String; LineNumber: Integer); override;
    procedure Next; override;
    function GetEol: Boolean; override;
    function GetToken: String; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: integer; override;
    function GetTokenPos: Integer; override;
    function GetRange: Pointer; override;
    procedure SetRange(Value: Pointer); override;
    procedure ResetRange; override;
  end;

implementation

constructor TSpxSynHighlighter.Create(AOwner: TComponent);

  function Attr(const AName: string; AColor: TColor; AStyle: TFontStyles): TSynHighlighterAttributes;
  begin
    Result := TSynHighlighterAttributes.Create(AName, AName);
    Result.Foreground := AColor;
    Result.Style := AStyle;
    AddAttribute(Result);
  end;

begin
  inherited Create(AOwner);
  FTokens := TSpxTokenList.Create;

  FTextAttr      := Attr('Text',       clWindowText, []);
  FCommentAttr   := Attr('Comment',    clGray,       [fsItalic]);
  FDirectiveAttr := Attr('Directive',  $00993300,    [fsBold]);      { dark blue }
  FStringAttr    := Attr('String',     $00107C10,    []);            { dark green }
  FVariableAttr  := Attr('Variable',   $00A03070,    []);            { violet }
  FPipeAttr      := Attr('Separator',  $000060C0,    [fsBold]);      { amber }
  FCondAttr      := Attr('Conditional',$000080C0,    [fsBold]);
  FPluralAttr    := Attr('Plural',     $000080C0,    [fsBold]);
  FConfigAttr    := Attr('Config',     $00808000,    []);            { teal }

  { Four shades for nesting, cycling. The eye needs a difference, not a scale. }
  FNestAttr[0] := Attr('Nesting 1', $00B04000, [fsBold]);
  FNestAttr[1] := Attr('Nesting 2', $00206090, [fsBold]);
  FNestAttr[2] := Attr('Nesting 3', $00107040, [fsBold]);
  FNestAttr[3] := Attr('Nesting 4', $00A02090, [fsBold]);

  FState.InComment := False;
  FState.LineEmpty := True;
  FState.Depth := 0;

  { Every stock highlighter in SynEdit ends its constructor with this, and the base class
    does NOT do it for you: without it a changed attribute never fires DefHighlightChange,
    so the editor does not repaint, and InternalSaveDefaultValues never runs, so there are
    no defaults to reset to. Both bite the moment a settings pane appears (spec §3). }
  SetAttributesOnChange(@DefHighlightChange);
end;

destructor TSpxSynHighlighter.Destroy;
begin
  FTokens.Free;
  inherited Destroy;
end;

function TSpxSynHighlighter.CurrentToken: TSpxToken;
begin
  Result := FTokens[FIndex];
end;

procedure TSpxSynHighlighter.SetLine(const NewValue: String; LineNumber: Integer);
begin
  inherited;
  FLineText := NewValue;
  FTokens.Clear;
  FIndex := 0;
  SpxScanLine(FLineText, FState, FTokens);
end;

procedure TSpxSynHighlighter.Next;
begin
  Inc(FIndex);
end;

function TSpxSynHighlighter.GetEol: Boolean;
begin
  Result := FIndex >= FTokens.Count;
end;

function TSpxSynHighlighter.GetToken: String;
var t: TSpxToken;
begin
  if GetEol then Exit('');
  t := CurrentToken;
  Result := Copy(FLineText, t.Start, t.Length);
end;

procedure TSpxSynHighlighter.GetTokenEx(out TokenStart: PChar; out TokenLength: integer);
var t: TSpxToken;
begin
  if GetEol then
  begin
    TokenStart := nil;
    TokenLength := 0;
    Exit;
  end;
  t := CurrentToken;
  TokenStart := PChar(FLineText) + t.Start - 1;
  TokenLength := t.Length;
end;

function TSpxSynHighlighter.GetTokenAttribute: TSynHighlighterAttributes;
var t: TSpxToken;
begin
  if GetEol then Exit(FTextAttr);
  t := CurrentToken;
  case t.Kind of
    sptComment:     Result := FCommentAttr;
    sptDirective:   Result := FDirectiveAttr;
    sptString:      Result := FStringAttr;
    sptVariable:    Result := FVariableAttr;
    sptPipe:        Result := FPipeAttr;
    sptCondHead:    Result := FCondAttr;
    sptPluralHead:  Result := FPluralAttr;
    { A trailing separator is configuration for one element, so it wears the config colour:
      the user is looking at the same kind of thing in both places. }
    sptPermConfig, sptTrailingSep: Result := FConfigAttr;
    sptBraceOpen, sptBraceClose, sptBracketOpen, sptBracketClose:
      { Depth is 1-based for a bracket, so the outermost pair gets shade 0. }
      if t.Depth > 0 then Result := FNestAttr[(t.Depth - 1) mod 4]
      else Result := FNestAttr[0];
  else
    Result := FTextAttr;
  end;
end;

function TSpxSynHighlighter.GetTokenKind: integer;
begin
  if GetEol then Exit(Ord(sptText));
  Result := Ord(CurrentToken.Kind);
end;

function TSpxSynHighlighter.GetTokenPos: Integer;
begin
  if GetEol then Exit(Length(FLineText));
  Result := CurrentToken.Start - 1;   // SynEdit counts from 0
end;

function TSpxSynHighlighter.GetRange: Pointer;
begin
  Result := Pointer(SpxPackState(FState));
end;

procedure TSpxSynHighlighter.SetRange(Value: Pointer);
begin
  FState := SpxUnpackState(PtrInt(Value));
end;

procedure TSpxSynHighlighter.ResetRange;
begin
  FState.InComment := False;
  FState.LineEmpty := True;
  FState.Depth := 0;
end;

function TSpxSynHighlighter.GetDefaultAttribute(Index: integer): TSynHighlighterAttributes;
begin
  case Index of
    SYN_ATTR_COMMENT:    Result := FCommentAttr;
    SYN_ATTR_STRING:     Result := FStringAttr;
    SYN_ATTR_KEYWORD:    Result := FDirectiveAttr;
    SYN_ATTR_IDENTIFIER: Result := FVariableAttr;
  else
    Result := FTextAttr;
  end;
end;

end.
