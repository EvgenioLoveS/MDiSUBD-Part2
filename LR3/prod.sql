-- Создание пользователя prod
CREATE USER c##prod IDENTIFIED BY prod_password;
GRANT CONNECT, RESOURCE TO c##prod;
GRANT SELECT ANY DICTIONARY TO c##prod;
ALTER USER c##prod QUOTA UNLIMITED ON USERS;


-- Таблица с другой структурой в prod
CREATE TABLE c##prod.E (
  id   NUMBER PRIMARY KEY,
  name VARCHAR2(50)
);

-- Создание процедуры в схеме c##prod
CREATE OR REPLACE PROCEDURE c##prod.PROC_DEV AS
BEGIN
  DBMS_OUTPUT.PUT_LINE('PROD версия процедуры');
END;
/

-- Процедура, которая есть только в prod
CREATE OR REPLACE PROCEDURE c##prod.PROC_PROD_ONLY AS
BEGIN
  DBMS_OUTPUT.PUT_LINE('PROD версия процедуры, которой нет в dev');
END;
/

-- Создание функции в схеме c##prod
CREATE OR REPLACE FUNCTION c##prod.FUNC_DEV RETURN VARCHAR2 AS
BEGIN
  RETURN 'PROD функция';
END;
/

-- Функция, которая есть только в prod
CREATE OR REPLACE FUNCTION c##prod.FUNC_PROD_ONLY RETURN VARCHAR2 AS
BEGIN
  RETURN 'PROD функция, которой нет в dev';
END;
/

-- Создание пакета в схеме c##prod
CREATE OR REPLACE PACKAGE c##prod.PKG_DEV AS
  PROCEDURE pkg_proc;
END;
/

-- Создание тела пакета в схеме c##prod
CREATE OR REPLACE PACKAGE BODY c##prod.PKG_DEV AS
  PROCEDURE pkg_proc IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('PROD пакет: процедура');
  END;
END;
/

-- Пакет, который есть только в prod
CREATE OR REPLACE PACKAGE c##prod.PKG_PROD_ONLY AS
  PROCEDURE pkg_proc_only;
END;
/

CREATE OR REPLACE PACKAGE BODY c##prod.PKG_PROD_ONLY AS
  PROCEDURE pkg_proc_only IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('PROD пакет: процедура, которой нет в dev');
  END;
END;
/



-- ЕСЛИ НАДО ВСЕ ОЧИСТИТЬ В PROD
BEGIN
    -- Удаление всех таблиц
    FOR rec IN (SELECT table_name FROM all_tables WHERE owner = 'C##PROD') LOOP
        EXECUTE IMMEDIATE 'DROP TABLE c##prod.' || rec.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;

    -- Удаление всех процедур
    FOR rec IN (SELECT object_name FROM all_objects WHERE owner = 'C##PROD' AND object_type = 'PROCEDURE') LOOP
        EXECUTE IMMEDIATE 'DROP PROCEDURE c##prod.' || rec.object_name;
    END LOOP;

    -- Удаление всех функций
    FOR rec IN (SELECT object_name FROM all_objects WHERE owner = 'C##PROD' AND object_type = 'FUNCTION') LOOP
        EXECUTE IMMEDIATE 'DROP FUNCTION c##prod.' || rec.object_name;
    END LOOP;

    -- Удаление всех пакетов
    FOR rec IN (SELECT object_name FROM all_objects WHERE owner = 'C##PROD' AND object_type = 'PACKAGE') LOOP
        EXECUTE IMMEDIATE 'DROP PACKAGE c##prod.' || rec.object_name;
    END LOOP;

    -- Удаление всех индексов
    FOR rec IN (SELECT index_name FROM all_indexes WHERE table_owner = 'C##PROD') LOOP
        EXECUTE IMMEDIATE 'DROP INDEX c##prod.' || rec.index_name;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Все объекты в схеме C##PROD удалены.');
END;
/

