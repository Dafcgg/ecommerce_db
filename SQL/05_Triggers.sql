-- =============================================================================
-- PROYECTO: Base de Datos de un E-commerce
-- ARCHIVO : 05_Triggers.sql
-- DESCRIPCIÓN: Triggers de integridad, consistencia y auditoría operativa.
-- MOTOR   : MySQL 8.0+
-- =============================================================================

USE ecommerce_db;

DELIMITER //

-- -----------------------------------------------------------------------------
-- TRIGGER 01: trg_audit_precio_producto_after_update
-- Registra en log_cambios_precio cualquier ajuste en el catálogo de precios.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_precio_producto_after_update //
CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO log_cambios_precio (id_producto, precio_anterior, precio_nuevo, usuario_bd)
        VALUES (NEW.id_producto, OLD.precio, NEW.precio, CURRENT_USER());
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 02: trg_check_stock_before_insert_venta
-- Bloquea la inserción de detalles de venta si el stock físico es insuficiente.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_check_stock_before_insert_venta //
CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    SELECT stock INTO v_stock FROM productos WHERE id_producto = NEW.id_producto;
    IF v_stock IS NULL OR v_stock < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuficiente para completar la venta';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 03: trg_update_stock_after_insert_venta
-- Descuenta el inventario físico y suma al acumulador histórico de ventas.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_stock_after_insert_venta //
CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos
    SET stock = stock - NEW.cantidad,
        total_vendido = total_vendido + NEW.cantidad
    WHERE id_producto = NEW.id_producto;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 04: trg_prevent_delete_categoria_with_products
-- Regla de integridad que impide eliminar categorías que contengan productos.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_delete_categoria_with_products //
CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    DECLARE v_cuenta INT;
    SELECT COUNT(*) INTO v_cuenta FROM productos WHERE id_categoria = OLD.id_categoria;
    IF v_cuenta > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede eliminar una categoria con productos asociados';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 05: trg_log_new_customer_after_insert
-- Auditoría de creación de cuentas de clientes.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert //
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO log_permisos (usuario_bd, accion)
    VALUES (CURRENT_USER(), CONCAT('Nuevo cliente registrado: id ', NEW.id_cliente, ' email ', NEW.email));
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 06: trg_update_total_gastado_cliente
-- Actualiza total gastado y nivel de lealtad en entregas y cancelaciones.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_total_gastado_cliente //
CREATE TRIGGER trg_update_total_gastado_cliente
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    DECLARE v_nuevo_total DECIMAL(12,2);
    
    IF NEW.estado = 'Entregado' AND OLD.estado <> 'Entregado' THEN
        SELECT (total_gastado + NEW.total) INTO v_nuevo_total 
        FROM clientes 
        WHERE id_cliente = NEW.id_cliente;

        UPDATE clientes
        SET total_gastado = v_nuevo_total,
            fecha_ultima_compra = NEW.fecha_venta,
            nivel_lealtad = fn_DeterminarEstadoLealtad(v_nuevo_total)
        WHERE id_cliente = NEW.id_cliente;

    ELSEIF OLD.estado = 'Entregado' AND NEW.estado = 'Cancelado' THEN
        SELECT GREATEST(0.00, total_gastado - OLD.total) INTO v_nuevo_total 
        FROM clientes 
        WHERE id_cliente = NEW.id_cliente;

        UPDATE clientes
        SET total_gastado = v_nuevo_total,
            nivel_lealtad = fn_DeterminarEstadoLealtad(v_nuevo_total)
        WHERE id_cliente = NEW.id_cliente;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 07: trg_set_fecha_modificacion_producto
