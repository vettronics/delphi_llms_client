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
  private
    FHistory: TChatMessageList;

    pnlTop: TPanel;
    pnlBottom: TPanel;
    pnlActions: TPanel;
    memChat: TMemo;
    memPrompt: TMemo;
    cbProvider: TComboBox;
    edtModel: TEdit;
    edtBaseUrl: TEdit;
    edtSecret: TEdit;
    edtOpenClawEndpoint: TEdit;
    chkKeepContext: TCheckBox;
    btnSend: TButton;
    btnClear: TButton;
    btnSave: TButton;
    lblProvider: TLabel;
    lblModel: TLabel;
    lblBaseUrl: TLabel;
    lblSecret: TLabel;
    lblEndpoint: TLabel;

    procedure BuildInterface;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ProviderChanged(Sender: TObject);
    procedure SendClicked(Sender: TObject);
    procedure ClearClicked(Sender: TObject);
    procedure SaveClicked(Sender: TObject);
    procedure PromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    function SelectedProvider: TLLMProvider;
    function CurrentSettings: TLLMSettings;
    function BuildOutboundMessages(const AUserMessage: string): TChatMessageList;
    procedure AppendChatLine(const APrefix, AText: string);
    procedure SetBusy(const AValue: Boolean);
    procedure RefreshProviderUi;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  frmMain: TfrmMain;

implementation

uses
  Winapi.Windows;

constructor TfrmMain.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHistory := TChatMessageList.Create;

  Caption := 'Delphi LLMs Client';
  Width := 1150;
  Height := 780;
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 10;

  BuildInterface;
  LoadSettings;
end;

destructor TfrmMain.Destroy;
begin
  SaveSettings;
  FHistory.Free;
  inherited;
end;

