"""
VíaSync ZMG — Configuración centralizada.

Usa pydantic-settings para validar variables de entorno al arranque.
Si falta alguna variable requerida, la app falla rápido con error claro
en vez de fallar en runtime con un KeyError críptico.
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Configuración del sistema cargada desde variables de entorno / .env"""

    # ── Base de datos ──
    # asyncpg usa DSN sin el prefijo +asyncpg de SQLAlchemy
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/viasync"

    # ── Privacidad ──
    # Salt diario para hashear UUIDs. Debe rotarse cada 24h en producción.
    # Al cambiar el salt, los session_hash previos se vuelven irreconectables
    # con los nuevos, reforzando la anonimización temporal.
    DAILY_SALT: str = "viasync_salt_cambiar_en_produccion"

    # ── Velocidades promedio (metros/minuto) para cálculo de ETA ──
    # L1/L3 tren ligero: 35 km/h ≈ 583 m/min (incluye paradas)
    # C-09/A04 autobús: 18 km/h ≈ 300 m/min (tráfico urbano promedio)
    VEL_TREN: float = 583.0
    VEL_BUS: float = 300.0

    # ── Pool de conexiones ──
    # min=2: mantiene 2 conexiones calientes para baja latencia en picos
    # max=10: límite conservador para no saturar PostgreSQL (default 100 conns)
    DB_POOL_MIN: int = 2
    DB_POOL_MAX: int = 10

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache()
def get_settings() -> Settings:
    """Singleton cacheado — la config se lee una sola vez."""
    return Settings()
