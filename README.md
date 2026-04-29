# 🚍 VíaSync ZMG — Motor de Crowdsourcing de Transporte Público

Sistema de monitoreo de transporte público en el Área Metropolitana de Guadalajara mediante **pings geoespaciales ligeros**. Diseñado para minimizar el consumo de batería en dispositivos móviles.

## Arquitectura

```
📱 Dispositivos                    🐍 FastAPI                    🐘 PostgreSQL + PostGIS
┌──────────┐     POST /reportar    ┌──────────────┐              ┌──────────────────────┐
│ UUID anón │ ──────────────────▶   │ SHA-256 hash │ ──INSERT──▶  │ pings_transito       │
│ lat, lon  │     ~120 bytes       │ ~50ms e2e    │              │   GIST index (geom)  │
│ ruta      │                      └──────────────┘              │   BRIN index (ts)    │
└──────────┘                                                     └──────────┬───────────┘
                                                                            │
📊 Consulta                        ┌──────────────┐              ┌──────────▼───────────┐
┌──────────┐     GET /consultar    │ Serializar   │ ◀─clusters── │ vw_estado_actual     │
│ Posición │ ◀─────────────────    │ JSON + ETA   │              │ fn_clustering (DBSCAN)│
│ ETA mins │     ~80ms            └──────────────┘              │ ST_ClusterDBSCAN     │
└──────────┘                                                     └──────────────────────┘
```

## Requisitos Previos

- **PostgreSQL 14+** con extensión **PostGIS 3.x**
- **Python 3.11+**
- pip

## Instalación y Setup

### 1. Base de Datos

```bash
# Crear la base de datos
psql -U postgres -c "CREATE DATABASE viasync;"

# Ejecutar el script de inicialización
psql -U postgres -d viasync -f database/init.sql
```

### 2. Backend

```bash
# Instalar dependencias
cd backend
pip install -r requirements.txt

# Copiar y ajustar variables de entorno
copy ..\.env.example .env    # Windows
# cp ../.env.example .env    # Linux/Mac

# Iniciar el servidor
uvicorn app.main:app --reload --port 8000
```

La API estará disponible en `http://localhost:8000` y la documentación interactiva en `http://localhost:8000/docs`.

---

## 📋 Queries de Demostración (para exposición)

> **IMPORTANTE:** Antes de cada demo, ejecuta `SELECT fn_insertar_pings_demo();` para generar pings frescos (expiran en 2 minutos).

### Conectarse a la base de datos

```bash
psql -U postgres -d viasync
```

### Query 1: Verificar estructura de datos

```sql
-- Ver las rutas registradas
SELECT id, clave, nombre, tipo FROM rutas;

-- Ver paradas de la Línea 1 del Tren Ligero
SELECT nombre, orden,
       ST_X(geom) AS longitud,
       ST_Y(geom) AS latitud
FROM paradas_clave
WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'L1')
ORDER BY orden;
```

### Query 2: Generar pings frescos para demo

```sql
-- Inserta 20 pings agrupados en 6 clusters + 1 outlier
SELECT fn_insertar_pings_demo();
```

### Query 3: Vista de estado actual (últimos 2 minutos)

```sql
-- Solo muestra pings activos — la base del sistema de tiempo real
SELECT
    p.id,
    p.session_hash,
    r.clave AS ruta,
    ST_X(p.geom) AS lon,
    ST_Y(p.geom) AS lat,
    p.ts,
    AGE(NOW(), p.ts) AS hace
FROM vw_estado_actual p
JOIN rutas r ON p.ruta_id = r.id
ORDER BY p.ts DESC;
```

### Query 4: DBSCAN Clustering — Detectar unidades

```sql
-- ⭐ QUERY PRINCIPAL: Detecta unidades por clustering de proximidad
-- Pings a <20m entre sí se agrupan como "misma unidad"
SELECT
    cluster_id AS unidad,
    ST_X(centroide) AS lon,
    ST_Y(centroide) AS lat,
    num_reportes AS reportes,
    ultima_ts
FROM fn_clustering_unidades(
    (SELECT id FROM rutas WHERE clave = 'L1')
);
```

