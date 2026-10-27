#!/usr/bin/env bash
# Comprueba las imágenes upstream y propone cambios en una rama propia.
# DRY_RUN=1 .github/scripts/update-app.sh <openwebui|searxng|terminal>
# El modo de prueba no modifica archivos, Git ni GitHub.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
APP="${1:?Uso: $0 <openwebui|searxng|terminal>}"
DRY_RUN="${DRY_RUN:-0}"
WORK_ROOT=""
WORK_TREE=""
die() { echo "[FALLO] $*" >&2; exit 1; }
case "$DRY_RUN" in 0|1) ;; *) die "DRY_RUN debe ser 0 o 1" ;; esac

cleanup() {
  local status=$?
  trap - EXIT
  if [ -n "$WORK_TREE" ]; then
    git -C "$ROOT" worktree remove --force "$WORK_TREE" >/dev/null 2>&1 || status=1
  fi
  if [ -n "$WORK_ROOT" ]; then rm -rf "$WORK_ROOT"; fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# El token lo lee gh desde el entorno; nunca forma parte de la URL ni de los argumentos.
git_auth() { git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"; }
fetch_json() { curl --fail --silent --show-error --connect-timeout 10 --max-time 30 --retry 2 "$1"; }
valid_semver() { [[ "$1" =~ ^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; }
valid_digest() { [[ "$1" =~ ^sha256:[0-9a-f]{64}$ ]]; }

case "$APP" in
  openwebui)
    modo_issue=0
    nombre="Open WebUI"
    enlace_notas="https://github.com/open-webui/open-webui/releases"
    TARGET_FILES=(Dockerfile)
    ;;
  searxng)
    modo_issue=0
    nombre="SearXNG"
    enlace_notas="https://github.com/searxng/searxng/commits/master/"
    TARGET_FILES=(docker-compose.yml docker-compose.coolify.yml .env.example README.md)
    ;;
  terminal)
    modo_issue=0
    nombre="Open Terminal"
    enlace_notas="https://github.com/open-webui/open-terminal/releases"
    TARGET_FILES=(docker-compose.yml docker-compose.coolify.yml)
    ;;
  *) die "App desconocida: usa openwebui, searxng o terminal" ;;
esac

if [ "$DRY_RUN" = 0 ] && [ -n "$(git status --porcelain)" ]; then
  die "El árbol de trabajo tiene cambios; no se modifica ni se publica nada"
fi

read_current() {
  case "$APP" in
    openwebui)
      version_actual="$(sed -n 's/^ARG OPENWEBUI_VERSION=//p' Dockerfile)"
      digest_actual="$(sed -n 's/^ARG OPENWEBUI_DIGEST=//p' Dockerfile)"
      if ! valid_semver "$version_actual" || ! valid_digest "$digest_actual"; then
        die "Versión o digest actual de Open WebUI no válidos"
      fi
      ;;
    searxng)
      version_actual="$(grep -m1 'SEARXNG_IMAGE:-searxng/searxng:' docker-compose.yml | sed -E 's|.*searxng/searxng:([^"@}]+).*|\1|')"
      [[ "$version_actual" =~ ^20[0-9]{2}\.[0-9]{2}\.[0-9]{2}-[0-9a-f]+$ ]] || die "Tag actual de SearXNG no válido"
      ;;
    terminal)
      version_actual="$(grep -m1 'ghcr.io/open-webui/open-terminal:' docker-compose.yml | sed -E 's|.*open-terminal:([^"@}]+).*|\1|')"
      valid_semver "$version_actual" || die "Versión actual de Open Terminal no válida"
      ;;
  esac
}

