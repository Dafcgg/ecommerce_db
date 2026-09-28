DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_db;

CREATE TABLE categorias (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    total_productos INT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE proveedores (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email_contacto VARCHAR(150) NOT NULL UNIQUE,
    telefono_contacto VARCHAR(30)
) ENGINE=InnoDB;

CREATE TABLE sucursales (
    id_sucursal INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ciudad VARCHAR(100),
    activa TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria INT,
    id_proveedor INT,
    nombre VARCHAR(200) NOT NULL UNIQUE,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL,
    costo DECIMAL(10,2) NOT NULL DEFAULT 0,
    stock INT NOT NULL DEFAULT 0,
    sku VARCHAR(50) NOT NULL UNIQUE,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion DATETIME NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    total_vendido INT NOT NULL DEFAULT 0,
    total_vistas INT NOT NULL DEFAULT 0,
    CONSTRAINT chk_precio_positivo CHECK (precio > 0),
    CONSTRAINT chk_costo_no_negativo CHECK (costo >= 0),
    CONSTRAINT chk_stock_no_negativo CHECK (stock >= 0),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    contrasena_hash VARCHAR(255) NOT NULL,
    direccion_envio VARCHAR(255),
    ciudad VARCHAR(100),
    pais VARCHAR(100),
    fecha_nacimiento DATE,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_ultima_compra DATETIME NULL,
    total_gastado DECIMAL(12,2) NOT NULL DEFAULT 0,
    nivel_lealtad VARCHAR(30) NOT NULL DEFAULT 'Bronce',
    referido_por INT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT fk_cliente_referido FOREIGN KEY (referido_por) REFERENCES clientes(id_cliente) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE ventas (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_sucursal INT NULL,
    fecha_venta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Pendiente de Pago','Procesando','Enviado','Entregado','Cancelado') NOT NULL DEFAULT 'Pendiente de Pago',
    total DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_venta_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE detalle_ventas (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario_congelado DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT fk_detalle_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE promociones (
    id_promocion INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria INT NULL,
    id_producto INT NULL,
    nombre VARCHAR(150) NOT NULL,
    porcentaje_descuento DECIMAL(5,2) NOT NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    activa TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT fk_promo_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_promo_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE resenas_productos (
    id_resena INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    id_cliente INT NOT NULL,
    calificacion TINYINT NOT NULL,
    comentario TEXT,
    fecha_resena DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_calificacion_rango CHECK (calificacion BETWEEN 1 AND 5),
    CONSTRAINT fk_resena_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_resena_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE vistas_productos (
    id_vista INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    id_cliente INT NULL,
    fecha_vista DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_vista_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_vista_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE carritos (
    id_carrito INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Activo','Abandonado','Convertido') NOT NULL DEFAULT 'Activo',
    CONSTRAINT fk_carrito_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE carrito_items (
    id_item INT AUTO_INCREMENT PRIMARY KEY,
    id_carrito INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    CONSTRAINT fk_item_carrito FOREIGN KEY (id_carrito) REFERENCES carritos(id_carrito) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_item_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE logins_fallidos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    usuario_bd VARCHAR(100),
    host_origen VARCHAR(150),
    fecha_intento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE log_permisos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    usuario_bd VARCHAR(100),
    accion VARCHAR(255),
    fecha_accion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE log_cambios_precio (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo DECIMAL(10,2) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_bd VARCHAR(100)
) ENGINE=InnoDB;

CREATE TABLE ventas_archivadas (
    id_venta INT NOT NULL,
    id_cliente INT,
    fecha_venta DATETIME,
    estado VARCHAR(30),
    total DECIMAL(12,2),
    fecha_archivado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_venta)
) ENGINE=InnoDB;

CREATE INDEX idx_productos_categoria ON productos(id_categoria);
CREATE INDEX idx_productos_proveedor ON productos(id_proveedor);
CREATE INDEX idx_ventas_cliente ON ventas(id_cliente);
CREATE INDEX idx_ventas_fecha ON ventas(fecha_venta);
CREATE INDEX idx_detalle_venta ON detalle_ventas(id_venta);
CREATE INDEX idx_detalle_producto ON detalle_ventas(id_producto);

INSERT INTO categorias (nombre, descripcion) VALUES
('Electronica','Dispositivos y gadgets electronicos'),
('Hogar','Articulos para el hogar'),
('Ropa','Prendas de vestir'),
('Deportes','Articulos deportivos'),
('Libros','Libros y material de lectura');

INSERT INTO proveedores (nombre, email_contacto, telefono_contacto) VALUES
('TechSupply SA','contacto@techsupply.com','3001234567'),
('HogarMax','ventas@hogarmax.com','3002345678'),
('ModaViva','info@modaviva.com','3003456789'),
('DeporTotal','contacto@deportotal.com','3004567890'),
('LibroMundo','pedidos@libromundo.com','3005678901');

INSERT INTO sucursales (nombre, ciudad) VALUES
('Sucursal Centro','Medellin'),
('Sucursal Norte','Bogota'),
('Sucursal Sur','Cali');

INSERT INTO productos (id_categoria, id_proveedor, nombre, descripcion, precio, costo, stock, sku) VALUES
(1,1,'Audifonos Bluetooth X200','Audifonos inalambricos con cancelacion de ruido',149900,80000,50,'SKU-ELE-0001'),
(1,1,'Smartwatch Fit 5','Reloj inteligente con monitor cardiaco',329900,180000,30,'SKU-ELE-0002'),
(1,1,'Cargador Rapido USB-C','Cargador de pared 30W',49900,20000,120,'SKU-ELE-0003'),
(2,2,'Juego de Sabanas Queen','Sabanas 100% algodon',119900,60000,40,'SKU-HOG-0001'),
(2,2,'Lampara LED Escritorio','Lampara regulable con puerto USB',79900,35000,60,'SKU-HOG-0002'),
(3,3,'Chaqueta Impermeable','Chaqueta para lluvia unisex',189900,90000,25,'SKU-ROP-0001'),
(3,3,'Camiseta Basica Algodon','Camiseta unisex varias tallas',39900,15000,200,'SKU-ROP-0002'),
(4,4,'Balon de Futbol Pro','Balon oficial talla 5',89900,40000,70,'SKU-DEP-0001'),
(4,4,'Set de Mancuernas 10kg','Par de mancuernas ajustables',199900,110000,15,'SKU-DEP-0002'),
(5,5,'Novela Historica Vol1','Bestseller de ficcion historica',59900,25000,90,'SKU-LIB-0001');

INSERT INTO clientes (nombre, apellido, email, contrasena_hash, direccion_envio, ciudad, pais, fecha_nacimiento) VALUES
('Ana','Gomez','ana.gomez@correo.com','$2y$10$hashfalsoana000000000000000000000000000000000000','Calle 10 #20-30','Medellin','Colombia','1995-04-12'),
('Carlos','Perez','carlos.perez@correo.com','$2y$10$hashfalsocarlos00000000000000000000000000000000000','Carrera 45 #12-08','Bogota','Colombia','1990-08-23'),
('Laura','Ramirez','laura.ramirez@correo.com','$2y$10$hashfalsolaura0000000000000000000000000000000000000','Av Siempre Viva 742','Cali','Colombia','1998-01-30'),
('Diego','Torres','diego.torres@correo.com','$2y$10$hashfalsodiego0000000000000000000000000000000000000','Calle 100 #15-20','Medellin','Colombia','1988-11-05'),
('Maria','Lopez','maria.lopez@correo.com','$2y$10$hashfalsomaria0000000000000000000000000000000000000','Transversal 5 #8-9','Barranquilla','Colombia','2000-06-18');

INSERT INTO ventas (id_cliente, id_sucursal, fecha_venta, estado, total) VALUES
(1,1,'2026-06-01 10:15:00','Entregado',329800),
(2,2,'2026-06-05 14:30:00','Entregado',149900),
(1,1,'2026-07-02 09:00:00','Entregado',119900),
(3,3,'2026-07-15 16:45:00','Enviado',269800),
(4,1,'2026-08-01 11:20:00','Procesando',89900),
(5,2,'2026-08-10 18:00:00','Pendiente de Pago',199900),
(2,2,'2026-08-20 13:10:00','Entregado',39900);

INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado) VALUES
(1,1,1,149900),
(1,2,1,329900),
(2,1,1,149900),
(3,4,1,119900),
(4,6,1,189900),
(4,7,2,39900),
(5,8,1,89900),
(6,9,1,199900),
(7,7,1,39900);

INSERT INTO promociones (id_categoria, id_producto, nombre, porcentaje_descuento, fecha_inicio, fecha_fin, activa) VALUES
(1,NULL,'Descuento Electronica Julio',10.00,'2026-07-01 00:00:00','2026-07-31 23:59:59',0),
(NULL,7,'Camiseta Basica Oferta',15.00,'2026-08-01 00:00:00','2026-09-30 23:59:59',1);

INSERT INTO resenas_productos (id_producto, id_cliente, calificacion, comentario) VALUES
(1,1,5,'Excelente calidad de sonido'),
(1,2,4,'Muy buenos pero la bateria dura poco'),
(4,1,5,'Sabanas muy suaves y comodas'),
(7,2,3,'Talla mas pequena de lo esperado');

INSERT INTO vistas_productos (id_producto, id_cliente) VALUES
(1,1),(1,2),(1,3),(2,1),(2,4),(4,1),(7,2),(7,5),(9,4),(9,5);
