-- ===========================================================================
-- VíaSync ZMG — Inicialización de Base de Datos
-- Motor de crowdsourcing para monitoreo de transporte público en Guadalajara
-- ===========================================================================
-- Requisitos: PostgreSQL 14+ con PostGIS 3.x
-- Ejecución:  psql -U postgres -d viasync -f init.sql
-- ===========================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. EXTENSIONES
-- ═══════════════════════════════════════════════════════════════════════════

-- PostGIS: tipos geoespaciales (geometry/geography) y funciones espaciales
-- como ST_Distance, ST_DWithin, ST_ClusterDBSCAN, ST_Transform, etc.
CREATE EXTENSION IF NOT EXISTS postgis;

-- pgcrypto: gen_random_uuid() para generación de UUIDs criptográficos
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. TABLAS
-- ═══════════════════════════════════════════════════════════════════════════

-- RUTAS: Catálogo de rutas de transporte público.
-- VARCHAR(10) en clave: los códigos GDL son cortos (A04, C-09, L1, L3).
-- CHECK en tipo: restringe a valores válidos, usado para velocidad ETA.
-- geometry(LineString, 4326): trazado oficial de la ruta. Permite validar
-- con ST_DWithin que un ping realmente está sobre la ruta y no en la banqueta.
-- created_at/updated_at: campos de auditoría estándar de la industria.
CREATE TABLE IF NOT EXISTS rutas (
    id         SERIAL PRIMARY KEY,
    clave      VARCHAR(10) UNIQUE NOT NULL,
    nombre     TEXT NOT NULL,
    tipo       VARCHAR(20) NOT NULL
               CHECK (tipo IN ('tren_ligero', 'autobus', 'alimentador')),
    geom       geometry(LineString, 4326),          -- Trazado oficial del recorrido
    activa     BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),   -- Auditoría: fecha de creación
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()    -- Auditoría: última modificación
);
COMMENT ON TABLE rutas IS 'Catálogo de rutas de transporte público del AMG';
COMMENT ON COLUMN rutas.tipo IS 'Tipo de transporte: determina velocidad promedio para ETA';
COMMENT ON COLUMN rutas.geom IS 'LineString del trazado oficial; usado para validar proximidad de pings con ST_DWithin';

-- PARADAS_CLAVE: Puntos de referencia para cálculo de ETA.
-- geometry(Point, 4326): WGS84, formato nativo GPS. Evita transformaciones
-- costosas en el INSERT del endpoint /reportar (optimización de batería).
CREATE TABLE IF NOT EXISTS paradas_clave (
    id         SERIAL PRIMARY KEY,
    ruta_id    INT NOT NULL REFERENCES rutas(id) ON DELETE CASCADE,
    nombre     TEXT NOT NULL,
    geom       geometry(Point, 4326) NOT NULL,
    orden      INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE paradas_clave IS 'Estaciones/paradas de referencia para cálculo de ETA';
COMMENT ON COLUMN paradas_clave.orden IS 'Secuencia en la ruta para inferir dirección de viaje';

-- PINGS_TRANSITO: Ubicaciones anónimas reportadas por usuarios.
-- PARTICIONAMIENTO DECLARATIVO por rango de ts (mensual).
-- ¿Por qué particionar?
--   1) Partition pruning: la vista vw_estado_actual (WHERE ts >= NOW()-2min)
--      solo escanea la partición activa, ignorando meses anteriores.
--   2) Mantenimiento: DROP PARTITION es O(1) vs DELETE masivo + VACUUM.
--   3) Paralelismo: cada partición tiene su propio índice GIST/BRIN.
--
-- PRIMARY KEY (id, ts): PostgreSQL exige que la columna de partición
-- esté incluida en la PK. El BIGSERIAL sigue siendo único en la práctica
-- (comparte secuencia global), pero la PK compuesta lo hace explícito.
--
-- CONSTRAINT chk_pings_dentro_amg: defensa en profundidad — valida que
-- las coordenadas estén dentro del AMG a nivel de motor de datos.
-- ST_MakeEnvelope es O(1), no penaliza el INSERT.
CREATE TABLE IF NOT EXISTS pings_transito (
    id            BIGSERIAL,
    session_hash  VARCHAR(64) NOT NULL,
    ruta_id       INT NOT NULL REFERENCES rutas(id),
    geom          geometry(Point, 4326) NOT NULL,
    ts            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, ts),
    CONSTRAINT chk_pings_dentro_amg CHECK (
        ST_Contains(
            ST_MakeEnvelope(-103.55, 20.40, -103.15, 20.85, 4326),
            geom
        )
    )
) PARTITION BY RANGE (ts);