resolve_latest() {
  case "$APP" in
    openwebui)
      VERSION_NUEVA="$(fetch_json "https://api.github.com/repos/open-webui/open-webui/releases/latest" | jq -er '.tag_name')"
      valid_semver "$VERSION_NUEVA" || die "Tag upstream de Open WebUI no válido"
      local token headers
      token="$(fetch_json "https://ghcr.io/token?scope=repository:open-webui/open-webui:pull" | jq -er '.token | select(type == "string" and length > 0)')"
      [[ "$token" =~ ^[A-Za-z0-9._~+/=-]+$ ]] || die "Token de lectura de GHCR no válido"
      # Es un token anónimo de lectura pública; tampoco se escribe en un archivo.
      headers="$(printf 'header = "Authorization: Bearer %s"\n' "$token" |
        curl --config - --fail --silent --show-error --connect-timeout 10 --max-time 30 --retry 2 -D - -o /dev/null \
          -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
          "https://ghcr.io/v2/open-webui/open-webui/manifests/$VERSION_NUEVA")"
      DIGEST_NUEVO="$(printf '%s\n' "$headers" | tr -d '\r' | awk 'tolower($1)=="docker-content-digest:"{print $2}')"
      valid_digest "$DIGEST_NUEVO" || die "Digest upstream de Open WebUI no válido"
      ;;
    searxng)
      VERSION_NUEVA="$(fetch_json "https://hub.docker.com/v2/repositories/searxng/searxng/tags?page_size=100" |
        jq -er '[.results[] | select(.name | test("^20[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}-[0-9a-f]+$"))] | sort_by([.name[0:10], .last_updated]) | last | .name // empty')"
      [[ "$VERSION_NUEVA" =~ ^20[0-9]{2}\.[0-9]{2}\.[0-9]{2}-[0-9a-f]+$ ]] || die "Tag upstream de SearXNG no válido"
      ;;
    terminal)
      local tag
      tag="$(fetch_json "https://api.github.com/repos/open-webui/open-terminal/releases/latest" | jq -er '.tag_name')"
      valid_semver "$tag" || die "Tag upstream de Open Terminal no válido"
      VERSION_NUEVA="${tag#v}"
      ;;
  esac
}

needs_update() {
  if [ "$APP" = searxng ]; then
    [[ "${VERSION_NUEVA:0:10}" < "${version_actual:0:10}" ]] && return 1
  else
    local current="${version_actual#v}" latest="${VERSION_NUEVA#v}"
    if [ "$current" != "$latest" ] && [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | head -n1)" = "$latest" ]; then
      return 1
    fi
  fi
  [ "$version_actual" != "$VERSION_NUEVA" ] ||
    { [ "$APP" = openwebui ] && [ "$digest_actual" != "$DIGEST_NUEVO" ]; }
}

apply_update() {
  case "$APP" in
    openwebui)
      sed -i -e "s|^ARG OPENWEBUI_VERSION=.*|ARG OPENWEBUI_VERSION=$VERSION_NUEVA|" \
        -e "s|^ARG OPENWEBUI_DIGEST=.*|ARG OPENWEBUI_DIGEST=$DIGEST_NUEVO|" Dockerfile
      ;;
    searxng)
      sed -i -E 's|searxng/searxng:[^"@` }]+|searxng/searxng:'"$VERSION_NUEVA"'|g' "${TARGET_FILES[@]}"
      ;;
    terminal)
      sed -i -E 's|ghcr.io/open-webui/open-terminal:[^"@` }]+|ghcr.io/open-webui/open-terminal:'"$VERSION_NUEVA"'|g' "${TARGET_FILES[@]}"
      ;;
  esac
}

read_current
resolve_latest
echo "[*] $nombre: actual $version_actual / upstream $VERSION_NUEVA"
if ! needs_update; then
  echo "[OK] $nombre ya está al día; no se propone una bajada de versión"
  exit 0
fi
if [ "$DRY_RUN" = 1 ]; then
  echo "[DRY_RUN] Se propondría actualizar $nombre a $VERSION_NUEVA"
  [ "$APP" != openwebui ] || echo "[DRY_RUN] Digest del índice: $DIGEST_NUEVO"
  printf '[DRY_RUN] Archivo previsto: %s\n' "${TARGET_FILES[@]}"
  exit 0
