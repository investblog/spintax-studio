(*
 * SpxGroups -- the group under the caret, and how to write it back.
 *
 * A "group" is what the author actually edits: `{a|b}`, `{?flag?yes|no}`, a plural, or a
 * permutation `[a|b|c]`. Editing one inside a long line of prose is the thing the editor this
 * syntax came from solved with a wizard, and the same job here needs two answers -- WHICH
 * group the caret is in, and what the document looks like with its variants replaced.
 *
 * IT ASKS THE SCANNER. Every structural question is put to `SpxTokens`, the scanner the
 * highlighter already runs: what is a comment, what is a conditional head, which `|` belongs
 * to this group rather than a nested one. That is not laziness -- it is the only way the group
 * a panel offers to edit is the same group the colours on screen describe. A second tokenizer
 * here would drift, and the first symptom would be an edit that rewrites the wrong span.
 *
 * BYTES, 1-based, into the whole document: the same coordinates SynEdit's logical positions
 * use, so a caret offset goes in and a replacement comes out without a conversion in between.
 *
 * WHAT IT COSTS, because the answer decides where it may be called from. Finding the group
 * means scanning from the start of the document -- a bracket's meaning depends on everything
 * above it -- and the scan stops the moment the enclosing pair closes. That early exit helps
 * only when the caret IS in a group: a caret in prose, which is most of a template, has no
 * pair to close around it and pays for the whole document.
 *
 * Measured with the caret at the very end and a group on every line: 3.5 ms over 160 KB,
 * 124 ms over 535 KB, 296 ms over 1 MB. The jump between the first two is the document
 * leaving the processor cache rather than a change in the algorithm. So this is a
 * DEBOUNCE-tick cost on ordinary templates and a stutter on very large ones; a panel that
 * wants it on every caret move will need the scan cached against the text, and there is no
 * point building that cache before a panel asks for it.
 *
 * IT DOES NOT TOKENIZE -- which is the half of "it does not parse" that is actually true. It
 * still decides which closer pairs with which opener, which pipes are this group's, and what
 * counts as a head; what it never does is decide what a `|` or a `/#` MEANS.
 *)
unit SpxGroups;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

uses
  Classes, SysUtils, Generics.Collections, SpxTokens;

type
  { Which of the four the brackets open. The kind is the head's business: a bare brace is a
    choice, `?name?` after it a conditional, `plural %n%:` a plural, a square bracket a
    permutation. }
  TSpxGroupKind = (spxGroupChoice, spxGroupConditional, spxGroupPlural, spxGroupPermutation);

  TSpxTexts = array of string;

  TSpxGroup = record
    Kind: TSpxGroupKind;
    { The opening and closing bracket themselves, 1-based byte offsets. }
    Start, Stop: Integer;
    { `?flag?`, `plural %n%:` or `<minsize=2>` verbatim, '' when the group has none. It is
      kept rather than parsed: writing the variants back must not touch it. }
    Head: string;
    { Where the variants begin -- after the head, and after any blank the scanner skipped
      before it. STORED rather than recomputed from the head's length, because a panel that
      edits a conditional's flag name would otherwise shift every write by the difference,
      silently, into the first variant. }
    BodyStart: Integer;
    { Top-level variants, in order, VERBATIM -- a nested group inside one of them is part of
      its text, newlines included. }
    Variants: TSpxTexts;
  end;

{ The innermost group whose brackets enclose Offset, or False when the caret is in none --
  in plain text, inside a comment, or inside brackets that do not pair -- a brace closed by a
  square bracket, or one never closed at all -- which is the validator's finding and not
  something to offer an edit for. }
function SpxGroupAt(const Text: string; Offset: Integer; out Group: TSpxGroup): Boolean;

