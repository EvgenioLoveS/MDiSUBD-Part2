CREATE USER c##admin_schema IDENTIFIED BY admin_password;
GRANT CONNECT, RESOURCE TO c##admin_schema;
GRANT SELECT ANY DICTIONARY TO c##admin_schema;
GRANT ALL PRIVILEGES TO c##admin_schema;
DROP USER c##admin_schema CASCADE;


-- Проверка существования схемы
CREATE OR REPLACE PROCEDURE ASSERT_SCHEMA_EXISTS(SCHEMA_NAME VARCHAR)
    IS
    SCHEMA_COUNT INTEGER;
BEGIN
    SELECT COUNT(*) INTO SCHEMA_COUNT FROM ALL_USERS WHERE USERNAME = UPPER(SCHEMA_NAME);
    IF SCHEMA_COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Schema ' || SCHEMA_NAME || ' does not exist');
    END IF;
END;
/

-- Типы данных для работы с таблицами и внешними ключами
CREATE OR REPLACE TYPE TABLE_ARRAY IS TABLE OF VARCHAR2(1024);
/

CREATE OR REPLACE TYPE FK_TMP IS OBJECT
(
    CHILD_OBJ  VARCHAR2(1024),
    PARENT_OBJ VARCHAR2(1024)
);
/

CREATE OR REPLACE TYPE FK_TMP_ARRAY IS TABLE OF FK_TMP;
/

-- Функция для получения таблиц в порядке зависимостей
CREATE OR REPLACE FUNCTION GET_SCHEME_TABLES_IN_ORDER(SCHEMA_NAME IN VARCHAR2) RETURN TABLE_ARRAY IS
    SCHEME_ORDER        FK_TMP_ARRAY DEFAULT FK_TMP_ARRAY();
    SCHEMA_ORDER_INDEX  INT DEFAULT 1;
    SCHEMA_TABLES       TABLE_ARRAY DEFAULT TABLE_ARRAY();
    SCHEMA_TABLES_INDEX INT DEFAULT 1;
    LOOPED_TIMES        INT DEFAULT 0;
BEGIN
    FOR SCHEMA_TABLE IN (SELECT TABLES.TABLE_NAME NAME FROM ALL_TABLES TABLES WHERE OWNER = SCHEMA_NAME)
        LOOP
            LOOPED_TIMES := 0;

            FOR RECORD IN (SELECT DISTINCT A.TABLE_NAME, C_PK.TABLE_NAME R_TABLE_NAME
                           FROM ALL_CONS_COLUMNS A
                                    JOIN ALL_CONSTRAINTS C
                                         ON A.OWNER = C.OWNER AND A.CONSTRAINT_NAME = C.CONSTRAINT_NAME
                                    JOIN ALL_CONSTRAINTS C_PK
                                         ON C.R_OWNER = C_PK.OWNER AND C.R_CONSTRAINT_NAME = C_PK.CONSTRAINT_NAME
                           WHERE C.CONSTRAINT_TYPE = 'R'
                             AND A.TABLE_NAME = SCHEMA_TABLE.NAME)
                LOOP
                    LOOPED_TIMES := 1;
                    SCHEME_ORDER.EXTEND;
                    SCHEME_ORDER(SCHEMA_ORDER_INDEX) :=
                            FK_TMP(RECORD.TABLE_NAME, RECORD.R_TABLE_NAME);
                    SCHEMA_ORDER_INDEX := SCHEMA_ORDER_INDEX + 1;
                END LOOP;

            IF LOOPED_TIMES = 0 THEN
                -- no constraints
                SCHEMA_TABLES.EXTEND;
                SCHEMA_TABLES(SCHEMA_TABLES_INDEX) := SCHEMA_TABLE.NAME;
                SCHEMA_TABLES_INDEX := SCHEMA_TABLES_INDEX + 1;
            END IF;
        END LOOP;

    FOR FK_CUR IN (
        SELECT CHILD_OBJ, PARENT_OBJ, CONNECT_BY_ISCYCLE
        FROM TABLE (SCHEME_ORDER)
        CONNECT BY NOCYCLE PRIOR PARENT_OBJ = CHILD_OBJ
        ORDER BY LEVEL
        )
        LOOP
            IF FK_CUR.CONNECT_BY_ISCYCLE = 0 THEN
                SCHEMA_TABLES.EXTEND;
                SCHEMA_TABLES(SCHEMA_TABLES_INDEX) := FK_CUR.CHILD_OBJ;
                SCHEMA_TABLES_INDEX := SCHEMA_TABLES_INDEX + 1;
            ELSE
                RAISE_APPLICATION_ERROR(-20001, 'CYCLE DEPENDENCY ' || FK_CUR.CHILD_OBJ || '<->' ||
                                                FK_CUR.PARENT_OBJ);
            END IF;
        END LOOP;

    RETURN SCHEMA_TABLES;
