# Usar `OpenClawClient.pas` noutro projecto Delphi

Este ficheiro explica como reutilizar a unidade `OpenClawClient.pas` num projecto Delphi 12 já existente, incluindo projectos que já tenham ligações próprias à OpenAI, Gemini e Claude.

A unidade foi desenhada para funcionar como mais um fornecedor LLM, neste caso apontado para o gateway OpenClaw.

## 1. Ficheiro necessário

Copiar ou adicionar ao projecto:

```text
OpenClawClient.pas
```

A unidade não depende de VCL nem de FMX. Usa apenas unidades standard do Delphi:

```pascal
System.SysUtils,
System.Classes,
System.JSON,
System.Diagnostics,
System.Net.HttpClient,
System.Net.URLClient
```

Pode ser usada em aplicações VCL, FMX, consola, serviço Windows ou bibliotecas internas.

## 2. Configuração mínima no OpenClaw

O gateway OpenClaw deve estar acessível por HTTP a partir da máquina onde corre a aplicação Delphi.

Exemplo típico:

```text
http://192.168.93.35:18789
```

A unidade tenta os endpoints por esta ordem:

1. `POST /v1/chat/completions`
2. `POST /v1/responses`
3. `POST /tools/invoke`, com a ferramenta `sessions_send`, como fallback legado

No `openclaw.json`, é recomendável ter activos os endpoints compatíveis:

```json
{
  "gateway": {
    "http": {
      "endpoints": {
        "chatCompletions": {
          "enabled": true
        },
        "responses": {
          "enabled": true
        }
      }
    }
  }
}
```

Também é necessário usar o token definido em `gateway.auth.token`, salvo se o gateway estiver explicitamente configurado sem autenticação.

## 3. Integração rápida

Adicionar ao `uses` da unidade onde quer chamar o OpenClaw:

```pascal
uses
  OpenClawClient;
```

Depois chamar:

```pascal
var
  Reply: string;
  Err: string;
begin
  if ConsumeOpenClawAPI(
    'http://192.168.93.35:18789',
    'TOKEN_DO_GATEWAY',
    'openclaw/codigo',
    'DelphiClient-codigo',
    'Analisa este código Delphi e devolve uma resposta objectiva.',
    Reply,
    Err
  ) then
    ShowMessage(Reply)
  else
    ShowMessage(Err);
end;
```

## 4. Uso recomendado com classe

Para aplicações maiores, é preferível usar `TOpenClawClient` e `TOpenClawSettings`.

```pascal
var
  Settings: TOpenClawSettings;
  Client: TOpenClawClient;
  Result: TOpenClawResult;
begin
  Settings := TOpenClawSettings.Default;
  Settings.BaseUrl := 'http://192.168.93.35:18789';
  Settings.BearerToken := 'TOKEN_DO_GATEWAY';
  Settings.Model := 'openclaw/codigo';
  Settings.SessionKey := 'DelphiClient-codigo';
  Settings.TimeoutSeconds := 120;

  Client := TOpenClawClient.Create(Settings);
  try
    Result := Client.SendTextEx('Explica como melhorar esta função Delphi.');

    if Result.Ok then
      ShowMessage(Result.Reply)
    else
      ShowMessage(Result.Error);
  finally
    Client.Free;
  end;
end;
```

## 5. Escolha do agente OpenClaw

O campo `Model` é usado como identificador do agente OpenClaw.

Exemplos:

```text
openclaw/default
openclaw/main
openclaw/codigo
openclaw/oftalvet
openclaw/automation
openclaw/dados
openclaw/sysadmin
openclaw/investimento
openclaw/investimento_brent_xtb
```

Sugestão prática:

- `openclaw/codigo`: análise e geração de código.
- `openclaw/oftalvet`: temas clínicos veterinários e oftalmologia veterinária.
- `openclaw/sysadmin`: tarefas de sistema, Docker, Synology, rede e OpenClaw.
- `openclaw/investimento`: análise financeira e regras IBKR/Portugal.
- `openclaw/investimento_brent_xtb`: fluxo específico para Brent/Oil XTB, caso esteja configurado.

## 6. Session key

A `SessionKey` identifica a conversa/sessão no OpenClaw.

Exemplos:

```text
DelphiClient-codigo
DelphiClient-oftalvet
DelphiClient-sysadmin
```

Usar uma `SessionKey` diferente por módulo ou finalidade evita misturar contextos clínicos, código e automações.

