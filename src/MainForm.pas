unit MainForm;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  LLM.Types, LLM.Config, LLM.ChatClients;

type
  TfrmMain = class(TForm)
  private
    FHistory: TChatMessageList;
    FChat: TMemo;
    FPrompt: TMemo;
    FProvider: TComboBox;
    FModel: TEdit;
    FBaseUrl: TEdit;
    FSecret: TEdit;
    FSessionKey: TEdit;
    FKeepContext: TCheckBox;
    FSend: TButton;
    FClear: TButton;
    FSave: TButton;
    FSessionLabel: TLabel;

    procedure BuildUi;
    procedure LoadLocalSettings;
    procedure SaveLocalSettings;
    procedure ProviderChanged(Sender: TObject);
    procedure SendClicked(Sender: TObject);
    procedure ClearClicked(Sender: TObject);
    procedure SaveClicked(Sender: TObject);
    procedure PromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    function SelectedProvider: TLLMProvider;
    function CurrentSettings: TLLMSettings;
    function BuildMessages(const AText: string): TChatMessageList;
    procedure AddToChat(const ATitle, AText: string);
    procedure SetBusy(const AValue: Boolean);
    procedure UpdateProviderUi;
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
  inherited;
  FHistory := TChatMessageList.Create;
  Caption := 'Delphi LLMs Client';
  Width := 1120;
  Height := 760;
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  BuildUi;
  LoadLocalSettings;
end;

destructor TfrmMain.Destroy;
begin
  SaveLocalSettings;
  FHistory.Free;
  inherited;
end;

procedure TfrmMain.BuildUi;
var
  TopPanel, BottomPanel, ButtonPanel: TPanel;
  L: TLabel;
begin
  TopPanel := TPanel.Create(Self);
  TopPanel.Parent := Self;
  TopPanel.Align := alTop;
  TopPanel.Height := 140;
  TopPanel.BevelOuter := bvNone;

  L := TLabel.Create(Self); L.Parent := TopPanel; L.SetBounds(12, 12, 120, 20); L.Caption := 'Provider';
  FProvider := TComboBox.Create(Self);
  FProvider.Parent := TopPanel;
  FProvider.SetBounds(12, 34, 160, 24);
  FProvider.Style := csDropDownList;
  FProvider.Items.Add(ProviderToString(lpOpenAI));
  FProvider.Items.Add(ProviderToString(lpGemini));
  FProvider.Items.Add(ProviderToString(lpClaude));
  FProvider.Items.Add(ProviderToString(lpGrok));
  FProvider.Items.Add(ProviderToString(lpOpenRouter));
  FProvider.Items.Add(ProviderToString(lpOpenClaw));
  FProvider.OnChange := ProviderChanged;

  L := TLabel.Create(Self); L.Parent := TopPanel; L.SetBounds(190, 12, 150, 20); L.Caption := 'Modelo / agente';
  FModel := TEdit.Create(Self); FModel.Parent := TopPanel; FModel.SetBounds(190, 34, 245, 24);

  L := TLabel.Create(Self); L.Parent := TopPanel; L.SetBounds(455, 12, 120, 20); L.Caption := 'Base URL';
  FBaseUrl := TEdit.Create(Self); FBaseUrl.Parent := TopPanel; FBaseUrl.SetBounds(455, 34, 330, 24);

  L := TLabel.Create(Self); L.Parent := TopPanel; L.SetBounds(805, 12, 120, 20); L.Caption := 'Chave';
  FSecret := TEdit.Create(Self); FSecret.Parent := TopPanel; FSecret.SetBounds(805, 34, 295, 24); FSecret.PasswordChar := '*';

  FSessionLabel := TLabel.Create(Self); FSessionLabel.Parent := TopPanel; FSessionLabel.SetBounds(12, 78, 180, 20); FSessionLabel.Caption := 'SessionKey OpenClaw';
  FSessionKey := TEdit.Create(Self); FSessionKey.Parent := TopPanel; FSessionKey.SetBounds(12, 100, 260, 24);

  FKeepContext := TCheckBox.Create(Self);
  FKeepContext.Parent := TopPanel;
  FKeepContext.SetBounds(295, 101, 360, 24);
  FKeepContext.Caption := 'Manter contexto local';
  FKeepContext.Checked := True;

  FSave := TButton.Create(Self); FSave.Parent := TopPanel; FSave.SetBounds(680, 96, 110, 32); FSave.Caption := 'Guardar'; FSave.OnClick := SaveClicked;
  FClear := TButton.Create(Self); FClear.Parent := TopPanel; FClear.SetBounds(800, 96, 140, 32); FClear.Caption := 'Limpar conversa'; FClear.OnClick := ClearClicked;

  FChat := TMemo.Create(Self);
  FChat.Parent := Self;
  FChat.Align := alClient;
  FChat.ScrollBars := ssVertical;
  FChat.ReadOnly := True;
  FChat.WordWrap := True;

  BottomPanel := TPanel.Create(Self);
  BottomPanel.Parent := Self;
  BottomPanel.Align := alBottom;
  BottomPanel.Height := 160;
  BottomPanel.BevelOuter := bvNone;
  BottomPanel.Padding.SetBounds(10, 8, 10, 10);

  ButtonPanel := TPanel.Create(Self);
  ButtonPanel.Parent := BottomPanel;
  ButtonPanel.Align := alRight;
  ButtonPanel.Width := 145;
  ButtonPanel.BevelOuter := bvNone;

  FSend := TButton.Create(Self);
  FSend.Parent := ButtonPanel;
  FSend.Align := alTop;
  FSend.Height := 42;
  FSend.Caption := 'Enviar';
  FSend.Default := True;
  FSend.OnClick := SendClicked;

  FPrompt := TMemo.Create(Self);
  FPrompt.Parent := BottomPanel;
  FPrompt.Align := alClient;
  FPrompt.ScrollBars := ssVertical;
  FPrompt.WordWrap := True;
  FPrompt.OnKeyDown := PromptKeyDown;