COMMENT ON TABLE pings_transito IS 'Ubicaciones anónimas por crowdsourcing (particionada por mes)';
COMMENT ON COLUMN pings_transito.session_hash
    IS 'Hash SHA-256 del UUID + salt rotativo diario. Irreversible.';

-- Particiones mensuales: en producción usar pg_partman para auto-creación.
-- Cada partición hereda índices y constraints de la tabla padre.
CREATE TABLE IF NOT EXISTS pings_2026_04 PARTITION OF pings_transito
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE IF NOT EXISTS pings_2026_05 PARTITION OF pings_transito
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE IF NOT EXISTS pings_2026_06 PARTITION OF pings_transito
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
-- Partición default: captura datos fuera de rangos definidos.
-- Evita errores de INSERT si se olvida crear la partición del mes.
CREATE TABLE IF NOT EXISTS pings_default PARTITION OF pings_transito DEFAULT;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2b. TRIGGERS DE AUDITORÍA
-- ═══════════════════════════════════════════════════════════════════════════
-- Patrón estándar: función genérica + trigger por tabla.
-- Actualiza updated_at automáticamente en cada UPDATE sin intervención
-- del código de aplicación (el backend no necesita saber de este campo).

CREATE OR REPLACE FUNCTION fn_actualizar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rutas_updated_at
    BEFORE UPDATE ON rutas
    FOR EACH ROW EXECUTE FUNCTION fn_actualizar_updated_at();

CREATE TRIGGER trg_paradas_updated_at
    BEFORE UPDATE ON paradas_clave
    FOR EACH ROW EXECUTE FUNCTION fn_actualizar_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. ÍNDICES
-- ═══════════════════════════════════════════════════════════════════════════

-- GIST (Generalized Search Tree) sobre geometría:
-- Árbol espacial que permite ST_DWithin, ST_Intersects en O(log n)
-- vs O(n) de sequential scan. Core del sistema de clustering.
CREATE INDEX IF NOT EXISTS idx_pings_geom
    ON pings_transito USING GIST (geom);

-- BRIN (Block Range INdex) sobre timestamp:
-- Almacena solo min/max por bloque de páginas → ~1000x menor que B-tree.
-- Perfecto para pings_transito (append-only = alta correlación física
-- entre valor de ts y posición en disco).
CREATE INDEX IF NOT EXISTS idx_pings_ts
    ON pings_transito USING BRIN (ts);

-- B-tree compuesto (ruta_id, ts DESC):
-- Optimiza el query más frecuente: "pings recientes de la ruta X".
-- DESC evita un sort adicional en consultas con ORDER BY ts DESC.
CREATE INDEX IF NOT EXISTS idx_pings_ruta_ts
    ON pings_transito (ruta_id, ts DESC);

-- GIST para paradas (proximidad en cálculo de ETA)
CREATE INDEX IF NOT EXISTS idx_paradas_geom
    ON paradas_clave USING GIST (geom);

-- GIST para trazado oficial de rutas (validación de proximidad de pings)
CREATE INDEX IF NOT EXISTS idx_rutas_geom
    ON rutas USING GIST (geom);

