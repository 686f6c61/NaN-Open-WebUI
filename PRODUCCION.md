# Poner NaN OpenWebUI en produccion

Guia para publicar esta stack en un servidor propio (VPS, servidor casero, PaaS con
Docker) de forma razonablemente segura: HTTPS, registro controlado, backups y
actualizaciones deliberadas.

Es generica: funciona en cualquier servidor con Docker y un dominio. Los ejemplos usan
`chat.tudominio.com` como dominio de ejemplo — cambiálo por el tuyo.

---

## Resumen de la arquitectura

```text
internet --> proxy inverso (TLS/HTTPS) --> 127.0.0.1:3000 (nan-open-webui)
                                             └── red interna compose --> searxng (sin puertos)
```

- La web **nunca se publica directa** a internet: queda atada a `127.0.0.1` y delante
  va un proxy que termina HTTPS.
- SearXNG no publica puertos: solo lo usa Open WebUI por la red interna.
- Todos los datos (cuentas, chats, documentos del RAG) viven en el volumen Docker
  `nan-open-webui-data`. Tu API key de NaN vive solo en el `.env` del servidor.

---

## 1) Preparar el servidor

- Docker instalado y actualizado; acceso por SSH con llaves (desactiva contraseña si
  puedes).
- Firewall: permite solo `22` (SSH), `80` y `443`. Nada mas expuesto.
- Apunta el DNS de `chat.tudominio.com` al servidor.

## 2) Desplegar la aplicacion

```bash
git clone https://github.com/686f6c61/NaN-Open-WebUI.git
cd NaN-Open-WebUI
./setup.sh
```

Edita el `.env` de produccion. Valores recomendados:

```ini
NAN_API_KEY=sk-tu-key-de-nan
OPENWEBUI_IMAGE=ghcr.io/686f6c61/nan-open-webui:v0.0.8   # tag fijo, NUNCA latest
WEBUI_BIND=127.0.0.1                                      # solo el proxy llega
WEBUI_PORT=3000
WEBUI_SECRET_KEY=(generado por setup.sh)
SEARXNG_SECRET=(generado por setup.sh)
ENABLE_SIGNUP=true            # al principio, para crear el admin y dar de alta
DEFAULT_USER_ROLE=pending     # cada registro necesita tu aprobacion
BYPASS_MODEL_ACCESS_CONTROL=false
WEBUI_URL=https://chat.tudominio.com
CORS_ALLOW_ORIGIN=https://chat.tudominio.com
ENABLE_IMAGE_GENERATION=true  # recuerda: la cuota de flux sale de TU key compartida
```

```bash
docker compose up -d
```

> Ojo con la key compartida: todo el consumo de todos los usuarios (chat, imagenes,
> voz) sale de tu cuenta de NaN, sin atribucion por persona. Para una comunidad
> grande, valora que cada usuario ponga su propia key en *Ajustes > Conexiones*.

## 3) HTTPS con proxy inverso

