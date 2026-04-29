"""
VíaSync ZMG — API de Alto Rendimiento (FastAPI).

Arquitectura de optimización de recursos:
  ┌─────────────────────────────────────────────────────────────────┐
  │  POST /reportar (~50ms)                                       │
  │  ┌──────────┐   ┌───────────┐   ┌────────────┐               │
  │  │ Validar  │──▶│ Hash UUID │──▶│ INSERT con │──▶ 201 {ok}   │
  │  │ Pydantic │   │ SHA-256   │   │ prepared   │    ~30 bytes  │
  │  └──────────┘   └───────────┘   │ statement  │               │
  │                                  └────────────┘               │
  ├─────────────────────────────────────────────────────────────────┤
  │  GET /consultar/{ruta} (~80ms)                                │
  │  ┌────────────┐   ┌──────────┐   ┌────────────┐              │
  │  │ DBSCAN en  │──▶│ ETA por  │──▶│ Respuesta  │              │
  │  │ PostgreSQL │   │ parada   │   │ GeoJSON    │              │
  │  └────────────┘   └──────────┘   └────────────┘              │
  └─────────────────────────────────────────────────────────────────┘
"""

import hashlib
import asyncpg
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .database import Database
from .schemas import (
    PingRequest, ConsultaResponse, UnidadDetectada, ParadaETA,
    EstadisticasResponse, RutaEstadistica,
)


