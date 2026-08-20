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

(* ▁▁▁ AND WHETHER THE ANSWER STILL BELONGS TO THE DOCUMENT THAT ASKED FOR IT ▁▁▁

   The conversion runs on the engine worker (2026-08-19) and its result REPLACES the buffer,
   the path, the session values and the caption. `AskSave` ran before the request went out
   and does not run again when it lands, so anything the reader did in between is destroyed
   rather than the document they meant to replace. Setting the editor read-only does not stop
   it: that stops a PERSON typing, and File > New, File > Open, an applied AI answer and the
   Insert commands all assign programmatically. Found by Codex review, 2026-08-20.

   The rule lives HERE, in a unit with no GUI in it, rather than inline in the form -- the
   form is not compiled into the suite, so a comparison written there is a rule nothing can
   check.

   A REVISION FIRST, because comparing content answers the wrong question. The first version
   compared only the path and the text, and Codex found what that cannot see: the session
   values are in neither. They stay editable while the editor is read-only, the result
   REPLACES them, and a reader who retyped one during the conversion lost it with the guard
   passing. Edit-then-undo and File > New over an empty untitled document slipped through for
   the same reason -- the state is equal, and the question is whether anything MOVED. The form
   bumps its revision from `LoopSnapshotMoved`, which every route that touches the document or
   its session state already calls.

   It OVER-refuses, deliberately: `SettingChanged` and `AiProfileChanged` bump the same
   revision and change nothing the result would overwrite, so changing the theme mid-import
   drops it. That is the safe direction -- the reader can ask for the file again and cannot
   ask for the work back -- and the status line says so.

   Path and text stay as a BELT, not as the rule. They catch the one thing a revision cannot:
   a future path that assigns the buffer wholesale and forgets to move the snapshot, which is
   a real shape here, because `Text :=` does not reach the editor's change handler (measured,
   twice) and every such path calls LoopSnapshotMoved by hand.

   WHAT THIS CANNOT SEE, and it is the larger half: that the form actually calls it before
   applying, that no OTHER route into the window skips it, and that the revision is bumped
   everywhere it should be. Only the window can answer those, and the window is not under
   test. *)
function SpxImportStillApplies(AWasRev, ANowRev: Int64;
  const AWasPath, ANowPath, AWasDoc, ANowDoc: string): Boolean;

{ The order the variables panel receives after an import: the trailing run of digits in a
  name compares as a NUMBER and the stem as text, so `<prefix><kind>1 .. <kind>12` come back
  in the order the engine lifted them and not as m1, m10, m11, m12, m2.

  PUBLIC so the rule can be checked, which is the whole reason the old one was wrong: it was
  reachable only through an import, the shapes that expose it -- no digits, digits in the
  middle, a run too long for Int64 -- are ones no GSA template produces, and nothing pinned
  the order at all. See the note on the implementation for what it cost and why it is a merge
  sort rather than the index sort SpxPanelRows uses. }
procedure SpxSortVarPairs(var APairs: TSpxVarPairs);

implementation

(* NATURAL ORDER, AND IT IS N LOG N ------------------------------------------

   TWO DEFECTS LIVED HERE, and the smaller one was the visible one.

   THE ORDER. This compared names with CompareStr, and the lifter's names carry a NUMBER:
   `__gsa_m1`, `__gsa_m2`, ... So twelve lifted file spins reached the panel as m1, m10,
   m11, m12, m2, ... m9 -- a reader importing a SER template with a list per line met their
   tenth list between the first and the second. Nothing pinned that order, which is how it
   survived: it was not a decision, it was CompareStr.

   The engine already hands over what is needed. Names are `<prefix><kind><N>` with a
   per-kind counter (`Spintax.Gsa.pas/TLifter`), so lift order -- which for these is document
   order -- is recoverable from the name itself. No engine change is wanted; the trailing run
   of digits is compared as a NUMBER and the stem as text, which groups the kinds and orders
   each kind the way it was lifted. A name with no trailing digits compares as its whole
   self, so this is total over any name and not only over the ones the lifter makes.

   THE COST. It was an insertion sort over a MANAGED RECORD, and its input is a TDictionary
   key enumeration -- hash order, which is the worst case rather than an unlucky one. Roughly
   n^2/4 record moves, each of them four reference-count pairs.

   That was invisible until 2026-08-20, and honestly so: the import was measured on 08-19
   and everything Studio adds on top WAS inside run-to-run noise, because the engine cost
   5 229 ms at four thousand macros. Engine v0.8.1 made the lifter linear, the engine's share
   fell to 31 ms, and what had been noise became all of it. Measured through SpxImportGsa and
   SpGsaToSpintax in one process and one build, unoptimised, minimum of three runs:

        n     engine   SpxImportGsa   Studio's own half
    1 000         15             15                   0
    2 000         15             62                  47
    4 000         31            203                 172
    8 000         62            765                 703
   16 000        156          3 422               3 266

   A share measured against a dominant cost says nothing about what happens when the dominant
   cost goes away.

   SO THIS IS A MERGE SORT, not the index-sort SpxPanelRows got. That one buys a constant and
   says so, which is right where the input is dozens of rows; here the input is thousands, and
   a constant on a quadratic is still a quadratic. Bottom-up, stable, over an index array; the
   records are permuted once at the end along the permutation's cycles, so a block that is
   already in order costs no record moves at all. *)

