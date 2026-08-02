(*
 * SpxExport -- writing a generated set out: .xlsx, .txt, one file per variant (spec §4.6).
 *
 * Pure and GUI-free, like the rest of editor-core: no dialogs here, only paths and bytes, so
 * the console suite can write real files and read them back.
 *
 * .xlsx IS WRITTEN HERE, not by a library. The whole format needed for two columns is five
 * small XML parts in a zip, and `zipper` is in the RTL -- while FPSpreadsheet is not in the
 * Lazarus install this project builds with and would have to come from OPM on every build
 * machine and in CI. Verified against the real thing: Excel 16.0 opens the result with no
 * repair prompt and hands back every cell verbatim, markup, ampersands, an embedded newline
 * and a tab included (ADR 0005).
 *
 * REPRODUCIBILITY IS THE POINT OF THE SEED COLUMN. Any row can be regenerated with
 * SpRender(tmpl, ctx{seed}) given the same engine and the same context, so the seed travels
 * with the text in every format that has room for it -- a column in .xlsx, an optional
 * prefix in .txt, part of the file name per-variant.
 *)
unit SpxExport;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, zipper, Spintax, SpxStudio;

type
  { What a .txt export does with a variant that has line breaks in it.

    The format is one variant per line (spec §4.6), and a variant is often multi-line HTML --
    so the two cannot both be true. Collapsing keeps the file readable as a list and says so
    in the report; refusing keeps the text intact and sends the author to a format that can
    hold it. Nothing here silently writes a file whose line count is not its variant count. }
  TSpxTxtBreaks = (spxTxtCollapse, spxTxtRefuse);

  TSpxTxtOpts = record
    WithSeed: Boolean;      { prefix each line with `<seed>\t` }
    Breaks: TSpxTxtBreaks;
  end;

  { What an export actually did. Written is how many variants reached the file; Collapsed how
    many had their line breaks folded into spaces, which is the one lossy thing any of these
    writers do and therefore the one thing that must never be silent. }
  TSpxExportReport = record
    Written: Integer;
    Collapsed: Integer;
    Refused: Boolean;       { a multi-line variant met spxTxtRefuse -- nothing was written }
    Path: string;
  end;

function SpxDefaultTxtOpts: TSpxTxtOpts;

{ One variant per line, in the order given. Returns False only when a multi-line variant met
  spxTxtRefuse; the file is not created in that case, so a refusal never leaves a half-written
  export behind. }
function SpxWriteTxt(const Path: string; Variants: TSpxVariantList;
  const Opts: TSpxTxtOpts; out Report: TSpxExportReport): Boolean;

{ One file per variant, named `<Prefix><seed>.<Ext>` in Dir -- the seed rather than the index,
  so a file names the thing that regenerates it. Dir must exist. }
function SpxWritePerFile(const Dir, Prefix, Ext: string; Variants: TSpxVariantList;
  out Report: TSpxExportReport): Boolean;

{ Two columns -- seed, then variant -- with a header row. Line breaks inside a cell are kept:
  a spreadsheet cell holds them, which is why this format is the lossless one.

  SheetName is what the tab is called and HeadSeed/HeadText are the two column headings; all
  three are written as given (Cyrillic is fine, verified). They are parameters rather than
  literals because the caller is the window, which knows what language the product is
  speaking -- a workbook whose tab says «Варианты» over columns saying `seed` and `variant`
  is a translation half-done. }
function SpxWriteXlsx(const Path, SheetName, HeadSeed, HeadText: string;
  Variants: TSpxVariantList;
  out Report: TSpxExportReport): Boolean;

{ The escaping an XML TEXT NODE needs, and the removal XML 1.0 requires.

  Three jobs, and each of them is load-bearing:

  - `&`, `<`, `>` are escaped, and CR is escaped as `&#13;` rather than written raw. XML 1.0
    §2.11 makes every conformant parser normalise a literal CR (and CRLF) to LF on the way
    back in, so a raw CR is not round-tripped -- it is silently rewritten. Windows templates
    are full of CRLF, so this is the common case, not a corner. Excel escapes it for the same
    reason.
  - Characters XML forbids outright are DROPPED, because there is no escape for them: a
    control byte in a cell does not make the file damaged, it makes it invalid. That covers
    C0 controls other than tab and the two line endings, and U+FFFE / U+FFFF.
  - The text is validated as UTF-8 and malformed bytes are dropped. Not theoretical: the file
    layer reads bytes and hands them on without transcoding (gui/SpxFiles), so a template
    saved in a legacy Windows codepage arrives here as invalid UTF-8, and one such byte makes
    a workbook nothing will open. Verified against two independent parsers.

  The engine's own sentinels U+E000-U+E005 are private-use characters, legal in XML, and pass
  through untouched -- Studio lints them in the document rather than hiding them here. }