### Query 5: Cálculo de distancia a paradas (base del ETA)

```sql
-- Distancia en metros desde un punto (Juárez) a las paradas más cercanas
SELECT
    p.nombre AS parada,
    ROUND(ST_Distance(
        ST_SetSRID(ST_MakePoint(-103.3547, 20.6747), 4326)::geography,
        p.geom::geography
    )::numeric, 1) AS distancia_metros,
    ROUND((ST_Distance(
        ST_SetSRID(ST_MakePoint(-103.3547, 20.6747), 4326)::geography,
        p.geom::geography
    ) / 583.0)::numeric, 1) AS eta_minutos_tren
FROM paradas_clave p
WHERE p.ruta_id = (SELECT id FROM rutas WHERE clave = 'L1')
ORDER BY p.geom <-> ST_SetSRID(ST_MakePoint(-103.3547, 20.6747), 4326)
LIMIT 5;
```

### Query 6: Demostrar efectividad del índice GIST

```sql
-- EXPLAIN ANALYZE para mostrar que usa el índice GIST
EXPLAIN ANALYZE
SELECT * FROM pings_transito
WHERE ST_DWithin(
    geom::geography,
    ST_SetSRID(ST_MakePoint(-103.3547, 20.6747), 4326)::geography,
    500  -- radio de 500 metros
);
```

### Query 7: Clustering completo con ETA (simula /consultar)

```sql
-- Simula exactamente lo que hace el endpoint GET /consultar/L1
WITH unidades AS (
    SELECT * FROM fn_clustering_unidades(
        (SELECT id FROM rutas WHERE clave = 'L1')
    )
)
SELECT
    u.cluster_id AS unidad,
    u.num_reportes AS confianza,
    p.nombre AS parada_cercana,
    ROUND(ST_Distance(u.centroide::geography, p.geom::geography)::numeric, 0) AS dist_m,
    ROUND((ST_Distance(u.centroide::geography, p.geom::geography) / 583.0)::numeric, 1) AS eta_min
FROM unidades u
CROSS JOIN LATERAL (
    SELECT nombre, geom
    FROM paradas_clave
    WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'L1')
    ORDER BY geom <-> u.centroide
    LIMIT 2
) p
ORDER BY u.cluster_id, dist_m;
```

### Query 8: Purga de pings antiguos (mantenimiento)

```sql
-- Elimina pings con más de 24 horas de antigüedad
SELECT fn_purgar_pings_antiguos(24);

-- Para demo rápida: purgar todo excepto los últimos 5 minutos
SELECT fn_purgar_pings_antiguos(0);  -- purga todo (0 horas de retención)
SELECT fn_insertar_pings_demo();     -- re-insertar datos frescos
```

### Query 9: Demostrar filtrado de noise (DBSCAN minpoints=2)

```sql
-- El outlier 'demo_noise' está aislado (sin vecinos a <20m)
-- Con minpoints=2, DBSCAN lo clasifica como noise (cid = NULL)
SELECT fn_insertar_pings_demo();

-- Ver TODOS los pings incluyendo el outlier
SELECT session_hash, ST_X(geom) AS lon, ST_Y(geom) AS lat
FROM vw_estado_actual WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'L1');

-- El clustering EXCLUYE el outlier automáticamente
SELECT cluster_id, num_reportes, ST_X(centroide) AS lon, ST_Y(centroide) AS lat
FROM fn_clustering_unidades((SELECT id FROM rutas WHERE clave = 'L1'));
-- Resultado: 3 clusters (Juárez=4, Mexicaltzingo=3, Ávila Camacho=2)
-- El ping 'demo_noise' NO aparece → filtrado como ruido ✓
```

### Query 10: Pipeline completo en un solo roundtrip (fn_consultar_ruta_completa)

```sql
-- ⭐ Reemplaza el anti-patrón N+1: clustering + ETA en UNA función
-- Usa CROSS JOIN LATERAL para obtener 3 paradas cercanas por cluster
SELECT fn_insertar_pings_demo();

SELECT cluster_id AS unidad,
       num_reportes AS confianza,
       lat, lon,
       parada_nombre,
       distancia_m,
       eta_minutos
FROM fn_consultar_ruta_completa('L1');
```

