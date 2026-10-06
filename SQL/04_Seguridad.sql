-- =============================================================================
-- PROYECTO: Base de Datos de un E-commerce
-- ARCHIVO : 04_Seguridad.sql
-- DESCRIPCIÓN: Seguridad Basada en Roles (RBAC), Principio de Menor Privilegio,
--              Vistas de Seguridad, Políticas de Contraseñas y Endurecimiento.
-- MOTOR   : MySQL 8.0+
-- =============================================================================

USE ecommerce_db;

-- -----------------------------------------------------------------------------
-- SECCIÓN 1: VISTAS DE SEGURIDAD (Data Masking y Abstracción)
-- -----------------------------------------------------------------------------

-- Vista 1: Información básica de clientes (oculta hashes, dirección y fecha de nacimiento)
CREATE OR REPLACE VIEW v_info_clientes_basica AS
SELECT 
    id_cliente, 
    nombre, 
    apellido, 
    ciudad, 
    pais, 
    nivel_lealtad,
    activo
FROM clientes;

-- Vista 2: Catálogo público de productos (oculta costos de adquisición y márgenes comerciales)
CREATE OR REPLACE VIEW v_catalogo_publico AS
SELECT 
    p.id_producto,
    p.sku,
    p.nombre,
    c.nombre AS categoria,
    p.descripcion,
    p.precio,
    (p.stock > 0) AS disponible
FROM productos p
LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
WHERE p.activo = 1;

-- Vista 3: Resumen público de ventas (anonimizada)
CREATE OR REPLACE VIEW v_ventas_publicas AS
SELECT 
    id_venta, 
    id_cliente, 
    fecha_venta, 
    estado, 
    total
FROM ventas;

-- -----------------------------------------------------------------------------
-- SECCIÓN 2: CREACIÓN DE ROLES (RBAC)
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'Administrador_Sistema';
CREATE ROLE IF NOT EXISTS 'Gerente_Marketing';
CREATE ROLE IF NOT EXISTS 'Analista_Datos';
CREATE ROLE IF NOT EXISTS 'Empleado_Inventario';
CREATE ROLE IF NOT EXISTS 'Atencion_Cliente';
CREATE ROLE IF NOT EXISTS 'Auditor_Financiero';
CREATE ROLE IF NOT EXISTS 'Visitante';

-- -----------------------------------------------------------------------------
-- SECCIÓN 3: ASIGNACIÓN DE PRIVILEGIOS A ROLES (Least Privilege Principle)
-- -----------------------------------------------------------------------------

-- 1. Rol Administrador: Control total sobre el esquema ecommerce_db
GRANT ALL PRIVILEGES ON ecommerce_db.* TO 'Administrador_Sistema';

-- 2. Rol Gerente de Marketing: Analítica de clientes, ventas, promociones y carritos
GRANT SELECT ON ecommerce_db.ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Gerente_Marketing';
-- Sin contrasena_hash ni direccion_envio (datos que este rol no necesita)
GRANT SELECT (id_cliente, nombre, apellido, email, ciudad, pais, fecha_nacimiento,
              fecha_registro, fecha_ultima_compra, total_gastado, nivel_lealtad,
              referido_por, activo)
    ON ecommerce_db.clientes TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.vistas_productos TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.resenas_productos TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.carritos TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.carrito_items TO 'Gerente_Marketing';
GRANT SELECT, INSERT, UPDATE, DELETE ON ecommerce_db.promociones TO 'Gerente_Marketing';
GRANT EXECUTE ON ecommerce_db.* TO 'Gerente_Marketing';

-- 3. Rol Analista de Datos: Lectura sobre todas las tablas analíticas y operativas
GRANT SELECT ON ecommerce_db.productos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.categorias TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.proveedores TO 'Analista_Datos';
-- Sin contrasena_hash ni direccion_envio
GRANT SELECT (id_cliente, nombre, apellido, email, ciudad, pais, fecha_nacimiento,
              fecha_registro, fecha_ultima_compra, total_gastado, nivel_lealtad,
              referido_por, activo)
    ON ecommerce_db.clientes TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.ventas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.promociones TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.vistas_productos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.resenas_productos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.carritos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.carrito_items TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.log_cambios_precio TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.devoluciones TO 'Analista_Datos';

-- 4. Rol Empleado de Inventario: Gestión y ajuste de stock
GRANT SELECT, UPDATE (stock) ON ecommerce_db.productos TO 'Empleado_Inventario';
GRANT SELECT ON ecommerce_db.categorias TO 'Empleado_Inventario';
GRANT SELECT ON ecommerce_db.proveedores TO 'Empleado_Inventario';

