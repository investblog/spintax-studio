(*
 * SpxLlm -- `TLlmProvider` from the spec (§4.5), with the two request formats ADR 0012 chose.
 *
 * TWO FORMATS, NOT TWO VENDORS, and the difference matters to what this covers. The Anthropic
 * Messages shape is one; the OpenAI chat-completions shape is the other, and the second is
 * spoken by OpenAI, OpenRouter, Ollama and LM Studio alike. So `http://localhost:11434/v1/...`
 * is not a special case here -- it is the same adapter pointed somewhere that never leaves the
 * machine, which is exactly the configuration the privacy policy goes out of its way to name.
 *
 * BUILD AND PARSE ARE SEPARATE FROM ASK, for the reason `SpxHttpParseUrl` is separate from
 * `SpxHttpSend`: a suite that has to open a connection to check anything is a suite that
 * reddens behind a proxy, and a red build nobody believes is worse than no check. Everything
 * decidable without a network -- what goes into the body, which header carries the key, what a
 * given answer means -- is decidable here, and that is where a caller's mistakes land.
 *
 * JSON THROUGH `fpjson`, NEVER BY HAND. The body carries the reader's own prose: quotes,
 * newlines, em dashes, whatever they typed. Hand-rolled escaping is the classic way to send a
 * request that is almost JSON, and the failure arrives as a provider error nobody can read.
 *
 * A PROVIDER'S ERROR IS NOT A TRANSPORT ERROR. `SpxHttp` answers whether the exchange happened;
 * this answers what the far end said about it. 401, 429 and a prompt too long for the model all
 * arrive as a perfectly successful HTTP exchange, and a reader told "network error" for an
 * expired key is a reader who cannot fix their problem.
 *
 * NO KEY IS EVER STORED HERE. The caller hands one in and it goes into a header; nothing keeps
 * it, so nothing here can log it. Where it lives between runs is `SpxSecrets`.
 *
 * EVERY COMMENT IS STAR-PAREN, NEVER A BRACE COMMENT -- prompts in this program are full of
 * `{a|b}`.
 *)
unit SpxLlm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SpxPrompt, SpxHttp;