-- B-tree para rate limiting: búsqueda rápida por session_hash + tiempo.
-- Permite verificar "¿este usuario ya envió un ping hace < 10 segundos?"
-- en ~1ms incluso con millones de registros.
CREATE INDEX IF NOT EXISTS idx_pings_session_ts
    ON pings_transito (session_hash, ts DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. VISTA: vw_estado_actual
-- ═══════════════════════════════════════════════════════════════════════════
-- Filtra pings a últimos 2 minutos. Sin ella, fn_clustering procesaría
-- TODOS los pings históricos → degradación exponencial.
--
-- ¿Por qué vista y no tabla materializada?
-- La materializada requiere REFRESH periódico (pg_cron). La vista es lazy:
-- se evalúa solo al consultarla, y el índice BRIN filtra en ~1ms.
CREATE OR REPLACE VIEW vw_estado_actual AS
SELECT id, session_hash, ruta_id, geom, ts
FROM pings_transito
WHERE ts >= NOW() - INTERVAL '2 minutes';

COMMENT ON VIEW vw_estado_actual
    IS 'Pings activos de los últimos 2 minutos. Base para clustering.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. FUNCIÓN: fn_clustering_unidades (PL/pgSQL + DBSCAN)
-- ═══════════════════════════════════════════════════════════════════════════
-- Calcula posición estimada de cada unidad usando DBSCAN.
--
-- ¿Por qué DBSCAN y no K-Means?
--   1) No requiere conocer K (no sabemos cuántos camiones hay)
--   2) Identifica outliers (pings erróneos = noise, cid IS NULL)
--   3) Funciona con clusters de forma arbitraria
--
-- ¿Por qué en SQL y no en Python?
--   El clustering opera sobre el índice GIST sin transferir datos.
--   SQL: ~15ms vs Python (scikit-learn): ~200ms + serialización.
--
-- Parámetros:
--   eps=20m: dos personas en el mismo camión están a <20m.
--   minpoints=2: se requieren al menos 2 reportes independientes para
--     confirmar una unidad. Filtra pings aislados (GPS erróneos, usuarios
--     que reportan ruta equivocada) como noise automáticamente.
--
-- Se transforma a EPSG:32613 (UTM Zona 13N, cubre GDL) para que eps
-- opere en metros reales, no en grados.
CREATE OR REPLACE FUNCTION fn_clustering_unidades(p_ruta_id INT)
RETURNS TABLE (
    cluster_id    INT,
    centroide     geometry,
    num_reportes  BIGINT,
    ultima_ts     TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE  -- No modifica datos; permite optimizaciones del planner
AS $$
BEGIN
    RETURN QUERY
    WITH pings_utm AS (
        -- Paso 1: Filtrar pings activos y transformar a UTM (metros)
        SELECT
            v.id,
            v.geom,
            v.ts,
            ST_Transform(v.geom, 32613) AS geom_utm
        FROM vw_estado_actual v
        WHERE v.ruta_id = p_ruta_id
    ),
    clustered AS (
        -- Paso 2: DBSCAN con eps=20m, minpoints=2 (filtra outliers)
        SELECT
            p.id,
            p.geom,
            p.ts,
            p.geom_utm,
            ST_ClusterDBSCAN(p.geom_utm, eps := 20, minpoints := 2)
                OVER (ORDER BY p.id) AS cid
        FROM pings_utm p
    )
    -- Paso 3: Centroide por cluster, transformado de vuelta a WGS84
    SELECT
        c.cid::INT                                        AS cluster_id,
        ST_Transform(ST_Centroid(ST_Collect(c.geom_utm)), 4326) AS centroide,
        COUNT(*)::BIGINT                                  AS num_reportes,
        MAX(c.ts)                                         AS ultima_ts
    FROM clustered c
    WHERE c.cid IS NOT NULL
    GROUP BY c.cid
    ORDER BY MAX(c.ts) DESC;
END;
$$;

COMMENT ON FUNCTION fn_clustering_unidades IS
    'DBSCAN clustering de pings activos por ruta. Retorna posición, confianza y timestamp.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 5b. FUNCIÓN: fn_consultar_ruta_completa (pipeline unificado)
-- ═══════════════════════════════════════════════════════════════════════════
-- Resuelve el anti-patrón N+1: antes, el backend ejecutaba 1 query de
-- clustering + N queries de ETA (una por cada unidad detectada).
-- Con 5 unidades = 6 roundtrips al servidor.
--
-- Esta función consolida TODO el pipeline en UN solo roundtrip:
--   1. Resuelve clave → ruta_id + tipo
--   2. Ejecuta fn_clustering_unidades (DBSCAN)
--   3. CROSS JOIN LATERAL calcula las 3 paradas más cercanas por cluster
--   4. ETA = distancia / velocidad según tipo de transporte
--
-- ¿Por qué CROSS JOIN LATERAL y no un subquery correlacionado?
--   LATERAL permite referenciar columnas de la tabla exterior (clusters)
--   dentro del subquery, habilitando ORDER BY + LIMIT por cada fila.
--   Es el equivalente PostgreSQL de "para cada cluster, dame las 3
--   paradas más cercanas" — imposible de expresar con un JOIN normal.
--
-- El operador <-> usa el índice GIST (KNN distance) para encontrar
-- las paradas cercanas sin calcular distancia a TODAS las paradas.

CREATE OR REPLACE FUNCTION fn_consultar_ruta_completa(p_ruta_clave VARCHAR)
RETURNS TABLE (
    cluster_id    INT,
    lat           DOUBLE PRECISION,
    lon           DOUBLE PRECISION,
    num_reportes  BIGINT,
    ultima_ts     TIMESTAMPTZ,
    parada_nombre TEXT,
    distancia_m   DOUBLE PRECISION,
    eta_minutos   DOUBLE PRECISION
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_ruta_id  INT;
    v_tipo     VARCHAR(20);
    v_vel      DOUBLE PRECISION;
BEGIN
    -- Paso 1: Resolver clave → id + tipo
    SELECT r.id, r.tipo INTO v_ruta_id, v_tipo
    FROM rutas r
    WHERE r.clave = p_ruta_clave AND r.activa = TRUE;

    IF v_ruta_id IS NULL THEN
        RETURN;  -- Retorna vacío si la ruta no existe; el backend maneja el 404
    END IF;

    -- Velocidad según tipo (mismos valores que config.py)
    v_vel := CASE WHEN v_tipo = 'tren_ligero' THEN 583.0 ELSE 300.0 END;

    -- Paso 2-4: Clustering + LATERAL JOIN + ETA en un solo query
    RETURN QUERY
    SELECT
        u.cluster_id,
        ST_Y(u.centroide)::DOUBLE PRECISION   AS lat,
        ST_X(u.centroide)::DOUBLE PRECISION   AS lon,
        u.num_reportes,
        u.ultima_ts,
        p.nombre                               AS parada_nombre,
        ROUND(ST_Distance(
            u.centroide::geography,
            p.geom::geography
        )::numeric, 1)::DOUBLE PRECISION       AS distancia_m,
        ROUND((ST_Distance(
            u.centroide::geography,
            p.geom::geography
        ) / v_vel)::numeric, 1)::DOUBLE PRECISION AS eta_minutos
    FROM fn_clustering_unidades(v_ruta_id) u
    CROSS JOIN LATERAL (
        -- Para cada cluster, obtener las 3 paradas más cercanas
        -- usando el operador KNN <-> sobre el índice GIST
        SELECT pc.nombre, pc.geom
        FROM paradas_clave pc
        WHERE pc.ruta_id = v_ruta_id
        ORDER BY pc.geom <-> u.centroide
        LIMIT 3
    ) p
    ORDER BY u.ultima_ts DESC, distancia_m;
END;
$$;

COMMENT ON FUNCTION fn_consultar_ruta_completa IS
    'Pipeline completo: DBSCAN + ETA en un solo roundtrip. Elimina N+1 del endpoint /consultar.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 5b. FUNCIÓN: fn_purgar_pings_antiguos (mantenimiento)
-- ═══════════════════════════════════════════════════════════════════════════
-- Sin purga, pings_transito crece indefinidamente → degradación de índices,
-- aumento de almacenamiento, y backups innecesariamente pesados.
-- En producción: programar con pg_cron o cron del SO cada hora.
-- Uso: SELECT fn_purgar_pings_antiguos(24);  -- purga pings > 24 horas

CREATE OR REPLACE FUNCTION fn_purgar_pings_antiguos(p_horas INT DEFAULT 24)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count BIGINT;
BEGIN
    DELETE FROM pings_transito
    WHERE ts < NOW() - make_interval(hours => p_horas);

    GET DIAGNOSTICS v_count = ROW_COUNT;

    -- VACUUM no se puede ejecutar dentro de una función/transacción,
    -- pero el autovacuum de PostgreSQL lo hará automáticamente.
    RETURN format('OK: %s pings purgados (antigüedad > %s horas).', v_count, p_horas);
END;
$$;

COMMENT ON FUNCTION fn_purgar_pings_antiguos IS
    'Elimina pings antiguos para mantener la tabla compacta. Parámetro: horas de retención.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. DATOS INICIALES: Rutas (sin geom; se calcula después desde paradas)
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO rutas (clave, nombre, tipo) VALUES
    ('L1',   'Línea 1 Tren Ligero (Auditorio – Periférico Sur)', 'tren_ligero'),
    ('L3',   'Línea 3 Mi Tren (Arcos – Central Camionera)',       'tren_ligero'),
    ('C-09', 'Ruta C-09 (Centro Sur – Los Abedules)',             'autobus'),
    ('A04',  'Alimentadora A04 (Periférico Sur – Lomas San Agustín)', 'alimentador')
ON CONFLICT (clave) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. DATOS INICIALES: Paradas clave (coordenadas reales de GDL)
-- ═══════════════════════════════════════════════════════════════════════════

-- --- L1: Tren Ligero (20 estaciones, Norte → Sur) ---
-- Coordenadas obtenidas de OpenStreetMap / Wikipedia SITEUR.
-- ST_MakePoint(longitud, latitud) — OJO: lon primero, lat después.
INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
    ((SELECT id FROM rutas WHERE clave='L1'), 'Auditorio',
        ST_SetSRID(ST_MakePoint(-103.3494, 20.7381), 4326), 1),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Periférico Norte',
        ST_SetSRID(ST_MakePoint(-103.3497, 20.7306), 4326), 2),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Dermatológico',
        ST_SetSRID(ST_MakePoint(-103.3500, 20.7222), 4326), 3),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Atemajac',
        ST_SetSRID(ST_MakePoint(-103.3508, 20.7139), 4326), 4),
    ((SELECT id FROM rutas WHERE clave='L1'), 'División del Norte',
        ST_SetSRID(ST_MakePoint(-103.3511, 20.7056), 4326), 5),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Ávila Camacho',
        ST_SetSRID(ST_MakePoint(-103.3514, 20.6972), 4326), 6),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Mezquitán',
        ST_SetSRID(ST_MakePoint(-103.3528, 20.6889), 4326), 7),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Refugio',
        ST_SetSRID(ST_MakePoint(-103.3539, 20.6806), 4326), 8),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Juárez',
        ST_SetSRID(ST_MakePoint(-103.3547, 20.6747), 4326), 9),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Mexicaltzingo',
        ST_SetSRID(ST_MakePoint(-103.3550, 20.6667), 4326), 10),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Washington',
        ST_SetSRID(ST_MakePoint(-103.3558, 20.6611), 4326), 11),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Santa Filomena',
        ST_SetSRID(ST_MakePoint(-103.3572, 20.6556), 4326), 12),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Unidad Deportiva',
        ST_SetSRID(ST_MakePoint(-103.3603, 20.6486), 4326), 13),
    ((SELECT id FROM rutas WHERE clave='L1'), 'España',
        ST_SetSRID(ST_MakePoint(-103.3639, 20.6417), 4326), 14),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Urdaneta',
        ST_SetSRID(ST_MakePoint(-103.3681, 20.6361), 4326), 15),
    ((SELECT id FROM rutas WHERE clave='L1'), '18 de Marzo',
        ST_SetSRID(ST_MakePoint(-103.3722, 20.6306), 4326), 16),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Patria',
        ST_SetSRID(ST_MakePoint(-103.3778, 20.6222), 4326), 17),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Isla Raza',
        ST_SetSRID(ST_MakePoint(-103.3822, 20.6167), 4326), 18),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Santuario',
        ST_SetSRID(ST_MakePoint(-103.3883, 20.6111), 4326), 19),
    ((SELECT id FROM rutas WHERE clave='L1'), 'Periférico Sur',
        ST_SetSRID(ST_MakePoint(-103.4011, 20.6067), 4326), 20);

