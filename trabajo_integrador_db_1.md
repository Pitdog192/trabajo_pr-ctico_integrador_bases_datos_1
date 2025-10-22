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