type
  TNatKey = record
    Stem: string;      { the name with its trailing digits removed }
    Num: Int64;        { those digits as a number, -1 when there are none }
  end;

function NatKeyOf(const AName: string): TNatKey;
var i, first_: Integer;
begin
  first_ := Length(AName) + 1;
  i := Length(AName);
  while (i >= 1) and (AName[i] >= '0') and (AName[i] <= '9') do
  begin
    first_ := i;
    Dec(i);
  end;
  Result.Stem := Copy(AName, 1, first_ - 1);
  if first_ > Length(AName) then Result.Num := -1
  else
    { A run long enough to overflow is not a lifter name; compare it as text instead of
      wrapping into a small number and ordering it wrongly. }
    if not TryStrToInt64(Copy(AName, first_, Length(AName) - first_ + 1), Result.Num) then
    begin
      Result.Stem := AName;
      Result.Num := -1;
    end;
end;

function NatLess(const A, B: TNatKey): Boolean;
var c: Integer;
begin
  c := CompareStr(A.Stem, B.Stem);
  if c <> 0 then Exit(c < 0);
  Result := A.Num < B.Num;
end;

procedure SpxSortVarPairs(var APairs: TSpxVarPairs);
var
  keys: array of TNatKey;
  from_, work: array of Integer;
  n, width, lo, mid, hi, i, j, k: Integer;
  tmp: TSpxVarPair;
begin
  n := Length(APairs);
  if n < 2 then Exit;

  SetLength(keys, n);
  SetLength(from_, n);
  SetLength(work, n);
  for i := 0 to n - 1 do
  begin
    keys[i] := NatKeyOf(APairs[i].Name);
    from_[i] := i;
  end;

  { Bottom-up merge over the INDICES: an Integer moves, not a record with four strings. }
  width := 1;
  while width < n do
  begin
    lo := 0;
    while lo < n do
    begin
      mid := lo + width;
      if mid > n then mid := n;
      hi := lo + 2 * width;
      if hi > n then hi := n;
      i := lo; j := mid; k := lo;
      while (i < mid) and (j < hi) do
      begin
        { `not NatLess(left, right)` would drop stability; ask whether the RIGHT one is
          strictly smaller, and take the left when it is not. }
        if NatLess(keys[from_[j]], keys[from_[i]]) then
        begin work[k] := from_[j]; Inc(j); end
        else
        begin work[k] := from_[i]; Inc(i); end;
        Inc(k);
      end;
      while i < mid do begin work[k] := from_[i]; Inc(i); Inc(k); end;
      while j < hi do begin work[k] := from_[j]; Inc(j); Inc(k); end;
      lo := hi;
    end;
    for i := 0 to n - 1 do from_[i] := work[i];
    width := width * 2;
  end;

  { Permute in place along the permutation's cycles, -1 marking a slot already placed. An
    array that arrived in order costs zero record moves here. }
  for i := 0 to n - 1 do
  begin
    if (from_[i] < 0) or (from_[i] = i) then Continue;
    tmp := APairs[i];
    j := i;
    while from_[j] <> i do
    begin
      k := from_[j];
      from_[j] := -1;
      APairs[j] := APairs[k];
      j := k;
    end;
    from_[j] := -1;
    APairs[j] := tmp;
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

(* The engine's `IsBlank` (`Spintax.Gsa.pas:156-159`): SPACE AND TAB, and nothing else.

   Written with CR and LF in it first, which quietly killed the third refusal below: the scan
   stopped AT the line break instead of walking onto it, so `TagOf`'s "a tag carrying a line
   break is not a tag" could never fire and a tag block split across two lines was lifted where
   the engine leaves it alone. A blank set copied by guess rather than from the source. *)
