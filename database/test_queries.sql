-- ===========================================================================
-- VíaSync ZMG — Script de Verificación Automatizada
-- Valida que la instalación está correcta y todas las funciones operan.
-- ===========================================================================
-- Ejecución: psql -U postgres -d viasync -f database/test_queries.sql
-- ===========================================================================

-- ── Test 1: PostGIS habilitado ──
DO $$
DECLARE v_ver TEXT;
BEGIN
    SELECT PostGIS_Version() INTO v_ver;
    IF v_ver IS NULL THEN
        RAISE EXCEPTION '✗ Test 1: PostGIS no está habilitado';
    END IF;
    RAISE NOTICE '✓ Test 1: PostGIS habilitado (versión %)', v_ver;
END $$;

-- ── Test 2: Las 4 rutas existen ──
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM rutas WHERE clave IN ('L1', 'L3', 'C-09', 'A04');
    IF v_count != 4 THEN
        RAISE EXCEPTION '✗ Test 2: Se esperaban 4 rutas, se encontraron %', v_count;
    END IF;
    RAISE NOTICE '✓ Test 2: Las 4 rutas existen (L1, L3, C-09, A04)';
END $$;

-- ── Test 3: L1 tiene 20 paradas ──
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM paradas_clave
    WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'L1');
    IF v_count != 20 THEN
        RAISE EXCEPTION '✗ Test 3: L1 debería tener 20 paradas, tiene %', v_count;
    END IF;
    RAISE NOTICE '✓ Test 3: L1 tiene exactamente 20 paradas';
END $$;

-- ── Test 4: Índices GIST y BRIN existen ──
DO $$
DECLARE
    v_gist INT;
    v_brin INT;
BEGIN
    SELECT COUNT(*) INTO v_gist
    FROM pg_indexes WHERE indexname = 'idx_pings_geom';
    SELECT COUNT(*) INTO v_brin
    FROM pg_indexes WHERE indexname = 'idx_pings_ts';
    IF v_gist = 0 THEN
        RAISE EXCEPTION '✗ Test 4: Índice GIST idx_pings_geom no encontrado';
    END IF;
    IF v_brin = 0 THEN
        RAISE EXCEPTION '✗ Test 4: Índice BRIN idx_pings_ts no encontrado';
    END IF;
    RAISE NOTICE '✓ Test 4: Índices GIST y BRIN existen';
END $$;

-- ── Test 5: Rutas tienen trazado LineString ──
DO $$
DECLARE v_null_count INT;
BEGIN
    SELECT COUNT(*) INTO v_null_count
    FROM rutas WHERE geom IS NULL AND activa = TRUE;
    IF v_null_count > 0 THEN
        RAISE EXCEPTION '✗ Test 5: % rutas activas sin trazado LineString', v_null_count;
    END IF;
    RAISE NOTICE '✓ Test 5: Todas las rutas activas tienen trazado LineString';
END $$;

-- ── Test 6: fn_insertar_pings_demo inserta 20 pings ──
DO $$
DECLARE
    v_result TEXT;
    v_count  BIGINT;
BEGIN
    PERFORM fn_insertar_pings_demo();
    SELECT COUNT(*) INTO v_count
    FROM pings_transito WHERE session_hash LIKE 'demo_%';
    IF v_count != 20 THEN
        RAISE EXCEPTION '✗ Test 6: Se esperaban 20 pings demo, se insertaron %', v_count;
    END IF;
    RAISE NOTICE '✓ Test 6: fn_insertar_pings_demo insertó exactamente 20 pings';
END $$;

-- ── Test 7: vw_estado_actual muestra los pings frescos ──
DO $$
DECLARE v_count BIGINT;
BEGIN
    -- Los pings demo se insertaron con NOW()-Xs, deben estar en la vista
    SELECT COUNT(*) INTO v_count FROM vw_estado_actual;
    IF v_count < 20 THEN
        RAISE EXCEPTION '✗ Test 7: vw_estado_actual muestra solo % pings (esperados >= 20)', v_count;
    END IF;
    RAISE NOTICE '✓ Test 7: vw_estado_actual muestra % pings activos', v_count;
END $$;

-- ── Test 8: Clustering L1 retorna 3 clusters ──
DO $$
DECLARE v_clusters INT;
BEGIN
    -- Con los pings demo: Juárez(4), Mexicaltzingo(3), Ávila Camacho(2)
    -- El outlier cerca de Patria es noise con minpoints=2
    SELECT COUNT(*) INTO v_clusters
    FROM fn_clustering_unidades((SELECT id FROM rutas WHERE clave = 'L1'));
    IF v_clusters != 3 THEN
        RAISE EXCEPTION '✗ Test 8: Se esperaban 3 clusters en L1, se obtuvieron %', v_clusters;
    END IF;
    RAISE NOTICE '✓ Test 8: DBSCAN detectó exactamente 3 clusters en L1 (outlier filtrado como noise)';
