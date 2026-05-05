# Integração com `OpenClawClient.pas`

A aplicação VCL usa directamente a unidade existente `OpenClawClient.pas`.

A integração está concentrada neste método:

```pascal
function TOpenClawChatClient.SendMessage(const AMessages: TChatMessageList): string;
```

Ficheiro:

```text
src/LLM.ChatClients.pas
```

## Fluxo usado

1. A interface recolhe:
   - Base URL do gateway OpenClaw.
   - Token do gateway.
   - Modelo/agente, por exemplo `openclaw/default`, `openclaw/codigo` ou `openclaw/oftalvet`.
   - `SessionKey`, por exemplo `DelphiClient-default`.
2. `TOpenClawChatClient` cria `TOpenClawSettings`.
3. A chamada é feita com `TOpenClawClient.SendTextEx`.

## Endpoints

A aplicação não chama `/api/chat`.

A selecção de endpoints é feita pela própria unidade `OpenClawClient.pas`, que tenta automaticamente:

1. `POST /v1/chat/completions`
2. `POST /v1/responses`
3. `POST /tools/invoke`, ferramenta `sessions_send`, como fallback legado

## Contexto

A opção **Manter contexto local** controla o histórico que a aplicação Delphi envia ao provider.

No caso do OpenClaw, mesmo que a aplicação envie apenas a última mensagem, o gateway pode manter contexto próprio através da sessão/agente configurado. A `SessionKey` é o identificador principal para separar conversas OpenClaw.

## Campos da interface

Para OpenClaw:

```text
Base URL      -> gateway OpenClaw, por exemplo http://127.0.0.1:18789
Chave         -> token do gateway
Modelo/agente -> agente OpenClaw, por exemplo openclaw/default
SessionKey    -> sessão, por exemplo DelphiClient-default
```
