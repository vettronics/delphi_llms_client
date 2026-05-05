unit MainForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Diagnostics,
  System.Threading,
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
    lblBusy: TLabel;
    tmrBusy: TTimer;
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
    procedure tmrBusyTimer(Sender: TObject);
  private
    FHistory: TChatMessageList;
    FTranscriptMarkdown: TStringBuilder;
    FSettings: TLLMSettings;
    FActiveProvider: TLLMProvider;
    FLoadingSettings: Boolean;
    FBusyFrame: Integer;
    procedure EnsureBusyIndicator;
    procedure LoadLocalSettings;
    procedure SaveLocalSettings;
    procedure StoreVisibleProviderFields;
    procedure DisplayProviderFields(const AProvider: TLLMProvider);
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
  FLoadingSettings := False;
  FBusyFrame := 0;
  EnsureBusyIndicator;

  cbProvider.Items.Clear;
  cbProvider.Items.Add(ProviderToString(lpOpenAI));
  cbProvider.Items.Add(ProviderToString(lpGemini));
  cbProvider.Items.Add(ProviderToString(lpClaude));
  cbProvider.Items.Add(ProviderToString(lpGrok));
  cbProvider.Items.Add(ProviderToString(lpOpenRouter));
  cbProvider.Items.Add(ProviderToString(lpOpenClaw));

  LoadLocalSettings;
  RenderChat;
  SetBusy(False);
end;

procedure TfrmMain.EnsureBusyIndicator;
begin
  if lblBusy = nil then
  begin
    lblBusy := TLabel.Create(Self);
    lblBusy.Parent := pnlTop;
    lblBusy.Left := 12;
    lblBusy.Top := 124;
    lblBusy.Width := 260;
    lblBusy.Height := 17;
    lblBusy.Caption := '';
    lblBusy.Visible := False;
  end;

  if tmrBusy = nil then
  begin
    tmrBusy := TTimer.Create(Self);
    tmrBusy.Enabled := False;
    tmrBusy.Interval := 150;
    tmrBusy.OnTimer := tmrBusyTimer;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  SaveLocalSettings;
  FTranscriptMarkdown.Free;
  FHistory.Free;
end;

procedure TfrmMain.LoadLocalSettings;
begin
  FLoadingSettings := True;
  try
    FSettings := TLLMConfigStore.Load;
    FActiveProvider := FSettings.Provider;

    cbProvider.ItemIndex := Ord(FSettings.Provider);
    edtSessionKey.Text := FSettings.OpenClawEndpoint;
    chkKeepContext.Checked := FSettings.KeepLocalContext;
    DisplayProviderFields(FSettings.Provider);
  finally
    FLoadingSettings := False;
  end;

  UpdateProviderUi;
end;

procedure TfrmMain.SaveLocalSettings;
begin
  if FLoadingSettings then
    Exit;

  StoreVisibleProviderFields;
  FSettings := CurrentSettings;
  TLLMConfigStore.Save(FSettings);
end;

procedure TfrmMain.StoreVisibleProviderFields;
var
  OldProvider: TLLMProvider;
begin
  if FLoadingSettings then
    Exit;

  OldProvider := FSettings.Provider;
  try
    FSettings.Provider := FActiveProvider;
    SetModelForProvider(FSettings, Trim(edtModel.Text));
    SetBaseUrlForProvider(FSettings, Trim(edtBaseUrl.Text));

    if FActiveProvider = lpOpenClaw then
      FSettings.OpenClawToken := Trim(edtSecret.Text)
    else
      SetApiKeyForProvider(FSettings, Trim(edtSecret.Text));
  finally
    FSettings.Provider := OldProvider;
  end;
end;

procedure TfrmMain.DisplayProviderFields(const AProvider: TLLMProvider);
var
  TempSettings: TLLMSettings;
