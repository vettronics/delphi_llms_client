unit OpenClawClient;

{
  OpenClawClient.pas
  Unidade Delphi 12 autónoma para integrar um projecto existente com o gateway OpenClaw.

  Objectivo:
  - Permitir chamar agentes OpenClaw como mais um fornecedor LLM, ao lado de OpenAI, Gemini e Claude.
  - Não depende de VCL.
  - Usa apenas RTL + System.Net.HttpClient + System.JSON.
  - Compatível com projecto VCL, FMX, serviço Windows ou consola.

  Endpoints usados, por ordem:
  1) POST /v1/chat/completions
  2) POST /v1/responses
  3) POST /tools/invoke, tool sessions_send, como fallback legado

  Exemplo simples:

    uses OpenClawClient;

    var
      Reply, Err: string;
      Ok: Boolean;
    begin
      Ok := ConsumeOpenClawAPI(
        'http://192.168.93.35:18789',
        'TOKEN_DO_GATEWAY',
        'openclaw/codigo',
        'DelphiClient-codigo',
        'Analisa este código Delphi...',
        Reply,
        Err
      );

      if Ok then
        ShowMessage(Reply)
      else
        ShowMessage(Err);
    end;

  Exemplo com classe:

    var
      Settings: TOpenClawSettings;
      Client: TOpenClawClient;
      Reply, Err: string;
    begin
      Settings := TOpenClawSettings.Default;
      Settings.BaseUrl := 'http://192.168.93.35:18789';
      Settings.BearerToken := 'TOKEN_DO_GATEWAY';
      Settings.Model := 'openclaw/oftalvet';
      Settings.SessionKey := 'DelphiClient-oftalvet';

      Client := TOpenClawClient.Create(Settings);
      try
        if Client.SendText('Mensagem clínica...', Reply, Err) then
          ShowMessage(Reply)
        else
          ShowMessage(Err);
      finally
        Client.Free;
      end;
    end;
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Diagnostics,
  System.Net.HttpClient,
  System.Net.URLClient;

type
  EOpenClawClientError = class(Exception);

  TOpenClawEndpoint = (
    oceNone,
    oceChatCompletions,
    oceResponses,
    oceToolsInvoke
  );

  TOpenClawSettings = record
    BaseUrl: string;
    BearerToken: string;
    Model: string;
    SessionKey: string;
    TimeoutSeconds: Integer;
    ConnectionTimeoutMs: Integer;
    MessageChannel: string;
    RequireBearerToken: Boolean;

    class function Default: TOpenClawSettings; static;
  end;

  TOpenClawResult = record
    Ok: Boolean;
    Reply: string;
    Error: string;
    Endpoint: TOpenClawEndpoint;
    EndpointPath: string;
    StatusCode: Integer;
    StatusText: string;
    DurationMs: Int64;
    RawResponse: string;
  end;

  TOpenClawClient = class
  private
    FHttp: THTTPClient;
    FSettings: TOpenClawSettings;
    FLastResult: TOpenClawResult;

    function BuildUrl(const APath: string): string;
    function NormalizedSessionKey: string;
    function NormalizedModel: string;

    function EndpointToPath(const AEndpoint: TOpenClawEndpoint): string;
    function IsMissingEndpoint(const AStatusCode: Integer): Boolean;

    function PostJson(const AEndpoint: TOpenClawEndpoint; const ABody: TJSONObject;
      out AStatusCode: Integer; out AStatusText, AResponseText, APostError: string;
      out ADurationMs: Int64): Boolean;

    function ExtractBestText(const AValue: TJSONValue): string;
    function ExtractReplyText(const ARoot: TJSONValue): string;
    function ExtractJsonErrorText(const AResponseText: string): string;
    function BuildHttpError(const AStatusCode: Integer; const AStatusText, AResponseText: string): string;
    function TryParseReply(const AResponseText: string; out AReply, AError: string): Boolean;

    function BuildChatCompletionsBody(const AMessage: string): TJSONObject;
    function BuildResponsesBody(const AMessage: string): TJSONObject;
    function BuildToolsInvokeBody(const AMessage: string; const ATimeoutSeconds: Integer): TJSONObject;

    procedure ResetLastResult;
    procedure SaveLastResult(const AEndpoint: TOpenClawEndpoint; const AStatusCode: Integer;
      const AStatusText, AResponseText: string; const ADurationMs: Int64);
  public
    constructor Create(const ASettings: TOpenClawSettings); overload;
    constructor Create(const ABaseUrl, ABearerToken, AModel, ASessionKey: string;
      ATimeoutSeconds: Integer = 120); overload;
    destructor Destroy; override;

    function SendText(const AMessage: string; out AReply, AError: string): Boolean;
    function SendTextEx(const AMessage: string): TOpenClawResult;

    property Settings: TOpenClawSettings read FSettings write FSettings;
    property LastResult: TOpenClawResult read FLastResult;
  end;

