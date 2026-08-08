(*
 * SpxFiles -- the host's side of the template set: bytes, names, and the folder.
 *
 * editor-core does no I/O by decision (ADR 0003): the set arrives as an in-memory
 * `slug -> text` map so M0 is testable without a filesystem. This is the layer that builds
 * that map, and it is deliberately free of LCL so the console suite can test it against a
 * real temp folder rather than against a mock.
 *
 * The rules it carries, each of which would otherwise be re-invented at a call site:
 *
 *   - A file is a member of the set when its extension is `.spintax`, compared without
 *     regard to case, and the SLUG is its base name EXACTLY as the filesystem spells it.
 *     `#include "Intro"` must not find `intro.spintax`: the engine compares targets byte for
 *     byte since v0.2.2, like the rest of the family, and NTFS would happily open the wrong
 *     case and leave the preview disagreeing with every other engine about one document.
 *   - Bytes in, bytes out. A UTF-8 BOM is stripped on read (the engine parses text, not a
 *     byte-order mark) and never written back, because the family's other engines read these
 *     files too and a BOM is a stray character to them.
 *   - The line ending of a file that already exists is its own. An editor that silently
 *     rewrites every LF to CRLF on the first save turns a one-line edit into a whole-file
 *     diff, and this document lives in the user's git.
 *)
unit SpxFiles;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Spintax, SpxStudio;

const
  SPX_EXT = '.spintax';
  { What a document that has never been saved is written with. LF, because that is what the
    family's shared corpus and this project's own fixtures use, and because nothing on
    Windows has needed CRLF in a decade. An existing file keeps whatever it had. }
  SPX_DEFAULT_EOL = #10;

{ Reads a file as the bytes it is, minus a UTF-8 BOM. No transcoding: the host runs in
  CP_UTF8 (spec §7) and every layer above holds UTF-8 in an AnsiString. }
function SpxReadTextFile(const Path: string): string;

{ Writes the bytes it is given, with no BOM and no line-ending fixups. }
procedure SpxWriteTextFile(const Path, Text: string);

{ The first line terminator in the text -- CRLF, LF or CR -- or SPX_DEFAULT_EOL when the
  text has none. CRLF is tested before CR, or every CRLF file would read as CR. }
function SpxDetectEol(const Text: string): string;

{ True when the text ends with a line terminator. Kept apart from the ending itself because
  TStrings.Text always appends one, and a file that had none must not grow one on save. }
function SpxEndsWithEol(const Text: string): Boolean;

{ Rewrites every terminator -- CRLF, LF or CR -- as AEol. Nothing else is touched. }
function SpxNormalizeEol(const Text, AEol: string): string;

{ How many line terminators Text ends with, counting CRLF as one. }
function SpxTrailEols(const Text: string): Integer;

{ Text with at most AMax trailing terminators. AMax < 0 leaves it exactly as it is, which is
  every ordinary document; the GSA import is the one caller that passes a number, because the
  converter appends a `#def` block whose line breaks GSA never wrote. Never PADS -- a render
  that already ends with fewer stays as it is. }
function SpxClampTrailEols(const Text: string; AMax: Integer): string;

{ The slug a path contributes to the set: base name, extension removed, case untouched. }
function SpxSlugOf(const Path: string): string;

{ True when this path is a set member by extension (case-insensitive on the extension only). }
function SpxIsTemplateFile(const Path: string): Boolean;

{ Every `*.spintax` file in one folder as `slug -> text`. Flat: subfolders are not walked,
  which is the set ADR 0003 describes. Unreadable files are skipped rather than fatal -- one
  locked file should not cost the user their whole set. Caller frees. }
function SpxLoadTemplateSet(const Folder: string): TSpxTemplateSet;

implementation

function SpxReadTextFile(const Path: string): string;
var
  fs: TFileStream;
  n: Int64;
