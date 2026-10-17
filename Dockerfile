# nan-open-webui
# Open WebUI preconfigurado para el servidor de inferencia NaN (https://nan.builders),
# que es compatible con la API de OpenAI.
#
# SEGURIDAD: aqui NO va ninguna API key. La key es de cada usuario y se inyecta en
# tiempo de ejecucion via .env / variables de entorno. Nunca se hornea en la imagen.

# Version de Open WebUI fijada por tag y digest: cada build de la misma version
# produce la misma imagen. Para subir de version, cambia ambos valores juntos
# (el digest se obtiene con: docker buildx imagetools inspect ghcr.io/open-webui/open-webui:vX.Y.Z).
ARG OPENWEBUI_VERSION=v0.12.3
ARG OPENWEBUI_DIGEST=sha256:a537bbe1e6b428820f52ed4a029d7fff97062e24d5cf32c365fba36fd0542def
FROM ghcr.io/open-webui/open-webui:${OPENWEBUI_VERSION}@${OPENWEBUI_DIGEST}

# Marca de la comunidad NaN: insignia "Built with NaN" y simbolo de Helmcode en la
# pantalla de entrada. Usa los puntos de extension que Open WebUI trae vacios
# (loader.js y custom.css) y que copia a /static al arrancar, asi que se mantiene al
# actualizar. Solo anade: la marca de Open WebUI no se toca (ver su LICENSE).
COPY branding/loader.js branding/custom.css /app/build/static/
COPY branding/helmcode-symbol-color.svg branding/helmcode-symbol-white.svg /app/build/static/branding/

# Logo de la comunidad (NAN_LOGO, activado por defecto): favicon, logo y pantalla de
# carga con el simbolo de Helmcode. Se guardan tambien los originales de Open WebUI
# para poder volver a ellos con NAN_LOGO=false. Lo aplica branding/start.sh en cada
# arranque. Ver la nota de licencia en el README.
COPY branding/logo/ /app/nan-branding/logo/
COPY branding/start.sh branding/rag-template.txt /app/nan-branding/
RUN set -eu; mkdir -p /app/nan-branding/original; \
    for f in favicon.png favicon-96x96.png favicon.ico favicon.svg apple-touch-icon.png \
             web-app-manifest-192x192.png web-app-manifest-512x512.png logo.png splash.png \
             splash-dark.png user.png; do cp "/app/build/static/$f" /app/nan-branding/original/; done

# Preconfiguracion (datos NO sensibles): apunta a NaN y desactiva Ollama local.
# La autenticacion (WEBUI_AUTH) NO se hornea aqui: se fija en tiempo de ejecucion
# (docker-compose.yml / docker run), y la imagen base ya la trae activada por defecto.
ENV ENABLE_OPENAI_API="true" \
    OPENAI_API_BASE_URL="https://api.nan.builders/v1" \
    OPENAI_API_CONFIGS='{"0":{"enable":true,"model_ids":["deepseek-v4-flash","glm5.3-flash","mimo-v2.6-flash","qwen3.8-flash","gemma4","qwen3.6"]}}' \
    DEFAULT_MODELS="deepseek-v4-flash" \
    TASK_MODEL_EXTERNAL="deepseek-v4-flash" \
    TASK_MODEL_PARAMS='{"reasoning_effort":"none"}' \
    MODEL_ORDER_LIST='["deepseek-v4-flash","glm5.3-flash","mimo-v2.6-flash","qwen3.8-flash","gemma4","qwen3.6"]' \
    ENABLE_CONTEXT_COMPACTION="true" \
    PDF_EXTRACT_IMAGES="true" \
    CONTEXT_COMPACTION_MODEL="deepseek-v4-flash" \
    ENABLE_TOOL_PERMISSIONS="true" \
    ENABLE_SUBAGENTS="true" \
    SUBAGENTS_BACKGROUND_ENABLED="true" \
    SUBAGENTS_MAX_CONCURRENT="20" \
    SUBAGENTS_MAX_ASYNC="20" \
    SUBAGENTS_MAX_ITERATIONS="30" \
    SUBAGENTS_MAX_OUTPUT="30000" \
    ENABLE_TOOL_SEARCH="true" \
    TOOL_SEARCH_ALWAYS_LOADED="run_command,get_process_status,read_file,write_file,replace_file_content,display_file,list_files,view_skill,read_skill_file,search_web,fetch_url,generate_image,edit_image" \
    DEFAULT_MODEL_METADATA='{"terminalId":"open-terminal","defaultFeatureIds":["web_search","image_generation"],"capabilities":{"file_context":true,"vision":true,"file_upload":true,"web_search":true,"image_generation":true,"code_interpreter":true,"terminal":true,"citations":true,"status_updates":true,"usage":true,"memory":true,"builtin_tools":true},"builtinTools":{"calendar":false,"automations":false,"tasks":false,"notes":false,"channels":false}}' \
    ENABLE_IMAGE_GENERATION="true" \
    IMAGE_GENERATION_ENGINE="openai" \
    IMAGE_GENERATION_MODEL="qwen-image-2.1" \
    IMAGE_SIZE="1024x1024" \
    IMAGES_OPENAI_API_BASE_URL="https://api.nan.builders/v1" \
    IMAGES_OPENAI_PARAMS='{"size":"1024x1024"}' \
    ENABLE_IMAGE_EDIT="true" \
    IMAGE_EDIT_ENGINE="openai" \
    IMAGE_EDIT_MODEL="flux-2-klein" \
    IMAGE_EDIT_SIZE="1024x1024" \
    IMAGES_EDIT_OPENAI_API_BASE_URL="https://api.nan.builders/v1" \
    RAG_EMBEDDING_ENGINE="openai" \
    RAG_OPENAI_API_BASE_URL="https://api.nan.builders/v1" \
    RAG_EMBEDDING_MODEL="qwen3-embedding" \
    RAG_EMBEDDING_BATCH_SIZE="32" \
    RAG_EMBEDDING_CONCURRENT_REQUESTS="2" \
    RAG_RERANKING_ENGINE="external" \
    RAG_EXTERNAL_RERANKER_URL="https://api.nan.builders/v1/rerank" \
    RAG_RERANKING_MODEL="rerank" \
    AUDIO_TTS_ENGINE="openai" \
    AUDIO_TTS_OPENAI_API_BASE_URL="https://api.nan.builders/v1" \
    AUDIO_TTS_MODEL="kokoro" \
    AUDIO_TTS_VOICE="ef_dora" \
    ENABLE_OLLAMA_API="false" \
    ENABLE_COMMUNITY_SHARING="false" \
    WEBUI_NAME="NaN Chat"

# La imagen base ya define ENTRYPOINT, el puerto 8080 y el healthcheck.
LABEL org.opencontainers.image.title="nan-open-webui" \
      org.opencontainers.image.description="Open WebUI preconfigurado para NaN (OpenAI-compatible). API key solo en runtime." \
      org.opencontainers.image.source="https://github.com/686f6c61/NaN-Open-WebUI"

CMD ["bash", "/app/nan-branding/start.sh"]
