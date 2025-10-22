CREATE DATABASE `trabajo_integrador_bases_datos_1` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
use trabajo_integrador_bases_datos_1;
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