-- =============================================================================
-- PROYECTO: Base de Datos de un E-commerce
-- ARCHIVO : 07_Procedimientos_Almacenados.sql
-- DESCRIPCIÓN: Procedimientos almacenados para lógica de negocio y transacciones.
-- MOTOR   : MySQL 8.0+
-- =============================================================================

USE ecommerce_db;

DELIMITER //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 01: sp_RealizarNuevaVenta
-- Ejecuta una orden transaccional completa verificando stock y cliente activo.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_RealizarNuevaVenta //
CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT,
    IN p_id_sucursal INT,
    IN p_id_producto INT,
    IN p_cantidad INT,
    OUT p_id_venta_generada INT
)
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_cliente_activo TINYINT(1);
    DECLARE v_stock_disponible TINYINT(1);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cantidad comprada debe ser mayor a cero';
    END IF;

    -- Validar estado del cliente
    SELECT activo INTO v_cliente_activo FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_cliente_activo IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El cliente especificado no existe';
    ELSEIF v_cliente_activo = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El cliente se encuentra inactivo o suspendido';
    END IF;

    -- Validar disponibilidad de stock
    SET v_stock_disponible = fn_VerificarDisponibilidadStock(p_id_producto, p_cantidad);
    IF v_stock_disponible = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Inventario insuficiente para el producto seleccionado';
    END IF;

    SET v_precio = fn_ObtenerPrecioProducto(p_id_producto);

    START TRANSACTION;

    INSERT INTO ventas (id_cliente, id_sucursal, estado, total)
    VALUES (p_id_cliente, p_id_sucursal, 'Pendiente de Pago', 0.00);

    SET p_id_venta_generada = LAST_INSERT_ID();

    INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
    VALUES (p_id_venta_generada, p_id_producto, p_cantidad, v_precio);

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 02: sp_AgregarNuevoProducto
-- Da de alta un producto y genera automáticamente su SKU estandarizado.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_AgregarNuevoProducto //
CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_id_categoria INT,
    IN p_id_proveedor INT,
    IN p_nombre VARCHAR(200),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(10,2),
    IN p_costo DECIMAL(10,2),
    IN p_stock INT,
    OUT p_id_producto_generado INT
)
BEGIN
    DECLARE v_sku_temp VARCHAR(50);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El precio debe ser un valor positivo';
    END IF;

    IF p_costo < 0 OR p_stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El costo y el stock no pueden ser valores negativos';
    END IF;

    SET v_sku_temp = CONCAT('TEMP-', UUID_SHORT());

    START TRANSACTION;

    INSERT INTO productos (id_categoria, id_proveedor, nombre, descripcion, precio, costo, stock, sku)
    VALUES (p_id_categoria, p_id_proveedor, p_nombre, p_descripcion, p_precio, p_costo, p_stock, v_sku_temp);

    SET p_id_producto_generado = LAST_INSERT_ID();

    UPDATE productos
    SET sku = fn_GenerarSKU(p_id_categoria, p_id_producto_generado)
    WHERE id_producto = p_id_producto_generado;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 03: sp_ActualizarDireccionCliente
-- Actualiza la dirección y datos de envío de un cliente registrado.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ActualizarDireccionCliente //
CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_id_cliente INT,
    IN p_direccion_envio VARCHAR(255),
    IN p_ciudad VARCHAR(100),
    IN p_pais VARCHAR(100)
)
BEGIN
    DECLARE v_existe INT;
    SELECT COUNT(*) INTO v_existe FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El cliente especificado no existe';
    END IF;

    UPDATE clientes
    SET direccion_envio = p_direccion_envio,
        ciudad = p_ciudad,
        pais = p_pais
    WHERE id_cliente = p_id_cliente;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 04: sp_ProcesarDevolucion
