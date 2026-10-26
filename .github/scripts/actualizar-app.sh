#!/usr/bin/env bash
# Actualiza la version de una de las apps upstream que usa este repo y abre un
# PR con el cambio (o una issue si la app tiene codigo modificado por el autor).
#
#   GH_TOKEN=... .github/scripts/actualizar-app.sh <openwebui|searxng|terminal>
#
# Apps soportadas (todas config-only: ninguna modifica codigo fuente upstream):
#   openwebui  imagen base del Dockerfile, fijada por version + digest juntos
#   searxng    tag por fecha en los compose, en .env.example y en el README
#   terminal   tag semver (sin la "v") en los compose
#
# Cada app lleva el flag modo_issue: si pasara a ser un fork con codigo
# modificado (Dockerfile o build propio en el compose), cambiarlo a 1: subir
# version dejara de ser cambiar dos lineas, y en vez de PR el script abrira
# una issue pidiendo la actualizacion manual.
#
# Para probar sin tocar git ni GitHub: DRY_RUN=1 .github/scripts/actualizar-app.sh <app>
set -euo pipefail
cd "$(dirname "$0")/../.."

APP="${1:?Uso: $0 <openwebui|searxng|terminal>}"
DRY_RUN="${DRY_RUN:-0}"

die() { echo "[FALLO] $*" >&2; exit 1; }

# --- Configuracion por app ---------------------------------------------------
case "$APP" in
  openwebui)
    modo_issue=0
    nombre="Open WebUI"
    enlace_notas="https://github.com/open-webui/open-webui/releases"
    ;;
  searxng)
    modo_issue=0
    nombre="SearXNG"
    enlace_notas="https://github.com/searxng/searxng/releases"
    ;;
  terminal)
    modo_issue=0
    nombre="Open Terminal"
    enlace_notas="https://github.com/open-webui/open-terminal/releases"
    ;;
  *) die "App desconocida: $APP (usa openwebui, searxng o terminal)" ;;
esac

# --- Version actual en el repo ----------------------------------------------
version_actual_openwebui() { grep -m1 '^ARG OPENWEBUI_VERSION=' Dockerfile | cut -d= -f2; }
version_actual_searxng() {
  grep -m1 'SEARXNG_IMAGE:-searxng/searxng:' docker-compose.yml | sed -E 's|.*searxng/searxng:([^"}]+).*|\1|'
}
version_actual_terminal() {
  grep -m1 'ghcr.io/open-webui/open-terminal:' docker-compose.yml | sed -E 's|.*open-terminal:([^"}]+).*|\1|'
}

# --- Ultima version upstream (escriben VERSION_NUEVA y DIGEST_NUEVO si aplica)
resolver_openwebui() {
  VERSION_NUEVA="$(curl -sf "https://api.github.com/repos/open-webui/open-webui/releases/latest" | jq -r .tag_name)"
  case "$VERSION_NUEVA" in v[0-9]*.[0-9]*.[0-9]*) ;; *) die "Tag inesperado de Open WebUI: $VERSION_NUEVA" ;; esac
  # El digest del indice multi-arquitectura es el mismo que reporta
  # 'docker buildx imagetools inspect', pero sin necesitar Docker.
  local token
  token="$(curl -sf "https://ghcr.io/token?scope=repository:open-webui/open-webui:pull" | jq -r .token)"
  DIGEST_NUEVO="$(curl -sf -D - -o /dev/null \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json" \
    "https://ghcr.io/v2/open-webui/open-webui/manifests/${VERSION_NUEVA}" \
    | tr -d '\r' | awk 'tolower($1)=="docker-content-digest:"{print $2}')"
  case "$DIGEST_NUEVO" in sha256:*) ;; *) die "No se obtuvo el digest de ${VERSION_NUEVA}" ;; esac
}

resolver_searxng() {
  # SearXNG publica tags de fecha (varios algunos dias): se coge el mas
  # reciente de Docker Hub, excluyendo 'latest' y cualquier tag sin forma
  # de fecha.
  VERSION_NUEVA="$(curl -sf "https://hub.docker.com/v2/repositories/searxng/searxng/tags?page_size=100" \
    | jq -r '[.results[] | select(.name | test("^20[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}-[0-9a-f]+$"))] | sort_by(.last_updated) | reverse | .[0].name')"
  case "$VERSION_NUEVA" in 20[0-9][0-9].*-*) ;; *) die "Tag inesperado de SearXNG: ${VERSION_NUEVA:-vacio}" ;; esac
}