type
  (* The request SHAPE, not the company. `lkOpenAiCompatible` is whatever speaks
     chat/completions, local models included. *)
  TSpxLlmKind = (lkAnthropic, lkOpenAiCompatible);

  (* HOW THIS PROFILE AUTHENTICATES -- STATED, NEVER INFERRED FROM THE ADDRESS.

     What stood here was `SpxLlmIsLocal`: an endpoint whose host was `localhost`, `127.0.0.1`
     or `::1` was allowed to go without a key, and everything else was refused. That reads the
     wrong thing twice. A local server can be configured to require a key, and a remote one can
     be open -- so the check refused requests that would have worked and let through ones that
     could not.

     It was also the load-bearing half of a bigger confusion the spec now settles in §4.5:
     `localhost` is an ADDRESS. It is not a promise that the software behind it is offline --
     a proxy, a gateway or a tunnel answers on the same port -- and it must not decide
     authentication, privacy wording, or anything else. *)
  TSpxLlmAuth = (
    laNone,          (* the endpoint takes no credential; no auth header is sent *)
    laApiKey,        (* the reader's own provider key (BYOK) *)
    laServiceToken   (* reserved: a token for a managed endpoint of ours (spec §6/§10) *)
  );

  (* What went wrong, in terms a reader can act on. The window turns these into sentences; the
     classification is here so it cannot differ between the two adapters. *)
  TSpxLlmError = (
    leNone,
    leNoKey,        (* the profile says it needs a credential and none is stored *)
    leRedirected,   (* the endpoint answered 3xx: the recipient would change, so it is refused *)
    leTransport,    (* the exchange never completed -- Detail carries SpxHttp's verdict *)
    leAuth,         (* 401 / 403: the key is wrong, expired, or not for this endpoint *)
    leRateLimit,    (* 429, or a provider that names a quota *)
    leContext,      (* the prompt is longer than the model will take *)
    leProvider,     (* the provider named something else; Detail is its own words *)
    leBadResponse,  (* the exchange succeeded and the body is not what this can read *)
    leEmpty,        (* read fine, and there was no text in it *)
    leCancelled
  );

  TSpxLlmConfig = record
    Kind: TSpxLlmKind;
    Endpoint: string;     (* the full URL; SpxLlmDefaultEndpoint gives the usual one *)
    Model: string;
    Auth: TSpxLlmAuth;    (* what this profile needs; `laNone` sends no credential *)
    ApiKey: string;       (* required when Auth <> laNone, and never guessed at from the URL *)
    MaxTokens: Integer;   (* SPX_LLM_MAX_TOKENS when zero *)
    TimeoutMs: Integer;   (* SpxHttp's default when zero *)
  end;

  TSpxLlmAnswer = record
    Error: TSpxLlmError;
    Text: string;         (* the model's reply, uncleaned -- SpxCleanModelTemplate is the caller's *)
    Status: Integer;      (* the HTTP status, 0 when the exchange never got there *)
    Detail: string;       (* what the provider or the transport said, for the log *)
  end;

const
  SPX_LLM_MAX_TOKENS = 4096;
  (* Anthropic versions its API by a dated header rather than by the URL, so this is part of the
     request and not part of the endpoint. *)
  SPX_ANTHROPIC_VERSION = '2023-06-01';

function SpxLlmDefaultEndpoint(AKind: TSpxLlmKind): string;

(* The request body, as it will be sent. Separate so the suite can read it. *)
function SpxLlmBuildBody(const ACfg: TSpxLlmConfig; const APrompt: TSpxBuiltPrompt): string;

(* `Name: value` per line, including the one that carries the key. *)
procedure SpxLlmHeaders(const ACfg: TSpxLlmConfig; AOut: TStrings);

(* What a given status and body mean. Separate for the same reason as the body. *)
function SpxLlmParse(AKind: TSpxLlmKind; AStatus: Integer; const ABody: string): TSpxLlmAnswer;

(* The whole exchange. Everything above, plus SpxHttp. *)
function SpxLlmAsk(const ACfg: TSpxLlmConfig; const APrompt: TSpxBuiltPrompt;
  const ACancel: PBoolean): TSpxLlmAnswer;

implementation

uses
  fpjson, jsonparser;

const
  LF = #10;

function SpxLlmDefaultEndpoint(AKind: TSpxLlmKind): string;
begin
  case AKind of
    lkAnthropic: Result := 'https://api.anthropic.com/v1/messages';
  else
    (* Deliberately the LOCAL one. A reader who picks "OpenAI-compatible" without typing an
       address is far likelier to mean the model already running on their machine than to mean
       a cloud they have not named -- and the wrong guess in that direction sends their text
       somewhere they did not choose. *)
    Result := 'http://localhost:11434/v1/chat/completions';
  end;
end;

function SpxLlmBuildBody(const ACfg: TSpxLlmConfig; const APrompt: TSpxBuiltPrompt): string;
var
  root, msg: TJSONObject;
  msgs: TJSONArray;
  tokens: Integer;
begin
  tokens := ACfg.MaxTokens;
  if tokens <= 0 then tokens := SPX_LLM_MAX_TOKENS;

  root := TJSONObject.Create;
  try
    root.Add('model', ACfg.Model);
    msgs := TJSONArray.Create;

    if ACfg.Kind = lkAnthropic then
    begin
      (* The system prompt is a FIELD here, not a message, and `max_tokens` is required rather
         than optional -- the two places this shape differs from the other one. *)
      root.Add('max_tokens', tokens);
      root.Add('system', APrompt.SystemPrompt);
      msg := TJSONObject.Create;
      msg.Add('role', 'user');
      msg.Add('content', APrompt.UserPrompt);
      msgs.Add(msg);
    end
    else
    begin
      root.Add('max_tokens', tokens);
      msg := TJSONObject.Create;
      msg.Add('role', 'system');
      msg.Add('content', APrompt.SystemPrompt);
      msgs.Add(msg);
      msg := TJSONObject.Create;
      msg.Add('role', 'user');
      msg.Add('content', APrompt.UserPrompt);
      msgs.Add(msg);
    end;

    root.Add('messages', msgs);
    (* Compact rather than indented: this is a wire format and the reader never sees it. *)
    Result := root.AsJSON;
  finally
    root.Free;
  end;
end;

procedure SpxLlmHeaders(const ACfg: TSpxLlmConfig; AOut: TStrings);
begin
  if AOut = nil then Exit;
  AOut.Clear;
  AOut.Add('content-type: application/json');
  if ACfg.Kind = lkAnthropic then AOut.Add('anthropic-version: ' + SPX_ANTHROPIC_VERSION);

  (* THE PROFILE DECIDES, not the presence of a string. `laNone` sends no credential even if one
     is lying about in the config, which is what a reader who switched a profile to "no
     authentication" asked for -- and a `Bearer ` with nothing after it, which is what an empty
     key used to produce, is refused by servers that would have accepted no header at all. *)
  if ACfg.Auth = laNone then Exit;
  if ACfg.ApiKey = '' then Exit;
  if ACfg.Kind = lkAnthropic then AOut.Add('x-api-key: ' + ACfg.ApiKey)
                              else AOut.Add('authorization: Bearer ' + ACfg.ApiKey);
end;

(* A STRING OUT OF A NODE THAT MAY NOT BE ONE -- and every read in this unit goes through here.

   `TJSONData.AsString` is not a conversion, it is an assertion: fpjson RAISES on an array, an
   object or a null rather than returning something empty. `TJSONObject.Get(name, default)` is
   the same function underneath, so a default of `''` protects against a MISSING key and not
   against a key of the wrong type.

   This body comes from an endpoint the reader configured, which may be a proxy, a gateway, a
   local server or a typo. `{"error": []}` raised out of `ProviderMessage`, and a `message` that
   is a string instead of an object raised `EInvalidCast` out of the choices path -- both found
   by review, both on the exact inputs. An exception here would not be a bad answer, it would be
   no answer at all: this parse runs on the network thread, where nothing is waiting to catch
   it. So a node of the wrong type reads as absent, and the shape falls through to the next
   candidate exactly as a missing key does. *)
function StrOf(AData: TJSONData): string;
begin
  Result := '';
  if AData = nil then Exit;
  (* jtNull is deliberately not here: fpjson raises on it too, and a null IS an absence. *)
  case AData.JSONType of
    jtString, jtNumber, jtBoolean: Result := AData.AsString;
  end;
end;

function StrIn(AObj: TJSONObject; const AName: string): string;
begin
  Result := '';
  if AObj <> nil then Result := StrOf(AObj.Find(AName));
end;

(* The text of an error the provider named, wherever it put it. Both shapes nest it under
   `error`, and a provider that does not is still likely to have a `message` somewhere -- so the
   fallback is the raw body, truncated, rather than silence. *)
function ProviderMessage(AObj: TJSONObject; const ARaw: string): string;
var
  err: TJSONData;
begin
  Result := '';
  if AObj <> nil then
  begin
    err := AObj.Find('error');
    if (err <> nil) and (err.JSONType = jtObject) then
    begin
      Result := StrIn(TJSONObject(err), 'message');
      if Result = '' then Result := StrIn(TJSONObject(err), 'type');
    end
    else if err <> nil then
      Result := StrOf(err);
    if Result = '' then Result := StrIn(AObj, 'message');
  end;
  if Result = '' then Result := Copy(Trim(ARaw), 1, 300);
end;

(* Which of ours a provider's own words mean. Read on the message because the status alone does
   not separate them: a context overflow and a malformed argument are both 400. *)
function KindOfProviderError(AStatus: Integer; const AMessage: string): TSpxLlmError;
var
  m: string;
begin
  m := LowerCase(AMessage);
  if (AStatus = 401) or (AStatus = 403) then Exit(leAuth);
  if AStatus = 429 then Exit(leRateLimit);
  if (Pos('context', m) > 0) or (Pos('too long', m) > 0) or
     (Pos('maximum context', m) > 0) or (Pos('token', m) > 0) and (Pos('exceed', m) > 0) then
    Exit(leContext);
  if (Pos('rate limit', m) > 0) or (Pos('quota', m) > 0) then Exit(leRateLimit);
  if (Pos('api key', m) > 0) or (Pos('authentication', m) > 0) or
     (Pos('unauthorized', m) > 0) then Exit(leAuth);
  Result := leProvider;
end;

function SpxLlmParse(AKind: TSpxLlmKind; AStatus: Integer; const ABody: string): TSpxLlmAnswer;
var
  data: TJSONData;
  root, obj: TJSONObject;
  arr: TJSONArray;
  i: Integer;
  text_, kind_: string;
  item, node: TJSONData;
begin
  Result := Default(TSpxLlmAnswer);
  Result.Status := AStatus;

  data := nil;
  try
    try
      data := GetJSON(ABody);
    except
      (* A body that is not JSON at all. Common and worth its own answer: a proxy's HTML error
         page, or an endpoint that is not a model API. Saying "provider error" over that sends
         the reader to check their key. *)
      on E: Exception do
      begin
        Result.Error := leBadResponse;
        Result.Detail := 'not JSON: ' + Copy(Trim(ABody), 1, 200);
        Exit;
      end;
    end;

    if (data = nil) or (data.JSONType <> jtObject) then
    begin
      Result.Error := leBadResponse;
      Result.Detail := 'JSON, but not an object';
      Exit;
    end;
    root := TJSONObject(data);

    (* An error can arrive on a 200 as well, which is why the status is not the only question. *)
    if (AStatus < 200) or (AStatus >= 300) or (root.Find('error') <> nil) then
    begin
      Result.Detail := ProviderMessage(root, ABody);
      Result.Error := KindOfProviderError(AStatus, Result.Detail);
      Exit;
    end;

    text_ := '';
    if AKind = lkAnthropic then
    begin
      (* `content` is an ARRAY of blocks; the text ones are joined and the rest ignored, because
         a model may return a thinking block or a tool use beside the answer. *)
      item := root.Find('content');
      if (item <> nil) and (item.JSONType = jtArray) then
      begin
        arr := TJSONArray(item);
        for i := 0 to arr.Count - 1 do
          if arr.Items[i].JSONType = jtObject then
          begin
            obj := TJSONObject(arr.Items[i]);
            kind_ := StrIn(obj, 'type');
            if (kind_ = '') or (kind_ = 'text') then text_ := text_ + StrIn(obj, 'text');
          end;
      end;
    end
    else
    begin
      item := root.Find('choices');
      if (item <> nil) and (item.JSONType = jtArray) and (TJSONArray(item).Count > 0) then
      begin
        item := TJSONArray(item).Items[0];
        if item.JSONType = jtObject then
        begin
          (* `as TJSONObject` STOOD HERE, and it is a cast rather than a question: a server that
             answers `"message": "text"` raised EInvalidCast instead of being read. Asked as a
             type test, the plain-string shape is READ instead of raising, and anything else
             falls through to the legacy one below. *)
          node := TJSONObject(item).Find('message');
          if (node <> nil) and (node.JSONType = jtObject) then
            text_ := StrIn(TJSONObject(node), 'content')
          else
            text_ := StrOf(node);
          (* Some compatible servers answer the legacy completion shape. Cheap to accept, and a
             reader who hits one otherwise gets "empty" from a server that answered. *)
          if text_ = '' then text_ := StrIn(TJSONObject(item), 'text');
        end;
      end;
    end;

    if Trim(text_) = '' then
    begin
      Result.Error := leEmpty;
      Result.Detail := 'the answer carried no text';
      Exit;
    end;

    Result.Error := leNone;
    Result.Text := text_;
  finally
    data.Free;
  end;
end;

function SpxLlmAsk(const ACfg: TSpxLlmConfig; const APrompt: TSpxBuiltPrompt;
  const ACancel: PBoolean): TSpxLlmAnswer;
var
  req: TSpxHttpRequest;
  res: TSpxHttpResult;
  hdrs: TStringList;
begin
  Result := Default(TSpxLlmAnswer);

  (* Asked BEFORE anything is dialled, because "you have not entered a key" is a better sentence
     than a 401. What it asks is the PROFILE, not the address: see TSpxLlmAuth. *)
  if (ACfg.Auth <> laNone) and (Trim(ACfg.ApiKey) = '') then
  begin
    Result.Error := leNoKey;
    Result.Detail := 'this profile authenticates, and no credential is stored for it';
    Exit;
  end;

  hdrs := TStringList.Create;
  try
    SpxLlmHeaders(ACfg, hdrs);
    req := Default(TSpxHttpRequest);
    req.Url := ACfg.Endpoint;
    req.Method := 'POST';
    req.Headers := hdrs;
    req.Body := SpxLlmBuildBody(ACfg, APrompt);
    req.TimeoutMs := ACfg.TimeoutMs;
    res := SpxHttpSend(req, ACancel);
  finally
    hdrs.Free;
  end;

  case res.Error of
    heNone: ;
    (* Not a transport failure: the endpoint answered, and what it said was "ask somebody else".
       Refused rather than followed -- spec §4.5. *)
    heRedirected:
      begin
        Result.Error := leRedirected;
        Result.Detail := res.Detail;
        Exit;
      end;
    heCancelled:
      begin
        Result.Error := leCancelled;
        Result.Detail := res.Detail;
        Exit;
      end;
  else
    (* The exchange did not happen. Keeping SpxHttp's own classification in Detail rather than
       flattening it: "no network" and "the certificate was refused" are different problems and
       the window says so. *)
    Result.Error := leTransport;
    Result.Status := res.Status;
    Result.Detail := res.Detail;
    Exit;
  end;

  Result := SpxLlmParse(ACfg.Kind, res.Status, res.Body);
end;

end.