-- --- L3: Mi Tren (tramo representativo Este-Oeste por Periférico) ---
INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
    ((SELECT id FROM rutas WHERE clave='L3'), 'Central de Autobuses',
        ST_SetSRID(ST_MakePoint(-103.3175, 20.6550), 4326), 1),
    ((SELECT id FROM rutas WHERE clave='L3'), 'Plaza de la Bandera',
        ST_SetSRID(ST_MakePoint(-103.3275, 20.6600), 4326), 2),
    ((SELECT id FROM rutas WHERE clave='L3'), 'Ávila Camacho (Transbordo L1)',
        ST_SetSRID(ST_MakePoint(-103.3514, 20.6972), 4326), 3),
    ((SELECT id FROM rutas WHERE clave='L3'), 'Normal',
        ST_SetSRID(ST_MakePoint(-103.3650, 20.6950), 4326), 4),
    ((SELECT id FROM rutas WHERE clave='L3'), 'Arcos de Guadalajara',
        ST_SetSRID(ST_MakePoint(-103.3900, 20.6894), 4326), 5);

-- --- C-09: Zona sur (Centro Sur → Los Abedules) ---
INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
    ((SELECT id FROM rutas WHERE clave='C-09'), 'Centro Sur',
        ST_SetSRID(ST_MakePoint(-103.3997, 20.5747), 4326), 1),
    ((SELECT id FROM rutas WHERE clave='C-09'), 'Camino Real a Colima',
        ST_SetSRID(ST_MakePoint(-103.3933, 20.5694), 4326), 2),
    ((SELECT id FROM rutas WHERE clave='C-09'), 'Loma Bonita',
        ST_SetSRID(ST_MakePoint(-103.3867, 20.5639), 4326), 3),
    ((SELECT id FROM rutas WHERE clave='C-09'), 'El Vergel',
        ST_SetSRID(ST_MakePoint(-103.3800, 20.5583), 4326), 4),
    ((SELECT id FROM rutas WHERE clave='C-09'), 'Lomas del Valle',
        ST_SetSRID(ST_MakePoint(-103.3733, 20.5528), 4326), 5),
    ((SELECT id FROM rutas WHERE clave='C-09'), 'Los Abedules',
        ST_SetSRID(ST_MakePoint(-103.3667, 20.5472), 4326), 6);