function SpxXmlText(const S: string): string;

{ The same for an ATTRIBUTE value, which needs more: a quote ends the attribute, and tab and
  the line endings are normalised to spaces by any conformant parser unless they are written
  as character references. Used for the sheet name, where the first version used the text-node
  escaper and a sheet called `Акция "Лето"` produced a workbook no parser would open. }
function SpxXmlAttr(const S: string): string;

implementation

const
  { The five parts a spreadsheet needs and no more. Written as constants because they never
    vary: one sheet, no styles, no shared strings. }
  PART_CONTENT_TYPES = '[Content_Types].xml';
  PART_ROOT_RELS     = '_rels/.rels';
  PART_WORKBOOK      = 'xl/workbook.xml';
  PART_WORKBOOK_RELS = 'xl/_rels/workbook.xml.rels';
  PART_SHEET         = 'xl/worksheets/sheet1.xml';

  XML_CONTENT_TYPES =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
    '</Types>';

  XML_ROOT_RELS =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
    '</Relationships>';

  XML_WORKBOOK_RELS =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
    '</Relationships>';

function SpxDefaultTxtOpts: TSpxTxtOpts;
begin
  Result.WithSeed := False;
  Result.Breaks := spxTxtCollapse;
end;

{ One UTF-8 sequence, validated. Returns its length in bytes and the code point, or 0 when
  the bytes at I are not a well-formed sequence -- overlong forms, lone continuation bytes,
  truncated tails, surrogates and anything past U+10FFFF all come back as 0, because XML has
  no way to carry them and a reader would simply refuse the file. }
function Utf8At(const S: string; I: Integer; out CP: LongWord): Integer;
var b0, n, k: Integer; b: Integer;
begin
  CP := 0;
  b0 := Ord(S[I]);
  if b0 < $80 then
  begin
    CP := b0;
    Exit(1);
  end;
  if (b0 and $E0) = $C0 then begin n := 2; CP := b0 and $1F; end
  else if (b0 and $F0) = $E0 then begin n := 3; CP := b0 and $0F; end
  else if (b0 and $F8) = $F0 then begin n := 4; CP := b0 and $07; end
  else Exit(0);                                   { continuation byte, or $F8..$FF }

  if I + n - 1 > Length(S) then Exit(0);          { truncated at the end of the string }
  for k := 1 to n - 1 do
  begin
    b := Ord(S[I + k]);
    if (b and $C0) <> $80 then Exit(0);
    CP := (CP shl 6) or LongWord(b and $3F);
  end;

  { Overlong encodings are invalid UTF-8 and a classic way to smuggle a forbidden character
    past a naive filter. }
  if ((n = 2) and (CP < $80)) or ((n = 3) and (CP < $800)) or ((n = 4) and (CP < $10000)) then
    Exit(0);
  if (CP >= $D800) and (CP <= $DFFF) then Exit(0);          { surrogate halves }
  if CP > $10FFFF then Exit(0);
  Result := n;
end;

{ True when the code point is one XML 1.0 allows at all. }
function XmlAllows(CP: LongWord): Boolean;
begin
  Result := (CP = $9) or (CP = $A) or (CP = $D) or
            ((CP >= $20) and (CP <= $D7FF)) or
            ((CP >= $E000) and (CP <= $FFFD)) or
            ((CP >= $10000) and (CP <= $10FFFF));
end;

{ The shared scan. Escaping differs between a text node and an attribute value; validation
  does not, so it lives in one place. }
