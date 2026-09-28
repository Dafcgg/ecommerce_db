USE ecommerce_db;

DELIMITER //

CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT COALESCE(SUM(cantidad * precio_unitario_congelado),0) INTO v_total
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;
    RETURN v_total;
END //

CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT, p_cantidad INT)
RETURNS TINYINT(1)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_stock INT;
    SELECT stock INTO v_stock FROM productos WHERE id_producto = p_id_producto;
    IF v_stock IS NULL THEN
        RETURN 0;
    END IF;
    IF v_stock >= p_cantidad THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END //

CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    SELECT precio INTO v_precio FROM productos WHERE id_producto = p_id_producto;
    RETURN v_precio;
END //

CREATE FUNCTION fn_CalcularEdadCliente(p_id_cliente INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_fecha_nac DATE;
    SELECT fecha_nacimiento INTO v_fecha_nac FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_fecha_nac IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN TIMESTAMPDIFF(YEAR, v_fecha_nac, CURDATE());
END //

CREATE FUNCTION fn_FormatearNombreCompleto(p_nombre VARCHAR(100), p_apellido VARCHAR(100))
RETURNS VARCHAR(201)
DETERMINISTIC
NO SQL
BEGIN
    RETURN CONCAT(
        UPPER(LEFT(TRIM(p_nombre),1)), LOWER(SUBSTRING(TRIM(p_nombre),2)), ' ',
        UPPER(LEFT(TRIM(p_apellido),1)), LOWER(SUBSTRING(TRIM(p_apellido),2))
    );
END //

CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT)
RETURNS TINYINT(1)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_fecha_registro DATETIME;
    SELECT fecha_registro INTO v_fecha_registro FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_fecha_registro IS NULL THEN
        RETURN 0;
    END IF;
    IF DATEDIFF(CURDATE(), v_fecha_registro) <= 30 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END //

CREATE FUNCTION fn_CalcularCostoEnvio(p_total_venta DECIMAL(12,2), p_ciudad VARCHAR(100))
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_costo DECIMAL(10,2);
    IF p_total_venta >= 200000 THEN
        RETURN 0;
    END IF;
    IF p_ciudad = 'Medellin' THEN
        SET v_costo = 8000;
    ELSE
        SET v_costo = 15000;
    END IF;
    RETURN v_costo;
END //

CREATE FUNCTION fn_AplicarDescuento(p_precio DECIMAL(10,2), p_porcentaje DECIMAL(5,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    RETURN ROUND(p_precio - (p_precio * (p_porcentaje / 100)), 2);
END //

CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT)
RETURNS DATETIME
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_fecha DATETIME;
    SELECT MAX(fecha_venta) INTO v_fecha FROM ventas WHERE id_cliente = p_id_cliente AND estado <> 'Cancelado';
    RETURN v_fecha;
END //

CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(150))
RETURNS TINYINT(1)
DETERMINISTIC
NO SQL
BEGIN
    IF p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END //

CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT)
RETURNS VARCHAR(100)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_nombre VARCHAR(100);
    SELECT c.nombre INTO v_nombre
    FROM productos p
    JOIN categorias c ON c.id_categoria = p.id_categoria
    WHERE p.id_producto = p_id_producto;
    RETURN v_nombre;
END //

CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_conteo INT;
    SELECT COUNT(*) INTO v_conteo FROM ventas WHERE id_cliente = p_id_cliente AND estado <> 'Cancelado';
    RETURN v_conteo;
END //

CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_fecha DATETIME;
    SET v_fecha = fn_ObtenerUltimaFechaCompra(p_id_cliente);
    IF v_fecha IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN DATEDIFF(CURDATE(), v_fecha);
END //

CREATE FUNCTION fn_DeterminarEstadoLealtad(p_total_gastado DECIMAL(12,2))
RETURNS VARCHAR(30)
DETERMINISTIC
NO SQL
BEGIN
    IF p_total_gastado >= 1000000 THEN
        RETURN 'Platino';
    ELSEIF p_total_gastado >= 500000 THEN
        RETURN 'Oro';
    ELSEIF p_total_gastado >= 100000 THEN
        RETURN 'Plata';
    ELSE
        RETURN 'Bronce';
    END IF;
END //

CREATE FUNCTION fn_GenerarSKU(p_id_categoria INT, p_id_producto INT)
RETURNS VARCHAR(50)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_prefijo VARCHAR(10);
    SELECT UPPER(LEFT(nombre,3)) INTO v_prefijo FROM categorias WHERE id_categoria = p_id_categoria;
    IF v_prefijo IS NULL THEN
        SET v_prefijo = 'GEN';
    END IF;
    RETURN CONCAT('SKU-', v_prefijo, '-', LPAD(p_id_producto, 4, '0'));
END //

CREATE FUNCTION fn_CalcularIVA(p_monto DECIMAL(12,2))
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    RETURN ROUND(p_monto * 0.19, 2);
END //

CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_stock INT;
    SELECT COALESCE(SUM(stock),0) INTO v_stock FROM productos WHERE id_categoria = p_id_categoria;
    RETURN v_stock;
END //

CREATE FUNCTION fn_EstimarFechaEntrega(p_fecha_venta DATETIME, p_ciudad VARCHAR(100))
RETURNS DATE
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_dias INT;
    IF p_ciudad = 'Medellin' THEN
        SET v_dias = 2;
    ELSE
        SET v_dias = 5;
    END IF;
    RETURN DATE_ADD(p_fecha_venta, INTERVAL v_dias DAY);
END //

CREATE FUNCTION fn_ConvertirMoneda(p_monto DECIMAL(12,2), p_tasa_cambio DECIMAL(10,4))
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    RETURN ROUND(p_monto * p_tasa_cambio, 2);
END //

CREATE FUNCTION fn_ValidarComplejidadContrasena(p_contrasena VARCHAR(255))
RETURNS TINYINT(1)
DETERMINISTIC
NO SQL
BEGIN
    IF LENGTH(p_contrasena) >= 8
        AND p_contrasena REGEXP '[A-Z]'
        AND p_contrasena REGEXP '[a-z]'
        AND p_contrasena REGEXP '[0-9]'
        AND p_contrasena REGEXP '[^A-Za-z0-9]' THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END //

DELIMITER ;
