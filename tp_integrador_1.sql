use trabajo_integrador_bases_datos_1;
SET @prefijo = DATE_FORMAT(NOW(), '%Y%m%d%H%i%s');
CREATE TABLE vehiculos(
	id int primary key auto_increment, /* Aunque se tengan el dominio y nro_chasis que suelen ser únicos, por causas excepcionales podrían cambiar, por lo tanto se usa el id como identificador único por estabilidad y performance*/ 
    eliminado boolean,
    dominio varchar(10) unique not null,
    marca varchar(50) not null,
    modelo varchar(50) not null,
    anio int,
    nro_chasis varchar(50) unique,
    id_seguro int unique
);

CREATE TABLE seguro_vehicular(
	id int primary key auto_increment ,
    eliminado boolean,
    aseguradora varchar(80) not null,
    nro_poliza varchar(50) unique not null,
    cobertura varchar(20) NOT NULL,
    vencimiento date not null
    /* No se añade el id de un vehiculo al existir la posibilidad de crear un seguro tipo flota en un futuro donde se establesca una relación 1:N  */ 
);

ALTER TABLE vehiculos 
	ADD CONSTRAINT fk_id_seguro 
    FOREIGN KEY (id_seguro) 
    REFERENCES seguro_vehicular(id)
    /* Se eliminó ON UPDATE CASCADE por sugerencia de IA ya que no aporta nada significativo al ser raro actualizar el id de un seguro */ 
	ON DELETE SET NULL;

ALTER TABLE vehiculos
  ADD CONSTRAINT chk_vehiculos_anio_rango
  CHECK (anio IS NULL OR (anio BETWEEN 1900 AND 2100));
  
ALTER TABLE seguro_vehicular
ADD CONSTRAINT chk_seguros_cobertura
CHECK (cobertura IN ('RC','TERCEROS','TODO_RIESGO'));

INSERT INTO vehiculos (eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro) 
VALUES (
  false,
  'AB110LG',
  'FORD',
  'MUSTANG',
  2022,
  'ABC123',
  NULL
);

INSERT INTO vehiculos (eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro) 
VALUES (
  false,
  'AB110LL',
  'FORD',
  'MUSTANG',
  803,
  'ABC124',
  NULL
);

-- ----------------------------------------------------------------------------
-- PASO 1: Serie de números
-- ----------------------------------------------------------------------------
CREATE TEMPORARY TABLE numeros (n INT PRIMARY KEY);

INSERT INTO numeros (n)
WITH RECURSIVE serie AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM serie WHERE n < 200000
)
SELECT n FROM serie;

-- ----------------------------------------------------------------------------
-- PASO 2: Insertar 150.000 seguros
-- ----------------------------------------------------------------------------
INSERT INTO seguro_vehicular (eliminado, aseguradora, nro_poliza, cobertura, vencimiento)
SELECT
    FALSE AS eliminado,
    
    CASE MOD(n, 5)
        WHEN 0 THEN 'Seguros La Estrella'
        WHEN 1 THEN 'Protección Total SA'
        WHEN 2 THEN 'Aseguradora del Sur'
        WHEN 3 THEN 'Cobertura Nacional'
        ELSE 'Seguros Unidos'
    END AS aseguradora,
    
    -- Nro póliza único CON PREFIJO para reproducibilidad
    CONCAT('POL-', @prefijo, '-', LPAD(n, 8, '0')) AS nro_poliza,
    
    CASE MOD(n, 10)
        WHEN 0 THEN 'TODO_RIESGO'
        WHEN 1 THEN 'TODO_RIESGO'
        WHEN 2 THEN 'TERCEROS'
        WHEN 3 THEN 'TERCEROS'
        WHEN 4 THEN 'TERCEROS'
        ELSE 'RC'
    END AS cobertura,
    
    DATE_ADD(CURDATE(), INTERVAL MOD(n, 730) DAY) AS vencimiento

FROM numeros
WHERE n <= 150000;

-- ----------------------------------------------------------------------------
-- PASO 3: Insertar 200.000 vehículos
-- ----------------------------------------------------------------------------
INSERT INTO vehiculos (eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro)
SELECT
    FALSE AS eliminado,
    
    -- Dominio único CON PREFIJO
    CONCAT(
		CHAR(65 + MOD(n, 26)),                    -- 1: A-Z
		CHAR(65 + MOD(FLOOR(n/26), 26)),          -- 2: A-Z
		LPAD(MOD(n, 1000), 3, '0'),               -- 3-5: 000-999
		CHAR(65 + MOD(FLOOR(n/1000), 26)),        -- 6: A-Z
		CHAR(65 + MOD(FLOOR(n/26000), 26))        -- 7: A-Z
	) AS dominio,
    
    CASE MOD(n, 5)
        WHEN 0 THEN 'FORD'
        WHEN 1 THEN 'CHEVROLET'
        WHEN 2 THEN 'TOYOTA'
        WHEN 3 THEN 'VOLKSWAGEN'
        ELSE 'FIAT'
    END AS marca,
    
    CASE MOD(n, 5)
        WHEN 0 THEN 'FOCUS'
        WHEN 1 THEN 'CRUZE'
        WHEN 2 THEN 'COROLLA'
        WHEN 3 THEN 'GOL'
        ELSE 'CRONOS'
    END AS modelo,
    
    2010 + MOD(n, 15) AS anio,
    
    -- Nro chasis único CON PREFIJO
    CONCAT('VIN', @prefijo, LPAD(n, 8, '0')) AS nro_chasis,
    
    NULL AS id_seguro

