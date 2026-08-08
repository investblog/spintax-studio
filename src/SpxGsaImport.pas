(*
 * SpxGsaImport -- an existing GSA SER template, turned into a document this editor can hold.
 *
 * The CONVERSION is the engine's (`Spintax.Gsa`, shipped from `v0.4.0` beside the engine but
 * deliberately outside `unit Spintax`). This unit is the part that belongs to the host: it
 * turns what the converter hands back into the two things a Studio document is made of -- the
 * template text, and the session variables that go with it.
 *
 * WHY THE VALUES CANNOT LIVE IN THE DOCUMENT, which is the first thing anybody tries. The
 * converter lifts out every construct it cannot fix in place -- BBCode brackets, a `#` inside
 * a URL, `#file[...]`, and any block it refused -- and returns each as a variable whose value
 * is NEUTRALISED, that is, written with the engine's private-use sentinels. Neither form can
 * be written back into the template:
 *
 *   - the neutralised form cannot, because `SpRender` strips sentinels from a template before
 *     parsing (and Studio's own health report lints them);
 *   - the plain form cannot either, because a `#set` value is TEMPLATE text, not a literal.
 *     Measured: `#set %x% = [b]` then `%x%this` renders `bthis`, and
 *     `#set %m% = #file[l.txt,1,S]` renders `#filel.txt,1, S` -- the brackets eaten, which is
 *     the exact corruption the converter exists to prevent.
 *
 * So they go where the engine's own contract says they must: through the host, in
 * `TSpContext.Vars`. Studio already has that path -- session variables, with `Literal` for a
 * value that means itself -- and `SpxValueForEngine` neutralises on the way past. The values
 * here are therefore RESTORED to their readable form (`[`, `/#`, `#file[l.txt,1,S]`) and
 * marked literal, so the panel shows a human what was lifted and the engine receives what the
 * converter meant. The round trip is exact: measured over every value the converter produces,
 * `SpNeutralize(SpSafetyRestore(v)) = v`.
 *
 * WHAT THIS COSTS THE READER, and the import dialog has to say it: session variables are not
 * saved. The document renders fully while it is open; saved and re-opened tomorrow it shows
 * `%__gsa_…%` where the lifted text was -- visibly incomplete rather than quietly wrong, which
 * is how the engine designed it, but incomplete all the same.
 *)
unit SpxGsaImport;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Spintax, Spintax.Gsa, SpxStudio;