-- Procesa la devolución física de mercancía y reconcilia inventario y estados.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ProcesarDevolucion //
CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT,
    IN p_id_producto INT,
    IN p_cantidad INT
)
BEGIN
    DECLARE v_cantidad_comprada INT;
    DECLARE v_estado_venta VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cantidad a devolver debe ser mayor a cero';
    END IF;

    SELECT estado INTO v_estado_venta FROM ventas WHERE id_venta = p_id_venta;
    IF v_estado_venta IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La orden de venta especificada no existe';
    END IF;

    SELECT cantidad INTO v_cantidad_comprada
    FROM detalle_ventas
    WHERE id_venta = p_id_venta AND id_producto = p_id_producto;

    IF v_cantidad_comprada IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El producto no pertenece a la orden especificada';
    ELSEIF p_cantidad > v_cantidad_comprada THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cantidad devuelta supera la cantidad comprada en la orden';
    END IF;

    START TRANSACTION;

    UPDATE productos
    SET stock = stock + p_cantidad,
        total_vendido = GREATEST(0, total_vendido - p_cantidad)
    WHERE id_producto = p_id_producto;

    IF p_cantidad = v_cantidad_comprada THEN
        UPDATE ventas
        SET estado = 'Cancelado'
        WHERE id_venta = p_id_venta;
    END IF;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 05: sp_ObtenerHistorialComprasCliente
-- Retorna el histórico detallado de compras realizadas por un cliente.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ObtenerHistorialComprasCliente //
CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(
    IN p_id_cliente INT
)
BEGIN
    SELECT 
        v.id_venta, 
        v.fecha_venta, 
        v.estado, 
        v.total,
        p.id_producto,
        p.nombre AS producto, 
        dv.cantidad, 
        dv.precio_unitario_congelado,
        (dv.cantidad * dv.precio_unitario_congelado) AS subtotal
    FROM ventas v
    JOIN detalle_ventas dv ON dv.id_venta = v.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC, v.id_venta DESC;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 06: sp_AjustarNivelStock
-- Registra ajustes de inventario con trazabilidad y auditoría obligatoria.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_AjustarNivelStock //
CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT,
    IN p_cantidad_ajuste INT,
    IN p_motivo VARCHAR(255)
)
BEGIN
    DECLARE v_stock_actual INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT stock INTO v_stock_actual FROM productos WHERE id_producto = p_id_producto;
    IF v_stock_actual IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El producto a ajustar no existe';
    END IF;

    IF (v_stock_actual + p_cantidad_ajuste) < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El ajuste solicitado resulta en un stock negativo';
    END IF;

    START TRANSACTION;

    UPDATE productos
    SET stock = stock + p_cantidad_ajuste
    WHERE id_producto = p_id_producto;

    INSERT INTO log_permisos (usuario_bd, accion)
    VALUES (
        CURRENT_USER(), 
        CONCAT('Ajuste de inventario producto id ', p_id_producto, ': ', p_cantidad_ajuste, ' unidades. Motivo: ', p_motivo)
    );

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 07: sp_EliminarClienteDeFormaSegura
-- Borrado lógico y anonimización si tiene ventas asociadas; borrado físico si no.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_EliminarClienteDeFormaSegura //
CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(
    IN p_id_cliente INT
)
BEGIN
    DECLARE v_total_ventas INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT COUNT(*) INTO v_total_ventas
    FROM ventas
    WHERE id_cliente = p_id_cliente;

    START TRANSACTION;

    IF v_total_ventas > 0 THEN
        UPDATE clientes 
        SET activo = 0,
            nombre = 'CLIENTE',
            apellido = 'ANONIMIZADO',
            direccion_envio = 'DIRECCION_ELIMINADA',
            contrasena_hash = '[CUENTA_CERRADA]'
        WHERE id_cliente = p_id_cliente;

        INSERT INTO log_permisos (usuario_bd, accion)
        VALUES (CURRENT_USER(), CONCAT('Cliente id ', p_id_cliente, ' desactivado y anonimizado por presencia de historial transaccional'));
    ELSE
        DELETE FROM clientes WHERE id_cliente = p_id_cliente;

        INSERT INTO log_permisos (usuario_bd, accion)
        VALUES (CURRENT_USER(), CONCAT('Cliente id ', p_id_cliente, ' eliminado fisicamente (sin ventas asociadas)'));
    END IF;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 08: sp_AplicarDescuentoPorCategoria
