#!/usr/bin/env bash
# Copia de seguridad del volumen de datos (cuentas, chats, ajustes, ficheros).
#
#   ./backup.sh                       -> ./backups/nan-AAAA-MM-DD_HHMMSS.tar.gz
#   ./backup.sh /var/backups/nan      -> en ese directorio
#   KEEP_DAYS=14 ./backup.sh /ruta    -> ademas borra copias de mas de 14 dias
#
# Para la app durante la copia (la base de datos SQLite queda consistente) y la
# vuelve a arrancar siempre, aunque la copia falle.
set -euo pipefail
cd "$(dirname "$0")"

VOLUME="${VOLUME:-nan-open-webui-data}"
SERVICE="${SERVICE:-nan-open-webui}"
HELPER_IMAGE="${HELPER_IMAGE:-alpine:3.22}"
DEST="${1:-./backups}"

if ! docker volume inspect "$VOLUME" >/dev/null 2>&1; then
  echo "[!] No existe el volumen $VOLUME: nada que copiar." >&2
  exit 1
fi

mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
FILE="nan-$(date +%Y-%m-%d_%H%M%S).tar.gz"

WAS_RUNNING=""
if [ -n "$(docker compose ps -q --status running "$SERVICE" 2>/dev/null)" ]; then
  WAS_RUNNING=1
  echo "[*] Parando $SERVICE..."
  docker compose stop "$SERVICE" >/dev/null
fi

restart() {
  if [ -n "$WAS_RUNNING" ]; then
    echo "[*] Arrancando $SERVICE..."
    docker compose start "$SERVICE" >/dev/null
  fi
}
trap restart EXIT

# Los modelos descargados en cache/ (whisper, embeddings, tiktoken) no se copian:
# ocupan cientos de MB y Open WebUI los vuelve a descargar si faltan. El fichero
# queda a nombre del usuario que ejecuta el script y solo legible por el.
echo "[*] Copiando el volumen $VOLUME..."
docker run --rm -v "$VOLUME":/data:ro -v "$DEST":/backup "$HELPER_IMAGE" sh -c '
  tar czf "/backup/$0" -C /data \
    --exclude=./cache/whisper --exclude=./cache/embedding --exclude=./cache/tiktoken . &&
  chown "$1" "/backup/$0" && chmod 600 "/backup/$0"' "$FILE" "$(id -u):$(id -g)"
echo "[OK] Copia creada: $DEST/$FILE ($(du -h "$DEST/$FILE" | cut -f1))"

if [ -n "${KEEP_DAYS:-}" ]; then
  find "$DEST" -maxdepth 1 -name 'nan-*.tar.gz' -mtime +"$KEEP_DAYS" -print -delete \
    | sed 's/^/[-] Borrada por antigua: /'
fi
