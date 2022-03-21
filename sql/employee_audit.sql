-- DROP DATABASE IF EXISTS sql_blog_audit;
CREATE DATABASE IF NOT EXISTS sql_blog_audit;

USE sql_blog_audit;

-- DROP TABLE IF EXISTS employee;
CREATE TABLE IF NOT EXISTS employee (
    -- KIM: this has to be NOT NULL in order to prevent the audit info trigger
    --  from failing 
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    first_name TEXT DEFAULT '',
    last_name TEXT DEFAULT '',
    email_address TEXT NOT NULL,
    version INT NOT NULL DEFAULT 1,
    last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_updated_by TEXT NOT NULL DEFAULT CURRENT_USER,
    UNIQUE(email_address)
) ENGINE = InnoDB;

-- DROP TABLE IF EXISTS employee_audit;
CREATE TABLE IF NOT EXISTS employee_audit (
    employee_id BIGINT,
    first_name TEXT,
    last_name TEXT,
    email_address TEXT,
    version INT NOT NULL,
    last_updated DATETIME NOT NULL,
    last_updated_by TEXT NOT NULL,
    FOREIGN KEY (employee_id) REFERENCES employee(id) ON DELETE CASCADE,
    PRIMARY KEY (employee_id, version)
) ENGINE = InnoDB;

-- KIM: these triggers will override any values provided for
--  timestamp, user or version to ensure they're maintained within
--  the context of audit
-- DROP TRIGGER IF EXISTS employee_audit_info_update;
DELIMITER $$
CREATE TRIGGER employee_audit_info_update
BEFORE UPDATE
    ON employee FOR EACH ROW
BEGIN
    SET new.version = old.version+1, new.last_updated = CURRENT_TIMESTAMP, new.last_updated_by = CURRENT_USER;
END$$
DELIMITER ;

-- DROP TRIGGER IF EXISTS employee_audit_info_insert;
DELIMITER $$
CREATE TRIGGER employee_audit_info_insert
BEFORE INSERT
    ON employee FOR EACH ROW
BEGIN
    SET new.last_updated = CURRENT_TIMESTAMP, new.last_updated_by = CURRENT_USER;
END$$
DELIMITER ;

-- DROP TRIGGER IF EXISTS employee_audit_insert;
DELIMITER $$
CREATE TRIGGER employee_audit_insert
AFTER INSERT
    ON employee FOR EACH ROW BEGIN
INSERT INTO
    employee_audit(employee_id, first_name, last_name, email_address, version, last_updated, last_updated_by)
values
    (new.id, new.first_name,  new.last_name, new.email_address, new.version, new.last_updated, new.last_updated_by);
END$$
DELIMITER ;

-- DROP TRIGGER IF EXISTS employee_audit_update;
DELIMITER $$
CREATE TRIGGER employee_audit_update
AFTER UPDATE
    ON employee FOR EACH ROW BEGIN
INSERT INTO
    employee_audit(employee_id, first_name, last_name, email_address, version, last_updated, last_updated_by)
values
    (new.id, new.first_name,  new.last_name, new.email_address, new.version, new.last_updated, new.last_updated_by);
END$$
DELIMITER ;
