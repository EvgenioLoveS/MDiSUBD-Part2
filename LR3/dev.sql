-- Создание пользователя dev
CREATE USER c##devv IDENTIFIED BY devv_password;
GRANT CONNECT, RESOURCE TO c##devv;
GRANT SELECT ANY DICTIONARY TO c##devv;
ALTER USER c##devv QUOTA UNLIMITED ON USERS;


CREATE TABLE c##devv.T2(
    id NUMBER PRIMARY KEY,
    desct2 VARCHAR2(100)
);

CREATE TABLE c##devv.T1(
    id NUMBER PRIMARY KEY,
    t3_id NUMBER,
    desct1 VARCHAR2(100),
    CONSTRAINT fk_t1_t3 FOREIGN KEY (t3_id) REFERENCES c##devv.T3(id)
);

CREATE TABLE c##devv.T3(
    id NUMBER PRIMARY KEY,
    t2_id NUMBER,
    desct3 VARCHAR2(100),
    CONSTRAINT fk_t3_t2 FOREIGN KEY (t2_id) REFERENCES c##devv.T2(id)
);

-- Таблица с другой структурой в dev
CREATE TABLE c##devv.E (
  id   NUMBER PRIMARY KEY,
  name VARCHAR2(100),
  age  NUMBER
);

-- Создание процедуры в схеме c##dev
CREATE OR REPLACE PROCEDURE c##devv.PROC_DEV AS
BEGIN
  DBMS_OUTPUT.PUT_LINE('DEV версия процедуры');
END;
/

-- Процедура, которая есть только в dev
CREATE OR REPLACE PROCEDURE c##devv.PROC_DEV_ONLY AS
BEGIN
  DBMS_OUTPUT.PUT_LINE('DEV версия процедуры, которой нет в prod');
END;
/

-- Создание функции в схеме c##dev
CREATE OR REPLACE FUNCTION c##devv.FUNC_DEV RETURN VARCHAR2 AS
BEGIN
  RETURN 'DEV функция';
END;
/

-- Функция, которая есть только в dev
CREATE OR REPLACE FUNCTION c##devv.FUNC_DEV_ONLY RETURN VARCHAR2 AS
BEGIN
  RETURN 'DEV функция, которой нет в prod';
END;
/

-- Создание пакета в схеме c##dev
CREATE OR REPLACE PACKAGE c##devv.PKG_DEV AS
  PROCEDURE pkg_proc;
END;
/

-- Создание тела пакета в схеме c##dev
CREATE OR REPLACE PACKAGE BODY c##devv.PKG_DEV AS
  PROCEDURE pkg_proc IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('DEV пакет: процедура');
  END;
END;
/

-- Пакет, который есть только в dev
CREATE OR REPLACE PACKAGE c##devv.PKG_DEV_ONLY AS
  PROCEDURE pkg_proc_only;
END;
/

CREATE OR REPLACE PACKAGE BODY c##devv.PKG_DEV_ONLY AS
  PROCEDURE pkg_proc_only IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('DEV пакет: процедура, которой нет в prod');
  END;
END;
/

-- Индекс, который есть только в dev
CREATE INDEX c##devv.IDX_E_NAME ON c##devv.E(name);


-- ЦИКЛИЧЕСКИЕ ЗАВИСИМОСТИ

--Создание таблицы X
CREATE TABLE c##devv.X (
    id   NUMBER PRIMARY KEY,
    y_id NUMBER,
    data VARCHAR2(100)
);

--Создание таблицы Y
CREATE TABLE c##devv.Y (
    id   NUMBER PRIMARY KEY,
    x_id NUMBER,
    info VARCHAR2(100)
);

--Добавление внешнего ключа в таблицу X, ссылающегося на таблицу Y
ALTER TABLE c##devv.X
ADD CONSTRAINT fk_x_y
FOREIGN KEY (y_id) REFERENCES c##devv.Y(id);

--Добавление внешнего ключа в таблицу Y, ссылающегося на таблицу X
ALTER TABLE c##devv.Y
ADD CONSTRAINT fk_y_x
FOREIGN KEY (x_id) REFERENCES c##devv.X(id);




-- ЕСЛИ НАДО ВСЕ ОЧИСТИТЬ В DEV
BEGIN
    -- Удаление всех таблиц
    FOR rec IN (SELECT table_name FROM all_tables WHERE owner = 'C##DEVV') LOOP
        EXECUTE IMMEDIATE 'DROP TABLE c##devv.' || rec.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;

    -- Удаление всех процедур
    FOR rec IN (SELECT object_name FROM all_objects WHERE owner = 'C##DEVV' AND object_type = 'PROCEDURE') LOOP
        EXECUTE IMMEDIATE 'DROP PROCEDURE c##devv.' || rec.object_name;
    END LOOP;

    -- Удаление всех функций
    FOR rec IN (SELECT object_name FROM all_objects WHERE owner = 'C##DEVV' AND object_type = 'FUNCTION') LOOP
        EXECUTE IMMEDIATE 'DROP FUNCTION c##devv.' || rec.object_name;
    END LOOP;

    -- Удаление всех пакетов
    FOR rec IN (SELECT object_name FROM all_objects WHERE owner = 'C##DEVV' AND object_type = 'PACKAGE') LOOP
        EXECUTE IMMEDIATE 'DROP PACKAGE c##devv.' || rec.object_name;
    END LOOP;

    -- Удаление всех индексов
    FOR rec IN (SELECT index_name FROM all_indexes WHERE table_owner = 'C##DEVV') LOOP
        EXECUTE IMMEDIATE 'DROP INDEX c##devv.' || rec.index_name;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Все объекты в схеме C##DEVV удалены.');
END;
/

