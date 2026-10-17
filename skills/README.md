# Skills del terminal

Skills que Open Terminal ofrece al modelo. El terminal viene seleccionado de serie, así
que están disponibles sin activar nada: se montan en solo lectura en
`/home/user/.agents/skills`, el modelo ve el nombre y la descripción de cada una y carga
la que necesita según el encargo.

Son 39: 38 de terceros, con licencia que permite redistribuirlas (MIT o Apache 2.0), y
una propia (`escritura-es`). Cada carpeta de terceros conserva el fichero de licencia de
su proyecto.

## Qué hay

| Skill | Para qué | Origen | Commit | Licencia |
| --- | --- | --- | --- | --- |
| `design-taste-frontend` | Webs con dirección de arte, fotos reales con licencia y revisión en navegador | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | `f624f37` | MIT |
| `theme-factory` | Aplicar un tema visual (paleta y tipografías) a webs, documentos o presentaciones | [anthropics/skills](https://github.com/anthropics/skills) | `dbd4588` | Apache 2.0 |
| `canvas-design` | Carteles y piezas gráficas en PNG o PDF | [anthropics/skills](https://github.com/anthropics/skills) | `dbd4588` | Apache 2.0 |
| `minimax-docx` | Word: crear, rellenar y dar formato | [MiniMax-AI/skills](https://github.com/MiniMax-AI/skills) | `60aaae5` | MIT |
| `minimax-pdf` | PDF con diseño: informes, propuestas, currículos | [MiniMax-AI/skills](https://github.com/MiniMax-AI/skills) | `60aaae5` | MIT |
| `pptx-generator` | PowerPoint editable con PptxGenJS | [MiniMax-AI/skills](https://github.com/MiniMax-AI/skills) | `60aaae5` | MIT |
| `minimax-xlsx` | Excel con fórmulas | [MiniMax-AI/skills](https://github.com/MiniMax-AI/skills) | `60aaae5` | MIT |
| `frontend-slides` | Presentaciones en HTML con animaciones | [zarazhangrui/frontend-slides](https://github.com/zarazhangrui/frontend-slides) | `9906a34` | MIT |
| `drawio` | Diagramas y organigramas editables en draw.io | [bahayonghang/drawio-skills](https://github.com/bahayonghang/drawio-skills) | `2aa612e` | MIT |
| `archify` | Diagramas de arquitectura y flujos en HTML interactivo | [tt-a1i/archify](https://github.com/tt-a1i/archify) | `68be1e0` | MIT |
| `copywriting` | Textos comerciales | [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) | `365b412` | MIT |
| `copy-editing` | Corregir y mejorar textos | [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) | `365b412` | MIT |
| `social` | Publicaciones para redes sociales | [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) | `365b412` | MIT |
| `emails` | Secuencias de correos | [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) | `365b412` | MIT |
| `content-strategy` | Planes de contenidos | [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) | `365b412` | MIT |
| `humanizer` | Quitar las señales de texto escrito por IA | [blader/humanizer](https://github.com/blader/humanizer) | `8c307f3` | MIT |
| `meeting-notes` | Actas de reunión con decisiones y tareas (versión en español) | [mohitagw15856/pm-claude-skills](https://github.com/mohitagw15856/pm-claude-skills) | `921e015` | MIT |
| `escritura-es` | Normas de español de España (RAE, títulos, cifras, calcos) para cualquier texto | Propia | — | — |
| Vídeo: `hyperframes` y 20 más | Vídeos y animaciones con HyperFrames (ver abajo) | [heygen-com/hyperframes](https://github.com/heygen-com/hyperframes) | `b18b3e9` | Apache 2.0 |

Las de vídeo son `hyperframes` (punto de entrada), `general-video`, `motion-graphics`,
`product-launch-video`, `faceless-explainer`, `slideshow`, `music-to-video`,
`embedded-captions`, `talking-head-recut`, `pr-to-video`, `figma`,
`remotion-to-hyperframes`, `media-use` y las de apoyo `hyperframes-core`,
`hyperframes-cli`, `hyperframes-animation`, `hyperframes-creative`,
`hyperframes-keyframes`, `hyperframes-audio`, `hyperframes-registry` y
`hyperframes-studio`.

## Pruebas

Todas desde el chat, el 17/10/2026, sin ayuda. «Cargó la skill» significa que el modelo
la leyó por su cuenta antes de trabajar.

### Con qwen3.8-flash

| Skill | Encargo | Resultado | Tiempo |
| --- | --- | --- | --- |
| `design-taste-frontend` | Landing de una panadería | Web editorial con 10 fotos reales acreditadas; 0 fallos del inspector en escritorio, tableta y móvil | ~70 min, muy alto en tokens |
| `design-taste-frontend` | Rediseño de una web anticuada | Rediseño completo y coherente | ~50 min |
| `humanizer` | Texto de gestoría «de IA» | Texto natural, sin inventar datos | 80 s |
| `copywriting` | Página de una academia de inglés | Texto profesional con huecos marcados para los datos que faltan | 97 s |
| `copy-editing` | «Sobre nosotros» de una tienda de café | Tildes y estilo corregidos, datos intactos | 112 s |
| `pptx-generator` | Presentación de 6 diapositivas | Diseño coherente, gráfico y tablas nativos; cifras de ejemplo inventadas | ~11 min |
| `frontend-slides` | Charla de 7 diapositivas | Presentación HTML navegable y cuidada | ~10 min |
| `minimax-xlsx` | Presupuesto familiar | 303 fórmulas, 0 errores, comprobación «cuadra» | ~15 min |

### Con deepseek-v4-flash

| Skill | Encargo | Resultado | Llamadas |
| --- | --- | --- | --- |
| `minimax-docx` | Informe en Word para una junta de vecinos | 10 páginas con portada, índice, tablas y gráfica; importes marcados «(ejemplo)». Hecho con python-docx siguiendo la skill (su herramienta en C# necesita .NET, que no se instala) | 130 |
| `minimax-pdf` | Currículum de una página | Bien diseñado, datos respetados, contacto marcado como ejemplo; añadió competencias genéricas | 92 |
| `canvas-design` | Cartel de un festival de jazz | Cartel con mucha personalidad y fechas correctas; un 524 de NaN cortó el chat al final (134.000 tokens) | 112 |
| `social` + `escritura-es` | 6 publicaciones para LinkedIn e Instagram | Buen tono, datos que faltan entre corchetes | 14 |
| `emails` | 4 correos de bienvenida | Calendario de envío, huecos marcados, suscripción como idea por decidir | 10 |
| `content-strategy` + `escritura-es` | Plan de contenidos de 3 meses | Calendario por semanas; usó el CSV de ejemplo de la carpeta y lo avisa | 31 |
| `theme-factory` | «Sobre nosotros» en HTML con un tema | Página completa y coherente; algún adorno de texto añadido | 52 |
| `meeting-notes` | Acta a partir de notas | Decisiones, responsables y plazos; añadió una «condición de revisión» que no estaba | 10 |
| `drawio` | Organigrama de una gestoría | Organigrama limpio y editable, con PNG | 71 |
| `archify` | Arquitectura de este sistema | Diagrama correcto y validado con su propia herramienta | 16 |
| `hyperframes` | Vídeo de 15 s de una panadería, desde cero | MP4 1920×1080 completo, sin datos inventados, proyecto editable en ZIP | 17 min |

Con qwen3.8-flash, el mismo vídeo quedó con la composición terminada y validada a los
~30 minutos (se paró antes del render; el render manual tardó 83 s) e inventó horario y
dirección.

### Descartadas

- `redesign-existing-projects`, `minimalist-ui` y `full-output-enforcement`
  (Leonxlnx/taste-skill): el modelo usa siempre `design-taste-frontend` y la última no
  se activó nunca.
- `imagemagick` y `report-generator` (TerminalSkills/skills), `data-visualization`,
  `analyze` y `explore-data` (anthropics/knowledge-work-plugins): en sus pruebas (editar
  un cartel, informe PDF de ventas, análisis y perfil de un CSV) el modelo hizo un
  trabajo excelente **sin cargarlas**.
- `pretty-mermaid`: intenta instalarse dentro de su carpeta, que es de solo lectura, y
  el modelo acabó dibujando el diagrama sin ella.
- Por licencia: las de Anthropic para Word, PDF, PowerPoint y Excel (privativas),
  `doc-coauthoring` (sin licencia), Remotion y OpenMontage.

## Configuración que necesitan (ya en los compose)

- **HyperFrames:** CLI `hyperframes@0.8.168` instalado (`OPEN_TERMINAL_NPM_PACKAGES`),
  `HYPERFRAMES_SKIP_SKILLS=1` para que no reinstale las skills en `~/.claude/skills`
  (saldrían duplicadas), `HYPERFRAMES_NO_TELEMETRY=1` y `DO_NOT_TRACK=1` (la telemetría
  viene activa) y `HYPERFRAMES_NO_UPDATE_CHECK=1`. Al actualizarlo, cambia a la vez las
  skills de esta carpeta y la versión del CLI.
- **Archify:** `ARCHIFY_UPDATE_CHECK_DISABLED=1` y `ARCHIFY_CHROME` con el Chromium del
  terminal.
- **Chromium** corre con `--no-sandbox` (envoltorio en `terminal/chromium`): dentro de
  Docker no puede crear su propio aislamiento y el contenedor hace de barrera.
- **Tool Search:** las herramientas del terminal van en `TOOL_SEARCH_ALWAYS_LOADED`; si
  no, qwen3.8-flash las llama mal a través de `call_tool`.

## Notas

- Las descripciones de las 39 skills suman unos 21.500 caracteres, que se envían en
  cada mensaje mientras el terminal está seleccionado.
- `read_skill_file` de Open WebUI solo lee el `SKILL.md` de las skills del terminal; el
  modelo lee el resto de ficheros con el terminal, sin intervención.
- El modelo mira los demás ficheros de la carpeta de trabajo y puede aprovecharlos como
  contexto (en las pruebas, siempre avisando).
- Para encargos largos rinde mejor deepseek-v4-flash: escribe ficheros largos unas 4
  veces más rápido que qwen3.8-flash (28-30 s frente a 96-116 s para 30.000 caracteres)
  y no inventó datos.
- El terminal no tiene el locale `es_ES.UTF-8`: si el modelo intenta fechas con nombres
  de mes vía `locale`, falla y las escribe a mano.
