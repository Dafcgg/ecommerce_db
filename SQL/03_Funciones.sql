-- =============================================================================
-- PROYECTO: Base de Datos de un E-commerce
-- ARCHIVO : 03_Funciones.sql
-- DESCRIPCIÓN: Funciones almacenadas definidas por el usuario (UDF).
-- MOTOR   : MySQL 8.0+
-- =============================================================================

USE ecommerce_db;

DELIMITER //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 01: fn_CalcularTotalVenta
-- Calcula el total acumulado de una orden a partir de su detalle.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularTotalVenta //
CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT COALESCE(SUM(cantidad * precio_unitario_congelado), 0.00) INTO v_total
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;
    RETURN COALESCE(v_total, 0.00);
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 02: fn_VerificarDisponibilidadStock
-- Verifica si un producto tiene inventario suficiente para una cantidad dada.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_VerificarDisponibilidadStock //
CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT, p_cantidad INT)
RETURNS TINYINT(1)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_stock INT;
    IF p_cantidad <= 0 THEN
        RETURN 0;
    END IF;
    SELECT stock INTO v_stock FROM productos WHERE id_producto = p_id_producto AND activo = 1;
    IF v_stock IS NULL OR v_stock < p_cantidad THEN
        RETURN 0;
    ELSE
        RETURN 1;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 03: fn_ObtenerPrecioProducto
-- Obtiene el precio vigente de catálogo de un producto.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerPrecioProducto //
CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    SELECT precio INTO v_precio FROM productos WHERE id_producto = p_id_producto;
    RETURN COALESCE(v_precio, 0.00);
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 04: fn_CalcularEdadCliente
-- Calcula la edad cronológica en años del cliente según su fecha de nacimiento.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularEdadCliente //
CREATE FUNCTION fn_CalcularEdadCliente(p_id_cliente INT)
RETURNS INT
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_fecha_nac DATE;
    SELECT fecha_nacimiento INTO v_fecha_nac FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_fecha_nac IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN TIMESTAMPDIFF(YEAR, v_fecha_nac, CURDATE());
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 05: fn_FormatearNombreCompleto
-- Normaliza y concatena nombre y apellido con iniciales en mayúscula.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_FormatearNombreCompleto //
CREATE FUNCTION fn_FormatearNombreCompleto(p_nombre VARCHAR(100), p_apellido VARCHAR(100))
RETURNS VARCHAR(201)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_nom VARCHAR(100);
    DECLARE v_ape VARCHAR(100);
    IF p_nombre IS NULL AND p_apellido IS NULL THEN
        RETURN '';
    END IF;
    SET v_nom = TRIM(COALESCE(p_nombre, ''));
    SET v_ape = TRIM(COALESCE(p_apellido, ''));
    
    RETURN TRIM(CONCAT(
        IF(LENGTH(v_nom) > 0, CONCAT(UPPER(LEFT(v_nom, 1)), LOWER(SUBSTRING(v_nom, 2))), ''),
        ' ',
        IF(LENGTH(v_ape) > 0, CONCAT(UPPER(LEFT(v_ape, 1)), LOWER(SUBSTRING(v_ape, 2))), '')
    ));
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 06: fn_EsClienteNuevo
-- Retorna 1 si el cliente se registró en los últimos 30 días, 0 en caso contrario.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_EsClienteNuevo //
CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT)
RETURNS TINYINT(1)
READS SQL DATA
NOT DETERMINISTIC
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

-- -----------------------------------------------------------------------------
-- FUNCIÓN 07: fn_CalcularCostoEnvio
-- Calcula flete según monto de compra (envío gratis >= 200,000) y destino.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularCostoEnvio //
CREATE FUNCTION fn_CalcularCostoEnvio(p_total_venta DECIMAL(12,2), p_ciudad VARCHAR(100))
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_total_venta IS NULL OR p_total_venta < 0 THEN
        SET p_total_venta = 0.00;
    END IF;
    IF p_total_venta >= 200000.00 THEN
        RETURN 0.00;
    END IF;
    IF LOWER(TRIM(COALESCE(p_ciudad, ''))) = 'medellin' THEN
        RETURN 8000.00;
    ELSE
        RETURN 15000.00;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 08: fn_AplicarDescuento
