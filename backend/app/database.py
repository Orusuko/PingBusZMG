"""
VíaSync ZMG — Pool de conexiones asyncpg.

¿Por qué asyncpg y no psycopg2 / SQLAlchemy?
  1. asyncpg es 100% asíncrono y nativo de PostgreSQL wire protocol.
     No envuelve libpq, sino que implementa el protocolo desde cero.
  2. ~3x más throughput en I/O bound vs psycopg2 (benchmarks de MagicStack).
  3. Soporta prepared statements nativos: el plan de ejecución se cachea
     en el servidor, reduciendo overhead en queries repetitivos como
     el INSERT de /reportar.
  4. Pool integrado: min/max conexiones sin dependencias extra.

Patrón singleton: se crea un pool al arrancar (lifespan) y se reutiliza
en todos los endpoints. Evita crear/destruir conexiones por request.
"""

import asyncpg
from .config import get_settings


class Database:
    """Wrapper singleton para el pool de conexiones asyncpg."""

    _pool: asyncpg.Pool | None = None

    @classmethod
    async def connect(cls) -> None:
        """Inicializa el pool de conexiones. Llamar en app startup."""
        settings = get_settings()

        # Parseamos el DSN para extraer componentes
        # asyncpg no acepta el prefijo postgresql+asyncpg://
        dsn = settings.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")

        cls._pool = await asyncpg.create_pool(
            dsn=dsn,
            min_size=settings.DB_POOL_MIN,
            max_size=settings.DB_POOL_MAX,
            # statement_cache_size: cachea hasta 100 prepared statements
            # por conexión. El INSERT de /reportar se prepara una vez y
            # se reutiliza en todas las llamadas subsecuentes.
            statement_cache_size=100,
            # command_timeout: si un query tarda más de 30s, algo está mal.
            # Fail fast en vez de bloquear el pool.
            command_timeout=30,
        )

    @classmethod
    async def disconnect(cls) -> None:
        """Cierra el pool. Llamar en app shutdown."""
        if cls._pool:
            await cls._pool.close()
            cls._pool = None

    @classmethod
    async def execute(cls, query: str, *args) -> str:
        """Ejecuta un query sin retorno (INSERT, UPDATE, DELETE)."""
        async with cls._pool.acquire() as conn:
            return await conn.execute(query, *args)

    @classmethod
    async def fetch(cls, query: str, *args) -> list[asyncpg.Record]:
        """Ejecuta un query y retorna todas las filas."""
        async with cls._pool.acquire() as conn:
            return await conn.fetch(query, *args)

    @classmethod
    async def fetchrow(cls, query: str, *args) -> asyncpg.Record | None:
        """Ejecuta un query y retorna la primera fila (o None)."""
        async with cls._pool.acquire() as conn:
            return await conn.fetchrow(query, *args)

    @classmethod
    async def fetchval(cls, query: str, *args):
        """Ejecuta un query y retorna un solo valor escalar."""
        async with cls._pool.acquire() as conn:
            return await conn.fetchval(query, *args)
