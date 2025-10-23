USE trabajo_integrador_bases_datos_1;

-- Creo una tabla de prueba para el usuario a crear y le inserto un valor
CREATE TABLE IF NOT EXISTS stock_vehiculos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    dominio VARCHAR(10) UNIQUE,
    cantidad INT DEFAULT 10,
    actualizado TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Datos de prueba
INSERT INTO stock_vehiculos (dominio, cantidad) VALUES ('AB110LG', 10), ('AB110LL', 10);

-- -------------------------------------------------
-- Derechos al usuario secundario a tabla de prueba para simulación de Deadlock
-- Se le otorga derecho de lectura a la tabla stock_vehiculos
GRANT SELECT ON trabajo_integrador_bases_datos_1.stock_vehiculos TO 'secure_user'@'localhost';

-- Se le quita el derecho de lectura en la tabla stock_vehiculos
REVOKE SELECT ON trabajo_integrador_bases_datos_1.stock_vehiculos FROM 'secure_user'@'localhost';

-- Se le da derechos de lectura y escritura en la tabla stock_vehiculos
GRANT SELECT, UPDATE ON trabajo_integrador_bases_datos_1.stock_vehiculos TO 'secure_user'@'localhost';

FLUSH PRIVILEGES;

-- --------------------------------------------------
-- Comandos para ejecutar con 2 usuarios distintos y documentar un deadlock
-- SESIÓN 1
START TRANSACTION;
UPDATE stock_vehiculos SET cantidad = cantidad - 1 WHERE dominio = 'AB110LG';
-- Esperar antes de ejecutar la siguiente línea
UPDATE stock_vehiculos SET cantidad = cantidad - 1 WHERE dominio = 'AB110LL';
COMMIT;


-- SESIÓN 2
START TRANSACTION;
UPDATE stock_vehiculos SET cantidad = cantidad - 1 WHERE dominio = 'AB110LL';
-- Esperar antes de ejecutar la siguiente línea
UPDATE stock_vehiculos SET cantidad = cantidad - 1 WHERE dominio = 'AB110LG';
COMMIT;

-- ------------------------------------------------
-- Tabla de logging para registrar posibles errores de transacciones
CREATE TABLE IF NOT EXISTS log_transacciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    operacion VARCHAR(100),
    dominio_origen VARCHAR(10),
    dominio_destino VARCHAR(10),
    intento INT,
    estado VARCHAR(50),
    error_msg TEXT
);

DROP PROCEDURE IF EXISTS transferir_stock_retry;

DELIMITER $$
CREATE PROCEDURE transferir_stock_retry(
    IN origen VARCHAR(10),
    IN destino VARCHAR(10),
    IN cant INT
)
BEGIN
    DECLARE intento INT DEFAULT 0;
    DECLARE max_intentos INT DEFAULT 2;
    DECLARE hubo_error INT DEFAULT 0;
    -- Handler para capturar deadlock (error 1213)
    DECLARE CONTINUE HANDLER FOR 1213
    BEGIN
        SET hubo_error = 1;
    END;
    -- Bucle de reintentos
    WHILE intento <= max_intentos DO
        SET intento = intento + 1;
        SET hubo_error = 0;
        -- Log: inicio
        INSERT INTO log_transacciones (operacion, dominio_origen, dominio_destino, intento, estado)
        VALUES ('transferir_stock', origen, destino, intento, 'INICIADO');
        DO SLEEP(3); -- Sleep artificial para probar deadlock
        -- Iniciar transacción
        START TRANSACTION;
        -- Hacer los updates
        UPDATE stock_vehiculos SET cantidad = cantidad - cant WHERE dominio = origen;
        DO SLEEP(5); -- Sleep artificial para probar deadlock
        UPDATE stock_vehiculos SET cantidad = cantidad + cant WHERE dominio = destino;
        -- Si hubo deadlock
        IF hubo_error = 1 THEN
            ROLLBACK;
            -- Log: deadlock
            INSERT INTO log_transacciones (operacion, dominio_origen, dominio_destino, intento, estado, error_msg)
            VALUES ('transferir_stock', origen, destino, intento, 'DEADLOCK', 'Error 1213: Deadlock detectado');
            -- Esperar un poco antes de reintentar
            DO SLEEP(intento * 0.5);
        ELSE
            COMMIT;
            -- Log: éxito
            INSERT INTO log_transacciones (operacion, dominio_origen, dominio_destino, intento, estado)
            VALUES ('transferir_stock', origen, destino, intento, 'EXITOSO');
            -- Salir del bucle
            SET intento = max_intentos + 1;
        END IF;
    END WHILE;
END$$
DELIMITER ;

-- Limpiar log anterior
TRUNCATE TABLE log_transacciones;

-- Permisos de procedure al segundo usuario
GRANT EXECUTE ON PROCEDURE trabajo_integrador_bases_datos_1.transferir_stock_retry TO 'secure_user'@'localhost';
FLUSH PRIVILEGES;

-- Llamar al procedimiento desde dos sesiones simultáneas
-- SESIÓN 1:
CALL transferir_stock_retry('AB110LG', 'AB110LL', 1); -- Ejecuto primero con usuario 1

-- SESIÓN 2 (ejecutar al mismo tiempo):
CALL transferir_stock_retry('AB110LL', 'AB110LG', 1); -- Ejecuto segundo con usuario 2

-- Ver los logs
SELECT * FROM log_transacciones ORDER BY fecha_hora;


-- ----------------------------------------
-- COMPARACIÓN DE NIVELES DE AISLAMIENTO

-- Preparar datos
UPDATE stock_vehiculos SET cantidad = 10 WHERE dominio = 'AB110LG';

-- ============================================
-- PRUEBA 1: READ COMMITTED
-- ============================================

-- SESIÓN 1
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT cantidad FROM stock_vehiculos WHERE dominio = 'AB110LG';  -- Ve: 10
-- PAUSAR - IR A SESIÓN 2

-- SESIÓN 2
START TRANSACTION;
UPDATE stock_vehiculos SET cantidad = 5 WHERE dominio = 'AB110LG';
COMMIT;
-- VOLVER A SESIÓN 1

-- SESIÓN 1 (continúa)
SELECT cantidad FROM stock_vehiculos WHERE dominio = 'AB110LG';  -- Ve: 5 CAMBIÓ
COMMIT;

-- ============================================
-- PRUEBA 2: REPEATABLE READ
-- ============================================

-- Resetear
UPDATE stock_vehiculos SET cantidad = 10 WHERE dominio = 'AB110LG';

-- SESIÓN 1
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT cantidad FROM stock_vehiculos WHERE dominio = 'AB110LG';  -- Ve: 10
-- *** PAUSAR - IR A SESIÓN 2 ***

-- SESIÓN 2
START TRANSACTION;
UPDATE stock_vehiculos SET cantidad = 5 WHERE dominio = 'AB110LG';
COMMIT;
-- *** VOLVER A SESIÓN 1 ***

-- SESIÓN 1 (continúa)
SELECT cantidad FROM stock_vehiculos WHERE dominio = 'AB110LG';  -- Ve: 10 NO CAMBIÓ
COMMIT;