## 7. Estrutura do resultado

`SendTextEx` devolve `TOpenClawResult`:

```pascal
TOpenClawResult = record
  Ok: Boolean;
  Reply: string;
  Error: string;
  Endpoint: TOpenClawEndpoint;
  EndpointPath: string;
  StatusCode: Integer;
  StatusText: string;
  DurationMs: Int64;
  RawResponse: string;
end;
```

Campos úteis:

- `Ok`: indica sucesso.
- `Reply`: resposta textual final.
- `Error`: erro tratado, quando existe.
- `EndpointPath`: endpoint realmente usado.
- `StatusCode`: código HTTP devolvido.
- `DurationMs`: duração da chamada.
- `RawResponse`: resposta JSON bruta do gateway.

## 8. Exemplo de wrapper semelhante aos teus fornecedores actuais

Se o projecto já usa funções como `ConsumeClaudeAPI(Messages: String)` ou `ConsumeGeminiAPI(Messages: String)`, pode criar um wrapper semelhante:

```pascal
function ConsumeOpenClawCodigoAPI(const Messages: string): string;
var
  Reply: string;
  Err: string;
begin
  if ConsumeOpenClawAPI(
    'http://192.168.93.35:18789',
    'TOKEN_DO_GATEWAY',
    'openclaw/codigo',
    'DelphiClient-codigo',
    Messages,
    Reply,
    Err,
    120
  ) then
    Result := Reply
  else
    raise Exception.Create(Err);
end;
```

Ou, para oftalmologia veterinária:

```pascal
function ConsumeOpenClawOftalvetAPI(const Messages: string): string;
var
  Reply: string;
  Err: string;
begin
  if ConsumeOpenClawAPI(
    'http://192.168.93.35:18789',
    'TOKEN_DO_GATEWAY',
    'openclaw/oftalvet',
    'DelphiClient-oftalvet',
    Messages,
    Reply,
    Err,
    180
  ) then
    Result := Reply
  else
    raise Exception.Create(Err);
end;
```

## 9. Uso assíncrono em VCL

A chamada HTTP é síncrona. Numa aplicação VCL, não deve ser executada directamente no thread da interface se a resposta puder demorar.

Exemplo com `TTask`:

```pascal
uses
  System.Threading,
  OpenClawClient;

procedure TForm1.BtnEnviarClick(Sender: TObject);
var
  Msg: string;
begin
  Msg := MemoInput.Text;

  TTask.Run(
    procedure
    var
      Reply: string;
      Err: string;
      Ok: Boolean;
    begin
      Ok := ConsumeOpenClawAPI(
        'http://192.168.93.35:18789',
        'TOKEN_DO_GATEWAY',
        'openclaw/codigo',
        'DelphiClient-codigo',
        Msg,
        Reply,
        Err,
        120
      );

      TThread.Queue(nil,
        procedure
        begin
          if Ok then
            MemoOutput.Lines.Add(Reply)
          else
            MemoOutput.Lines.Add('Erro: ' + Err);
        end);
    end);
end;
```

## 10. Segurança

Não guardar o token directamente no código-fonte se o projecto for partilhado.

Preferir uma destas opções:

- ficheiro `.ini` fora do Git;
- variável de ambiente;
- gestor de segredos;
- campo de configuração local não versionado.

Exemplo simples com variável de ambiente:

```pascal
Settings.BearerToken := GetEnvironmentVariable('OPENCLAW_GATEWAY_TOKEN');
```

## 11. Notas de compatibilidade

A unidade foi pensada para Delphi 12.

Pode exigir pequenos ajustes em versões antigas do Delphi, sobretudo se a versão não suportar adequadamente:

- `System.Net.HttpClient`;
- `TJSONBool`;
- `THTTPClient.CustomHeaders`.

## 12. Diagnóstico rápido

Se receber `HTTP 401` ou `HTTP 403`:

- confirmar `BearerToken`;
- confirmar `gateway.auth.token` no OpenClaw;
- confirmar se está a enviar `Authorization: Bearer <token>`.

Se receber `HTTP 404` ou `HTTP 405` nos endpoints modernos:

- a unidade tentará automaticamente o endpoint seguinte;
- confirmar se `chatCompletions` e/ou `responses` estão activos no `openclaw.json`.

Se a aplicação bloquear durante a chamada:

- usar `TTask.Run` ou outro mecanismo assíncrono;
- aumentar `TimeoutSeconds` se o agente precisar de mais tempo.
