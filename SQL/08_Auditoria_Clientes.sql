-- =============================================================================
-- PROYECTO: Base de Datos de un E-commerce
-- ARCHIVO : 08_Auditoria_Clientes.sql
-- DESCRIPCIÓN: Tabla de auditoría y trigger para cambios sensibles en clientes.
-- MOTOR   : MySQL 8.0+
-- =============================================================================

USE ecommerce_db;

-- -----------------------------------------------------------------------------
-- TABLA: Auditoria_Clientes
-- Registro histórico de modificaciones en datos sensibles de clientes.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS Auditoria_Clientes (
    id_auditoria       BIGINT       NOT NULL AUTO_INCREMENT,
    id_cliente         INT          NOT NULL,
    campo_modificado   VARCHAR(50)  NOT NULL,
    valor_antiguo      VARCHAR(255) NULL,
    valor_nuevo        VARCHAR(255) NULL,
    fecha_modificacion DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_auditoria),
    INDEX idx_auditoria_cliente_fecha (id_cliente, fecha_modificacion),
    CONSTRAINT fk_auditoria_cliente
        FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- TRIGGER: trg_audit_cliente_after_update
-- Audita modificaciones reales en 'email' y 'direccion_envio' (NULL-safe y binario).
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_cliente_after_update;

DELIMITER //

CREATE TRIGGER trg_audit_cliente_after_update
AFTER UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NOT (CAST(OLD.email AS BINARY) <=> CAST(NEW.email AS BINARY)) THEN
        INSERT INTO Auditoria_Clientes
            (id_cliente, campo_modificado, valor_antiguo, valor_nuevo)
        VALUES
            (NEW.id_cliente, 'email', OLD.email, NEW.email);
    END IF;

    IF NOT (CAST(OLD.direccion_envio AS BINARY) <=> CAST(NEW.direccion_envio AS BINARY)) THEN
        INSERT INTO Auditoria_Clientes
            (id_cliente, campo_modificado, valor_antiguo, valor_nuevo)
        VALUES
            (NEW.id_cliente, 'direccion_envio', OLD.direccion_envio, NEW.direccion_envio);
    END IF;
END //

DELIMITER ;