Opcion **Caddy** (el mas simple; certificados Let's Encrypt automaticos):

```text
# /etc/caddy/Caddyfile
chat.tudominio.com {
    reverse_proxy 127.0.0.1:3000
}
```

Opcion **Nginx** + certbot (mas clasica):

```nginx
server {
    server_name chat.tudominio.com;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        # websockets (tiempo real de la UI)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        # subidas de documentos/audio un poco generosas
        client_max_body_size 50m;
    }
}
```

> Si tu plataforma ya monta el proxy (Coolify, Traefik, Dokploy...), simplemente
> despliega el compose tal cual y apunta el proxy interno al puerto 3000 del
> contenedor; mantén `WEBUI_URL` y `CORS_ALLOW_ORIGIN` con tu dominio.
> Este repo incluye **`docker-compose.coolify.yml`**, una variante lista para
> Coolify (sin puertos publicados, `expose` interno, sin nombres fijos):
> despliega esa si tu hosting es Coolify.

> **Matiz importante de Coolify:** los *bind mounts* de ficheros del repo
> (como `./searxng`) **no funcionan tal cual**, porque Coolify solo persiste el
> compose y el `.env` en el directorio de la app, no el resto del repo. Para
> SearXNG, copia una vez `searxng/settings.yml` del repo a
> `<directorio-de-la-app>/searxng/settings.yml` (en un Coolify autoalojado:
> `/data/coolify/applications/<uuid>/searxng/settings.yml`). Ese directorio
> persiste entre redeploys. Sin ese fichero, la búsqueda web falla con `403`
> (el settings por defecto no habilita el formato JSON que Open WebUI consulta).

Abre `https://chat.tudominio.com`, **crea tu cuenta admin** (la primera) y a
continuacion cierra o controla el registro:

- Flujo recomendado: deja `ENABLE_SIGNUP=true` + `DEFAULT_USER_ROLE=pending`; la gente
  se registra y tu apruebas desde *Panel de administracion > Users*.
- Censo cerrado: pon `ENABLE_SIGNUP=false` en el `.env` y `docker compose up -d`; das
  de alta a cada persona manualmente desde el panel.

## 4) Backups

Todo vive en el volumen `nan-open-webui-data`. Backup con la app parada (base de
datos SQLite consistente):

```bash
docker compose stop nan-open-webui
docker run --rm -v nan-open-webui-data:/data -v /var/backups/nan-open-webui:/backup \
  alpine tar czf /backup/nan-$(date +%F).tar.gz -C /data .
docker compose start nan-open-webui
```

Cron ejemplo (diario a las 04:00, conserva 14 dias):

```cron
0 4 * * * cd /opt/NaN-Open-WebUI && docker compose stop nan-open-webui && docker run --rm -v nan-open-webui-data:/data -v /var/backups/nan-open-webui:/backup alpine tar czf /backup/nan-$(date +\%F).tar.gz -C /data . && docker compose start nan-open-webui && find /var/backups/nan-open-webui -name 'nan-*.tar.gz' -mtime +14 -delete
```

**Restaurar** (verificalo una vez en un entorno de prueba; un backup no probado no es
un backup):

```bash
docker compose down
docker volume rm nan-open-webui-data
docker volume create nan-open-webui-data
docker run --rm -v nan-open-webui-data:/data -v /var/backups/nan-open-webui:/backup \
  alpine sh -c "tar xzf /backup/nan-2026-08-21.tar.gz -C /data"
docker compose up -d
```

> Si te alojas en un VPS, copia tambien los `.tar.gz` fuera del servidor (rsync a
> otro equipo o almacenamiento cifrado). Un backup en la misma maquina no te salva de
> perder la maquina.

## 5) Actualizar de version

La imagen va fijada por tag: **actualizar es una decision explicita**, no algo que
pasa solo.

```bash
# 1) backup (paso 4)
# 2) edita .env:  OPENWEBUI_IMAGE=ghcr.io/686f6c61/nan-open-webui:v0.0.9
# 3) aplica y observa las migraciones
docker compose up -d
docker compose logs -f nan-open-webui
```

Si algo sale mal: restaura el backup (paso 4), vuelve el tag anterior en el `.env` y
`docker compose up -d`.

## 6) Checklist final

- [ ] La web solo escucha en `127.0.0.1` (`docker ps` debe mostrar `127.0.0.1:3000->8080`).
- [ ] HTTPS valido y redireccion de 80 a 443.
- [ ] Firewall: solo 22/80/443; SSH con llaves.
- [ ] `ENABLE_SIGNUP=false` o `DEFAULT_USER_ROLE=pending`.
- [ ] `BYPASS_MODEL_ACCESS_CONTROL=false` (control de modelos por grupo activo).
- [ ] `WEBUI_URL` y `CORS_ALLOW_ORIGIN` acotados a tu dominio.
- [ ] Backup automatico configurado **y restaurado una vez con exito**.
- [ ] `.env` con permisos `600` y jamas versionado.
- [ ] `docker compose logs` sin errores repetidos.

## 7) Rotacion de la API key (runbook)

1. Revoca la key antigua en https://nan.builders y crea una nueva.
2. Actualizala en el `.env` (`NAN_API_KEY`) y en el panel de Open WebUI
   (*Admin > Settings > Connections*): recuerda que la configuracion del panel manda
   sobre el `.env` ([configuracion persistente](README.md#configuracion-persistente-importante)).
   Alternativa: ten `ENABLE_PERSISTENT_CONFIG=false` para que el `.env` mande siempre.
3. `docker compose up -d` y comprueba que los modelos vuelven a listar.

## 8) Operaciones utiles

```bash
docker compose logs -f nan-open-webui        # logs de la app
docker compose logs -f searxng               # logs del buscador
docker compose restart                       # reinicio rapido
docker compose stats                         # consumo de recursos
docker exec -it nan-open-webui du -sh /app/backend/data   # tamano de los datos
```

---

*Esta guia es intencionalmente generica: no contiene dominios, IPs ni datos de ningun
despliegue concreto. Adaptala a tu infraestructura.*