function ConsumeOpenClawAPI(const ABaseUrl, ABearerToken, AModel, ASessionKey, AMessages: string;
  out AReply, AError: string; ATimeoutSeconds: Integer = 120): Boolean;

function OpenClawEndpointToString(const AEndpoint: TOpenClawEndpoint): string;

implementation

class function TOpenClawSettings.Default: TOpenClawSettings;
begin
  Result.BaseUrl := 'http://192.168.93.35:18789';
  Result.BearerToken := '';
  Result.Model := 'openclaw/codigo';
  Result.SessionKey := 'DelphiClient-codigo';
  Result.TimeoutSeconds := 120;
  Result.ConnectionTimeoutMs := 5000;
  Result.MessageChannel := 'delphi-client';
  Result.RequireBearerToken := True;
end;

function OpenClawEndpointToString(const AEndpoint: TOpenClawEndpoint): string;
begin
  case AEndpoint of
    oceChatCompletions: Result := '/v1/chat/completions';
    oceResponses:       Result := '/v1/responses';
    oceToolsInvoke:     Result := '/tools/invoke';
  else
    Result := '';
  end;
end;

constructor TOpenClawClient.Create(const ASettings: TOpenClawSettings);
begin
  inherited Create;

  FSettings := ASettings;
  if FSettings.Model.Trim = '' then
    FSettings.Model := 'openclaw/codigo';
  if FSettings.SessionKey.Trim = '' then
    FSettings.SessionKey := 'DelphiClient-codigo';
  if FSettings.TimeoutSeconds <= 0 then
    FSettings.TimeoutSeconds := 120;
  if FSettings.ConnectionTimeoutMs <= 0 then
    FSettings.ConnectionTimeoutMs := 5000;
  if FSettings.MessageChannel.Trim = '' then
    FSettings.MessageChannel := 'delphi-client';

  FHttp := THTTPClient.Create;
  FHttp.ConnectionTimeout := FSettings.ConnectionTimeoutMs;
  FHttp.ResponseTimeout := FSettings.TimeoutSeconds * 1000;

  ResetLastResult;
end;

constructor TOpenClawClient.Create(const ABaseUrl, ABearerToken, AModel, ASessionKey: string;
  ATimeoutSeconds: Integer);
var
  S: TOpenClawSettings;
begin
  S := TOpenClawSettings.Default;
  S.BaseUrl := ABaseUrl;
  S.BearerToken := ABearerToken;
  S.Model := AModel;
  S.SessionKey := ASessionKey;
  S.TimeoutSeconds := ATimeoutSeconds;
  Create(S);
end;

destructor TOpenClawClient.Destroy;
begin
  FHttp.Free;
  inherited;
end;

procedure TOpenClawClient.ResetLastResult;
begin
  FLastResult.Ok := False;
  FLastResult.Reply := '';
  FLastResult.Error := '';
  FLastResult.Endpoint := oceNone;
  FLastResult.EndpointPath := '';
  FLastResult.StatusCode := 0;
  FLastResult.StatusText := '';
  FLastResult.DurationMs := 0;
  FLastResult.RawResponse := '';
end;

procedure TOpenClawClient.SaveLastResult(const AEndpoint: TOpenClawEndpoint; const AStatusCode: Integer;
  const AStatusText, AResponseText: string; const ADurationMs: Int64);
begin
  FLastResult.Endpoint := AEndpoint;
  FLastResult.EndpointPath := EndpointToPath(AEndpoint);
  FLastResult.StatusCode := AStatusCode;
  FLastResult.StatusText := AStatusText;
  FLastResult.RawResponse := AResponseText;
  FLastResult.DurationMs := ADurationMs;
end;

function TOpenClawClient.BuildUrl(const APath: string): string;
begin
  Result := Trim(FSettings.BaseUrl);
  while (Result <> '') and (Result[Length(Result)] = '/') do
    Delete(Result, Length(Result), 1);

  Result := Result + APath;
end;

