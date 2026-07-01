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

ensure_secret WEBUI_SECRET_KEY
ensure_secret SEARXNG_SECRET

PORT="$(grep -E '^WEBUI_PORT=' .env | cut -d= -f2)"
echo
echo "Siguientes pasos:"
echo "  1) Edita .env y pon tu NAN_API_KEY (la consigues en https://nan.builders)"
echo "  2) Arranca:  docker compose up -d"
echo "  3) Abre:     http://localhost:${PORT:-3000}"
