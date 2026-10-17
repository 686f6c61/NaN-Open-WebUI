#!/usr/bin/env bash
# Restaura una copia hecha con ./backup.sh sobre el volumen de datos.
#
#   ./restore.sh backups/nan-2026-10-17_120000.tar.gz
#   ./restore.sh --yes backups/nan-...tar.gz      (sin pedir confirmacion)
#   VOLUME=nan-open-terminal-data SERVICE=open-terminal CHECK_FILE= ./restore.sh ...
#                                                   (volumen de Open Terminal)
#
# Antes de tocar nada guarda el estado actual con ./backup.sh, para poder
# deshacer la restauracion.
set -euo pipefail
cd "$(dirname "$0")"

VOLUME="${VOLUME:-nan-open-webui-data}"
SERVICE="${SERVICE:-nan-open-webui}"
HELPER_IMAGE="${HELPER_IMAGE:-alpine:3.22}"
# Fichero que debe contener la copia para aceptarla; vacio = no comprobar.
CHECK_FILE="${CHECK_FILE-./webui.db}"

YES=""
if [ "${1:-}" = "--yes" ]; then
  YES=1
  shift
fi
SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  echo "Uso: $0 [--yes] <fichero nan-*.tar.gz>" >&2
  exit 1
fi
SRC_DIR="$(cd "$(dirname "$SRC")" && pwd)"
SRC_FILE="$(basename "$SRC")"

if [ -n "$CHECK_FILE" ] && ! docker run --rm -v "$SRC_DIR":/backup:ro "$HELPER_IMAGE" \
    tar tzf "/backup/$SRC_FILE" "$CHECK_FILE" >/dev/null 2>&1; then
  echo "[!] $SRC no parece una copia valida (no contiene $CHECK_FILE)." >&2
  exit 1
fi

if [ -z "$YES" ]; then
  echo "Se va a SUSTITUIR todo el contenido del volumen $VOLUME por $SRC."
  read -r -p "Escribe 'restaurar' para continuar: " answer
  [ "$answer" = "restaurar" ] || { echo "Cancelado."; exit 1; }
fi

if docker volume inspect "$VOLUME" >/dev/null 2>&1; then
  echo "[*] Guardando el estado actual antes de restaurar..."
  ./backup.sh ./backups/antes-de-restaurar
fi

echo "[*] Parando $SERVICE..."
docker compose stop "$SERVICE" >/dev/null 2>&1 || true
trap 'echo "[*] Arrancando..."; docker compose up -d >/dev/null' EXIT

docker volume create "$VOLUME" >/dev/null
docker run --rm -v "$VOLUME":/data -v "$SRC_DIR":/backup:ro "$HELPER_IMAGE" \
  sh -c 'find /data -mindepth 1 -delete && tar xzf "/backup/$0" -C /data' "$SRC_FILE"
echo "[OK] Restaurado $SRC en $VOLUME."
