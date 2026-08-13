(*
 * SpxSettings -- the handful of choices that must outlive a restart.
 *
 * WHY THIS EXISTS AT ALL. Four settings already had nowhere to live: the interface language,
 * the side the rail is on, the preview's mode and which panel is open. They reset on every
 * launch, which is tolerable for a mode and not for a font size -- a size that is forgotten
 * each time is worse than no size at all. The Store release needs this anyway: settings go in
 * the user's profile through a known-folder API, never beside the .exe and never with
 * administrator rights (spec §11).
 *
 * A PLAIN key=value FILE, UTF-8, one line each. Not an .ini (TIniFile writes the system
 * codepage, and this file crosses machines), not JSON (nothing else here parses any, and a
 * dependency for eleven values is a poor trade). A person can open it and fix it, which is the
 * point of a settings file that lives outside the program.
 *
 * IT NEVER RAISES AND NEVER BLOCKS A START. A missing file, an empty one, a directory that
 * cannot be created, a line of noise, a number where a word belongs -- every one of them means
 * "use the default for that key" and nothing more. Preferences are not worth an error dialog,
 * and a settings file is exactly the thing that gets copied half-written or edited by hand.
 *
 * IT KNOWS NOTHING ABOUT WHAT THE VALUES MEAN. The language code is a string here; whether
 * `xx` is a language this build has is the window's question, and it already answers it
 * (SpxLangFor falls back). The same for the panel index. This unit's whole job is to survive
 * the round trip.
 *)
unit SpxSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SpxEditorFont, SpxLlm{$IFDEF WINDOWS}, Windirs{$ENDIF};

const
  (* THE HIGHEST PANEL INDEX THIS FILE WILL RESTORE, and it must be raised whenever the window
     gains a panel.

     It was a bare `2` inside the parser, written when there were three panels, and adding a
     fourth broke restoring it in the quietest possible way: a stored `3` was clamped to `2`,
     so the reader who left the AI panel open came back to the variants panel with nothing said
     and nothing logged. Found by launching the application and looking at it.

     THE SUITE HAD A CHECK ON THIS ALREADY, and it did not help -- which is the part worth
     remembering. It fed the parser `panel=7` and asserted the answer was `'2'`, a number typed
     into the test. That kind of check reports when the clamp CHANGES; it cannot report that
     the clamp is too low, so it sat green through the defect and then went red at the fix,
     blaming it. Both checks now read this constant instead of a literal, and a second one
     round-trips the highest real panel -- so the pair fails when the window gains a panel and
     this does not. *)
  SPX_PANEL_MAX = 3;