-- --- A04: Alimentadora (Periférico Sur → López Mateos Sur) ---
INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
    ((SELECT id FROM rutas WHERE clave='A04'), 'Periférico Sur (Conexión L1)',
        ST_SetSRID(ST_MakePoint(-103.4011, 20.6067), 4326), 1),
    ((SELECT id FROM rutas WHERE clave='A04'), 'La Tijera',
        ST_SetSRID(ST_MakePoint(-103.4100, 20.5975), 4326), 2),
    ((SELECT id FROM rutas WHERE clave='A04'), 'El Palomar',
        ST_SetSRID(ST_MakePoint(-103.4200, 20.5883), 4326), 3),
    ((SELECT id FROM rutas WHERE clave='A04'), 'Los Gavilanes',
        ST_SetSRID(ST_MakePoint(-103.4280, 20.5800), 4326), 4),
    ((SELECT id FROM rutas WHERE clave='A04'), 'Lomas de San Agustín',
        ST_SetSRID(ST_MakePoint(-103.4350, 20.5725), 4326), 5);

-- ═══════════════════════════════════════════════════════════════════════════
-- 7b. GENERAR TRAZADO OFICIAL (LineString) DESDE PARADAS
-- ═══════════════════════════════════════════════════════════════════════════
-- ST_MakeLine con array_agg ordenado por parada genera el LineString
-- oficial de cada ruta. Técnica elegante: no duplicamos coordenadas,
-- las derivamos de los datos existentes (Single Source of Truth).
UPDATE rutas SET geom = sub.linea
FROM (
    SELECT p.ruta_id,
           ST_SetSRID(ST_MakeLine(array_agg(p.geom ORDER BY p.orden)), 4326) AS linea
    FROM paradas_clave p
    GROUP BY p.ruta_id
) sub
WHERE rutas.id = sub.ruta_id;

