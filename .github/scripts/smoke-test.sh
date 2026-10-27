#!/usr/bin/env bash
# Prueba de humo: levanta el stack con una imagen ya construida y comprueba que
# arranca y queda bien configurado. No llama a NaN: usa una key ficticia.
#
#   .github/scripts/smoke-test.sh nan-open-webui:ci
#
# Cada ejecucion tiene su propio proyecto, volumenes, red y puerto asignado por
# Docker. Puede ejecutarse junto a una instalacion en uso sin tocar sus datos.
set -euo pipefail
cd "$(dirname "$0")/../.."

IMAGE="${1:?Uso: $0 <imagen>}"
EXPECTED="$(sed -n 's/^ARG OPENWEBUI_VERSION=v//p' Dockerfile)"
TEST_DIR="$(mktemp -d)"
PROJECT="nan-smoke-$(basename "$TEST_DIR" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
dc() { docker compose -p "$PROJECT" --env-file "$TEST_DIR/.env" -f "$TEST_DIR/compose.json" "$@"; }
cleanup() {
  dc down -v >/dev/null 2>&1 || true
  # SearXNG cambia el propietario de su configuración. El helper solo monta
  # la copia temporal de esta prueba, para poder borrarla también en Linux.
  if [ -d "$TEST_DIR/searxng" ]; then
    docker run --rm --pull=never --network none --user 0:0 --entrypoint sh \
      -v "$TEST_DIR/searxng:/smoke-config" "$IMAGE" \
      -c 'chmod -R a+rwX /smoke-config' >/dev/null 2>&1 || true
  fi
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

fail() { echo "[FALLO] $*" >&2; dc logs --tail 80 >&2 || true; exit 1; }

cp setup.sh .env.example "$TEST_DIR/"
"$TEST_DIR/setup.sh" >/dev/null
sed -i "s|^NAN_API_KEY=.*|NAN_API_KEY=sk-smoke-test|; s|^OPENWEBUI_IMAGE=.*|OPENWEBUI_IMAGE=${IMAGE}|" "$TEST_DIR/.env"

echo "[*] Validando los compose..."
docker compose --env-file "$TEST_DIR/.env" config -q
COMPOSE_PROFILES=terminal docker compose --env-file "$TEST_DIR/.env" config --format json > "$TEST_DIR/compose.json"
python3 - "$TEST_DIR/compose.json" "$PROJECT" <<'PY'
import json, shutil, sys
from pathlib import Path
p = Path(sys.argv[1])
d = json.loads(p.read_text())
project = sys.argv[2]
d.pop('name', None)
for service in d['services'].values():
    service.pop('container_name', None)
    service.pop('profiles', None)
for section in ('volumes', 'networks'):
    for key, settings in d.get(section, {}).items():
        settings['name'] = f'{project}_{key}'
d['services']['nan-open-webui']['ports'] = [{'target': 8080, 'published': '0', 'host_ip': '127.0.0.1'}]
for mount in d['services']['searxng']['volumes']:
    if mount['type'] == 'bind' and mount['target'] == '/etc/searxng':
        config = p.parent / 'searxng'
        shutil.copytree(mount['source'], config)
        mount['source'] = str(config)
# La prueba valida la API del terminal, sin instalar las herramientas de las skills.
for key in ('OPEN_TERMINAL_PACKAGES', 'OPEN_TERMINAL_PIP_PACKAGES', 'OPEN_TERMINAL_NPM_PACKAGES'):
    d['services']['open-terminal']['environment'][key] = ''
p.write_text(json.dumps(d))
PY
NAN_API_KEY=x WEBUI_SECRET_KEY=x SEARXNG_SECRET=x WEBUI_URL=https://example.com \
  OPEN_TERMINAL_API_KEY=x docker compose --env-file "$TEST_DIR/.env" -f docker-compose.coolify.yml config -q

echo "[*] Arrancando con $IMAGE..."
dc up -d --quiet-pull
BASE="http://$(dc port nan-open-webui 8080)"

for _ in $(seq 1 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/health")" = 200 ] && break
  sleep 5
done
[ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/health")" = 200 ] \
  || fail "Open WebUI no responde en /health"
echo "[OK] /health"

VERSION="$(curl -s "$BASE/api/version" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
[ "$VERSION" = "$EXPECTED" ] || fail "version de Open WebUI '$VERSION', se esperaba '$EXPECTED'"
echo "[OK] Open WebUI $VERSION"

ENV_DUMP="$(dc exec -T nan-open-webui env)"
for kv in OPENAI_API_BASE_URL=https://api.nan.builders/v1 IMAGE_GENERATION_MODEL=qwen-image-2.1 \
          IMAGE_EDIT_MODEL=flux-2-klein RAG_RERANKING_MODEL=rerank RAG_EMBEDDING_BATCH_SIZE=32 \
          ENABLE_COMMUNITY_SHARING=false ENABLE_TOOL_SEARCH=true; do
  grep -qx "$kv" <<<"$ENV_DUMP" || fail "falta $kv en el contenedor"
done
grep -q '^DEFAULT_MODEL_METADATA=.*"usage":true' <<<"$ENV_DUMP" \
  || fail "DEFAULT_MODEL_METADATA sin la capacidad usage (las analiticas marcarian 0 tokens)"
grep -q '^DEFAULT_MODEL_METADATA=.*"builtinTools":{"calendar":false' <<<"$ENV_DUMP" \
  || fail "DEFAULT_MODEL_METADATA sin el recorte de herramientas integradas"
grep -q '^DEFAULT_MODEL_METADATA=.*"terminalId":"open-terminal"' <<<"$ENV_DUMP" \
  || fail "DEFAULT_MODEL_METADATA sin el terminal por defecto"
grep -q '^TOOL_SEARCH_ALWAYS_LOADED=.*run_command' <<<"$ENV_DUMP" \
  || fail "TOOL_SEARCH_ALWAYS_LOADED sin las herramientas del terminal"
echo "[OK] configuracion de NaN"

# Configuracion efectiva en una instalacion nueva (lo que Open WebUI guarda en su base
# de datos al primer arranque), consultada con una cuenta admin creada para la prueba.
TOKEN="$(curl -s "$BASE/api/v1/auths/signup" -H 'Content-Type: application/json' \
  -d '{"name":"smoke","email":"smoke@example.com","password":"smoke-test-123"}' \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
[ -n "$TOKEN" ] || fail "no se pudo crear la cuenta admin de prueba"
api() { curl -s "$BASE$1" -H "Authorization: Bearer $TOKEN"; }
[ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/auths/signup" -H 'Content-Type: application/json' \
  -d '{"name":"otro","email":"otro@example.com","password":"smoke-test-123"}')" = 403 ] \
  || fail "el registro sigue abierto tras crear el admin (ENABLE_SIGNUP)"
api /api/v1/chats/config | grep -q '"ENABLE_TOOL_SEARCH":true' || fail "Tool Search no queda activada"
MODELS_CFG="$(api /api/v1/configs/models)"
grep -q '"usage":true' <<<"$MODELS_CFG" || fail "la capacidad usage no queda activada"
grep -q '"calendar":false' <<<"$MODELS_CFG" || fail "el recorte de herramientas no queda aplicado"
grep -q '"DEFAULT_MODELS":"deepseek-v4-flash"' <<<"$MODELS_CFG" || fail "el modelo por defecto no es deepseek-v4-flash"
TASK_CFG="$(api /api/v1/tasks/config)"
grep -q '"TASK_MODEL_EXTERNAL":"deepseek-v4-flash"' <<<"$TASK_CFG" || fail "el modelo de tareas no es deepseek-v4-flash"
grep -q '"reasoning_effort":"none"' <<<"$TASK_CFG" || fail "las tareas siguen razonando"
api /api/v1/images/config | grep -q '"IMAGE_GENERATION_MODEL":"qwen-image-2.1"' || fail "el modelo de imagen no es qwen-image-2.1"
api /api/v1/retrieval/embedding | grep -q '"RAG_EMBEDDING_BATCH_SIZE":32' || fail "el lote de embeddings no es 32"
echo "[OK] configuracion efectiva en instalacion nueva"

dc exec -T nan-open-webui curl -sf "http://searxng:8080/search?q=test&format=json" >/dev/null \
  || fail "SearXNG no devuelve JSON"
echo "[OK] SearXNG responde en JSON"

dc exec -T open-terminal python - < .github/scripts/smoke-terminal.py

echo "[OK] Prueba de humo superada"
