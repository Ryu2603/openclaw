#!/bin/bash
# =============================================================================
# entrypoint-allinone.sh — Entrypoint do container all-in-one
#
# Responsabilidades:
# 1. Garante diretórios de log e dados
# 2. Seta BROWSER_CDP_URL para apontar ao CDP local (porta 9223)
# 3. Executa script de configuração do openclaw (configure.js)
# 4. Configura nginx principal (:8080 → :18789)
# 5. Inicia supervisord (que sobe: chromium, nginx-cdp, openclaw gateway)
# =============================================================================
set -e

echo "============================================="
echo " OpenClaw All-in-One — ARM64 Ready"
echo " $(date)"
echo "============================================="

# ── Diretórios necessários ────────────────────────────────────────────
mkdir -p /data/logs
mkdir -p /data/.openclaw
mkdir -p /data/workspace
mkdir -p /data/browser-profile

# Garante permissão de escrita para browseruser no perfil
chown -R browseruser:browseruser /data/browser-profile 2>/dev/null || true

# ── Porta do gateway (interna, openclaw escuta aqui) ─────────────────
export OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
export PORT="${PORT:-8080}"

# ── Define CDP URL para o browser local ──────────────────────────────
export BROWSER_CDP_URL="${BROWSER_CDP_URL:-http://127.0.0.1:9223}"
export BROWSER_DEFAULT_PROFILE="${BROWSER_DEFAULT_PROFILE:-openclaw}"
export BROWSER_EVALUATE_ENABLED="${BROWSER_EVALUATE_ENABLED:-true}"

echo "[entrypoint] PORT=$PORT | GATEWAY_PORT=$OPENCLAW_GATEWAY_PORT"
echo "[entrypoint] BROWSER_CDP_URL=$BROWSER_CDP_URL"

# ── Executa script de configuração do openclaw (gera openclaw.json) ──
if [ -f /app/scripts/configure.js ]; then
    echo "[entrypoint] Executando configure.js..."
    node /app/scripts/configure.js || true
fi

# ── Configura nginx principal (reverse proxy :PORT → :GATEWAY_PORT) ──
NGINX_CONF="/etc/nginx/sites-available/openclaw-main.conf"
NGINX_HTPASSWD="/etc/nginx/.htpasswd"

# Gera htpasswd se AUTH_PASSWORD estiver definido
if [ -n "$AUTH_PASSWORD" ]; then
    AUTH_USER="${AUTH_USERNAME:-admin}"
    htpasswd -bc "$NGINX_HTPASSWD" "$AUTH_USER" "$AUTH_PASSWORD" 2>/dev/null || \
        echo "$AUTH_USER:$(openssl passwd -apr1 "$AUTH_PASSWORD")" > "$NGINX_HTPASSWD"
    
    cat > "$NGINX_CONF" <<NGINX_EOF
server {
    listen ${PORT} default_server;
    server_name _;

    auth_basic "OpenClaw";
    auth_basic_user_file ${NGINX_HTPASSWD};

    # Proxy para o gateway
    location / {
        proxy_pass http://127.0.0.1:${OPENCLAW_GATEWAY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        client_max_body_size 100M;
    }

    # Sem auth para healthcheck
    location /healthz {
        auth_basic off;
        proxy_pass http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}/healthz;
    }
}
NGINX_EOF
else
    cat > "$NGINX_CONF" <<NGINX_EOF
server {
    listen ${PORT} default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${OPENCLAW_GATEWAY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        client_max_body_size 100M;
    }

    location /healthz {
        proxy_pass http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}/healthz;
    }
}
NGINX_EOF
fi

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/openclaw-main.conf
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Testa configuração nginx
nginx -t 2>/dev/null && echo "[entrypoint] nginx config OK"

# ── Executa init script customizado (opcional) ───────────────────────
if [ -f /data/init.sh ]; then
    echo "[entrypoint] Executando /data/init.sh customizado..."
    bash /data/init.sh
fi

# ── Inicia supervisord (gerencia: chromium + nginx-cdp + nginx-main + openclaw) ──
echo "[entrypoint] Iniciando supervisord..."
exec supervisord -c /etc/supervisor/conf.d/openclaw.conf
