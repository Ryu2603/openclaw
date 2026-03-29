#!/bin/bash
# =============================================================================
# start-browser.sh — Inicia o Chromium headless com CDP na porta 9222
# TESTADO E VALIDADO em ARM64 (Oracle VPS, Debian 12 / Chrome 146)
# =============================================================================
set -e

echo "[start-browser] Iniciando..."

# ── Detecta o binário correto do Chromium ────────────────────────────
if command -v chromium > /dev/null 2>&1; then
    CHROMIUM_BIN="chromium"
elif command -v chromium-browser > /dev/null 2>&1; then
    CHROMIUM_BIN="chromium-browser"
elif command -v google-chrome > /dev/null 2>&1; then
    CHROMIUM_BIN="google-chrome"
else
    echo "[start-browser] ERRO: Chromium não encontrado!"
    exit 1
fi

echo "[start-browser] Binário: $CHROMIUM_BIN ($($CHROMIUM_BIN --version 2>&1))"

# ── Diretório de perfil persistente ──────────────────────────────────
PROFILE_DIR="${BROWSER_PROFILE_DIR:-/data/browser-profile}"
mkdir -p "$PROFILE_DIR"
chown -R 1001:1001 "$PROFILE_DIR" 2>/dev/null || true

echo "[start-browser] Perfil: ${PROFILE_DIR}"
echo "[start-browser] CDP ouvindo na porta 9222..."

# ── Inicia Chromium headless puro (sem Xvfb, sem display virtual) ─────
# Flags validadas em ARM64 / Debian 12 / Chrome 146
exec "$CHROMIUM_BIN" \
    --remote-debugging-port=9222 \
    --remote-debugging-address=0.0.0.0 \
    --user-data-dir="${PROFILE_DIR}" \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --headless=new \
    --disable-seccomp-filter-sandbox \
    --disable-dbus \
    --window-size=1920,1080 \
    --hide-scrollbars \
    --mute-audio \
    --no-first-run \
    --disable-background-networking \
    --disable-default-apps \
    --disable-sync \
    about:blank