END GET_SCHEME_TABLES_IN_ORDER;
/

-- Функция для сравнения таблиц
CREATE OR REPLACE FUNCTION COMPARE_TABLE_DIFF(SCHEMA1 VARCHAR, SCHEMA2 VARCHAR, TABLE_TO_COMPARE VARCHAR) RETURN VARCHAR IS
    DIFF NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO DIFF
    FROM (SELECT TABLE1.COLUMN_NAME NAME, TABLE1.DATA_TYPE
          FROM ALL_TAB_COLUMNS TABLE1
          WHERE OWNER = SCHEMA1
            AND TABLE_NAME = TABLE_TO_COMPARE) COLS1
             FULL JOIN
         (SELECT TABLE2.COLUMN_NAME NAME, TABLE2.DATA_TYPE
          FROM ALL_TAB_COLUMNS TABLE2
          WHERE OWNER = SCHEMA2
            AND TABLE_NAME = TABLE_TO_COMPARE) COLS2
         ON COLS1.NAME = COLS2.NAME
    WHERE COLS1.NAME IS NULL
       OR COLS2.NAME IS NULL;

    IF DIFF > 0 THEN
        RETURN 'Таблица ' || TABLE_TO_COMPARE || ' отличается в схемах ' || SCHEMA1 ||
               ' и ' || SCHEMA2;
    ELSE
        RETURN '';
    END IF;
END COMPARE_TABLE_DIFF;
/

-- Функция для сравнения схем (версия 1)
CREATE OR REPLACE FUNCTION COMPARE_SCHEMAS_V1(DEV_SCHEMA_NAME VARCHAR, PROD_SCHEMA_NAME VARCHAR)
    RETURN CLOB IS
    DEV_TABLES  TABLE_ARRAY;
    PROD_TABLES TABLE_ARRAY;
    TEXT_RESULT CLOB DEFAULT '';
BEGIN
    ASSERT_SCHEMA_EXISTS(DEV_SCHEMA_NAME);
    ASSERT_SCHEMA_EXISTS(PROD_SCHEMA_NAME);

    DEV_TABLES := GET_SCHEME_TABLES_IN_ORDER(DEV_SCHEMA_NAME);
    PROD_TABLES := GET_SCHEME_TABLES_IN_ORDER(PROD_SCHEMA_NAME);

    FOR RECORD IN (SELECT COLUMN_VALUE AS TABLE_NAME FROM TABLE (DEV_TABLES))
        LOOP
            IF RECORD.TABLE_NAME NOT MEMBER OF PROD_TABLES THEN
                TEXT_RESULT := TEXT_RESULT || 'Таблица ' || RECORD.TABLE_NAME || ' отсутствует в схеме ' || PROD_SCHEMA_NAME ||
                               CHR(10);
            ELSE
                TEXT_RESULT := TEXT_RESULT || COMPARE_TABLE_DIFF(DEV_SCHEMA_NAME, PROD_SCHEMA_NAME, RECORD.TABLE_NAME) || CHR(10);
            END IF;
        END LOOP;
    RETURN TEXT_RESULT;
END;
/

