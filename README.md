# Base de Datos E-commerce — MySQL

Sistema de base de datos relacional completo para una plataforma de comercio electrónico, desarrollado en MySQL 8.0. Incluye modelo de datos normalizado, consultas analíticas avanzadas, funciones definidas por el usuario, seguridad basada en roles, auditoría mediante triggers, automatización mediante eventos programados y lógica de negocio encapsulada en procedimientos almacenados.

Todo el código fue probado de extremo a extremo en una instancia MySQL 8.0 real, ejecutando los 7 archivos en orden secuencial sin errores.

## Integrantes

- Dilan — Arquitectura de base de datos, desarrollo backend
- (Agregar aquí los demás integrantes del equipo)

## Estructura del proyecto

```
ecommerce_db/
├── README.md
└── sql/
    ├── 01_Esquema_y_Datos.sql
    ├── 02_Consultas_Avanzadas.sql
    ├── 03_Funciones.sql
    ├── 04_Seguridad.sql
    ├── 05_Triggers.sql
    ├── 06_Eventos.sql
    └── 07_Procedimientos_Almacenados.sql
```

## Modelo de datos

**Entidades principales:** `productos`, `categorias`, `proveedores`, `clientes`, `ventas`, `detalle_ventas`.

**Entidades de soporte:** `sucursales`, `promociones`, `resenas_productos`, `vistas_productos`, `carritos`, `carrito_items`, `logins_fallidos`, `log_permisos`, `log_cambios_precio`, `ventas_archivadas`.

**Relaciones:**
- Categorías 1:N Productos
- Proveedores 1:N Productos
- Clientes 1:N Ventas
- Ventas M:N Productos (a través de `detalle_ventas`)

## Contenido por archivo

| Archivo | Contenido |
|---|---|
| `01_Esquema_y_Datos.sql` | Creación de la base de datos, 16 tablas con llaves foráneas, restricciones `CHECK`, índices y datos de prueba iniciales |
| `02_Consultas_Avanzadas.sql` | 20 consultas analíticas (top productos, LTV, cohortes, RFM, rotación de inventario, carrito abandonado, entre otras) |
| `03_Funciones.sql` | 20 funciones (UDF) reutilizables para cálculos de negocio (stock, descuentos, IVA, lealtad, validaciones) |
| `04_Seguridad.sql` | 7 roles, 7 usuarios, vistas de datos sensibles, políticas de contraseñas, límite de consultas por hora y bloqueo de acceso remoto para `root` |
| `05_Triggers.sql` | Tabla `log_cambios_precio` y 20 triggers de auditoría, validación e integridad de datos |
| `06_Eventos.sql` | Tablas de reportes y 20 eventos programados (`event_scheduler`) para tareas automáticas de mantenimiento y reportería |
| `07_Procedimientos_Almacenados.sql` | 20 procedimientos almacenados con lógica transaccional (ventas, devoluciones, fusión de cuentas, dashboard administrativo) |

## Instrucciones de ejecución

Ejecutar los archivos **en orden estricto**, ya que cada uno depende de objetos creados en los anteriores (tablas, funciones y triggers son referenciados entre archivos).

```bash
mysql -u root -p < sql/01_Esquema_y_Datos.sql
mysql -u root -p < sql/02_Consultas_Avanzadas.sql
mysql -u root -p < sql/03_Funciones.sql
mysql -u root -p < sql/04_Seguridad.sql
mysql -u root -p < sql/05_Triggers.sql
mysql -u root -p < sql/06_Eventos.sql
mysql -u root -p < sql/07_Procedimientos_Almacenados.sql
```

O bien, desde el cliente MySQL:

```sql
SOURCE sql/01_Esquema_y_Datos.sql;
SOURCE sql/02_Consultas_Avanzadas.sql;
SOURCE sql/03_Funciones.sql;
SOURCE sql/04_Seguridad.sql;
SOURCE sql/05_Triggers.sql;
SOURCE sql/06_Eventos.sql;
SOURCE sql/07_Procedimientos_Almacenados.sql;
```

### Requisitos

- MySQL 8.0 o superior (se requiere soporte de `WITH` / CTEs, `ROW_NUMBER()` y roles de MySQL)
- Usuario con privilegios `SUPER` o `SYSTEM_VARIABLES_ADMIN` para poder ejecutar `SET GLOBAL event_scheduler = ON;` en `06_Eventos.sql`
- El `event_scheduler` debe quedar activo para que los 20 eventos programados se ejecuten automáticamente

### Notas de seguridad

`04_Seguridad.sql` crea usuarios con contraseñas de ejemplo (`Adm1n$Secure2026!`, etc.). **Deben reemplazarse por contraseñas reales antes de usar el sistema en un entorno de producción.**

## Prueba rápida del sistema

Una vez ejecutados los 7 archivos, se puede validar el funcionamiento con:

```sql
CALL sp_RealizarNuevaVenta(1, 1, 2, 1, @id_venta);
SELECT @id_venta;
CALL sp_ObtenerDashboardAdmin();
CALL sp_ObtenerHistorialComprasCliente(1);
```
