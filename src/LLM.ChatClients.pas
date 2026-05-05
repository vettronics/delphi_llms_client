unit LLM.ChatClients;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.URLClient,
  System.Net.HttpClient,
  LLM.Types;

type
  ELLMClientError = class(Exception);

  TCustomChatClient = class abstract
  private
    FSettings: TLLMSettings;
    FHttp: THTTPClient;
  protected
    property Settings: TLLMSettings read FSettings;
    property Http: THTTPClient read FHttp;

    function JoinUrl(const ABaseUrl, APath: string): string;
    function SendJson(const AUrl, AJson: string; const AHeaders: TNetHeaders): string;
    function MessagesToOpenAIJson(const AMessages: TChatMessageList): TJSONArray;
    function LastUserMessage(const AMessages: TChatMessageList): string;
    procedure RequireSecret(const ASecretName, ASecretValue: string);
  public
    constructor Create(const ASettings: TLLMSettings); virtual;
    destructor Destroy; override;
    function SendMessage(const AMessages: TChatMessageList): string; virtual; abstract;
  end;

  TOpenAICompatibleChatClient = class(TCustomChatClient)
  public
    function SendMessage(const AMessages: TChatMessageList): string; override;
  end;

  TGeminiChatClient = class(TCustomChatClient)
  public
    function SendMessage(const AMessages: TChatMessageList): string; override;
  end;

  TClaudeChatClient = class(TCustomChatClient)
  public
    function SendMessage(const AMessages: TChatMessageList): string; override;
  end;

  TOpenClawChatClient = class(TCustomChatClient)
  public
    function SendMessage(const AMessages: TChatMessageList): string; override;
  end;

  TChatClientFactory = class
  public
    class function CreateClient(const ASettings: TLLMSettings): TCustomChatClient; static;
  end;

implementation

function JsonString(const AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if AObject = nil then
    Exit;
  LValue := AObject.GetValue(AName);
  if LValue <> nil then
    Result := LValue.Value;
end;

function JsonObject(const AObject: TJSONObject; const AName: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  Result := nil;
  if AObject = nil then
    Exit;
  LValue := AObject.GetValue(AName);
  if LValue is TJSONObject then
    Result := TJSONObject(LValue);
end;

function JsonArray(const AObject: TJSONObject; const AName: string): TJSONArray;
var
  LValue: TJSONValue;
begin
  Result := nil;
  if AObject = nil then
    Exit;
  LValue := AObject.GetValue(AName);
  if LValue is TJSONArray then
    Result := TJSONArray(LValue);
end;

function ExtractOpenAIText(const AResponse: string): string;
var
  LRoot: TJSONValue;
  LObj, LChoice, LMessage: TJSONObject;
  LChoices: TJSONArray;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AResponse);
  try
    if not (LRoot is TJSONObject) then
      Exit;

    LObj := TJSONObject(LRoot);
    LChoices := JsonArray(LObj, 'choices');
    if (LChoices = nil) or (LChoices.Count = 0) or not (LChoices.Items[0] is TJSONObject) then
      Exit;

    LChoice := TJSONObject(LChoices.Items[0]);
    LMessage := JsonObject(LChoice, 'message');
    Result := JsonString(LMessage, 'content');
  finally
    LRoot.Free;
  end;
end;

function ExtractGeminiText(const AResponse: string): string;
var
  LRoot: TJSONValue;
  LObj, LCandidate, LContent, LPart: TJSONObject;
  LCandidates, LParts: TJSONArray;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AResponse);
  try
    if not (LRoot is TJSONObject) then
      Exit;

    LObj := TJSONObject(LRoot);
    LCandidates := JsonArray(LObj, 'candidates');
    if (LCandidates = nil) or (LCandidates.Count = 0) or not (LCandidates.Items[0] is TJSONObject) then
      Exit;

    LCandidate := TJSONObject(LCandidates.Items[0]);
    LContent := JsonObject(LCandidate, 'content');
    LParts := JsonArray(LContent, 'parts');
    if (LParts = nil) or (LParts.Count = 0) or not (LParts.Items[0] is TJSONObject) then
      Exit;

    LPart := TJSONObject(LParts.Items[0]);
    Result := JsonString(LPart, 'text');
  finally
    LRoot.Free;
  end;
end;

