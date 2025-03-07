-- Создание пользователя prod
CREATE USER c##prod IDENTIFIED BY prod_password;
GRANT CONNECT, RESOURCE TO c##prod;
GRANT SELECT ANY DICTIONARY TO c##prod;
ALTER USER c##prod QUOTA UNLIMITED ON USERS;
--DROP USER c##prod CASCADE;

-- Создание таблиц в схеме c##prod
CREATE TABLE c##prod.A (
  id   NUMBER PRIMARY KEY,
  name VARCHAR2(50)
);

CREATE TABLE c##prod.B (
  id          NUMBER PRIMARY KEY,
  a_id        NUMBER,
  description VARCHAR2(50),
  CONSTRAINT fk_b_a FOREIGN KEY (a_id) REFERENCES c##prod.A(id)
);

-- Таблица, которая есть только в prod
CREATE TABLE c##prod.F (
  id   NUMBER PRIMARY KEY,
  data VARCHAR2(100)
);

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

-- Создание индекса в схеме c##prod
CREATE INDEX c##prod.IDX_B_DESCRIPTION ON c##prod.B(description);

-- Индекс, который есть только в prod
CREATE INDEX c##prod.IDX_F_DATA ON c##prod.F(data);