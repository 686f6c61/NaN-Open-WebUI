#!/usr/bin/env bash
# Prueba de humo: levanta el stack con una imagen ya construida y comprueba que
# arranca y queda bien configurado. No llama a NaN: usa una key ficticia.
#
#   .github/scripts/smoke-test.sh nan-open-webui:ci
#
# OJO: usa los nombres de contenedor y volumen del compose local y los borra al
# terminar (docker compose down -v). Pensado para CI; no lo lances junto a una
# instalacion en uso.
set -euo pipefail
cd "$(dirname "$0")/../.."

IMAGE="${1:?Uso: $0 <imagen>}"
PORT="${WEBUI_PORT:-3000}"
EXPECTED="$(sed -n 's/^ARG OPENWEBUI_VERSION=v//p' Dockerfile)"

fail() { echo "[FALLO] $*" >&2; docker compose logs --tail 80 >&2 || true; exit 1; }

[ ! -f .env ] || fail ".env ya existe: este script crea uno propio"
# Al terminar hace 'down -v': nunca sobre un volumen con datos de una instalacion real.
for v in nan-open-webui-data nan-open-terminal-data; do
  ! docker volume inspect "$v" >/dev/null 2>&1 || fail "el volumen $v ya existe: no lo ejecutes junto a una instalacion en uso"
done
trap 'docker compose down -v >/dev/null 2>&1 || true; rm -f .env' EXIT

./setup.sh >/dev/null
sed -i "s|^NAN_API_KEY=.*|NAN_API_KEY=sk-smoke-test|; s|^OPENWEBUI_IMAGE=.*|OPENWEBUI_IMAGE=${IMAGE}|" .env

echo "[*] Validando los compose..."
docker compose config -q
COMPOSE_PROFILES=terminal docker compose config -q
NAN_API_KEY=x WEBUI_SECRET_KEY=x SEARXNG_SECRET=x WEBUI_URL=https://example.com \
  OPEN_TERMINAL_API_KEY=x docker compose -f docker-compose.coolify.yml config -q

echo "[*] Arrancando con $IMAGE..."
docker compose up -d --quiet-pull

for _ in $(seq 1 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/health")" = 200 ] && break
  sleep 5
done
[ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/health")" = 200 ] \
  || fail "Open WebUI no responde en /health"
echo "[OK] /health"

VERSION="$(curl -s "http://127.0.0.1:${PORT}/api/version" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
[ "$VERSION" = "$EXPECTED" ] || fail "version de Open WebUI '$VERSION', se esperaba '$EXPECTED'"
echo "[OK] Open WebUI $VERSION"

ENV_DUMP="$(docker exec nan-open-webui env)"
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
BASE="http://127.0.0.1:${PORT}"
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

docker exec nan-open-webui curl -sf "http://searxng:8080/search?q=test&format=json" >/dev/null \
  || fail "SearXNG no devuelve JSON"
echo "[OK] SearXNG responde en JSON"

echo "[OK] Prueba de humo superada"
