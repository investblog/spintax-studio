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
    (* THE FAR END SAID "ASK SOMEBODY ELSE", AND THIS DOES NOT.

       WinHTTP follows up to ten redirects by default and RESENDS the request headers to the new
       host -- which is where the reader's API key is. So a misconfigured or hostile endpoint
       could move the recipient of a credential without the reader ever seeing it happen. The
       feature is switched off and the 3xx is reported instead, with the address it named, so
       that changing where a prompt goes stays a decision somebody makes (spec §4.5). *)
    heRedirected,
    heTooLarge,      (* the far end kept sending past the ceiling *)
    (* CLEARTEXT OFF THIS MACHINE, WHICH IS A TRANSPORT FACT AND NOTHING MORE.

       Plain `http` to anything but loopback is refused. The reason is narrow and worth keeping
       narrow: a request to 127.0.0.1 does not cross a network interface, and a request to
       anywhere else does -- so a credential in a header, and the reader's document in the body,
       would travel where anyone on the path can read them. Authentication became a property of
       the profile rather than of the address (spec §4.5), which is right, and it is exactly
       what makes this rule necessary: `api-key` + `http://example.com` is now a reachable
       configuration and it would put the key on the wire in clear.

       THIS IS NOT THE RULE THAT WAS JUST DELETED. `SpxLlmIsLocal` claimed loopback meant the
       processing was local and nothing left the machine -- a claim about somebody else's
       software, which this cannot know. This claims only that packets to 127.0.0.1 do not
       reach a network, which is true of the IP stack whatever is listening. Address as
       transport fact: yes. Address as privacy promise: never. *)
    heInsecure,
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

(* Whether this URL may be dialled AT ALL -- the cleartext rule above, asked separately so the
   caller can refuse before it builds a request that carries a credential. `SpxHttpSend` asks it
   too, so there is one rule and no way round it. *)
function SpxHttpTransportAllowed(const AUrl: string): TSpxHttpError;

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
(* Directly under `implementation`, where FPC requires it -- a uses clause after any
   other declaration is a syntax error, which is how SpxSecrets first failed to build. *)
uses
  Windows, winhttp;
{$ENDIF}