-- Функция для сравнения кода объектов (процедур, функций, пакетов)
CREATE OR REPLACE FUNCTION COMPARE_OBJECT_CODE(
    schema1 IN VARCHAR2,
    schema2 IN VARCHAR2,
    object_name IN VARCHAR2,
    object_type IN VARCHAR2
) RETURN VARCHAR2 IS
    code1 CLOB;
    code2 CLOB;
BEGIN
    -- Получаем код объекта из первой схемы
    SELECT LISTAGG(TEXT, CHR(10)) WITHIN GROUP (ORDER BY LINE)
    INTO code1
    FROM ALL_SOURCE
    WHERE OWNER = schema1
      AND NAME = object_name
      AND TYPE = object_type;

    -- Получаем код объекта из второй схемы
    SELECT LISTAGG(TEXT, CHR(10)) WITHIN GROUP (ORDER BY LINE)
    INTO code2
    FROM ALL_SOURCE
    WHERE OWNER = schema2
      AND NAME = object_name
      AND TYPE = object_type;

    -- Сравниваем код
    IF code1 = code2 THEN
        RETURN 'Совпадение: ' || object_type || ' ' || object_name || ' идентичен в обеих схемах';
    ELSE
        RETURN 'Различие: ' || object_type || ' ' || object_name || ' отличается в ' || schema1 || ' и ' || schema2;
    END IF;
END COMPARE_OBJECT_CODE;
/

-- Функция для сравнения схем (версия 2)
CREATE OR REPLACE FUNCTION COMPARE_SCHEMES_V2(SCHEMA1 VARCHAR, SCHEMA2 VARCHAR) RETURN CLOB IS
    DIFF        NUMBER := 0;
    TYPE OBJARRAY IS TABLE OF VARCHAR2(16); -- Используем TABLE вместо VARRAY
    OBJECTS_ARR OBJARRAY := OBJARRAY('PROCEDURE', 'PACKAGE', 'INDEX', 'TABLE', 'FUNCTION');
    TEXT_RESULT CLOB DEFAULT '';
BEGIN
    FOR I IN 1 .. OBJECTS_ARR.COUNT -- Используем COUNT для динамического размера
        LOOP
            TEXT_RESULT := TEXT_RESULT || '=== Сравнение ' || OBJECTS_ARR(I) || ' ===' || CHR(10);

            FOR SAME_OBJECT IN (
                SELECT OBJECTS1.OBJECT_NAME
                FROM ALL_OBJECTS OBJECTS1
                WHERE OWNER = SCHEMA1
                  AND OBJECT_TYPE = OBJECTS_ARR(I)
                INTERSECT
                SELECT OBJECTS2.OBJECT_NAME
                FROM ALL_OBJECTS OBJECTS2
                WHERE OWNER = SCHEMA2
                  AND OBJECT_TYPE = OBJECTS_ARR(I))
                LOOP
                    IF OBJECTS_ARR(I) IN ('PROCEDURE', 'FUNCTION', 'PACKAGE') THEN
                        -- Сравниваем код объектов
                        TEXT_RESULT := TEXT_RESULT || COMPARE_OBJECT_CODE(SCHEMA1, SCHEMA2, SAME_OBJECT.OBJECT_NAME, OBJECTS_ARR(I)) || CHR(10);
                    ELSE
                        -- Остальная логика сравнения
                        SELECT COUNT(*)
                        INTO DIFF
                        FROM (SELECT TABLE1.COLUMN_NAME NAME, TABLE1.DATA_TYPE
                              FROM ALL_TAB_COLUMNS TABLE1
                              WHERE OWNER = SCHEMA1
                                AND TABLE_NAME = SAME_OBJECT.OBJECT_NAME) COLS1
                                 FULL JOIN
                             (SELECT TABLE2.COLUMN_NAME NAME, TABLE2.DATA_TYPE
                              FROM ALL_TAB_COLUMNS TABLE2
                              WHERE OWNER = SCHEMA2
                                AND TABLE_NAME = SAME_OBJECT.OBJECT_NAME) COLS2
                             ON COLS1.NAME = COLS2.NAME
                        WHERE COLS1.NAME IS NULL
                           OR COLS2.NAME IS NULL;

                        IF DIFF > 0 THEN
                            TEXT_RESULT := TEXT_RESULT || 'Различие: ' || OBJECTS_ARR(I) || ' ' || SAME_OBJECT.OBJECT_NAME ||
                                           ' отличается в ' || SCHEMA1 || ' и ' || SCHEMA2 || CHR(10);
                        ELSE
                            TEXT_RESULT := TEXT_RESULT || 'Совпадение: ' || OBJECTS_ARR(I) || ' ' || SAME_OBJECT.OBJECT_NAME ||
                                           ' идентичен в обеих схемах' || CHR(10);
                        END IF;
                    END IF;
                END LOOP;

            TEXT_RESULT := TEXT_RESULT || CHR(10); -- Добавляем пустую строку для разделения
        END LOOP;

    RETURN TEXT_RESULT;