resolver_terminal() {
  # La release se etiqueta vX.Y.Z pero la imagen usa el tag sin la "v".
  local tag
  tag="$(curl -sf "https://api.github.com/repos/open-webui/open-terminal/releases/latest" | jq -r .tag_name)"
  case "$tag" in v[0-9]*.[0-9]*.[0-9]*) ;; *) die "Tag inesperado de Open Terminal: $tag" ;; esac
  VERSION_NUEVA="${tag#v}"
}

# --- Aplicar el cambio -------------------------------------------------------
aplicar_openwebui() {
  sed -i \
    -e "s|^ARG OPENWEBUI_VERSION=.*|ARG OPENWEBUI_VERSION=${VERSION_NUEVA}|" \
    -e "s|^ARG OPENWEBUI_DIGEST=.*|ARG OPENWEBUI_DIGEST=${DIGEST_NUEVO}|" \
    Dockerfile
}

aplicar_searxng() {
  # El backtick y la llave van excluidos para no comerse los delimitadores
  # del compose (`${VAR:-...}`) ni los backticks del README.
  sed -i -E "s|searxng/searxng:[^\"@\` }]+|searxng/searxng:${VERSION_NUEVA}|g" \
    docker-compose.yml docker-compose.coolify.yml .env.example README.md
}

aplicar_terminal() {
  sed -i -E "s|ghcr.io/open-webui/open-terminal:[^\"@ }]+|ghcr.io/open-webui/open-terminal:${VERSION_NUEVA}|g" \
    docker-compose.yml docker-compose.coolify.yml
}

# --- Ejecucion ---------------------------------------------------------------
version_actual="$("version_actual_${APP}")"
[ -n "$version_actual" ] || die "No se pudo leer la version actual de ${APP} del repo"

"resolver_${APP}"
echo "[*] ${nombre}: actual ${version_actual} / upstream ${VERSION_NUEVA}"

if [ "$version_actual" = "$VERSION_NUEVA" ]; then
  echo "[OK] ${nombre} ya esta en la ultima version (${version_actual})"
  exit 0
fi

"aplicar_${APP}"
git diff --quiet -- Dockerfile docker-compose.yml docker-compose.coolify.yml .env.example README.md \
  && die "El cambio no toco nada: revisa los patrones de aplicar_${APP}"
git diff --stat

if [ "$DRY_RUN" = "1" ]; then
  echo "[DRY_RUN] Fin: se habria abierto el PR (o la issue) de ${version_actual} a ${VERSION_NUEVA}"
  git checkout -- .
  exit 0
fi

if [ "$modo_issue" = "1" ]; then
  gh issue create \
    --title "Actualizar ${nombre} manualmente: hay version nueva (${VERSION_NUEVA})" \
    --body "$(cat <<EOF
\`${nombre}\` ha publicado la version **${VERSION_NUEVA}** (actual en el repo: **${version_actual}**), pero este repo modifica su codigo, asi que el cambio automatico de tag no basta y hay que actualizarlo a mano.

Notas de la version: ${enlace_notas}

_Aviso: contenido y codigo generados automaticamente con una IA._
EOF
)"
  exit 0
fi

: "${GH_TOKEN:?Falta GH_TOKEN}"
rama="auto/subir-${APP}-${VERSION_NUEVA}"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git checkout -B "$rama"
git commit -aqm "Subir ${nombre} a ${VERSION_NUEVA}"
git push --force "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "$rama"

{
  echo "Actualiza \`${nombre}\` de **${version_actual}** a **${VERSION_NUEVA}** (hay version nueva upstream)."
  echo
  echo "No publica nada: tras fusionar, la publicacion sigue siendo manual (actualizar CHANGELOG.md y taguear la version propia)."
  echo
  echo "Notas de la version: ${enlace_notas}"
  if [ "$APP" = "openwebui" ]; then
    echo
    echo "Version y digest del Dockerfile actualizados juntos, como pide su cabecera."
  fi
  echo
  echo "---"
  echo
  echo "_Aviso: contenido y codigo generados automaticamente con una IA._"
} > cuerpo-pr.md
gh pr create --head "$rama" --title "Subir ${nombre} a ${VERSION_NUEVA}" --body-file cuerpo-pr.md
rm -f cuerpo-pr.md