begin
  TempSettings := FSettings;
  TempSettings.Provider := AProvider;

  edtModel.Text := ModelForProvider(TempSettings);
  edtBaseUrl.Text := BaseUrlForProvider(TempSettings);

  if AProvider = lpOpenClaw then
    edtSecret.Text := FSettings.OpenClawToken
  else
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
  Result.OpenClawEndpoint := Trim(edtSessionKey.Text);
  Result.KeepLocalContext := chkKeepContext.Checked;
  Result.TimeoutSeconds := 120;

  SetModelForProvider(Result, Trim(edtModel.Text));
  if Result.Model = '' then
    SetModelForProvider(Result, DefaultModel(Result.Provider));

  SetBaseUrlForProvider(Result, Trim(edtBaseUrl.Text));
  if Result.BaseUrl = '' then
    SetBaseUrlForProvider(Result, DefaultBaseUrl(Result.Provider));

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
  if FLoadingSettings then
    Exit;

  StoreVisibleProviderFields;

  NewProvider := SelectedProvider;
  FSettings.Provider := NewProvider;
  FActiveProvider := NewProvider;

  if NewProvider = lpOpenClaw then
  begin
    if Trim(edtSessionKey.Text) = '' then
      edtSessionKey.Text := DefaultOpenClawSessionKey;
  end;

  DisplayProviderFields(NewProvider);
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
    lblModel.Caption := ProviderToString(SelectedProvider) + ' model';
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
  FTranscriptMarkdown.AppendLine(TrimRight(AText));
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
  OutMsgs: TChatMessageList;
  Settings: TLLMSettings;
begin
  Msg := Trim(memPrompt.Text);
  if Msg = '' then
    Exit;

  SaveLocalSettings;
  Settings := CurrentSettings;
  OutMsgs := BuildMessages(Msg);

  AddToChat('Utilizador', Msg);
  memPrompt.Clear;
  SetBusy(True);

  TTask.Run(
    procedure
    var
      Client: TCustomChatClient;
      Stopwatch: TStopwatch;
      Answer: string;
      ErrorText: string;
      ElapsedText: string;
      Ok: Boolean;
    begin
      Client := nil;
      Ok := False;
      ErrorText := '';
      Answer := '';
      Stopwatch := TStopwatch.StartNew;
      try
        try
          Client := TChatClientFactory.CreateClient(Settings);
          Answer := Client.SendMessage(OutMsgs);
          Ok := True;
        except
          on E: Exception do
          begin
            ErrorText := E.Message;
            Ok := False;
          end;
        end;
      finally
        Stopwatch.Stop;
        ElapsedText := FormatFloat('0.00', Stopwatch.Elapsed.TotalSeconds) + ' s';
        Client.Free;
        OutMsgs.Free;
      end;

      TThread.Queue(nil,
        procedure
        begin
          if Ok then
          begin
            FHistory.Add(TChatMessage.Create('user', Msg));
            FHistory.Add(TChatMessage.Create('assistant', Answer));
            AddToChat(ProviderToString(Settings.Provider) + ' - ' + ElapsedText, Answer);
          end
          else
          begin
            AddToChat('Erro - ' + ElapsedText, ErrorText);
            MessageDlg(ErrorText, mtError, [mbOK], 0);
          end;

          SetBusy(False);
        end);
    end);
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
  if (Key = VK_RETURN) and not (ssShift in Shift) then
  begin
    Key := 0;
    btnSendClick(Sender);
  end;
end;

procedure TfrmMain.tmrBusyTimer(Sender: TObject);
const
  FRAMES: array[0..3] of string = ('|', '/', '-', '\');
begin
  Inc(FBusyFrame);
  if FBusyFrame > High(FRAMES) then
    FBusyFrame := Low(FRAMES);

  if lblBusy <> nil then
    lblBusy.Caption := FRAMES[FBusyFrame] + ' A aguardar resposta...';
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
  memPrompt.Enabled := not AValue;

  if lblBusy <> nil then
    lblBusy.Visible := AValue;
  if tmrBusy <> nil then
    tmrBusy.Enabled := AValue;

  if AValue then
  begin
    FBusyFrame := 0;
    if lblBusy <> nil then
      lblBusy.Caption := '| A aguardar resposta...';
    Screen.Cursor := crHourGlass;
  end
  else
  begin
    if lblBusy <> nil then
      lblBusy.Caption := '';
    Screen.Cursor := crDefault;
  end;
end;

end.