END COMPARE_SCHEMES_V2;
/

-- Функция для сравнения существования объектов в схемах
CREATE OR REPLACE FUNCTION COMPARE_SCHEMES_EXISTANCE_V2(SCHEMA1 VARCHAR, SCHEMA2 VARCHAR) RETURN VARCHAR IS
    TYPE OBJARRAY IS TABLE OF VARCHAR2(16); -- Используем TABLE вместо VARRAY
    OBJECTS_ARR OBJARRAY := OBJARRAY('PROCEDURE', 'PACKAGE', 'INDEX', 'TABLE', 'FUNCTION');
    TEXT_RESULT CLOB DEFAULT '';
BEGIN
    -- Добавляем заголовок для объектов, которые есть в SCHEMA1, но отсутствуют в SCHEMA2
    TEXT_RESULT := TEXT_RESULT || '=== Объекты, которые есть в ' || SCHEMA1 || ', но отсутствуют в ' || SCHEMA2 || ' ===' || CHR(10);

    FOR I IN 1 .. OBJECTS_ARR.COUNT -- Используем COUNT для динамического размера
        LOOP
            FOR OTHER_TABLE IN (SELECT OBJECTS1.OBJECT_NAME NAME
                                FROM ALL_OBJECTS OBJECTS1
                                WHERE OWNER = SCHEMA1
                                  AND OBJECT_TYPE = OBJECTS_ARR(I)
                                MINUS
                                SELECT OBJECTS2.OBJECT_NAME
                                FROM ALL_OBJECTS OBJECTS2
                                WHERE OWNER = SCHEMA2
                                  AND OBJECT_TYPE = OBJECTS_ARR(I))
                LOOP
                    TEXT_RESULT := TEXT_RESULT || OBJECTS_ARR(I) || ' ' || OTHER_TABLE.NAME || ' есть в  ' || SCHEMA1 ||
                                   ' но отсутствует в ' || SCHEMA2 || CHR(10);
                END LOOP;
        END LOOP;

    TEXT_RESULT := TEXT_RESULT || CHR(10); -- Добавляем пустую строку для разделения

     -- Добавляем заголовок для объектов, которые есть в SCHEMA2, но отсутствуют в SCHEMA1
    TEXT_RESULT := TEXT_RESULT || '=== Объекты, которые есть в ' || SCHEMA2 || ', но отсутствуют в ' || SCHEMA1 || ' ===' || CHR(10);

    FOR I IN 1 .. OBJECTS_ARR.COUNT -- Используем COUNT для динамического размера
        LOOP
            FOR OTHER_TABLE IN (SELECT OBJECTS2.OBJECT_NAME NAME
                                FROM ALL_OBJECTS OBJECTS2
                                WHERE OWNER = SCHEMA2
                                  AND OBJECT_TYPE = OBJECTS_ARR(I)
                                MINUS
                                SELECT OBJECTS1.OBJECT_NAME
                                FROM ALL_OBJECTS OBJECTS1
                                WHERE OWNER = SCHEMA1
                                  AND OBJECT_TYPE = OBJECTS_ARR(I))
                LOOP
                    TEXT_RESULT := TEXT_RESULT || OBJECTS_ARR(I) || ' ' || OTHER_TABLE.NAME || ' есть в ' || SCHEMA2 ||
                                   ' но отсутствует в ' || SCHEMA1 || CHR(10);
                END LOOP;
        END LOOP;

    RETURN TEXT_RESULT;
