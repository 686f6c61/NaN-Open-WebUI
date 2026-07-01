# Changelog

## v0.0.7 - 2026-07-01

- Elimina el `secret_key` compartido de SearXNG del repo.
- Pasa `SEARXNG_SECRET` desde `.env` y lo genera automaticamente con `./setup.sh`.
- Hace que `./setup.sh` complete secretos faltantes en instalaciones existentes sin tocar `NAN_API_KEY`.

## v0.0.6 - 2026-07-01

- Fuerza `DEFAULT_MODEL_PARAMS={"function_calling":"legacy"}` para que la herramienta **Image** dispare `flux-2-klein` aunque el modelo de chat seleccionado no declare tool calling nativo.
- Desactiva `ENABLE_IMAGE_PROMPT_GENERATION` por defecto para evitar que Open WebUI se quede reescribiendo el prompt con `qwen3.6` antes de generar la imagen.
- Documenta que el selector superior puede seguir en `qwen3.6`; la generacion real sale por la integracion **Image**.

## v0.0.5 - 2026-07-01

- Usa la imagen oficial `ghcr.io/open-webui/open-webui:main` en Docker Compose para recibir la ultima Open WebUI con `docker compose up -d`.
- Anade `pull_policy: always` para Open WebUI y SearXNG.
- Anade `glm5.2` al portfolio de modelos de chat/coding.
- Oculta `flux-2-klein` del selector de chat mediante `OPENAI_API_CONFIGS`; queda reservado para generacion/edicion de imagenes.
- Corrige SearXNG fijando un `secret_key` no predeterminado y manteniendo salida JSON para busqueda web.
- Documenta como activar generacion de imagenes desde el menu de integraciones del chat.
