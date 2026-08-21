# Changelog

## v0.0.8 - 2026-08-21

- Retira `glm5.2` del catalogo configurado: NaN ya no lo sirve (verificado contra
  `/v1/models`). Quedan como modelos de chat: `qwen3.6`, `deepseek-v4-flash`,
  `mimo-v2.5`, `gemma4`.
- El Compose pasa a usar la imagen propia publicada en GHCR
  (`ghcr.io/686f6c61/nan-open-webui:vX.Y.Z`) en vez de `open-webui:main` con
  `pull_policy: always`: actualizar Open WebUI es ahora una decision deliberada
  (cambiar `OPENWEBUI_IMAGE` en el `.env`), no algo que pasa en cualquier reinicio.
- Seguro por defecto: el puerto se publica en `127.0.0.1` (antes `0.0.0.0`); nuevo
  `WEBUI_BIND=0.0.0.0` en el `.env` para compartirlo en red local.
- Multiusuario: `DEFAULT_USER_ROLE=pending` (los registros nuevos requieren
  aprobacion de un admin) y `BYPASS_MODEL_ACCESS_CONTROL=false` por defecto (se
  respeta el control de modelos por grupo).
- Documenta la configuracion persistente de Open WebUI y anade
  `ENABLE_PERSISTENT_CONFIG` al `.env` (el panel de admin manda sobre el `.env`;
  con `false`, el `.env` manda siempre).
- Compose: healthcheck de SearXNG con `depends_on: condition: service_healthy`,
  rotacion de logs y limites de memoria. Nuevos passthroughs `WEBUI_URL` y
  `CORS_ALLOW_ORIGIN`.
- Nueva guia [PRODUCCION.md](PRODUCCION.md): proxy inverso con HTTPS, backups y
  restauracion, actualizaciones, checklist y runbook de rotacion de la API key.
- README: la seccion "usar sin clonar" pasa a usar la imagen propia (mucho mas
  corta, sin duplicar la configuracion) y se reordena la documentacion de
  multiusuario.

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
