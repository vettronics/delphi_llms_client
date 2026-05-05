program DelphiLLMsClient;

uses
  Vcl.Forms,
  MainForm in 'src\MainForm.pas',
  LLM.Types in 'src\LLM.Types.pas',
  LLM.Config in 'src\LLM.Config.pas',
  LLM.ChatClients in 'src\LLM.ChatClients.pas',
  OpenClawClient in 'OpenClawClient.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Delphi LLMs Client';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
