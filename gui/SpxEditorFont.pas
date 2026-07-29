(*
 * SpxEditorFont -- which font the EDITORS draw with, and how big.
 *
 * THE EDITOR'S FONT IS NOT THE INTERFACE'S. Everything that is chrome -- menus, buttons,
 * grids, the status bar -- keeps the family and the size the person configured for their
 * desktop, and SpxUi says at length why. The editors are the exception, and they are the
 * exception twice over:
 *
 *   the FAMILY, because a template is markup and markup wants a fixed pitch; and
 *   the SIZE, because a desktop configured at 9 pt is configured for reading captions, not
 *   for reading `{a|b|{c|d}}` -- the editor starts at a size chosen for the text it holds and
 *   the user moves it from there.
 *
 * AVAILABLE IS NOT THE SAME AS USABLE. Asking Screen.Fonts whether a family is installed
 * answers a different question from "can it draw THIS document": every one of these families
 * carries Latin, most carry Cyrillic, and almost none carries CJK. A template with Japanese in
 * it rendered in Consolas is a page of boxes, and the family list would have said yes. So a
 * candidate is asked to draw a SAMPLE of the document's own characters, and is skipped when it
 * cannot -- which is why the cascade ends in CJK families rather than in a second Latin one.
 *
 * THIS IS NOT PER-GLYPH FALLBACK. One font is chosen for the whole document, not a different
 * one per run of text: that is what a text engine does, SynEdit does not offer it, and doing
 * it by hand would mean owning the measurement of every line. A document mixing scripts no
 * single installed font covers will therefore lose something -- the choice is which, and this
 * picks the family that covers the most of what is actually there.
 *
 * THE CHOOSER IS PURE, and this unit is too: no LCL, no Windows, nothing that needs a screen.
 * That is what lets the suite -- a console program built without the LCL on its unit path --
 * drive it with a fake probe that answers from a table. The real probe needs a device context
 * and therefore lives in SpxUi, with the rest of the code that knows what a screen is.
 *)
unit SpxEditorFont;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { Can this family draw this sample? The suite substitutes its own. }
  TSpxFontProbe = function(const AFamily, ASample: string): Boolean;

