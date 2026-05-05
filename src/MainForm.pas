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
    btnSave: TButton;
    btnClear: TButton;
    memChat: TMemo;
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
    procedure memPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FHistory: TChatMessageList;
    procedure LoadLocalSettings;
    procedure SaveLocalSettings;
    function SelectedProvider: TLLMProvider;
    function CurrentSettings: TLLMSettings;
    function BuildMessages(const AText: string): TChatMessageList;
    procedure AddToChat(const ATitle, AText: string);
    procedure SetBusy(const AValue: Boolean);
    procedure UpdateProviderUi;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  Winapi.Windows;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FHistory := TChatMessageList.Create;

  cbProvider.Items.Clear;
  cbProvider.Items.Add(ProviderToString(lpOpenAI));
  cbProvider.Items.Add(ProviderToString(lpGemini));
  cbProvider.Items.Add(ProviderToString(lpClaude));
  cbProvider.Items.Add(ProviderToString(lpGrok));
  cbProvider.Items.Add(ProviderToString(lpOpenRouter));
  cbProvider.Items.Add(ProviderToString(lpOpenClaw));

  LoadLocalSettings;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  SaveLocalSettings;
  FHistory.Free;
end;

procedure TfrmMain.LoadLocalSettings;
var
  S: TLLMSettings;
begin
  S := TLLMConfigStore.Load;
  cbProvider.ItemIndex := Ord(S.Provider);
  edtModel.Text := S.Model;
  edtBaseUrl.Text := S.BaseUrl;
  edtSessionKey.Text := S.OpenClawEndpoint;
  chkKeepContext.Checked := S.KeepLocalContext;

  if S.Provider = lpOpenClaw then
    edtSecret.Text := S.OpenClawToken
  else
    edtSecret.Text := S.ApiKey;

  UpdateProviderUi;
end;

procedure TfrmMain.SaveLocalSettings;
begin
  TLLMConfigStore.Save(CurrentSettings);
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
  Result.Provider := SelectedProvider;
  Result.Model := edtModel.Text.Trim;
  Result.BaseUrl := edtBaseUrl.Text.Trim;
  Result.ApiKey := '';
  Result.OpenClawToken := '';
  Result.OpenClawEndpoint := edtSessionKey.Text.Trim;
  Result.KeepLocalContext := chkKeepContext.Checked;
  Result.TimeoutSeconds := 120;

  if Result.Model = '' then
    Result.Model := DefaultModel(Result.Provider);
  if Result.BaseUrl = '' then
    Result.BaseUrl := DefaultBaseUrl(Result.Provider);
  if Result.OpenClawEndpoint = '' then
    Result.OpenClawEndpoint := DefaultOpenClawSessionKey;

  if Result.Provider = lpOpenClaw then
    Result.OpenClawToken := edtSecret.Text.Trim
  else
    Result.ApiKey := edtSecret.Text.Trim;
end;

procedure TfrmMain.cbProviderChange(Sender: TObject);
var
  P: TLLMProvider;
begin
  P := SelectedProvider;
  edtModel.Text := DefaultModel(P);
  edtBaseUrl.Text := DefaultBaseUrl(P);

  if P = lpOpenClaw then
    edtSessionKey.Text := DefaultOpenClawSessionKey;

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
    lblSecret.Caption := 'API key';
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
  if memChat.Lines.Count > 0 then
    memChat.Lines.Add('');

  memChat.Lines.Add(ATitle + ':');
  memChat.Lines.Add(AText);
  memChat.SelStart := Length(memChat.Text);
end;

procedure TfrmMain.btnSendClick(Sender: TObject);
var
  Msg: string;
  Answer: string;
  Client: TCustomChatClient;
  OutMsgs: TChatMessageList;
  Settings: TLLMSettings;
begin
  Msg := memPrompt.Text.Trim;
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
  memChat.Clear;
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
  edtSessionKey.Enabled := (not AValue) and (SelectedProvider = lpOpenClaw);

  if AValue then
    Screen.Cursor := crHourGlass
  else
    Screen.Cursor := crDefault;

  Application.ProcessMessages;
end;

end.
