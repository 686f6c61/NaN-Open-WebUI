#!/usr/bin/env bash
# Prepara el .env: lo crea desde la plantilla y genera la WEBUI_SECRET_KEY.
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .env ]; then
  echo "[i] Ya existe .env -> no lo toco. Revisa que tu NAN_API_KEY este puesta."
  exit 0
fi

cp .env.example .env

# Generar una clave secreta unica para firmar las sesiones
if command -v openssl >/dev/null 2>&1; then
  SECRET="$(openssl rand -hex 32)"
else
  SECRET="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fi
sed -i.bak "s|^WEBUI_SECRET_KEY=.*|WEBUI_SECRET_KEY=${SECRET}|" .env && rm -f .env.bak

PORT="$(grep -E '^WEBUI_PORT=' .env | cut -d= -f2)"
echo "[OK] .env creado con una clave secreta generada."
echo
echo "Siguientes pasos:"
echo "  1) Edita .env y pon tu NAN_API_KEY (la consigues en https://nan.builders)"
echo "  2) Arranca:  docker compose up -d"
echo "  3) Abre:     http://localhost:${PORT:-3000}"
