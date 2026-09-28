USE ecommerce_db;

SELECT p.id_producto, p.nombre, SUM(dv.cantidad * dv.precio_unitario_congelado) AS ingresos_totales
FROM detalle_ventas dv
JOIN productos p ON p.id_producto = dv.id_producto
GROUP BY p.id_producto, p.nombre
ORDER BY ingresos_totales DESC
LIMIT 10;

WITH ranking_bajas_ventas AS (
    SELECT p.id_producto, p.nombre, COALESCE(SUM(dv.cantidad),0) AS unidades_vendidas,
        ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(dv.cantidad),0) ASC) AS posicion,
        COUNT(*) OVER () AS total_productos
    FROM productos p
    LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
    GROUP BY p.id_producto, p.nombre
)
SELECT id_producto, nombre, unidades_vendidas
FROM ranking_bajas_ventas
WHERE posicion <= GREATEST(1, CEIL(total_productos * 0.10));

SELECT c.id_cliente, CONCAT(c.nombre,' ',c.apellido) AS cliente, SUM(v.total) AS valor_vida_cliente
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
WHERE v.estado <> 'Cancelado'
GROUP BY c.id_cliente, cliente
ORDER BY valor_vida_cliente DESC
LIMIT 10;

SELECT DATE_FORMAT(fecha_venta,'%Y-%m') AS mes, SUM(total) AS total_ventas, COUNT(*) AS numero_ventas
FROM ventas
WHERE estado <> 'Cancelado'
GROUP BY DATE_FORMAT(fecha_venta,'%Y-%m')
ORDER BY mes;

SELECT CONCAT(ANY_VALUE(YEAR(fecha_registro)),'-Q',ANY_VALUE(QUARTER(fecha_registro))) AS trimestre, COUNT(*) AS nuevos_clientes
FROM clientes
GROUP BY YEAR(fecha_registro), QUARTER(fecha_registro)
ORDER BY YEAR(fecha_registro), QUARTER(fecha_registro);

SELECT
    ROUND(100.0 * SUM(CASE WHEN total_compras > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS tasa_recompra_porcentaje
FROM (
    SELECT id_cliente, COUNT(*) AS total_compras
    FROM ventas
    WHERE estado <> 'Cancelado'
    GROUP BY id_cliente
) sub;

SELECT a.id_producto AS producto_a, b.id_producto AS producto_b, COUNT(*) AS veces_juntos
FROM detalle_ventas a
JOIN detalle_ventas b ON a.id_venta = b.id_venta AND a.id_producto < b.id_producto
GROUP BY a.id_producto, b.id_producto
ORDER BY veces_juntos DESC
LIMIT 10;

SELECT cat.id_categoria, cat.nombre, COALESCE(SUM(dv.cantidad),0) AS unidades_vendidas, SUM(p.stock) AS stock_actual,
    ROUND(COALESCE(SUM(dv.cantidad),0) / NULLIF(SUM(p.stock),0), 2) AS indice_rotacion
FROM categorias cat
LEFT JOIN productos p ON p.id_categoria = cat.id_categoria
LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
GROUP BY cat.id_categoria, cat.nombre;

SELECT id_producto, nombre, stock
FROM productos
WHERE stock <= 15 AND activo = 1
ORDER BY stock ASC;

SELECT ca.id_carrito, ca.id_cliente, ca.fecha_actualizacion, COUNT(ci.id_item) AS items_en_carrito
FROM carritos ca
JOIN carrito_items ci ON ci.id_carrito = ca.id_carrito
WHERE ca.estado = 'Activo' AND ca.fecha_actualizacion < (NOW() - INTERVAL 3 DAY)
GROUP BY ca.id_carrito, ca.id_cliente, ca.fecha_actualizacion;

SELECT pr.id_proveedor, pr.nombre, COUNT(DISTINCT p.id_producto) AS productos_suministrados,
    COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado),0) AS ingresos_generados