end;

procedure TfrmMain.LoadLocalSettings;
var
  S: TLLMSettings;
begin
  S := TLLMConfigStore.Load;
  FProvider.ItemIndex := Ord(S.Provider);
  FModel.Text := S.Model;
  FBaseUrl.Text := S.BaseUrl;
  FSessionKey.Text := S.OpenClawEndpoint;
  FKeepContext.Checked := S.KeepLocalContext;
  if S.Provider = lpOpenClaw then FSecret.Text := S.OpenClawToken else FSecret.Text := S.ApiKey;
  UpdateProviderUi;
end;

procedure TfrmMain.SaveLocalSettings;
begin
  TLLMConfigStore.Save(CurrentSettings);
end;

function TfrmMain.SelectedProvider: TLLMProvider;
begin
  if FProvider.ItemIndex < 0 then Result := lpOpenAI else Result := TLLMProvider(FProvider.ItemIndex);
end;

function TfrmMain.CurrentSettings: TLLMSettings;
begin
  Result.Provider := SelectedProvider;
  Result.Model := FModel.Text.Trim;
  Result.BaseUrl := FBaseUrl.Text.Trim;
  Result.ApiKey := '';
  Result.OpenClawToken := '';
  Result.OpenClawEndpoint := FSessionKey.Text.Trim;
  Result.KeepLocalContext := FKeepContext.Checked;
  Result.TimeoutSeconds := 120;

  if Result.Model = '' then Result.Model := DefaultModel(Result.Provider);
  if Result.BaseUrl = '' then Result.BaseUrl := DefaultBaseUrl(Result.Provider);
  if Result.OpenClawEndpoint = '' then Result.OpenClawEndpoint := DefaultOpenClawSessionKey;

  if Result.Provider = lpOpenClaw then Result.OpenClawToken := FSecret.Text.Trim else Result.ApiKey := FSecret.Text.Trim;
end;

procedure TfrmMain.ProviderChanged(Sender: TObject);
var
  P: TLLMProvider;
begin
  P := SelectedProvider;
  FModel.Text := DefaultModel(P);
  FBaseUrl.Text := DefaultBaseUrl(P);
  if P = lpOpenClaw then FSessionKey.Text := DefaultOpenClawSessionKey;
  UpdateProviderUi;
end;

procedure TfrmMain.UpdateProviderUi;
var
  IsOpenClaw: Boolean;
begin
  IsOpenClaw := SelectedProvider = lpOpenClaw;
  FSessionLabel.Enabled := IsOpenClaw;
  FSessionKey.Enabled := IsOpenClaw;
  if IsOpenClaw then FKeepContext.Caption := 'Manter contexto local; o gateway pode manter sessão própria' else FKeepContext.Caption := 'Manter contexto local';
end;

function TfrmMain.BuildMessages(const AText: string): TChatMessageList;
var
  M: TChatMessage;
begin
  Result := TChatMessageList.Create;
  if FKeepContext.Checked then for M in FHistory do Result.Add(M);
  Result.Add(TChatMessage.Create('user', AText));
end;

procedure TfrmMain.AddToChat(const ATitle, AText: string);
begin
  if FChat.Lines.Count > 0 then FChat.Lines.Add('');
  FChat.Lines.Add(ATitle + ':');
  FChat.Lines.Add(AText);
  FChat.SelStart := Length(FChat.Text);
end;

procedure TfrmMain.SendClicked(Sender: TObject);
var
  Msg, Answer: string;
  C: TCustomChatClient;
  OutMsgs: TChatMessageList;
  S: TLLMSettings;
begin
  Msg := FPrompt.Text.Trim;
  if Msg = '' then Exit;

  SaveLocalSettings;
  S := CurrentSettings;
  AddToChat('Utilizador', Msg);
  FPrompt.Clear;
  SetBusy(True);
  C := nil;
  OutMsgs := nil;
  try
    OutMsgs := BuildMessages(Msg);
    C := TChatClientFactory.CreateClient(S);
    Answer := C.SendMessage(OutMsgs);
    FHistory.Add(TChatMessage.Create('user', Msg));
    FHistory.Add(TChatMessage.Create('assistant', Answer));
    AddToChat(ProviderToString(S.Provider), Answer);
  except
    on E: Exception do
    begin
      AddToChat('Erro', E.Message);
      MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  end;
  C.Free;
  OutMsgs.Free;
  SetBusy(False);
end;

procedure TfrmMain.ClearClicked(Sender: TObject);
begin
  FHistory.Clear;
  FChat.Clear;
  FPrompt.SetFocus;
end;

procedure TfrmMain.SaveClicked(Sender: TObject);
begin
  SaveLocalSettings;
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
  FSend.Enabled := not AValue;
  FClear.Enabled := not AValue;
  FSave.Enabled := not AValue;
  FProvider.Enabled := not AValue;
  FModel.Enabled := not AValue;
  FBaseUrl.Enabled := not AValue;
  FSecret.Enabled := not AValue;
  FKeepContext.Enabled := not AValue;
  FSessionKey.Enabled := (not AValue) and (SelectedProvider = lpOpenClaw);
  if AValue then Screen.Cursor := crHourGlass else Screen.Cursor := crDefault;
  Application.ProcessMessages;
end;

end.