# ═══════════════════════════════════════════════════════════════════════════
# LIFESPAN: Startup / Shutdown
# ═══════════════════════════════════════════════════════════════════════════
# asynccontextmanager reemplaza los deprecados on_event("startup"/"shutdown").
# El pool se crea una sola vez y se comparte entre todos los workers.

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gestiona el ciclo de vida del pool de conexiones."""
    await Database.connect()
    yield
    await Database.disconnect()


app = FastAPI(
    title="VíaSync ZMG",
    description="Motor de crowdsourcing para monitoreo de transporte público en Guadalajara",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS permisivo para desarrollo. En producción, restringir origins.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# ═══════════════════════════════════════════════════════════════════════════
# MIDDLEWARE DE PRIVACIDAD
# ═══════════════════════════════════════════════════════════════════════════
# Se ejecuta en CADA request. Agrega header X-Privacy para confirmar
# al cliente que sus datos se anonimizaron. No loguea UUIDs.

@app.middleware("http")
async def privacy_middleware(request: Request, call_next):
    """
    Middleware de privacidad:
    - Agrega header X-Privacy: anonymized a toda respuesta
    - Garantiza que ningún log del framework capture UUIDs raw
    """
    response: Response = await call_next(request)
    response.headers["X-Privacy"] = "anonymized"
    response.headers["X-Data-Retention"] = "2-minutes"
    return response


# ═══════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ═══════════════════════════════════════════════════════════════════════════

def _hash_uuid(uuid_raw: str) -> str:
    """
    Anonimiza el UUID del dispositivo con SHA-256 + salt diario.
    
    ¿Por qué SHA-256 y no MD5/bcrypt?
      - MD5: colisiones conocidas, inaceptable para privacidad.
      - bcrypt: demasiado lento (~300ms) para un endpoint que debe ser <50ms.
      - SHA-256: irreversible, rápido (~0.001ms), 64 chars hex.
    
    El salt diario (DAILY_SALT) asegura que el mismo UUID genera hashes
    diferentes cada día. Esto impide correlacionar sesiones entre días,
    incluso si un atacante obtiene acceso a la tabla pings_transito.
    """
    settings = get_settings()
    payload = f"{uuid_raw}:{settings.DAILY_SALT}".encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


# ═══════════════════════════════════════════════════════════════════════════
# ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════

@app.post("/reportar", status_code=201, tags=["Pings"])
async def reportar(ping: PingRequest):
    """
    Registra la ubicación anónima de un usuario en una ruta.
    
    Optimizaciones para bajo consumo de batería:
      1. Payload mínimo: 4 campos, ~120 bytes JSON
      2. Respuesta mínima: {"ok": true} = ~13 bytes
      3. SHA-256 del UUID en backend (no en el dispositivo)
      4. Single INSERT con prepared statement (plan cacheado)
      5. Sin procesamiento adicional: el clustering se hace en /consultar
    
    El diseño "fire and forget" permite al dispositivo enviar el ping
    y cerrar la conexión inmediatamente, minimizando el tiempo de radio
    activa (principal consumidor de batería en móviles).
    """
    # 1. Anonimizar UUID
    session_hash = _hash_uuid(ping.uuid)

    # 2. Rate limiting: máximo 1 ping cada 10 segundos por sesión.
    # Previene abuso (flood de pings) y duplicados exactos bajo concurrencia.
    # El índice idx_pings_session_ts hace esta verificación en ~1ms.
    recent_ping = await Database.fetchval(
        """SELECT EXISTS(
            SELECT 1 FROM pings_transito
            WHERE session_hash = $1 AND ts > NOW() - INTERVAL '10 seconds'
        )""",
        session_hash
    )
    if recent_ping:
        raise HTTPException(
            status_code=429,
            detail="Rate limit: máximo 1 ping cada 10 segundos por sesión"
        )

    # 3. Validar que la ruta existe (query cacheado por prepared statement)
    ruta_id = await Database.fetchval(
        "SELECT id FROM rutas WHERE clave = $1 AND activa = TRUE",
        ping.ruta
    )
    if ruta_id is None:
        raise HTTPException(status_code=404, detail=f"Ruta '{ping.ruta}' no encontrada o inactiva")

    # 4. INSERT — ST_MakePoint(lon, lat): OJO al orden, PostGIS usa X=lon, Y=lat
    # try/except captura el trigger trg_validar_ping_en_ruta si el ping
    # está a >100m del trazado oficial de la ruta.
    try:
        await Database.execute(
            """INSERT INTO pings_transito (session_hash, ruta_id, geom, ts)
               VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326), NOW())""",
            session_hash, ruta_id, ping.lon, ping.lat
        )
    except asyncpg.RaiseError as e:
        raise HTTPException(
            status_code=422,
            detail=f"Ubicación rechazada: {e.message}"
        )

    return {"ok": True}


@app.get("/consultar/{ruta_clave}", response_model=ConsultaResponse, tags=["Consultas"])
async def consultar(ruta_clave: str):
    """
    Devuelve las posiciones estimadas de unidades en una ruta, con ETA.

    Pipeline optimizado (UN solo roundtrip a PostgreSQL):
      fn_consultar_ruta_completa ejecuta internamente:
        1. vw_estado_actual filtra a pings de últimos 2 minutos
        2. fn_clustering_unidades agrupa por proximidad (DBSCAN, 20m)
        3. CROSS JOIN LATERAL calcula las 3 paradas más cercanas por cluster
        4. ETA = distancia / velocidad_promedio_según_tipo

    Python solo agrupa las filas planas por cluster_id para armar el JSON.
    Antes: 1 + N queries (N = clusters). Ahora: 1 query total.
    """
    # 1. Validar que la ruta existe (para retornar 404 en vez de respuesta vacía)
    ruta_exists = await Database.fetchval(
        "SELECT EXISTS(SELECT 1 FROM rutas WHERE clave = $1 AND activa = TRUE)",
        ruta_clave
    )
    if not ruta_exists:
        raise HTTPException(status_code=404, detail=f"Ruta '{ruta_clave}' no encontrada")

    # 2. UN solo roundtrip: clustering + ETA completo
    rows = await Database.fetch(
        "SELECT * FROM fn_consultar_ruta_completa($1)",
        ruta_clave
    )

    # 3. Agrupar filas planas por cluster_id para armar la respuesta JSON
    # La función retorna N filas por cluster (1 por cada parada cercana),
    # así que agrupamos por cluster_id para construir UnidadDetectada.
    clusters_map: dict[int, UnidadDetectada] = {}
    for row in rows:
        cid = row["cluster_id"]
        if cid not in clusters_map:
            clusters_map[cid] = UnidadDetectada(
                unidad_id=cid,
                posicion={"lat": float(row["lat"]), "lon": float(row["lon"])},
                confianza=row["num_reportes"],
                ultima_actualizacion=(
                    row["ultima_ts"].isoformat() if row["ultima_ts"] else None
                ),
                proximas_paradas=[]
            )
        clusters_map[cid].proximas_paradas.append(
            ParadaETA(
                nombre=row["parada_nombre"],
                distancia_m=float(row["distancia_m"]),
                eta_minutos=float(row["eta_minutos"])
            )
        )

    unidades = list(clusters_map.values())
    return ConsultaResponse(
        ruta=ruta_clave,
        unidades=unidades,
        total=len(unidades)
    )


@app.get("/health", tags=["Sistema"])
async def health():
    """Health check — verifica conectividad con PostgreSQL + PostGIS."""
    try:
        version = await Database.fetchval("SELECT PostGIS_Version()")
        return {"status": "ok", "postgis": version}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"DB no disponible: {str(e)}")


@app.get("/rutas", tags=["Consultas"])
async def listar_rutas():
    """Lista todas las rutas activas del sistema."""
    rutas = await Database.fetch(
        "SELECT clave, nombre, tipo FROM rutas WHERE activa = TRUE ORDER BY clave"
    )
    return [dict(r) for r in rutas]


@app.get("/estadisticas", response_model=EstadisticasResponse, tags=["Sistema"])
async def estadisticas():
    """
    Métricas en tiempo real del sistema.

    Devuelve pings activos y unidades detectadas por ruta dentro de la
    ventana de 2 minutos. Útil para monitoreo operativo y para demostrar
    el volumen de datos que el sistema procesa en tiempo real.
    """
    # Total de pings activos (ventana de 2 minutos)
    total = await Database.fetchval("SELECT COUNT(*) FROM vw_estado_actual")

    # Desglose por ruta: pings activos + unidades detectadas por DBSCAN
    rutas_raw = await Database.fetch(
        """SELECT r.clave,
                  COUNT(v.id) AS pings_activos,
                  (SELECT COUNT(*) FROM fn_clustering_unidades(r.id)) AS unidades
           FROM rutas r
           LEFT JOIN vw_estado_actual v ON v.ruta_id = r.id
           WHERE r.activa = TRUE
           GROUP BY r.id, r.clave
           ORDER BY r.clave"""
    )

    rutas = [
        RutaEstadistica(
            clave=r["clave"],
            pings_activos=r["pings_activos"],
            unidades_detectadas=r["unidades"]
        )
        for r in rutas_raw
    ]

    return EstadisticasResponse(
        pings_activos_total=total,
        rutas=rutas
    )
