unit MainForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Dialogs,
  Vcl.ComCtrls,
  LLM.Types,
  LLM.Config,
  LLM.ChatClients;

type
  TfrmMain = class(TForm)
    pnlTop: TPanel;
    lblProvider: TLabel;
    cbProvider: TComboBox;
    lblModel: TLabel;
    edtModel: TEdit;
    lblBaseUrl: TLabel;
    edtBaseUrl: TEdit;
    lblSecret: TLabel;
    edtSecret: TEdit;
    lblSessionKey: TLabel;
    edtSessionKey: TEdit;
    chkKeepContext: TCheckBox;
    chkVisualMarkdown: TCheckBox;
    btnSave: TButton;
    btnClear: TButton;
    memChat: TMemo;
    reChat: TRichEdit;
    pnlBottom: TPanel;
    pnlActions: TPanel;
    btnSend: TButton;
    memPrompt: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cbProviderChange(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure chkVisualMarkdownClick(Sender: TObject);
    procedure memPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FHistory: TChatMessageList;
    FTranscriptMarkdown: TStringBuilder;
    FSettings: TLLMSettings;
    FActiveProvider: TLLMProvider;
    procedure LoadLocalSettings;
    procedure SaveLocalSettings;
    procedure StoreVisibleSecret;
    procedure DisplaySecretForProvider(const AProvider: TLLMProvider);
    function SelectedProvider: TLLMProvider;
    function CurrentSettings: TLLMSettings;
    function BuildMessages(const AText: string): TChatMessageList;
    procedure AddToChat(const ATitle, AText: string);
    procedure RenderChat;
    procedure SetBusy(const AValue: Boolean);
    procedure UpdateProviderUi;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  Winapi.Windows,
  MarkdownRenderer;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FHistory := TChatMessageList.Create;
  FTranscriptMarkdown := TStringBuilder.Create;
  FSettings := TLLMConfigStore.DefaultSettings;
  FActiveProvider := FSettings.Provider;

  cbProvider.Items.Clear;
  cbProvider.Items.Add(ProviderToString(lpOpenAI));
  cbProvider.Items.Add(ProviderToString(lpGemini));
  cbProvider.Items.Add(ProviderToString(lpClaude));
  cbProvider.Items.Add(ProviderToString(lpGrok));
  cbProvider.Items.Add(ProviderToString(lpOpenRouter));
  cbProvider.Items.Add(ProviderToString(lpOpenClaw));

  LoadLocalSettings;
  RenderChat;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  SaveLocalSettings;
  FTranscriptMarkdown.Free;
  FHistory.Free;
end;

procedure TfrmMain.LoadLocalSettings;
begin
  FSettings := TLLMConfigStore.Load;
  FActiveProvider := FSettings.Provider;

  cbProvider.ItemIndex := Ord(FSettings.Provider);
  edtModel.Text := FSettings.Model;
  edtBaseUrl.Text := FSettings.BaseUrl;
  edtSessionKey.Text := FSettings.OpenClawEndpoint;
  chkKeepContext.Checked := FSettings.KeepLocalContext;
  DisplaySecretForProvider(FSettings.Provider);

  UpdateProviderUi;
end;

procedure TfrmMain.SaveLocalSettings;
begin
  StoreVisibleSecret;
  FSettings := CurrentSettings;
  TLLMConfigStore.Save(FSettings);
end;

procedure TfrmMain.StoreVisibleSecret;
var
  OldProvider: TLLMProvider;
begin
  if FActiveProvider = lpOpenClaw then
  begin
    FSettings.OpenClawToken := Trim(edtSecret.Text);
    Exit;
  end;

  OldProvider := FSettings.Provider;
  try
    FSettings.Provider := FActiveProvider;
    SetApiKeyForProvider(FSettings, Trim(edtSecret.Text));
  finally
    FSettings.Provider := OldProvider;
  end;
end;

procedure TfrmMain.DisplaySecretForProvider(const AProvider: TLLMProvider);
var
  TempSettings: TLLMSettings;
begin
  if AProvider = lpOpenClaw then
  begin
    edtSecret.Text := FSettings.OpenClawToken;
    Exit;
  end;

  TempSettings := FSettings;
  TempSettings.Provider := AProvider;
  edtSecret.Text := ApiKeyForProvider(TempSettings);
end;

function TfrmMain.SelectedProvider: TLLMProvider;
begin
  if cbProvider.ItemIndex < 0 then
    Result := lpOpenAI
  else
    Result := TLLMProvider(cbProvider.ItemIndex);
end;

function TfrmMain.CurrentSettings: TLLMSettings;
begin
  Result := FSettings;
  Result.Provider := SelectedProvider;
  Result.Model := Trim(edtModel.Text);
  Result.BaseUrl := Trim(edtBaseUrl.Text);
  Result.OpenClawEndpoint := Trim(edtSessionKey.Text);
  Result.KeepLocalContext := chkKeepContext.Checked;
  Result.TimeoutSeconds := 120;

  if Result.Model = '' then
    Result.Model := DefaultModel(Result.Provider);
  if Result.BaseUrl = '' then
    Result.BaseUrl := DefaultBaseUrl(Result.Provider);
  if Result.OpenClawEndpoint = '' then
    Result.OpenClawEndpoint := DefaultOpenClawSessionKey;

  if Result.Provider = lpOpenClaw then
    Result.OpenClawToken := Trim(edtSecret.Text)
  else
  begin
    SetApiKeyForProvider(Result, Trim(edtSecret.Text));
    Result.ApiKey := ApiKeyForProvider(Result);
  end;
end;

procedure TfrmMain.cbProviderChange(Sender: TObject);
var
  NewProvider: TLLMProvider;
begin
  StoreVisibleSecret;

  NewProvider := SelectedProvider;
  FSettings.Provider := NewProvider;
  FActiveProvider := NewProvider;

  edtModel.Text := DefaultModel(NewProvider);
  edtBaseUrl.Text := DefaultBaseUrl(NewProvider);

  if NewProvider = lpOpenClaw then
    edtSessionKey.Text := DefaultOpenClawSessionKey;

  DisplaySecretForProvider(NewProvider);
  UpdateProviderUi;
end;

procedure TfrmMain.UpdateProviderUi;
var
  IsOpenClaw: Boolean;
begin
  IsOpenClaw := SelectedProvider = lpOpenClaw;

  lblSessionKey.Enabled := IsOpenClaw;
  edtSessionKey.Enabled := IsOpenClaw;

  if IsOpenClaw then
  begin
    lblSecret.Caption := 'OpenClaw token';
    lblModel.Caption := 'Agente OpenClaw';
    chkKeepContext.Caption := 'Manter contexto local; o gateway pode manter sessão própria';
  end
  else
  begin
    lblSecret.Caption := ProviderToString(SelectedProvider) + ' API key';
    lblModel.Caption := 'Modelo';
    chkKeepContext.Caption := 'Manter contexto local';
  end;
end;

function TfrmMain.BuildMessages(const AText: string): TChatMessageList;
var
  M: TChatMessage;
begin
  Result := TChatMessageList.Create;

  if chkKeepContext.Checked then
    for M in FHistory do
      Result.Add(M);

  Result.Add(TChatMessage.Create('user', AText));
end;

procedure TfrmMain.AddToChat(const ATitle, AText: string);
begin
  if FTranscriptMarkdown.Length > 0 then
    FTranscriptMarkdown.AppendLine;

  FTranscriptMarkdown.AppendLine('## ' + ATitle);
  FTranscriptMarkdown.AppendLine;
  FTranscriptMarkdown.AppendLine(AText);
  RenderChat;
end;

procedure TfrmMain.RenderChat;
var
  Text: string;
begin
  Text := FTranscriptMarkdown.ToString;

  memChat.Visible := not chkVisualMarkdown.Checked;
  reChat.Visible := chkVisualMarkdown.Checked;

  if chkVisualMarkdown.Checked then
  begin
    TMarkdownRenderer.RenderToRichEdit(reChat, Text);
    reChat.SelStart := Length(reChat.Text);
  end
  else
  begin
    memChat.Text := Text;
    memChat.SelStart := Length(memChat.Text);
  end;
end;

procedure TfrmMain.chkVisualMarkdownClick(Sender: TObject);
begin
  RenderChat;
end;

procedure TfrmMain.btnSendClick(Sender: TObject);
var
  Msg: string;
  Answer: string;
  Client: TCustomChatClient;
  OutMsgs: TChatMessageList;
  Settings: TLLMSettings;
begin
  Msg := Trim(memPrompt.Text);
  if Msg = '' then
    Exit;

  SaveLocalSettings;
  Settings := CurrentSettings;
  AddToChat('Utilizador', Msg);
  memPrompt.Clear;
  SetBusy(True);

  Client := nil;
  OutMsgs := nil;
  try
    OutMsgs := BuildMessages(Msg);
    Client := TChatClientFactory.CreateClient(Settings);
    Answer := Client.SendMessage(OutMsgs);

    FHistory.Add(TChatMessage.Create('user', Msg));
    FHistory.Add(TChatMessage.Create('assistant', Answer));
    AddToChat(ProviderToString(Settings.Provider), Answer);
  except
    on E: Exception do
    begin
      AddToChat('Erro', E.Message);
      MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  end;

  Client.Free;
  OutMsgs.Free;
  SetBusy(False);
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  FHistory.Clear;
  FTranscriptMarkdown.Clear;
  memChat.Clear;
  reChat.Clear;
  memPrompt.SetFocus;
end;

procedure TfrmMain.btnSaveClick(Sender: TObject);
begin
  SaveLocalSettings;
  MessageDlg('Definições guardadas.', mtInformation, [mbOK], 0);
end;

procedure TfrmMain.memPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    btnSendClick(Sender);
  end;
end;

procedure TfrmMain.SetBusy(const AValue: Boolean);
begin
  btnSend.Enabled := not AValue;
  btnClear.Enabled := not AValue;
  btnSave.Enabled := not AValue;
  cbProvider.Enabled := not AValue;
  edtModel.Enabled := not AValue;
  edtBaseUrl.Enabled := not AValue;
  edtSecret.Enabled := not AValue;
  chkKeepContext.Enabled := not AValue;
  chkVisualMarkdown.Enabled := not AValue;
  edtSessionKey.Enabled := (not AValue) and (SelectedProvider = lpOpenClaw);

  if AValue then
    Screen.Cursor := crHourGlass
  else
    Screen.Cursor := crDefault;

  Application.ProcessMessages;
end;

end.