function TOpenClawClient.NormalizedSessionKey: string;
begin
  Result := Trim(FSettings.SessionKey);
  if Result = '' then
    Result := 'DelphiClient-codigo';
end;

function TOpenClawClient.NormalizedModel: string;
begin
  Result := Trim(FSettings.Model);
  if Result = '' then
    Result := 'openclaw/codigo';
end;

function TOpenClawClient.EndpointToPath(const AEndpoint: TOpenClawEndpoint): string;
begin
  Result := OpenClawEndpointToString(AEndpoint);
end;

function TOpenClawClient.IsMissingEndpoint(const AStatusCode: Integer): Boolean;
begin
  Result := (AStatusCode = 404) or (AStatusCode = 405);
end;

function TOpenClawClient.PostJson(const AEndpoint: TOpenClawEndpoint; const ABody: TJSONObject;
  out AStatusCode: Integer; out AStatusText, AResponseText, APostError: string;
  out ADurationMs: Int64): Boolean;
var
  Body: TStringStream;
  Resp: IHTTPResponse;
  Stopwatch: TStopwatch;
  Path: string;
begin
  Result := False;
  AStatusCode := 0;
  AStatusText := '';
  AResponseText := '';
  APostError := '';
  ADurationMs := 0;

  Path := EndpointToPath(AEndpoint);
  if Path = '' then
  begin
    APostError := 'Endpoint OpenClaw inválido.';
    Exit(False);
  end;

  Body := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
  try
    try
      Stopwatch := TStopwatch.StartNew;

      FHttp.CustomHeaders['Accept'] := 'application/json';
      FHttp.CustomHeaders['x-openclaw-session-key'] := NormalizedSessionKey;
      FHttp.CustomHeaders['x-openclaw-message-channel'] := FSettings.MessageChannel;

      if Trim(FSettings.BearerToken) <> '' then
        FHttp.CustomHeaders['Authorization'] := 'Bearer ' + Trim(FSettings.BearerToken)
      else
        FHttp.CustomHeaders['Authorization'] := '';

      Resp := FHttp.Post(
        BuildUrl(Path),
        Body,
        nil,
        [TNameValuePair.Create('Content-Type', 'application/json')]
      );

      Stopwatch.Stop;

      AStatusCode := Resp.StatusCode;
      AStatusText := Resp.StatusText;
      AResponseText := Resp.ContentAsString(TEncoding.UTF8);
      ADurationMs := Stopwatch.ElapsedMilliseconds;

      SaveLastResult(AEndpoint, AStatusCode, AStatusText, AResponseText, ADurationMs);

      Result := (AStatusCode >= 200) and (AStatusCode <= 299);
    except
      on E: Exception do
      begin
        try
          Stopwatch.Stop;
          ADurationMs := Stopwatch.ElapsedMilliseconds;
        except
          ADurationMs := 0;
        end;

        APostError := E.Message;
        SaveLastResult(AEndpoint, AStatusCode, AStatusText, AResponseText, ADurationMs);
      end;
    end;
  finally
    Body.Free;
  end;
end;

function TOpenClawClient.ExtractBestText(const AValue: TJSONValue): string;
const
  KEYS: array[0..16] of string = (
    'text',
    'message',
    'output_text',
    'output',
    'content',
    'final',
    'response',
    'result',
    'resultText',
    'summary',
    'value',
    'reply',
    'answer',
    'data',
    'body',
    'textContent',
    'display'
  );
var
  Obj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Candidate: TJSONValue;
begin
  Result := '';
  if AValue = nil then
    Exit;

  if AValue is TJSONString then
    Exit(TJSONString(AValue).Value);

  if AValue is TJSONNumber then
    Exit(AValue.Value);

  if AValue is TJSONBool then
    Exit(AValue.Value);

  if AValue is TJSONArray then
  begin
    Arr := TJSONArray(AValue);
    for I := 0 to Arr.Count - 1 do
    begin
      Result := ExtractBestText(Arr.Items[I]);
      if Result <> '' then
        Exit;
    end;
    Exit;
  end;

  if AValue is TJSONObject then
  begin
    Obj := TJSONObject(AValue);

    for I := Low(KEYS) to High(KEYS) do
    begin
      Candidate := Obj.FindValue(KEYS[I]);
      Result := ExtractBestText(Candidate);
      if Result <> '' then
        Exit;
    end;

    for I := 0 to Obj.Count - 1 do
    begin
      Candidate := Obj.Pairs[I].JsonValue;
      Result := ExtractBestText(Candidate);
      if Result <> '' then
        Exit;
    end;
  end;
