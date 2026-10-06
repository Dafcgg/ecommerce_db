-- =============================================================================
-- PROYECTO: Base de Datos de un E-commerce
-- ARCHIVO : 02_Consultas_Avanzadas.sql
-- DESCRIPCIÓN: Consultas analíticas avanzadas para inteligencia de negocio.
-- MOTOR   : MySQL 8.0+
-- =============================================================================

USE ecommerce_db;

-- -----------------------------------------------------------------------------
-- CONSULTA 01: Top 10 productos con mayores ingresos generados
-- -----------------------------------------------------------------------------
SELECT 
    p.id_producto,
    p.nombre AS producto,
    COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado), 0) AS ingresos_totales,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas
FROM detalle_ventas dv
JOIN ventas v ON v.id_venta = dv.id_venta
JOIN productos p ON p.id_producto = dv.id_producto
WHERE v.estado <> 'Cancelado'
GROUP BY p.id_producto, p.nombre
ORDER BY ingresos_totales DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- CONSULTA 02: 10% de productos con menor rotación de ventas
-- -----------------------------------------------------------------------------
WITH ventas_por_producto AS (
    SELECT 
        dv.id_producto,
        SUM(dv.cantidad) AS unidades_vendidas
    FROM detalle_ventas dv
    JOIN ventas v ON v.id_venta = dv.id_venta
    WHERE v.estado <> 'Cancelado'
    GROUP BY dv.id_producto
),
ranking_bajas_ventas AS (
    SELECT 
        p.id_producto,
        p.nombre,
        COALESCE(vp.unidades_vendidas, 0) AS unidades_vendidas,
        ROW_NUMBER() OVER (ORDER BY COALESCE(vp.unidades_vendidas, 0) ASC, p.id_producto ASC) AS posicion,
        COUNT(*) OVER () AS total_productos
    FROM productos p
    LEFT JOIN ventas_por_producto vp ON vp.id_producto = p.id_producto
    WHERE p.activo = 1
)
SELECT 
    id_producto,
    nombre,
    unidades_vendidas,
    posicion,
    total_productos
FROM ranking_bajas_ventas
WHERE posicion <= GREATEST(1, CEIL(total_productos * 0.10));

-- -----------------------------------------------------------------------------
-- CONSULTA 03: Top 10 clientes con mayor valor de vida (Customer Lifetime Value)
-- -----------------------------------------------------------------------------
SELECT 
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.email,
    c.nivel_lealtad,
    COALESCE(SUM(v.total), 0) AS valor_vida_cliente,
    COUNT(v.id_venta) AS total_pedidos
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
WHERE v.estado <> 'Cancelado'
GROUP BY c.id_cliente, c.nombre, c.apellido, c.email, c.nivel_lealtad
ORDER BY valor_vida_cliente DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- CONSULTA 04: Tendencia histórica mensual de ventas e ingresos
-- -----------------------------------------------------------------------------
SELECT 
    DATE_FORMAT(fecha_venta, '%Y-%m') AS mes,
    COUNT(*) AS numero_ventas,
    COALESCE(SUM(total), 0) AS total_ventas,
    ROUND(COALESCE(AVG(total), 0), 2) AS ticket_promedio
FROM ventas
WHERE estado <> 'Cancelado'
GROUP BY DATE_FORMAT(fecha_venta, '%Y-%m')
ORDER BY mes ASC;

-- -----------------------------------------------------------------------------
-- CONSULTA 05: Adquisición de nuevos clientes por trimestre
-- -----------------------------------------------------------------------------
SELECT 
    CONCAT(YEAR(fecha_registro), '-Q', QUARTER(fecha_registro)) AS trimestre,
    COUNT(*) AS nuevos_clientes
FROM clientes
GROUP BY YEAR(fecha_registro), QUARTER(fecha_registro)
ORDER BY YEAR(fecha_registro) ASC, QUARTER(fecha_registro) ASC;

