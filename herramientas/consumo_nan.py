"""
title: Consumo de NaN
author: NaN-Open-WebUI
version: 1.0.0
description: Consulta el consumo de la cuenta de NaN en el mes en curso (tokens y peticiones por modelo) y lo compara con las cuotas mensuales.
"""

import os
from datetime import datetime, timezone

import aiohttp
from pydantic import BaseModel, Field

# Cuotas mensuales por miembro segun https://nan.builders/docs/models (octubre de 2026).
# Los modelos sin cuota publicada (gemma4, qwen3.6...) se muestran sin porcentaje.
# glm5.3 se mide por periodo de facturacion, no por mes natural: se muestra sin porcentaje.
CUOTAS_MENSUALES = {
    "deepseek-v4-flash": 3_000_000_000,
    "glm5.3-flash": 2_000_000_000,
    "mimo-v2.6-flash": 1_000_000_000,
    "qwen3.8-flash": 500_000_000,
}


def _formato(n: int) -> str:
    if n >= 1_000_000_000:
        return f"{n / 1_000_000_000:.2f} B"
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f} M"
    if n >= 1_000:
        return f"{n / 1_000:.1f} K"
    return str(n)


class Tools:
    class Valves(BaseModel):
        NAN_API_KEY: str = Field(
            default="",
            description="API key de NaN. Vacia = la misma que usa la conexion (OPENAI_API_KEY del contenedor).",
        )
        API_BASE_URL: str = Field(
            default="https://api.nan.builders/v1",
            description="URL base de la API de NaN (Helmcode: https://api.helmcode.com/v1).",
        )

    def __init__(self):
        self.valves = self.Valves()

    async def consumo_nan(self) -> str:
        """
        Devuelve el consumo de la cuenta de NaN en el mes en curso: tokens y peticiones por
        modelo y el porcentaje usado de la cuota mensual de cada uno. Usala cuando el usuario
        pregunte cuanto ha gastado o cuanto le queda de NaN, de su cuota o de sus tokens.
        """
        key = self.valves.NAN_API_KEY or os.environ.get("OPENAI_API_KEY", "")
        if not key:
            return "No hay API key de NaN configurada para esta herramienta."

        hoy = datetime.now(timezone.utc).date()
        inicio = hoy.replace(day=1)
        url = f"{self.valves.API_BASE_URL.rstrip('/')}/usage"
        params = {"start_date": inicio.isoformat(), "end_date": hoy.isoformat(), "limit": "500"}

        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=30)) as session:
                async with session.get(url, params=params, headers={"Authorization": f"Bearer {key}"}) as r:
                    if r.status != 200:
                        return f"NaN respondio {r.status} al consultar el consumo: {(await r.text())[:300]}"
                    datos = await r.json()
        except Exception as e:
            return f"No se pudo consultar el consumo de NaN: {e}"

        totales = datos.get("totals") or {}
        filas = []
        for m in sorted(totales.get("by_model") or [], key=lambda x: -x.get("total_tokens", 0)):
            usados = m.get("total_tokens", 0)
            cuota = CUOTAS_MENSUALES.get(m.get("model"))
            porcentaje = f"{usados / cuota * 100:.1f} % de {_formato(cuota)}" if cuota else "sin cuota mensual publicada"
            filas.append(
                f"| {m.get('model')} | {_formato(usados)} | {m.get('api_requests', 0)} | {porcentaje} |"
            )

        if not filas:
            return f"Sin consumo registrado en NaN desde el {inicio.isoformat()}."

        return "\n".join(
            [
                f"Consumo de la cuenta de NaN del {inicio.isoformat()} al {hoy.isoformat()} (UTC).",
                "Es el total de tu cuenta de NaN, incluido el uso fuera de Open WebUI.",
                "",
                "| Modelo | Tokens | Peticiones | Cuota mensual |",
                "|---|---|---|---|",
                *filas,
                "",
                f"Total: {_formato(totales.get('total_tokens', 0))} tokens en {totales.get('api_requests', 0)} peticiones.",
            ]
        )
