# Integração com `openclawclient.pas`

Esta aplicação já inclui uma implementação HTTP genérica para OpenClaw em `src/LLM.ChatClients.pas`, classe `TOpenClawChatClient`.

## Ponto de integração

Substituir ou adaptar este método:

```pascal
function TOpenClawChatClient.SendMessage(const AMessages: TChatMessageList): string;
```

A implementação actual envia:

```json
{
  "agent": "main",
  "model": "main",
  "prompt": "última mensagem do utilizador",
  "messages": [
    {"role": "user", "content": "..."}
  ]
}
```

Cabeçalhos enviados:

```text
Authorization: Bearer <token>
X-OpenClaw-Token: <token>
Content-Type: application/json
```

Endpoint predefinido:

```text
http://127.0.0.1:18789/api/chat
```

## Se o teu `openclawclient.pas` já tiver uma função pronta

A forma recomendada é manter a interface da aplicação e alterar apenas `TOpenClawChatClient.SendMessage` para chamar a função existente.

Exemplo conceptual:

```pascal
uses
  OpenClawClient;

function TOpenClawChatClient.SendMessage(const AMessages: TChatMessageList): string;
begin
  Result := TOpenClawClient.SendChat(
    Settings.BaseUrl,
    Settings.OpenClawToken,
    Settings.Model,
    LastUserMessage(AMessages)
  );
end;
```

O nome exacto da função deve ser ajustado de acordo com a API real documentada no MD do teu repositório.

## Contexto

A opção **Manter contexto local** controla apenas o histórico enviado pela aplicação Delphi.

No OpenClaw, pode existir contexto persistente do lado do gateway/agente. Assim, mesmo que a aplicação envie apenas a última mensagem, o OpenClaw pode continuar a usar memória, sessão ou contexto próprio, conforme a configuração do servidor.
