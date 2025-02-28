-- Общие функции и процедуры для сравнения схем

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
        RETURN 'Table ' || TABLE_TO_COMPARE || ' is different in ' || SCHEMA1 ||
               ' and ' || SCHEMA2;
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
                TEXT_RESULT := TEXT_RESULT || 'Table ' || RECORD.TABLE_NAME || ' not exists in ' || PROD_SCHEMA_NAME ||
                               CHR(10);
            ELSE
                TEXT_RESULT := TEXT_RESULT || COMPARE_TABLE_DIFF(DEV_SCHEMA_NAME, PROD_SCHEMA_NAME, RECORD.TABLE_NAME);
            END IF;
        END LOOP;
    RETURN TEXT_RESULT;
END;
/

-- Функция для сравнения схем (версия 2)
CREATE OR REPLACE FUNCTION COMPARE_SCHEMES_V2(SCHEMA1 VARCHAR, SCHEMA2 VARCHAR) RETURN VARCHAR
AS
    DIFF        NUMBER := 0;
    TYPE OBJARRAY IS TABLE OF VARCHAR2(16); -- Используем TABLE вместо VARRAY
    OBJECTS_ARR OBJARRAY := OBJARRAY('PROCEDURE', 'PACKAGE', 'INDEX', 'TABLE', 'FUNCTION');
    TEXT_RESULT CLOB DEFAULT '';
BEGIN
    FOR I IN 1 .. OBJECTS_ARR.COUNT -- Используем COUNT для динамического размера
        LOOP
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
                        TEXT_RESULT := TEXT_RESULT || OBJECTS_ARR(I) || ' structure of ' || SAME_OBJECT.OBJECT_NAME ||
                                       ' is different in ' || SCHEMA1 || ' and ' || SCHEMA2 || CHR(10);
                    ELSE
                        TEXT_RESULT := TEXT_RESULT || OBJECTS_ARR(I) || ' structure of ' || SAME_OBJECT.OBJECT_NAME ||
                                       ' the same' || CHR(10);
                    END IF;
                END LOOP;
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
                    TEXT_RESULT := TEXT_RESULT || OBJECTS_ARR(I) || ' ' || OTHER_TABLE.NAME || ' is in ' || SCHEMA1 ||
                                   ' but not in ' || SCHEMA2 || CHR(10);
                END LOOP;
        END LOOP;

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
                    TEXT_RESULT := TEXT_RESULT || OBJECTS_ARR(I) || ' ' || OTHER_TABLE.NAME || ' is in ' || SCHEMA2 ||
                                   ' but not in ' || SCHEMA1 || CHR(10);
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


-- Вызов функции для тестирования первой задачи (сравнение таблиц и их структуры)
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Тестирование первой задачи ===');
    DBMS_OUTPUT.PUT_LINE(COMPARE_SCHEMAS_V1('C##DEV', 'C##PROD'));
END;
/

-- Вызов функции для тестирования второй задачи (сравнение процедур, функций, индексов и пакетов)
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Тестирование второй задачи ===');
    DBMS_OUTPUT.PUT_LINE(FULL_COMPARE_V2('C##DEV', 'C##PROD'));
END;
/
