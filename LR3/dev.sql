-- Создание пользователя dev
CREATE USER c##devv IDENTIFIED BY devv_password;
GRANT CONNECT, RESOURCE TO c##devv;
GRANT SELECT ANY DICTIONARY TO c##devv;
ALTER USER c##devv QUOTA UNLIMITED ON USERS;
--DROP USER c##devv CASCADE;

-- Создание таблиц в схеме c##dev
CREATE TABLE c##devv.A (
  id   NUMBER PRIMARY KEY,
  name VARCHAR2(50)
);

CREATE TABLE c##devv.B (
  id          NUMBER PRIMARY KEY,
  a_id        NUMBER,
  description VARCHAR2(100),
  CONSTRAINT fk_b_a FOREIGN KEY (a_id) REFERENCES c##devv.A(id)
);

CREATE TABLE c##devv.C (
  id   NUMBER PRIMARY KEY,
  b_id NUMBER,
  info VARCHAR2(100),
  CONSTRAINT fk_c_b FOREIGN KEY (b_id) REFERENCES c##devv.B(id)
);

-- Таблица, которая есть только в dev
CREATE TABLE c##devv.D (
  id   NUMBER PRIMARY KEY,
  data VARCHAR2(100)
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

-- Создание индекса в схеме c##dev
CREATE INDEX c##devv.IDX_B_DESCRIPTION ON c##devv.B(description);

-- Индекс, который есть только в dev
CREATE INDEX c##devv.IDX_E_NAME ON c##devv.E(name);