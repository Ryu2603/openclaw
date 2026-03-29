# OpenClaw All-in-One — ARM64 (Oracle VPS + Coolify)

Solução de container único combinando **OpenClaw** + **Chromium browser (CDP)**, compatível com servidores ARM64 (Oracle VPS).

## Problema resolvido

O projeto oficial `coollabsio/openclaw` usa dois containers separados:
- `openclaw`: a aplicação principal  
- `browser`: imagem `lscr.io/linuxserver/chromium` — **não otimizada para ARM64**

Esta solução coloca tudo num único container usando o `chromium` nativo do Debian/APT (armhf/arm64 nativos), eliminando esse problema.

## Estrutura de arquivos

```
openclaw/
├── Dockerfile                          # Build all-in-one
├── docker-compose.yml                  # Para deploy no Coolify
├── supervisord.conf                    # Gerencia os 3 processos internos
├── .env.example                        # Variáveis de ambiente necessárias
└── scripts/
    ├── start-browser.sh                # Inicia Chromium headless + CDP
    └── entrypoint-allinone.sh          # Entrypoint customizado
```

## Como funciona internamente

```
Container único
┌─────────────────────────────────────────────────────────┐
│  supervisord (gerencia tudo)                            │
│                                                         │
│  ┌────────────────┐   ┌──────────┐   ┌──────────────┐ │
│  │ openclaw       │   │ chromium │   │ nginx-cdp    │ │
│  │ gateway :18789 │   │ CDP:9222 │   │ proxy :9223  │ │
│  └───────┬────────┘   └────┬─────┘   └──────┬───────┘ │
│          │                  │                │          │
│  nginx :8080 (UI)    BROWSER_CDP_URL=127.0.0.1:9223   │
└─────────────────────────────────────────────────────────┘
         ↓
   Coolify → domínio externo
```

## Deploy no Coolify

### Opção 1: Build via Git (recomendado)

1. Faça push deste repositório para o GitHub
2. No Coolify: **New Resource → Application → From GitHub**
3. Selecione o repositório, branch `main`
4. **Build Pack**: Docker Compose
5. Arquivo: `docker-compose.yml`
6. Configure as variáveis de ambiente (ver `.env.example`)
7. **Deploy**

### Opção 2: Docker Compose direto no Coolify

1. No Coolify: **New Resource → Docker Compose**
2. Cole o conteúdo do `docker-compose.yml`
3. Mude `build: .` para usar a imagem pré-buildada (opcional)

## Variáveis de ambiente obrigatórias

| Variável | Descrição |
|---|---|
| `ANTHROPIC_API_KEY` | API key do Claude (ou outro provider) |
| `AUTH_PASSWORD` | Senha de acesso à UI |
| `OPENCLAW_GATEWAY_TOKEN` | Token interno — **não mude após o primeiro deploy** |

## Atualizar o OpenClaw (redeploy sem perder dados)

O `OPENCLAW_GATEWAY_TOKEN` garante estabilidade entre redeploys. Os dados ficam em `/data` (volume Docker persistente).

Para atualizar:
```bash
# Apenas redeploy pelo Coolify (botão "Redeploy")
# OU via CLI no VPS:
docker compose pull   # (se usar imagem de registry)
docker compose up -d --build
```

O volume `openclaw-data` persiste:
- `/data/.openclaw/` — configuração e estado
- `/data/workspace/` — projetos do usuário  
- `/data/browser-profile/` — perfil do Chromium (sessões salvas)

## Troubleshooting

### Ver logs do browser
```bash
docker logs openclaw-allinone
# ou dentro do container:
tail -f /data/logs/chromium.log
tail -f /data/logs/openclaw.log
```

### Testar CDP manualmente
```bash
# Dentro do container
curl http://localhost:9222/json/version
curl http://localhost:9223/json/version
```

### Chromium não sobe no ARM
O Chromium é instalado via `apt` (nativo ARM64). Verifique:
```bash
docker exec openclaw-allinone chromium --version
```
