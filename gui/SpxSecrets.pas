(*
 * SpxSecrets -- the reader's key, in the Windows Credential Manager and nowhere else.
 *
 * THE SPEC SETTLES THIS, AND IT IS WORTH REPEATING WHY. §6: "Секреты — только Windows Credential
 * Manager (DPAPI-backed), НИКОГДА не плейнтекст в конфиге", and §7 adds that no secret lives in
 * `%APPDATA%` or beside the `.exe`. ADR 0012 had written "DPAPI, in its own file", and the
 * Credential Manager serves the same intent more strongly: it IS DPAPI bound to the Windows
 * account, and there is no file at all -- so there is nothing to attach to a bug report by
 * accident. This project has already destroyed a settings file by guessing at its path; a key
 * that never becomes a file cannot be lost that way.
 *
 * TWO SECRETS, TWO NAMESPACES, AND THEY MUST NOT MERGE. §6 is explicit that the reader's own
 * provider key and the token for a managed service (if one is ever built, §10/§11) are different
 * things: the first goes straight to their provider on their account, the second would only ever
 * authenticate against us while the upstream key sat on a server. Storing them under one name
 * would make a future migration silently overwrite one with the other, and the suite asserts the
 * two can never collide for any provider name.
 *
 * NOTHING HERE IS DECLARED BY `winunits-base` -- measured, not assumed. `CredWriteW`,
 * `CredReadW`, `CredDeleteW` and `CredFree` are declared below from `advapi32.dll`, as is the
 * `CREDENTIALW` record they take.
 *
 * PERSISTENCE IS `CRED_PERSIST_LOCAL_MACHINE`, which is a misleading name: it does not mean
 * "shared by every user of this machine". It means the credential belongs to this user, survives
 * a reboot, and does NOT roam. `CRED_PERSIST_ENTERPRISE` roams with a roaming profile, which is
 * the wrong answer for a secret, and `CRED_PERSIST_SESSION` would make the reader retype it at
 * every logon.
 *
 * A MISSING SECRET IS NOT AN ERROR. A first run has none, and a Windows reinstall takes the
 * whole credential set with it -- so `SpxSecretRead` answers False without noise, and the window
 * says "enter the key again" rather than showing a 401 the reader cannot act on.
 *
 * NO LOGGING, EVER. Nothing in this unit writes a secret anywhere but the store; the last
 * failure code is available separately for a message, and it carries a number rather than a
 * value.
 *
 * EVERY COMMENT IS STAR-PAREN, NEVER A BRACE COMMENT.
 *)
