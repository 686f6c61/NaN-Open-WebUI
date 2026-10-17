#!/usr/bin/env bash
# Prepara el .env: lo crea desde la plantilla y genera secretos locales si faltan.
set -euo pipefail
cd "$(dirname "$0")"

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

ensure_secret() {
  local name="$1"
  local current=""
  local secret

  if grep -qE "^${name}=" .env; then
    current="$(grep -E "^${name}=" .env | tail -n 1 | cut -d= -f2-)"
    if [ -n "$current" ]; then
      return 0
    fi

    secret="$(generate_secret)"
    sed -i.bak "s|^${name}=.*|${name}=${secret}|" .env
    rm -f .env.bak
    echo "[OK] ${name} generado."
    return 0
  fi

  secret="$(generate_secret)"
  printf "\n%s=%s\n" "$name" "$secret" >> .env
  echo "[OK] ${name} anadido."
}

if [ -f .env ]; then
  echo "[i] Ya existe .env -> conservo tus valores y completo secretos si faltan."
else
  cp .env.example .env
  echo "[OK] .env creado desde .env.example."
fi

# El .env lleva la API key y los secretos: solo legible por su propietario.
chmod 600 .env

ensure_secret WEBUI_SECRET_KEY
ensure_secret SEARXNG_SECRET
ensure_secret OPEN_TERMINAL_API_KEY

# Copia la clave del terminal dentro de TERMINAL_SERVER_CONNECTIONS (aunque la
# linea siga comentada), para que activarlo sea solo descomentar.
TERMINAL_KEY="$(grep -E '^OPEN_TERMINAL_API_KEY=' .env | tail -n 1 | cut -d= -f2-)"
if [ -n "$TERMINAL_KEY" ] && grep -q 'PON_AQUI_OPEN_TERMINAL_API_KEY' .env; then
  sed -i.bak "s|PON_AQUI_OPEN_TERMINAL_API_KEY|${TERMINAL_KEY}|" .env
  rm -f .env.bak
fi

KEY="$(grep -E '^NAN_API_KEY=' .env | tail -n 1 | cut -d= -f2-)"
case "$KEY" in
  ""|sk-pon-aqui-tu-api-key)
    echo "[!] NAN_API_KEY sigue sin rellenar." ;;
  nan_pat_*)
    echo "[!] NAN_API_KEY es un platform token (nan_pat_...): NaN lo rechaza para inferencia. Usa una API key sk-..." ;;
esac

PORT="$(grep -E '^WEBUI_PORT=' .env | cut -d= -f2)"
echo
echo "Siguientes pasos:"
echo "  1) Edita .env y pon tu NAN_API_KEY (la generas en https://cloud.nan.builders -> Settings -> API Keys)"
echo "  2) Arranca:  docker compose up -d"
echo "  3) Abre:     http://localhost:${PORT:-3000}"