begin
  Result := '';
  fs := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    n := fs.Size;
    if n > 0 then
    begin
      SetLength(Result, n);
      fs.ReadBuffer(Result[1], n);
    end;
  finally
    fs.Free;
  end;
  if (Length(Result) >= 3) and (Result[1] = #$EF) and (Result[2] = #$BB) and
     (Result[3] = #$BF) then
    Delete(Result, 1, 3);
end;

procedure SpxWriteTextFile(const Path, Text: string);
var fs: TFileStream;
begin
  fs := TFileStream.Create(Path, fmCreate);
  try
    if Text <> '' then fs.WriteBuffer(Text[1], Length(Text));
  finally
    fs.Free;
  end;
end;

function SpxTrailEols(const Text: string): Integer;
var i: Integer;
begin
  Result := 0;
  i := Length(Text);
  while i >= 1 do
  begin
    if Text[i] = #10 then
    begin
      Inc(Result);
      { CRLF is ONE terminator, so the CR before an LF is consumed with it. }
      if (i > 1) and (Text[i - 1] = #13) then Dec(i);
      Dec(i);
    end
    else if Text[i] = #13 then
    begin
      Inc(Result);
      Dec(i);
    end
    else
      Break;
  end;
end;

function SpxClampTrailEols(const Text: string; AMax: Integer): string;
var have, i: Integer;
begin
  Result := Text;
  if AMax < 0 then Exit;
  have := SpxTrailEols(Result);
  i := Length(Result);
  while have > AMax do
  begin
    if Result[i] = #10 then
    begin
      if (i > 1) and (Result[i - 1] = #13) then Dec(i);
      Dec(i);
    end
    else
      Dec(i);
    Dec(have);
  end;
  SetLength(Result, i);
end;

function SpxDetectEol(const Text: string): string;
var i: Integer;
begin
  for i := 1 to Length(Text) do
  begin
    if Text[i] = #13 then
    begin
      if (i < Length(Text)) and (Text[i + 1] = #10) then Exit(#13#10);
      Exit(#13);
    end;
    if Text[i] = #10 then Exit(#10);
  end;
  Result := SPX_DEFAULT_EOL;
end;

function SpxEndsWithEol(const Text: string): Boolean;
begin
  Result := (Text <> '') and (Text[Length(Text)] in [#10, #13]);
end;

function SpxNormalizeEol(const Text, AEol: string): string;
var
  i, n: Integer;
  sb: TStringBuilder;
begin
  sb := TStringBuilder.Create(Length(Text) + 16);
  try
    i := 1;
    n := Length(Text);
    while i <= n do
    begin
      if Text[i] = #13 then
      begin
        sb.Append(AEol);
        if (i < n) and (Text[i + 1] = #10) then Inc(i, 2) else Inc(i);
      end
      else if Text[i] = #10 then
      begin
        sb.Append(AEol);
        Inc(i);
      end
      else
      begin
        sb.Append(Text[i]);
        Inc(i);
      end;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function SpxSlugOf(const Path: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(Path), '');
end;

function SpxIsTemplateFile(const Path: string): Boolean;
begin
  Result := LowerCase(ExtractFileExt(Path)) = SPX_EXT;
end;

function SpxLoadTemplateSet(const Folder: string): TSpxTemplateSet;
var
  sr: TSearchRec;
  dir, slug: string;
begin
  Result := TSpxTemplateSet.Create;
  if Folder = '' then Exit;
  dir := IncludeTrailingPathDelimiter(Folder);
  { Enumerated with '*' and filtered here, not with a '*.spintax' mask: on Windows a mask
    extension of eight characters also matches longer ones through the 8.3 alias, so
    `notes.spintaxbackup` would join the set. }
  if FindFirst(dir + '*', faAnyFile, sr) <> 0 then Exit;
  try
    repeat
      if (sr.Attr and faDirectory) <> 0 then Continue;
      if not SpxIsTemplateFile(sr.Name) then Continue;
      slug := SpxSlugOf(sr.Name);
      if slug = '' then Continue;                    { a bare `.spintax` has no slug }
      if Result.ContainsKey(slug) then Continue;     { first wins; NTFS cannot make two }
      try
        Result.Add(slug, SpxReadTextFile(dir + sr.Name));
      except
        on E: EStreamError do ;                      { locked or vanished: skip, not fatal }
      end;
    until FindNext(sr) <> 0;
  finally
    FindClose(sr);
  end;
end;

end.
