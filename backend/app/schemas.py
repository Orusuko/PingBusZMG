"""
VíaSync ZMG — Schemas de validación (Pydantic v2).

Validaciones estrictas en el borde de la API para rechazar datos inválidos
antes de que lleguen a la base de datos. Esto protege contra:
  - Coordenadas fuera del Área Metropolitana de Guadalajara
  - Claves de ruta vacías o demasiado largas
  - Payloads malformados
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class PingRequest(BaseModel):
    """
    Payload del endpoint POST /reportar.
    Diseñado para ser ultra-ligero: solo 4 campos, ~120 bytes JSON.
    
    Validaciones geográficas:
      - lat: 20.40–20.85 (norte-sur del AMG)
      - lon: -103.55 a -103.15 (este-oeste del AMG)
    Cualquier coordenada fuera de estos bounds es rechazada con 422,
    evitando inserts de datos basura que contaminarían el clustering.
    """
    uuid: str = Field(
        ...,
        min_length=8,
        max_length=64,
        description="UUID de sesión del dispositivo (se hasheará antes de persistir)"
    )
    ruta: str = Field(
        ...,
        min_length=1,
        max_length=10,
        description="Clave de la ruta: L1, L3, C-09, A04"
    )
    lat: float = Field(
        ...,
        ge=20.40, le=20.85,
        description="Latitud WGS84 (bounds del AMG)"
    )
    lon: float = Field(
        ...,
        ge=-103.55, le=-103.15,
        description="Longitud WGS84 (bounds del AMG)"
    )


class ParadaETA(BaseModel):
    """ETA a una parada específica."""
    nombre: str
    distancia_m: float
    eta_minutos: float


class UnidadDetectada(BaseModel):
    """Unidad de transporte detectada por clustering."""
    unidad_id: int
    posicion: dict  # {"lat": float, "lon": float}
    confianza: int  # Número de reportes en el cluster
    ultima_actualizacion: Optional[str] = None
    proximas_paradas: list[ParadaETA]


class ConsultaResponse(BaseModel):
    """Respuesta del endpoint GET /consultar/{ruta_id}."""
    ruta: str
    unidades: list[UnidadDetectada]
    total: int


class RutaEstadistica(BaseModel):
    """Estadísticas de una ruta individual."""
    clave: str
    pings_activos: int
    unidades_detectadas: int


class EstadisticasResponse(BaseModel):
    """Respuesta del endpoint GET /estadisticas."""
    pings_activos_total: int
    rutas: list[RutaEstadistica]
    ventana_minutos: int = 2