function ExtractClaudeText(const AResponse: string): string;
var
  LRoot: TJSONValue;
  LObj, LBlock: TJSONObject;
  LContent: TJSONArray;
  I: Integer;
  LText: string;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AResponse);
  try
    if not (LRoot is TJSONObject) then
      Exit;

    LObj := TJSONObject(LRoot);
    LContent := JsonArray(LObj, 'content');
    if LContent = nil then
      Exit;

    for I := 0 to LContent.Count - 1 do
    begin
      if not (LContent.Items[I] is TJSONObject) then
        Continue;

      LBlock := TJSONObject(LContent.Items[I]);
      if SameText(JsonString(LBlock, 'type'), 'text') then
      begin
        LText := JsonString(LBlock, 'text');
        if LText <> '' then
        begin
          if Result <> '' then
            Result := Result + sLineBreak;
          Result := Result + LText;
        end;
      end;
    end;
  finally
    LRoot.Free;
  end;
end;

function ExtractOpenClawText(const AResponse: string): string;
var
  LRoot: TJSONValue;
  LObj, LMessage: TJSONObject;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AResponse);
  try
    if not (LRoot is TJSONObject) then
    begin
      Result := AResponse;
      Exit;
    end;

    LObj := TJSONObject(LRoot);
    Result := JsonString(LObj, 'answer');
    if Result = '' then
      Result := JsonString(LObj, 'response');
    if Result = '' then
      Result := JsonString(LObj, 'content');
    if Result = '' then
    begin
      LMessage := JsonObject(LObj, 'message');
      Result := JsonString(LMessage, 'content');
    end;
    if Result = '' then
      Result := AResponse;
  finally
    LRoot.Free;
  end;
end;

{ TCustomChatClient }

constructor TCustomChatClient.Create(const ASettings: TLLMSettings);
begin
  inherited Create;
  FSettings := ASettings;
  FHttp := THTTPClient.Create;
  FHttp.ConnectionTimeout := Settings.TimeoutSeconds * 1000;
  FHttp.ResponseTimeout := Settings.TimeoutSeconds * 1000;
end;

destructor TCustomChatClient.Destroy;
begin
  FHttp.Free;
  inherited;
end;

function TCustomChatClient.JoinUrl(const ABaseUrl, APath: string): string;
begin
  Result := ABaseUrl.Trim;
  while Result.EndsWith('/') do
    Delete(Result, Result.Length, 1);

  if APath.Trim = '' then
    Exit;

  if APath.StartsWith('/') then
    Result := Result + APath
  else
    Result := Result + '/' + APath;
end;

function TCustomChatClient.SendJson(const AUrl, AJson: string; const AHeaders: TNetHeaders): string;
var
  LStream: TStringStream;
  LResponse: IHTTPResponse;
begin
  LStream := TStringStream.Create(AJson, TEncoding.UTF8);
  try
    LResponse := Http.Post(AUrl, LStream, nil, AHeaders);
    Result := LResponse.ContentAsString(TEncoding.UTF8);

    if (LResponse.StatusCode < 200) or (LResponse.StatusCode >= 300) then
      raise ELLMClientError.CreateFmt('Erro HTTP %d: %s', [LResponse.StatusCode, Result]);
  finally
    LStream.Free;
  end;
end;

function TCustomChatClient.MessagesToOpenAIJson(const AMessages: TChatMessageList): TJSONArray;
var
  LMessage: TChatMessage;
  LObj: TJSONObject;
begin
  Result := TJSONArray.Create;
  for LMessage in AMessages do
  begin
    LObj := TJSONObject.Create;
    LObj.AddPair('role', LMessage.Role);
    LObj.AddPair('content', LMessage.Content);
    Result.AddElement(LObj);
  end;
end;

function TCustomChatClient.LastUserMessage(const AMessages: TChatMessageList): string;
var
  I: Integer;
begin
  Result := '';
  for I := AMessages.Count - 1 downto 0 do
  begin
    if SameText(AMessages[I].Role, 'user') then
      Exit(AMessages[I].Content);
  end;
end;

procedure TCustomChatClient.RequireSecret(const ASecretName, ASecretValue: string);
begin
  if ASecretValue.Trim = '' then
    raise ELLMClientError.CreateFmt('%s em falta.', [ASecretName]);
end;

{ TOpenAICompatibleChatClient }

function TOpenAICompatibleChatClient.SendMessage(const AMessages: TChatMessageList): string;
var
  LBody: TJSONObject;
  LMessages: TJSONArray;
  LResponse: string;
  LUrl: string;
  LHeaders: TNetHeaders;
begin
  RequireSecret('API key', Settings.ApiKey);

  LMessages := MessagesToOpenAIJson(AMessages);
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('model', Settings.Model);
    LBody.AddPair('messages', LMessages);
    LBody.AddPair('temperature', TJSONNumber.Create(0.2));

    LUrl := JoinUrl(Settings.BaseUrl, '/chat/completions');
    LHeaders := [
      TNameValuePair.Create('Content-Type', 'application/json'),
      TNameValuePair.Create('Authorization', 'Bearer ' + Settings.ApiKey),
      TNameValuePair.Create('HTTP-Referer', 'https://github.com/vettronics/delphi_llms_client'),
      TNameValuePair.Create('X-Title', 'Delphi LLMs Client')
    ];

    LResponse := SendJson(LUrl, LBody.ToJSON, LHeaders);
    Result := ExtractOpenAIText(LResponse);
    if Result.Trim = '' then
      Result := LResponse;
  finally
    LBody.Free;
  end;