-- ═══════════════════════════════════════════════════════════════════════════
-- 7c. TRIGGER: Validar proximidad de ping al trazado oficial
-- ═══════════════════════════════════════════════════════════════════════════
-- Un usuario que reporta ruta "L1" pero está a 500m de las vías
-- probablemente seleccionó la ruta equivocada. Este trigger rechaza
-- pings a más de 100m del trazado oficial (tolerancia para GPS impreciso).
-- Solo valida si la ruta tiene geom definido (NULL = sin restricción).

CREATE OR REPLACE FUNCTION trg_validar_ping_en_ruta()
RETURNS TRIGGER AS $$
DECLARE
    v_distancia DOUBLE PRECISION;
BEGIN
    SELECT ST_Distance(r.geom::geography, NEW.geom::geography)
    INTO v_distancia
    FROM rutas r
    WHERE r.id = NEW.ruta_id AND r.geom IS NOT NULL;

    IF v_distancia IS NOT NULL AND v_distancia > 100 THEN
        RAISE EXCEPTION 'Ping a %.0fm del trazado de la ruta (máx: 100m). ¿Ruta correcta?', v_distancia
            USING HINT = 'Verifique que el usuario está cerca de la ruta reportada';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger en cada partición (PG requiere triggers por partición, no en tabla padre)