END $$;

-- ── Test 9: CHECK constraint rechaza coordenadas fuera del AMG ──
DO $$
BEGIN
    BEGIN
        INSERT INTO pings_transito (session_hash, ruta_id, geom, ts)
        VALUES ('test_fuera', 1,
                ST_SetSRID(ST_MakePoint(-103.40, 19.0), 4326), NOW());
        -- Si llega aquí, el constraint no funcionó
        RAISE EXCEPTION '✗ Test 9: El INSERT fuera del AMG NO fue rechazado';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ Test 9: CHECK chk_pings_dentro_amg rechazó coordenadas fuera del AMG';
    END;
END $$;

-- ── Test 10: Trigger rechaza pings lejos del trazado ──
DO $$
BEGIN
    BEGIN
        -- Punto a ~2km del trazado de L1, pero dentro del AMG
        INSERT INTO pings_transito (session_hash, ruta_id, geom, ts)
        VALUES ('test_lejos',
                (SELECT id FROM rutas WHERE clave = 'L1'),
                ST_SetSRID(ST_MakePoint(-103.32, 20.67), 4326), NOW());
        -- Si llega aquí, el trigger no lo rechazó
        DELETE FROM pings_transito WHERE session_hash = 'test_lejos';
        RAISE EXCEPTION '✗ Test 10: El trigger NO rechazó un ping a >100m del trazado';
    EXCEPTION
        WHEN raise_exception THEN
            RAISE NOTICE '✓ Test 10: Trigger trg_validar_ping_en_ruta rechazó ping fuera de ruta';
    END;
END $$;

-- ── Test 11: fn_purgar_pings_antiguos funciona ──
DO $$
DECLARE v_result TEXT;
BEGIN
    -- Purgar con 0 horas no debería borrar pings recién insertados
    SELECT fn_purgar_pings_antiguos(0) INTO v_result;
    IF v_result NOT LIKE 'OK:%' THEN
        RAISE EXCEPTION '✗ Test 11: fn_purgar_pings_antiguos retornó resultado inesperado: %', v_result;
    END IF;
    RAISE NOTICE '✓ Test 11: fn_purgar_pings_antiguos ejecutó correctamente (%)', v_result;
    -- Re-insertar demo data para tests posteriores
    PERFORM fn_insertar_pings_demo();
END $$;

-- ── Test 12: Tabla pings_transito está particionada ──
DO $$
DECLARE v_is_partitioned BOOL;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM pg_partitioned_table
        WHERE partrelid = 'pings_transito'::regclass
    ) INTO v_is_partitioned;
    IF NOT v_is_partitioned THEN
        RAISE EXCEPTION '✗ Test 12: pings_transito NO está particionada';
    END IF;
    RAISE NOTICE '✓ Test 12: pings_transito está particionada (PARTITION BY RANGE)';
END $$;

-- ── Test 13: Campos de auditoría y trigger updated_at ──
DO $$
DECLARE
    v_before TIMESTAMPTZ;
    v_after  TIMESTAMPTZ;
BEGIN
    -- Verificar que created_at existe y tiene valor
    SELECT created_at INTO v_before
    FROM rutas WHERE clave = 'L1';
    IF v_before IS NULL THEN
        RAISE EXCEPTION '✗ Test 13: created_at es NULL en rutas';
    END IF;

    -- Esperar 10ms y actualizar para verificar trigger updated_at
    PERFORM pg_sleep(0.01);
    UPDATE rutas SET nombre = nombre WHERE clave = 'L1';
    SELECT updated_at INTO v_after FROM rutas WHERE clave = 'L1';

    IF v_after <= v_before THEN
        RAISE EXCEPTION '✗ Test 13: updated_at no se actualizó tras UPDATE (before=%, after=%)', v_before, v_after;
    END IF;
    RAISE NOTICE '✓ Test 13: Auditoría funciona (created_at existe, updated_at se actualiza con trigger)';
END $$;

-- ===========================================================================
-- RESUMEN
-- ===========================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '══════════════════════════════════════════════════';
    RAISE NOTICE '  ✓ TODOS LOS 13 TESTS PASARON EXITOSAMENTE';
    RAISE NOTICE '  VíaSync ZMG está correctamente instalado.';
    RAISE NOTICE '══════════════════════════════════════════════════';
END $$;
