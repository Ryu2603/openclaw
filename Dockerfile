# =============================================================================
# OpenClaw All-in-One — ARM64 compatible (Oracle VPS / Coolify)
#
# Combina o OpenClaw com o Chromium (browser CDP) no MESMO container.
# Resolve o problema da imagem lscr.io/linuxserver/chromium que não
# funciona bem em ARM64.
#
# Processos internos (gerenciados pelo supervisord):
#   1. chromium     — headless, CDP na porta 9222
#   2. nginx-cdp    — proxy CDP 9223 → 9222 (com fix do Host header)
#   3. nginx-main   — reverse proxy :PORT → gateway :18789
#   4. openclaw     — gateway principal
#
# Build: docker build -t openclaw-allinone:latest .
# =============================================================================

# A imagem oficial coollabsio/openclaw é multi-arch (amd64 + arm64)
FROM coollabsio/openclaw:latest

LABEL maintainer="custom-build" \
      description="OpenClaw + Chromium browser (CDP) all-in-one, ARM64-ready"

# ── 1. Instalar Chromium nativo do Debian (funciona em arm64) ────────
#    + supervisor para gerenciar múltiplos processos
#    + xvfb para display virtual (needed pelo Chromium no headless=new)
#    + apache2-utils para htpasswd (autenticação nginx)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        chromium \
        supervisor \
        xvfb \
        fonts-liberation \
        fonts-noto-color-emoji \
        libnss3 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libcups2 \
        libxss1 \
        libxrandr2 \
        libasound2 \
        libpangocairo-1.0-0 \
        libgtk-3-0 \
        apache2-utils \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Usuário sem privilégios para o browser ─────────────────────────
# Usa UID/GID fixos e não depende de nome para o chown (evita falha se já existir)
RUN groupadd -r browseruser --gid=1001 2>/dev/null || \
        groupmod -n browseruser $(getent group 1001 | cut -d: -f1) 2>/dev/null || true && \
    useradd -r -g 1001 --uid=1001 \
        --home-dir=/home/browseruser \
        --shell=/bin/bash \
        --no-create-home \
        browseruser 2>/dev/null || true && \
    mkdir -p /home/browseruser && \
    chown -R 1001:1001 /home/browseruser

# ── 3. Nginx CDP proxy config ─────────────────────────────────────────
# Arquivo de config separado para o proxy CDP (porta 9223)
# Isso não conflita com o nginx principal (porta 8080)
COPY nginx-cdp.conf /etc/nginx/cdp-proxy.conf

# ── 4. Scripts de controle ────────────────────────────────────────────
COPY scripts/start-browser.sh /app/scripts/start-browser.sh
COPY scripts/entrypoint-allinone.sh /app/scripts/entrypoint-allinone.sh
RUN chmod +x /app/scripts/start-browser.sh \
             /app/scripts/entrypoint-allinone.sh

# ── 5. Supervisord config ─────────────────────────────────────────────
COPY supervisord.conf /etc/supervisor/conf.d/openclaw.conf

# ── 6. Variáveis de ambiente padrão ──────────────────────────────────
ENV PORT=8080 \
    OPENCLAW_GATEWAY_PORT=18789 \
    BROWSER_CDP_URL=http://127.0.0.1:9223 \
    BROWSER_DEFAULT_PROFILE=openclaw \
    BROWSER_EVALUATE_ENABLED=true \
    OPENCLAW_HOME=/data \
    OPENCLAW_STATE_DIR=/data/.openclaw \
    OPENCLAW_CONFIG_PATH=/data/.openclaw/openclaw.json

# Volume para dados persistentes
VOLUME ["/data"]

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=5 \
    CMD curl -sf http://localhost:${PORT:-8080}/healthz || exit 1

ENTRYPOINT ["/app/scripts/entrypoint-allinone.sh"]
