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


-- PRUEBAS CON MEJORAS SUGERIDAS POR IA
-- Tabla de auditoría
CREATE TABLE IF NOT EXISTS auditoria_busquedas (
  id INT PRIMARY KEY AUTO_INCREMENT,
  usuario VARCHAR(100),
  dominio_buscado VARCHAR(10),
  fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ip_origen VARCHAR(45),
  resultado_encontrado BOOLEAN,
  INDEX idx_usuario_fecha (usuario, fecha_hora)
);

-- Vista con datos públicos
CREATE OR REPLACE VIEW vehiculos_publicos AS
SELECT dominio, marca, modelo, anio
FROM vehiculos
WHERE eliminado = FALSE;

DELIMITER //
CREATE PROCEDURE buscar_vehiculo_seguro(
  IN p_dominio VARCHAR(10), 
  IN p_usuario VARCHAR(100), 
  IN p_ip VARCHAR(45)
)
BEGIN
  DECLARE v_consultas_recientes INT;
  DECLARE v_encontrado BOOLEAN DEFAULT FALSE;
  DECLARE v_count INT DEFAULT 0;
  
  -- VALIDACIÓN 1: Entrada no vacía
  IF p_dominio IS NULL OR TRIM(p_dominio) = '' THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Error: El dominio no puede estar vacío';
  END IF;
  
  -- VALIDACIÓN 2: Caracteres sospechosos
  IF p_dominio REGEXP '[";\\-\\-]' THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Error: El dominio contiene caracteres no permitidos';
  END IF;
  
  -- VALIDACIÓN 3: Formato esperado
  IF p_dominio NOT REGEXP '^[A-Z0-9]{5,10}$' THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Error: Formato de dominio inválido';
  END IF;
  
  -- VALIDACIÓN 4: Rate limiting
  SELECT COUNT(*) INTO v_consultas_recientes 
  FROM auditoria_busquedas 
  WHERE usuario = p_usuario 
    AND fecha_hora >= DATE_SUB(NOW(), INTERVAL 1 MINUTE);
    
  IF v_consultas_recientes >= 10 THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Error: Límite de consultas excedido (máx 10/min)';
  END IF;
  
  -- CONSULTA SEGURA
  SELECT * FROM vehiculos_publicos WHERE dominio = p_dominio;
  
  -- Verificar si se encontró resultado (reemplazando FOUND_ROWS())
  SELECT COUNT(*) INTO v_count 
  FROM vehiculos_publicos 
  WHERE dominio = p_dominio;
  
  IF v_count > 0 THEN
    SET v_encontrado = TRUE;
  END IF;
  
  -- AUDITORÍA
  INSERT INTO auditoria_busquedas (usuario, dominio_buscado, ip_origen, resultado_encontrado)
  VALUES (p_usuario, p_dominio, p_ip, v_encontrado);
END //
DELIMITER ;

-- Prueba legítima
CALL buscar_vehiculo_seguro('AB110LG', 'juan.perez', '192.168.1.100');

-- Prueba con inyección (rechazada por validación de caracteres)
CALL buscar_vehiculo_seguro("AB110LG' OR '1'='1", 'atacante', '10.0.0.1');