-- Estampa de tiempo automática en actualización de catálogo de productos.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_set_fecha_modificacion_producto //
CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    SET NEW.fecha_modificacion = NOW();
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 08: trg_prevent_negative_stock
-- Salvaguarda contra inventario físico negativo.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_negative_stock //
CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El stock no puede ser negativo';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 09: trg_capitalize_nombre_cliente
-- Normalización de nombres de clientes al momento de inserción.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_capitalize_nombre_cliente //
CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    DECLARE v_nom VARCHAR(100);
    DECLARE v_ape VARCHAR(100);
    SET v_nom = TRIM(COALESCE(NEW.nombre, ''));
    SET v_ape = TRIM(COALESCE(NEW.apellido, ''));
    IF LENGTH(v_nom) > 0 THEN
        SET NEW.nombre = CONCAT(UPPER(LEFT(v_nom, 1)), LOWER(SUBSTRING(v_nom, 2)));
    END IF;
    IF LENGTH(v_ape) > 0 THEN
        SET NEW.apellido = CONCAT(UPPER(LEFT(v_ape, 1)), LOWER(SUBSTRING(v_ape, 2)));
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 10: trg_recalculate_total_venta_on_detalle_change
-- Mantiene sincronizado el total monetario de la orden tras agregar ítems.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_recalculate_total_venta_on_detalle_change //
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas
    SET total = fn_CalcularTotalVenta(NEW.id_venta)
    WHERE id_venta = NEW.id_venta;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 11: trg_recalculate_total_venta_on_detalle_delete
-- Recalcula el total de la orden si se remueve un ítem.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_recalculate_total_venta_on_detalle_delete //
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_delete
AFTER DELETE ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas
    SET total = fn_CalcularTotalVenta(OLD.id_venta)
    WHERE id_venta = OLD.id_venta;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 12: trg_log_order_status_change
-- Registro de auditoría en cambios de estado de órdenes de compra.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_log_order_status_change //
CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO log_permisos (usuario_bd, accion)
        VALUES (CURRENT_USER(), CONCAT('Venta ', NEW.id_venta, ' cambio de estado de ', OLD.estado, ' a ', NEW.estado));
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 13: trg_prevent_price_zero_or_less
-- Validación de regla comercial: precios positivos en catálogo.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less //
CREATE TRIGGER trg_prevent_price_zero_or_less
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El precio del producto debe ser mayor a cero';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 14: trg_send_stock_alert_on_low_stock
-- Alerta generada al cruzar el umbral crítico de stock (<= 15 unidades).
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock //
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock <= 15 AND OLD.stock > 15 THEN
        INSERT INTO log_permisos (usuario_bd, accion)
        VALUES ('SISTEMA', CONCAT('ALERTA stock bajo para producto id ', NEW.id_producto, ' (', NEW.nombre, '). Stock actual: ', NEW.stock));
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 15: trg_archive_deleted_venta
-- Archivo histórico automático antes de cualquier eliminación en ventas.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_archive_deleted_venta //
CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO ventas_archivadas (id_venta, id_cliente, fecha_venta, estado, total)
    VALUES (OLD.id_venta, OLD.id_cliente, OLD.fecha_venta, OLD.estado, OLD.total);
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 16: trg_validate_email_format_on_customer
-- Validación de formato estándar de correo electrónico en clientes.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer //
CREATE TRIGGER trg_validate_email_format_on_customer
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF fn_ValidarFormatoEmail(NEW.email) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El formato del correo electronico no es valido';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 17: trg_update_last_order_date_customer
-- Actualiza la fecha de última compra en la ficha del cliente.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_last_order_date_customer //
CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes
    SET fecha_ultima_compra = NEW.fecha_venta
    WHERE id_cliente = NEW.id_cliente;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 18: trg_prevent_self_referral
-- Impide que un cliente sea su propio referente comercial.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_self_referral //
CREATE TRIGGER trg_prevent_self_referral
BEFORE UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NEW.referido_por IS NOT NULL AND NEW.referido_por = NEW.id_cliente THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Un cliente no puede referirse a si mismo';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 19: trg_assign_default_category_on_null
-- Asigna la categoría por defecto si se omite en la creación del producto.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_assign_default_category_on_null //
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        SET NEW.id_categoria = 1;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 20: trg_update_producto_count_in_categoria
-- Mantiene actualizado el contador total_productos en categorias al insertar.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_producto_count_in_categoria //
CREATE TRIGGER trg_update_producto_count_in_categoria
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias
    SET total_productos = total_productos + 1
    WHERE id_categoria = NEW.id_categoria;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 21: trg_update_producto_count_on_delete
-- Decrementa total_productos en categorias al retirar un producto.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_producto_count_on_delete //
CREATE TRIGGER trg_update_producto_count_on_delete
AFTER DELETE ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias
    SET total_productos = GREATEST(0, total_productos - 1)
    WHERE id_categoria = OLD.id_categoria;
END //

DELIMITER ;
