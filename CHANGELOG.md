# Changelog

## v1.0.0 - 2026-10-17

Primera versión estable. Todo lo de esta entrada está probado con la API real de NaN,
en el navegador y con un smoke test en un Docker limpio.

**Open WebUI 0.11.0 -> 0.12.3.** La imagen v0.0.9 llevaba Open WebUI de finales de
julio (`:main` del 27/07/2026). Desde entonces se han publicado al menos 30 avisos de
seguridad corregidos en 0.11.1 y 0.11.4 (robo de token de sesión por XSS en
previsualizaciones DOCX, citas y enlaces `javascript:`, SSRF por DNS rebinding,
escalada en el proxy de terminales, etc.). Incluye migraciones de base de datos:
**haz backup antes de actualizar** (`./backup.sh`).

> **Si usas la etiqueta `latest`** (por ejemplo con `docker run ...:latest` o un
> actualizador automático como Watchtower), al publicarse esta versión pasarás de
> golpe a Open WebUI 0.12.3 y sus migraciones se aplicarán al arrancar. Haz backup
> antes del siguiente `pull` o fija la versión anterior (`:v0.0.9`) hasta que puedas
> actualizar con calma. Desde esta versión, `latest` solo cambia al publicar una
> release, nunca con cada cambio en `main`.

### Modelos (catálogo oficial de NaN)

- Nuevos en el selector: `glm5.3-flash`, `qwen3.8-flash` y `mimo-v2.6-flash`.
  `mimo-v2.5` desaparece (sustituido por `mimo-v2.6-flash`).
- `deepseek-v4-flash` pasa a ser el modelo por defecto (`DEFAULT_MODELS`), como
  recomienda NaN; `qwen3.6` y `gemma4` siguen como generación anterior.
- `glm5.3` (premium) documentado como opcional. `minimax-h3` aparece en `/v1/models`,
  pero devuelve 401 sin la suscripción adecuada: no se incluye.
- Documentado `reasoning_effort` (`none` .. `max`) con su comportamiento en cada modelo
  y cómo fijarlo por chat, por modelo o para todos con `DEFAULT_MODEL_PARAMS`
  (verificado: `none` da 0 tokens de razonamiento y `high`, 78).

### Herramientas: tool calling nativo

- `DEFAULT_MODEL_PARAMS` pasa de `{"function_calling":"legacy"}` a `{}`: el modelo
  decide por su cuenta cuándo buscar en internet, generar imágenes o consultar
  documentos. Verificado con los seis modelos de chat. `legacy` sigue disponible.

### Imágenes

- **Generación con `qwen-image-2.1`** (más fiel al prompt y con texto legible dentro
  de la imagen, unos 70-100 s) y **edición con `flux-2-klein`** (Qwen no edita).
  Comparativa con el mismo prompt en el README.
- **Corrige un 400 de NaN**: en modo nativo el modelo copia el ejemplo `1536x1024` de
  la herramienta de Open WebUI y Qwen solo admite hasta 1280 px. `IMAGES_OPENAI_PARAMS`
  fija ahora el tamaño a `IMAGE_SIZE`.
- Galería de ejemplos con sus prompts en el README y la guía.

### RAG, voz y búsqueda

- **Reordenado con `rerank` de NaN** (Qwen3-Reranker-8B) y búsqueda híbrida activada.
- **Corrige 429 en búsqueda web y documentos grandes**: Open WebUI mandaba una petición
  de embeddings por fragmento, sin límite de concurrencia, y superaba las 60
  peticiones/min de NaN. Ahora usa lotes de 32 (`RAG_EMBEDDING_BATCH_SIZE`) y 2
  peticiones simultáneas.
- **Búsqueda web en 5 buscadores** (Google CSE, Bing, DuckDuckGo, Yahoo y Yep) en vez
  de uno: antes casi todo salía de Google. DuckDuckGo pasa a su API (`duckduckgo web`),
  porque la variante HTML clásica recibía CAPTCHA siempre.
