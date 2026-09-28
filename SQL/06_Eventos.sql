USE ecommerce_db;

SET GLOBAL event_scheduler = ON;

CREATE TABLE reporte_ventas_semanales (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    semana_inicio DATE NOT NULL,
    semana_fin DATE NOT NULL,
    total_ventas DECIMAL(14,2) NOT NULL,
    numero_ordenes INT NOT NULL,
    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE reorden_sugerida (
    id_reorden INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    stock_actual INT NOT NULL,
    cantidad_sugerida INT NOT NULL,
    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE kpi_mensual (
    id_kpi INT AUTO_INCREMENT PRIMARY KEY,
    mes VARCHAR(7) NOT NULL,
    total_ventas DECIMAL(14,2) NOT NULL,
    total_clientes_nuevos INT NOT NULL,
    ticket_promedio DECIMAL(12,2) NOT NULL,
    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE tamano_bd_log (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    tamano_mb DECIMAL(12,2) NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE alertas_fraude (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    fecha_deteccion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE respaldo_productos (
    id_producto INT NOT NULL,
    nombre VARCHAR(200),
    precio DECIMAL(10,2),
    stock INT,
    fecha_respaldo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_producto, fecha_respaldo)
) ENGINE=InnoDB;

CREATE TABLE ranking_productos (
    id_producto INT PRIMARY KEY,
    total_vendido INT NOT NULL,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE agregados_ventas_diarias (
    id_agregado INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE NOT NULL,
    total_vendido DECIMAL(14,2) NOT NULL,
    numero_ordenes INT NOT NULL
) ENGINE=InnoDB;

CREATE TABLE reporte_proveedores_mensual (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    id_proveedor INT NOT NULL,
    mes VARCHAR(7) NOT NULL,
    ingresos_generados DECIMAL(14,2) NOT NULL,
    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

DELIMITER //

CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO reporte_ventas_semanales (semana_inicio, semana_fin, total_ventas, numero_ordenes)
    SELECT DATE(NOW() - INTERVAL 7 DAY), DATE(NOW()), COALESCE(SUM(total),0), COUNT(*)
    FROM ventas
    WHERE fecha_venta >= (NOW() - INTERVAL 7 DAY) AND estado <> 'Cancelado';
END //

CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM carrito_items
    WHERE id_carrito IN (SELECT id_carrito FROM carritos WHERE estado = 'Convertido');
END //

CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM log_permisos WHERE fecha_accion < (NOW() - INTERVAL 12 MONTH);
    DELETE FROM logins_fallidos WHERE fecha_intento < (NOW() - INTERVAL 12 MONTH);
END //

CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
DO
BEGIN
    UPDATE promociones
    SET activa = 0
    WHERE fecha_fin < NOW() AND activa = 1;
END //

CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '02:00:00')
DO
BEGIN
    UPDATE clientes
    SET nivel_lealtad = fn_DeterminarEstadoLealtad(total_gastado);
END //

CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO reorden_sugerida (id_producto, stock_actual, cantidad_sugerida)
    SELECT id_producto, stock, GREATEST(50 - stock, 10)
    FROM productos
    WHERE stock <= 15 AND activo = 1;
END //

CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
BEGIN
    ANALYZE TABLE productos, ventas, detalle_ventas, clientes;
END //

CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH STARTS CURRENT_TIMESTAMP
DO
BEGIN
    UPDATE clientes
    SET activo = 0
    WHERE (fecha_ultima_compra IS NULL OR fecha_ultima_compra < (NOW() - INTERVAL 12 MONTH))
      AND fecha_registro < (NOW() - INTERVAL 12 MONTH);
END //

CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '01:00:00')
DO
BEGIN
    INSERT INTO agregados_ventas_diarias (fecha, total_vendido, numero_ordenes)
    SELECT DATE(NOW() - INTERVAL 1 DAY), COALESCE(SUM(total),0), COUNT(*)
    FROM ventas
    WHERE DATE(fecha_venta) = DATE(NOW() - INTERVAL 1 DAY) AND estado <> 'Cancelado';
END //

CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '03:00:00')
DO
BEGIN
    UPDATE ventas v
    SET total = fn_CalcularTotalVenta(v.id_venta)
    WHERE v.total <> fn_CalcularTotalVenta(v.id_venta);
END //

CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO log_permisos (usuario_bd, accion)
    SELECT 'SISTEMA', CONCAT('Saludo de cumpleanos para cliente id ', id_cliente)
    FROM clientes
    WHERE MONTH(fecha_nacimiento) = MONTH(CURDATE()) AND DAY(fecha_nacimiento) = DAY(CURDATE());
END //

CREATE EVENT evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
DO
BEGIN
    REPLACE INTO ranking_productos (id_producto, total_vendido, fecha_actualizacion)
    SELECT id_producto, total_vendido, NOW()
    FROM productos;
END //

CREATE EVENT evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '00:30:00')
DO
BEGIN
    INSERT INTO respaldo_productos (id_producto, nombre, precio, stock)
    SELECT id_producto, nombre, precio, stock FROM productos;
END //

CREATE EVENT evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    UPDATE carritos
    SET estado = 'Abandonado'
    WHERE estado = 'Activo' AND fecha_actualizacion < (NOW() - INTERVAL 3 DAY);
END //

CREATE EVENT evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO kpi_mensual (mes, total_ventas, total_clientes_nuevos, ticket_promedio)
    SELECT DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m'),
        COALESCE((SELECT SUM(total) FROM ventas WHERE DATE_FORMAT(fecha_venta,'%Y-%m') = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m') AND estado <> 'Cancelado'),0),
        COALESCE((SELECT COUNT(*) FROM clientes WHERE DATE_FORMAT(fecha_registro,'%Y-%m') = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m')),0),
        COALESCE((SELECT AVG(total) FROM ventas WHERE DATE_FORMAT(fecha_venta,'%Y-%m') = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m') AND estado <> 'Cancelado'),0);
END //

CREATE EVENT evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '04:00:00')
DO
BEGIN
    REPLACE INTO ranking_productos (id_producto, total_vendido, fecha_actualizacion)
    SELECT id_producto, total_vendido, NOW()
    FROM productos;
END //

CREATE EVENT evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO tamano_bd_log (tamano_mb)
    SELECT COALESCE(SUM(data_length + index_length) / 1024 / 1024, 0)
    FROM information_schema.tables
    WHERE table_schema = 'ecommerce_db';
END //

CREATE EVENT evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO alertas_fraude (id_cliente, motivo)
    SELECT id_cliente, 'Multiples ordenes en menos de una hora'
    FROM ventas
    WHERE fecha_venta >= (NOW() - INTERVAL 1 HOUR)
    GROUP BY id_cliente
    HAVING COUNT(*) >= 5;
END //

CREATE EVENT evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO reporte_proveedores_mensual (id_proveedor, mes, ingresos_generados)
    SELECT pr.id_proveedor, DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m'),
        COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado),0)
    FROM proveedores pr
    LEFT JOIN productos p ON p.id_proveedor = pr.id_proveedor
    LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
    LEFT JOIN ventas v ON v.id_venta = dv.id_venta AND DATE_FORMAT(v.fecha_venta,'%Y-%m') = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m')
    GROUP BY pr.id_proveedor;
END //

CREATE EVENT evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM productos
    WHERE activo = 0 AND fecha_modificacion < (NOW() - INTERVAL 6 MONTH);
END //

DELIMITER ;
