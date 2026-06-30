# Guia paso a paso, sin saber nada de Docker

Sigue estos pasos en orden y no te equivocaras. No necesitas saber programar.
Tiempo: unos 10-15 minutos la primera vez.

> Que es Docker, en una frase: un programa que ejecuta esta app dentro de una "caja"
> ya preparada, para que no tengas que instalar nada raro. Lo instalas una vez y ya.

---

## Paso 1 - Instalar Docker (una sola vez)

**Windows o Mac:** instala **Docker Desktop**.
1. Entra en https://www.docker.com/products/docker-desktop/
2. Descarga el instalador de tu sistema (Windows o Mac) y abrelo.
3. Sigue "Siguiente / Aceptar" hasta el final. Reinicia si te lo pide.
4. Abre **Docker Desktop** y **dejalo abierto**. Cuando la ballena de arriba/abajo
   este fija (no animada), Docker esta listo.

**Linux (Ubuntu/Debian):** abre un terminal y pega:
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```
Despues **cierra sesion y vuelve a entrar** (para que el cambio surta efecto).

> Importante (Windows/Mac): Docker Desktop tiene que estar **abierto** cada vez que uses
> la app. Si lo cierras, la web dejara de funcionar hasta que lo abras otra vez.

---

## Paso 2 - Conseguir tu clave de NaN (API key)

1. Entra en https://nan.builders y crea tu cuenta / inicia sesion.
2. Busca la seccion de **API keys** y crea una.
3. Copiala entera. Empieza por `sk-...`. **Guardala**, la necesitas en el Paso 4.

> Esta clave es tuya y privada. No la enseñes ni la subas a ningun sitio.

---

## Paso 3 - Descargar esta carpeta

Si te han pasado la carpeta **NaN OpenWebUI** (por ejemplo en un .zip), **descomprimela**
en un sitio facil de encontrar (por ejemplo el Escritorio).

Deberias tener una carpeta con estos archivos dentro: `docker-compose.yml`,
`.env.example`, `setup.sh`, `README.md`, etc.

---

## Paso 4 - Poner tu clave (el unico paso "manual")

Hay que crear un archivo llamado `.env` con tu clave dentro. Elige tu sistema:

### En Windows
1. Entra en la carpeta. Haz una **copia** del archivo `.env.example` y a la copia
   **renombrala** a `.env` (sin nada delante, solo `.env`).
   - Si Windows no te deja ponerle ese nombre, ponlo desde el Bloc de notas:
     Abre el Bloc de notas -> Archivo -> Guardar como -> en "Tipo" elige "Todos los
     archivos" -> nombre `.env` -> guardalo en la carpeta.
2. Abre el archivo `.env` con el **Bloc de notas**.
3. Busca la linea que pone `NAN_API_KEY=sk-pon-aqui-tu-api-key` y **sustituye**
   `sk-pon-aqui-tu-api-key` por **tu clave** (la del Paso 2). Debe quedar asi:
   ```
   NAN_API_KEY=sk-tu-clave-de-verdad
   ```
4. **Guarda** (Archivo -> Guardar) y cierra.

### En Mac o Linux (lo hace solo)
1. Abre un terminal **dentro de la carpeta**:
   - Mac: arrastra la carpeta al icono de Terminal, o abre Terminal y escribe `cd ` y
     arrastra la carpeta detras, y pulsa Enter.
   - Linux: clic derecho en la carpeta -> "Abrir en terminal".
2. Pega esto y pulsa Enter:
   ```bash
   ./setup.sh
   ```
3. Te creara el `.env`. Ahora abrelo y pon tu clave en la linea `NAN_API_KEY=`
   (con cualquier editor de texto), y guarda.

> Reglas para no fallar con el `.env`:
> - El archivo se llama **`.env`** exacto (con el punto delante, sin `.txt` al final).
> - **No** pongas comillas alrededor de la clave. Asi NO: `NAN_API_KEY="sk-..."`.
> - **No** dejes espacios: asi NO: `NAN_API_KEY = sk-...`. Asi SI: `NAN_API_KEY=sk-...`.

---

## Paso 5 - Arrancar la app

1. Abre un terminal **dentro de la carpeta** (igual que en el Paso 4):
   - **Windows 11**: clic derecho dentro de la carpeta -> "Abrir en Terminal".
   - **Windows 10**: abre la carpeta, haz clic en la barra de la ruta de arriba,
     escribe `powershell` y pulsa Enter.
   - **Mac/Linux**: como en el Paso 4.
2. Pega esto y pulsa Enter:
   ```bash
   docker compose up -d
   ```
3. La primera vez tardara unos minutos (esta descargando la app). Cuando termine y
   vuelva a aparecer la linea para escribir, ya esta.

---

## Paso 6 - Entrar

1. Abre tu navegador (Chrome, Firefox, Edge...) y ve a:

   **http://localhost:3000**

2. La primera vez te pedira crear una cuenta. La **primera cuenta es la de
   administrador** (la tuya). Pon tu email y una contraseña y entra.
3. Arriba a la izquierda elige un modelo (por ejemplo `qwen3.6`) y a chatear.

Ya esta. Lo tienes funcionando.

> **Buscar en internet:** en la caja del chat, activa el interruptor **Búsqueda web**
> (el icono del globo) y pregunta lo que quieras. El modelo buscara en internet y te
> respondera citando las fuentes. Funciona sin configurar nada y sin ninguna API key:
> ya viene incluido un buscador propio (SearXNG). Funciona con cualquier modelo.

> **Generar imagenes:** abre la herramienta de imagenes de Open WebUI y pide la imagen
> que quieras. Viene configurada con `flux-2-klein` de NaN. Tambien puedes editar una
> imagen de referencia desde la herramienta de edicion si tu cuenta de NaN tiene acceso
> `inference-tier`.

---

## Para apagarlo y volver a encenderlo

- **Apagar** (no borra nada): en el terminal dentro de la carpeta:
  ```bash
  docker compose down
  ```
- **Encender otra vez**:
  ```bash
  docker compose up -d
  ```
  (Acuerdate, en Windows/Mac, de tener **Docker Desktop abierto**.)

Tus chats y tu cuenta se guardan; no se pierden al apagar.

---

## Si algo va mal (errores tipicos)

| Lo que ves | Que pasa | Como se arregla |
|---|---|---|
| `Falta NAN_API_KEY` | No creaste el `.env` o no tiene la clave | Repite el Paso 4 con cuidado |
| La web no carga / "no se puede conectar" | Docker Desktop esta cerrado | Abrelo y espera a que la ballena se quede fija |
| Entras pero **no hay modelos** | La clave esta mal escrita o caducada | Revisa el `.env` (sin comillas ni espacios) y vuelve a `docker compose up -d` |
| `port is already allocated` / puerto ocupado | El 3000 lo usa otra cosa | En el `.env` cambia `WEBUI_PORT=3000` por `WEBUI_PORT=3001` y entra en `http://localhost:3001` |
| `docker: command not found` | Docker no esta instalado | Repite el Paso 1 |
| Una **foto** da "no soporta imagenes" | Tienes un modelo de solo texto | Elige `qwen3.6`, `gemma4` o `mimo-v2.5` |
| Generar imagenes falla | Falta acceso `inference-tier`, cuota, rate limit o tamaño valido | Revisa tu cuenta de NaN, espera unos segundos si has generado varias seguidas, y usa tamaños como `512x512` o `1024x1024` |

