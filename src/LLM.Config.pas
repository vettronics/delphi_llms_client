unit LLM.Config;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.IniFiles,
  LLM.Types;

type
  TLLMConfigStore = class
  public
    class function SettingsFileName: string; static;
    class function DefaultSettings: TLLMSettings; static;
    class function Load: TLLMSettings; static;
    class procedure Save(const ASettings: TLLMSettings); static;
  end;

implementation

class function TLLMConfigStore.SettingsFileName: string;
var
  LFolder: string;
begin
  LFolder := TPath.Combine(TPath.GetHomePath, 'AppData\Roaming\DelphiLLMsClient');

  if not TDirectory.Exists(LFolder) then
    TDirectory.CreateDirectory(LFolder);

  Result := TPath.Combine(LFolder, 'settings.ini');
end;

class function TLLMConfigStore.DefaultSettings: TLLMSettings;
begin
  Result.Provider := lpOpenAI;
  Result.Model := DefaultModel(Result.Provider);
  Result.ApiKey := 'COLOCAR_API_KEY_AQUI';
  Result.BaseUrl := DefaultBaseUrl(Result.Provider);
  Result.OpenClawToken := 'COLOCAR_TOKEN_OPENCLAW_AQUI';
  Result.OpenClawEndpoint := DefaultOpenClawSessionKey;
  Result.KeepLocalContext := True;
  Result.TimeoutSeconds := 120;
end;

class function TLLMConfigStore.Load: TLLMSettings;
var
  LIni: TIniFile;
  LFileName: string;
begin
  Result := DefaultSettings;

  LFileName := SettingsFileName;
  if not TFile.Exists(LFileName) then
  begin
    Save(Result);
    Exit;
  end;

  LIni := TIniFile.Create(LFileName);
  try
    Result.Provider := StringToProvider(LIni.ReadString('General', 'Provider', ProviderToString(Result.Provider)));
    Result.Model := LIni.ReadString('General', 'Model', DefaultModel(Result.Provider));
    Result.BaseUrl := LIni.ReadString('General', 'BaseUrl', DefaultBaseUrl(Result.Provider));
    Result.ApiKey := LIni.ReadString('Secrets', 'ApiKey', Result.ApiKey);
    Result.OpenClawToken := LIni.ReadString('Secrets', 'OpenClawToken', Result.OpenClawToken);
    Result.OpenClawEndpoint := LIni.ReadString('OpenClaw', 'Endpoint', DefaultOpenClawSessionKey);
    Result.KeepLocalContext := LIni.ReadBool('General', 'KeepLocalContext', True);
    Result.TimeoutSeconds := LIni.ReadInteger('General', 'TimeoutSeconds', 120);

    if Result.Model.Trim = '' then
      Result.Model := DefaultModel(Result.Provider);
    if Result.BaseUrl.Trim = '' then
      Result.BaseUrl := DefaultBaseUrl(Result.Provider);
    if Result.OpenClawEndpoint.Trim = '' then
      Result.OpenClawEndpoint := DefaultOpenClawSessionKey;
    if Result.TimeoutSeconds < 10 then
      Result.TimeoutSeconds := 10;
  finally
    LIni.Free;
  end;
end;

class procedure TLLMConfigStore.Save(const ASettings: TLLMSettings);
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(SettingsFileName);
  try
    LIni.WriteString('General', 'Provider', ProviderToString(ASettings.Provider));
    LIni.WriteString('General', 'Model', ASettings.Model);
    LIni.WriteString('General', 'BaseUrl', ASettings.BaseUrl);
    LIni.WriteBool('General', 'KeepLocalContext', ASettings.KeepLocalContext);
    LIni.WriteInteger('General', 'TimeoutSeconds', ASettings.TimeoutSeconds);

    LIni.WriteString('Secrets', 'ApiKey', ASettings.ApiKey);
    LIni.WriteString('Secrets', 'OpenClawToken', ASettings.OpenClawToken);
    LIni.WriteString('OpenClaw', 'Endpoint', ASettings.OpenClawEndpoint);
  finally
    LIni.Free;
  end;
end;

end.
