CREATE DATABASE `trabajo_integrador_bases_datos_1`;

CREATE TABLE vehiculos(
	id int primary key auto_increment,
    eliminado boolean,
    dominio varchar(10) unique not null,
    marca varchar(50) not null,
    modelo varchar(50) not null,
    anio int CHECK (anio IS NULL OR (anio BETWEEN 1900 AND 2100)),
    nro_chasis varchar(50) unique,
    id_seguro int unique
);

CREATE TABLE seguro_vehicular(
	id int primary key auto_increment ,
    eliminado boolean,
    aseguradora varchar(80) not null,
    nro_poliza varchar(50) unique not null,
    cobertura varchar(20) NOT NULL CHECK (cobertura IN ('RC','TERCEROS','TODO_RIESGO')),
    vencimiento date not null 
);

ALTER TABLE vehiculos ADD CONSTRAINT fk_id_seguro FOREIGN KEY (id_seguro) REFERENCES seguro_vehicular(id) ON UPDATE CASCADE ON DELETE SET NULL;

DROP TABLE vehiculos;
DROP TABLE seguro_vehicular;