END COMPARE_SCHEMES_EXISTANCE_V2;
/

-- Функция для полного сравнения схем (версия 2)
CREATE OR REPLACE FUNCTION FULL_COMPARE_V2(DEV_SCHEME_NAME VARCHAR, PROD_SCHEME_NAME VARCHAR) RETURN CLOB IS
    TEXT_RESULT CLOB DEFAULT '';
BEGIN
    ASSERT_SCHEMA_EXISTS(DEV_SCHEME_NAME);
    ASSERT_SCHEMA_EXISTS(PROD_SCHEME_NAME);


    TEXT_RESULT := TEXT_RESULT || COMPARE_SCHEMES_EXISTANCE_V2(DEV_SCHEME_NAME, PROD_SCHEME_NAME) || CHR(10);

    TEXT_RESULT := TEXT_RESULT || COMPARE_SCHEMES_V2(DEV_SCHEME_NAME, PROD_SCHEME_NAME) || CHR(10);

    RETURN TEXT_RESULT;
END;
/

-- Функция для финального сравнения схем
CREATE OR REPLACE FUNCTION COMPARE_SCHEMA_FINAL(DEV_SCHEMA_NAME VARCHAR, PROD_SCHEMA_NAME VARCHAR) RETURN VARCHAR
    IS
    COUNTER     NUMBER;
    COUNTER2    NUMBER;
    TEXT        VARCHAR2(100);
    TEXT_RESULT CLOB;