end;

{ TGeminiChatClient }

function TGeminiChatClient.SendMessage(const AMessages: TChatMessageList): string;
var
  LBody, LContent, LPart: TJSONObject;
  LContents, LParts: TJSONArray;
  LMessage: TChatMessage;
  LRole: string;
  LResponse: string;
  LUrl: string;
  LHeaders: TNetHeaders;
begin
  RequireSecret('API key', Settings.ApiKey);

  LBody := TJSONObject.Create;
  LContents := TJSONArray.Create;
  try
    for LMessage in AMessages do
    begin
      if SameText(LMessage.Role, 'assistant') then
        LRole := 'model'
      else
        LRole := 'user';

      LContent := TJSONObject.Create;
      LParts := TJSONArray.Create;
      LPart := TJSONObject.Create;
      LPart.AddPair('text', LMessage.Content);
      LParts.AddElement(LPart);
      LContent.AddPair('role', LRole);
      LContent.AddPair('parts', LParts);
      LContents.AddElement(LContent);
    end;

    LBody.AddPair('contents', LContents);
    LUrl := JoinUrl(Settings.BaseUrl, Format('/models/%s:generateContent?key=%s', [Settings.Model, Settings.ApiKey]));
    LHeaders := [TNameValuePair.Create('Content-Type', 'application/json')];

    LResponse := SendJson(LUrl, LBody.ToJSON, LHeaders);
    Result := ExtractGeminiText(LResponse);
    if Result.Trim = '' then
      Result := LResponse;
  finally
    LBody.Free;
  end;
end;

{ TClaudeChatClient }

function TClaudeChatClient.SendMessage(const AMessages: TChatMessageList): string;
var
  LBody: TJSONObject;
  LMessages: TJSONArray;
  LResponse: string;
  LUrl: string;
  LHeaders: TNetHeaders;
begin
  RequireSecret('API key', Settings.ApiKey);

  LMessages := MessagesToOpenAIJson(AMessages);
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('model', Settings.Model);
    LBody.AddPair('max_tokens', TJSONNumber.Create(4096));
    LBody.AddPair('messages', LMessages);

    LUrl := JoinUrl(Settings.BaseUrl, '/messages');
    LHeaders := [
      TNameValuePair.Create('Content-Type', 'application/json'),
      TNameValuePair.Create('x-api-key', Settings.ApiKey),
      TNameValuePair.Create('anthropic-version', '2023-06-01')
    ];

    LResponse := SendJson(LUrl, LBody.ToJSON, LHeaders);
    Result := ExtractClaudeText(LResponse);
    if Result.Trim = '' then
      Result := LResponse;
  finally
    LBody.Free;
  end;
end;

{ TOpenClawChatClient }

function TOpenClawChatClient.SendMessage(const AMessages: TChatMessageList): string;
var
  LBody: TJSONObject;
  LMessages: TJSONArray;
  LResponse: string;
  LUrl: string;
  LHeaders: TNetHeaders;
begin
  RequireSecret('OpenClaw token', Settings.OpenClawToken);

  LMessages := MessagesToOpenAIJson(AMessages);
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('agent', Settings.Model);
    LBody.AddPair('model', Settings.Model);
    LBody.AddPair('prompt', LastUserMessage(AMessages));
    LBody.AddPair('messages', LMessages);

    LUrl := JoinUrl(Settings.BaseUrl, Settings.OpenClawEndpoint);
    LHeaders := [
      TNameValuePair.Create('Content-Type', 'application/json'),
      TNameValuePair.Create('Authorization', 'Bearer ' + Settings.OpenClawToken),
      TNameValuePair.Create('X-OpenClaw-Token', Settings.OpenClawToken)
    ];

    LResponse := SendJson(LUrl, LBody.ToJSON, LHeaders);
    Result := ExtractOpenClawText(LResponse);
  finally
    LBody.Free;
  end;
end;

{ TChatClientFactory }

class function TChatClientFactory.CreateClient(const ASettings: TLLMSettings): TCustomChatClient;
begin
  case ASettings.Provider of
    lpGemini:
      Result := TGeminiChatClient.Create(ASettings);
    lpClaude:
      Result := TClaudeChatClient.Create(ASettings);
    lpOpenClaw:
      Result := TOpenClawChatClient.Create(ASettings);
  else
    Result := TOpenAICompatibleChatClient.Create(ASettings);
  end;
end;

end.