FROM numeros;

-- ----------------------------------------------------------------------------
-- PASO 4: Asignar seguros (emparejamiento robusto con ROW_NUMBER)
-- ----------------------------------------------------------------------------
-- Garantiza 1:1 independiente de IDs físicos

UPDATE vehiculos v
JOIN (
    -- Enumeramos los primeros 140k vehículos
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM vehiculos
    ORDER BY id
    LIMIT 140000
) v_num ON v.id = v_num.id
JOIN (
    -- Enumeramos los primeros 140k seguros
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM seguro_vehicular
    ORDER BY id
    LIMIT 140000
) s_num ON v_num.rn = s_num.rn
SET v.id_seguro = s_num.id;

-- 1. Integridad referencial: ¿Hay FKs inválidas? (debe ser 0)
SELECT 'FKs inválidas' AS validacion, COUNT(*) AS cantidad
FROM vehiculos v
WHERE v.id_seguro IS NOT NULL 
  AND NOT EXISTS (SELECT 1 FROM seguro_vehicular s WHERE s.id = v.id_seguro);

-- Cardinalidad 1:1: ¿Hay seguros reutilizados? (debe ser 0)
SELECT 'Seguros reutilizados (viola 1:1)' AS validacion, COUNT(*) AS cantidad
FROM (
    SELECT id_seguro 
    FROM vehiculos 
    WHERE id_seguro IS NOT NULL
    GROUP BY id_seguro 
    HAVING COUNT(*) > 1
) dup;

-- Reproducibilidad: Conteos y proporciones
SELECT 'Total vehículos' AS metrica, COUNT(*) AS valor FROM vehiculos
UNION ALL
SELECT 'Total seguros', COUNT(*) FROM seguro_vehicular
UNION ALL
SELECT 'Vehículos con seguro', COUNT(*) FROM vehiculos WHERE id_seguro IS NOT NULL
UNION ALL
SELECT 'Proporción con seguro (%)', 
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM vehiculos), 2)
FROM vehiculos WHERE id_seguro IS NOT NULL;

-- Distribución de coberturas
SELECT cobertura, COUNT(*) AS cantidad, 
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM seguro_vehicular), 2) AS porcentaje
FROM seguro_vehicular
GROUP BY cobertura
ORDER BY cantidad DESC;

-- ============================================================================
-- FIN
-- ============================================================================

SHOW INDEX FROM vehiculos;
SHOW INDEX FROM seguro_vehicular;

-- Consulta 1: Vehículos con información completa de su seguro
SELECT 
    v.dominio,
    v.marca,
    v.modelo,
    v.anio,
    s.aseguradora,
    s.nro_poliza,
    s.cobertura,
    s.vencimiento
FROM vehiculos v
INNER JOIN seguro_vehicular s ON v.id_seguro = s.id
WHERE v.eliminado = FALSE 
  AND s.eliminado = FALSE
ORDER BY v.dominio;

-- Consulta 2: Vehículos con seguros próximos a vencer (30 días)
SELECT 
    v.dominio,
    v.marca,
    v.modelo,
    s.aseguradora,
    s.nro_poliza,
    s.vencimiento,
    DATEDIFF(s.vencimiento, CURDATE()) AS dias_para_vencer
FROM vehiculos v
INNER JOIN seguro_vehicular s ON v.id_seguro = s.id
WHERE s.vencimiento BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)
  AND v.eliminado = FALSE
  AND s.eliminado = FALSE
ORDER BY s.vencimiento ASC;

-- Consulta 3: Distribución de coberturas por marca (solo marcas con +1000 vehículos)
SELECT 
    v.marca,
    s.cobertura,
    COUNT(*) AS cantidad_vehiculos,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY v.marca), 2) AS porcentaje
FROM vehiculos v
INNER JOIN seguro_vehicular s ON v.id_seguro = s.id
WHERE v.eliminado = FALSE 
  AND s.eliminado = FALSE
GROUP BY v.marca, s.cobertura
HAVING COUNT(*) > 1000
ORDER BY v.marca, cantidad_vehiculos DESC;

-- CONSULTA OPTIMIZADA POR IA
-- Indices para consulta optimizada por IA
-- Para vehiculos: filtra por eliminado y agrupa por marca
CREATE INDEX idx_vehiculos_eliminado_marca ON vehiculos(eliminado, marca);
-- Para seguro_vehicular: filtra por eliminado y agrupa por cobertura
CREATE INDEX idx_seguros_eliminado_cobertura ON seguro_vehicular(eliminado, cobertura);