end;

function TOpenClawClient.ExtractReplyText(const ARoot: TJSONValue): string;
var
  Obj: TJSONObject;
  Choices: TJSONValue;
  Output: TJSONValue;
begin
  Result := '';
  if ARoot = nil then
    Exit;

  if not (ARoot is TJSONObject) then
    Exit(ExtractBestText(ARoot));

  Obj := TJSONObject(ARoot);

  { OpenAI-compatible /v1/chat/completions }
  Choices := Obj.FindValue('choices');
  Result := ExtractBestText(Choices);
  if Result <> '' then
    Exit;

  { OpenAI-compatible /v1/responses }
  Output := Obj.FindValue('output_text');
  Result := ExtractBestText(Output);
  if Result <> '' then
    Exit;

  Output := Obj.FindValue('output');
  Result := ExtractBestText(Output);
  if Result <> '' then
    Exit;

  { Fallbacks genéricos usados por /tools/invoke e wrappers diversos }
  Result := ExtractBestText(Obj.FindValue('result'));
  if Result <> '' then
    Exit;

  Result := ExtractBestText(Obj.FindValue('message'));
  if Result <> '' then
    Exit;

  Result := ExtractBestText(Obj.FindValue('content'));
  if Result <> '' then
    Exit;

  Result := ExtractBestText(Obj.FindValue('response'));
  if Result <> '' then
    Exit;

  Result := ExtractBestText(Obj);
end;

function TOpenClawClient.ExtractJsonErrorText(const AResponseText: string): string;
var
  Root: TJSONValue;
begin
  Result := '';
  Root := TJSONObject.ParseJSONValue(AResponseText);
  try
    if Root is TJSONObject then
    begin
      Result := ExtractBestText(TJSONObject(Root).FindValue('error'));
      if Result = '' then
        Result := ExtractBestText(TJSONObject(Root).FindValue('errors'));
      if Result = '' then
        Result := ExtractBestText(TJSONObject(Root).FindValue('message'));
    end;
  finally
    Root.Free;
  end;
end;

function TOpenClawClient.BuildHttpError(const AStatusCode: Integer; const AStatusText, AResponseText: string): string;
var
  JsonError: string;
begin
  JsonError := ExtractJsonErrorText(AResponseText);

  if JsonError <> '' then
    Exit(Format('HTTP %d: %s | %s', [AStatusCode, AStatusText, JsonError]));

  if Trim(AResponseText) <> '' then
    Exit(Format('HTTP %d: %s | %s', [AStatusCode, AStatusText, AResponseText]));

  Result := Format('HTTP %d: %s', [AStatusCode, AStatusText]);
end;

function TOpenClawClient.TryParseReply(const AResponseText: string; out AReply, AError: string): Boolean;
var
  Root: TJSONValue;
begin
  Result := False;
  AReply := '';
  AError := '';

  Root := TJSONObject.ParseJSONValue(AResponseText);
  try
    if Root = nil then
    begin
      AError := 'Resposta JSON inválida do OpenClaw.';
      Exit(False);
    end;

    AReply := ExtractReplyText(Root);
    if AReply = '' then
      AReply := '(sem texto na resposta)';

    Result := True;
  finally
    Root.Free;
  end;
end;

function TOpenClawClient.BuildChatCompletionsBody(const AMessage: string): TJSONObject;
var
  Messages: TJSONArray;
  MsgObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('model', NormalizedModel);
    Result.AddPair('user', NormalizedSessionKey);

    Messages := TJSONArray.Create;
    MsgObj := TJSONObject.Create;
    MsgObj.AddPair('role', 'user');
    MsgObj.AddPair('content', AMessage);
    Messages.AddElement(MsgObj);

    Result.AddPair('messages', Messages);
    Result.AddPair('stream', TJSONBool.Create(False));
  except
    Result.Free;
    raise;
  end;
end;

