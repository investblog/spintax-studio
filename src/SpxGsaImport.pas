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
  finally
    refused.Free;
    macros.Free;
  end;
end;

end.
