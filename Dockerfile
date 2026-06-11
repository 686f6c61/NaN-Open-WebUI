# nan-open-webui
# Open WebUI preconfigurado para el servidor de inferencia NaN (https://nan.builders),
# que es compatible con la API de OpenAI.
#
# SEGURIDAD: aqui NO va ninguna API key. La key es de cada usuario y se inyecta en
# tiempo de ejecucion via .env / variables de entorno. Nunca se hornea en la imagen.

FROM ghcr.io/open-webui/open-webui:main

# Preconfiguracion (datos NO sensibles): apunta a NaN y desactiva Ollama local.
# La autenticacion (WEBUI_AUTH) NO se hornea aqui: se fija en tiempo de ejecucion
# (docker-compose.yml / docker run), y la imagen base ya la trae activada por defecto.
ENV ENABLE_OPENAI_API="true" \
    OPENAI_API_BASE_URL="https://api.nan.builders/v1" \
    ENABLE_OLLAMA_API="false" \
    WEBUI_NAME="NaN Chat"

# La imagen base ya define ENTRYPOINT, el puerto 8080 y el healthcheck.
LABEL org.opencontainers.image.title="nan-open-webui" \
      org.opencontainers.image.description="Open WebUI preconfigurado para NaN (OpenAI-compatible). API key solo en runtime." \
      org.opencontainers.image.source="https://nan.builders"