---

## ✅ Verificación Automatizada

El script `database/test_queries.sql` ejecuta 13 tests que validan la instalación completa:

```bash
psql -U postgres -d viasync -f database/test_queries.sql
```

Verifica: PostGIS, rutas, paradas, índices, LineString, particionamiento, constraints, triggers, clustering, auditoría y purga.

---

## 🔌 Probar la API (curl)

```bash
# Health check
curl http://localhost:8000/health

# Reportar un ping (simula usuario en tren L1 cerca de Juárez)
curl -X POST http://localhost:8000/reportar \
  -H "Content-Type: application/json" \
  -d '{"uuid":"test-device-001","ruta":"L1","lat":20.6747,"lon":-103.3547}'

# Consultar unidades detectadas en L1 con ETA
curl http://localhost:8000/consultar/L1 | python -m json.tool

# Listar rutas disponibles
curl http://localhost:8000/rutas

# Ver estadísticas del sistema en tiempo real
curl http://localhost:8000/estadisticas | python -m json.tool

# Probar rate limiting (segundo ping será rechazado con 429)
curl -X POST http://localhost:8000/reportar \
  -H "Content-Type: application/json" \
  -d '{"uuid":"test-device-001","ruta":"L1","lat":20.6747,"lon":-103.3547}'
# Esperar 10 segundos antes de repetir, o cambiar uuid
```

## Estructura del Proyecto

```
PingBus-ZMG/
├── database/
│   ├── init.sql              # Schema + índices + funciones + datos de prueba
│   └── test_queries.sql      # 13 tests de verificación automatizada
├── backend/
│   ├── requirements.txt
│   └── app/
│       ├── __init__.py
│       ├── main.py       # FastAPI: endpoints + middleware de privacidad
│       ├── config.py     # Variables de entorno (pydantic-settings)
│       ├── schemas.py    # Validación de payloads (Pydantic v2)
│       └── database.py   # Pool asyncpg singleton
├── .env.example          # Template de variables de entorno
└── README.md
```

## Decisiones Técnicas Clave

| Decisión | Justificación |
|---|---|
| **BIGSERIAL** en pings | Soporta 9.2×10¹⁸ registros vs 2.1×10⁹ de SERIAL |
| **GIST index** | O(log n) para queries espaciales vs O(n) de seq scan |
| **BRIN index** en ts | ~1000x menor que B-tree para datos append-only |
| **TIMESTAMPTZ** | GDL opera en CST/CDT; sin TZ el filtro de 2 min falla |
| **DBSCAN en SQL** | ~15ms vs ~200ms en Python; sin transferencia de datos |
| **asyncpg** | ~3x throughput vs psycopg2 en I/O bound |
| **SHA-256 + salt** | Irreversible, rápido (~0.001ms), rotación diaria |
| **SRID 4326** | Formato GPS nativo; evita transformaciones en INSERT |
| **UTM 32613 para DBSCAN** | eps en metros reales, no en grados imprecisos |
| **Vista vs Materializada** | Lazy evaluation; BRIN filtra en ~1ms sin REFRESH |
| **minpoints=2** | Filtra outliers como noise; requiere 2+ reportes por unidad |
| **Rate limit 10s** | Previene flood + duplicados; idx_session_ts en ~1ms |
| **fn_purgar** | Mantenimiento de tabla; evita crecimiento infinito |
| **Particionamiento** | PARTITION BY RANGE(ts) mensual; pruning automático en vw_estado_actual |
| **LineString en rutas** | Trazado oficial; valida con ST_DWithin que el ping está en la ruta |
| **Trigger validación** | Rechaza pings a >100m del trazado; defensa a nivel de motor de datos |
| **CHECK ST_Contains** | Bounds del AMG como constraint; O(1) con ST_MakeEnvelope |
| **created_at/updated_at** | Auditoría estándar con trigger automático en UPDATE |
| **PK compuesta (id,ts)** | Requerida por particionamiento; secuencia global mantiene unicidad |
| **fn_consultar_ruta_completa** | Elimina N+1: clustering + ETA en 1 roundtrip con LATERAL JOIN |