BEGIN
    -- dev tables to create or add columns in prod
    FOR RES IN (SELECT DISTINCT TABLE_NAME
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = DEV_SCHEMA_NAME
                  AND (TABLE_NAME, COLUMN_NAME) NOT IN
                      (SELECT TABLE_NAME, COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE OWNER = PROD_SCHEMA_NAME))
        LOOP
            COUNTER := 0;
            SELECT COUNT(*) INTO COUNTER FROM ALL_TABLES WHERE OWNER = PROD_SCHEMA_NAME AND TABLE_NAME = RES.TABLE_NAME;
            IF COUNTER > 0 THEN
                FOR RES2 IN (SELECT DISTINCT COLUMN_NAME, DATA_TYPE
                             FROM ALL_TAB_COLUMNS
                             WHERE OWNER = DEV_SCHEMA_NAME
                               AND TABLE_NAME = RES.TABLE_NAME
                               AND (TABLE_NAME, COLUMN_NAME) NOT IN
                                   (SELECT TABLE_NAME, COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE OWNER = PROD_SCHEMA_NAME))
                    LOOP
                        TEXT_RESULT :=
                                TEXT_RESULT || 'ALTER TABLE ' || PROD_SCHEMA_NAME || '.' || RES.TABLE_NAME || ' ADD ' ||
                                RES2.COLUMN_NAME || ' ' || RES2.DATA_TYPE || ';' || CHR(10);
                    END LOOP;
            ELSE
                TEXT_RESULT := TEXT_RESULT || 'CREATE TABLE ' || PROD_SCHEMA_NAME || '.' || RES.TABLE_NAME ||
                               ' AS (SELECT * FROM ' || DEV_SCHEMA_NAME || '.' || RES.TABLE_NAME || ');' || CHR(10);
            END IF;
        END LOOP;

    FOR RES IN (SELECT DISTINCT TABLE_NAME
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = PROD_SCHEMA_NAME
                  AND (TABLE_NAME, COLUMN_NAME) NOT IN
                      (SELECT TABLE_NAME, COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE OWNER = DEV_SCHEMA_NAME))
        LOOP
            COUNTER := 0;
            COUNTER2 := 0;
            SELECT COUNT(COLUMN_NAME)
            INTO COUNTER
            FROM ALL_TAB_COLUMNS
            WHERE OWNER = PROD_SCHEMA_NAME
              AND TABLE_NAME = RES.TABLE_NAME;
            SELECT COUNT(COLUMN_NAME)
            INTO COUNTER2
            FROM ALL_TAB_COLUMNS
            WHERE OWNER = DEV_SCHEMA_NAME
              AND TABLE_NAME = RES.TABLE_NAME;
            IF COUNTER != COUNTER2 THEN
                FOR RES2 IN (SELECT COLUMN_NAME
                             FROM ALL_TAB_COLUMNS
                             WHERE OWNER = PROD_SCHEMA_NAME
                               AND TABLE_NAME = RES.TABLE_NAME
                               AND COLUMN_NAME NOT IN (SELECT COLUMN_NAME
                                                       FROM ALL_TAB_COLUMNS
                                                       WHERE OWNER = DEV_SCHEMA_NAME
                                                         AND TABLE_NAME = RES.TABLE_NAME))
                    LOOP
                        TEXT_RESULT := TEXT_RESULT || 'ALTER TABLE ' || PROD_SCHEMA_NAME || '.' || RES.TABLE_NAME ||
                                       ' DROP COLUMN ' || RES2.COLUMN_NAME || ';' || CHR(10);
                    END LOOP;
            ELSE
                TEXT_RESULT := TEXT_RESULT || 'DROP TABLE ' || PROD_SCHEMA_NAME || '.' || RES.TABLE_NAME ||
                               ' CASCADE CONSTRAINTS;' || CHR(10);
            END IF;
        END LOOP;

    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'PROCEDURE'
                  AND OWNER = DEV_SCHEMA_NAME
                  AND OBJECT_NAME NOT IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = PROD_SCHEMA_NAME AND OBJECT_TYPE = 'PROCEDURE'))
        LOOP
            COUNTER := 0;
            TEXT_RESULT := TEXT_RESULT || 'CREATE OR REPLACE ';
            FOR RES2 IN (SELECT TEXT
                         FROM ALL_SOURCE
                         WHERE TYPE = 'PROCEDURE'
                           AND NAME = RES.OBJECT_NAME
                           AND OWNER = DEV_SCHEMA_NAME)
                LOOP
                    IF COUNTER != 0 THEN
                        TEXT_RESULT := TEXT_RESULT || RTRIM(RES2.TEXT, CHR(10) || CHR(13)) || CHR(10);
                    ELSE
                        TEXT_RESULT := TEXT_RESULT || RTRIM(PROD_SCHEMA_NAME || '.' || RES2.TEXT, CHR(10) || CHR(13)) ||
                                       CHR(10);
                        COUNTER := 1;
                    END IF;
                END LOOP;
        END LOOP;

-- prod procedures to delete
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'PROCEDURE'
                  AND OWNER = PROD_SCHEMA_NAME
                  AND OBJECT_NAME NOT IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = DEV_SCHEMA_NAME AND OBJECT_TYPE = 'PROCEDURE'))
        LOOP
            TEXT_RESULT := TEXT_RESULT || 'DROP PROCEDURE ' || PROD_SCHEMA_NAME || '.' || RES.OBJECT_NAME || CHR(10);
        END LOOP;

--dev functions to create in prod
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'FUNCTION'
                  AND OWNER = DEV_SCHEMA_NAME
                  AND OBJECT_NAME NOT IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = PROD_SCHEMA_NAME AND OBJECT_TYPE = 'FUNCTION'))
        LOOP
            COUNTER := 0;
            TEXT_RESULT := TEXT_RESULT || 'CREATE OR REPLACE ';
            FOR RES2 IN (SELECT TEXT
                         FROM ALL_SOURCE
                         WHERE TYPE = 'FUNCTION'
                           AND NAME = RES.OBJECT_NAME
                           AND OWNER = DEV_SCHEMA_NAME)
                LOOP
                    IF COUNTER != 0 THEN
                        TEXT_RESULT := TEXT_RESULT || RTRIM(RES2.TEXT, CHR(10) || CHR(13)) || CHR(10);
                    ELSE
                        TEXT_RESULT := TEXT_RESULT || RTRIM(PROD_SCHEMA_NAME || '.' || RES2.TEXT, CHR(10) || CHR(13)) ||
                                       CHR(10);
                        COUNTER := 1;
                    END IF;
                END LOOP;
        END LOOP;