-- 5. Rol Atención al Cliente: Consulta de órdenes y actualización de estados
GRANT SELECT ON ecommerce_db.v_info_clientes_basica TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.ventas TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.resenas_productos TO 'Atencion_Cliente';
GRANT UPDATE (estado) ON ecommerce_db.ventas TO 'Atencion_Cliente';

-- 6. Rol Auditor Financiero: Trazabilidad, logs y auditoría de clientes
GRANT SELECT ON ecommerce_db.ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.productos TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.log_cambios_precio TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.log_permisos TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.logins_fallidos TO 'Auditor_Financiero';
-- NOTA: El permiso para Auditoria_Clientes ha sido movido al script 08
GRANT SELECT ON ecommerce_db.ventas_archivadas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.devoluciones TO 'Auditor_Financiero';

-- 7. Rol Visitante: Acceso exclusivo a catálogo público
GRANT SELECT ON ecommerce_db.v_catalogo_publico TO 'Visitante';
GRANT SELECT ON ecommerce_db.categorias TO 'Visitante';

-- -----------------------------------------------------------------------------
-- SECCIÓN 4: CREACIÓN DE USUARIOS Y POLÍTICAS DE EXPIRACIÓN
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'admin_user'@'%' 
    IDENTIFIED BY 'Adm1n$Secure2026!' 
    PASSWORD EXPIRE INTERVAL 90 DAY;

CREATE USER IF NOT EXISTS 'marketing_user'@'%' 
    IDENTIFIED BY 'Mkt$Secure2026!' 
    PASSWORD EXPIRE INTERVAL 90 DAY;

CREATE USER IF NOT EXISTS 'analyst_user'@'%' 
    IDENTIFIED BY 'Anl$Secure2026!' 
    WITH MAX_QUERIES_PER_HOUR 500 
    PASSWORD EXPIRE INTERVAL 90 DAY;

CREATE USER IF NOT EXISTS 'inventory_user'@'%' 
    IDENTIFIED BY 'Inv$Secure2026!' 
    PASSWORD EXPIRE INTERVAL 90 DAY;

CREATE USER IF NOT EXISTS 'support_user'@'%' 
    IDENTIFIED BY 'Sup$Secure2026!' 
    PASSWORD EXPIRE INTERVAL 90 DAY;

CREATE USER IF NOT EXISTS 'auditor_user'@'%' 
    IDENTIFIED BY 'Aud$Secure2026!' 
    PASSWORD EXPIRE INTERVAL 90 DAY;

CREATE USER IF NOT EXISTS 'visitor_user'@'%' 
    IDENTIFIED BY 'Vis$Secure2026!' 
    PASSWORD EXPIRE INTERVAL 90 DAY;

-- -----------------------------------------------------------------------------
-- SECCIÓN 5: ASIGNACIÓN Y ACTIVACIÓN DE ROLES POR DEFECTO
-- -----------------------------------------------------------------------------
GRANT 'Administrador_Sistema' TO 'admin_user'@'%';
GRANT 'Gerente_Marketing' TO 'marketing_user'@'%';
GRANT 'Analista_Datos' TO 'analyst_user'@'%';
GRANT 'Empleado_Inventario' TO 'inventory_user'@'%';
GRANT 'Atencion_Cliente' TO 'support_user'@'%';
GRANT 'Auditor_Financiero' TO 'auditor_user'@'%';
GRANT 'Visitante' TO 'visitor_user'@'%';

SET DEFAULT ROLE 'Administrador_Sistema' TO 'admin_user'@'%';
SET DEFAULT ROLE 'Gerente_Marketing' TO 'marketing_user'@'%';
SET DEFAULT ROLE 'Analista_Datos' TO 'analyst_user'@'%';
SET DEFAULT ROLE 'Empleado_Inventario' TO 'inventory_user'@'%';
SET DEFAULT ROLE 'Atencion_Cliente' TO 'support_user'@'%';
SET DEFAULT ROLE 'Auditor_Financiero' TO 'auditor_user'@'%';
SET DEFAULT ROLE 'Visitante' TO 'visitor_user'@'%';

-- -----------------------------------------------------------------------------
-- SECCIÓN 6: ENDURECIMIENTO DE SEGURIDAD (Hardening)
-- -----------------------------------------------------------------------------
-- IMPORTANTE: este paso se deja COMENTADO a proposito. Si te conectas como
-- root@'%' (p. ej. MySQL en Docker o por TCP), al eliminarlo los scripts 05 a 08
-- fallarian con "Access denied". Ejecutalo manualmente DESPUES del script 08:
-- DROP USER IF EXISTS 'root'@'%';

FLUSH PRIVILEGES;
