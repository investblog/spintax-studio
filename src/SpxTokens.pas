(*
 * SpxTokens -- the spintax tokenizer the editor colours by.
 *
 * Pure and GUI-free on purpose. SynEdit's highlighter is a thin adapter over this
 * (gui/SpxSynHighlighter.pas), which keeps the scanning testable in the console suite and
 * keeps the toolkit choice contained -- the same split editor-core already makes.
 *
 * WHAT THIS IS NOT. It is a presentation scan, not a second validator: it never decides
 * whether a template is valid, never reports a diagnostic, and a `}` that closes nothing is
 * simply drawn as a brace. Verdicts come from `SpValidate`, positions from `TSpDiag`, and
 * this file must never grow an opinion about either (spec §4.1).
 *
 * Token classes follow the family's own grammar -- the same ones `vscode-spintax` and
 * `sublime-spintax` colour -- so a template looks like itself in every editor.
 *
 * STATE BETWEEN LINES is a comment flag and a nesting depth, and that is the whole reason
 * unbounded nesting is not a problem here: depth is an integer, not a stack, so a template
 * nested three hundred deep costs one more increment rather than one more frame. Whether a
 * `}` matches the `{` that opened its level is a question this scan deliberately does not
 * ask -- the validator does.
 *
 * Bytes, not code points: every structural character is ASCII, and a UTF-8 continuation
 * byte can never be mistaken for one. That is what lets this scan step a byte at a time
 * over Cyrillic without a decoder.
 *)
unit SpxTokens;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  Classes, SysUtils, Generics.Collections;

type
  TSpxTokenKind = (
    sptText,          // anything with no meaning of its own
    sptComment,       // /# ... #/, markers included
    sptDirective,     // the #set / #def / #include keyword itself
    sptString,        // "target" of an #include
    sptVariable,      // %name%
    sptBraceOpen,     // { -- enumeration, conditional or plural
    sptBraceClose,    // }
    sptBracketOpen,   // [ -- permutation
    sptBracketClose,  // ]
    sptPipe,          // | between options
    sptCondHead,      // ?name? or ?!name? right after {
    sptPluralHead,    // plural %n%: -- keyword, count and colon
    sptPermConfig     // <minsize=2;sep=", "> right after [
  );

  { Everything the next line needs to know. Packed into an integer for SynEdit's range
    pointer, which is why depth is capped rather than unbounded -- 255 levels of nesting is
    already past anything a human writes, and the cap only affects the SHADE a brace gets. }
  TSpxScanState = record
    InComment: Boolean;
    { Nothing but comment (and whitespace) has appeared on the current LOGICAL line. The
      engine strips comments before it splits lines, so `/# n #/ #set %x% = 1` really is a
      directive to it and `before /# n #/ #set %x% = 1` really is not -- and a comment that
      opened on an earlier line keeps the logical line open, newline and all. Without this
      bit a highlighter confirms a macro definition the engine never made. }
    LineEmpty: Boolean;
    Depth: Integer;
  end;

  { Offsets are 1-based BYTE positions within the line, which is what both FPC strings and
    SynEdit use. Depth is the nesting level this token belongs to: an opener carries the
    level it creates, a closer the level it closes, everything else the level it sits in. }
  TSpxToken = record
    Kind: TSpxTokenKind;
    Start: Integer;
    Length: Integer;
    Depth: Integer;
  end;
  TSpxTokenList = TList<TSpxToken>;

const
  { The cap and the mask are separate on purpose: raising one used to silently corrupt the
    other, because a depth of 300 sets the bit the comment flag lives in. }
  SPX_MAX_DEPTH = 255;
  SPX_DEPTH_MASK = $FFFF;

{ Scan ONE line (without its terminator). State goes in as the previous line left it and
  comes out ready for the next. Tokens are appended, never cleared, so a caller can scan a
  document into one list. }
procedure SpxScanLine(const Line: string; var State: TSpxScanState; Tokens: TSpxTokenList);

{ For SynEdit's Range pointer, which is where a highlighter's between-line state must live. }
function SpxPackState(const State: TSpxScanState): PtrInt;
function SpxUnpackState(Value: PtrInt): TSpxScanState;

implementation

function SpxPackState(const State: TSpxScanState): PtrInt;
begin
  Result := State.Depth and SPX_DEPTH_MASK;
  if State.InComment then Result := Result or (1 shl 16);
  if State.LineEmpty then Result := Result or (1 shl 17);
end;

function SpxUnpackState(Value: PtrInt): TSpxScanState;
begin
  Result.Depth := Value and SPX_DEPTH_MASK;
  Result.InComment := (Value and (1 shl 16)) <> 0;
  Result.LineEmpty := (Value and (1 shl 17)) <> 0;
end;

