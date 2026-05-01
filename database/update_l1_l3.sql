-- =========================================================
-- Actualizar L1 y L3 con coordenadas oficiales SITEUR
-- Fuente: Wikipedia (en/es) - coordenadas verificadas
-- =========================================================

-- ── L1: Tren Ligero (20 estaciones, norte → sur) ──────────

DELETE FROM paradas_clave
WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'L1');

INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
  ((SELECT id FROM rutas WHERE clave='L1'), 'Auditorio',
      ST_SetSRID(ST_MakePoint(-103.3495694, 20.7380583), 4326), 1),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Periferico Norte',
      ST_SetSRID(ST_MakePoint(-103.3521222, 20.731056), 4326), 2),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Dermatologico',
      ST_SetSRID(ST_MakePoint(-103.3533250, 20.7209250), 4326), 3),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Atemajac',
      ST_SetSRID(ST_MakePoint(-103.3543750, 20.7160528), 4326), 4),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Division del Norte',
      ST_SetSRID(ST_MakePoint(-103.3554611, 20.7076806), 4326), 5),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Avila Camacho',
      ST_SetSRID(ST_MakePoint(-103.3549583, 20.6993861), 4326), 6),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Mezquitan',
      ST_SetSRID(ST_MakePoint(-103.3539028, 20.6914778), 4326), 7),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Refugio',
      ST_SetSRID(ST_MakePoint(-103.3540639, 20.6822167), 4326), 8),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Juarez',
      ST_SetSRID(ST_MakePoint(-103.3547194, 20.6748639), 4326), 9),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Mexicaltzingo',
      ST_SetSRID(ST_MakePoint(-103.3553583, 20.6669222), 4326), 10),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Washington',
      ST_SetSRID(ST_MakePoint(-103.3574417, 20.6610139), 4326), 11),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Santa Filomena',
      ST_SetSRID(ST_MakePoint(-103.363639, 20.6543000), 4326), 12),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Unidad Deportiva',
      ST_SetSRID(ST_MakePoint(-103.3691333, 20.6473694), 4326), 13),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Urdaneta',
      ST_SetSRID(ST_MakePoint(-103.3726611, 20.6431889), 4326), 14),
  ((SELECT id FROM rutas WHERE clave='L1'), '18 de Marzo',
      ST_SetSRID(ST_MakePoint(-103.376889, 20.6381972), 4326), 15),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Isla Raza',
      ST_SetSRID(ST_MakePoint(-103.3805361, 20.6328194), 4326), 16),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Patria',
      ST_SetSRID(ST_MakePoint(-103.3849278, 20.6268250), 4326), 17),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Espana',
      ST_SetSRID(ST_MakePoint(-103.3893361, 20.6214361), 4326), 18),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Santuario Martires de Cristo Rey',
      ST_SetSRID(ST_MakePoint(-103.3956556, 20.6137639), 4326), 19),
  ((SELECT id FROM rutas WHERE clave='L1'), 'Periferico Sur',
      ST_SetSRID(ST_MakePoint(-103.4009000, 20.6073222), 4326), 20);

-- Regenerar trazado L1
UPDATE rutas SET geom = (
  SELECT ST_SetSRID(ST_MakeLine(array_agg(p.geom ORDER BY p.orden)), 4326)
  FROM paradas_clave p WHERE p.ruta_id = rutas.id
) WHERE clave = 'L1';

-- ── L3: Mi Tren (18 estaciones, noroeste → sureste) ────────

DELETE FROM paradas_clave
WHERE ruta_id = (SELECT id FROM rutas WHERE clave = 'L3');

INSERT INTO paradas_clave (ruta_id, nombre, geom, orden) VALUES
  ((SELECT id FROM rutas WHERE clave='L3'), 'Arcos de Zapopan',
      ST_SetSRID(ST_MakePoint(-103.4074472, 20.7412250), 4326), 1),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Periferico Belenes',
      ST_SetSRID(ST_MakePoint(-103.4030917, 20.7381000), 4326), 2),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Mercado del Mar',
      ST_SetSRID(ST_MakePoint(-103.3892417, 20.7288111), 4326), 3),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Zapopan Centro',
      ST_SetSRID(ST_MakePoint(-103.3861167, 20.7193500), 4326), 4),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Plaza Patria',
      ST_SetSRID(ST_MakePoint(-103.3748667, 20.7121417), 4326), 5),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Circunvalacion Country',
      ST_SetSRID(ST_MakePoint(-103.3660139, 20.7064667), 4326), 6),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Avila Camacho (Transbordo L1)',
      ST_SetSRID(ST_MakePoint(-103.3549583, 20.6993861), 4326), 7),
  ((SELECT id FROM rutas WHERE clave='L3'), 'La Normal',
      ST_SetSRID(ST_MakePoint(-103.3487250, 20.6951250), 4326), 8),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Santuario',
      ST_SetSRID(ST_MakePoint(-103.3478667, 20.6840444), 4326), 9),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Guadalajara Centro',
      ST_SetSRID(ST_MakePoint(-103.3473944, 20.6761940), 4326), 10),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Independencia',
      ST_SetSRID(ST_MakePoint(-103.3444389, 20.6708300), 4326), 11),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Plaza de la Bandera',
      ST_SetSRID(ST_MakePoint(-103.3327250, 20.6651306), 4326), 12),
  ((SELECT id FROM rutas WHERE clave='L3'), 'CUCEI',
      ST_SetSRID(ST_MakePoint(-103.3240306, 20.6596417), 4326), 13),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Revolucion',
      ST_SetSRID(ST_MakePoint(-103.3102750, 20.6509694), 4326), 14),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Rio Nilo',
      ST_SetSRID(ST_MakePoint(-103.3041110, 20.6447889), 4326), 15),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Tlaquepaque Centro',
      ST_SetSRID(ST_MakePoint(-103.2999694, 20.6375528), 4326), 16),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Lazaro Cardenas',
      ST_SetSRID(ST_MakePoint(-103.2962306, 20.6321444), 4326), 17),
  ((SELECT id FROM rutas WHERE clave='L3'), 'Central de Autobuses',
      ST_SetSRID(ST_MakePoint(-103.2850583, 20.6231472), 4326), 18);

-- Regenerar trazado L3
UPDATE rutas SET geom = (
  SELECT ST_SetSRID(ST_MakeLine(array_agg(p.geom ORDER BY p.orden)), 4326)
  FROM paradas_clave p WHERE p.ruta_id = rutas.id
) WHERE clave = 'L3';

-- Verificar
SELECT r.clave, COUNT(p.id) AS paradas
FROM rutas r
JOIN paradas_clave p ON p.ruta_id = r.id
WHERE r.clave IN ('L1','L3')
GROUP BY r.clave
ORDER BY r.clave;