- Voz por defecto `ef_dora` (español) en lugar de `af_sky`.
- Dictado opcional con `whisper` large-v3 de NaN (`AUDIO_STT_ENGINE=openai`). Probado con
  audio con ruido en `webm/opus` (el formato del navegador): transcribe mejor que el
  whisper local, en unos 2,5 s. Por defecto sigue el local, porque NaN limita whisper a
  10 peticiones/min por key (poco con varios usuarios) y el local no saca el audio de
  tu equipo.

### Consumo

- **Analítica por usuario con tokens**: *Admin > Analíticas* marcaba 0 tokens porque
  Open WebUI solo pide el recuento a NaN si el modelo tiene la capacidad `usage`. Ahora
  viene activada para todos con `DEFAULT_MODEL_METADATA`.
- **Herramienta `consumo_nan`** (`herramientas/consumo_nan.py`): consulta `/v1/usage` y
  compara el consumo del mes de la cuenta con la cuota mensual de cada modelo. Se
  instala desde *Espacio de trabajo > Herramientas* y queda solo para administradores.
- **77 % menos de tokens por mensaje en modo nativo.** Medido con un proxy: Open WebUI
  enviaba 36 herramientas (24.169 caracteres) en cada mensaje, aunque fuera trivial. Ahora
  se apagan las categorías poco usadas (calendario, automatizaciones, tareas, notas y
  canales) con `builtinTools` en `DEFAULT_MODEL_METADATA` y se activa la
  Tool Search (`ENABLE_TOOL_SEARCH=true`, experimental): 7 herramientas y 5.619
  caracteres (medido con las habilidades también apagadas; se dejan activas porque sin
  ellas el modelo no puede leer los ficheros de una skill, y solo suman `create_skill`,
  891 caracteres, a los admins). Probado con búsqueda web e imagen.
- **Tareas internas sin razonamiento.** Títulos, etiquetas y sugerencias van a
  `deepseek-v4-flash` con `TASK_MODEL_PARAMS={"reasoning_effort":"none"}`: medido en la
  generación de títulos de Open WebUI, 1,5-2,3 s y 12 tokens frente a 3,5-6 s y unos
  160 tokens razonando. En 20 títulos seguidos: 20/20, mediana 1,77 s, p90 2,40 s
  (`qwen3.8-flash`, 1,46 s y 2,12 s); `gemma4` sirve como alternativa sin cuota.
- Nueva opción `WEB_FETCH_MAX_CONTENT_LENGTH` para recortar las páginas que lee el modelo
  (sin límite por defecto; se midió una página de 79.585 caracteres).

### Ajustes activados de serie

- **Compactación de contexto** (`ENABLE_CONTEXT_COMPACTION`): al pasar de 80.000
  tokens, Open WebUI resume el historial antiguo con `deepseek-v4-flash`. En las pruebas,
  un encargo largo con el terminal llegó a 134.000 tokens y NaN lo cortó con un 524.
- **Permisos de herramientas** (`ENABLE_TOOL_PERMISSIONS`, experimental): «Acceso
  completo» o «Solicitar aprobación» en el menú de la caja de texto.
- **Subagentes** (`ENABLE_SUBAGENTS`, también en segundo plano): el modelo puede delegar
  tareas en chats propios con herramientas. Hasta 20 a la vez, 30 iteraciones y 30.000
  caracteres de salida. Ojo: NaN admite unas 7 peticiones simultáneas por clave en
  `deepseek-v4-flash`, así que con muchos subagentes a la vez puede responder 429.
- **Orden de modelos** (`MODEL_ORDER_LIST`): deepseek-v4-flash, glm5.3-flash,
  mimo-v2.6-flash, qwen3.8-flash, gemma4 y qwen3.6.
- **OCR de PDF escaneados** (`PDF_EXTRACT_IMAGES`): extrae las imágenes de los PDF para
  que el OCR lea también las páginas que solo son imagen. Probado con un PDF sin texto:
  extrajo «Total a pagar: 1.452,30 euros» exacto.
- **Plantilla de RAG propia** (`branding/rag-template.txt`, cambiable con
  `RAG_TEMPLATE`): prioriza los documentos, copia cifras y fechas exactas, avisa si las
  fuentes se contradicen o falta el dato, separa lo que no sale de los documentos y
  responde en español de España.

### Open Terminal