-- -----------------------------------------------------------------------------
-- CONSULTA 06: Tasa de recompra de clientes (Repeat Purchase Rate)
-- -----------------------------------------------------------------------------
SELECT 
    COUNT(*) AS total_clientes_compradores,
    SUM(CASE WHEN total_compras > 1 THEN 1 ELSE 0 END) AS clientes_recurrentes,
    ROUND(100.0 * SUM(CASE WHEN total_compras > 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS tasa_recompra_porcentaje
FROM (
    SELECT 
        id_cliente, 
        COUNT(*) AS total_compras
    FROM ventas
    WHERE estado <> 'Cancelado'
    GROUP BY id_cliente
) sub;

-- -----------------------------------------------------------------------------
-- CONSULTA 07: Afinidad de productos (Cross-selling / Market Basket)
-- -----------------------------------------------------------------------------
SELECT 
    a.id_producto AS id_producto_a,
    pa.nombre AS producto_a,
    b.id_producto AS id_producto_b,
    pb.nombre AS producto_b,
    COUNT(*) AS veces_comprados_juntos
FROM detalle_ventas a
JOIN detalle_ventas b ON a.id_venta = b.id_venta AND a.id_producto < b.id_producto
JOIN ventas v ON v.id_venta = a.id_venta
JOIN productos pa ON pa.id_producto = a.id_producto
JOIN productos pb ON pb.id_producto = b.id_producto
WHERE v.estado <> 'Cancelado'
GROUP BY a.id_producto, pa.nombre, b.id_producto, pb.nombre
ORDER BY veces_comprados_juntos DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- CONSULTA 08: Índice de rotación de inventario por categoría
-- -----------------------------------------------------------------------------
WITH stock_por_categoria AS (
    SELECT 
        id_categoria,
        COALESCE(SUM(stock), 0) AS stock_actual
    FROM productos
    GROUP BY id_categoria
),
ventas_por_categoria AS (
    SELECT 
        p.id_categoria,
        COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas
    FROM detalle_ventas dv
    JOIN ventas v ON v.id_venta = dv.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    WHERE v.estado <> 'Cancelado'
    GROUP BY p.id_categoria
)
SELECT 
    cat.id_categoria,
    cat.nombre AS categoria,
    COALESCE(v.unidades_vendidas, 0) AS unidades_vendidas,
    COALESCE(s.stock_actual, 0) AS stock_actual,
    ROUND(COALESCE(v.unidades_vendidas, 0) / NULLIF(s.stock_actual, 0), 2) AS indice_rotacion
FROM categorias cat
LEFT JOIN stock_por_categoria s ON s.id_categoria = cat.id_categoria
LEFT JOIN ventas_por_categoria v ON v.id_categoria = cat.id_categoria
ORDER BY indice_rotacion DESC;

-- -----------------------------------------------------------------------------
-- CONSULTA 09: Monitoreo de productos con stock crítico (<= 15 unidades)
-- -----------------------------------------------------------------------------
SELECT 
    p.id_producto,
    p.sku,
    p.nombre,
    c.nombre AS categoria,
    p.stock,
    p.precio
FROM productos p
LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
WHERE p.stock <= 15 AND p.activo = 1
ORDER BY p.stock ASC;

-- -----------------------------------------------------------------------------
-- CONSULTA 10: Carritos de compra abandonados (> 3 días de inactividad)
-- -----------------------------------------------------------------------------
SELECT 
    ca.id_carrito,
    ca.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.email,
    ca.fecha_actualizacion,
    COUNT(ci.id_item) AS items_en_carrito,
    COALESCE(SUM(ci.cantidad * p.precio), 0) AS valor_estimado_carrito
FROM carritos ca
JOIN clientes c ON c.id_cliente = ca.id_cliente
JOIN carrito_items ci ON ci.id_carrito = ca.id_carrito
JOIN productos p ON p.id_producto = ci.id_producto
WHERE ca.estado IN ('Activo', 'Abandonado')
  AND ca.fecha_actualizacion < (NOW() - INTERVAL 3 DAY)
GROUP BY ca.id_carrito, ca.id_cliente, c.nombre, c.apellido, c.email, ca.fecha_actualizacion
ORDER BY ca.fecha_actualizacion ASC;

-- -----------------------------------------------------------------------------
-- CONSULTA 11: Desempeño y volumen de facturación por proveedor
-- -----------------------------------------------------------------------------
SELECT 
    pr.id_proveedor,
    pr.nombre AS proveedor,
    pr.email_contacto,
    COUNT(DISTINCT p.id_producto) AS productos_suministrados,
    COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado), 0) AS ingresos_generados