procedure TfrmMain.BuildInterface;
begin
  pnlTop := TPanel.Create(Self);
  pnlTop.Parent := Self;
  pnlTop.Align := alTop;
  pnlTop.Height := 140;
  pnlTop.BevelOuter := bvNone;
  pnlTop.Padding.SetBounds(10, 10, 10, 8);

  lblProvider := TLabel.Create(Self);
  lblProvider.Parent := pnlTop;
  lblProvider.Left := 12;
  lblProvider.Top := 14;
  lblProvider.Caption := 'Provider';

  cbProvider := TComboBox.Create(Self);
  cbProvider.Parent := pnlTop;
  cbProvider.Left := 12;
  cbProvider.Top := 36;
  cbProvider.Width := 160;
  cbProvider.Style := csDropDownList;
  cbProvider.Items.Add(ProviderToString(lpOpenAI));
  cbProvider.Items.Add(ProviderToString(lpGemini));
  cbProvider.Items.Add(ProviderToString(lpClaude));
  cbProvider.Items.Add(ProviderToString(lpGrok));
  cbProvider.Items.Add(ProviderToString(lpOpenRouter));
  cbProvider.Items.Add(ProviderToString(lpOpenClaw));
  cbProvider.OnChange := ProviderChanged;

  lblModel := TLabel.Create(Self);
  lblModel.Parent := pnlTop;
  lblModel.Left := 190;
  lblModel.Top := 14;
  lblModel.Caption := 'Modelo / agente';

  edtModel := TEdit.Create(Self);
  edtModel.Parent := pnlTop;
  edtModel.Left := 190;
  edtModel.Top := 36;
  edtModel.Width := 240;

  lblBaseUrl := TLabel.Create(Self);
  lblBaseUrl.Parent := pnlTop;
  lblBaseUrl.Left := 450;
  lblBaseUrl.Top := 14;
  lblBaseUrl.Caption := 'Base URL';

  edtBaseUrl := TEdit.Create(Self);
  edtBaseUrl.Parent := pnlTop;
  edtBaseUrl.Left := 450;
  edtBaseUrl.Top := 36;
  edtBaseUrl.Width := 330;

  lblSecret := TLabel.Create(Self);
  lblSecret.Parent := pnlTop;
  lblSecret.Left := 800;
  lblSecret.Top := 14;
  lblSecret.Caption := 'API key / token';

  edtSecret := TEdit.Create(Self);
  edtSecret.Parent := pnlTop;
  edtSecret.Left := 800;
  edtSecret.Top := 36;
  edtSecret.Width := 310;
  edtSecret.PasswordChar := '*';

  lblEndpoint := TLabel.Create(Self);
  lblEndpoint.Parent := pnlTop;
  lblEndpoint.Left := 12;
  lblEndpoint.Top := 78;
  lblEndpoint.Caption := 'Endpoint OpenClaw';

  edtOpenClawEndpoint := TEdit.Create(Self);
  edtOpenClawEndpoint.Parent := pnlTop;
  edtOpenClawEndpoint.Left := 12;
  edtOpenClawEndpoint.Top := 100;
  edtOpenClawEndpoint.Width := 260;

  chkKeepContext := TCheckBox.Create(Self);
  chkKeepContext.Parent := pnlTop;
  chkKeepContext.Left := 295;
  chkKeepContext.Top := 103;
  chkKeepContext.Width := 220;
  chkKeepContext.Caption := 'Manter contexto local';
  chkKeepContext.Checked := True;

  btnSave := TButton.Create(Self);
  btnSave.Parent := pnlTop;
  btnSave.Left := 540;
  btnSave.Top := 96;
  btnSave.Width := 120;
  btnSave.Caption := 'Guardar';
  btnSave.OnClick := SaveClicked;

  btnClear := TButton.Create(Self);
  btnClear.Parent := pnlTop;
  btnClear.Left := 670;
  btnClear.Top := 96;
  btnClear.Width := 140;
  btnClear.Caption := 'Limpar conversa';
  btnClear.OnClick := ClearClicked;

  memChat := TMemo.Create(Self);
  memChat.Parent := Self;
  memChat.Align := alClient;
  memChat.ScrollBars := ssVertical;
  memChat.ReadOnly := True;
  memChat.WordWrap := True;

  pnlBottom := TPanel.Create(Self);
  pnlBottom.Parent := Self;
  pnlBottom.Align := alBottom;
  pnlBottom.Height := 165;
  pnlBottom.BevelOuter := bvNone;
  pnlBottom.Padding.SetBounds(10, 8, 10, 10);

  pnlActions := TPanel.Create(Self);
  pnlActions.Parent := pnlBottom;
  pnlActions.Align := alRight;
  pnlActions.Width := 145;
  pnlActions.BevelOuter := bvNone;

  btnSend := TButton.Create(Self);
  btnSend.Parent := pnlActions;
  btnSend.Align := alTop;
  btnSend.Height := 42;
  btnSend.Caption := 'Enviar';
  btnSend.Default := True;
  btnSend.OnClick := SendClicked;

  memPrompt := TMemo.Create(Self);
  memPrompt.Parent := pnlBottom;
  memPrompt.Align := alClient;
  memPrompt.ScrollBars := ssVertical;
  memPrompt.WordWrap := True;
  memPrompt.OnKeyDown := PromptKeyDown;
end;

procedure TfrmMain.LoadSettings;
var
  LSettings: TLLMSettings;
begin
  LSettings := TLLMConfigStore.Load;

  cbProvider.ItemIndex := Ord(LSettings.Provider);
  edtModel.Text := LSettings.Model;
  edtBaseUrl.Text := LSettings.BaseUrl;
  edtOpenClawEndpoint.Text := LSettings.OpenClawEndpoint;
  chkKeepContext.Checked := LSettings.KeepLocalContext;

  if LSettings.Provider = lpOpenClaw then
    edtSecret.Text := LSettings.OpenClawToken
  else
    edtSecret.Text := LSettings.ApiKey;

  RefreshProviderUi;
end;

procedure TfrmMain.SaveSettings;
var
  LSettings: TLLMSettings;