-- Crea una campaña promocional para todos los productos de una categoría.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_AplicarDescuentoPorCategoria //
CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT,
    IN p_porcentaje_descuento DECIMAL(5,2),
    IN p_fecha_inicio DATETIME,
    IN p_fecha_fin DATETIME
)
BEGIN
    DECLARE v_cat_existe INT;

    IF p_porcentaje_descuento <= 0 OR p_porcentaje_descuento > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El porcentaje de descuento debe ubicarse entre 0.01 y 100';
    END IF;

    IF p_fecha_fin <= p_fecha_inicio THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La fecha de fin debe ser posterior a la fecha de inicio';
    END IF;

    SELECT COUNT(*) INTO v_cat_existe FROM categorias WHERE id_categoria = p_id_categoria;
    IF v_cat_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La categoria ingresada no existe';
    END IF;

    INSERT INTO promociones (id_categoria, id_producto, nombre, porcentaje_descuento, fecha_inicio, fecha_fin, activa)
    VALUES (p_id_categoria, NULL, CONCAT('Descuento Categoria ', p_id_categoria), p_porcentaje_descuento, p_fecha_inicio, p_fecha_fin, 1);
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 09: sp_GenerarReporteMensualVentas
-- Genera el resumen consolidado de ventas de un periodo (año y mes).
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_GenerarReporteMensualVentas //
CREATE PROCEDURE sp_GenerarReporteMensualVentas(
    IN p_anio INT,
    IN p_mes INT
)
BEGIN
    SELECT
        p_anio AS anio,
        p_mes AS mes,
        COUNT(*) AS numero_ventas,
        COALESCE(SUM(total), 0.00) AS total_vendido,
        ROUND(COALESCE(AVG(total), 0.00), 2) AS ticket_promedio
    FROM ventas
    WHERE YEAR(fecha_venta) = p_anio 
      AND MONTH(fecha_venta) = p_mes 
      AND estado <> 'Cancelado';
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 10: sp_CambiarEstadoPedido
-- Valida y transiciona el estado operativo de una orden.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_CambiarEstadoPedido //
CREATE PROCEDURE sp_CambiarEstadoPedido(
    IN p_id_venta INT,
    IN p_nuevo_estado VARCHAR(30)
)
BEGIN
    DECLARE v_existe INT;

    IF p_nuevo_estado NOT IN ('Pendiente de Pago','Procesando','Enviado','Entregado','Cancelado') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Estado no valido para la orden de compra';
    END IF;

    SELECT COUNT(*) INTO v_existe FROM ventas WHERE id_venta = p_id_venta;
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La orden especificada no existe';
    END IF;

    UPDATE ventas
    SET estado = p_nuevo_estado
    WHERE id_venta = p_id_venta;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 11: sp_RegistrarNuevoCliente
-- Da de alta a un cliente validando estructura de correo electrónico.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_RegistrarNuevoCliente //
CREATE PROCEDURE sp_RegistrarNuevoCliente(
    IN p_nombre VARCHAR(100),
    IN p_apellido VARCHAR(100),
    IN p_email VARCHAR(150),
    IN p_contrasena_hash VARCHAR(255),
    IN p_direccion_envio VARCHAR(255),
    IN p_ciudad VARCHAR(100),
    IN p_pais VARCHAR(100),
    IN p_fecha_nacimiento DATE,
    OUT p_id_cliente_generado INT
)
BEGIN
    IF fn_ValidarFormatoEmail(p_email) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El formato del correo electronico es invalido';
    END IF;

    INSERT INTO clientes (
        nombre, apellido, email, contrasena_hash, 
        direccion_envio, ciudad, pais, fecha_nacimiento
    )
    VALUES (
        p_nombre, p_apellido, p_email, p_contrasena_hash, 
        p_direccion_envio, p_ciudad, p_pais, p_fecha_nacimiento
    );

    SET p_id_cliente_generado = LAST_INSERT_ID();
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 12: sp_ObtenerDetallesProductoCompleto
-- Retorna información comercial completa, categorización y calificación promedio.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ObtenerDetallesProductoCompleto //
CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(
    IN p_id_producto INT
)
BEGIN
    SELECT 
        p.id_producto,
        p.sku,
        p.nombre,
        p.descripcion,
        p.precio,
        p.costo,
        p.stock,
        p.activo,
        p.total_vendido,
        p.total_vistas,
        c.nombre AS nombre_categoria, 
        pr.nombre AS nombre_proveedor,
        ROUND(COALESCE((SELECT AVG(calificacion) FROM resenas_productos r WHERE r.id_producto = p.id_producto), 0.0), 1) AS calificacion_promedio,
        (SELECT COUNT(*) FROM resenas_productos r WHERE r.id_producto = p.id_producto) AS total_resenas
    FROM productos p
    LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
    LEFT JOIN proveedores pr ON pr.id_proveedor = p.id_proveedor
    WHERE p.id_producto = p_id_producto;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 13: sp_FusionarCuentasCliente