function Escape(const S: string; ForAttribute: Boolean): string;
var i, n: Integer; cp: LongWord;
begin
  Result := '';
  i := 1;
  while i <= Length(S) do
  begin
    n := Utf8At(S, i, cp);
    if n = 0 then
    begin
      { Not UTF-8. Dropped, one byte at a time, so the rest of a mostly-valid text survives. }
      Inc(i);
      Continue;
    end;
    if not XmlAllows(cp) then
    begin
      Inc(i, n);
      Continue;
    end;
    case cp of
      Ord('&'): Result := Result + '&amp;';
      Ord('<'): Result := Result + '&lt;';
      Ord('>'): Result := Result + '&gt;';
      { CR always as a reference: a literal one is normalised to LF on the way back. }
      $D: Result := Result + '&#13;';
      Ord('"'): if ForAttribute then Result := Result + '&quot;'
                else Result := Result + '"';
      $9, $A: if ForAttribute then
                Result := Result + '&#' + IntToStr(cp) + ';'
              else
                Result := Result + Chr(cp);
    else
      Result := Result + Copy(S, i, n);
    end;
    Inc(i, n);
  end;
end;

function SpxXmlText(const S: string): string;
begin
  Result := Escape(S, False);
end;

function SpxXmlAttr(const S: string): string;
begin
  Result := Escape(S, True);
end;

{ A line break, for the purpose of "one variant per line": CR, LF, CRLF, and U+2028 / U+2029.
  The last two are here because the engine itself ends a line on them (spec §7's two line
  models), and a file whose lines were counted without them is a file several editors show
  with more lines than it has variants. Returns the length in bytes, or 0. }
