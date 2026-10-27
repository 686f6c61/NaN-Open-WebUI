# Secretos y datos locales

- Mantener `.gitignore` y `.dockerignore` alineados para excluir credenciales,
  sesiones, bases de datos, backups, logs y salidas de pruebas.
- `.env.example` solo contiene marcadores y configuración pública. Las claves
  reales se inyectan en runtime y nunca se copian a la imagen ni al repositorio.
- Antes de cada push, revisar los archivos versionados y el diff preparado.
  `.gitignore` no elimina archivos que ya estén versionados.
- Guardar las copias de seguridad en `backups/`, con permisos restringidos.
  Las pruebas usan recursos temporales propios y credenciales ficticias.
- Si aparece una credencial real en un registro o archivo público, no imprimirla:
  identificar dónde se usa y rotarla de forma coordinada tras hacer backup.