fi

: "${GH_TOKEN:?Falta GH_TOKEN}"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "Repositorio no válido"
REPO_URL="https://github.com/$REPO.git"
base_branch="$(gh repo view "$REPO" --json defaultBranchRef --jq .defaultBranchRef.name)"
git check-ref-format --branch "$base_branch" >/dev/null
git_auth fetch --no-tags "$REPO_URL" "$base_branch"
base_sha="$(git rev-parse FETCH_HEAD)"

WORK_ROOT="$(mktemp -d)"
WORK_TREE="$WORK_ROOT/tree"
git worktree add --detach "$WORK_TREE" "$base_sha" >/dev/null
cd "$WORK_TREE"
# Una actualización concurrente de main puede haber resuelto ya el cambio.
read_current
if ! needs_update; then echo "[OK] El cambio ya está en la rama base"; exit 0; fi

WORK_BODY="$WORK_ROOT/body.md"
if [ "$modo_issue" = 1 ]; then
  title="Actualizar $nombre manualmente: hay imagen nueva ($VERSION_NUEVA)"
  existing="$(gh issue list --repo "$REPO" --state open --json title,url --limit 100 |
    jq -r --arg title "$title" '.[] | select(.title == $title) | .url')"
  if [ -n "$existing" ]; then echo "[OK] La issue ya existe: $existing"; exit 0; fi
  printf 'Hay una imagen upstream nueva de %s (%s). El código local requiere revisión manual.\n\nNotas: %s\n' \
    "$nombre" "$VERSION_NUEVA" "$enlace_notas" > "$WORK_BODY"
  gh issue create --repo "$REPO" --title "$title" --body-file "$WORK_BODY"
  exit 0
fi

rama="auto/subir-$APP-$VERSION_NUEVA"
if [ "$APP" = openwebui ]; then rama="$rama-${DIGEST_NUEVO:7:12}"; fi
git check-ref-format --branch "$rama" >/dev/null
existing="$(gh pr list --repo "$REPO" --head "$rama" --state all --limit 1 --json url --jq '.[0].url // empty')"
if [ -n "$existing" ]; then echo "[OK] Este cambio ya tiene PR: $existing"; exit 0; fi
if git_auth ls-remote --exit-code "$REPO_URL" "refs/heads/$rama" >/dev/null; then
  die "La rama $rama ya existe sin PR; revisarla antes de continuar"
else
  status=$?
  [ "$status" = 2 ] || die "No se pudo comprobar la rama remota"
fi

apply_update
git diff --quiet -- "${TARGET_FILES[@]}" && die "No se modificaron los archivos previstos"
git diff --stat -- "${TARGET_FILES[@]}"
git add -- "${TARGET_FILES[@]}"
git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -m "Actualizar $nombre a $VERSION_NUEVA"
git_auth push "$REPO_URL" "HEAD:refs/heads/$rama"

{
  printf 'Actualiza %s de %s a %s.\n' "$nombre" "$version_actual" "$VERSION_NUEVA"
  if [ "$APP" = openwebui ]; then
    printf '\nVersión y digest del índice se revisan juntos. Digest anterior: %s. Nuevo: %s.\n' "$digest_actual" "$DIGEST_NUEVO"
  fi
  printf '\nLa release estable sigue requiriendo CHANGELOG y un tag propio. El merge puede publicar las imágenes de prueba main y sha.\n\nNotas: %s\n' "$enlace_notas"
  printf '\nSi se ha utilizado GITHUB_TOKEN, aprobar la ejecución pendiente de la CI o ejecutar docker-publish.yml manualmente sobre esta rama.\n'
  printf '\nPropuesta generada automáticamente; requiere revisión antes de integrarla.\n'
} > "$WORK_BODY"
gh pr create --repo "$REPO" --base "$base_branch" --head "$rama" --title "Actualizar $nombre a $VERSION_NUEVA" --body-file "$WORK_BODY"