-- En producción, usar un event trigger para aplicarlo a particiones nuevas.
CREATE TRIGGER trg_pings_validar_ruta
    BEFORE INSERT ON pings_2026_04
    FOR EACH ROW EXECUTE FUNCTION trg_validar_ping_en_ruta();
CREATE TRIGGER trg_pings_validar_ruta
    BEFORE INSERT ON pings_2026_05
    FOR EACH ROW EXECUTE FUNCTION trg_validar_ping_en_ruta();
CREATE TRIGGER trg_pings_validar_ruta
    BEFORE INSERT ON pings_2026_06
    FOR EACH ROW EXECUTE FUNCTION trg_validar_ping_en_ruta();
CREATE TRIGGER trg_pings_validar_ruta
    BEFORE INSERT ON pings_default
    FOR EACH ROW EXECUTE FUNCTION trg_validar_ping_en_ruta();

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. FUNCIÓN DE DEMO: Inserta pings frescos para demostración
-- ═══════════════════════════════════════════════════════════════════════════
-- Los pings expiran en 2 minutos (vw_estado_actual). Esta función genera
-- pings con timestamp NOW() para que la demo funcione en cualquier momento.
-- Uso: SELECT fn_insertar_pings_demo();

CREATE OR REPLACE FUNCTION fn_insertar_pings_demo()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_l1  INT;
    v_c09 INT;
    v_l3  INT;
