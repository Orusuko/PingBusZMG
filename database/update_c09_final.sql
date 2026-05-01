-- =========================================================
-- C-09 correccion final: Antiguo Camino Real a Colima
-- 44 paradas de sur a norte: Dalia → Centro Sur
-- Paradas con *GTFS* = coordenadas exactas del GTFS oficial
-- Resto = estimado segun trayectoria del Antiguo Camino Real a Colima
-- =========================================================

DELETE FROM paradas_clave
WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'C-09');

INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
  -- ── Zona sur (Tlajomulco, calles de flores) ──
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Dalia (Terminal)',
      ST_SetSRID(ST_MakePoint(-103.474500, 20.499500), 4326), 1),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Palma',
      ST_SetSRID(ST_MakePoint(-103.473500, 20.501800), 4326), 2),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Cto. Geranio',
      ST_SetSRID(ST_MakePoint(-103.472800, 20.504200), 4326), 3),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Gardenia',
      ST_SetSRID(ST_MakePoint(-103.472000, 20.507000), 4326), 4),

  -- ── Zona Lomas (calles Loma*) ──
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Lomas Del Valle',
      ST_SetSRID(ST_MakePoint(-103.471500, 20.510000), 4326), 5),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Loma Central',
      ST_SetSRID(ST_MakePoint(-103.471000, 20.513000), 4326), 6),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Loma Alta Norte',
      ST_SetSRID(ST_MakePoint(-103.470500, 20.516000), 4326), 7),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Loma Bonita',
      ST_SetSRID(ST_MakePoint(-103.470000, 20.519000), 4326), 8),

  -- ── Camino a La Pedrera (GTFS MM_C09_09) ──
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Camino a La Pedrera',
      ST_SetSRID(ST_MakePoint(-103.468990, 20.530020), 4326), 9),

  ((SELECT id FROM rutas WHERE clave='C-09'), 'Loma Del Camichin',
      ST_SetSRID(ST_MakePoint(-103.468500, 20.523500), 4326), 10),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Loma De Los Olivos',
      ST_SetSRID(ST_MakePoint(-103.468800, 20.526500), 4326), 11),

  -- ── Zona Cajititlan / Lagos ──
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Laguna Azul',
      ST_SetSRID(ST_MakePoint(-103.468500, 20.532500), 4326), 12),
  -- Lago Cajititlan (GTFS MM_C09_10)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Lago Cajititlan',
      ST_SetSRID(ST_MakePoint(-103.469670, 20.534030), 4326), 13),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'La Lagunita',
      ST_SetSRID(ST_MakePoint(-103.469000, 20.536500), 4326), 14),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'El Puentecito',
      ST_SetSRID(ST_MakePoint(-103.468000, 20.538800), 4326), 15),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Nogal',
      ST_SetSRID(ST_MakePoint(-103.466500, 20.541000), 4326), 16),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'La Cienega',
      ST_SetSRID(ST_MakePoint(-103.465000, 20.543000), 4326), 17),

  -- ── Antiguo Camino Real a Colima (zona San Agustin) ──
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Hidalgo',
      ST_SetSRID(ST_MakePoint(-103.463000, 20.545500), 4326), 18),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'San Agustin - Camino Real',
      ST_SetSRID(ST_MakePoint(-103.460500, 20.548500), 4326), 19),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Francisco I. Madero',
      ST_SetSRID(ST_MakePoint(-103.458000, 20.551500), 4326), 20),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Ramon Corona - Camino Real',
      ST_SetSRID(ST_MakePoint(-103.455500, 20.554500), 4326), 21),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Aquiles Serdan',
      ST_SetSRID(ST_MakePoint(-103.453000, 20.557500), 4326), 22),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Sevilla',
      ST_SetSRID(ST_MakePoint(-103.450500, 20.560000), 4326), 23),
  -- Real San Ignacio (GTFS MM_C09_21)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Cto. Sorrento / Real San Ignacio',
      ST_SetSRID(ST_MakePoint(-103.449450, 20.560140), 4326), 24),

  -- ── Punto Sur - Camino Real (interseccion con Av. Punto Sur) ──
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Punto Sur - Camino Real',
      ST_SetSRID(ST_MakePoint(-103.445000, 20.564500), 4326), 25),

  -- ── Zona norte: continua por Camino Real hacia Mariano Otero ──
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Magallanes',
      ST_SetSRID(ST_MakePoint(-103.441000, 20.568000), 4326), 26),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Los Magueyes',
      ST_SetSRID(ST_MakePoint(-103.437500, 20.572000), 4326), 27),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Prolongacion Mariano Otero',
      ST_SetSRID(ST_MakePoint(-103.433500, 20.576000), 4326), 28),
  ((SELECT id FROM rutas WHERE clave='C-09'), '17 de Mayo',
      ST_SetSRID(ST_MakePoint(-103.430000, 20.580000), 4326), 29),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Jose Guadalupe Gallo',
      ST_SetSRID(ST_MakePoint(-103.426500, 20.584000), 4326), 30),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Las Pomas',
      ST_SetSRID(ST_MakePoint(-103.422500, 20.587500), 4326), 31),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'San Antonio',
      ST_SetSRID(ST_MakePoint(-103.419000, 20.590500), 4326), 32),

  -- ── Zona La Tijera / acercamiento a Centro Sur ──
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Parques de Santa Maria',
      ST_SetSRID(ST_MakePoint(-103.416500, 20.593000), 4326), 33),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Arroyo Seco',
      ST_SetSRID(ST_MakePoint(-103.414000, 20.595500), 4326), 34),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Valle del Sur',
      ST_SetSRID(ST_MakePoint(-103.411500, 20.598000), 4326), 35),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Haciendas de San Jose',
      ST_SetSRID(ST_MakePoint(-103.409000, 20.600500), 4326), 36),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Independencia',
      ST_SetSRID(ST_MakePoint(-103.406000, 20.603000), 4326), 37),

  -- Terminal norte (GTFS A04 MM_C111V2_41)
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Centro Sur (Terminal)',
      ST_SetSRID(ST_MakePoint(-103.401090, 20.605890), 4326), 38);

-- Regenerar trazado
UPDATE rutas SET geom = (
  SELECT ST_SetSRID(ST_MakeLine(array_agg(p.geom ORDER BY p.orden)), 4326)
  FROM paradas_clave p WHERE p.ruta_id = rutas.id
) WHERE clave = 'C-09';

-- Verificar
SELECT r.clave, COUNT(p.id) AS paradas,
       ROUND(ST_Length(r.geom::geography)/1000, 2) AS km_trazado
FROM rutas r
JOIN paradas_clave p ON p.ruta_id = r.id
WHERE r.clave = 'C-09'
GROUP BY r.clave, r.geom;