(* Loopback in the strict sense: `localhost`, 127.0.0.0/8, and the IPv6 `::1`. Deliberately not
   exported -- the only question this file lets anyone ask is `SpxHttpTransportAllowed`, so a
   later reader cannot rebuild a privacy claim on top of it. `localhost.example.com` is somebody
   else's machine and must not match, which is why the name is compared whole. *)
function IsLoopbackHost(const AHost: string): Boolean;
var
  h: string;
  i: Integer;
begin
  h := LowerCase(AHost);
  if (h = 'localhost') or (h = '::1') or (h = '[::1]') then Exit(True);
  Result := False;
  if Copy(h, 1, 4) <> '127.' then Exit;
  for i := 5 to Length(h) do
    if not (((h[i] >= '0') and (h[i] <= '9')) or (h[i] = '.')) then Exit;
  Result := Length(h) > 4;
end;

function SpxHttpTransportAllowed(const AUrl: string): TSpxHttpError;
var
  host, path: string;
  port: Integer;
  secure: Boolean;
begin
  Result := SpxHttpParseUrl(AUrl, host, path, port, secure);
  if Result <> heNone then Exit;
  if (not secure) and (not IsLoopbackHost(host)) then Result := heInsecure;
end;

(* THE URL, IN PLAIN PASCAL AND ON EVERY PLATFORM.

   This was `WinHttpCrackUrl` and therefore Windows-only, which broke two things at once. The
   unit did not compile off Windows at all (fixed in a2a3e7a with a stub), and then the stub
   answered `heUnsupported` for everything -- which took `SpxLlmIsLocal` down with it, because
   deciding whether an endpoint is on this machine is done by looking at the HOST. CI said so
   in two named failures: `llm/localhost is local`, `llm/127.0.0.1 is local`.

   That is the argument for parsing here rather than stubbing: the host is needed to decide
   whether plain http may be used (`heInsecure`), and that decision has nothing to do with which
   transport carries the request. Written once, it is checked on all three CI legs.

   *(This paragraph used to call it "a PRIVACY question -- the policy says a local model sends
   nothing off the machine". Both halves were wrong and were removed from the policy the same
   week: an address is not a promise about the software behind it. Spec §4.5.)*

   `SpxHttpSend` already took the pieces apart for `WinHttpConnect` and `WinHttpOpenRequest`,
   so nothing downstream changes. Stricter than WinHttpCrackUrl in one place on purpose: a
   port outside 1..65535 is refused rather than wrapped. *)
function SpxHttpParseUrl(const AUrl: string; out AHost, APath: string;
  out APort: Integer; out ASecure: Boolean): TSpxHttpError;
var
  s, scheme, authority, rest: string;
  at, colon, cut, i: Integer;
begin
  AHost := ''; APath := ''; APort := 0; ASecure := False;
  s := Trim(AUrl);
  if s = '' then Exit(heBadUrl);

  cut := Pos('://', s);
  if cut < 2 then Exit(heBadUrl);
  scheme := LowerCase(Copy(s, 1, cut - 1));
  rest := Copy(s, cut + 3, MaxInt);

  (* http is PARSED here on purpose -- a model on this machine answers on plain http, and the
     parser's job is to read an address, not to judge it. Whether it may be DIALLED is
     `SpxHttpTransportAllowed`, which allows cleartext only to loopback. *)
  if scheme = 'https' then ASecure := True
  else if scheme <> 'http' then Exit(heBadUrl);

  (* The authority ends at the first delimiter of what follows it, and all three must be
     looked for: `https://host?q` has no path and `https://host#f` none either. *)
  cut := Length(rest) + 1;
  for i := 1 to Length(rest) do
    if (rest[i] = '/') or (rest[i] = '?') or (rest[i] = '#') then
    begin
      cut := i;
      Break;
    end;
  authority := Copy(rest, 1, cut - 1);
  APath := Copy(rest, cut, MaxInt);
  if APath = '' then APath := '/';

  { Credentials in the authority are the far end's business, not ours -- but they must not be
    mistaken for the host. }
  at := 0;
  for i := 1 to Length(authority) do
    if authority[i] = '@' then at := i;
  if at > 0 then authority := Copy(authority, at + 1, MaxInt);

  if (authority <> '') and (authority[1] = '[') then
  begin
    { An IPv6 literal: the colons inside the brackets are not a port separator. }
    cut := Pos(']', authority);
    if cut = 0 then Exit(heBadUrl);
    AHost := Copy(authority, 2, cut - 2);
    rest := Copy(authority, cut + 1, MaxInt);
    if (rest <> '') and (rest[1] <> ':') then Exit(heBadUrl);
    if rest <> '' then rest := Copy(rest, 2, MaxInt);
  end
  else
  begin
    colon := 0;
    for i := 1 to Length(authority) do
      if authority[i] = ':' then colon := i;
    if colon > 0 then
    begin
      AHost := Copy(authority, 1, colon - 1);
      rest := Copy(authority, colon + 1, MaxInt);
    end
    else
    begin
      AHost := authority;
      rest := '';
    end;
  end;

  if AHost = '' then Exit(heBadUrl);
  { A host is not a host if it carries a space: `not a url at all` cracks into nonsense
    otherwise, and this is the check that refuses it. }
  for i := 1 to Length(AHost) do
    if AHost[i] <= ' ' then Exit(heBadUrl);

  if rest = '' then
  begin
    if ASecure then APort := 443 else APort := 80;
  end
  else
  begin
    APort := 0;
    for i := 1 to Length(rest) do
    begin
      if (rest[i] < '0') or (rest[i] > '9') then Exit(heBadUrl);
      APort := APort * 10 + (Ord(rest[i]) - Ord('0'));
      if APort > 65535 then Exit(heBadUrl);
    end;
    if APort = 0 then Exit(heBadUrl);
  end;

  Result := heNone;
end;

{$IFDEF WINDOWS}

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

function SpxHttpSend(const ARequest: TSpxHttpRequest; const ACancel: PBoolean): TSpxHttpResult;
var
  host, path, verb, hdrs: WideString;
  hostS, pathS: string;
  port: Integer;
  secure: Boolean;
  sess, conn, req: HINTERNET;
  flags, status, statusLen, read_, avail: DWORD;
  timeout, ceiling: Integer;
  feature: DWORD;
  where: WideString;
  whereLen: DWORD;
  bodyBytes: RawByteString;
  chunk: array[0..8191] of Byte;
  got: TMemoryStream;
  i, at: Integer;
  line, name_, value: string;
begin
  Result := Default(TSpxHttpResult);
  sess := nil; conn := nil; req := nil;

  (* THE ZEROTH READ OF THE CANCEL FLAG, before anything is dialled: a Stop pressed before
     the exchange began must not put the prompt -- or the key riding the headers -- on the
     wire at all. The flag is read again between reads; without this one, a cancellation
     that landed before the call still transmitted everything and blocked through the
     timeout. Found by review. *)
  if (ACancel <> nil) and ACancel^ then
  begin
    Result.Error := heCancelled;
    Result.Detail := 'cancelled before the request was sent';
    Exit;
  end;

  timeout := ARequest.TimeoutMs;
  if timeout <= 0 then timeout := SPX_HTTP_TIMEOUT_MS;
  ceiling := ARequest.MaxBytes;
  if ceiling <= 0 then ceiling := SPX_HTTP_MAX_BYTES;

  (* ── may this be dialled at all ── *)
  Result.Error := SpxHttpTransportAllowed(ARequest.Url);
  if Result.Error <> heNone then
  begin
    Result.Detail := 'plain http is only allowed to this machine';
    Exit;
  end;

  (* ── the URL, taken apart HERE rather than by WinHTTP ───────────────────────
     `WinHttpCrackUrl` did this until 2026-08-10, and it made the parse Windows-only for no
     reason: the pieces go to WinHttpConnect and WinHttpOpenRequest separately anyway. (This
     comment used to argue the opposite and was left standing when the code changed.) *)
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

    (* NO AUTOMATIC REDIRECTS. WinHTTP's default is to follow up to ten of them and to resend
       the request headers each time -- and one of those headers carries the reader's key. That
       makes the recipient of a credential something the far end can change silently, which is
       exactly what spec §4.5 says must stay a decision a person makes. Off, and the 3xx is
       reported to the caller with the address it named. *)
    feature := WINHTTP_DISABLE_REDIRECTS;
    WinHttpSetOption(req, WINHTTP_OPTION_DISABLE_FEATURE, @feature, SizeOf(feature));

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

    (* A 3xx reaches the caller as its own answer rather than as a body to parse. The address it
       named goes with it: "the endpoint redirected to X" is something a reader can act on, and
       "provider error" over the same thing is not. *)
    if (status >= 300) and (status < 400) then
    begin
      Result.Error := heRedirected;
      SetLength(where, 2048);
      whereLen := Length(where) * SizeOf(WideChar);
      if WinHttpQueryHeaders(req, WINHTTP_QUERY_LOCATION, nil, @where[1], @whereLen, nil) then
        SetLength(where, whereLen div SizeOf(WideChar))
      else
        where := '';
      Result.Detail := 'the endpoint redirected (' + IntToStr(status) + ')';
      if where <> '' then Result.Detail := Result.Detail + ' to ' + UTF8Encode(where);
      Exit;
    end;

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

   `SpxHttpParseUrl` is NOT among them any more: it moved above the split and is plain Pascal,
   because the stub that stood here answered `heUnsupported` for every URL and took
   `SpxLlmIsLocal` -- a privacy question, not a transport one -- down with it on both
   non-Windows legs. What is left below is genuinely the transport, and only that. *)

function SpxHttpAvailable: Boolean;
begin
  Result := False;
end;

function SpxHttpClassify(ACode: LongWord): TSpxHttpError;
begin
  Result := heUnsupported;
end;

function SpxHttpSend(const ARequest: TSpxHttpRequest; const ACancel: PBoolean): TSpxHttpResult;
begin
  Result := Default(TSpxHttpResult);
  (* The same zeroth cancel read as the Windows branch, for the same answer on every leg. *)
  if (ACancel <> nil) and ACancel^ then
  begin
    Result.Error := heCancelled;
    Result.Detail := 'cancelled before the request was sent';
    Exit;
  end;
  (* A BAD URL IS STILL A BAD URL HERE. Answering `heUnsupported` to everything would make the
     platform the only thing this branch can say, and the caller's own mistakes would be
     invisible on the two CI legs that run it. *)
  Result.Error := SpxHttpTransportAllowed(ARequest.Url);
  if Result.Error <> heNone then
  begin
    Result.Detail := 'not a url this accepts';
    Exit;
  end;
  Result.Error := heUnsupported;
  Result.Detail := 'no transport on this platform';
end;

{$ENDIF}

end.