-- Calcula el precio final aplicando un porcentaje de descuento válido.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_AplicarDescuento //
CREATE FUNCTION fn_AplicarDescuento(p_precio DECIMAL(10,2), p_porcentaje DECIMAL(5,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_precio IS NULL OR p_precio < 0 THEN
        RETURN 0.00;
    END IF;
    IF p_porcentaje IS NULL OR p_porcentaje <= 0 THEN
        RETURN p_precio;
    END IF;
    IF p_porcentaje >= 100 THEN
        RETURN 0.00;
    END IF;
    RETURN ROUND(p_precio - (p_precio * (p_porcentaje / 100.00)), 2);
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 09: fn_ObtenerUltimaFechaCompra
-- Retorna la fecha del último pedido no cancelado del cliente.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerUltimaFechaCompra //
CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT)
RETURNS DATETIME
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_fecha DATETIME;
    SELECT MAX(fecha_venta) INTO v_fecha 
    FROM ventas 
    WHERE id_cliente = p_id_cliente AND estado <> 'Cancelado';
    RETURN v_fecha;
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 10: fn_ValidarFormatoEmail
-- Valida sintaxis estándar de correo electrónico mediante expresiones regulares.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ValidarFormatoEmail //
CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(150))
RETURNS TINYINT(1)
DETERMINISTIC
NO SQL
BEGIN
    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        RETURN 0;
    END IF;
    IF p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 11: fn_ObtenerNombreCategoria
-- Obtiene el nombre de la categoría a la que pertenece un producto.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerNombreCategoria //
CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT)
RETURNS VARCHAR(100)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_nombre VARCHAR(100);
    SELECT c.nombre INTO v_nombre
    FROM productos p
    JOIN categorias c ON c.id_categoria = p.id_categoria
    WHERE p.id_producto = p_id_producto;
    RETURN COALESCE(v_nombre, 'Sin Categoria');
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 12: fn_ContarVentasCliente
-- Cuenta la cantidad de compras no canceladas realizadas por un cliente.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ContarVentasCliente //
CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT)
RETURNS INT
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_conteo INT;
    SELECT COUNT(*) INTO v_conteo 
    FROM ventas 
    WHERE id_cliente = p_id_cliente AND estado <> 'Cancelado';
    RETURN COALESCE(v_conteo, 0);
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 13: fn_CalcularDiasDesdeUltimaCompra
-- Calcula el número de días de inactividad transcurridos desde la última compra.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularDiasDesdeUltimaCompra //
CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT)
RETURNS INT
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_fecha DATETIME;
    SET v_fecha = fn_ObtenerUltimaFechaCompra(p_id_cliente);
    IF v_fecha IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN DATEDIFF(CURDATE(), v_fecha);
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 14: fn_DeterminarEstadoLealtad
-- Clasifica el rango de fidelización según el volumen histórico de gasto.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_DeterminarEstadoLealtad //
CREATE FUNCTION fn_DeterminarEstadoLealtad(p_total_gastado DECIMAL(12,2))
RETURNS VARCHAR(30)
DETERMINISTIC
NO SQL
BEGIN
    IF p_total_gastado IS NULL OR p_total_gastado < 0 THEN
        RETURN 'Bronce';
    ELSEIF p_total_gastado >= 1000000.00 THEN
        RETURN 'Platino';
    ELSEIF p_total_gastado >= 500000.00 THEN
        RETURN 'Oro';
    ELSEIF p_total_gastado >= 100000.00 THEN
        RETURN 'Plata';
    ELSE
        RETURN 'Bronce';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 15: fn_GenerarSKU
