USE ecommerce_db;

CREATE OR REPLACE VIEW v_info_clientes_basica AS
SELECT id_cliente, nombre, apellido, ciudad, pais, nivel_lealtad
FROM clientes;

CREATE OR REPLACE VIEW v_ventas_publicas AS
SELECT id_venta, id_cliente, fecha_venta, estado, total
FROM ventas;

CREATE ROLE IF NOT EXISTS 'Administrador_Sistema';
CREATE ROLE IF NOT EXISTS 'Gerente_Marketing';
CREATE ROLE IF NOT EXISTS 'Analista_Datos';
CREATE ROLE IF NOT EXISTS 'Empleado_Inventario';
CREATE ROLE IF NOT EXISTS 'Atencion_Cliente';
CREATE ROLE IF NOT EXISTS 'Auditor_Financiero';
CREATE ROLE IF NOT EXISTS 'Visitante';

GRANT ALL PRIVILEGES ON ecommerce_db.* TO 'Administrador_Sistema';

GRANT SELECT ON ecommerce_db.ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.clientes TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.promociones TO 'Gerente_Marketing';
GRANT EXECUTE ON ecommerce_db.* TO 'Gerente_Marketing';

GRANT SELECT ON ecommerce_db.productos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.categorias TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.proveedores TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.clientes TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.ventas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Analista_Datos';

GRANT SELECT, UPDATE (stock) ON ecommerce_db.productos TO 'Empleado_Inventario';
GRANT SELECT ON ecommerce_db.categorias TO 'Empleado_Inventario';
GRANT SELECT ON ecommerce_db.proveedores TO 'Empleado_Inventario';

GRANT SELECT ON ecommerce_db.v_info_clientes_basica TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.ventas TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Atencion_Cliente';
GRANT UPDATE (estado) ON ecommerce_db.ventas TO 'Atencion_Cliente';

GRANT SELECT ON ecommerce_db.ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.productos TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.log_cambios_precio TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.log_permisos TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.logins_fallidos TO 'Auditor_Financiero';

GRANT SELECT ON ecommerce_db.productos TO 'Visitante';
GRANT SELECT ON ecommerce_db.categorias TO 'Visitante';

CREATE USER IF NOT EXISTS 'admin_user'@'%' IDENTIFIED BY 'Adm1n$Secure2026!' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER IF NOT EXISTS 'marketing_user'@'%' IDENTIFIED BY 'Mkt$Secure2026!' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER IF NOT EXISTS 'analyst_user'@'%' IDENTIFIED BY 'Anl$Secure2026!' WITH MAX_QUERIES_PER_HOUR 500 PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER IF NOT EXISTS 'inventory_user'@'%' IDENTIFIED BY 'Inv$Secure2026!' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER IF NOT EXISTS 'support_user'@'%' IDENTIFIED BY 'Sup$Secure2026!' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER IF NOT EXISTS 'auditor_user'@'%' IDENTIFIED BY 'Aud$Secure2026!' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER IF NOT EXISTS 'visitor_user'@'%' IDENTIFIED BY 'Vis$Secure2026!' PASSWORD EXPIRE INTERVAL 90 DAY;

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

DROP USER IF EXISTS 'root'@'%';

FLUSH PRIVILEGES;