const
  { The cascade, in the order it is walked. Latin and Cyrillic first, because that is what
    this product's templates are mostly made of and those families read best at small sizes;
    then one family per CJK script, because none of the above carries any of them:
      MS Gothic  -- Japanese, on every Windows since 95
      NSimSun    -- Simplified Chinese
      GulimChe   -- Korean
      MingLiU    -- Traditional Chinese
    All four are fixed-pitch and ship with Windows' language packs. }
  SPX_EDITOR_FONTS: array[0..7] of string = (
    'Cascadia Mono',
    'Consolas',
    'DejaVu Sans Mono',
    'Noto Sans Mono',
    'MS Gothic',
    'NSimSun',
    'GulimChe',
    'MingLiU'
  );

  { Points. Fixed rather than derived from the desktop: a size that follows the caption font
    is a size nobody chose for reading a template, and 12 is the smallest that stays
    comfortable for the punctuation this language is made of. The user moves it from here and
    the move is remembered; Ctrl+0 comes back to THIS, not to the desktop's. }
  SPX_EDITOR_SIZE = 12;
  SPX_EDITOR_SIZE_MIN = 6;
  SPX_EDITOR_SIZE_MAX = 32;

  { How many distinct characters a sample carries. Enough to catch a script, small enough that
    probing eight families costs nothing: a document is sampled by its DISTINCT characters, so
    a megabyte of Latin prose yields the same short sample as a paragraph of it. }
  SPX_SAMPLE_MAX = 48;

{ The document's own characters, deduplicated and capped -- what a family has to be able to
  draw. ASCII is represented by a single letter rather than by all of it: no installed font
  lacks ASCII, and spending the sample on it would crowd out the characters that decide. }
function SpxFontSample(const AText: string): string;

{ THE CHOICE. AManual is a family the user named, or empty for Auto. A named family is tried
  FIRST and wins if the probe accepts it; if it does not -- uninstalled since, or unable to
  draw this document -- the cascade is walked as if Auto. Returns '' when nothing is
  acceptable, which the caller reads as "leave the font alone". }
function SpxChooseEditorFont(const AManual, ASample: string;
  const ACascade: array of string; AProbe: TSpxFontProbe): string;

{ A size the user asked for, held to what stays readable. }
function SpxClampEditorSize(APoints: Integer): Integer;

implementation

function SpxFontSample(const AText: string): string;
var
  i, n, len, b, kept, j: Integer;
  cp: LongWord;
  hasAscii, known: Boolean;
  { MEMBERSHIP IN A BITSET, one bit per character below U+10000, because this loop runs over
    the WHOLE document on every render and the obvious way to write it does not.

    It was written the obvious way first: cut the character out with Copy and look for it in
    the answer with Pos. That allocates a string for every non-ASCII character in the file --
    not for every NEW one -- and searches a growing haystack each time. Measured at 54 ms for
    a 1.14 MB Cyrillic template and 13 ms for a 1.37 MB Spanish one, once per render, on the
    thread that draws. The early exit does not save it: it fires at 48 DISTINCT characters,
    and ordinary European text never has that many.

    Eight kilobytes of stack, cleared once per call, turns the test into one bit lookup and
    the allocations into one per character actually kept -- at most 48. }
  seen: array[0..8191] of Byte;
  { Above U+FFFF a bitset would be half a megabyte for characters that are vanishingly rare in
    a template; a linear scan of at most 48 is the right shape there. }
  astral: array[0..SPX_SAMPLE_MAX - 1] of LongWord;
  astralN: Integer;
begin
  Result := '';
  hasAscii := False;
  kept := 0;
  astralN := 0;
  FillChar(seen{%H-}, SizeOf(seen), 0);
  FillChar(astral{%H-}, SizeOf(astral), 0);
  i := 1;
  n := Length(AText);
  while (i <= n) and (kept < SPX_SAMPLE_MAX) do
  begin
    { UTF-8 by its lead byte, so a character travels whole. A byte that is neither a lead nor
      a plain ASCII one is a stray continuation -- the text is malformed there, and stepping
      one byte is what keeps this a sampler rather than a validator. }
    b := Ord(AText[i]);
    if b < $80 then len := 1
    else if (b and $E0) = $C0 then len := 2
    else if (b and $F0) = $E0 then len := 3
    else if (b and $F8) = $F0 then len := 4
    else len := 1;
    if i + len - 1 > n then Break;

    if len = 1 then
      hasAscii := True
    else
    begin
      { The character's own number, assembled from the lead byte and its continuations. Working
        in numbers rather than in byte strings is what makes the membership test exact: the
        earlier version compared substrings, which on MALFORMED input could find a match
        straddling two sequences and drop a character it had never seen (measured on
        `E3 E3 81 | E3 81 C3 | E3 81 E3`). A number cannot straddle anything. }
      case len of
        2: cp := LongWord(b and $1F);
        3: cp := LongWord(b and $0F);
      else
        cp := LongWord(b and $07);
      end;
      for j := 1 to len - 1 do
        cp := (cp shl 6) or LongWord(Ord(AText[i + j]) and $3F);

      if cp < $10000 then
      begin
        known := (seen[cp shr 3] and (1 shl (cp and 7))) <> 0;
        if not known then seen[cp shr 3] := seen[cp shr 3] or (1 shl (cp and 7));
      end
      else
      begin
        known := False;
        for j := 0 to astralN - 1 do
          if astral[j] = cp then begin known := True; Break; end;
        if not known then
        begin
          astral[astralN] := cp;
          Inc(astralN);
        end;
      end;

      if not known then
      begin
        Result := Result + Copy(AText, i, len);
        Inc(kept);
      end;
    end;
    Inc(i, len);
  end;
  { One ASCII letter stands for all of it: every installed font has ASCII, and letting it fill
    the sample would push out the characters that actually decide the answer. }
  if hasAscii or (Result = '') then Result := 'A' + Result;
end;

function SpxChooseEditorFont(const AManual, ASample: string;
  const ACascade: array of string; AProbe: TSpxFontProbe): string;
var i: Integer;
begin
  Result := '';
  if not Assigned(AProbe) then Exit;
  { A NAMED FAMILY WINS -- but only if it can still do the job. Silently keeping a choice the
    machine can no longer honour would leave the editor drawing boxes and no way to tell why. }
  if (AManual <> '') and AProbe(AManual, ASample) then Exit(AManual);
  for i := Low(ACascade) to High(ACascade) do
    if AProbe(ACascade[i], ASample) then Exit(ACascade[i]);
  { Nothing accepted: the caller keeps whatever the control already has, which is the system's
    font. A proportional editor is poor; a font that cannot draw the text is worse. }
end;

function SpxClampEditorSize(APoints: Integer): Integer;
begin
  Result := APoints;
  if Result < SPX_EDITOR_SIZE_MIN then Result := SPX_EDITOR_SIZE_MIN;
  if Result > SPX_EDITOR_SIZE_MAX then Result := SPX_EDITOR_SIZE_MAX;
end;

end.