-- Genera un SKU estandarizado basado en categoría y código autoincrementable.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_GenerarSKU //
CREATE FUNCTION fn_GenerarSKU(p_id_categoria INT, p_id_producto INT)
RETURNS VARCHAR(50)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_prefijo VARCHAR(10);
    SELECT UPPER(LEFT(nombre, 3)) INTO v_prefijo 
    FROM categorias 
    WHERE id_categoria = p_id_categoria;
    
    IF v_prefijo IS NULL OR LENGTH(v_prefijo) < 3 THEN
        SET v_prefijo = 'GEN';
    END IF;
    RETURN CONCAT('SKU-', v_prefijo, '-', LPAD(COALESCE(p_id_producto, 0), 4, '0'));
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 16: fn_CalcularIVA
-- Calcula el valor correspondiente al impuesto al valor agregado (IVA 19%).
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularIVA //
CREATE FUNCTION fn_CalcularIVA(p_monto DECIMAL(12,2))
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_monto IS NULL OR p_monto < 0 THEN
        RETURN 0.00;
    END IF;
    RETURN ROUND(p_monto * 0.19, 2);
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 17: fn_ObtenerStockTotalPorCategoria
-- Totaliza el inventario físico disponible en una categoría específica.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerStockTotalPorCategoria //
CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT)
RETURNS INT
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_stock INT;
    SELECT COALESCE(SUM(stock), 0) INTO v_stock 
    FROM productos 
    WHERE id_categoria = p_id_categoria AND activo = 1;
    RETURN COALESCE(v_stock, 0);
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 18: fn_EstimarFechaEntrega
-- Calcula fecha estimada de entrega basada en días hábiles y destino.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_EstimarFechaEntrega //
CREATE FUNCTION fn_EstimarFechaEntrega(p_fecha_venta DATETIME, p_ciudad VARCHAR(100))
RETURNS DATE
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_dias INT;
    IF p_fecha_venta IS NULL THEN
        SET p_fecha_venta = CURRENT_TIMESTAMP;
    END IF;
    IF LOWER(TRIM(COALESCE(p_ciudad, ''))) = 'medellin' THEN
        SET v_dias = 2;
    ELSE
        SET v_dias = 5;
    END IF;
    RETURN DATE(DATE_ADD(p_fecha_venta, INTERVAL v_dias DAY));
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 19: fn_ConvertirMoneda
-- Realiza conversión de moneda multiplicando por una tasa de cambio provista.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ConvertirMoneda //
CREATE FUNCTION fn_ConvertirMoneda(p_monto DECIMAL(12,2), p_tasa_cambio DECIMAL(10,4))
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_monto IS NULL OR p_tasa_cambio IS NULL OR p_monto < 0 OR p_tasa_cambio < 0 THEN
        RETURN 0.00;
    END IF;
    RETURN ROUND(p_monto * p_tasa_cambio, 2);
END //

-- -----------------------------------------------------------------------------
-- FUNCIÓN 20: fn_ValidarComplejidadContrasena
-- Valida políticas de robustez: longitud >= 8, mayúscula, minúscula, dígito y símbolo.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ValidarComplejidadContrasena //
CREATE FUNCTION fn_ValidarComplejidadContrasena(p_contrasena VARCHAR(255))
RETURNS TINYINT(1)
DETERMINISTIC
NO SQL
BEGIN
    IF p_contrasena IS NULL OR LENGTH(p_contrasena) < 8 THEN
        RETURN 0;
    END IF;
    -- REGEXP_LIKE con 'c' (case-sensitive): con una colacion *_ci, REGEXP a secas
    -- ignora mayusculas/minusculas y '[A-Z]' aceptaria tambien letras minusculas.
    IF REGEXP_LIKE(p_contrasena, '[A-Z]', 'c')
       AND REGEXP_LIKE(p_contrasena, '[a-z]', 'c')
       AND REGEXP_LIKE(p_contrasena, '[0-9]', 'c')
       AND REGEXP_LIKE(p_contrasena, '[^A-Za-z0-9]', 'c') THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END //

DELIMITER ;
