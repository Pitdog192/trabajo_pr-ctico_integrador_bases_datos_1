# Trabajo Final Integrador (TFI) - Bases de Datos I 

## Etapa 1 – Modelado y Definición de Constraints

### Creación base de datos y tablas
![alt text](image.png)

### Incorporación contraints
![alt text](image-1.png)

### Prueba la robustez
#### Inserción válida
![alt text](image-2.png)
![alt text](image-3.png)

#### Inserción errónea por anio fuera de rango
 ![alt text](image-4.png)
 ![alt text](image-5.png)

### Demostración DER 
 ![alt text](image.png)

## Etapa 2 - Generación y carga de datos masivos con SQL puro

### Creación de tablas semilla, se genera una tabla temporal con una secuencia de hasta 200.000 para generar esos registros
![alt text](image-3.png)

### Se insertan primero los seguros para integridad referencial
![alt text](image-4.png)

### Se insertan los vehiculos tomando como referencia los numeros creados en la tabla semilla
![alt text](image-5.png)

### Emparejamiento de los vehiculos con los seguros atravez de FK id_seguro
![alt text](image-6.png)

### Conteo de tuplas
![alt text](image-7.png)

### Sin registros huerfanos
![alt text](image-8.png)

### Sin dominios o poliza duplicadas
![alt text](image-9.png)
![alt text](image-10.png)

### Descripción conceptual 
Usé una tabla con números del 1 al 200.000 como base, y a partir de esos números generé todos los datos de forma automática usando operaciones matemáticas simples. Primero creé los seguros, después los vehículos, y al final los conecté.
 - Se usaron los siguientes comandos sql:
    - WITH RECURSIVE: Para generar la lista de números del 1 al 200.000
    - INSERT ... SELECT: Para insertar muchos registros de una sola vez
    - CASE WHEN: Para elegir diferentes valores según el número
    - MOD(): Para rotar entre opciones (resto de la división)
    - CONCAT(): Para armar textos únicos (como "POL-00000001")
    - UPDATE con JOIN: Para conectar vehículos con seguro
Primero inserté los seguros porque los vehículos tienen una foreign key (clave foránea) que apunta a los seguros. Si intentaba crear un vehículo con un seguro que no existe, MySQL me daba error.

## Etapa 3

### Consultas JOIN
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

### Consulta GROUP BY + HAVING
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

### Subconsulta
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

### Script creación de vista
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

#### Se creó una vista tipo reporte, sería la más usada por un usuario administrativo o empleado de aseguradora que necesita ver qué seguro tiene cada auto. Evita tener que hacer JOIN manuales en cada consulta. Sirve de base para generar reportes, por ejemplo: seguros próximos a vencer, vehículos sin seguro, vencimientos por aseguradora.