type
  { The editor's colours. Only the editor and the source view: the preview shows the user's
    own HTML as it will be published, so darkening it would misreport the work. }
  TSpxTheme = (spxThemeLight, spxThemeDark);

  TSpxPrefs = record
    { The interface language: a code ('en', 'ru', …), or empty for the system's. Follow means
      "take it from the document" and then the code is only what to fall back to. }
    LangFollow: Boolean;
    Lang: string;
    RailRight: Boolean;
    PreviewSource: Boolean;
    { 0..SPX_PANEL_MAX for the panels, or -1 for a collapsed bottom block. }
    Panel: Integer;
    { POINTS, and the editor's own -- not an offset from the desktop's caption font. The
      editor has its own readability policy now (SpxEditorFont says why), so a size here is
      an absolute the user chose and Ctrl+0 returns to the EDITOR's default rather than to
      whatever the desktop is configured for. }
    FontSize: Integer;
    { The family the user named, or empty for Auto -- and Auto is not "the first installed"
      but "the first that can draw this document" (SpxEditorFont). }
    FontFamily: string;
    Theme: TSpxTheme;
    { How wide the group editor's slide-out is. A variant can be longer than any sensible
      default, and the panel is the one place in this window whose useful width depends on
      the DOCUMENT rather than on the layout. }
    SlideWidth: Integer;
    { The SAME SLOT holds two faces -- the group editor and the help -- and they want different
      widths: one shows a list of short variants, the other shows prose. One remembered width
      would mean a group editor at 900 px because someone widened the help once. Both in
      96-dpi units, like SlideWidth, for the reason SlideResized gives. }
    HelpWidth: Integer;
    (* THE GSA IMPORT, OFF UNTIL ASKED FOR. `Spintax.Gsa` converts a GSA Search Engine Ranker
       template into this family's syntax (spec §4.7), and most authors have never seen GSA:
       a File menu carrying an import for a product they do not use is clutter they cannot
       turn off. So the menu item appears only when this is on, and this is off by default --
       the same shape as any other optional dialect, and the reason it is a SETTING rather
       than an always-visible action. *)
    GsaImport: Boolean;
    (* THE CONNECTION PROFILE (spec §4.5) -- identity and grants only, never the key itself:
       the key lives in the Windows Credential Manager under `byok/<Ai.Id>` (§6), and this
       file is exactly the one people attach to bug reports. The auth mode and the request
       format are stored as WORDS (`api-key`, `anthropic`), not ordinals: an enum that gains
       a member must not renumber a saved choice. An old file without these keys reads back
       as the default profile -- no network, no consent -- which is what R0 was. *)
    Ai: TSpxLlmProfile;
  end;

const
  { Narrow enough to leave the editor usable, wide enough for a long variant. The default is
    the width the panel shipped with. }
  SPX_SLIDE_MIN = 200;
  SPX_SLIDE_MAX = 900;
  SPX_SLIDE_DEFAULT = 300;
  { The slot holds the CONTENTS -- twelve sections and their articles -- while the help itself
    is in the left pane. So it wants a little more than the group editor and nothing like a
    reading column: the page needs its measured 450 px from the pane beside it, and every pixel
    taken here is one taken from there. }
  SPX_HELP_DEFAULT = 260;

function SpxDefaultPrefs: TSpxPrefs;

