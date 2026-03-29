#!/bin/bash
# =============================================================================
# start-browser.sh — Inicia o Chromium headless com CDP na porta 9222
# Executado como usuário "browseruser" pelo supervisord
# =============================================================================
set -e

# Diretório de perfil persistente
PROFILE_DIR="${BROWSER_PROFILE_DIR:-/data/browser-profile}"
mkdir -p "$PROFILE_DIR"

# Permite ao browseruser escrever no diretório
if [ "$(stat -c '%U' "$PROFILE_DIR")" != "browseruser" ]; then
    chown -R browseruser:browseruser "$PROFILE_DIR" 2>/dev/null || true
fi

# Tamanho da tela virtual (usado pelo Xvfb se disponível)
SCREEN_RES="${BROWSER_SCREEN_RES:-1920x1080x24}"

# Inicia Xvfb (display virtual) se não houver DISPLAY
if [ -z "$DISPLAY" ]; then
    export DISPLAY=":99"
    Xvfb :99 -screen 0 "$SCREEN_RES" -ac +extension GLX +render -noreset &
    sleep 1
fi

# Flags do Chromium
CHROMIUM_FLAGS=(
    --remote-debugging-port=9222
    --remote-debugging-address=127.0.0.1
    --user-data-dir="${PROFILE_DIR}"
    --no-sandbox
    --disable-dev-shm-usage
    --disable-gpu
    --disable-software-rasterizer
    --disable-background-networking
    --disable-default-apps
    --disable-extensions-except
    --disable-sync
    --disable-translate
    --metrics-recording-only
    --no-first-run
    --safebrowsing-disable-auto-update
    --password-store=basic
    --use-mock-keychain
    --headless=new
    --window-size=1920,1080
    --hide-scrollbars
    --mute-audio
)

# Flags extras definidas por ENV
if [ -n "$CHROME_CLI" ]; then
    read -ra EXTRA_FLAGS <<< "$CHROME_CLI"
    CHROMIUM_FLAGS+=("${EXTRA_FLAGS[@]}")
fi

echo "[start-browser] Iniciando Chromium CDP na porta 9222..."
echo "[start-browser] Perfil: ${PROFILE_DIR}"
exec chromium "${CHROMIUM_FLAGS[@]}" about:blank