BEGIN
    SELECT id INTO v_l1  FROM rutas WHERE clave = 'L1';
    SELECT id INTO v_c09 FROM rutas WHERE clave = 'C-09';
    SELECT id INTO v_l3  FROM rutas WHERE clave = 'L3';

    -- Limpiar pings demo anteriores
    DELETE FROM pings_transito WHERE session_hash LIKE 'demo_%';

    -- ── CLUSTER A: 4 usuarios cerca de Juárez (L1) ──
    -- Simula un tren con 4 pasajeros reportando (~10m entre sí)
    INSERT INTO pings_transito (session_hash, ruta_id, geom, ts) VALUES
        ('demo_a1', v_l1, ST_SetSRID(ST_MakePoint(-103.3547, 20.6747), 4326), NOW() - INTERVAL '30s'),
        ('demo_a2', v_l1, ST_SetSRID(ST_MakePoint(-103.3548, 20.6748), 4326), NOW() - INTERVAL '25s'),
        ('demo_a3', v_l1, ST_SetSRID(ST_MakePoint(-103.3546, 20.6746), 4326), NOW() - INTERVAL '18s'),
        ('demo_a4', v_l1, ST_SetSRID(ST_MakePoint(-103.3547, 20.6749), 4326), NOW() - INTERVAL '10s');

    -- ── CLUSTER B: 3 usuarios cerca de Mexicaltzingo (L1) ──
    INSERT INTO pings_transito (session_hash, ruta_id, geom, ts) VALUES
        ('demo_b1', v_l1, ST_SetSRID(ST_MakePoint(-103.3550, 20.6667), 4326), NOW() - INTERVAL '45s'),
        ('demo_b2', v_l1, ST_SetSRID(ST_MakePoint(-103.3551, 20.6668), 4326), NOW() - INTERVAL '35s'),
        ('demo_b3', v_l1, ST_SetSRID(ST_MakePoint(-103.3549, 20.6666), 4326), NOW() - INTERVAL '20s');

    -- ── CLUSTER C: 2 usuarios cerca de Ávila Camacho (L1) ──
    INSERT INTO pings_transito (session_hash, ruta_id, geom, ts) VALUES
        ('demo_c1', v_l1, ST_SetSRID(ST_MakePoint(-103.3514, 20.6972), 4326), NOW() - INTERVAL '50s'),
        ('demo_c2', v_l1, ST_SetSRID(ST_MakePoint(-103.3515, 20.6973), 4326), NOW() - INTERVAL '40s');

    -- ── CLUSTER D: 3 usuarios en ruta C-09 (Centro Sur) ──
    INSERT INTO pings_transito (session_hash, ruta_id, geom, ts) VALUES
        ('demo_d1', v_c09, ST_SetSRID(ST_MakePoint(-103.3997, 20.5747), 4326), NOW() - INTERVAL '20s'),
        ('demo_d2', v_c09, ST_SetSRID(ST_MakePoint(-103.3998, 20.5748), 4326), NOW() - INTERVAL '15s'),
        ('demo_d3', v_c09, ST_SetSRID(ST_MakePoint(-103.3996, 20.5746), 4326), NOW() - INTERVAL '8s');

    -- ── CLUSTER E: 2 usuarios en ruta C-09 (Loma Bonita) ──
    INSERT INTO pings_transito (session_hash, ruta_id, geom, ts) VALUES
        ('demo_e1', v_c09, ST_SetSRID(ST_MakePoint(-103.3867, 20.5639), 4326), NOW() - INTERVAL '30s'),
        ('demo_e2', v_c09, ST_SetSRID(ST_MakePoint(-103.3868, 20.5640), 4326), NOW() - INTERVAL '22s');

    -- ── CLUSTER F: 3 usuarios en L3 (Plaza de la Bandera) ──
    INSERT INTO pings_transito (session_hash, ruta_id, geom, ts) VALUES
        ('demo_f1', v_l3, ST_SetSRID(ST_MakePoint(-103.3275, 20.6600), 4326), NOW() - INTERVAL '15s'),
        ('demo_f2', v_l3, ST_SetSRID(ST_MakePoint(-103.3276, 20.6601), 4326), NOW() - INTERVAL '10s'),
        ('demo_f3', v_l3, ST_SetSRID(ST_MakePoint(-103.3274, 20.6599), 4326), NOW() - INTERVAL '5s');

    -- ── OUTLIER: 1 ping aislado SOBRE la ruta (pasa validación de ruta,
    -- pero al ser único con minpoints=2, DBSCAN lo clasifica como noise)
    INSERT INTO pings_transito (session_hash, ruta_id, geom, ts) VALUES
        ('demo_noise', v_l1, ST_SetSRID(ST_MakePoint(-103.3779, 20.6223), 4326), NOW() - INTERVAL '55s');

    RETURN 'OK: 20 pings demo insertados (6 clusters + 1 outlier). Válidos por 2 minutos.';
END;
$$;

COMMENT ON FUNCTION fn_insertar_pings_demo IS
    'Inserta pings frescos para demostración. Ejecutar antes de cada demo.';

-- Ejecutar automáticamente al correr el script
SELECT fn_insertar_pings_demo();