{ Where the file lives on this machine, folder included: the known-folder API for the base,
  and a FIXED name under it.

  NOT GetAppConfigDir, which is what this used at first and which is wrong here for a reason
  worth writing down: LCL hooks OnGetApplicationName to return Application.TITLE
  (application.inc:72-79), so the path would follow a string that exists to be DISPLAYED --
  rename the window, or translate it, and every setting silently disappears. Measured: the app
  wrote to `…\Local\Spintax Studio\` while a probe built from the same code wrote to
  `…\Local\prefsx\`, and the theme this was meant to restore never came back. }
function SpxPrefsPath: string;

{ The pair that does the work. The public ones below are these against SpxPrefsPath; the
  suite drives these directly against a temporary file. }
function SpxLoadPrefsFrom(const APath: string): TSpxPrefs;
function SpxSavePrefsTo(const APath: string; const APrefs: TSpxPrefs): Boolean;

function SpxLoadPrefs: TSpxPrefs;
function SpxSavePrefs(const APrefs: TSpxPrefs): Boolean;

implementation

function SpxDefaultPrefs: TSpxPrefs;
begin
  Result.LangFollow := False;
  Result.Lang := '';
  Result.RailRight := False;
  Result.PreviewSource := False;
  Result.Panel := 0;
  Result.FontSize := SPX_EDITOR_SIZE;
  Result.FontFamily := '';
  Result.Theme := spxThemeLight;
  Result.SlideWidth := SPX_SLIDE_DEFAULT;
  Result.HelpWidth := SPX_HELP_DEFAULT;
  { OFF. A reader who has never used GSA should not find its import in their File menu. }
  Result.GsaImport := False;
  Result.Ai := SpxLlmDefaultProfile;
end;

function SpxConfigDir: string;
begin
  {$IFDEF WINDOWS}
  { SHGetFolderPath under the hood -- the known-folder API the Store asks for (spec §11), and
    the one an MSIX container redirects correctly. }
  Result := GetWindowsSpecialDir(CSIDL_LOCAL_APPDATA, False);
  if Result <> '' then
  begin
    Result := IncludeTrailingPathDelimiter(Result) + 'spintax-studio';
    Exit;
  end;
  {$ENDIF}
  { Not Windows, or a machine that will not say where its profile is: keep the product name
    fixed here too. GetAppConfigDir(False) includes Application.Title,
    which makes tests and renamed binaries write to different folders. }
  Result := IncludeTrailingPathDelimiter(GetUserDir) + '.config' + PathDelim + 'spintax-studio';
end;

function SpxPrefsPath: string;
begin
  Result := IncludeTrailingPathDelimiter(SpxConfigDir) + 'settings.txt';
end;

function Clamp(AValue, ALow, AHigh: Integer): Integer;
begin
  Result := AValue;
  if Result < ALow then Result := ALow;
  if Result > AHigh then Result := AHigh;
end;

{ 'yes'/'no', and anything else is the default -- a half-written file should not decide a
  setting by accident. }
function ReadBool(const AValue: string; ADefault: Boolean): Boolean;
begin
  if AValue = 'yes' then Result := True
  else if AValue = 'no' then Result := False
  else Result := ADefault;
end;

function WriteBool(AValue: Boolean): string;
begin
  if AValue then Result := 'yes' else Result := 'no';
end;

function SpxLoadPrefsFrom(const APath: string): TSpxPrefs;
var lines: TStringList; i, at, n: Integer; line, key, val: string;
    kind: TSpxLlmKind; auth: TSpxLlmAuth;
begin
  Result := SpxDefaultPrefs;
  if not FileExists(APath) then Exit;
  lines := TStringList.Create;
  try
    try
      lines.LoadFromFile(APath);
    except
      { Locked, unreadable, gone between the test and the open: the defaults are already in
        Result and a preference is not worth failing a launch over. }
      Exit;
    end;
    for i := 0 to lines.Count - 1 do
    begin
      line := Trim(lines[i]);
      if (line = '') or (line[1] = '#') then Continue;
      at := Pos('=', line);
      if at < 2 then Continue;
      key := LowerCase(Trim(Copy(line, 1, at - 1)));
      val := Trim(Copy(line, at + 1, Length(line)));

      if key = 'lang' then Result.Lang := val
      else if key = 'lang.follow' then Result.LangFollow := ReadBool(val, Result.LangFollow)
      else if key = 'rail.right' then Result.RailRight := ReadBool(val, Result.RailRight)
      else if key = 'preview.source' then
        Result.PreviewSource := ReadBool(val, Result.PreviewSource)
      else if key = 'gsa.import' then
        Result.GsaImport := ReadBool(val, Result.GsaImport)
      else if key = 'panel' then
      begin
        if TryStrToInt(val, n) then Result.Panel := Clamp(n, -1, SPX_PANEL_MAX);
      end
      else if key = 'font.size' then
      begin
        if TryStrToInt(val, n) then Result.FontSize := SpxClampEditorSize(n);
      end
      else if key = 'font.family' then Result.FontFamily := val
      else if key = 'slide.width' then
      begin
        if TryStrToInt(val, n) then
          Result.SlideWidth := Clamp(n, SPX_SLIDE_MIN, SPX_SLIDE_MAX);
      end
      else if key = 'help.width' then
      begin
        if TryStrToInt(val, n) then
          Result.HelpWidth := Clamp(n, SPX_SLIDE_MIN, SPX_SLIDE_MAX);
      end
      else if key = 'theme' then
      begin
        if val = 'dark' then Result.Theme := spxThemeDark
        else if val = 'light' then Result.Theme := spxThemeLight;
      end
      { The connection profile. The words go through SpxLlm's own maps, and a word this build
        does not recognise leaves the default in place -- the same fail-soft rule as every
        other key, and the direction matters: an unknown AUTH word must not quietly become a
        weaker mode. }
      else if key = 'ai.profile' then
      begin
        if val <> '' then Result.Ai.Id := val;
      end
      else if key = 'ai.kind' then
      begin
        { Through a local, because FromWord writes its out-parameter even when it answers
          False -- assigning straight into the profile would replace the default with the
          enum's first member on any word this build does not know. }
        if SpxLlmKindFromWord(val, kind) then Result.Ai.Kind := kind;
      end
      else if key = 'ai.endpoint' then Result.Ai.Endpoint := val
      else if key = 'ai.model' then Result.Ai.Model := val
      else if key = 'ai.auth' then
      begin
        if SpxLlmAuthFromWord(val, auth) then Result.Ai.Auth := auth;
      end
      else if key = 'ai.network' then Result.Ai.Network := ReadBool(val, Result.Ai.Network)
      else if key = 'ai.consent.origin' then Result.Ai.ConsentOrigin := val
      else if key = 'ai.key.origin' then Result.Ai.KeyOrigin := val;
      { An unknown key is left alone rather than reported: a file written by a later version
        must not lose its settings just because this one opened it. }
    end;
  finally
    lines.Free;
  end;
end;

function SpxSavePrefsTo(const APath: string; const APrefs: TSpxPrefs): Boolean;
var lines: TStringList; dir: string;
begin
  Result := False;
  dir := ExtractFilePath(APath);
  if (dir <> '') and not DirectoryExists(dir) then
    if not ForceDirectories(dir) then Exit;
  lines := TStringList.Create;
  try
    lines.Add('# Spintax Studio settings. One key per line; delete a line for its default.');
    lines.Add('lang=' + APrefs.Lang);
    lines.Add('lang.follow=' + WriteBool(APrefs.LangFollow));
    lines.Add('rail.right=' + WriteBool(APrefs.RailRight));
    lines.Add('preview.source=' + WriteBool(APrefs.PreviewSource));
    lines.Add('gsa.import=' + WriteBool(APrefs.GsaImport));
    lines.Add('panel=' + IntToStr(APrefs.Panel));
    lines.Add('font.size=' + IntToStr(APrefs.FontSize));
    lines.Add('font.family=' + APrefs.FontFamily);
    lines.Add('slide.width=' + IntToStr(APrefs.SlideWidth));
    lines.Add('help.width=' + IntToStr(APrefs.HelpWidth));
    if APrefs.Theme = spxThemeDark then lines.Add('theme=dark') else lines.Add('theme=light');
    { The connection profile -- words, not ordinals, and no secret anywhere in this file. }
    lines.Add('ai.profile=' + APrefs.Ai.Id);
    lines.Add('ai.kind=' + SpxLlmKindWord(APrefs.Ai.Kind));
    lines.Add('ai.endpoint=' + APrefs.Ai.Endpoint);
    lines.Add('ai.model=' + APrefs.Ai.Model);
    lines.Add('ai.auth=' + SpxLlmAuthWord(APrefs.Ai.Auth));
    lines.Add('ai.network=' + WriteBool(APrefs.Ai.Network));
    lines.Add('ai.consent.origin=' + APrefs.Ai.ConsentOrigin);
    lines.Add('ai.key.origin=' + APrefs.Ai.KeyOrigin);
    try
      lines.SaveToFile(APath);
      Result := True;
    except
      { A read-only profile, a full disk, a file someone else has open. The window carries on
        with the settings it has; the next save will try again. }
    end;
  finally
    lines.Free;
  end;
end;

function SpxLoadPrefs: TSpxPrefs;
begin
  Result := SpxLoadPrefsFrom(SpxPrefsPath);
end;

function SpxSavePrefs(const APrefs: TSpxPrefs): Boolean;
begin
  Result := SpxSavePrefsTo(SpxPrefsPath, APrefs);
end;

end.