- Nuevo servicio `open-terminal` en el compose local tras el perfil `terminal`
  (`COMPOSE_PROFILES=terminal`), activado en el `.env.example`. El modelo puede crear y ejecutar
  ficheros (probado: generar un Word con tabla y revisarlo). Solo para admins salvo
  permiso expreso, sin puertos publicados y con clave obligatoria (401 sin ella).
- `setup.sh` genera `OPEN_TERMINAL_API_KEY` y la copia en la línea de conexión.
- `OPEN_TERMINAL_PACKAGES`, `OPEN_TERMINAL_PIP_PACKAGES` y `OPEN_TERMINAL_NPM_PACKAGES`
  para paquetes fijos (lo que el modelo instala con `pip` ya persiste en el volumen).

### Skills del terminal

39 skills precargadas en `skills/`, disponibles sin activar nada. Cada una se probó
desde el chat y solo se quedaron las que el modelo usa de verdad; origen, commit,
licencia y resultado de cada prueba en `skills/README.md`.

| Para qué | Skills |
| --- | --- |
| Webs y diseño | `design-taste-frontend`, `theme-factory`, `canvas-design` |
| Documentos | `minimax-docx` (Word), `minimax-pdf` (PDF), `pptx-generator` (PowerPoint), `minimax-xlsx` (Excel) |
| Presentaciones web | `frontend-slides` |
| Diagramas | `drawio`, `archify` |
| Textos | `copywriting`, `copy-editing`, `humanizer`, `social`, `emails`, `content-strategy`, `meeting-notes` y `escritura-es` (propia: español de España) |
| Vídeo | `hyperframes` y 20 más de HyperFrames |

- Licencias MIT o Apache 2.0, cada carpeta con la suya. Descartadas tras probarlas
  porque el modelo no las usaba: `imagemagick`, `report-generator`,
  `data-visualization`, `analyze`, `explore-data`, `pretty-mermaid`,
  `redesign-existing-projects`, `minimalist-ui` y `full-output-enforcement`.
- **Vídeo con HyperFrames** (Apache 2.0): sus 21 skills van en `skills/` y el CLI
  `hyperframes@0.8.168`, la misma versión, viene instalado en el terminal. Probado desde
  cero con deepseek-v4-flash: un vídeo de 15 s en 1080p, completo, en 17 minutos.
  El terminal arranca con `HYPERFRAMES_SKIP_SKILLS=1` (si no, el CLI reinstala las skills
  en `~/.claude/skills` y salen duplicadas), sin telemetría (`HYPERFRAMES_NO_TELEMETRY`,
  `DO_NOT_TRACK`) y sin consultar versiones nuevas en cada comando.
- El terminal instala de serie Chromium, tipografías Liberation y Noto, `pptxgenjs` y
  `hyperframes`.
- **Corrige un bucle de reinicios de Open Terminal:** `OPEN_TERMINAL_NPM_PACKAGES` hacía
  `npm install -g` sin permisos. Ahora npm instala en la carpeta del usuario
  (`NPM_CONFIG_PREFIX`), y los paquetes persisten en el volumen.
- Chromium funciona en el contenedor con un envoltorio `--no-sandbox` (`terminal/chromium`).
- **`TOOL_SEARCH_ALWAYS_LOADED`** con las herramientas del terminal, skills, búsqueda e
  imagen: con la Búsqueda de herramientas, qwen3.8-flash las llamaba mal a través de
  `call_tool` (11 llamadas rotas en una sola presentación).
- **Descarga de lo que crea el modelo:** en el panel Archivos, las carpetas no tienen
  «Descargar» en su menú «⋯» (solo dentro de ellas, en «Acciones»). Ahora el terminal
  monta `terminal/AGENTS.md`, que pide al modelo empaquetar las entregas de varios
  ficheros en un ZIP y explicar cómo descargarlo.
- **El terminal viene seleccionado de serie** en todos los modelos (`terminalId` en
  `DEFAULT_MODEL_METADATA`), así que las skills están disponibles sin que el usuario active
  nada. Si el terminal no está levantado, Open WebUI lo ignora.
