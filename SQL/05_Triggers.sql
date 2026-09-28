USE ecommerce_db;

DELIMITER //

CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO log_cambios_precio (id_producto, precio_anterior, precio_nuevo, usuario_bd)
        VALUES (NEW.id_producto, OLD.precio, NEW.precio, CURRENT_USER());
    END IF;
END //

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

CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos
    SET stock = stock - NEW.cantidad,
        total_vendido = total_vendido + NEW.cantidad
    WHERE id_producto = NEW.id_producto;
END //

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

CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO log_permisos (usuario_bd, accion)
    VALUES (CURRENT_USER(), CONCAT('Nuevo cliente registrado: id ', NEW.id_cliente));
END //

CREATE TRIGGER trg_update_total_gastado_cliente
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Entregado' AND OLD.estado <> 'Entregado' THEN
        UPDATE clientes
        SET total_gastado = total_gastado + NEW.total,
            fecha_ultima_compra = NEW.fecha_venta,
            nivel_lealtad = fn_DeterminarEstadoLealtad(total_gastado + NEW.total)
        WHERE id_cliente = NEW.id_cliente;
    END IF;
END //

CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    SET NEW.fecha_modificacion = NOW();
END //

CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El stock no puede ser negativo';
    END IF;
END //

CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    SET NEW.nombre = CONCAT(UPPER(LEFT(TRIM(NEW.nombre),1)), LOWER(SUBSTRING(TRIM(NEW.nombre),2)));
    SET NEW.apellido = CONCAT(UPPER(LEFT(TRIM(NEW.apellido),1)), LOWER(SUBSTRING(TRIM(NEW.apellido),2)));
END //

CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas
    SET total = fn_CalcularTotalVenta(NEW.id_venta)
    WHERE id_venta = NEW.id_venta;
END //

CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO log_permisos (usuario_bd, accion)
        VALUES (CURRENT_USER(), CONCAT('Venta ', NEW.id_venta, ' cambio de estado de ', OLD.estado, ' a ', NEW.estado));
    END IF;
END //

CREATE TRIGGER trg_prevent_price_zero_or_less
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El precio del producto debe ser mayor a cero';
    END IF;
END //

CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock <= 15 AND OLD.stock > 15 THEN
        INSERT INTO log_permisos (usuario_bd, accion)
        VALUES ('SISTEMA', CONCAT('ALERTA stock bajo para producto id ', NEW.id_producto, ' stock actual ', NEW.stock));
    END IF;
END //

CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO ventas_archivadas (id_venta, id_cliente, fecha_venta, estado, total)
    VALUES (OLD.id_venta, OLD.id_cliente, OLD.fecha_venta, OLD.estado, OLD.total);
END //

CREATE TRIGGER trg_validate_email_format_on_customer
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF fn_ValidarFormatoEmail(NEW.email) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El formato del correo electronico no es valido';
    END IF;
END //

CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes
    SET fecha_ultima_compra = NEW.fecha_venta
    WHERE id_cliente = NEW.id_cliente;
END //

CREATE TRIGGER trg_prevent_self_referral
BEFORE UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NEW.referido_por = NEW.id_cliente THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Un cliente no puede referirse a si mismo';
    END IF;
END //

CREATE TRIGGER trg_log_permission_changes
AFTER UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF OLD.activo <> NEW.activo THEN
        INSERT INTO log_permisos (usuario_bd, accion)
        VALUES (CURRENT_USER(), CONCAT('Estado de cuenta del cliente ', NEW.id_cliente, ' cambio a ', NEW.activo));
    END IF;
END //

CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        SET NEW.id_categoria = 1;
    END IF;
END //

CREATE TRIGGER trg_update_producto_count_in_categoria
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias
    SET total_productos = total_productos + 1
    WHERE id_categoria = NEW.id_categoria;
END //

DELIMITER ;
