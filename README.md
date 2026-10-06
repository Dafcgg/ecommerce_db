# Base de Datos de un E-commerce — MySQL 8.0

Sistema integral de base de datos relacional para una plataforma de comercio electrónico de nivel empresarial, diseñado e implementado sobre **MySQL 8.0+**. El sistema implementa un modelo de datos normalizado (3FN), consultas analíticas avanzadas para inteligencia de negocio, funciones almacenadas personalizadas (UDF), control de acceso y seguridad basada en roles (RBAC), integridad y auditoría continua mediante triggers, automatización de tareas y mantenimiento preventivo mediante eventos programados (`Event Scheduler`), y lógica operativa encapsulada en procedimientos almacenados con control transaccional estricto (ACID).

---

## 1. Estructura del Proyecto

El repositorio organiza el ciclo de vida y los objetos de la base de datos de manera modular e independiente dentro del directorio `SQL/`:

```
ecommerce_db/
├── README.md
└── SQL/
    ├── 01_Esquema_y_Datos.sql
    ├── 02_Consultas_Avanzadas.sql
    ├── 03_Funciones.sql
    ├── 04_Seguridad.sql
    ├── 05_Triggers.sql
    ├── 06_Eventos.sql
    ├── 07_Procedimientos_Almacenados.sql
    └── 08_Auditoria_Clientes.sql
```

---

## 2. Modelo de Datos

El diseño de datos separa los flujos transaccionales centrales de los mecanismos de soporte, auditoría y análisis de desempeño:

### Entidades Principales
- **`clientes`**: Información personal, perfil de contacto, nivel de lealtad (`Bronce`, `Plata`, `Oro`, `Platino`), gasto histórico acumulado y estado de cuenta.
- **`productos`**: Catálogo comercial de artículos, referencias de inventario (SKU), precios de venta, costos de adquisición, stock disponible y contadores de rendimiento.
- **`categorias`**: Estructura de clasificación jerárquica de artículos con contadores desnormalizados de productos activos.
- **`proveedores`**: Directorio de fabricantes y distribuidores de mercancía con canales de contacto.
- **`ventas`**: Encabezado de órdenes de compra con control de estado (`Pendiente de Pago`, `Procesando`, `Enviado`, `Entregado`, `Cancelado`), marca de tiempo y monto total consolidado.
- **`detalle_ventas`**: Renglones específicos de cada orden, registrando la cantidad adquirida y congelando el precio unitario pactado al momento de la venta.

### Entidades de Soporte y Auditoría
- **`Auditoria_Clientes`**: Bitácora inmutable de modificaciones en campos sensibles de clientes (`email`, `direccion_envio`), registrando valores previos, valores nuevos y estampas de tiempo.
- **`sucursales`**: Puntos físicos de distribución y despacho regional.
- **`promociones`**: Reglas comerciales de descuento porcentual asociadas a categorías o productos específicos con vigencia temporal.
- **`resenas_productos`**: Evaluaciones de satisfacción (calificación de 1 a 5 y comentarios) otorgadas por clientes verificados.
- **`vistas_productos`**: Registro cronológico de impresiones e interés de navegación en el catálogo.
- **`carritos`** y **`carrito_items`**: Persistencia de sesiones de compra pendientes de checkout y detección de abandono.
- **`log_cambios_precio`**: Trazabilidad histórica de modificaciones en los precios de catálogo de productos.
- **`log_permisos`**: Registro de operaciones administrativas, alertas de inventario y acciones de seguridad.
- **`logins_fallidos`**: Detección de intentos de acceso fallidos al sistema.
- **`ventas_archivadas`**: Repositorio de resguardo histórico para órdenes depuradas o dadas de baja.
- **Tablas analíticas de eventos**: `reporte_ventas_semanales`, `reorden_sugerida`, `kpi_mensual`, `tamano_bd_log`, `alertas_fraude`, `respaldo_productos`, `ranking_productos`, `agregados_ventas_diarias` y `reporte_proveedores_mensual`.