> Tras cualquier cambio en el `.env`, vuelve a ejecutar `docker compose up -d` para que
> se aplique.

---

## Si te atascas, que te ayude una IA

No te sale algo? Pidselo a un asistente de IA y que te guie (o lo haga por ti). Como los
modelos los pones tu desde NaN, puedes aprovecharlos tambien para esto:

1. Instala un asistente de IA con terminal, por ejemplo **OpenCode** (https://opencode.ai),
   o similar (Cline, Continue, Cursor...).
2. Configuralo como proveedor compatible con OpenAI:
   - URL base: `https://api.nan.builders/v1`
   - API key: tu clave de NaN
   - Modelo: por ejemplo `mimo-v2.5` o `qwen3.6`
3. Abrelo **dentro de esta carpeta** y dile en lenguaje normal lo que quieres, por ejemplo:
   > "Quiero levantar esta imagen Docker para usar Open WebUI con NaN. Guiame paso a paso
   > segun el README y la guia, y avisame si me equivoco en algo."
4. Cuando funcione, **guarda la web en los favoritos** del navegador
   (`http://localhost:3000`) para abrirla con un clic.

Asi usas los propios modelos de NaN para montarte la herramienta de NaN.

---

## Que NO hacer

- **No** compartas tu archivo `.env`: lleva tu clave. Si pasas la carpeta a alguien,
  pasala **sin** el `.env`.
- **No** edites el `docker-compose.yml` ni el `Dockerfile` si no sabes lo que haces;
  todo lo que necesitas cambiar esta en el `.env`.
- **No** pongas tu clave dentro de un chat, un grupo o una captura de pantalla.

Si te atascas, copia el mensaje de error exacto y pidelo en la comunidad de NaN.
