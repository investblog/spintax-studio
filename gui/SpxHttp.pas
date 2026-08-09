(*
 * SpxHttp -- one HTTP request, over WinHTTP, cancellable and bounded (ADR 0012).
 *
 * THE ONLY UNIT IN THIS PRODUCT THAT OPENS A SOCKET, and the suite says so by name: `NET_ALLOWED`
 * in `tests/studio_tests.dpr` holds exactly this file, and every other `.pas` still fails if it
 * reaches for one. That list was empty until this unit existed, which is the whole point of
 * having it rather than deleting the check.
 *
 * WHY WINHTTP AND NOT `fphttpclient`. Both are in the toolchain, and the second wants OpenSSL:
 * two DLLs in an MSIX that ships as one offline file, another WACK run, the OpenSSL/GPL
 * question this project already answered once for IPro, and a dependency on somebody else's
 * security calendar. WinHTTP is part of Windows and Windows updates it. Measured, not assumed:
 * `winhttp.pp` is in `winunits-base`, built for x86_64-win64, and declares everything used here
 * except `WinHttpSetTimeouts` -- which is the one `external` line below.
 *
 * NO WINDOWS IN THE INTERFACE. The seam is ADR 0007's: a caller passes strings and reads
 * strings, so the day a second platform appears the implementation moves and nothing above it
 * does. `{$IFDEF WINDOWS}` guards the body; elsewhere the unit compiles and every request
 * answers `heUnsupported`, which is a truthful answer rather than a link error.
 *
 * THREE THINGS THE RENDER PATH NEVER NEEDED AND THIS DOES:
 *
 * 1. A TIMEOUT. A render is bounded by the document; a model's answer is bounded by nothing at
 *    all, and a window that waits forever is a window that has crashed as far as the reader can
 *    tell. Four timeouts, because WinHTTP has four and a resolve that hangs is as bad as a read
 *    that does.
 * 2. CANCELLATION. Checked between reads rather than by killing the thread: `ACancel` is read,
 *    never written, by this unit. A caller sets it from the UI thread and the loop notices --
 *    a plain Boolean is enough because one side only writes and the other only reads.
 * 3. A CEILING ON THE BODY. `WinHttpReadData` will return whatever the far end sends, and the
 *    far end is not ours. Without a limit a wrong URL that answers with a disc image is an
 *    out-of-memory in a text editor.
 *
 * WHAT IT DOES NOT DO. No retries -- a retry policy belongs where the error is understood, and
 * 429 is not 500. No JSON. No provider knowledge. No key handling: the caller puts the header
 * in, so a key never lands in this unit's state and cannot be logged by it.
 *)
