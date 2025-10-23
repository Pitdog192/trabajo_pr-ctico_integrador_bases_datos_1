CREATE DATABASE IF NOT EXISTS `trabajo_integrador_bases_datos_1` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
use trabajo_integrador_bases_datos_1;
CREATE TABLE IF NOT EXISTS vehiculos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    eliminado BOOLEAN,
    dominio VARCHAR(10) UNIQUE NOT NULL,
    marca VARCHAR(50) NOT NULL,
    modelo VARCHAR(50) NOT NULL,
    anio INT,
    nro_chasis VARCHAR(50) UNIQUE,
    id_seguro INT UNIQUE,
    CONSTRAINT chk_vehiculos_anio_rango CHECK (anio IS NULL OR (anio BETWEEN 1900 AND 2100)),
    CONSTRAINT fk_id_seguro FOREIGN KEY (id_seguro) REFERENCES seguro_vehicular(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS seguro_vehicular(
	id int primary key auto_increment ,
    eliminado boolean,
    aseguradora varchar(80) not null,
    nro_poliza varchar(50) unique not null,
    cobertura varchar(20) NOT NULL,
    vencimiento date not null,
    CONSTRAINT chk_seguros_cobertura CHECK (cobertura IN ('RC','TERCEROS','TODO_RIESGO'))
    /* No se añade el id de un vehiculo al existir la posibilidad de crear un seguro tipo flota en un futuro donde se establesca una relación 1:N  */ 
);

INSERT INTO IGNORE vehiculos (eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro) 
VALUES (
    false,
    'AB110LG',
    'FORD',
    'MUSTANG',
    2022,
    'ABC123',
    NULL
);

INSERT INTO IGNORE vehiculos (eliminado, dominio, marca, modelo, anio, nro_chasis, id_seguro) 
VALUES (
    false,
    'AB110LL',
    'FORD',
    'MUSTANG',
    803,
    'ABC124',
    NULL
);