function GsaBlank(c: Char): Boolean;
begin
  Result := (c = ' ') or (c = #9);
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

(* A prefix that occurs nowhere in the document, so every name built on it is free --
   compared CASE-INSENSITIVELY, because the engine folds variable names and the engine's own
   `ChoosePrefix` says so in as many words (`Spintax.Gsa.pas:251`). Matching case-sensitively
   let a document carrying `%__SPX_U1%` in upper case hand the author's own variable to a
   generated name, and the render came back with the tag twice. *)
function FreePrefix(const ADoc: string): string;
var n: Integer; low: string;
begin
  low := LowerCase(ADoc);
  Result := '__spx_u';
  n := 0;
  while Pos(LowerCase(Result), low) > 0 do
  begin
    Inc(n);
    Result := '__spx' + IntToStr(n) + '_u';
  end;
end;

(* WHAT A REFUSAL MUST CARRY: the AUTHOR's text.

   The guard walks the CONVERTED document, where every BBCode bracket, `#file[...]` and `/#`
   has already become a `%__gsa_N%` ref. Lifting the block as it stands there hands the reader
   -- and the render -- this unit's placeholders instead of what they wrote, and marking it
   `Literal` makes that permanent: `SpNeutralize` treats `%` as structural, so the ref can
   never resolve again. Measured: `{#.de [b]Hallo[/b]} today.` came out as
   `{#.de %__gsa_l1%b%__gsa_l2%Hallo…} today.` on screen and in the dialog -- WORSE than the
   leak this guard was written to close, which at least kept the text.

   The engine does the identical lift and expands first, for the identical reason
   (`Spintax.Gsa.pas:843-846`, `ExpandMacroRefs` at `:438`): "a block that later turns out to
   be unconvertible puts them back before it is reported, so the host is handed the author's
   text and not this unit's placeholders". Mirrored here. *)
function ExpandRefs(const S: string; AMacros: TStrMap): string;
var i, n, j: Integer; nm, val: string;
begin
  Result := '';
  i := 1;
  n := Length(S);
  while i <= n do
  begin
    if S[i] = '%' then
    begin
      j := i + 1;
      while (j <= n) and (S[j] <> '%') do Inc(j);
      if j <= n then
      begin
        nm := Copy(S, i + 1, j - i - 1);
        if AMacros.TryGetValue(nm, val) then
        begin
          Result := Result + SpSafetyRestore(val);
          i := j + 1;
          Continue;
        end;
      end;
    end;
    Result := Result + S[i];
    Inc(i);
  end;
end;

{ Lifts every single-option tag block out of ADoc, appending one entry to AVars and one to
  ARefused for each, and returns the rewritten document. }
function GuardTagBlocks(const ADoc: string; AMacros: TStrMap; var AVars: TSpxVarPairs;
  var ARefused: TSpxGsaRefusals): string;
var
  i, j, depth, at, n, taken: Integer;
  content, prefix, name_, whole: string;
  seen: TStrMap;         { lifted text -> the name it was given }
begin
  Result := '';
  prefix := FreePrefix(ADoc);
  taken := 0;
  n := Length(ADoc);
  i := 1;
  seen := TStrMap.Create;
  try
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
      (* UNBALANCED, so this `{` closes nothing -- and the walk goes ON. Copying the remainder
         and stopping meant one stray brace anywhere disabled the guard for everything after
         it: `a { b {#.de Hallo} c` leaked exactly as before. The engine's own walk emits the
         brace and carries on (`Spintax.Gsa.pas:806-807`); so does this. *)
      Result := Result + ADoc[i];
      Inc(i);
      Continue;
    end;

    content := Copy(ADoc, i + 1, j - i - 1);
    if SingleOption(content) and TagShaped(content) then
    begin
      { The author's text, not the converter's placeholders -- see ExpandRefs above. }
      whole := ExpandRefs(Copy(ADoc, i, j - i + 1), AMacros);
      { IDENTICAL TEXT SHARES ONE NAME, as the engine's lifter does (`:269-273`) -- otherwise
        the same block twice made two variables, the count said "2 variables" for one distinct
        text, and the dialog's dedupe could never collapse them. }
      { A DICTIONARY, not a name=value list: the lifted text is arbitrary and may carry an
        `=` of its own, and `IndexOf` over a joined line found nothing at all -- the first
        version of this dedupe silently did not dedupe. }
      if not seen.TryGetValue(whole, name_) then
      begin
        Inc(taken);
        name_ := prefix + IntToStr(taken);
        seen.AddOrSetValue(whole, name_);
        at := Length(AVars);
        SetLength(AVars, at + 1);
        AVars[at].Name := name_;
        AVars[at].Value := whole;
        AVars[at].Literal := True;
      end;
      { One refusal per OCCURRENCE, which is what the engine reports too -- the dialog dedupes
        by name for display. }
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
  finally
    seen.Free;
  end;
end;

function SpxImportStillApplies(AWasRev, ANowRev: Int64;
  const AWasPath, ANowPath, AWasDoc, ANowDoc: string): Boolean;
begin
  Result := (AWasRev = ANowRev) and (AWasPath = ANowPath) and (AWasDoc = ANowDoc);
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
    { NOT SORTED HERE. GuardTagBlocks below appends to this array and reads nothing but its
      length, and nothing between here and there looks at it -- so the only sort that can be
      observed is the one after it. Sorting twice built every key twice and merged twice, on
      exactly the path this was made fast for. Found by Codex review, 2026-08-21. }

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
    Result.Doc := GuardTagBlocks(Result.Doc, macros, Result.Vars, Result.Refused);
    SpxSortVarPairs(Result.Vars);
  finally
    refused.Free;
    macros.Free;
  end;
end;

end.