--prod functions to delete
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'FUNCTION'
                  AND OWNER = PROD_SCHEMA_NAME
                  AND OBJECT_NAME NOT IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = DEV_SCHEMA_NAME AND OBJECT_TYPE = 'FUNCTION'))
        LOOP
            TEXT_RESULT := 'DROP FUNCTION ' || PROD_SCHEMA_NAME || '.' || RES.OBJECT_NAME || CHR(10);
        END LOOP;

--dev indexes to create in prod
    FOR RES IN (SELECT INDEX_NAME, INDEX_TYPE, TABLE_NAME
                FROM ALL_INDEXES
                WHERE TABLE_OWNER = DEV_SCHEMA_NAME
                  AND INDEX_NAME NOT LIKE '%_PK'
                  AND INDEX_NAME NOT IN
                      (SELECT INDEX_NAME
                       FROM ALL_INDEXES
                       WHERE TABLE_OWNER = PROD_SCHEMA_NAME
                         AND INDEX_NAME NOT LIKE '%_PK'))
        LOOP
            SELECT COLUMN_NAME
            INTO TEXT
            FROM ALL_IND_COLUMNS
            WHERE INDEX_NAME = RES.INDEX_NAME
              AND TABLE_OWNER = DEV_SCHEMA_NAME;
            TEXT_RESULT := TEXT_RESULT || 'CREATE ' || RES.INDEX_TYPE || ' INDEX ' || RES.INDEX_NAME || ' ON ' ||
                           PROD_SCHEMA_NAME || '.' || RES.TABLE_NAME || '(' || TEXT || ');' || CHR(10);

        END LOOP;

--delete indexes drop prod
    FOR RES IN (SELECT INDEX_NAME
                FROM ALL_INDEXES
                WHERE TABLE_OWNER = PROD_SCHEMA_NAME
                  AND INDEX_NAME NOT LIKE '%_PK'
                  AND INDEX_NAME NOT IN
                      (SELECT INDEX_NAME
                       FROM ALL_INDEXES
                       WHERE TABLE_OWNER = DEV_SCHEMA_NAME
                         AND INDEX_NAME NOT LIKE '%_PK'))
        LOOP
            TEXT_RESULT := TEXT_RESULT || 'DROP INDEX ' || RES.INDEX_NAME || ';' || CHR(10);
        END LOOP;
    RETURN TEXT_RESULT;
END;
/

-- Вызов функции для тестирования первой задачи (сравнение таблиц и их структуры)
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Тестирование первой задачи ===');
    DBMS_OUTPUT.PUT_LINE('Сравнение таблиц и их структуры между схемами C##DEV и C##PROD:');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(COMPARE_SCHEMAS_V1('C##DEVV', 'C##PROD'));
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------');
END;
/

-- Вызов функции для тестирования второй задачи (сравнение процедур, функций, индексов и пакетов)
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Тестирование второй задачи ===');
    DBMS_OUTPUT.PUT_LINE('Сравнение процедур, функций, индексов и пакетов между схемами C##DEV и C##PROD:');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(FULL_COMPARE_V2('C##DEVV', 'C##PROD'));
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------');
END;
/

-- Вызов функции для тестирования третьей задачи (генерация DDL-скрипта для обновления схемы PROD)
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Тестирование третьей задачи ===');
    DBMS_OUTPUT.PUT_LINE('Генерация DDL-скрипта для обновления схемы C##PROD на основе схемы C##DEV:');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(COMPARE_SCHEMA_FINAL('C##DEVV', 'C##PROD'));
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------');
END;
/
