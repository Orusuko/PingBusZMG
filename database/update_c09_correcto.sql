-- =========================================================
-- Correccion definitiva de C-09
-- Fuente: transitrun.com (lista de paradas oficial) + 
--         GTFS mimacro-mitren-sitren (coordenadas verificadas de paradas compartidas)
--
-- La ruta va de sur a norte:
--   Dalia (Tlajomulco sur) → Lomas de San Agustin → Camino a La Pedrera
--   → Lago Cajititlan → Camino Real a Colima → Real San Ignacio
--   → Punto Sur → Prol. Mariano Otero → Plaza Centro Sur
--
-- Paradas con coordenadas GTFS exactas (mismo corredor que A04):
--   Camino a La Pedrera: MM_C09_09
--   Lago Cajititlan:     MM_C09_10
--   Camino Real a Colima: MM_C09_12 / MM_C09_57
--   Real San Ignacio:    MM_C09_21
--   Punto Sur:           A04 GTFS MM_C125V1_130
-- =========================================================

DELETE FROM paradas_clave
WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'C-09');

INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
  -- Terminal sur (Tlajomulco, estimado)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Dalia (Terminal)',
      ST_SetSRID(ST_MakePoint(-103.474500, 20.499500), 4326), 1),

  -- Los Abedules / Lomas area (estimado, continuando norte)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Los Abedules',
      ST_SetSRID(ST_MakePoint(-103.471800, 20.510500), 4326), 2),

  -- Lomas de San Agustin y alrededores (GTFS MM_C09_07)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Lomas de San Agustin',
      ST_SetSRID(ST_MakePoint(-103.468800, 20.524210), 4326), 3),

  -- Camino a La Pedrera (GTFS MM_C09_09 exacto)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Camino a La Pedrera',
      ST_SetSRID(ST_MakePoint(-103.468990, 20.530020), 4326), 4),

  -- Lago Cajititlan (GTFS MM_C09_10 exacto)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Lago Cajititlan',
      ST_SetSRID(ST_MakePoint(-103.469670, 20.534030), 4326), 5),

  -- Camino Real a Colima norte (GTFS MM_C09_57 exacto)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Av. Camino Real a Colima',
      ST_SetSRID(ST_MakePoint(-103.465610, 20.543750), 4326), 6),

  -- Real San Ignacio (GTFS MM_C09_21 exacto)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Real San Ignacio',
      ST_SetSRID(ST_MakePoint(-103.449450, 20.560140), 4326), 7),

  -- Avenida Punto Sur (GTFS A04 MM_C125V1_130 exacto)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Avenida Punto Sur',
      ST_SetSRID(ST_MakePoint(-103.456500, 20.570140), 4326), 8),

  -- Prol. Mariano Otero (entre Punto Sur y Periferico Sur, estimado)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Prolongacion Mariano Otero',
      ST_SetSRID(ST_MakePoint(-103.428500, 20.590500), 4326), 9),

  -- Terminal norte: Plaza Centro Sur (GTFS A04 MM_C111V2_41 exacto)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Plaza Centro Sur (Terminal)',
      ST_SetSRID(ST_MakePoint(-103.401090, 20.605890), 4326), 10);

-- Regenerar trazado C-09
UPDATE rutas SET geom = (
  SELECT ST_SetSRID(ST_MakeLine(array_agg(p.geom ORDER BY p.orden)), 4326)
  FROM paradas_clave p WHERE p.ruta_id = rutas.id
) WHERE clave = 'C-09';

-- Actualizar nombre para reflejar correctamente los extremos
UPDATE rutas
SET nombre = 'Ruta C-09 (Dalia / Los Abedules - Centro Sur)'
WHERE clave = 'C-09';

-- Verificar
SELECT r.clave, r.nombre, COUNT(p.id) AS paradas
FROM rutas r
JOIN paradas_clave p ON p.ruta_id = r.id
WHERE r.clave = 'C-09'
GROUP BY r.clave, r.nombre;