DROP INDEX idx_vehiculos_eliminado_marca ON vehiculos;
DROP INDEX idx_seguros_eliminado_cobertura ON seguro_vehicular;

-- Validación 1: FKs inválidas
SELECT 'FKs inválidas' AS validacion, COUNT(*) AS cantidad
FROM vehiculos v
WHERE v.id_seguro IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM seguro_vehicular s WHERE s.id = v.id_seguro);

-- Validación 2: Vehículos activos con seguros eliminados
SELECT 'Vehículos activos con seguros eliminados' AS validacion, COUNT(*) AS cantidad
FROM vehiculos v
INNER JOIN seguro_vehicular s ON v.id_seguro = s.id
WHERE v.eliminado = FALSE AND s.eliminado = TRUE;

-- PASO 1: Consulta principal con CTEs (más legible)
-- -------------------------------------------------------------------------

WITH vehiculos_activos AS (
    SELECT v.id, v.marca, v.id_seguro
    FROM vehiculos v
    WHERE v.eliminado = FALSE
      AND v.id_seguro IS NOT NULL
),
seguros_activos AS (
    SELECT s.id, s.cobertura
    FROM seguro_vehicular s
    WHERE s.eliminado = FALSE
),
conteo_por_marca_cobertura AS (
    SELECT 
        v.marca,
        s.cobertura,
        COUNT(*) AS cantidad_vehiculos
    FROM vehiculos_activos v
    INNER JOIN seguros_activos s ON v.id_seguro = s.id
    GROUP BY v.marca, s.cobertura
),
resultado_con_porcentajes AS (
    SELECT 
        marca,
        cobertura,
        cantidad_vehiculos,
        ROUND(cantidad_vehiculos * 100.0 / SUM(cantidad_vehiculos) OVER (PARTITION BY marca), 2) AS porcentaje
    FROM conteo_por_marca_cobertura
)
SELECT *
FROM resultado_con_porcentajes
WHERE cantidad_vehiculos > 1000
ORDER BY marca, cantidad_vehiculos DESC;

-- PASO 2: Validación de resultados (verificar que porcentajes suman 100%)
-- -------------------------------------------------------------------------

WITH vehiculos_activos AS (
    SELECT v.id, v.marca, v.id_seguro
    FROM vehiculos v
    WHERE v.eliminado = FALSE AND v.id_seguro IS NOT NULL
),
seguros_activos AS (
    SELECT s.id, s.cobertura
    FROM seguro_vehicular s
    WHERE s.eliminado = FALSE
),
conteo_por_marca_cobertura AS (
    SELECT 
        v.marca,
        s.cobertura,
        COUNT(*) AS cantidad_vehiculos
    FROM vehiculos_activos v
    INNER JOIN seguros_activos s ON v.id_seguro = s.id
    GROUP BY v.marca, s.cobertura
),
resultado_con_porcentajes AS (
    SELECT 
        marca,
        cobertura,
        cantidad_vehiculos,
        ROUND(cantidad_vehiculos * 100.0 / SUM(cantidad_vehiculos) OVER (PARTITION BY marca), 2) AS porcentaje
    FROM conteo_por_marca_cobertura
)
SELECT 
    marca,
    SUM(porcentaje) AS suma_porcentajes,
    CASE 
        WHEN ABS(SUM(porcentaje) - 100) < 0.1 THEN '✅ Correcto'
        ELSE '⚠️ Error de redondeo'
    END AS validacion
FROM resultado_con_porcentajes
GROUP BY marca;

-- Consulta 4: Vehículos con mejor cobertura que el promedio de su marca
SELECT 
    v.dominio,
    v.marca,
    v.modelo,
    v.anio,
    promedio.anio_promedio
FROM vehiculos v
INNER JOIN (
    SELECT 
        marca,
        AVG(anio) AS anio_promedio
    FROM vehiculos
    WHERE eliminado = FALSE
    GROUP BY marca
) promedio ON v.marca = promedio.marca
WHERE v.anio > promedio.anio_promedio
  AND v.eliminado = FALSE
ORDER BY v.marca, v.anio DESC;

CREATE OR REPLACE VIEW vista_vehiculos_con_seguro AS
SELECT 
    v.id AS id_vehiculo,
    v.dominio,
    v.marca,
    v.modelo,
    v.anio,
    v.nro_chasis,
    s.id AS id_seguro,
    s.aseguradora,
    s.nro_poliza,
    s.cobertura,
    s.vencimiento,
    DATEDIFF(s.vencimiento, CURDATE()) AS dias_para_vencer
FROM vehiculos v
LEFT JOIN seguro_vehicular s ON v.id_seguro = s.id
WHERE v.eliminado = FALSE
  AND (s.eliminado = FALSE OR s.eliminado IS NULL);