unit SpxSecrets;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  (* WHICH secret. Not a provider name -- the provider is a separate argument -- but which KIND
     of thing it authenticates, because the two must never share a target. *)
  TSpxSecretKind = (
    skByokKey,       (* the reader's own provider key; goes to their provider, on their account *)
    skServiceToken   (* reserved: a token for a managed service of ours, if one is ever built *)
  );

(* True when this build has a credential store at all. The window asks before offering to
   remember a key, rather than offering and failing. *)
function SpxSecretsAvailable: Boolean;

(* The target name a secret is filed under. Exported so the suite can assert the two kinds never
   collide, and so a reader can be told where to look in the Credential Manager. *)
function SpxSecretTarget(AKind: TSpxSecretKind; const AProvider: string): string;

function SpxSecretStore(AKind: TSpxSecretKind; const AProvider, ASecret: string): Boolean;
(* False when there is none -- which is ordinary, not a failure. *)
function SpxSecretRead(AKind: TSpxSecretKind; const AProvider: string; out ASecret: string): Boolean;
(* True when it is gone afterwards, including when there was nothing to delete. *)
function SpxSecretForget(AKind: TSpxSecretKind; const AProvider: string): Boolean;

(* The last Windows error, for a message that has to say more than "it did not work". Never a
   secret: a number. *)
function SpxSecretsLastError: LongWord;

implementation

{$IFDEF WINDOWS}
uses
  Windows;
{$ENDIF}

const
  (* The prefix every target shares, so a reader searching the Credential Manager finds the
     application's entries together and nothing else of ours hides among them. *)
  SPX_CRED_PREFIX = 'SpintaxStudio';

function SpxSecretTarget(AKind: TSpxSecretKind; const AProvider: string): string;
var
  slot: string;
begin
  (* The two namespaces of §6. Written as distinct words rather than as a flag inside one name,
     because a flag is something a later edit can drop. *)
  if AKind = skByokKey then slot := 'byok' else slot := 'service';
  Result := SPX_CRED_PREFIX + '/' + slot + '/' + LowerCase(Trim(AProvider));
end;

{$IFDEF WINDOWS}

const
  CRED_TYPE_GENERIC          = 1;
  CRED_PERSIST_LOCAL_MACHINE = 2;
  ERROR_NOT_FOUND            = 1168;
  (* The API's own ceiling on a blob. An API key is nowhere near it; the check exists so that a
     caller handing in a document instead of a key gets a refusal rather than a truncation. *)
  CRED_MAX_CREDENTIAL_BLOB_SIZE = 5 * 512;

type
  PCredentialW = ^TCredentialW;
  TCredentialW = record
    Flags: DWORD;
    CredType: DWORD;
    TargetName: LPWSTR;
    Comment: LPWSTR;
    LastWritten: FILETIME;
    CredentialBlobSize: DWORD;
    CredentialBlob: PByte;
    Persist: DWORD;
    AttributeCount: DWORD;
    Attributes: Pointer;
    TargetAlias: LPWSTR;
    UserName: LPWSTR;
  end;

function CredWriteW(Credential: PCredentialW; Flags: DWORD): BOOL; stdcall;
  external 'advapi32.dll' name 'CredWriteW';
function CredReadW(TargetName: LPCWSTR; CredType: DWORD; Flags: DWORD;
  out Credential: PCredentialW): BOOL; stdcall; external 'advapi32.dll' name 'CredReadW';
function CredDeleteW(TargetName: LPCWSTR; CredType: DWORD; Flags: DWORD): BOOL; stdcall;
  external 'advapi32.dll' name 'CredDeleteW';
procedure CredFree(Buffer: Pointer); stdcall; external 'advapi32.dll' name 'CredFree';

var
  GLastError: LongWord = 0;

function SpxSecretsAvailable: Boolean;
begin
  Result := True;
end;

function SpxSecretsLastError: LongWord;
begin
  Result := GLastError;
end;

function SpxSecretStore(AKind: TSpxSecretKind; const AProvider, ASecret: string): Boolean;
var
  cred: TCredentialW;
  target, who: WideString;
  blob: RawByteString;
begin
  GLastError := 0;
  Result := False;
  if Trim(AProvider) = '' then Exit;

  (* Stored as UTF-8 bytes rather than as UTF-16, so what comes back out is exactly what went in
     regardless of what the caller's string type happens to be today. *)
  blob := ASecret;
  if Length(blob) > CRED_MAX_CREDENTIAL_BLOB_SIZE then Exit;

  target := UTF8Decode(SpxSecretTarget(AKind, AProvider));
  (* A user name is required by the Credential Manager's own UI to show anything sensible, and
     it is NOT a secret -- it says which slot this is, in words a reader recognises. *)
  who := UTF8Decode(SpxSecretTarget(AKind, AProvider));

  FillChar(cred, SizeOf(cred), 0);
  cred.CredType := CRED_TYPE_GENERIC;
  cred.TargetName := PWideChar(target);
  cred.UserName := PWideChar(who);
  cred.Persist := CRED_PERSIST_LOCAL_MACHINE;
  cred.CredentialBlobSize := Length(blob);
  if Length(blob) > 0 then cred.CredentialBlob := PByte(@blob[1]);

  Result := CredWriteW(@cred, 0);
  if not Result then GLastError := GetLastError;
end;

function SpxSecretRead(AKind: TSpxSecretKind; const AProvider: string; out ASecret: string): Boolean;
var
  cred: PCredentialW;
  target: WideString;
  blob: RawByteString;
begin
  GLastError := 0;
  ASecret := '';
  Result := False;
  if Trim(AProvider) = '' then Exit;

  target := UTF8Decode(SpxSecretTarget(AKind, AProvider));
  cred := nil;
  if not CredReadW(PWideChar(target), CRED_TYPE_GENERIC, 0, cred) then
  begin
    GLastError := GetLastError;
    (* NOT FOUND IS NOT A FAILURE. A first run has no key, and a fresh Windows profile has no
       credential set at all -- both are the same ordinary answer, and reporting them as an
       error is how a reader ends up reading "401" for "you have not entered it yet". *)
    if GLastError = ERROR_NOT_FOUND then GLastError := 0;
    Exit;
  end;

  try
    if (cred <> nil) and (cred^.CredentialBlobSize > 0) and (cred^.CredentialBlob <> nil) then
    begin
      SetLength(blob, cred^.CredentialBlobSize);
      Move(cred^.CredentialBlob^, blob[1], cred^.CredentialBlobSize);
      ASecret := blob;
    end;
    Result := True;
  finally
    if cred <> nil then CredFree(cred);
  end;
end;

function SpxSecretForget(AKind: TSpxSecretKind; const AProvider: string): Boolean;
var
  target: WideString;
begin
  GLastError := 0;
  Result := False;
  if Trim(AProvider) = '' then Exit;
  target := UTF8Decode(SpxSecretTarget(AKind, AProvider));
  Result := CredDeleteW(PWideChar(target), CRED_TYPE_GENERIC, 0);
  if not Result then
  begin
    GLastError := GetLastError;
    (* Already absent is the state the caller asked for. *)
    if GLastError = ERROR_NOT_FOUND then
    begin
      GLastError := 0;
      Result := True;
    end;
  end;
end;

{$ELSE}

function SpxSecretsAvailable: Boolean;
begin
  Result := False;
end;

function SpxSecretsLastError: LongWord;
begin
  Result := 0;
end;

function SpxSecretStore(AKind: TSpxSecretKind; const AProvider, ASecret: string): Boolean;
begin
  Result := False;
end;

function SpxSecretRead(AKind: TSpxSecretKind; const AProvider: string; out ASecret: string): Boolean;
begin
  ASecret := '';
  Result := False;
end;

function SpxSecretForget(AKind: TSpxSecretKind; const AProvider: string): Boolean;
begin
  Result := False;
end;

{$ENDIF}

end.