(* The document with this group's variants replaced. The brackets and the head stay exactly
   as they were; everything between the head and the closing bracket is rewritten. An empty
   list writes an empty group -- `{` immediately followed by `}` -- which is legal and renders
   nothing; refusing it here would be this unit having an opinion about the author's text. *)
function SpxSetGroupVariants(const Text: string; const Group: TSpxGroup;
  const Variants: array of string): string;

implementation

type
  { Only what a still-open bracket needs to be remembered by. The whole token stream is NOT
    kept: a caret move would then pay for materialising every token in the document. }
  TOpenBracket = record
    Kind: TSpxTokenKind;
    Start: Integer;
  end;

{ Nothing but spaces and tabs. A blank run before a head is not the body starting: the
  scanner skips blanks before a permutation config on purpose, because the engine trims one,
  and treating that blank as the first variant lost the config on every write. }
function AllBlanks(const S: string): Boolean;
var i: Integer;
begin
  Result := True;
  for i := 1 to Length(S) do
    if (S[i] <> ' ') and (S[i] <> #9) then Exit(False);
end;

function Pairs(Opener, Closer: TSpxTokenKind): Boolean;
begin
  Result := ((Opener = sptBraceOpen) and (Closer = sptBraceClose)) or
            ((Opener = sptBracketOpen) and (Closer = sptBracketClose));
end;

(* The enclosing pair, found by streaming the scanner over the document and stopping the
   moment it closes. Two properties make that sound: the scanner carries its own state
   between lines, so a comment or a group that spans lines is handled by it rather than here;
   and inner pairs close first, so the first pair to close around the caret is the innermost
   one the caret is in.

   A closer of the WRONG kind pops its opener -- which is what the engine does, and why it
   then reports the next closer as unexpected -- but a pair that closes AROUND one is not
   offered. Measured: the engine renders `{x|{a]b}|y}` as literal text and reports both
   bracket.mismatched and bracket.unexpected-closing, so rewriting the variants of that span
   would be editing a construct the engine never saw as a group.

   AState and ALineFrom come back so the caller can replay the scanner over the group's real
   lines rather than over a copy of the span: a copy is truncated at the closing bracket, and
   the scanner's html-ish lookahead reads to the end of the LINE -- `[<li>a|b]</li>` is prose
   to the document scan and a permutation config to an isolated one. *)
function EnclosingPair(const Text: string; Offset: Integer;
  out AStart, AStop, ADepth, ALineFrom: Integer; out AKind: TSpxTokenKind;
  out AState: TSpxScanState): Boolean;
var
  st, stBefore: TSpxScanState;
  toks: TSpxTokenList;
  stack: array of TOpenBracket;
  stackLineFrom, stackDepth: array of Integer;
  stackState: array of TSpxScanState;
  top, i, k, n, lineStart, tokStart, mismatchAt: Integer;
  line: string;
  done: Boolean;
begin
  Result := False;
  AStart := 0;
  AStop := 0;
  ADepth := 0;
  ALineFrom := 1;
  AKind := sptText;
  AState := Default(TSpxScanState);
  st := Default(TSpxScanState);
  st.LineEmpty := True;
  SetLength(stack, 32);
  SetLength(stackLineFrom, 32);
  SetLength(stackState, 32);
  SetLength(stackDepth, 32);
  top := 0;
  done := False;
  mismatchAt := 0;
  toks := TSpxTokenList.Create;
  try
    n := Length(Text);
    lineStart := 1;
    while (lineStart <= n + 1) and not done do
    begin
      i := lineStart;
      while (i <= n) and (Text[i] <> #13) and (Text[i] <> #10) do Inc(i);
      line := Copy(Text, lineStart, i - lineStart);
      stBefore := st;
      toks.Clear;
      SpxScanLine(line, st, toks);
      for k := 0 to toks.Count - 1 do
      begin
        tokStart := lineStart + toks[k].Start - 1;
        if toks[k].Kind in [sptBraceOpen, sptBracketOpen] then
        begin
          if top = Length(stack) then
          begin
            SetLength(stack, top * 2);
            SetLength(stackLineFrom, top * 2);
            SetLength(stackState, top * 2);
            SetLength(stackDepth, top * 2);
          end;
          stack[top].Kind := toks[k].Kind;
          stack[top].Start := tokStart;
          stackLineFrom[top] := lineStart;
          stackState[top] := stBefore;
          stackDepth[top] := toks[k].Depth;
          Inc(top);
        end
        else if toks[k].Kind in [sptBraceClose, sptBracketClose] then
        begin
          if top = 0 then Continue;   { a closer with nothing open: the validator's finding }
          Dec(top);
          if not Pairs(stack[top].Kind, toks[k].Kind) then
          begin
            { Remembered so a pair closing around it can be refused rather than rewritten. }
            if mismatchAt = 0 then mismatchAt := tokStart;
            Continue;
          end;
          if (stack[top].Start <= Offset) and (Offset <= tokStart) then
          begin
            done := True;
            if (mismatchAt > stack[top].Start) and (mismatchAt < tokStart) then Break;
            AStart := stack[top].Start;
            AStop := tokStart;
            AKind := stack[top].Kind;
            ADepth := stackDepth[top];
            ALineFrom := stackLineFrom[top];
            AState := stackState[top];
            Result := True;
            Break;
          end;
        end;
      end;
      if i > n then Break;
      if (Text[i] = #13) and (i < n) and (Text[i + 1] = #10) then Inc(i);
      lineStart := i + 1;
    end;
  finally
    toks.Free;
  end;
end;

function SpxGroupAt(const Text: string; Offset: Integer; out Group: TSpxGroup): Boolean;
var
  st: TSpxScanState;
  toks: TSpxTokenList;
  line: string;
  k, nVars, cut, tokStart, i, n, lineStart, depth, lineFrom: Integer;
  openKind: TSpxTokenKind;
  seenBody: Boolean;
begin
  Group := Default(TSpxGroup);
  Result := EnclosingPair(Text, Offset, Group.Start, Group.Stop, depth, lineFrom,
                          openKind, st);
  if not Result then Exit;

  Group.Kind := spxGroupChoice;
  if openKind = sptBracketOpen then Group.Kind := spxGroupPermutation;
  Group.BodyStart := Group.Start + 1;
  cut := Group.BodyStart;
  nVars := 0;
  seenBody := False;

  { Replayed over the document's OWN lines, from the line the group opens on and with the
    state the scanner had entering it -- so every token here is the one the highlighter
    paints, which is the whole point of asking the scanner rather than parsing. }
  toks := TSpxTokenList.Create;
  try
    n := Length(Text);
    lineStart := lineFrom;
    while lineStart <= n do
    begin
      i := lineStart;
      while (i <= n) and (Text[i] <> #13) and (Text[i] <> #10) do Inc(i);
      line := Copy(Text, lineStart, i - lineStart);
      toks.Clear;
      SpxScanLine(line, st, toks);
      for k := 0 to toks.Count - 1 do
      begin
        tokStart := lineStart + toks[k].Start - 1;
        if tokStart <= Group.Start then Continue;
        if tokStart >= Group.Stop then Break;
        { A blank run before the head has not started the body yet. }
        if (not seenBody) and (toks[k].Kind = sptText) and
           AllBlanks(Copy(Text, tokStart, toks[k].Length)) then Continue;
        { The head is the first thing inside. }
        if (not seenBody) and
           (toks[k].Kind in [sptCondHead, sptPluralHead, sptPermConfig]) then
        begin
          case toks[k].Kind of
            sptCondHead: Group.Kind := spxGroupConditional;
            sptPluralHead: Group.Kind := spxGroupPlural;
          end;
          Group.Head := Copy(Text, tokStart, toks[k].Length);
          Group.BodyStart := tokStart + toks[k].Length;
          cut := Group.BodyStart;
          seenBody := True;
          Continue;
        end;
        seenBody := True;
        if (toks[k].Kind = sptPipe) and (toks[k].Depth = depth) then
        begin
          if nVars = Length(Group.Variants) then
            SetLength(Group.Variants, 8 + nVars * 2);
          Group.Variants[nVars] := Copy(Text, cut, tokStart - cut);
          Inc(nVars);
          cut := tokStart + toks[k].Length;
        end;
      end;
      if (i > n) or (i > Group.Stop) then Break;
      if (Text[i] = #13) and (i < n) and (Text[i + 1] = #10) then Inc(i);
      lineStart := i + 1;
    end;
  finally
    toks.Free;
  end;

  SetLength(Group.Variants, nVars + 1);
  Group.Variants[nVars] := Copy(Text, cut, Group.Stop - cut);
end;

function SpxSetGroupVariants(const Text: string; const Group: TSpxGroup;
  const Variants: array of string): string;
var i: Integer; body: string;
begin
  body := '';
  for i := 0 to High(Variants) do
  begin
    if i > 0 then body := body + '|';
    body := body + Variants[i];
  end;
  { BodyStart, not a length recomputed from the head: the head is a public field, and a panel
    that edits a conditional's flag name would otherwise shift every write by the difference
    in length -- silently, into the first variant. }
  Result := Copy(Text, 1, Group.BodyStart - 1) + body +
            Copy(Text, Group.Stop, Length(Text) - Group.Stop + 1);
end;

end.
