"""Comprueba autenticación y aislamiento de credenciales en un terminal de prueba."""

import json
import os
import shlex
import sys
import time
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:8000"
KEY = os.environ["OPEN_TERMINAL_API_KEY"]


def request(path, body=None, credential=KEY, method=None):
    headers = {"Content-Type": "application/json"}
    if credential is not None:
        headers["Authorization"] = "Bearer " + credential
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=35) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, None


deadline = time.monotonic() + 60
while True:
    try:
        status, _ = request("/execute")
        assert status == 200, "La clave válida no permite acceder al terminal"
        break
    except urllib.error.URLError:
        if time.monotonic() >= deadline:
            raise RuntimeError("El terminal no arrancó dentro del plazo") from None
        time.sleep(0.25)

for credential in (None, "", "invalid-smoke-credential"):
    status, _ = request("/execute", credential=credential)
    assert status in (401, 403), "El terminal no rechaza credenciales incorrectas"

code = (
    "import os; "
    "print('SERVER_KEY_PRESENT=' + str('OPEN_TERMINAL_API_KEY' in os.environ)); "
    "print('CUSTOM_VALUE=' + os.environ.get('NAN_SMOKE_VALUE', 'missing'))"
)
command = shlex.join([sys.executable, "-c", code])
status, process = request("/execute", {"command": command, "env": {"NAN_SMOKE_VALUE": "preserved"}})
assert status == 200, "No se pudo iniciar el comando de prueba"
process_id = process["id"]
try:
    status, result = request("/execute/" + process_id + "/status?wait=30")
    assert status == 200 and result["status"] == "done", "El comando no terminó dentro del plazo"
    assert result["exit_code"] == 0, "Falló el comando de prueba"
    output = "".join(entry["data"] for entry in result["output"] if entry["type"] == "output")
    assert "SERVER_KEY_PRESENT=False" in output, "El comando hereda la API key del servidor"
    assert "CUSTOM_VALUE=preserved" in output, "Se perdió el entorno explícito del comando"
finally:
    # Solo el proceso creado por esta prueba; nunca procesos de una instalación real.
    request("/execute/" + process_id, method="DELETE")

print("[OK] Terminal: autenticación y comandos sin API key del servidor")