function BreakAt(const S: string; I: Integer): Integer;
begin
  if S[I] = #13 then
  begin
    if (I < Length(S)) and (S[I + 1] = #10) then Exit(2);
    Exit(1);
  end;
  if S[I] = #10 then Exit(1);
  { E2 80 A8 / E2 80 A9 }
  if (S[I] = #$E2) and (I + 2 <= Length(S)) and (S[I + 1] = #$80) and
     ((S[I + 2] = #$A8) or (S[I + 2] = #$A9)) then Exit(3);
  Result := 0;
end;

{ Line breaks folded into single spaces, and the caller told whether anything was folded.
  CRLF collapses to ONE space rather than two, which is what a reader expects and what a
  naive per-character replace gets wrong. }
function CollapseBreaks(const S: string; out Changed: Boolean): string;
var i, n: Integer;
begin
  Result := '';
  Changed := False;
  i := 1;
  while i <= Length(S) do
  begin
    n := BreakAt(S, i);
    if n > 0 then
    begin
      Changed := True;
      Result := Result + ' ';
      Inc(i, n);
    end
    else
    begin
      Result := Result + S[i];
      Inc(i);
    end;
  end;
end;

function HasBreak(const S: string): Boolean;
var i: Integer;
begin
  i := 1;
  while i <= Length(S) do
  begin
    if BreakAt(S, i) > 0 then Exit(True);
    Inc(i);
  end;
  Result := False;
end;

procedure InitReport(out R: TSpxExportReport; const Path: string);
begin
  R.Written := 0;
  R.Collapsed := 0;
  R.Refused := False;
  R.Path := Path;
end;

{ Bytes to a file, with no BOM and no line-ending translation: the whole project is UTF-8 and
  the engine's output keeps whatever breaks it produced (gui/SpxFiles does the same on the
  way in). }
procedure WriteBytes(const Path, Data: string);
var fs: TFileStream;
begin
  fs := TFileStream.Create(Path, fmCreate);
  try
    if Length(Data) > 0 then fs.WriteBuffer(Data[1], Length(Data));
  finally
    fs.Free;
  end;
end;

function SpxWriteTxt(const Path: string; Variants: TSpxVariantList;
  const Opts: TSpxTxtOpts; out Report: TSpxExportReport): Boolean;
var
  sb: TStringList;
  i: Integer;
  line: string;
  changed: Boolean;
begin
  InitReport(Report, Path);
  Result := False;
  if Variants = nil then Exit;

  { Checked BEFORE anything is written, so a refusal leaves no file at all rather than a
    truncated one the author might mistake for the export. }
  if Opts.Breaks = spxTxtRefuse then
    for i := 0 to Variants.Count - 1 do
      if HasBreak(Variants[i].Text) then
      begin
        Report.Refused := True;
        Exit;
      end;

  sb := TStringList.Create;
  try
    for i := 0 to Variants.Count - 1 do
    begin
      line := CollapseBreaks(Variants[i].Text, changed);
      if changed then Inc(Report.Collapsed);
      if Opts.WithSeed then line := IntToStr(Variants[i].Seed) + #9 + line;
      sb.Add(line);
    end;
    try
      { TStringList.Text uses the platform's line ending, which for a list of variants is
        exactly right: this file IS a list of lines, and the breaks inside variants are gone
        by construction. }
      WriteBytes(Path, sb.Text);
    except
      { Counted only once the bytes are down. A report that says "12 written" about a write
        that raised is worse than no report. }
      on E: Exception do
      begin
        Report.Collapsed := 0;
        Exit(False);
      end;
    end;
    Report.Written := Variants.Count;
  finally
    sb.Free;
  end;
  Result := True;
end;

{ Anything that could make a name mean something other than a name. Path separators are the
  obvious ones -- a prefix of `..\` wrote the export OUTSIDE the folder it was given, which
  is how this was found -- and on Windows a colon is worse than it looks: `a:b` creates a
  zero-byte file `a` and hides the text in an alternate data stream, so the author sees an
  empty export and no error at all. Measured, both of them. }
function SafeNamePart(const S: string): string;
var i: Integer; c: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    c := S[i];
    if (c = '\') or (c = '/') or (c = ':') or (c = '*') or (c = '?') or (c = '"') or
       (c = '<') or (c = '>') or (c = '|') or (c < ' ') then
      Result := Result + '_'
    else
      Result := Result + c;
  end;
end;

function SpxWritePerFile(const Dir, Prefix, Ext: string; Variants: TSpxVariantList;
  out Report: TSpxExportReport): Boolean;
var i: Integer; name_, prefix_, ext_: string;
begin
  InitReport(Report, Dir);
  Result := False;
  if Variants = nil then Exit;
  if not DirectoryExists(Dir) then Exit;

  prefix_ := SafeNamePart(Prefix);
  ext_ := SafeNamePart(Ext);
  if (ext_ <> '') and (ext_[1] <> '.') then ext_ := '.' + ext_;

  try
    for i := 0 to Variants.Count - 1 do
    begin
      { The seed names the file, because the seed is what regenerates it -- an index would
        name a position in a list nobody keeps. An existing file of that name is overwritten:
        the same set exported twice is the same set. }
      name_ := IncludeTrailingPathDelimiter(Dir) + prefix_ +
               IntToStr(Variants[i].Seed) + ext_;
      WriteBytes(name_, Variants[i].Text);
      { Counted AFTER the write, so a report never claims a file that does not exist. }
      Inc(Report.Written);
    end;
  except
    { A full disk, a read-only folder, a file held open by something else. The count says how
      far it got, which is what the caller needs to say to the author. }
    on E: Exception do Exit(False);
  end;
  Result := True;
end;

{ A1-style column name, for as many columns as anyone asks for. Written in full rather than
  capped at Z with a comment: the cap would be one more rule to remember and this is five
  lines. }
function ColName(Col: Integer): string;
begin
  Result := '';
  repeat
    Result := Chr(Ord('A') + (Col mod 26)) + Result;
    Col := (Col div 26) - 1;
  until Col < 0;
end;

function SheetXml(const Variants: TSpxVariantList;
  const HeadSeed, HeadText: string): string;
var sb: TStringList; i: Integer; row: string;

  function TextCell(Col, Row: Integer; const Text: string): string;
  begin
    { Inline strings: no shared-string table to keep consistent, at the cost of a bigger
      file. xml:space="preserve" because a variant may legitimately begin or end with a
      space, and a trimmed cell is a changed export. }
    Result := Format('<c r="%s%d" t="inlineStr"><is><t xml:space="preserve">%s</t></is></c>',
      [ColName(Col), Row, SpxXmlText(Text)]);
  end;

  { The seed is a NUMBER, and writing it as a string was a real defect: a spreadsheet sorted
    on that column would order 10 before 9, filters would offer text matching instead of
    ranges, and Excel would flag every cell as a number stored as text. LongWord's maximum is
    exact in a double, so there is nothing to lose by writing it as one. }
  function NumberCell(Col, Row: Integer; Value: LongWord): string;
  begin
    Result := Format('<c r="%s%d"><v>%u</v></c>', [ColName(Col), Row, Value]);
  end;

begin
  sb := TStringList.Create;
  try
    sb.Add('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.Add('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sb.Add('<sheetData>');
    sb.Add('<row r="1">' + TextCell(0, 1, HeadSeed) + TextCell(1, 1, HeadText) + '</row>');
    for i := 0 to Variants.Count - 1 do
    begin
      row := Format('<row r="%d">', [i + 2]);
      row := row + NumberCell(0, i + 2, Variants[i].Seed);
      row := row + TextCell(1, i + 2, Variants[i].Text);
      sb.Add(row + '</row>');
    end;
    sb.Add('</sheetData></worksheet>');
    Result := sb.Text;
  finally
    sb.Free;
  end;
end;

{ A tab name Excel will accept: it forbids : \ / ? * [ ] outright and stops at 31 characters,
  and a workbook naming a sheet illegally is refused by readers that check (openpyxl does;
  Excel silently repairs, which is worse). Replaced rather than dropped, so the name stays
  recognisable. Counted in CODE POINTS -- 31 Cyrillic letters is 62 bytes, and truncating on
  bytes would both cut the name short and risk splitting a character in half. }
function SafeSheetName(const S: string): string;
var i, n, taken: Integer; cp: LongWord; ch: string;
begin
  Result := '';
  taken := 0;
  i := 1;
  while (i <= Length(S)) and (taken < 31) do
  begin
    n := Utf8At(S, i, cp);
    if n = 0 then
    begin
      Inc(i);
      Continue;
    end;
    ch := Copy(S, i, n);
    if (ch = ':') or (ch = '\') or (ch = '/') or (ch = '?') or (ch = '*') or
       (ch = '[') or (ch = ']') then
      ch := '-';
    Result := Result + ch;
    Inc(taken);
    Inc(i, n);
  end;
  Result := Trim(Result);
  if Result = '' then Result := 'Sheet1';
end;

function WorkbookXml(const SheetName: string): string;
begin
  Result :=
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
    '<sheets><sheet name="' + SpxXmlAttr(SafeSheetName(SheetName)) +
    '" sheetId="1" r:id="rId1"/></sheets>' +
    '</workbook>';
end;

function SpxWriteXlsx(const Path, SheetName, HeadSeed, HeadText: string;
  Variants: TSpxVariantList; out Report: TSpxExportReport): Boolean;
var
  zip: TZipper;
  streams: TList;
  i: Integer;
  name_: string;

  procedure AddPart(const AName, AContent: string);
  var ms: TMemoryStream;
    {$IFDEF UNIX}
    entry: TZipFileEntry;
    {$ENDIF}
  begin
    ms := TMemoryStream.Create;
    { Registered for cleanup BEFORE anything can raise. The zipper reads the streams when it
      saves, so they have to outlive the call that adds them -- and it does not own them, so
      they are freed in the finally below. }
    streams.Add(ms);
    if Length(AContent) > 0 then ms.WriteBuffer(AContent[1], Length(AContent));
    ms.Position := 0;
    {$IFDEF UNIX}
    { Streams have no source filesystem mode. Without explicit Unix attributes, FPC's
      unzipper recreates the entry with mode 000 on macOS, making the workbook unreadable. }
    entry := zip.Entries.AddFileEntry(ms, AName);
    entry.Attributes := UNIX_FILE or UNIX_DEFAULT;
    {$ELSE}
    zip.Entries.AddFileEntry(ms, AName);
    {$ENDIF}
  end;

begin
  InitReport(Report, Path);
  Result := False;
  if Variants = nil then Exit;

  name_ := SheetName;

  zip := nil;
  streams := TList.Create;
  try
    zip := TZipper.Create;
    zip.FileName := Path;
    { [Content_Types].xml first, which is where a reader looks first. }
    AddPart(PART_CONTENT_TYPES, XML_CONTENT_TYPES);
    AddPart(PART_ROOT_RELS, XML_ROOT_RELS);
    AddPart(PART_WORKBOOK, WorkbookXml(name_));
    AddPart(PART_WORKBOOK_RELS, XML_WORKBOOK_RELS);
    AddPart(PART_SHEET, SheetXml(Variants, HeadSeed, HeadText));
    try
      zip.ZipAllFiles;
    except
      { The zipper creates the output file before it writes the entries, so a failure
        part-way leaves a truncated .xlsx sitting where the author will try to open it.
        Removed, so a failed export leaves nothing rather than something broken -- the same
        promise the txt refusal makes. }
      on E: Exception do
      begin
        if FileExists(Path) then DeleteFile(Path);
        Exit(False);
      end;
    end;
    Report.Written := Variants.Count;
    Result := True;
  finally
    for i := 0 to streams.Count - 1 do TObject(streams[i]).Free;
    streams.Free;
    zip.Free;
  end;
end;

end.
