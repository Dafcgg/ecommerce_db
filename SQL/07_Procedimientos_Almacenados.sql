USE ecommerce_db;

DELIMITER //

CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT,
    IN p_id_sucursal INT,
    IN p_id_producto INT,
    IN p_cantidad INT,
    OUT p_id_venta_generada INT
)
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SET v_precio = fn_ObtenerPrecioProducto(p_id_producto);

    INSERT INTO ventas (id_cliente, id_sucursal, estado, total)
    VALUES (p_id_cliente, p_id_sucursal, 'Pendiente de Pago', 0);

    SET p_id_venta_generada = LAST_INSERT_ID();

    INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
    VALUES (p_id_venta_generada, p_id_producto, p_cantidad, v_precio);

    COMMIT;
END //

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
    INSERT INTO productos (id_categoria, id_proveedor, nombre, descripcion, precio, costo, stock, sku)
    VALUES (p_id_categoria, p_id_proveedor, p_nombre, p_descripcion, p_precio, p_costo, p_stock, CONCAT('TEMP-', UUID_SHORT()));

    SET p_id_producto_generado = LAST_INSERT_ID();

    UPDATE productos
    SET sku = fn_GenerarSKU(p_id_categoria, p_id_producto_generado)
    WHERE id_producto = p_id_producto_generado;
END //

CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_id_cliente INT,
    IN p_direccion_envio VARCHAR(255),
    IN p_ciudad VARCHAR(100),
    IN p_pais VARCHAR(100)
)
BEGIN
    UPDATE clientes
    SET direccion_envio = p_direccion_envio,
        ciudad = p_ciudad,
        pais = p_pais
    WHERE id_cliente = p_id_cliente;
END //

CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT,
    IN p_id_producto INT,
    IN p_cantidad INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE productos
    SET stock = stock + p_cantidad,
        total_vendido = total_vendido - p_cantidad
    WHERE id_producto = p_id_producto;

    UPDATE ventas
    SET estado = 'Cancelado'
    WHERE id_venta = p_id_venta;

    COMMIT;
END //

CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(
    IN p_id_cliente INT
)
BEGIN
    SELECT v.id_venta, v.fecha_venta, v.estado, v.total,
        p.nombre AS producto, dv.cantidad, dv.precio_unitario_congelado
    FROM ventas v
    JOIN detalle_ventas dv ON dv.id_venta = v.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC;
END //

CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT,
    IN p_cantidad_ajuste INT,
    IN p_motivo VARCHAR(255)
)
BEGIN
    UPDATE productos
    SET stock = stock + p_cantidad_ajuste
    WHERE id_producto = p_id_producto;

    INSERT INTO log_permisos (usuario_bd, accion)
    VALUES (CURRENT_USER(), CONCAT('Ajuste de stock producto ', p_id_producto, ' cantidad ', p_cantidad_ajuste, ' motivo ', p_motivo));
END //

CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(
    IN p_id_cliente INT
)
BEGIN
    DECLARE v_ventas_activas INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT COUNT(*) INTO v_ventas_activas
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado IN ('Pendiente de Pago','Procesando','Enviado');

    START TRANSACTION;
    IF v_ventas_activas > 0 THEN
        UPDATE clientes SET activo = 0 WHERE id_cliente = p_id_cliente;
    ELSE
        DELETE FROM clientes WHERE id_cliente = p_id_cliente;
    END IF;
    COMMIT;
END //

CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT,
    IN p_porcentaje_descuento DECIMAL(5,2),
    IN p_fecha_inicio DATETIME,
    IN p_fecha_fin DATETIME
)
BEGIN
    INSERT INTO promociones (id_categoria, id_producto, nombre, porcentaje_descuento, fecha_inicio, fecha_fin, activa)
    VALUES (p_id_categoria, NULL, CONCAT('Descuento categoria ', p_id_categoria), p_porcentaje_descuento, p_fecha_inicio, p_fecha_fin, 1);
END //

CREATE PROCEDURE sp_GenerarReporteMensualVentas(
    IN p_anio INT,
    IN p_mes INT
)
BEGIN
    SELECT
        COUNT(*) AS numero_ventas,
        COALESCE(SUM(total),0) AS total_vendido,
        COALESCE(AVG(total),0) AS ticket_promedio
    FROM ventas
    WHERE YEAR(fecha_venta) = p_anio AND MONTH(fecha_venta) = p_mes AND estado <> 'Cancelado';
END //

CREATE PROCEDURE sp_CambiarEstadoPedido(
    IN p_id_venta INT,
    IN p_nuevo_estado VARCHAR(30)
)
BEGIN
    UPDATE ventas
    SET estado = p_nuevo_estado
    WHERE id_venta = p_id_venta;