### Relaciones Cardinales de Integridad
- **Categorías 1:N Productos**: Llave foránea `fk_producto_categoria` (`ON DELETE SET NULL ON UPDATE CASCADE`).
- **Proveedores 1:N Productos**: Llave foránea `fk_producto_proveedor` (`ON DELETE SET NULL ON UPDATE CASCADE`).
- **Clientes 1:N Ventas**: Llave foránea `fk_venta_cliente` (`ON DELETE RESTRICT ON UPDATE CASCADE`), preservando la trazabilidad fiscal y contable obligatoria de pedidos históricos.
- **Ventas 1:N Detalle de Ventas**: Llave foránea `fk_detalle_venta` (`ON DELETE CASCADE ON UPDATE CASCADE`).
- **Productos 1:N Detalle de Ventas**: Llave foránea `fk_detalle_producto` (`ON DELETE RESTRICT ON UPDATE CASCADE`), impidiendo la supresión accidental de productos con historial transaccional activo.
- **Clientes 1:N Auditoría de Clientes**: Llave foránea `fk_auditoria_cliente` (`ON DELETE CASCADE ON UPDATE CASCADE`).
- **Clientes 1:N Carritos**: Llave foránea `fk_carrito_cliente` (`ON DELETE CASCADE ON UPDATE CASCADE`).
- **Carritos 1:N Carrito Items**: Llave foránea `fk_item_carrito` (`ON DELETE CASCADE ON UPDATE CASCADE`).
- **Productos 1:N Carrito Items**: Llave foránea `fk_item_producto` (`ON DELETE CASCADE ON UPDATE CASCADE`).
- **Clientes 1:N Clientes (Referidos)**: Llave foránea `fk_cliente_referido` (`ON DELETE SET NULL ON UPDATE CASCADE`).

---

## 3. Contenido de los Archivos del Proyecto

| Archivo | Componentes y Propósito |
| :--- | :--- |
| `01_Esquema_y_Datos.sql` | Inicialización DDL del esquema `ecommerce_db`, definición de 17 tablas con restricciones de dominio (`CHECK`), claves primarias, claves foráneas, 12 índices de cobertura y carga de datos semilla balanceados y consistentes. |
| `02_Consultas_Avanzadas.sql` | 20 consultas analíticas de alta eficiencia para toma de decisiones (Top ingresos, productos de baja rotación, Customer Lifetime Value [CLV], cohortes de retención, segmentación RFM, horas pico y afinidad de canasta) optimizadas para evitar productos cartesianos (fan-out) y compatibles con `ONLY_FULL_GROUP_BY`. |
| `03_Funciones.sql` | 20 funciones almacenadas definidas por el usuario (UDF) con determinismo explícito (`DETERMINISTIC` vs `NOT DETERMINISTIC`) y manejo seguro de nulos (`NULL-safety`) para cálculos de flete, lealtad, SKU, descuentos, validación de credenciales y edad. |
| `04_Seguridad.sql` | Esquema de seguridad basado en roles (RBAC) con 7 roles operativos, 7 usuarios con límites de consultas por hora y expiración de contraseñas cada 90 días, 3 vistas de seguridad con enmascaramiento de datos (data masking) y revocación preventiva de accesos remotos no seguros (`root`). |
| `05_Triggers.sql` | 21 disparadores para gobierno de datos e integridad operativa: control y validación de inventario físico en dos fases (`BEFORE` y `AFTER`), recálculo automático de importes de órdenes, alertas de stock bajo y actualización del acumulador de gasto y rango de lealtad en entregas o cancelaciones. |
| `06_Eventos.sql` | 9 tablas auxiliares y 20 eventos programados automáticos (`MySQL Event Scheduler`) para agregación diaria de facturación, depuración de carritos abandonados, actualización nocturna de estadísticas de productos y categorías, respaldo de catálogo y generación mensual de KPIs. |
| `07_Procedimientos_Almacenados.sql` | 20 procedimientos almacenados transaccionales que encapsulan la lógica operativa del e-commerce bajo control ACID (manejo de excepciones con `EXIT HANDLER`, `ROLLBACK` y `SIGNAL SQLSTATE '45000'`) para compras completas, devoluciones, pagos, auditoría de stock y fusión de cuentas. |
| `08_Auditoria_Clientes.sql` | Módulo de auditoría especializada: define la tabla `Auditoria_Clientes` (6 columnas estrictas con clave primaria `BIGINT`) y el trigger `trg_audit_cliente_after_update` (`AFTER UPDATE ON clientes`), implementando comparación binaria e inmune a nulos (`<=>` combinado con `CAST AS BINARY`) para monitorear modificaciones reales en `email` y `direccion_envio`. |

---

## 4. Instrucciones de Ejecución Secuencial

Para garantizar la correcta resolución de dependencias entre esquemas, funciones, permisos, disparadores y procedimientos, los archivos deben ejecutarse en **orden estricto del 01 al 08**.

