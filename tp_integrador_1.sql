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

-- PASO 1: Generar una serie de números (1..200000)
-- ----------------------------------------------------------------------------
SET SESSION cte_max_recursion_depth = 200000;
CREATE TEMPORARY TABLE numeros (n INT PRIMARY KEY);

INSERT INTO numeros (n)
WITH RECURSIVE serie AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM serie WHERE n < 200000
)
SELECT n FROM serie;

-- Ahora tenemos una tabla con 200.000 números únicos (1, 2, 3, ..., 200000)

-- ----------------------------------------------------------------------------
-- PASO 2: Insertar 150.000 seguros
-- ----------------------------------------------------------------------------
-- Derivamos todos los campos desde la serie de números.

INSERT INTO seguro_vehicular (eliminado, aseguradora, nro_poliza, cobertura, vencimiento)
SELECT
    FALSE AS eliminado,  -- Todos activos (simplificado)
    
    -- Aseguradora: rotamos entre 5 opciones usando MOD
    CASE MOD(n, 5)
        WHEN 0 THEN 'Seguros La Estrella'
        WHEN 1 THEN 'Protección Total SA'
        WHEN 2 THEN 'Aseguradora del Sur'
        WHEN 3 THEN 'Cobertura Nacional'
        ELSE 'Seguros Unidos'
    END AS aseguradora,
    
    -- Nro póliza único: POL-00000001, POL-00000002, etc.
    CONCAT('POL-', @prefijo, '-', LPAD(n, 8, '0')) AS nro_poliza,
    
    -- Cobertura: distribución simple con MOD
    CASE MOD(n, 10)
        WHEN 0 THEN 'TODO_RIESGO'  -- 10%
        WHEN 1 THEN 'TODO_RIESGO'
        WHEN 2 THEN 'TERCEROS'     -- 30%
        WHEN 3 THEN 'TERCEROS'
        WHEN 4 THEN 'TERCEROS'
        ELSE 'RC'                  -- 60%
    END AS cobertura,
    
    -- Vencimiento: distribuimos en próximos 2 años
    DATE_ADD(CURDATE(), INTERVAL MOD(n, 730) DAY) AS vencimiento

FROM numeros
WHERE n <= 200000;  -- Solo 150k seguros

-- ----------------------------------------------------------------------------
-- PASO 3: Insertar 200.000 vehículos (sin seguro asignado todavía)
-- ----------------------------------------------------------------------------

INSERT INTO vehiculos (eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro)
SELECT
    FALSE AS eliminado,  -- Todos activos
    -- Dominio único: AB001CD, AB002CD, etc.
    CONCAT(
        CHAR(65 + MOD(n, 26)),              -- Primera letra A-Z
        CHAR(65 + MOD(FLOOR(n/26), 26)),    -- Segunda letra A-Z
        LPAD(MOD(n, 1000), 3, '0'),         -- 3 dígitos
        CHAR(65 + MOD(FLOOR(n/1000), 26)),  -- Tercera letra
        CHAR(65 + MOD(FLOOR(n/26000), 26))  -- Cuarta letra
    ) AS dominio,
    
    -- Marca: rotamos entre 5 marcas
    CASE MOD(n, 5)
        WHEN 0 THEN 'FORD'
        WHEN 1 THEN 'CHEVROLET'
        WHEN 2 THEN 'TOYOTA'
        WHEN 3 THEN 'VOLKSWAGEN'
        ELSE 'FIAT'
    END AS marca,
    
    -- Modelo: rotamos entre 5 modelos
    CASE MOD(n, 5)
        WHEN 0 THEN 'FOCUS'
        WHEN 1 THEN 'CRUZE'
        WHEN 2 THEN 'COROLLA'
        WHEN 3 THEN 'GOL'
        ELSE 'CRONOS'
    END AS modelo,
    
    -- Año: entre 2010 y 2024
    2010 + MOD(n, 15) AS anio,
    
    -- Nro chasis único: VIN00000000000001, etc.
    CONCAT('VIN', @prefijo, LPAD(n, 8, '0')) AS nro_chasis,
    
    NULL AS id_seguro  -- Lo asignamos después

FROM numeros;

-- ----------------------------------------------------------------------------
-- PASO 4: Asignar seguros a 70% de vehículos (140.000)
-- ----------------------------------------------------------------------------
-- Emparejamos los primeros 140k vehículos con los primeros 140k seguros.

UPDATE vehiculos v
JOIN (
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM vehiculos
    WHERE id <= 200000
) v_num ON v.id = v_num.id
JOIN (
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM seguro_vehicular
    LIMIT 200000
) s_num ON v_num.rn = s_num.rn
SET v.id_seguro = s_num.id;

-- Conteo total
SELECT 'Vehículos' AS tabla, COUNT(*) AS total FROM vehiculos
UNION ALL
SELECT 'Seguros', COUNT(*) FROM seguro_vehicular
UNION ALL
SELECT 'Vehículos con seguro', COUNT(*) FROM vehiculos WHERE id_seguro IS NOT NULL;

-- Verificar que no hay duplicados en dominio
SELECT COUNT(*) AS dominios_duplicados
FROM (SELECT dominio FROM vehiculos GROUP BY dominio HAVING COUNT(*) > 1) dup;

-- Verificar que no hay duplicados en nro_poliza
SELECT COUNT(*) AS polizas_duplicadas
FROM (SELECT nro_poliza FROM seguro_vehicular GROUP BY nro_poliza HAVING COUNT(*) > 1) dup;

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
