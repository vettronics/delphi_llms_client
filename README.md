# Delphi LLMs Client

Aplicação VCL para Delphi 12 que permite conversar com vários fornecedores de LLM a partir de uma interface única.

## Funcionalidades

- Chat com OpenAI, Gemini, Claude, Grok/xAI, OpenRouter e OpenClaw.
- Selecção manual do provider e do modelo/agente.
- Suporte para fornecedores compatíveis com a API de chat da OpenAI, incluindo OpenRouter e Grok/xAI.
- Separação entre `API key` e `token` do OpenClaw.
- Integração com a unidade existente `OpenClawClient.pas`.
- Opção para manter contexto local da conversa ou enviar apenas a última mensagem.
- Configuração guardada localmente num ficheiro INI em `%APPDATA%\DelphiLLMsClient\settings.ini`.
- Sem chaves ou tokens gravados no repositório.

## Estrutura

```text
DelphiLLMsClient.dpr      Projecto VCL Delphi 12
DelphiLLMsClient.dproj    Projecto MSBuild
OpenClawClient.pas        Cliente OpenClaw existente
USAR_OPENCLAWCLIENT.md    Instruções do cliente OpenClaw
src/MainForm.pas          Interface principal criada por código
src/LLM.Types.pas         Tipos comuns e configuração
src/LLM.Config.pas        Leitura/escrita de configuração local
src/LLM.ChatClients.pas   Clientes HTTP para os providers
```

## Utilização

1. Abrir `DelphiLLMsClient.dproj` no Delphi 12.
2. Compilar para Win32 ou Win64.
3. Executar a aplicação.
4. Seleccionar o provider.
5. Introduzir modelo e chave/token.
6. Para OpenRouter usar, por exemplo:
   - Base URL: `https://openrouter.ai/api/v1`
   - Modelo: `openai/gpt-4o-mini`, `anthropic/claude-3.5-sonnet`, `google/gemini-2.0-flash`, ou outro modelo disponível na conta.
7. Para OpenClaw indicar:
   - Base URL do gateway, por exemplo `http://127.0.0.1:18789` ou `http://192.168.93.35:18789`.
   - Token do gateway.
   - Agente/modelo, por exemplo `openclaw/default`, `openclaw/codigo`, `openclaw/oftalvet`.
   - `SessionKey`, por exemplo `DelphiClient-default`.

## Notas sobre contexto

Quando a opção **Manter contexto local** está activa, a aplicação envia o histórico local completo da conversa ao provider. Quando está inactiva, envia apenas a última pergunta do utilizador.

No OpenClaw, a sessão do gateway pode manter estado próprio. Por isso, mesmo com a opção local desactivada, o gateway pode continuar a usar contexto persistido do lado do OpenClaw, dependendo da configuração do servidor e da `SessionKey` usada.

## OpenClaw

A aplicação usa a unidade já existente `OpenClawClient.pas` através da classe `TOpenClawClient`.

Essa unidade tenta automaticamente os endpoints OpenClaw por esta ordem:

1. `POST /v1/chat/completions`
2. `POST /v1/responses`
3. `POST /tools/invoke`, ferramenta `sessions_send`, como fallback legado

A aplicação não força `/api/chat`. O campo mostrado na interface para OpenClaw é `SessionKey`, não endpoint HTTP.
