-- ------------------------
-- Creación de indices para pruebas de rendimiento
SHOW INDEX FROM vehiculos;
SHOW INDEX FROM seguro_vehicular;

-- Consulta con JOIN 1: Vehículos con información completa de su seguro
SELECT 
    v.dominio,
    v.marca,
    v.modelo,
    v.anio,
    s.aseguradora,
    s.nro_poliza,
    s.cobertura,
    s.vencimiento
FROM
    vehiculos v
        INNER JOIN
    seguro_vehicular s ON v.id_seguro = s.id
WHERE
    v.eliminado = FALSE
        AND s.eliminado = FALSE
ORDER BY v.dominio;

-- Consulta con JOIN 2: Vehículos con seguros próximos a vencer (30 días)
SELECT 
    v.dominio,
    v.marca,
    v.modelo,
    s.aseguradora,
    s.nro_poliza,
    s.vencimiento,
    DATEDIFF(s.vencimiento, CURDATE()) AS dias_para_vencer
FROM
    vehiculos v
        INNER JOIN
    seguro_vehicular s ON v.id_seguro = s.id
WHERE
    s.vencimiento BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)
        AND v.eliminado = FALSE
        AND s.eliminado = FALSE
ORDER BY s.vencimiento ASC; -- Distribución de coberturas por marca
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

-- --------------------------------------------
-- CONSULTA GROUP BY + HAVING OPTIMIZADA POR IA
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
        WHEN ABS(SUM(porcentaje) - 100) < 0.1 THEN 'Correcto'
        ELSE 'Error de redondeo'
    END AS validacion
FROM resultado_con_porcentajes
GROUP BY marca;

-- Consulta con SUBCONSULTA 4: Vehículos con mejor cobertura que el promedio de su marca
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

-- -------------------------------------------------------------------------
-- CREACIÓN VISTA ÚTIL PARA EL SISTEMA, es para ver vehiculo con detalle de su seguro
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