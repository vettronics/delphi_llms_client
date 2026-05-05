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

class function TLLMConfigStore.Load: TLLMSettings;
var
  LIni: TIniFile;
  LFileName: string;
begin
  Result.Provider := lpOpenAI;
  Result.Model := DefaultModel(Result.Provider);
  Result.ApiKey := '';
  Result.BaseUrl := DefaultBaseUrl(Result.Provider);
  Result.OpenClawToken := '';
  Result.OpenClawEndpoint := '/api/chat';
  Result.KeepLocalContext := True;
  Result.TimeoutSeconds := 120;

  LFileName := SettingsFileName;
  if not TFile.Exists(LFileName) then
    Exit;

  LIni := TIniFile.Create(LFileName);
  try
    Result.Provider := StringToProvider(LIni.ReadString('General', 'Provider', ProviderToString(Result.Provider)));
    Result.Model := LIni.ReadString('General', 'Model', DefaultModel(Result.Provider));
    Result.BaseUrl := LIni.ReadString('General', 'BaseUrl', DefaultBaseUrl(Result.Provider));
    Result.ApiKey := LIni.ReadString('Secrets', 'ApiKey', '');
    Result.OpenClawToken := LIni.ReadString('Secrets', 'OpenClawToken', '');
    Result.OpenClawEndpoint := LIni.ReadString('OpenClaw', 'Endpoint', '/api/chat');
    Result.KeepLocalContext := LIni.ReadBool('General', 'KeepLocalContext', True);
    Result.TimeoutSeconds := LIni.ReadInteger('General', 'TimeoutSeconds', 120);

    if Result.Model.Trim = '' then
      Result.Model := DefaultModel(Result.Provider);
    if Result.BaseUrl.Trim = '' then
      Result.BaseUrl := DefaultBaseUrl(Result.Provider);
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