type
  { One block the converter REFUSED, kept apart from the ones it merely lifted. The engine
    reports these so a host can resolve them itself rather than have a guess made on its
    behalf: a domain-bound block, a partially tagged one, a repeated tag. The original text
    survives as the variable's value, so nothing is lost and nothing is reinterpreted. }
  TSpxGsaRefusal = record
    Name: string;       { the variable it became, without the % %  }
    Original: string;   { the GSA text, exactly as it was written  }
  end;
  TSpxGsaRefusals = array of TSpxGsaRefusal;

  { What an import produced. `Vars` is every construct the converter lifted -- refusals
    included, because those are lifted too -- ready to be handed to the panel as session
    values. `Refused` is the subset that needs the reader's attention. }
  TSpxGsaResult = record
    Doc: string;
    Vars: TSpxVarPairs;
    Refused: TSpxGsaRefusals;
    (* ▁▁▁ ALWAYS FALSE, AND IT IS HERE SO A CALLER CANNOT MISS IT ▁▁▁

       A converted GSA template renders with the cosmetic stage OFF. Every other document in
       this editor renders with it ON -- that is the WYSIWYG rule the right pane is built on --
       and this one is the exception, because the text is not ours: it is somebody else's
       template, usually on its way back to GSA, and the post-processor edits it.

       Measured on engine `v0.4.0`, with the lifted value handed through `Vars` the way the
       converter's contract demands: `#file[l.txt,1,S]` comes back `#file[l.txt,1, S]`, and
       `a,b` comes back `A, b` -- a space and a capital, in a macro that has to survive
       character for character. Neutralising defends a value against the parser and not against
       the typographer.

       The engine may well fix that (it is reported), and this field stays either way: prose
       conventions do not belong on a foreign template even when they are applied correctly.
       The window copies this into `TSpxContext.PostProcess` for the imported document. *)
    PostProcess: Boolean;
  end;

{ Convert, and return the document with the variables it needs.

  The engine does the translating; this owns the shape of the answer. Named `SpxImportGsa`
  rather than after its unit: a function that shares its unit's name cannot be called from a
  program that uses that unit -- the compiler reads the identifier as the unit reference and
  stops at the opening bracket. Measured, in this suite. Vars come back sorted by
  name so two imports of one template give the same panel, and so a test can say what it
  expects without knowing a dictionary's order. }
function SpxImportGsa(const ASource: string): TSpxGsaResult;

implementation

{ Insertion sort by name: the lists here are a handful of entries, and the only property that
  matters is that the order is the SAME every time. }
procedure SortPairs(var APairs: TSpxVarPairs);
var i, j: Integer; tmp: TSpxVarPair;
begin
  for i := 1 to High(APairs) do
  begin
    tmp := APairs[i];
    j := i - 1;
    while (j >= 0) and (CompareStr(APairs[j].Name, tmp.Name) > 0) do
    begin
      APairs[j + 1] := APairs[j];
      Dec(j);
    end;
    APairs[j + 1] := tmp;
  end;
end;

(* ▁▁▁ A TAG BLOCK WITH ONE OPTION, WHICH THE CONVERTER LETS THROUGH ▁▁▁

   `SpGsaToSpintax` returns `bkPlain` for any block with fewer than two options
   (`Spintax.Gsa.pas:626`) -- BEFORE the tag-shape test at `:631-640` that exists to catch
   exactly this. So `{#.de Hallo}` is neither converted nor refused: it renders `#.de Hallo`,
   with `Refused = 0` and nothing said to the reader. That is the coin flip the converter's own
   header forbids in as many words -- text it does not understand is not "left alone" -- and
   `{x|{#.de Hallo}}` shows it plainly: the tag comes out at random.

   Reported upstream; the pin cannot move for it today, and Studio calls this converter
   DIRECTLY, so Studio defends itself. It reads the RESULT back and refuses the shape, the way
   the group editor reads its own edits back rather than trusting a release note -- the lesson
   v0.4.0's defective converter already cost this project.

   The mirror is deliberately narrow: a brace group with no top-level separator whose content
   is tag-shaped by the engine's own rule (`TagOf`, `:226-246`). Anything wider would start
   refusing ordinary spin.

   DELETE THIS when the engine's converter tests the shape before the count. *)

{ The engine's `IsBlank`. }
function GsaBlank(c: Char): Boolean;
begin
  Result := (c = ' ') or (c = #9) or (c = #13) or (c = #10);
end;

{ `TagOf` reduced to the question this asks -- is the option claiming to be a tag AND readable
  as one -- with the same tests in the same order, including its two refusals. }
function TagShaped(const AOpt: string): Boolean;
var i, n, tagStart: Integer;
begin
  Result := False;
  n := Length(AOpt);
  i := 1;
  while (i <= n) and GsaBlank(AOpt[i]) do Inc(i);
  if (i > n) or (AOpt[i] <> '#') then Exit;
  Inc(i);
  tagStart := i;
  while (i <= n) and not GsaBlank(AOpt[i]) do
  begin
    if (AOpt[i] = #13) or (AOpt[i] = #10) then Exit;   { a tag carrying a line break }
    Inc(i);
  end;
  if i = tagStart then Exit;    { a bare `#` }
  if i > n then Exit;           { a tag with no text after it }
  Result := True;
end;

{ True when the content holds no separator at its own level, so the engine saw ONE option and
  took the early exit. Both bracket kinds counted, as SplitTop counts them. }
function SingleOption(const AContent: string): Boolean;
var i, brace, brack: Integer;
begin
  brace := 0;
  brack := 0;
  for i := 1 to Length(AContent) do
    case AContent[i] of
      '{': Inc(brace);
      '}': Dec(brace);
      '[': Inc(brack);
      ']': Dec(brack);
      '|': if (brace = 0) and (brack = 0) then Exit(False);
    end;
  Result := True;
end;

{ A prefix that occurs nowhere in the document, so every name built on it is free. }
function FreePrefix(const ADoc: string): string;
var n: Integer;
begin
  Result := '__spx_u';
  n := 0;
  while Pos(Result, ADoc) > 0 do
  begin
    Inc(n);
    Result := '__spx' + IntToStr(n) + '_u';
  end;
end;

{ Lifts every single-option tag block out of ADoc, appending one entry to AVars and one to
  ARefused for each, and returns the rewritten document. }
function GuardTagBlocks(const ADoc: string; var AVars: TSpxVarPairs;
  var ARefused: TSpxGsaRefusals): string;
var
  i, j, depth, at, n, taken: Integer;
  content, prefix, name_, whole: string;
begin
  Result := '';
  prefix := FreePrefix(ADoc);
  taken := 0;
  n := Length(ADoc);
  i := 1;
  while i <= n do
  begin
    if ADoc[i] <> '{' then
    begin
      Result := Result + ADoc[i];
      Inc(i);
      Continue;
    end;
    (* the matching closer, counting braces only -- which is how the engine finds it *)
    depth := 0;
    j := i;
    while j <= n do
    begin
      if ADoc[j] = '{' then Inc(depth)
      else if ADoc[j] = '}' then
      begin
        Dec(depth);
        if depth = 0 then Break;
      end;
      Inc(j);
    end;
    if (j > n) or (depth <> 0) then
    begin
      { unbalanced: the rest goes through exactly as it is }
      Result := Result + Copy(ADoc, i, n - i + 1);
      Break;
    end;

    content := Copy(ADoc, i + 1, j - i - 1);
    if SingleOption(content) and TagShaped(content) then
    begin
      Inc(taken);
      name_ := prefix + IntToStr(taken);
      whole := Copy(ADoc, i, j - i + 1);
      at := Length(AVars);
      SetLength(AVars, at + 1);
      AVars[at].Name := name_;
      AVars[at].Value := whole;
      AVars[at].Literal := True;
      at := Length(ARefused);
      SetLength(ARefused, at + 1);
      ARefused[at].Name := name_;
      ARefused[at].Original := whole;
      Result := Result + '%' + name_ + '%';
      i := j + 1;
    end
    else
    begin
      (* Not this shape -- keep the brace and carry on INSIDE it, so a nested one is still
         found: a tag block wrapped in an ordinary choice is the case that made this matter. *)
      Result := Result + ADoc[i];
      Inc(i);
    end;
  end;
end;

function SpxImportGsa(const ASource: string): TSpxGsaResult;
var
  macros: TStrMap;
  refused: TStringList;
  key, name_: string;
  i, n: Integer;
begin
  Result.Doc := '';
  SetLength(Result.Vars, 0);
  SetLength(Result.Refused, 0);
  { Set BEFORE the early exit, so even an empty import answers the question it is asked. }
  Result.PostProcess := False;
  if ASource = '' then Exit;

  macros := TStrMap.Create;
  refused := TStringList.Create;
  try
    { Both must be non-nil -- the engine says so in as many words, and hands back placeholders
      rather than plausible text when a host ignores them. }
    Result.Doc := SpGsaToSpintax(ASource, macros, refused);

    n := 0;
    SetLength(Result.Vars, macros.Count);
    for key in macros.Keys do
    begin
      Result.Vars[n].Name := key;
      { RESTORED, not raw. What the panel shows a reader has to be the text that was lifted --
        `[`, `/#`, `#file[l.txt,1,S]` -- and not the private-use characters standing in for it.
        SpxValueForEngine puts the sentinels back on the way to the engine. }
      Result.Vars[n].Value := SpSafetyRestore(macros[key]);
      Result.Vars[n].Literal := True;
      Inc(n);
    end;
    SortPairs(Result.Vars);

    { `name=original text`, and the name is what the block became. Split on the FIRST `=`
      only: a refused block is arbitrary text and may carry more of them. }
    SetLength(Result.Refused, refused.Count);
    for i := 0 to refused.Count - 1 do
    begin
      name_ := refused.Names[i];
      if name_ = '' then
      begin
        { No `=` at all: keep the line rather than drop it, so a shape this unit did not expect
          still reaches the reader. }
        Result.Refused[i].Name := '';
        Result.Refused[i].Original := refused[i];
      end
      else
      begin
        Result.Refused[i].Name := name_;
        Result.Refused[i].Original := refused.ValueFromIndex[i];
      end;
    end;

    (* OURS LAST, and after the loop above rather than before it: the loop does
       `SetLength(Result.Refused, refused.Count)`, which THROWS AWAY anything already there.
       The first version of this call sat above it and its refusals vanished silently -- the
       document was rewritten correctly and the reader was told nothing, which is the very
       defect being fixed. Caught by measuring the result, not by reading the diff. *)
    Result.Doc := GuardTagBlocks(Result.Doc, Result.Vars, Result.Refused);
    SortPairs(Result.Vars);
  finally
    refused.Free;
    macros.Free;
  end;
end;

end.
