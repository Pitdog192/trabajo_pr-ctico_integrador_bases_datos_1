CREATE DATABASE IF NOT EXISTS `trabajo_integrador_bases_datos_1` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
use trabajo_integrador_bases_datos_1;

-- -----------------------------------
-- Se crea la tabla vehiculos
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

-- Se crea la tabla seguro_vehicular
CREATE TABLE seguro_vehicular(
	id int primary key auto_increment ,
    eliminado boolean,
    aseguradora varchar(80) not null,
    nro_poliza varchar(50) unique not null,
    cobertura varchar(20) NOT NULL,
    vencimiento date not null,
    /* No se añade el id de un vehiculo al existir la posibilidad de crear un seguro tipo flota en un futuro donde se establesca una relación 1:N  */ 
    CONSTRAINT chk_seguros_cobertura CHECK (cobertura IN ('RC','TERCEROS','TODO_RIESGO'))
);

-- --------------------------------
-- Se añaden las FK
ALTER TABLE vehiculos 
	ADD CONSTRAINT fk_id_seguro 
    FOREIGN KEY (id_seguro) 
    REFERENCES seguro_vehicular(id)
    /* Se eliminó ON UPDATE CASCADE por sugerencia de IA ya que no aporta nada significativo al ser raro actualizar el id de un seguro */ 
	ON DELETE SET NULL;

ALTER TABLE vehiculos
    ADD CONSTRAINT chk_vehiculos_anio_rango
    CHECK (anio IS NULL OR (anio BETWEEN 1900 AND 2100));

-- -----------------------------------------
-- Inserción correcta
INSERT INTO seguro_vehicular (eliminado, aseguradora, nro_poliza, cobertura, vencimiento)
VALUES (false, 'La Caja', 'POL-001', 'TODO_RIESGO', '2026-12-31');

-- Segunda insersión correcta
INSERT INTO vehiculos (eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro)
VALUES (FALSE, 'AB110LG', 'FORD', 'MUSTANG', 2022, 'ABC123', 1);

-- Inserción incorrecta por key duplicada
INSERT INTO vehiculos (eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro)
VALUES (false, 'CD220MN', 'TOYOTA', 'COROLLA', 2021, 'XYZ789', 1);

-- Inserción incorrecta por valor fuera de rango en check
INSERT INTO seguro_vehicular (eliminado, aseguradora, nro_poliza, cobertura, vencimiento)
VALUES (false, 'Seguros SA', 'POL-002', 'COBERTURA_INVALIDA', '2025-06-30');