- `terminal/AGENTS.md` pide al modelo no crear skills de Open WebUI por su cuenta: en las
  pruebas guardó una «skill» con las notas de una web (`create_skill` se ofrece siempre a
  los administradores y no se puede apagar sin perder la lectura de skills).
- `terminal/AGENTS.md` avisa también de que `run_command` espera como máximo 300 s, y que
  los procesos largos se siguen con `get_process_status`.

### Registro y marca

- **Registro cerrado de serie** (`ENABLE_SIGNUP=false`): quien llega a la URL no puede
  crearse una cuenta; solo el administrador da de alta usuarios. La primera cuenta (la
  del administrador) se sigue creando. Probado en limpio: primer registro 200, segundo
  403, alta desde el administrador 200.
- **Marca de la comunidad NaN en la entrada:** insignia «Built with NaN» (clara u oscura
  según el tema, enlazada desde `nan.builders` como piden sus normas) y el símbolo de
  Helmcode con «NaN es la comunidad de inferencia de Helmcode». Va en `branding/` a
  través de `loader.js` y `custom.css`, los puntos de extensión de Open WebUI, así que
  se mantiene al actualizar.
- **Sesiones huérfanas:** si el navegador conserva la sesión de un usuario que ya no
  existe (por ejemplo, tras reinstalar), Open WebUI se quedaba en `/error`. Ahora
  `branding/loader.js` la cierra y lleva a la entrada.
- **Logo de Helmcode** en favicon, barra lateral y pantalla de carga con `NAN_LOGO=true`
  (por defecto); `NAN_LOGO=false` vuelve a los de Open WebUI. **Ojo:** la licencia de
  Open WebUI prohíbe cambiar su logo en instalaciones de más de 50 usuarios en 30 días
  sin su permiso; en ese caso hay que poner `NAN_LOGO=false`.
- **Icono de NaN como foto de perfil sin foto** (`NAN_AVATAR=true`): sustituye la
  silueta gris que Open WebUI usa cuando un usuario no tiene foto o pulsa «Eliminar» en
  *Ajustes > Cuenta*. Las cuentas nuevas siguen naciendo con sus iniciales, que Open
  WebUI genera en el navegador. Con `false`, la silueta gris.

### Copias de seguridad

- `backup.sh`: copia del volumen con la app parada y rearranque garantizado, permisos
  `600`, sin las cachés de modelos (de 254 MB a 4,4 MB) y rotación con `KEEP_DAYS`.
- `restore.sh`: valida el fichero, pide confirmación y guarda antes el estado actual.
  Sirve también para el volumen de Open Terminal.

### Seguridad y despliegue

- `Dockerfile` fijado a `open-webui:v0.12.3` por tag **y digest** (antes `:main`).
  SearXNG y Open Terminal también pasan a versiones fijas (antes `latest`).
- `WEBUI_SECRET_KEY` pasa a ser obligatoria: sin ella Open WebUI la guardaba en un
  fichero fuera del volumen y todas las sesiones caducaban al recrear el contenedor.
- `no-new-privileges` en los contenedores; SearXNG con `cap_drop: ALL` y solo
  `CHOWN`/`SETGID`/`SETUID`. Red propia `nan-open-webui-network`.
- `ENABLE_COMMUNITY_SHARING=false`.
- Coolify: `WEBUI_URL`, secretos y `OPEN_TERMINAL_API_KEY` obligatorios; CORS acotado
  por defecto a `WEBUI_URL`; cookies `Secure`.
- `setup.sh`: `.env` con permisos 600 y aviso si la key está vacía o es un platform
  token (`nan_pat_...`).
- **Modo `docker run` corregido**: Open WebUI no reutiliza `OPENAI_API_KEY` para
  embeddings, reranker, voz ni imágenes, que se quedaban sin clave (las imágenes ya
  fallaban así en v0.0.9). El ejemplo del README pasa la key a cada servicio, y la
  imagen trae la lista de modelos y el modelo por defecto.
- CI: imagen multiplataforma (`amd64` + `arm64`), acciones fijadas por SHA,
  procedencia y SBOM, y `latest` solo en releases. **Smoke test antes de publicar**
  (`.github/scripts/smoke-test.sh`): levanta el stack y comprueba versión,
  configuración y SearXNG; si falla, no se publica nada.

