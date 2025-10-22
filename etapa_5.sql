USE trabajo_integrador_bases_datos_1;

-- Creo una tabla de prueba y le inserto un valor
CREATE TABLE IF NOT EXISTS stock_vehiculos (
  id INT PRIMARY KEY AUTO_INCREMENT,
  dominio VARCHAR(10) UNIQUE,
  cantidad INT DEFAULT 10,
  actualizado TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT IGNORE INTO stock_vehiculos (dominio, cantidad)
VALUES ('AB110LG', 10), ('AB110LL', 8);

GRANT SELECT ON trabajo_integrador_bases_datos_1.stock_vehiculos TO 'secure_user'@'localhost';

START TRANSACTION;
UPDATE stock_vehiculos SET cantidad = cantidad - 1 WHERE dominio = 'AB110LL';