FROM proveedores pr
LEFT JOIN productos p ON p.id_proveedor = pr.id_proveedor
LEFT JOIN (
    detalle_ventas dv 
    JOIN ventas v ON v.id_venta = dv.id_venta AND v.estado <> 'Cancelado'
) ON dv.id_producto = p.id_producto
GROUP BY pr.id_proveedor, pr.nombre, pr.email_contacto
ORDER BY ingresos_generados DESC;

-- -----------------------------------------------------------------------------
-- CONSULTA 12: Distribución geográfica de ventas por ciudad y país
-- -----------------------------------------------------------------------------
SELECT 
    COALESCE(c.ciudad, 'No especificada') AS ciudad,
    COALESCE(c.pais, 'No especificado') AS pais,
    COUNT(DISTINCT v.id_venta) AS numero_ventas,
    COALESCE(SUM(v.total), 0) AS total_vendido,
    ROUND(COALESCE(AVG(v.total), 0), 2) AS promedio_por_venta
FROM ventas v
JOIN clientes c ON c.id_cliente = v.id_cliente
WHERE v.estado <> 'Cancelado'
GROUP BY c.ciudad, c.pais
ORDER BY total_vendido DESC;

-- -----------------------------------------------------------------------------
-- CONSULTA 13: Distribución horaria de compras (Horas pico)
-- -----------------------------------------------------------------------------
SELECT 
    HOUR(fecha_venta) AS hora_del_dia,
    COUNT(*) AS numero_ventas,
    COALESCE(SUM(total), 0) AS total_vendido
FROM ventas
WHERE estado <> 'Cancelado'
GROUP BY HOUR(fecha_venta)
ORDER BY hora_del_dia ASC;

-- -----------------------------------------------------------------------------
-- CONSULTA 14: Efectividad e ingresos generados durante promociones activas
-- -----------------------------------------------------------------------------
SELECT 
    pm.id_promocion,
    pm.nombre AS promocion,
    pm.porcentaje_descuento,
    pm.fecha_inicio,
    pm.fecha_fin,
    COUNT(DISTINCT v.id_venta) AS ventas_durante_promocion,
    COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado), 0) AS ingresos_durante_promocion
FROM promociones pm
LEFT JOIN productos p ON (p.id_producto = pm.id_producto OR (pm.id_producto IS NULL AND p.id_categoria = pm.id_categoria))
LEFT JOIN (
    detalle_ventas dv 
    JOIN ventas v ON v.id_venta = dv.id_venta AND v.estado <> 'Cancelado'
) ON dv.id_producto = p.id_producto AND v.fecha_venta BETWEEN pm.fecha_inicio AND pm.fecha_fin
GROUP BY pm.id_promocion, pm.nombre, pm.porcentaje_descuento, pm.fecha_inicio, pm.fecha_fin
ORDER BY ingresos_durante_promocion DESC;

-- -----------------------------------------------------------------------------
-- CONSULTA 15: Análisis de cohortes (Retención mensual de clientes)
-- -----------------------------------------------------------------------------
SELECT 
    DATE_FORMAT(c.fecha_registro, '%Y-%m') AS cohorte_registro,
    DATE_FORMAT(v.fecha_venta, '%Y-%m') AS mes_actividad,
    COUNT(DISTINCT v.id_cliente) AS clientes_activos,
    COALESCE(SUM(v.total), 0) AS ingresos_cohorte
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
WHERE v.estado <> 'Cancelado'
GROUP BY cohorte_registro, mes_actividad
ORDER BY cohorte_registro ASC, mes_actividad ASC;

-- -----------------------------------------------------------------------------
-- CONSULTA 16: Margen de rentabilidad bruta por producto
-- -----------------------------------------------------------------------------
SELECT 
    p.id_producto,
    p.nombre,
    p.costo,
    p.precio,
    (p.precio - p.costo) AS margen_bruto_valor,
    ROUND(((p.precio - p.costo) / p.precio) * 100, 2) AS margen_bruto_porcentaje
