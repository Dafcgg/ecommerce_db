-- =============================================================================
-- PROYECTO: Base de Datos de un E-commerce
-- ARCHIVO : 06_Eventos.sql
-- DESCRIPCIÓN: Eventos programados para automatización, mantenimiento y reportería.
-- MOTOR   : MySQL 8.0+
-- =============================================================================

USE ecommerce_db;

SET GLOBAL event_scheduler = ON;

-- -----------------------------------------------------------------------------
-- SECCIÓN 1: TABLAS DE SOPORTE PARA REPORTES Y MONITOREO
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reporte_ventas_semanales (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    semana_inicio DATE NOT NULL,
    semana_fin DATE NOT NULL,
    total_ventas DECIMAL(14,2) NOT NULL,
    numero_ordenes INT NOT NULL,
    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reorden_sugerida (
    id_reorden INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    stock_actual INT NOT NULL,
    cantidad_sugerida INT NOT NULL,
    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kpi_mensual (
    id_kpi INT AUTO_INCREMENT PRIMARY KEY,
    mes VARCHAR(7) NOT NULL,
    total_ventas DECIMAL(14,2) NOT NULL,
    total_clientes_nuevos INT NOT NULL,
    ticket_promedio DECIMAL(12,2) NOT NULL,
    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tamano_bd_log (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    tamano_mb DECIMAL(12,2) NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alertas_fraude (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    fecha_deteccion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS respaldo_productos (
    id_producto INT NOT NULL,
    nombre VARCHAR(200),
    precio DECIMAL(10,2),
    stock INT,
    fecha_respaldo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_producto, fecha_respaldo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ranking_productos (
    id_producto INT PRIMARY KEY,
    total_vendido INT NOT NULL,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS agregados_ventas_diarias (
    id_agregado INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE NOT NULL UNIQUE,
    total_vendido DECIMAL(14,2) NOT NULL,
    numero_ordenes INT NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reporte_proveedores_mensual (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    id_proveedor INT NOT NULL,
    mes VARCHAR(7) NOT NULL,
    ingresos_generados DECIMAL(14,2) NOT NULL,
    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- SECCIÓN 2: DEFINICIÓN DE EVENTOS PROGRAMADOS
-- -----------------------------------------------------------------------------
DELIMITER //

-- EVENTO 01: Reporte semanal de ventas consolidadas
DROP EVENT IF EXISTS evt_generate_weekly_sales_report //
CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO reporte_ventas_semanales (semana_inicio, semana_fin, total_ventas, numero_ordenes)
    SELECT DATE(NOW() - INTERVAL 7 DAY), DATE(NOW()), COALESCE(SUM(total), 0.00), COUNT(*)
    FROM ventas
    WHERE fecha_venta >= (NOW() - INTERVAL 7 DAY) AND estado <> 'Cancelado';
END //

-- EVENTO 02: Limpieza diaria de ítems de carritos convertidos en compras
DROP EVENT IF EXISTS evt_cleanup_temp_tables_daily //
CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM carrito_items
    WHERE id_carrito IN (SELECT id_carrito FROM carritos WHERE estado = 'Convertido');
END //

-- EVENTO 03: Depuración mensual de logs históricos antiguos (> 12 meses)
DROP EVENT IF EXISTS evt_archive_old_logs_monthly //
CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM log_permisos WHERE fecha_accion < (NOW() - INTERVAL 12 MONTH);
    DELETE FROM logins_fallidos WHERE fecha_intento < (NOW() - INTERVAL 12 MONTH);
END //

-- EVENTO 04: Desactivación horaria de promociones vencidas
DROP EVENT IF EXISTS evt_deactivate_expired_promotions_hourly //
CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
DO
BEGIN
    UPDATE promociones
    SET activa = 0
    WHERE fecha_fin < NOW() AND activa = 1;
END //

-- EVENTO 05: Recálculo nocturno de niveles de fidelización de clientes
DROP EVENT IF EXISTS evt_recalculate_customer_loyalty_tiers_nightly //
CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '02:00:00')
DO
BEGIN
    UPDATE clientes
    SET nivel_lealtad = fn_DeterminarEstadoLealtad(total_gastado);
END //

-- EVENTO 06: Generación diaria de sugerencias de reabastecimiento (stock crítico)
DROP EVENT IF EXISTS evt_generate_reorder_list_daily //
CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO reorden_sugerida (id_producto, stock_actual, cantidad_sugerida)
    SELECT id_producto, stock, GREATEST(50 - stock, 10)
    FROM productos
    WHERE stock <= 15 AND activo = 1;
END //

-- EVENTO 07: Optimización y análisis de estadísticas de índices semanal
DROP EVENT IF EXISTS evt_rebuild_indexes_weekly //
CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
BEGIN
    ANALYZE TABLE productos, ventas, detalle_ventas, clientes;
END //

-- EVENTO 08: Suspensión trimestral de cuentas inactivas (> 12 meses sin transacciones)
DROP EVENT IF EXISTS evt_suspend_inactive_accounts_quarterly //
CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH STARTS CURRENT_TIMESTAMP
DO
BEGIN
    UPDATE clientes
    SET activo = 0
    WHERE (fecha_ultima_compra IS NULL OR fecha_ultima_compra < (NOW() - INTERVAL 12 MONTH))
      AND fecha_registro < (NOW() - INTERVAL 12 MONTH)
      AND activo = 1;
END //

-- EVENTO 09: Agregación nocturna de métricas diarias de facturación
DROP EVENT IF EXISTS evt_aggregate_daily_sales_data //
CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '01:00:00')
DO
BEGIN
    INSERT INTO agregados_ventas_diarias (fecha, total_vendido, numero_ordenes)
    SELECT DATE(NOW() - INTERVAL 1 DAY), COALESCE(SUM(total), 0.00), COUNT(*)
    FROM ventas
    WHERE DATE(fecha_venta) = DATE(NOW() - INTERVAL 1 DAY) AND estado <> 'Cancelado'
    ON DUPLICATE KEY UPDATE 
        total_vendido = VALUES(total_vendido),
        numero_ordenes = VALUES(numero_ordenes);
END //

-- EVENTO 10: Auditoría nocturna de consistencia en totales de ventas
DROP EVENT IF EXISTS evt_check_data_consistency_nightly //
CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '03:00:00')
DO
BEGIN
    UPDATE ventas v
    SET total = fn_CalcularTotalVenta(v.id_venta)
    WHERE v.total <> fn_CalcularTotalVenta(v.id_venta);
END //

-- EVENTO 11: Envío diario de notificaciones de cumpleaños a clientes
DROP EVENT IF EXISTS evt_send_birthday_greetings_daily //
CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO log_permisos (usuario_bd, accion)
    SELECT 'SISTEMA', CONCAT('Saludo de cumpleanos programado para cliente id ', id_cliente, ' (', nombre, ' ', apellido, ')')
    FROM clientes
    WHERE MONTH(fecha_nacimiento) = MONTH(CURDATE()) 
      AND DAY(fecha_nacimiento) = DAY(CURDATE())
      AND activo = 1;
END //

-- EVENTO 12: Actualización horaria de ranking de productos más vendidos
DROP EVENT IF EXISTS evt_update_product_rankings_hourly //
CREATE EVENT evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
DO
BEGIN
    REPLACE INTO ranking_productos (id_producto, total_vendido, fecha_actualizacion)
    SELECT id_producto, total_vendido, NOW()
    FROM productos;
END //

-- EVENTO 13: Respaldo diario de seguridad de catálogo de productos
DROP EVENT IF EXISTS evt_backup_critical_tables_daily //
CREATE EVENT evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '00:30:00')
DO
BEGIN
    INSERT INTO respaldo_productos (id_producto, nombre, precio, stock)
    SELECT id_producto, nombre, precio, stock FROM productos;
END //

-- EVENTO 14: Marcado automático de carritos abandonados (> 3 días de inactividad)
DROP EVENT IF EXISTS evt_clear_abandoned_carts_daily //
CREATE EVENT evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    UPDATE carritos
    SET estado = 'Abandonado'
    WHERE estado = 'Activo' AND fecha_actualizacion < (NOW() - INTERVAL 3 DAY);
END //

-- EVENTO 15: Cálculo mensual de indicadores clave de rendimiento (KPIs)
DROP EVENT IF EXISTS evt_calculate_monthly_kpis //
CREATE EVENT evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO kpi_mensual (mes, total_ventas, total_clientes_nuevos, ticket_promedio)
    SELECT 
        DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m'),
        COALESCE((SELECT SUM(total) FROM ventas WHERE DATE_FORMAT(fecha_venta,'%Y-%m') = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m') AND estado <> 'Cancelado'), 0.00),
        COALESCE((SELECT COUNT(*) FROM clientes WHERE DATE_FORMAT(fecha_registro,'%Y-%m') = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m')), 0),
        COALESCE((SELECT AVG(total) FROM ventas WHERE DATE_FORMAT(fecha_venta,'%Y-%m') = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m') AND estado <> 'Cancelado'), 0.00);
END //

-- EVENTO 16: Refresco nocturno de contadores y estadísticas acumuladas
DROP EVENT IF EXISTS evt_refresh_materialized_views_nightly //
CREATE EVENT evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '04:00:00')
DO
BEGIN
    UPDATE categorias c
    SET total_productos = (SELECT COUNT(*) FROM productos p WHERE p.id_categoria = c.id_categoria);

    UPDATE productos p
    SET total_vendido = COALESCE((
            SELECT SUM(dv.cantidad) 
            FROM detalle_ventas dv 
            JOIN ventas v ON v.id_venta = dv.id_venta 
            WHERE dv.id_producto = p.id_producto AND v.estado <> 'Cancelado'
        ), 0),
        total_vistas = (
            SELECT COUNT(*) 
            FROM vistas_productos vp 
            WHERE vp.id_producto = p.id_producto
        );
END //

-- EVENTO 17: Monitoreo y registro semanal del volumen de base de datos
DROP EVENT IF EXISTS evt_log_database_size_weekly //
CREATE EVENT evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO tamano_bd_log (tamano_mb)
    SELECT COALESCE(SUM(data_length + index_length) / 1024 / 1024, 0.00)
    FROM information_schema.tables
    WHERE table_schema = 'ecommerce_db';
END //

-- EVENTO 18: Detección horaria de patrones sospechosos de compras (> 5 pedidos/hora)
DROP EVENT IF EXISTS evt_detect_fraudulent_activity_hourly //
CREATE EVENT evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO alertas_fraude (id_cliente, motivo)
    SELECT id_cliente, CONCAT('Alerta: ', COUNT(*), ' ordenes generadas en la ultima hora')
    FROM ventas
    WHERE fecha_venta >= (NOW() - INTERVAL 1 HOUR)
    GROUP BY id_cliente
    HAVING COUNT(*) >= 5;
END //

-- EVENTO 19: Generación mensual de informe de facturación por proveedor
DROP EVENT IF EXISTS evt_generate_supplier_performance_report_monthly //
CREATE EVENT evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO reporte_proveedores_mensual (id_proveedor, mes, ingresos_generados)
    SELECT 
        pr.id_proveedor, 
        DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m'),
        COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado), 0.00)
    FROM proveedores pr
    LEFT JOIN productos p ON p.id_proveedor = pr.id_proveedor
    LEFT JOIN (
        detalle_ventas dv
        JOIN ventas v ON v.id_venta = dv.id_venta 
            AND v.estado <> 'Cancelado' 
            AND DATE_FORMAT(v.fecha_venta, '%Y-%m') = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m')
    ) ON dv.id_producto = p.id_producto
    GROUP BY pr.id_proveedor;
END //

-- EVENTO 20: Depuración semanal de productos inactivos sin ventas
DROP EVENT IF EXISTS evt_purge_soft_deleted_records_weekly //
CREATE EVENT evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM productos
    WHERE activo = 0 
      AND fecha_modificacion < (NOW() - INTERVAL 6 MONTH)
      AND NOT EXISTS (
          SELECT 1 FROM detalle_ventas dv WHERE dv.id_producto = productos.id_producto
      );
END //

DELIMITER ;
