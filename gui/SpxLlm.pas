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

  (* What went wrong, in terms a reader can act on. The window turns these into sentences; the
     classification is here so it cannot differ between the two adapters. *)
  TSpxLlmError = (
    leNone,
    leNoKey,        (* nothing to authenticate with, and the endpoint is not a local one *)
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
    ApiKey: string;       (* may be empty for a local endpoint *)
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

(* An endpoint on this machine, where an empty key is normal and nothing leaves. *)
function SpxLlmIsLocal(const AUrl: string): Boolean;

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

function SpxLlmIsLocal(const AUrl: string): Boolean;
var
  host, path: string;
  port: Integer;
  secure: Boolean;
begin
  Result := False;
  if SpxHttpParseUrl(AUrl, host, path, port, secure) <> heNone then Exit;
  host := LowerCase(host);
  (* The loopback names, and nothing clever. A host that merely RESOLVES to a loopback address
     is not decidable without asking the resolver, and this is asked before anything is dialled;
     being narrow here can only cost a reader an unnecessary "no key" message, while being wide
     could call a "no key needed" endpoint that is not on their machine at all. *)
  Result := (host = 'localhost') or (host = '127.0.0.1') or (host = '::1') or (host = '[::1]');
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
  if ACfg.Kind = lkAnthropic then
  begin
    AOut.Add('anthropic-version: ' + SPX_ANTHROPIC_VERSION);
    if ACfg.ApiKey <> '' then AOut.Add('x-api-key: ' + ACfg.ApiKey);
  end
  else
    (* An empty key sends NO header at all rather than `Bearer ` with nothing after it: a local
       model refuses the second and accepts the absence. *)
    if ACfg.ApiKey <> '' then AOut.Add('authorization: Bearer ' + ACfg.ApiKey);
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
      Result := TJSONObject(err).Get('message', '');
      if Result = '' then Result := TJSONObject(err).Get('type', '');
    end
    else if err <> nil then
      Result := err.AsString;
    if Result = '' then Result := AObj.Get('message', '');
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
  item: TJSONData;
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
            kind_ := obj.Get('type', '');
            if (kind_ = '') or (kind_ = 'text') then text_ := text_ + obj.Get('text', '');
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
          obj := TJSONObject(item).Find('message') as TJSONObject;
          if obj <> nil then text_ := obj.Get('content', '');
          (* Some compatible servers answer the legacy completion shape. Cheap to accept, and a
             reader who hits one otherwise gets "empty" from a server that answered. *)
          if text_ = '' then text_ := TJSONObject(item).Get('text', '');
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
     than a 401 -- and a local endpoint legitimately needs none. *)
  if (Trim(ACfg.ApiKey) = '') and (not SpxLlmIsLocal(ACfg.Endpoint)) then
  begin
    Result.Error := leNoKey;
    Result.Detail := 'no key, and the endpoint is not on this machine';
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
