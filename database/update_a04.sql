-- Actualizar A04 con las 15 paradas reales (fuente: SITEUR / busmaps.com)
-- La ruta sale de Estacion Periferico Sur hacia el poniente,
-- luego gira al sur por Av. Lopez Mateos Sur hasta Lomas de San Agustin.

DELETE FROM paradas_clave
WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'A04');

INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
  ((SELECT id FROM rutas WHERE clave='A04'), 'Periferico Sur (Estacion L1)',
      ST_SetSRID(ST_MakePoint(-103.4002, 20.6055), 4326), 1),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Plaza Centro Sur / Foraneos',
      ST_SetSRID(ST_MakePoint(-103.4018, 20.5968), 4326), 2),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Halcon',
      ST_SetSRID(ST_MakePoint(-103.4065, 20.5920), 4326), 3),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Camino a Santa Ana Tepetitlan',
      ST_SetSRID(ST_MakePoint(-103.4115, 20.5878), 4326), 4),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Av. Vicente Guerrero',
      ST_SetSRID(ST_MakePoint(-103.4165, 20.5840), 4326), 5),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Las Villas',
      ST_SetSRID(ST_MakePoint(-103.4210, 20.5800), 4326), 6),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Avenida Punto Sur',
      ST_SetSRID(ST_MakePoint(-103.4255, 20.5762), 4326), 7),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Guadalajara-Morelia',
      ST_SetSRID(ST_MakePoint(-103.4295, 20.5724), 4326), 8),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Av. Adolfo Lopez Mateos Sur',
      ST_SetSRID(ST_MakePoint(-103.4320, 20.5685), 4326), 9),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Av. Lopez Mateos Sur (Sur)',
      ST_SetSRID(ST_MakePoint(-103.4345, 20.5645), 4326), 10),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Aldama',
      ST_SetSRID(ST_MakePoint(-103.4368, 20.5605), 4326), 11),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Av. Camino Real a Colima',
      ST_SetSRID(ST_MakePoint(-103.4390, 20.5565), 4326), 12),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Lago Cajititlan',
      ST_SetSRID(ST_MakePoint(-103.4410, 20.5525), 4326), 13),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Camino a La Pedrera',
      ST_SetSRID(ST_MakePoint(-103.4428, 20.5487), 4326), 14),
  ((SELECT id FROM rutas WHERE clave='A04'), 'Lomas de San Agustin (Terminal)',
      ST_SetSRID(ST_MakePoint(-103.4450, 20.5448), 4326), 15);

-- Regenerar LineString desde las nuevas 15 paradas
UPDATE rutas
SET geom = (
  SELECT ST_SetSRID(ST_MakeLine(array_agg(p.geom ORDER BY p.orden)), 4326)
  FROM paradas_clave p
  WHERE p.ruta_id = rutas.id
)
WHERE clave = 'A04';

SELECT 'OK: ' || COUNT(*) || ' paradas insertadas para A04' AS resultado
FROM paradas_clave
WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'A04');
