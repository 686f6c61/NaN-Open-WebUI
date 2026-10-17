#!/usr/bin/env bash
# Arranque de la imagen: aplica (o retira) el logo de la comunidad NaN y lanza Open WebUI.
#
# NAN_LOGO=true (por defecto) sustituye el favicon, el logo y la pantalla de carga de
# Open WebUI por el simbolo de Helmcode. NAN_LOGO=false deja los de Open WebUI.
#
# OJO: la licencia de Open WebUI no permite cambiar su logo en instalaciones de mas de
# 50 usuarios en 30 dias sin su permiso. En ese caso, usa NAN_LOGO=false.
set -e

STATIC=/app/build/static
ICONS="favicon.png favicon-96x96.png favicon.ico favicon.svg apple-touch-icon.png
       web-app-manifest-192x192.png web-app-manifest-512x512.png logo.png splash.png
       splash-dark.png"

if [ "${NAN_LOGO:-true}" = "true" ]; then
	src=/app/nan-branding/logo
else
	src=/app/nan-branding/original
fi

for f in $ICONS; do
	cp "$src/$f" "$STATIC/$f"
done
# Open WebUI sirve tambien /favicon.png desde la raiz del frontend.
cp "$src/favicon.png" /app/build/favicon.png

# Foto de perfil de quien no tiene foto (NAN_AVATAR=true): el icono de NaN en lugar de
# la silueta gris. Es la que queda al pulsar "Eliminar" en Ajustes > Cuenta.
if [ "${NAN_AVATAR:-true}" = "true" ]; then
	avatar=/app/nan-branding/logo/user.png
else
	avatar=/app/nan-branding/original/user.png
fi
cp "$avatar" "$STATIC/user.png"
cp "$avatar" /app/build/user.png

# Plantilla de RAG (respuestas con documentos y busquedas): la de NaN, salvo que el
# .env traiga RAG_TEMPLATE propia. Va en fichero porque ocupa varias lineas.
if [ -z "${RAG_TEMPLATE:-}" ]; then
	export RAG_TEMPLATE="$(cat /app/nan-branding/rag-template.txt)"
fi

cd /app/backend
exec bash start.sh "$@"