FROM proveedores pr
LEFT JOIN productos p ON p.id_proveedor = pr.id_proveedor
LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
GROUP BY pr.id_proveedor, pr.nombre
ORDER BY ingresos_generados DESC;

SELECT c.ciudad, c.pais, COUNT(DISTINCT v.id_venta) AS numero_ventas, SUM(v.total) AS total_vendido
FROM ventas v
JOIN clientes c ON c.id_cliente = v.id_cliente
WHERE v.estado <> 'Cancelado'
GROUP BY c.ciudad, c.pais
ORDER BY total_vendido DESC;

SELECT HOUR(fecha_venta) AS hora_del_dia, COUNT(*) AS numero_ventas, SUM(total) AS total_vendido
FROM ventas
GROUP BY HOUR(fecha_venta)
ORDER BY hora_del_dia;

SELECT pm.id_promocion, pm.nombre, COUNT(dv.id_detalle) AS ventas_durante_promocion,
    COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado),0) AS ingresos_durante_promocion
FROM promociones pm
LEFT JOIN productos p ON p.id_producto = pm.id_producto OR p.id_categoria = pm.id_categoria
LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
LEFT JOIN ventas v ON v.id_venta = dv.id_venta AND v.fecha_venta BETWEEN pm.fecha_inicio AND pm.fecha_fin
GROUP BY pm.id_promocion, pm.nombre;

SELECT DATE_FORMAT(c.fecha_registro,'%Y-%m') AS cohorte,
    DATE_FORMAT(v.fecha_venta,'%Y-%m') AS mes_actividad,
    COUNT(DISTINCT v.id_cliente) AS clientes_activos
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
GROUP BY cohorte, mes_actividad
ORDER BY cohorte, mes_actividad;

SELECT p.id_producto, p.nombre,
    ROUND(((p.precio - p.costo) / p.precio) * 100, 2) AS margen_porcentaje,
    (p.precio - p.costo) AS margen_valor
FROM productos p
ORDER BY margen_porcentaje DESC;

SELECT id_cliente, AVG(dias_entre_compras) AS promedio_dias_entre_compras
FROM (
    SELECT id_cliente, fecha_venta,
        DATEDIFF(fecha_venta, LAG(fecha_venta) OVER (PARTITION BY id_cliente ORDER BY fecha_venta)) AS dias_entre_compras
    FROM ventas
    WHERE estado <> 'Cancelado'
) sub
WHERE dias_entre_compras IS NOT NULL
GROUP BY id_cliente;

SELECT p.id_producto, p.nombre,
    COUNT(DISTINCT vp.id_vista) AS total_vistas,
    COALESCE(SUM(dv.cantidad),0) AS total_comprado,
    ROUND(COALESCE(SUM(dv.cantidad),0) / NULLIF(COUNT(DISTINCT vp.id_vista),0), 4) AS tasa_conversion
FROM productos p
LEFT JOIN vistas_productos vp ON vp.id_producto = p.id_producto
LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
GROUP BY p.id_producto, p.nombre
ORDER BY total_vistas DESC;

SELECT c.id_cliente, CONCAT(c.nombre,' ',c.apellido) AS cliente,
    DATEDIFF(CURDATE(), MAX(v.fecha_venta)) AS recencia_dias,
    COUNT(v.id_venta) AS frecuencia,
    SUM(v.total) AS valor_monetario
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
WHERE v.estado <> 'Cancelado'
GROUP BY c.id_cliente, cliente
ORDER BY valor_monetario DESC;

SELECT p.id_producto, p.nombre,
    ROUND(COALESCE(SUM(dv.cantidad),0) / GREATEST(1, TIMESTAMPDIFF(MONTH, MIN(v.fecha_venta), CURDATE())), 2) AS demanda_mensual_estimada
FROM productos p
LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
LEFT JOIN ventas v ON v.id_venta = dv.id_venta
GROUP BY p.id_producto, p.nombre
ORDER BY demanda_mensual_estimada DESC;