END //

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
    INSERT INTO clientes (nombre, apellido, email, contrasena_hash, direccion_envio, ciudad, pais, fecha_nacimiento)
    VALUES (p_nombre, p_apellido, p_email, p_contrasena_hash, p_direccion_envio, p_ciudad, p_pais, p_fecha_nacimiento);

    SET p_id_cliente_generado = LAST_INSERT_ID();
END //

CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(
    IN p_id_producto INT
)
BEGIN
    SELECT p.*, c.nombre AS nombre_categoria, pr.nombre AS nombre_proveedor,
        (SELECT AVG(calificacion) FROM resenas_productos r WHERE r.id_producto = p.id_producto) AS calificacion_promedio
    FROM productos p
    LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
    LEFT JOIN proveedores pr ON pr.id_proveedor = p.id_proveedor
    WHERE p.id_producto = p_id_producto;
END //

CREATE PROCEDURE sp_FusionarCuentasCliente(
    IN p_id_cliente_principal INT,
    IN p_id_cliente_secundario INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE ventas
    SET id_cliente = p_id_cliente_principal
    WHERE id_cliente = p_id_cliente_secundario;

    UPDATE clientes principal
    JOIN clientes secundario ON secundario.id_cliente = p_id_cliente_secundario
    SET principal.total_gastado = principal.total_gastado + secundario.total_gastado
    WHERE principal.id_cliente = p_id_cliente_principal;

    DELETE FROM clientes WHERE id_cliente = p_id_cliente_secundario;

    COMMIT;
END //

CREATE PROCEDURE sp_AsignarProductoAProveedor(
    IN p_id_producto INT,
    IN p_id_proveedor INT
)
BEGIN
    UPDATE productos
    SET id_proveedor = p_id_proveedor
    WHERE id_producto = p_id_producto;
END //

CREATE PROCEDURE sp_BuscarProductos(
    IN p_termino_busqueda VARCHAR(200)
)
BEGIN
    SELECT id_producto, nombre, descripcion, precio, stock
    FROM productos
    WHERE activo = 1
      AND (nombre LIKE CONCAT('%', p_termino_busqueda, '%')
           OR descripcion LIKE CONCAT('%', p_termino_busqueda, '%'))
    ORDER BY nombre;
END //

CREATE PROCEDURE sp_ObtenerDashboardAdmin()
BEGIN
    SELECT
        (SELECT COUNT(*) FROM clientes WHERE activo = 1) AS clientes_activos,
        (SELECT COUNT(*) FROM productos WHERE activo = 1) AS productos_activos,
        (SELECT COALESCE(SUM(total),0) FROM ventas WHERE estado <> 'Cancelado') AS ingresos_totales,
        (SELECT COUNT(*) FROM ventas WHERE estado = 'Pendiente de Pago') AS ventas_pendientes,
        (SELECT COUNT(*) FROM productos WHERE stock <= 15) AS productos_stock_bajo;
END //

CREATE PROCEDURE sp_ProcesarPago(
    IN p_id_venta INT,
    IN p_monto_pagado DECIMAL(12,2)
)
BEGIN
    DECLARE v_total DECIMAL(12,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT total INTO v_total FROM ventas WHERE id_venta = p_id_venta;

    START TRANSACTION;
    IF p_monto_pagado >= v_total THEN
        UPDATE ventas SET estado = 'Procesando' WHERE id_venta = p_id_venta;
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto pagado es insuficiente para cubrir el total de la venta';
    END IF;
    COMMIT;
END //

CREATE PROCEDURE `sp_AñadirReseñaProducto`(
    IN p_id_producto INT,
    IN p_id_cliente INT,
    IN p_calificacion TINYINT,
    IN p_comentario TEXT
)
BEGIN
    INSERT INTO resenas_productos (id_producto, id_cliente, calificacion, comentario)
    VALUES (p_id_producto, p_id_cliente, p_calificacion, p_comentario);
END //

CREATE PROCEDURE sp_ObtenerProductosRelacionados(
    IN p_id_producto INT
)
BEGIN
    SELECT p2.id_producto, p2.nombre, p2.precio
    FROM productos p1
    JOIN productos p2 ON p2.id_categoria = p1.id_categoria AND p2.id_producto <> p1.id_producto
    WHERE p1.id_producto = p_id_producto AND p2.activo = 1
    LIMIT 5;
END //

CREATE PROCEDURE sp_MoverProductosEntreCategorias(
    IN p_id_categoria_origen INT,
    IN p_id_categoria_destino INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

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
