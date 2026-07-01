# Changelog

## v0.0.5 - 2026-07-01

- Usa la imagen oficial `ghcr.io/open-webui/open-webui:main` en Docker Compose para recibir la ultima Open WebUI con `docker compose up -d`.
- Anade `pull_policy: always` para Open WebUI y SearXNG.
- Anade `glm5.2` al portfolio de modelos de chat/coding.
- Oculta `flux-2-klein` del selector de chat mediante `OPENAI_API_CONFIGS`; queda reservado para generacion/edicion de imagenes.
- Corrige SearXNG fijando un `secret_key` no predeterminado y manteniendo salida JSON para busqueda web.
- Documenta como activar generacion de imagenes desde el menu de integraciones del chat.