begin
  LSettings := CurrentSettings;
  TLLMConfigStore.Save(LSettings);
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
  Result.KeepLocalContext := chkKeepContext.Checked;
  Result.TimeoutSeconds := 120;
  Result.ApiKey := '';
  Result.OpenClawToken := '';
  Result.OpenClawEndpoint := edtOpenClawEndpoint.Text.Trim;

  if Result.Model = '' then
    Result.Model := DefaultModel(Result.Provider);
  if Result.BaseUrl = '' then
    Result.BaseUrl := DefaultBaseUrl(Result.Provider);
  if Result.OpenClawEndpoint = '' then
    Result.OpenClawEndpoint := '/api/chat';

  if Result.Provider = lpOpenClaw then
    Result.OpenClawToken := edtSecret.Text.Trim
  else
    Result.ApiKey := edtSecret.Text.Trim;
end;

procedure TfrmMain.ProviderChanged(Sender: TObject);
var
  LProvider: TLLMProvider;
begin
  LProvider := SelectedProvider;
  edtModel.Text := DefaultModel(LProvider);
  edtBaseUrl.Text := DefaultBaseUrl(LProvider);

  if LProvider = lpOpenClaw then
    edtOpenClawEndpoint.Text := '/api/chat';

  RefreshProviderUi;
end;

procedure TfrmMain.RefreshProviderUi;
var
  LProvider: TLLMProvider;
begin
  LProvider := SelectedProvider;

  if LProvider = lpOpenClaw then
    lblSecret.Caption := 'OpenClaw token'
  else
    lblSecret.Caption := 'API key';

  lblEndpoint.Enabled := LProvider = lpOpenClaw;
  edtOpenClawEndpoint.Enabled := LProvider = lpOpenClaw;

  if LProvider = lpOpenClaw then
    chkKeepContext.Caption := 'Manter contexto local (OpenClaw pode manter contexto no servidor)'
  else
    chkKeepContext.Caption := 'Manter contexto local';
end;

procedure TfrmMain.AppendChatLine(const APrefix, AText: string);
begin
  if memChat.Lines.Count > 0 then
    memChat.Lines.Add('');
  memChat.Lines.Add(APrefix + ':');
  memChat.Lines.Add(AText);
  memChat.SelStart := Length(memChat.Text);
end;

function TfrmMain.BuildOutboundMessages(const AUserMessage: string): TChatMessageList;
var
  LMessage: TChatMessage;
begin
  Result := TChatMessageList.Create;

  if chkKeepContext.Checked then
  begin
    for LMessage in FHistory do
      Result.Add(LMessage);
  end;

  Result.Add(TChatMessage.Create('user', AUserMessage));
end;

procedure TfrmMain.SendClicked(Sender: TObject);
var
  LUserMessage: string;
  LSettings: TLLMSettings;
  LClient: TCustomChatClient;
  LOutbound: TChatMessageList;
  LAnswer: string;
begin
  LUserMessage := memPrompt.Text.Trim;
  if LUserMessage = '' then
    Exit;

  SaveSettings;
  LSettings := CurrentSettings;

  AppendChatLine('Utilizador', LUserMessage);
  memPrompt.Clear;
  SetBusy(True);

  LOutbound := nil;
  LClient := nil;
  try
    LOutbound := BuildOutboundMessages(LUserMessage);
    LClient := TChatClientFactory.CreateClient(LSettings);
    LAnswer := LClient.SendMessage(LOutbound);

    FHistory.Add(TChatMessage.Create('user', LUserMessage));
    FHistory.Add(TChatMessage.Create('assistant', LAnswer));
    AppendChatLine(ProviderToString(LSettings.Provider), LAnswer);
  except
    on E: Exception do
    begin
      AppendChatLine('Erro', E.Message);
      MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  end;

  LClient.Free;
  LOutbound.Free;
  SetBusy(False);
end;

procedure TfrmMain.ClearClicked(Sender: TObject);
begin
  FHistory.Clear;
  memChat.Clear;
  memPrompt.SetFocus;
end;

procedure TfrmMain.SaveClicked(Sender: TObject);
begin
  SaveSettings;
  MessageDlg('Definições guardadas.', mtInformation, [mbOK], 0);
end;

procedure TfrmMain.PromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    SendClicked(Sender);
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
  edtOpenClawEndpoint.Enabled := (not AValue) and (SelectedProvider = lpOpenClaw);

  if AValue then
    Screen.Cursor := crHourGlass
  else
    Screen.Cursor := crDefault;
  Application.ProcessMessages;
end;

end.
