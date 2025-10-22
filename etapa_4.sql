CREATE USER 'secure_user'@'localhost' IDENTIFIED BY 'secure_user';

GRANT SELECT ON trabajo_integrador_bases_datos_1.vista_vehiculos_basicos TO 'secure_user'@'localhost';
GRANT SELECT ON trabajo_integrador_bases_datos_1.vista_seguro_resumido TO 'secure_user'@'localhost';

FLUSH PRIVILEGES; -- instrucción en bases de datos como MySQL que recarga las tablas de permisos en memoria, haciendo que los cambios realizados directamente en las tablas de permisos sean efectivos

-- Primer vista sin datos sensibles, se podría usar como estadistica de inventario o flota, reportes comerciales de marca sin exponer datos criticos de cada vehículo
CREATE OR REPLACE VIEW vista_vehiculos_basicos AS
SELECT 
    v.dominio,
    v.marca,
    v.modelo,
    v.anio,
    CASE  	
        WHEN v.id_seguro IS NOT NULL THEN 'ASEGURADO'
        ELSE 'SIN SEGURO'
    END AS estado_seguro,
    CASE 
        WHEN v.anio >= YEAR(CURDATE()) - 5 THEN 'NUEVO'
        WHEN v.anio >= YEAR(CURDATE()) - 10 THEN 'SEMINUEVO'
        ELSE 'ANTIGUO'
    END AS categoria_antiguedad
FROM vehiculos v
WHERE v.eliminado = FALSE;

-- Vista tipo resumen o reporte de agrupamiento por seguros donde se ve la cantidad de polizas asignadas y el promedio de dias a vencer
CREATE OR REPLACE VIEW vista_seguro_resumido AS
SELECT 
  aseguradora,
  cobertura,
  COUNT(*) AS cantidad_polizas,
  ROUND(AVG(DATEDIFF(vencimiento, CURDATE())), 0) AS días_promedio_para_vencer
FROM seguro_vehicular
WHERE eliminado = FALSE
GROUP BY aseguradora, cobertura;

-- PRUEBAS DE INTEGRIDAD
INSERT INTO vehiculos (id, eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro)
VALUES (1, FALSE, 'ZZ999ZZ', 'FIAT', 'UNO', 2020, 'TESTCHASIS', NULL); -- Esto debería fallar por violación de primary key


INSERT INTO vehiculos (eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro)
VALUES (FALSE, 'XY123ZT', 'FORD', 'FOCUS', 1800, 'TESTCHASIS2', NULL); -- debería fallar por año fuera de rango del CHECK

DELIMITER //
CREATE PROCEDURE buscar_vehiculo_por_dominio(IN p_dominio VARCHAR(10))
BEGIN
  SELECT dominio, marca, modelo, anio
  FROM vehiculos
  WHERE dominio = p_dominio;
END //
DELIMITER ;

-- Prueba legítima
CALL buscar_vehiculo_por_dominio('AB110LG');

-- Prueba maliciosa (intento de inyección)
CALL buscar_vehiculo_por_dominio("AB110LG' OR '1'='1");