### Opción A: Ejecución mediante línea de comandos (MySQL CLI)

Desde la terminal del sistema operativo, ubicándose en la raíz del proyecto (`ecommerce_db/`):

```bash
mysql -u root -p < SQL/01_Esquema_y_Datos.sql
mysql -u root -p < SQL/02_Consultas_Avanzadas.sql
mysql -u root -p < SQL/03_Funciones.sql
mysql -u root -p < SQL/04_Seguridad.sql
mysql -u root -p < SQL/05_Triggers.sql
mysql -u root -p < SQL/06_Eventos.sql
mysql -u root -p < SQL/07_Procedimientos_Almacenados.sql
mysql -u root -p < SQL/08_Auditoria_Clientes.sql
```

### Opción B: Ejecución interactiva desde el cliente MySQL (`SOURCE`)

Inicie sesión en el cliente interactivo de MySQL y cargue secuencialmente los scripts:

```sql
SOURCE SQL/01_Esquema_y_Datos.sql;
SOURCE SQL/02_Consultas_Avanzadas.sql;
SOURCE SQL/03_Funciones.sql;
SOURCE SQL/04_Seguridad.sql;
SOURCE SQL/05_Triggers.sql;
SOURCE SQL/06_Eventos.sql;
SOURCE SQL/07_Procedimientos_Almacenados.sql;
SOURCE SQL/08_Auditoria_Clientes.sql;
```

---

## 5. Requisitos del Sistema

- **Motor de Base de Datos**: MySQL Community Server 8.0 o superior (o MySQL Enterprise Edition).
- **Características requeridas del motor**:
  - Soporte de Common Table Expressions (`WITH` CTEs) y Funciones de Ventana (`ROW_NUMBER()`, `COUNT() OVER()`, `LAG()`).
  - Motor de almacenamiento `InnoDB` con soporte para transacciones ACID y restricciones foráneas en cascada y restrictivas.
  - Soporte nativo para seguridad basada en roles (RBAC) y `SET DEFAULT ROLE`.
  - Conjunto de caracteres `utf8mb4` con colación `utf8mb4_unicode_ci`.
- **Privilegios de Despliegue**: Usuario con privilegios de administrador (`SUPER` o `SYSTEM_VARIABLES_ADMIN`) para habilitar el programador de eventos (`SET GLOBAL event_scheduler = ON;`) y conceder privilegios a los distintos roles del sistema.

> [!IMPORTANT]
> Las credenciales de usuarios creadas en `04_Seguridad.sql` son provistas con fines de estructuración arquitectónica inicial (`Adm1n$Secure2026!`, etc.). En entornos de producción deben modificarse inmediatamente por secretos gestionados según la política de seguridad corporativa.

---

## 6. Verificación y Prueba Rápida del Sistema

Una vez ejecutados los 8 archivos secuencialmente, puede verificar la operatividad integral de la plataforma ejecutando las siguientes pruebas funcionales:

```sql
USE ecommerce_db;

-- 1. Prueba de compra transaccional completa con cálculo automático y descuento de stock
CALL sp_RealizarNuevaVenta(1, 1, 3, 2, @id_venta_generada);
SELECT @id_venta_generada AS venta_creada;

-- 2. Verificación de la orden generada y su detalle asociado
SELECT * FROM ventas WHERE id_venta = @id_venta_generada;
SELECT * FROM detalle_ventas WHERE id_venta = @id_venta_generada;

-- 3. Simulación de liquidación y procesamiento de pago de la orden
CALL sp_ProcesarPago(@id_venta_generada, 99800.00);

-- 4. Prueba del Trigger de Auditoría de Clientes (08_Auditoria_Clientes.sql)
-- Modificación de correo electrónico y dirección sensible
UPDATE clientes 
SET email = 'ana.gomez.nuevo@correo.com', 
    direccion_envio = 'Avenida El Poblado #45-10' 
WHERE id_cliente = 1;

-- Comprobación de los registros inmutables en la tabla de auditoría
SELECT id_auditoria, id_cliente, campo_modificado, valor_antiguo, valor_nuevo, fecha_modificacion 
FROM Auditoria_Clientes 
WHERE id_cliente = 1;

-- 5. Consulta ejecutiva del panel administrativo
CALL sp_ObtenerDashboardAdmin();

-- 6. Historial consolidado de compras del cliente
CALL sp_ObtenerHistorialComprasCliente(1);
```