FROM productos p
WHERE p.activo = 1
ORDER BY margen_bruto_porcentaje DESC;

-- -----------------------------------------------------------------------------
-- CONSULTA 17: Promedio de días transcurridos entre compras por cliente
-- -----------------------------------------------------------------------------
SELECT 
    sub.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    ROUND(AVG(sub.dias_entre_compras), 1) AS promedio_dias_entre_compras,
    COUNT(*) + 1 AS total_compras_evaluadas
FROM (
    SELECT 
        id_cliente, 
        fecha_venta,
        DATEDIFF(fecha_venta, LAG(fecha_venta) OVER (PARTITION BY id_cliente ORDER BY fecha_venta)) AS dias_entre_compras
    FROM ventas
    WHERE estado <> 'Cancelado'
) sub
JOIN clientes c ON c.id_cliente = sub.id_cliente
WHERE sub.dias_entre_compras IS NOT NULL
GROUP BY sub.id_cliente, c.nombre, c.apellido
ORDER BY promedio_dias_entre_compras ASC;

-- -----------------------------------------------------------------------------
-- CONSULTA 18: Tasa de conversión de vistas a compras por producto
-- -----------------------------------------------------------------------------
WITH vistas_agg AS (
    SELECT 
        id_producto, 
        COUNT(*) AS total_vistas
    FROM vistas_productos
    GROUP BY id_producto
),
ventas_agg AS (
    SELECT 
        dv.id_producto, 
        COALESCE(SUM(dv.cantidad), 0) AS total_comprado
    FROM detalle_ventas dv
    JOIN ventas v ON v.id_venta = dv.id_venta
    WHERE v.estado <> 'Cancelado'
    GROUP BY dv.id_producto
)
SELECT 
    p.id_producto,
    p.nombre AS producto,
    COALESCE(va.total_vistas, 0) AS total_vistas,
    COALESCE(ve.total_comprado, 0) AS total_comprado,
    ROUND(COALESCE(ve.total_comprado, 0) / NULLIF(COALESCE(va.total_vistas, 0), 0), 4) AS tasa_conversion
FROM productos p
LEFT JOIN vistas_agg va ON va.id_producto = p.id_producto
LEFT JOIN ventas_agg ve ON ve.id_producto = p.id_producto
WHERE p.activo = 1
ORDER BY total_vistas DESC, total_comprado DESC;

-- -----------------------------------------------------------------------------
-- CONSULTA 19: Segmentación RFM (Recencia, Frecuencia y Valor Monetario)
-- -----------------------------------------------------------------------------
SELECT 
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.nivel_lealtad,
    DATEDIFF(CURDATE(), MAX(v.fecha_venta)) AS recencia_dias,
    COUNT(v.id_venta) AS frecuencia,
    COALESCE(SUM(v.total), 0) AS valor_monetario
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
WHERE v.estado <> 'Cancelado'
GROUP BY c.id_cliente, c.nombre, c.apellido, c.nivel_lealtad
ORDER BY valor_monetario DESC;

-- -----------------------------------------------------------------------------
-- CONSULTA 20: Estimación de velocidad de ventas y demanda mensual (Run-rate)
-- -----------------------------------------------------------------------------
SELECT 
    p.id_producto,
    p.nombre AS producto,
    p.stock AS stock_actual,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas_historicas,
    ROUND(
        COALESCE(SUM(dv.cantidad), 0) / 
        GREATEST(1, TIMESTAMPDIFF(MONTH, MIN(v.fecha_venta), CURDATE())), 
        2
    ) AS demanda_mensual_estimada
FROM productos p
LEFT JOIN (
    detalle_ventas dv
    JOIN ventas v ON v.id_venta = dv.id_venta AND v.estado <> 'Cancelado'
) ON dv.id_producto = p.id_producto
WHERE p.activo = 1
GROUP BY p.id_producto, p.nombre, p.stock
ORDER BY demanda_mensual_estimada DESC;