function IsWordByte(c: Char): Boolean;
begin
  Result := (c in ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

procedure Emit(Tokens: TSpxTokenList; Kind: TSpxTokenKind; Start, Len, Depth: Integer);
var t: TSpxToken;
begin
  if Len <= 0 then Exit;
  t.Kind := Kind;
  t.Start := Start;
  t.Length := Len;
  t.Depth := Depth;
  Tokens.Add(t);
end;

{ `%name%` at p, or 0. The engine's variable names are ASCII word characters, so this agrees
  with it without borrowing its scanner. }
function VariableLength(const Line: string; p: Integer): Integer;
var i, n: Integer;
begin
  Result := 0;
  n := Length(Line);
  if (p > n) or (Line[p] <> '%') then Exit;
  i := p + 1;
  while (i <= n) and IsWordByte(Line[i]) do Inc(i);
  if (i > p + 1) and (i <= n) and (Line[i] = '%') then Result := i - p + 1;
end;

{ `?name?` or `?!name?` directly after a `{`. }
function CondHeadLength(const Line: string; p: Integer): Integer;
var i, n: Integer;
begin
  Result := 0;
  n := Length(Line);
  if (p > n) or (Line[p] <> '?') then Exit;
  i := p + 1;
  if (i <= n) and (Line[i] = '!') then Inc(i);
  { The first byte must be a letter or underscore, and there must be one: a digit-leading
    name, or no name at all, is NOT a conditional to the engine -- it falls through to a
    plain enumeration whose first option happens to start with a question mark. Colouring
    it as a conditional would show a branch that does not exist. }
  if (i > n) or not (Line[i] in ['A'..'Z', 'a'..'z', '_']) then Exit;
  Inc(i);
  while (i <= n) and IsWordByte(Line[i]) do Inc(i);
  if (i <= n) and (Line[i] = '?') then Result := i - p + 1;
end;

{ `plural <count>:` directly after a `{`, where the count is a macro or a number. The colon
  is part of the head; the forms after it are ordinary content. }
function PluralHeadLength(const Line: string; p: Integer): Integer;
var i, n: Integer;
begin
  Result := 0;
  n := Length(Line);
  if Copy(Line, p, 7) <> 'plural ' then Exit;
  i := p + 7;
  while (i <= n) and (Line[i] <> ':') and (Line[i] <> '|') and (Line[i] <> '}') do Inc(i);
  if (i <= n) and (Line[i] = ':') then Result := i - p + 1;
end;

{ `<...>` directly after a `[`: the permutation's config. Anything else after `[` is just
  content, including an HTML tag, which is why this stops at the first `>` and does not care
  what is inside. }
function PermConfigLength(const Line: string; p: Integer): Integer;
var i, n: Integer;
begin
  Result := 0;
  n := Length(Line);
  if (p > n) or (Line[p] <> '<') then Exit;
  i := p + 1;
  while (i <= n) and (Line[i] <> '>') and (Line[i] <> '<') do Inc(i);
  if (i <= n) and (Line[i] = '>') then Result := i - p + 1;
end;

{ The `#set` / `#def` / `#include` head, if this line starts with one. Returns the length of
  the keyword and leaves the rest of the line to the ordinary scan -- a directive VALUE is
  spintax like any other text, and colouring it as one is the point. }
function DirectiveKeywordLength(const Line: string; p: Integer): Integer;
var i, n: Integer;
begin
  Result := 0;
  n := Length(Line);
  if (Copy(Line, p, 9) = '#include ') or (Copy(Line, p, 9) = '#include'#9) then
    Exit(8);   { the target's own shape is gated by the quote rule below }

  if (Copy(Line, p, 5) = '#set ') or (Copy(Line, p, 5) = '#set'#9) or
     (Copy(Line, p, 5) = '#def ') or (Copy(Line, p, 5) = '#def'#9) then
  begin
    { A keyword alone is not a directive. `#set brand = Acme` -- the `%` forgotten -- is
      literal text to the engine, and the likeliest of all directive typos: colouring it
      bold blue would tell the user it worked. Require %name% and the `=` before saying so. }
    i := p + 4;
    while (i <= n) and ((Line[i] = ' ') or (Line[i] = #9)) do Inc(i);
    if VariableLength(Line, i) = 0 then Exit;
    Inc(i, VariableLength(Line, i));
    while (i <= n) and ((Line[i] = ' ') or (Line[i] = #9)) do Inc(i);
    if (i <= n) and (Line[i] = '=') then Result := 4;
  end;
end;

procedure SpxScanLine(const Line: string; var State: TSpxScanState; Tokens: TSpxTokenList);
var
  p, n, runStart, len, q: Integer;

  procedure FlushText(upTo: Integer);
  var i: Integer;
  begin
    if upTo > runStart then
    begin
      Emit(Tokens, sptText, runStart, upTo - runStart, State.Depth);
      { Whitespace does not open a logical line; anything else does. }
      for i := runStart to upTo - 1 do
        if (Line[i] <> ' ') and (Line[i] <> #9) then
        begin
          State.LineEmpty := False;
          Break;
        end;
    end;
    runStart := upTo;
  end;

  { Emitting anything that is not a comment means the logical line has content, so a later
    `#set` on the same line is not a directive. }
  procedure Mark(Kind: TSpxTokenKind; Start, Len: Integer);
  begin
    Emit(Tokens, Kind, Start, Len, State.Depth);
    if Kind <> sptComment then State.LineEmpty := False;
  end;

  procedure Push;
  begin
    if State.Depth < SPX_MAX_DEPTH then Inc(State.Depth);
  end;

  procedure Pop;
  begin
    if State.Depth > 0 then Dec(State.Depth);
  end;

begin
  n := Length(Line);
  p := 1;
  runStart := 1;

  { A source line that does not continue a comment starts a new LOGICAL line; one that does
    continues the old one, because the newline inside a comment is removed with it. }
  if not State.InComment then State.LineEmpty := True;

  { A comment carried over from an earlier line: everything up to `#/` belongs to it. }
  if State.InComment then
  begin
    while (p <= n) and not ((Line[p] = '#') and (p < n) and (Line[p + 1] = '/')) do Inc(p);
    if p <= n then
    begin
      Mark(sptComment, 1, p + 1);   // through the closing #/
      State.InComment := False;
      p := p + 2;
      runStart := p;
    end
    else
    begin
      Mark(sptComment, 1, n);
      Exit;
    end;
  end;

  { A directive is line-anchored -- against the logical line, which is what survives comment
    removal, so this may sit after a comment that closed mid-line and still be one. }
  while (p <= n) and ((Line[p] = ' ') or (Line[p] = #9)) do Inc(p);
  if State.LineEmpty and (p <= n) and (Line[p] = '#') then
  begin
    len := DirectiveKeywordLength(Line, p);
    if len > 0 then
    begin
      FlushText(p);
      Mark(sptDirective, p, len);
      p := p + len;
      runStart := p;
    end;
  end;
  p := runStart;

  while p <= n do
  begin
    case Line[p] of
      '/':
        if (p < n) and (Line[p + 1] = '#') then
        begin
          FlushText(p);
          { Runs to `#/` or to the end of the line, and then the next line continues it. }
          len := p + 2;
          while (len <= n) and not ((Line[len] = '#') and (len < n) and (Line[len + 1] = '/')) do
            Inc(len);
          if len <= n then
          begin
            Mark(sptComment, p, len + 2 - p);
            p := len + 2;
          end
          else
          begin
            Mark(sptComment, p, n - p + 1);
            State.InComment := True;
            p := n + 1;
          end;
          runStart := p;
          Continue;
        end;
      '%':
        begin
          len := VariableLength(Line, p);
          if len > 0 then
          begin
            FlushText(p);
            Mark(sptVariable, p, len);
            p := p + len;
            runStart := p;
            Continue;
          end;
        end;
      '"':
        begin
          { Only inside an #include head, where the target is the string. Elsewhere a quote
            is ordinary text and falls through. }
          if (Tokens.Count > 0) and (Tokens[Tokens.Count - 1].Kind = sptDirective) then
          begin
            len := p + 1;
            while (len <= n) and (Line[len] <> '"') do Inc(len);
            if len <= n then
            begin
              FlushText(p);
              Mark(sptString, p, len - p + 1);
              p := len + 1;
              runStart := p;
              Continue;
            end;
          end;
        end;
      '{':
        begin
          FlushText(p);
          Push;
          Mark(sptBraceOpen, p, 1);
          Inc(p);
          runStart := p;
          len := CondHeadLength(Line, p);
          if len > 0 then
          begin
            Mark(sptCondHead, p, len);
            p := p + len;
            runStart := p;
          end
          else
          begin
            len := PluralHeadLength(Line, p);
            if len > 0 then
            begin
              Mark(sptPluralHead, p, len);
              p := p + len;
              runStart := p;
            end;
          end;
          Continue;
        end;
      '}':
        begin
          FlushText(p);
          Mark(sptBraceClose, p, 1);
          Pop;
          Inc(p);
          runStart := p;
          Continue;
        end;
      '[':
        begin
          FlushText(p);
          Push;
          Mark(sptBracketOpen, p, 1);
          Inc(p);
          runStart := p;
          { `[ <minsize=2>a|b]` -- the engine left-trims before parsing the config, so the
            space does not disable it, and neither may the colouring. }
          q := p;
          while (q <= n) and ((Line[q] = ' ') or (Line[q] = #9)) do Inc(q);
          len := PermConfigLength(Line, q);
          if len > 0 then
          begin
            FlushText(q);
            Mark(sptPermConfig, q, len);
            p := q + len;
            runStart := p;
          end;
          Continue;
        end;
      ']':
        begin
          FlushText(p);
          Mark(sptBracketClose, p, 1);
          Pop;
          Inc(p);
          runStart := p;
          Continue;
        end;
      '|':
        begin
          FlushText(p);
          Mark(sptPipe, p, 1);
          Inc(p);
          runStart := p;
          Continue;
        end;
    end;
    Inc(p);
  end;

  FlushText(n + 1);
end;

end.