-- Reasigna ventas, reseñas y carritos al cliente principal antes de eliminar la cuenta.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_FusionarCuentasCliente //
CREATE PROCEDURE sp_FusionarCuentasCliente(
    IN p_id_cliente_principal INT,
    IN p_id_cliente_secundario INT
)
BEGIN
    DECLARE v_gasto_secundario DECIMAL(12,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_id_cliente_principal = p_id_cliente_secundario THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No es posible fusionar un cliente consigo mismo';
    END IF;

    SELECT total_gastado INTO v_gasto_secundario 
    FROM clientes 
    WHERE id_cliente = p_id_cliente_secundario;

    IF v_gasto_secundario IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta secundaria no existe';
    END IF;

    START TRANSACTION;

    UPDATE ventas
    SET id_cliente = p_id_cliente_principal
    WHERE id_cliente = p_id_cliente_secundario;

    UPDATE IGNORE resenas_productos
    SET id_cliente = p_id_cliente_principal
    WHERE id_cliente = p_id_cliente_secundario;

    UPDATE vistas_productos
    SET id_cliente = p_id_cliente_principal
    WHERE id_cliente = p_id_cliente_secundario;

    UPDATE carritos
    SET id_cliente = p_id_cliente_principal
    WHERE id_cliente = p_id_cliente_secundario;

    UPDATE clientes
    SET referido_por = p_id_cliente_principal
    WHERE referido_por = p_id_cliente_secundario;

    UPDATE clientes
    SET total_gastado = total_gastado + v_gasto_secundario,
        nivel_lealtad = fn_DeterminarEstadoLealtad(total_gastado + v_gasto_secundario)
    WHERE id_cliente = p_id_cliente_principal;

    DELETE FROM clientes WHERE id_cliente = p_id_cliente_secundario;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 14: sp_AsignarProductoAProveedor
-- Asocia un producto a un proveedor registrado.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_AsignarProductoAProveedor //
CREATE PROCEDURE sp_AsignarProductoAProveedor(
    IN p_id_producto INT,
    IN p_id_proveedor INT
)
BEGIN
    DECLARE v_prod INT;
    DECLARE v_prov INT;

    SELECT COUNT(*) INTO v_prod FROM productos WHERE id_producto = p_id_producto;
    SELECT COUNT(*) INTO v_prov FROM proveedores WHERE id_proveedor = p_id_proveedor;

    IF v_prod = 0 OR v_prov = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El producto o el proveedor especificado no existe';
    END IF;

    UPDATE productos
    SET id_proveedor = p_id_proveedor
    WHERE id_producto = p_id_producto;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 15: sp_BuscarProductos
-- Búsqueda de texto en catálogo sobre nombres o descripciones.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_BuscarProductos //
CREATE PROCEDURE sp_BuscarProductos(
    IN p_termino_busqueda VARCHAR(200)
)
BEGIN
    SELECT 
        p.id_producto, 
        p.sku, 
        p.nombre, 
        c.nombre AS categoria,
        p.descripcion, 
        p.precio, 
        p.stock
    FROM productos p
    LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
    WHERE p.activo = 1
      AND (p.nombre LIKE CONCAT('%', TRIM(p_termino_busqueda), '%')
           OR p.descripcion LIKE CONCAT('%', TRIM(p_termino_busqueda), '%'))
    ORDER BY p.nombre ASC;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 16: sp_ObtenerDashboardAdmin
-- Retorna las métricas ejecutivas clave para el panel administrativo.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ObtenerDashboardAdmin //
CREATE PROCEDURE sp_ObtenerDashboardAdmin()
BEGIN
    SELECT
        (SELECT COUNT(*) FROM clientes WHERE activo = 1) AS clientes_activos,
        (SELECT COUNT(*) FROM productos WHERE activo = 1) AS productos_activos,
        (SELECT COALESCE(SUM(total), 0.00) FROM ventas WHERE estado <> 'Cancelado') AS ingresos_totales,
        (SELECT COUNT(*) FROM ventas WHERE estado = 'Pendiente de Pago') AS ventas_pendientes,
        (SELECT COUNT(*) FROM productos WHERE stock <= 15 AND activo = 1) AS productos_stock_bajo;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 17: sp_ProcesarPago
-- Valida el monto liquidado y avanza el pedido a estado 'Procesando'.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ProcesarPago //
CREATE PROCEDURE sp_ProcesarPago(
    IN p_id_venta INT,
    IN p_monto_pagado DECIMAL(12,2)
)
BEGIN
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_estado VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT total, estado INTO v_total, v_estado 
    FROM ventas 
    WHERE id_venta = p_id_venta;

    IF v_total IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La orden especificada no existe';
    END IF;

    IF v_estado <> 'Pendiente de Pago' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La orden no se encuentra en estado Pendiente de Pago';
    END IF;

    IF p_monto_pagado < v_total THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto pagado es insuficiente para cubrir el total de la venta';
    END IF;

    START TRANSACTION;

    UPDATE ventas 
    SET estado = 'Procesando' 
    WHERE id_venta = p_id_venta;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 18: sp_AnadirResenaProducto
-- Inserta o actualiza la reseña y calificación de un producto por cliente.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_AnadirResenaProducto //
CREATE PROCEDURE sp_AnadirResenaProducto(
    IN p_id_producto INT,
    IN p_id_cliente INT,
    IN p_calificacion TINYINT,
    IN p_comentario TEXT
)
BEGIN
    IF p_calificacion < 1 OR p_calificacion > 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La calificacion debe encontrarse en el rango de 1 a 5';
    END IF;

    INSERT INTO resenas_productos (id_producto, id_cliente, calificacion, comentario)
    VALUES (p_id_producto, p_id_cliente, p_calificacion, p_comentario)
    ON DUPLICATE KEY UPDATE 
        calificacion = VALUES(calificacion),
        comentario = VALUES(comentario),
        fecha_resena = CURRENT_TIMESTAMP;
END //

-- Compatibilidad con identificador previo
DROP PROCEDURE IF EXISTS `sp_AñadirReseñaProducto` //
CREATE PROCEDURE `sp_AñadirReseñaProducto`(
    IN p_id_producto INT,
    IN p_id_cliente INT,
    IN p_calificacion TINYINT,
    IN p_comentario TEXT
)
BEGIN
    CALL sp_AnadirResenaProducto(p_id_producto, p_id_cliente, p_calificacion, p_comentario);
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 19: sp_ObtenerProductosRelacionados
-- Retorna sugerencias de productos de la misma categoría.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ObtenerProductosRelacionados //
CREATE PROCEDURE sp_ObtenerProductosRelacionados(
    IN p_id_producto INT
)
BEGIN
    SELECT 
        p2.id_producto, 
        p2.sku, 
        p2.nombre, 
        p2.precio, 
        p2.stock
    FROM productos p1
    JOIN productos p2 ON p2.id_categoria = p1.id_categoria AND p2.id_producto <> p1.id_producto
    WHERE p1.id_producto = p_id_producto AND p2.activo = 1
    ORDER BY p2.total_vendido DESC
    LIMIT 5;
END //

-- -----------------------------------------------------------------------------
-- PROCEDIMIENTO 20: sp_MoverProductosEntreCategorias
-- Migra masivamente productos entre categorías y recalcula ambos contadores.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_MoverProductosEntreCategorias //
CREATE PROCEDURE sp_MoverProductosEntreCategorias(
    IN p_id_categoria_origen INT,
    IN p_id_categoria_destino INT
)
BEGIN
    DECLARE v_orig INT;
    DECLARE v_dest INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT COUNT(*) INTO v_orig FROM categorias WHERE id_categoria = p_id_categoria_origen;
    SELECT COUNT(*) INTO v_dest FROM categorias WHERE id_categoria = p_id_categoria_destino;

    IF v_orig = 0 OR v_dest = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Alguna de las categorias ingresadas no existe';
    END IF;

    START TRANSACTION;

    UPDATE productos
    SET id_categoria = p_id_categoria_destino
    WHERE id_categoria = p_id_categoria_origen;

    UPDATE categorias
    SET total_productos = (SELECT COUNT(*) FROM productos WHERE id_categoria = p_id_categoria_destino)
    WHERE id_categoria = p_id_categoria_destino;

    UPDATE categorias
    SET total_productos = (SELECT COUNT(*) FROM productos WHERE id_categoria = p_id_categoria_origen)
    WHERE id_categoria = p_id_categoria_origen;

    COMMIT;
END //

DELIMITER ;
