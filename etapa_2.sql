USE trabajo_integrador_bases_datos_1;
SET @prefijo = DATE_FORMAT(NOW(), '%Y%m%d%H%i%s');

-- ----------------------------------------------------------------------------
-- PASO 1: Serie de números
-- ----------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS numeros; 
CREATE TEMPORARY TABLE numeros (n INT PRIMARY KEY);

-- Ver límite actual
SHOW VARIABLES LIKE 'cte_max_recursion_depth';

-- Aumentar si es necesario (default: 1000)
SET SESSION cte_max_recursion_depth = 200000;
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
-- PASO 4: Asignar seguros
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

-- -------------------------------------------------------
-- 1. Integridad referencial (debe ser 0)
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