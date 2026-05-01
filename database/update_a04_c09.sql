-- =========================================================
-- Actualizar A04 y C-09 con coordenadas correctas
-- A04: coordenadas exactas del GTFS oficial (Gobierno de Jalisco)
-- C-09: correccion de posicion (Centro Sur estaba 2.5km al sur)
-- =========================================================

-- ── A04: Alimentadora Periferico Sur → Lomas de San Agustin ──
-- La ruta va primero al OESTE por el Periferico (paradas 1-5),
-- luego gira al sur por Lopez Mateos Sur hasta Lomas de San Agustin.
-- Fuente: GTFS oficial mimacro-mitren-sitren (Gobierno Jalisco)

DELETE FROM paradas_clave
WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'A04');

INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
  ((SELECT id FROM rutas WHERE clave='A04'), 'Plaza Centro Sur',
      ST_SetSRID(ST_MakePoint(-103.401090, 20.605890), 4326), 1),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Foraneos',
      ST_SetSRID(ST_MakePoint(-103.404780, 20.608220), 4326), 2),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Halcon',
      ST_SetSRID(ST_MakePoint(-103.423290, 20.612760), 4326), 3),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Camino a Santa Ana Tepetitlan',
      ST_SetSRID(ST_MakePoint(-103.428780, 20.612210), 4326), 4),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Av. Vicente Guerrero',
      ST_SetSRID(ST_MakePoint(-103.431180, 20.608570), 4326), 5),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Las Villas',
      ST_SetSRID(ST_MakePoint(-103.445160, 20.587340), 4326), 6),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Avenida Punto Sur',
      ST_SetSRID(ST_MakePoint(-103.456500, 20.570140), 4326), 7),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Guadalajara-Morelia',
      ST_SetSRID(ST_MakePoint(-103.459890, 20.565070), 4326), 8),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Av. Adolfo Lopez Mateos Sur (Norte)',
      ST_SetSRID(ST_MakePoint(-103.465330, 20.556760), 4326), 9),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Av. Adolfo Lopez Mateos Sur (Sur)',
      ST_SetSRID(ST_MakePoint(-103.468470, 20.551970), 4326), 10),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Aldama',
      ST_SetSRID(ST_MakePoint(-103.470670, 20.548610), 4326), 11),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Av. Camino Real a Colima',
      ST_SetSRID(ST_MakePoint(-103.465610, 20.543750), 4326), 12),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Lago Cajititlan',
      ST_SetSRID(ST_MakePoint(-103.469880, 20.533950), 4326), 13),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Camino a La Pedrera',
      ST_SetSRID(ST_MakePoint(-103.469160, 20.529830), 4326), 14),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Lomas de San Agustin (Terminal)',
      ST_SetSRID(ST_MakePoint(-103.468390, 20.521330), 4326), 15);

-- Regenerar trazado A04
UPDATE rutas SET geom = (
  SELECT ST_SetSRID(ST_MakeLine(array_agg(p.geom ORDER BY p.orden)), 4326)
  FROM paradas_clave p WHERE p.ruta_id = rutas.id
) WHERE clave = 'A04';

-- ── C-09: Correccion de posicion ─────────────────────────────
-- La parada "Centro Sur" estaba ~2.5km al sur de Plaza Centro Sur.
-- Se corrige a la ubicacion real de la terminal sobre Blvd. Lopez Mateos Sur.
-- La ruta va en direccion sureste desde Plaza Centro Sur
-- hacia el area de Los Abedules (Tlaquepaque sur).

DELETE FROM paradas_clave
WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'C-09');

INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Plaza Centro Sur',
      ST_SetSRID(ST_MakePoint(-103.401090, 20.598000), 4326), 1),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Camino Real a Colima',
      ST_SetSRID(ST_MakePoint(-103.395700, 20.592000), 4326), 2),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Loma Bonita',
      ST_SetSRID(ST_MakePoint(-103.387200, 20.587000), 4326), 3),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Av. de los Abedules',
      ST_SetSRID(ST_MakePoint(-103.378500, 20.581000), 4326), 4),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Amaranto',
      ST_SetSRID(ST_MakePoint(-103.368300, 20.575500), 4326), 5),
  ((SELECT id FROM rutas WHERE clave='C-09'), 'Jazmin (Terminal)',
      ST_SetSRID(ST_MakePoint(-103.357800, 20.569800), 4326), 6);

-- Regenerar trazado C-09
UPDATE rutas SET geom = (
  SELECT ST_SetSRID(ST_MakeLine(array_agg(p.geom ORDER BY p.orden)), 4326)
  FROM paradas_clave p WHERE p.ruta_id = rutas.id
) WHERE clave = 'C-09';

-- Verificar
SELECT r.clave, COUNT(p.id) AS paradas,
       ST_AsText(ST_StartPoint(r.geom)) AS inicio,
       ST_AsText(ST_EndPoint(r.geom)) AS fin
FROM rutas r
JOIN paradas_clave p ON p.ruta_id = r.id
WHERE r.clave IN ('A04', 'C-09')
GROUP BY r.clave, r.geom
ORDER BY r.clave;