### Límites conocidos

- NaN corta a los 120 s las peticiones sin streaming. Qwen tardó entre 68 y 100 s en
  las pruebas; si una generación llega a cortarse, usa
  `IMAGE_GENERATION_MODEL=flux-2-klein` (unos 7 s).
- Con el tamaño fijado, las imágenes salen con `IMAGE_SIZE` (por defecto cuadradas)
  aunque se pidan horizontales.
- Encargos muy largos con el terminal (webs completas, vídeos) pueden acumular tanto
  contexto que NaN corte con un 524; la compactación de contexto lo reduce.
- `NAN_AVATAR` no cambia la foto de las cuentas nuevas: Open WebUI les genera sus
  iniciales en el navegador.

### Actualizar desde v0.0.x

Con `ENABLE_PERSISTENT_CONFIG=true` (por defecto), lo que ya está guardado en la base
de datos manda sobre el `.env`, así que los valores nuevos **no se aplican solos**. Tras
actualizar, en el panel de administración:

1. *Settings > Connections*: añade los modelos nuevos a la lista de la conexión de NaN.
2. *Settings > Documents*: tamaño de lote de embeddings 32, búsqueda híbrida activada y
   reranker externo `https://api.nan.builders/v1/rerank` con modelo `rerank`.
3. *Settings > Images*: modelo de generación `qwen-image-2.1` y, en *Parámetros
   adicionales*, `{"size":"1024x1024"}`.
4. *Settings > Models > Valores predeterminados del modelo*: quita
   `function_calling: legacy` de *Parámetros del modelo* para el modo nativo, activa la
   capacidad *Uso* y desactiva las herramientas integradas que no uses.
5. *Settings > Interface*: activa *Búsqueda de herramientas* (Tool Search).
6. *Settings > Audio*: voz `ef_dora` si la quieres en español.
7. *Settings > Interface > Modelo de tarea*: `deepseek-v4-flash` con
   `{"reasoning_effort":"none"}` en sus parámetros.
8. *Settings > Interface*: compactación de contexto (modelo `deepseek-v4-flash`) y
   permisos de herramientas; *Settings > Subagents*: activarlos.
9. *Settings > Documents*: *Extraer imágenes del PDF (OCR)* y, si quieres, la plantilla
   de `branding/rag-template.txt`.
10. *Settings > Models > Valores predeterminados del modelo*: terminal por defecto
    *Open Terminal* y, en funciones por defecto, búsqueda web e imagen.
11. Terminal: añade `COMPOSE_PROFILES=terminal` y `TERMINAL_SERVER_CONNECTIONS` al
    `.env` (copia las líneas de `.env.example` y ejecuta `./setup.sh`); en *Settings >
    Integrations* añade la conexión `http://open-terminal:8000` con su clave.

También puedes arrancar una vez con `ENABLE_PERSISTENT_CONFIG=false` para que se carguen
los valores del `.env`. Ejecuta `./setup.sh` para añadir las claves nuevas al `.env` y
copia `searxng/settings.yml` (los buscadores nuevos). En Coolify, copia también las
carpetas `skills/` y `terminal/`.

## v0.0.9 - 2026-08-21

- Nueva variante **`docker-compose.coolify.yml`** para hosting gestionado con
  Coolify/Traefik: sin `ports` publicados (`expose` interno tras el proxy), sin
  `container_name` ni volumen de nombre fijo, y toda la configuracion por
  variables del panel. Documentada en PRODUCCION.md.
- Añade **Open Terminal** (ghcr.io/open-webui/open-terminal) como tercer
  servicio en la variante Coolify: interno (sin dominio ni puertos), API key
  por variable de entorno del panel, volumen persistente propio y limites de
  memoria. Es una shell real: restringir su uso a admins/grupos de confianza.
- Documenta el matiz de bind mounts en Coolify: los ficheros del repo no se
  persisten en el directorio de la app, asi que `searxng/settings.yml` debe
  copiarse a mano una vez (sin el, la busqueda web falla con 403).
- Actualiza referencias de version e imagen por defecto a v0.0.9.

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
