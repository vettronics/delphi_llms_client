unit LLM.Types;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TLLMProvider = (lpOpenAI, lpGemini, lpClaude, lpGrok, lpOpenRouter, lpOpenClaw);

  TChatMessage = record
    Role: string;
    Content: string;
    class function Create(const ARole, AContent: string): TChatMessage; static;
  end;

  TChatMessageList = TList<TChatMessage>;

  TLLMSettings = record
    Provider: TLLMProvider;
    Model: string;
    ApiKey: string;
    OpenAIApiKey: string;
    GeminiApiKey: string;
    ClaudeApiKey: string;
    GrokApiKey: string;
    OpenRouterApiKey: string;
    BaseUrl: string;
    OpenAIBaseUrl: string;
    GeminiBaseUrl: string;
    ClaudeBaseUrl: string;
    GrokBaseUrl: string;
    OpenRouterBaseUrl: string;
    OpenClawBaseUrl: string;
    OpenClawToken: string;
    OpenClawEndpoint: string;
    KeepLocalContext: Boolean;
    TimeoutSeconds: Integer;
  end;

function ProviderToString(const AProvider: TLLMProvider): string;
function StringToProvider(const AValue: string): TLLMProvider;
function DefaultBaseUrl(const AProvider: TLLMProvider): string;
function DefaultModel(const AProvider: TLLMProvider): string;
function ProviderUsesToken(const AProvider: TLLMProvider): Boolean;
function DefaultOpenClawSessionKey: string;
function ApiKeyForProvider(const ASettings: TLLMSettings): string;
procedure SetApiKeyForProvider(var ASettings: TLLMSettings; const AApiKey: string);
function BaseUrlForProvider(const ASettings: TLLMSettings): string;
procedure SetBaseUrlForProvider(var ASettings: TLLMSettings; const ABaseUrl: string);

implementation

class function TChatMessage.Create(const ARole, AContent: string): TChatMessage;
begin
  Result.Role := ARole;
  Result.Content := AContent;
end;

function ProviderToString(const AProvider: TLLMProvider): string;
begin
  case AProvider of
    lpOpenAI: Result := 'OpenAI';
    lpGemini: Result := 'Gemini';
    lpClaude: Result := 'Claude';
    lpGrok: Result := 'Grok';
    lpOpenRouter: Result := 'OpenRouter';
    lpOpenClaw: Result := 'OpenClaw';
  else
    Result := 'OpenAI';
  end;
end;

function StringToProvider(const AValue: string): TLLMProvider;
begin
  if SameText(AValue, 'Gemini') then
    Exit(lpGemini);
  if SameText(AValue, 'Claude') then
    Exit(lpClaude);
  if SameText(AValue, 'Grok') then
    Exit(lpGrok);
  if SameText(AValue, 'OpenRouter') then
    Exit(lpOpenRouter);
  if SameText(AValue, 'OpenClaw') then
    Exit(lpOpenClaw);
  Result := lpOpenAI;
end;

function DefaultBaseUrl(const AProvider: TLLMProvider): string;
begin
  case AProvider of
    lpOpenAI: Result := 'https://api.openai.com/v1';
    lpGemini: Result := 'https://generativelanguage.googleapis.com/v1beta';
    lpClaude: Result := 'https://api.anthropic.com/v1';
    lpGrok: Result := 'https://api.x.ai/v1';
    lpOpenRouter: Result := 'https://openrouter.ai/api/v1';
    lpOpenClaw: Result := 'http://192.168.93.35:18789';
  else
    Result := '';
  end;
end;

function DefaultModel(const AProvider: TLLMProvider): string;
begin
  case AProvider of
    lpOpenAI: Result := 'gpt-4.1-mini';
    lpGemini: Result := 'gemini-2.0-flash';
    lpClaude: Result := 'claude-3-5-sonnet-latest';
    lpGrok: Result := 'grok-2-latest';
    lpOpenRouter: Result := 'openai/gpt-4o-mini';
    lpOpenClaw: Result := 'openclaw/default';
  else
    Result := '';
  end;
end;

function ProviderUsesToken(const AProvider: TLLMProvider): Boolean;
begin
  Result := AProvider = lpOpenClaw;
end;

function DefaultOpenClawSessionKey: string;
begin
  Result := 'DelphiClient-default';
end;

function ApiKeyForProvider(const ASettings: TLLMSettings): string;
begin
  case ASettings.Provider of
    lpOpenAI: Result := ASettings.OpenAIApiKey;
    lpGemini: Result := ASettings.GeminiApiKey;
    lpClaude: Result := ASettings.ClaudeApiKey;
    lpGrok: Result := ASettings.GrokApiKey;
    lpOpenRouter: Result := ASettings.OpenRouterApiKey;
  else
    Result := '';
  end;

  if Result = '' then
    Result := ASettings.ApiKey;
end;

procedure SetApiKeyForProvider(var ASettings: TLLMSettings; const AApiKey: string);
begin
  case ASettings.Provider of
    lpOpenAI: ASettings.OpenAIApiKey := AApiKey;
    lpGemini: ASettings.GeminiApiKey := AApiKey;
    lpClaude: ASettings.ClaudeApiKey := AApiKey;
    lpGrok: ASettings.GrokApiKey := AApiKey;
    lpOpenRouter: ASettings.OpenRouterApiKey := AApiKey;
  end;
  ASettings.ApiKey := AApiKey;
end;

function BaseUrlForProvider(const ASettings: TLLMSettings): string;
begin
  case ASettings.Provider of
    lpOpenAI: Result := ASettings.OpenAIBaseUrl;
    lpGemini: Result := ASettings.GeminiBaseUrl;
    lpClaude: Result := ASettings.ClaudeBaseUrl;
    lpGrok: Result := ASettings.GrokBaseUrl;
    lpOpenRouter: Result := ASettings.OpenRouterBaseUrl;
    lpOpenClaw: Result := ASettings.OpenClawBaseUrl;
  else
    Result := '';
  end;

  if Result = '' then
    Result := ASettings.BaseUrl;
  if Result = '' then
    Result := DefaultBaseUrl(ASettings.Provider);
end;

procedure SetBaseUrlForProvider(var ASettings: TLLMSettings; const ABaseUrl: string);
begin
  case ASettings.Provider of
    lpOpenAI: ASettings.OpenAIBaseUrl := ABaseUrl;
    lpGemini: ASettings.GeminiBaseUrl := ABaseUrl;
    lpClaude: ASettings.ClaudeBaseUrl := ABaseUrl;
    lpGrok: ASettings.GrokBaseUrl := ABaseUrl;
    lpOpenRouter: ASettings.OpenRouterBaseUrl := ABaseUrl;
    lpOpenClaw: ASettings.OpenClawBaseUrl := ABaseUrl;
  end;
  ASettings.BaseUrl := ABaseUrl;
end;

end.