function TOpenClawClient.BuildResponsesBody(const AMessage: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('model', NormalizedModel);
    Result.AddPair('user', NormalizedSessionKey);
    Result.AddPair('input', AMessage);
  except
    Result.Free;
    raise;
  end;
end;

function TOpenClawClient.BuildToolsInvokeBody(const AMessage: string; const ATimeoutSeconds: Integer): TJSONObject;
var
  Args: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('tool', 'sessions_send');

    Args := TJSONObject.Create;
    Args.AddPair('sessionKey', NormalizedSessionKey);
    Args.AddPair('message', AMessage);
    Args.AddPair('timeoutSeconds', TJSONNumber.Create(ATimeoutSeconds));

    Result.AddPair('args', Args);
  except
    Result.Free;
    raise;
  end;
end;

function TOpenClawClient.SendText(const AMessage: string; out AReply, AError: string): Boolean;
var
  R: TOpenClawResult;
begin
  R := SendTextEx(AMessage);
  AReply := R.Reply;
  AError := R.Error;
  Result := R.Ok;
end;

function TOpenClawClient.SendTextEx(const AMessage: string): TOpenClawResult;
var
  Body: TJSONObject;
  StatusCode: Integer;
  StatusText: string;
  RespText: string;
  PostError: string;
  DurationMs: Int64;

  function TryEndpoint(const AEndpoint: TOpenClawEndpoint; ABody: TJSONObject): Boolean;
  begin
    Result := PostJson(AEndpoint, ABody, StatusCode, StatusText, RespText, PostError, DurationMs);
  end;

begin
  ResetLastResult;

  Result.Ok := False;
  Result.Reply := '';
  Result.Error := '';
  Result.Endpoint := oceNone;
  Result.EndpointPath := '';
  Result.StatusCode := 0;
  Result.StatusText := '';
  Result.DurationMs := 0;
  Result.RawResponse := '';

  if Trim(FSettings.BaseUrl) = '' then
  begin
    Result.Error := 'Base URL OpenClaw vazia.';
    FLastResult := Result;
    Exit;
  end;

  if FSettings.RequireBearerToken and (Trim(FSettings.BearerToken) = '') then
  begin
    Result.Error := 'Bearer token OpenClaw vazio.';
    FLastResult := Result;
    Exit;
  end;

  if Trim(AMessage) = '' then
  begin
    Result.Error := 'Mensagem vazia.';
    FLastResult := Result;
    Exit;
  end;

  { 1) /v1/chat/completions }
  Body := BuildChatCompletionsBody(AMessage);
  try
    if TryEndpoint(oceChatCompletions, Body) then
    begin
      Result := FLastResult;
      Result.Ok := TryParseReply(RespText, Result.Reply, Result.Error);
      FLastResult := Result;
      Exit;
    end;
  finally
    Body.Free;
  end;

  if PostError <> '' then
  begin
    Result := FLastResult;
    Result.Error := PostError;
    FLastResult := Result;
    Exit;
  end;

  if not IsMissingEndpoint(StatusCode) then
  begin
    Result := FLastResult;
    Result.Error := BuildHttpError(StatusCode, StatusText, RespText);
    FLastResult := Result;
    Exit;
  end;

  { 2) /v1/responses }
  Body := BuildResponsesBody(AMessage);
  try
    if TryEndpoint(oceResponses, Body) then
    begin
      Result := FLastResult;
      Result.Ok := TryParseReply(RespText, Result.Reply, Result.Error);
      FLastResult := Result;
      Exit;
    end;
  finally
    Body.Free;
  end;

  if PostError <> '' then
  begin
    Result := FLastResult;
    Result.Error := PostError;
    FLastResult := Result;
    Exit;
  end;

  if not IsMissingEndpoint(StatusCode) then
  begin
    Result := FLastResult;
    Result.Error := BuildHttpError(StatusCode, StatusText, RespText);
    FLastResult := Result;
    Exit;
  end;

  { 3) /tools/invoke sessions_send }
  Body := BuildToolsInvokeBody(AMessage, FSettings.TimeoutSeconds);
  try
    if TryEndpoint(oceToolsInvoke, Body) then
    begin
      Result := FLastResult;
      Result.Ok := TryParseReply(RespText, Result.Reply, Result.Error);
      FLastResult := Result;
      Exit;
    end;
  finally
    Body.Free;
  end;

  Result := FLastResult;

  if PostError <> '' then
    Result.Error := PostError
  else
    Result.Error := BuildHttpError(StatusCode, StatusText, RespText);

  FLastResult := Result;
end;

function ConsumeOpenClawAPI(const ABaseUrl, ABearerToken, AModel, ASessionKey, AMessages: string;
  out AReply, AError: string; ATimeoutSeconds: Integer): Boolean;
var
  Client: TOpenClawClient;
begin
  Client := TOpenClawClient.Create(ABaseUrl, ABearerToken, AModel, ASessionKey, ATimeoutSeconds);
  try
    Result := Client.SendText(AMessages, AReply, AError);
  finally
    Client.Free;
  end;
end;

end.