unit SpxHttp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  (* Which failure it was, so the window can say something a reader can act on. The strings
     are the GUI's business; this is the classification. *)
  TSpxHttpError = (
    heNone,          (* the request completed -- Status carries the HTTP code, which may be 4xx *)
    heBadUrl,        (* not a URL this can parse, or not http/https *)
    heNoNetwork,     (* the name did not resolve, or nothing accepted the connection *)
    heTimeout,       (* one of the four bounds ran out *)
    heSecurity,      (* TLS: certificate, protocol version, revocation *)
    heCancelled,     (* the caller asked, between reads *)
    heTooLarge,      (* the far end kept sending past the ceiling *)
    heUnsupported,   (* no transport on this platform *)
    heOther          (* Detail carries what Windows said *)
  );

  TSpxHttpRequest = record
    Url: string;
    Method: string;          (* 'POST' when empty *)
    Headers: TStrings;       (* `Name: value`, one per line; NOT owned by this unit *)
    Body: string;            (* sent as-is; UTF-8 is the caller's business *)
    TimeoutMs: Integer;      (* per phase; SPX_HTTP_TIMEOUT_MS when zero *)
    MaxBytes: Integer;       (* SPX_HTTP_MAX_BYTES when zero *)
  end;

  TSpxHttpResult = record
    Error: TSpxHttpError;
    Status: Integer;         (* the HTTP status; 0 when the exchange never got that far *)
    Body: string;
    (* What Windows said, for the log and for a reader who reports it. Never a key: this unit
       is never given one -- the caller puts the header in. *)
    Detail: string;
  end;

const
  SPX_HTTP_TIMEOUT_MS = 60000;
  (* Generous on purpose: a long answer from a slow model is normal, and a reader who has been
     told to wait can wait. What must not happen is FOREVER. *)
  SPX_HTTP_MAX_BYTES = 8 * 1024 * 1024;

(* THE URL, DECIDED WITHOUT DIALLING, and separate for two reasons rather than one. The window
   wants to show a reader the host it is about to call before it calls it, and the suite wants
   to assert what is accepted without a network -- a check that has to open a connection is a
   check that reddens behind a proxy, and a red build nobody believes is worse than none. *)
function SpxHttpParseUrl(const AUrl: string; out AHost, APath: string;
  out APort: Integer; out ASecure: Boolean): TSpxHttpError;

(* ACancel is read and never written here. Set it from another thread to stop between reads. *)
function SpxHttpSend(const ARequest: TSpxHttpRequest; const ACancel: PBoolean): TSpxHttpResult;

(* True when this build has a transport at all. The window asks before it offers the feature,
   rather than offering it and failing. *)
function SpxHttpAvailable: Boolean;

(* WHICH OF OURS A WINDOWS ERROR CODE MEANS, exported so the suite can ask it in numbers.

   The codes themselves come from `winhttp`, which declares all but one of them -- they were
   hand-copied here once and one was wrong: `ERROR_WINHTTP_SECURE_CERT_CN_INVALID` was written
   as base+169, which is `ERROR_WINHTTP_SECURE_INVALID_CERT`, so a certificate whose name did
   not match the host fell through to `heOther` and the reader was told "something went wrong"
   instead of "this connection is not what it claims to be". Found by review. A list of another
   unit's constants is enforced nowhere until something compares it to that unit -- and this
   unit was ALREADY in `uses`.

   The suite asks in LITERAL NUMBERS on purpose. Asserting against the same symbol the code
   uses would agree with itself whatever the value; the numbers come from Microsoft's published
   list, so the check sits between this file and its source rather than inside it. *)
function SpxHttpClassify(ACode: LongWord): TSpxHttpError;

implementation

{$IFDEF WINDOWS}
uses
  Windows, winhttp;

(* Not declared by winunits-base, and the one thing this unit needs that it lacks. Without it
   WinHTTP's defaults apply, and its default resolve timeout is infinite. *)
function WinHttpSetTimeouts(hInternet: HINTERNET; nResolveTimeout: Integer;
    nConnectTimeout: Integer; nSendTimeout: Integer;
  nReceiveTimeout: Integer): BOOL; stdcall; external 'winhttp.dll';

const
  (* THE ONLY ONE `winhttp` DOES NOT DECLARE -- measured, not assumed: every other code named
     below comes from the unit itself, and the hand-written copy of that list is gone. *)
  ERROR_WINHTTP_TIMEOUT = WINHTTP_ERROR_BASE + 2;

function SpxHttpClassify(ACode: LongWord): TSpxHttpError;
begin
  case ACode of
    ERROR_WINHTTP_TIMEOUT:
      Result := heTimeout;
    ERROR_WINHTTP_NAME_NOT_RESOLVED,
    ERROR_WINHTTP_CANNOT_CONNECT,
    ERROR_WINHTTP_CONNECTION_ERROR:
      Result := heNoNetwork;
    (* EVERY WAY A CERTIFICATE CAN BE REFUSED, not the three that were thought of. A reader
       behind a corporate proxy meets INVALID_CA; an expired certificate is DATE_INVALID; a
       host that does not match its certificate is CN_INVALID -- and that last one was the
       code written down wrongly, so the case it names never fired. *)
    ERROR_WINHTTP_SECURE_FAILURE,
    ERROR_WINHTTP_SECURE_CERT_CN_INVALID,
    ERROR_WINHTTP_SECURE_CERT_DATE_INVALID,
    ERROR_WINHTTP_SECURE_CERT_REVOKED,
    ERROR_WINHTTP_SECURE_CERT_REV_FAILED,
    ERROR_WINHTTP_SECURE_CERT_WRONG_USAGE,
    ERROR_WINHTTP_SECURE_INVALID_CERT,
    ERROR_WINHTTP_SECURE_CHANNEL_ERROR,
    ERROR_WINHTTP_SECURE_INVALID_CA:
      Result := heSecurity;
  else
    Result := heOther;
  end;
end;

function Fail(var R: TSpxHttpResult; AError: TSpxHttpError; const AWhere: string): TSpxHttpResult;
var
  code: DWORD;
begin
  code := GetLastError;
  R.Error := AError;
  if AError = heOther then R.Error := SpxHttpClassify(code);
  R.Detail := AWhere + ' (' + IntToStr(code) + ')';
  Result := R;
end;

function SpxHttpAvailable: Boolean;
begin
  Result := True;
end;

function SpxHttpParseUrl(const AUrl: string; out AHost, APath: string;
  out APort: Integer; out ASecure: Boolean): TSpxHttpError;
var
  comps: URL_COMPONENTS;
  wurl, host, path, extra: WideString;
begin
  AHost := ''; APath := ''; APort := 0; ASecure := False;
  wurl := UTF8Decode(Trim(AUrl));
  if wurl = '' then Exit(heBadUrl);
  FillChar(comps, SizeOf(comps), 0);
  comps.dwStructSize := SizeOf(comps);
  comps.dwSchemeLength := DWORD(-1);
  comps.dwHostNameLength := DWORD(-1);
  comps.dwUrlPathLength := DWORD(-1);
  comps.dwExtraInfoLength := DWORD(-1);
  if not WinHttpCrackUrl(PWideChar(wurl), Length(wurl), 0, @comps) then Exit(heBadUrl);

  (* http is allowed on purpose: a local model answers on plain http at 127.0.0.1, and refusing
     it would refuse the one configuration that never leaves the machine -- which is the
     configuration the privacy policy goes out of its way to describe. *)
  ASecure := comps.nScheme = INTERNET_SCHEME_HTTPS;
  if (not ASecure) and (comps.nScheme <> INTERNET_SCHEME_HTTP) then Exit(heBadUrl);

  SetString(host, comps.lpszHostName, comps.dwHostNameLength);
  SetString(path, comps.lpszUrlPath, comps.dwUrlPathLength);
  if comps.dwExtraInfoLength > 0 then
  begin
    SetString(extra, comps.lpszExtraInfo, comps.dwExtraInfoLength);
    path := path + extra;
  end;
  if path = '' then path := '/';
  if host = '' then Exit(heBadUrl);

  AHost := UTF8Encode(host);
  APath := UTF8Encode(path);
  APort := comps.nPort;
  Result := heNone;
end;

function SpxHttpSend(const ARequest: TSpxHttpRequest; const ACancel: PBoolean): TSpxHttpResult;
var
  host, path, verb, hdrs: WideString;
  hostS, pathS: string;
  port: Integer;
  secure: Boolean;
  sess, conn, req: HINTERNET;
  flags, status, statusLen, read_, avail: DWORD;
  timeout, ceiling: Integer;
  bodyBytes: RawByteString;
  chunk: array[0..8191] of Byte;
  got: TMemoryStream;
  i, at: Integer;
  line, name_, value: string;
begin
  Result := Default(TSpxHttpResult);
  sess := nil; conn := nil; req := nil;

  timeout := ARequest.TimeoutMs;
  if timeout <= 0 then timeout := SPX_HTTP_TIMEOUT_MS;
  ceiling := ARequest.MaxBytes;
  if ceiling <= 0 then ceiling := SPX_HTTP_MAX_BYTES;

  (* ── the URL, taken apart by WinHTTP rather than by us ──────────────────────
     A hand-written splitter is one more thing that can disagree with the stack that will
     actually dial. *)
  Result.Error := SpxHttpParseUrl(ARequest.Url, hostS, pathS, port, secure);
  if Result.Error <> heNone then
  begin
    Result.Detail := 'not a url this can call';
    Exit;
  end;
  host := UTF8Decode(hostS);
  path := UTF8Decode(pathS);

  verb := UTF8Decode(ARequest.Method);
  if verb = '' then verb := 'POST';

  got := TMemoryStream.Create;
  try
    sess := WinHttpOpen(PWideChar(WideString('SpintaxStudio')),
                        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, nil, nil, 0);
    if sess = nil then Exit(Fail(Result, heOther, 'WinHttpOpen'));
    (* All four, because a hang anywhere reads the same to a user. *)
    WinHttpSetTimeouts(sess, timeout, timeout, timeout, timeout);

    conn := WinHttpConnect(sess, PWideChar(host), INTERNET_PORT(port), 0);
    if conn = nil then Exit(Fail(Result, heOther, 'WinHttpConnect'));

    flags := 0;
    if secure then flags := WINHTTP_FLAG_SECURE;
    req := WinHttpOpenRequest(conn, PWideChar(verb), PWideChar(path), nil, nil, nil, flags);
    if req = nil then Exit(Fail(Result, heOther, 'WinHttpOpenRequest'));

    (* ── headers, one per line, name and value split at the first colon ── *)
    if ARequest.Headers <> nil then
      for i := 0 to ARequest.Headers.Count - 1 do
      begin
        line := ARequest.Headers[i];
        at := Pos(':', line);
        if at <= 1 then Continue;
        name_ := Trim(Copy(line, 1, at - 1));
        value := Trim(Copy(line, at + 1, Length(line)));
        if name_ = '' then Continue;
        hdrs := UTF8Decode(name_ + ': ' + value);
        WinHttpAddRequestHeaders(req, PWideChar(hdrs), Length(hdrs),
                                 WINHTTP_ADDREQ_FLAG_ADD);
      end;

    bodyBytes := ARequest.Body;
    if not WinHttpSendRequest(req, nil, 0,
                              Pointer(bodyBytes), Length(bodyBytes),
                              Length(bodyBytes), 0) then
      Exit(Fail(Result, heOther, 'WinHttpSendRequest'));

    if not WinHttpReceiveResponse(req, nil) then
      Exit(Fail(Result, heOther, 'WinHttpReceiveResponse'));

    status := 0;
    statusLen := SizeOf(status);
    if not WinHttpQueryHeaders(req,
             WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
             nil, @status, @statusLen, nil) then
      Exit(Fail(Result, heOther, 'WinHttpQueryHeaders'));
    Result.Status := status;

    (* ── the body, in chunks, asking about the cancel between each ── *)
    repeat
      if (ACancel <> nil) and ACancel^ then
      begin
        Result.Error := heCancelled;
        Result.Detail := 'cancelled by the caller';
        Exit;
      end;
      avail := 0;
      if not WinHttpQueryDataAvailable(req, @avail) then
        Exit(Fail(Result, heOther, 'WinHttpQueryDataAvailable'));
      if avail = 0 then Break;
      if avail > DWORD(SizeOf(chunk)) then avail := SizeOf(chunk);
      read_ := 0;
      if not WinHttpReadData(req, @chunk[0], avail, @read_) then
        Exit(Fail(Result, heOther, 'WinHttpReadData'));
      if read_ = 0 then Break;
      if got.Size + Int64(read_) > ceiling then
      begin
        Result.Error := heTooLarge;
        Result.Detail := 'over ' + IntToStr(ceiling) + ' bytes';
        Exit;
      end;
      got.WriteBuffer(chunk[0], read_);
    until False;

    SetLength(bodyBytes, got.Size);
    if got.Size > 0 then Move(got.Memory^, bodyBytes[1], got.Size);
    Result.Body := bodyBytes;
    Result.Error := heNone;
  finally
    got.Free;
    if req <> nil then WinHttpCloseHandle(req);
    if conn <> nil then WinHttpCloseHandle(conn);
    if sess <> nil then WinHttpCloseHandle(sess);
  end;
end;

{$ELSE}

(* EVERY FUNCTION THE INTERFACE DECLARES, and the omission of one is what taught this file the
   rule. `SpxHttpParseUrl` was declared above and implemented only inside `{$IFDEF WINDOWS}`,
   so the unit did not compile at all on Linux or macOS -- `Forward declaration not solved`,
   in the compiler's own words -- and CI's two non-Windows legs stayed red for five commits
   while every local gate passed, because every local gate runs on Windows.

   Stubs rather than a hand-rolled parser: `SpxHttpParseUrl` is WinHTTP's `WinHttpCrackUrl`,
   and a second implementation for a platform the product does not ship on would be code the
   Windows build never runs and nothing compares -- a worse answer than saying plainly that
   there is no transport here. *)

function SpxHttpAvailable: Boolean;
begin
  Result := False;
end;

function SpxHttpClassify(ACode: LongWord): TSpxHttpError;
begin
  Result := heUnsupported;
end;

function SpxHttpParseUrl(const AUrl: string; out AHost, APath: string;
  out APort: Integer; out ASecure: Boolean): TSpxHttpError;
begin
  AHost := ''; APath := ''; APort := 0; ASecure := False;
  Result := heUnsupported;
end;

function SpxHttpSend(const ARequest: TSpxHttpRequest; const ACancel: PBoolean): TSpxHttpResult;
begin
  Result := Default(TSpxHttpResult);
  Result.Error := heUnsupported;
  Result.Detail := 'no transport on this platform';
end;

{$ENDIF}

end.
