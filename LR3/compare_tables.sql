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


CREATE OR REPLACE FUNCTION CHECK_FOR_CYCLIC_DEPENDENCIES(SCHEMA_NAME IN VARCHAR2) RETURN BOOLEAN IS
    v_dependencies FK_TMP_ARRAY := FK_TMP_ARRAY(); -- Для хранения зависимостей
    v_visited TABLE_ARRAY := TABLE_ARRAY(); -- Для хранения посещенных таблиц
    v_recursion_stack TABLE_ARRAY := TABLE_ARRAY(); -- Для отслеживания текущего пути в DFS

    -- Рекурсивная процедура для поиска циклов
    PROCEDURE dfs(
        table_name IN VARCHAR2,
        dependencies IN FK_TMP_ARRAY,
        visited IN OUT TABLE_ARRAY,
        recursion_stack IN OUT TABLE_ARRAY
    ) IS
    BEGIN
        IF table_name MEMBER OF recursion_stack THEN
              DBMS_OUTPUT.PUT_LINE('CYCLE DEPENDENCY DETECTED: ' || table_name);
              RETURN;
        END IF;

        recursion_stack.EXTEND;
        recursion_stack(recursion_stack.COUNT) := table_name;

        IF NOT table_name MEMBER OF visited THEN
            visited.EXTEND;
            visited(visited.COUNT) := table_name;

            -- Рекурсивно обходим все таблицы, от которых зависит текущая таблица
            FOR i IN 1 .. dependencies.COUNT LOOP
                IF dependencies(i).CHILD_OBJ = table_name THEN
                    dfs(dependencies(i).PARENT_OBJ, dependencies, visited, recursion_stack);
                END IF;
            END LOOP;
        END IF;

        recursion_stack.DELETE(recursion_stack.COUNT); -- Удаляем таблицу из стека рекурсии
    END dfs;

BEGIN
    -- Собираем зависимости между таблицами
    FOR FK_REC IN (
        SELECT a.table_name AS child_table, c.table_name AS parent_table
        FROM all_constraints a
        JOIN all_constraints c ON a.r_constraint_name = c.constraint_name
        WHERE a.owner = SCHEMA_NAME
          AND c.owner = SCHEMA_NAME
          AND a.constraint_type = 'R'
    ) LOOP
        v_dependencies.EXTEND;
        v_dependencies(v_dependencies.COUNT) := FK_TMP(FK_REC.child_table, FK_REC.parent_table);
    END LOOP;

    -- Выполняем поиск циклов
    FOR i IN 1 .. v_dependencies.COUNT LOOP
        IF NOT v_dependencies(i).CHILD_OBJ MEMBER OF v_visited THEN
            dfs(v_dependencies(i).CHILD_OBJ, v_dependencies, v_visited, v_recursion_stack);
        END IF;
    END LOOP;

    -- Если циклов не обнаружено, возвращаем FALSE
    RETURN FALSE;
EXCEPTION
    WHEN OTHERS THEN
        -- Если обнаружен цикл, возвращаем TRUE
        RETURN TRUE;
END CHECK_FOR_CYCLIC_DEPENDENCIES;
/


CREATE OR REPLACE FUNCTION GET_SCHEME_TABLES_IN_ORDER(SCHEMA_NAME IN VARCHAR2) RETURN TABLE_ARRAY IS
    v_tables TABLE_ARRAY := TABLE_ARRAY(); -- Используем TABLE_ARRAY вместо локального типа
    v_dependencies FK_TMP_ARRAY := FK_TMP_ARRAY(); -- Для хранения зависимостей
    v_sorted TABLE_ARRAY := TABLE_ARRAY(); -- Для хранения отсортированного списка
    v_visited TABLE_ARRAY := TABLE_ARRAY(); -- Для хранения посещенных таблиц

    -- Рекурсивная процедура для топологической сортировки
    PROCEDURE topological_dfs(
        table_name IN VARCHAR2,
        dependencies IN FK_TMP_ARRAY,
        visited IN OUT TABLE_ARRAY,
        sorted IN OUT TABLE_ARRAY
    ) IS
    BEGIN
        visited.EXTEND;
        visited(visited.COUNT) := table_name;

        -- Рекурсивно обходим все таблицы, от которых зависит текущая таблица
        FOR i IN 1 .. dependencies.COUNT LOOP
            IF dependencies(i).CHILD_OBJ = table_name AND NOT dependencies(i).PARENT_OBJ MEMBER OF visited THEN
                topological_dfs(dependencies(i).PARENT_OBJ, dependencies, visited, sorted);
            END IF;
        END LOOP;

        sorted.EXTEND;
        sorted(sorted.COUNT) := table_name;
    END topological_dfs;

BEGIN
    -- Проверка на циклические зависимости
    IF CHECK_FOR_CYCLIC_DEPENDENCIES(SCHEMA_NAME) THEN
        RAISE_APPLICATION_ERROR(-20001, 'CYCLE DEPENDENCY DETECTED IN SCHEMA: ' || SCHEMA_NAME);
    END IF;

    -- Собираем все таблицы схемы
    SELECT table_name BULK COLLECT INTO v_tables
    FROM all_tables
    WHERE owner = SCHEMA_NAME;

    -- Собираем зависимости между таблицами
    FOR FK_REC IN (
        SELECT a.table_name AS child_table, c.table_name AS parent_table
        FROM all_constraints a
        JOIN all_constraints c ON a.r_constraint_name = c.constraint_name
        WHERE a.owner = SCHEMA_NAME
          AND c.owner = SCHEMA_NAME
          AND a.constraint_type = 'R'
    ) LOOP
        v_dependencies.EXTEND;
        v_dependencies(v_dependencies.COUNT) := FK_TMP(FK_REC.child_table, FK_REC.parent_table);
    END LOOP;

    -- Выполняем топологическую сортировку
    FOR i IN 1 .. v_tables.COUNT LOOP
        IF NOT v_tables(i) MEMBER OF v_visited THEN
            topological_dfs(v_tables(i), v_dependencies, v_visited, v_sorted);
        END IF;
    END LOOP;

    -- Возвращаем отсортированный список таблиц
    RETURN v_sorted;
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


CREATE OR REPLACE FUNCTION COMPARE_SCHEMES_EXISTANCE_V2(SCHEMA1 VARCHAR, SCHEMA2 VARCHAR) RETURN VARCHAR IS
    TYPE OBJARRAY IS TABLE OF VARCHAR2(16); -- Используем TABLE вместо VARRAY
    OBJECTS_ARR OBJARRAY := OBJARRAY('PROCEDURE', 'PACKAGE', 'INDEX', 'TABLE', 'FUNCTION');
    TEXT_RESULT CLOB DEFAULT '';
BEGIN
    -- Добавляем заголовок для объектов, которые есть в SCHEMA1, но отсутствуют в SCHEMA2
    TEXT_RESULT := TEXT_RESULT || '=== Объекты, которые есть в ' || SCHEMA1 || ', но отсутствуют в ' || SCHEMA2 || ' ===' || CHR(10);

    FOR I IN 1 .. OBJECTS_ARR.COUNT -- Используем COUNT для динамического размера
        LOOP
            FOR OTHER_TABLE IN (
                SELECT OBJECTS1.OBJECT_NAME NAME
                FROM ALL_OBJECTS OBJECTS1
                WHERE OWNER = SCHEMA1
                  AND OBJECT_TYPE = OBJECTS_ARR(I)
                  AND (OBJECTS_ARR(I) != 'INDEX' OR OBJECTS1.OBJECT_NAME NOT LIKE 'SYS\_%' ESCAPE '\')
                MINUS
                SELECT OBJECTS2.OBJECT_NAME
                FROM ALL_OBJECTS OBJECTS2
                WHERE OWNER = SCHEMA2
                  AND OBJECT_TYPE = OBJECTS_ARR(I)
                  AND (OBJECTS_ARR(I) != 'INDEX' OR OBJECTS2.OBJECT_NAME NOT LIKE 'SYS\_%' ESCAPE '\'))
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
            FOR OTHER_TABLE IN (
                SELECT OBJECTS2.OBJECT_NAME NAME
                FROM ALL_OBJECTS OBJECTS2
                WHERE OWNER = SCHEMA2
                  AND OBJECT_TYPE = OBJECTS_ARR(I)
                  AND (OBJECTS_ARR(I) != 'INDEX' OR OBJECTS2.OBJECT_NAME NOT LIKE 'SYS\_%' ESCAPE '\')
                MINUS
                SELECT OBJECTS1.OBJECT_NAME
                FROM ALL_OBJECTS OBJECTS1
                WHERE OWNER = SCHEMA1
                  AND OBJECT_TYPE = OBJECTS_ARR(I)
                  AND (OBJECTS_ARR(I) != 'INDEX' OR OBJECTS1.OBJECT_NAME NOT LIKE 'SYS\_%' ESCAPE '\'))
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
CREATE OR REPLACE FUNCTION COMPARE_SCHEMA_FINAL(DEV_SCHEMA_NAME VARCHAR, PROD_SCHEMA_NAME VARCHAR) RETURN CLOB
    IS
    COUNTER     NUMBER;
    COUNTER2    NUMBER;
    TEXT        VARCHAR2(100);
    TEXT_RESULT CLOB := ''; -- Инициализация переменной
BEGIN
    -- Создание таблиц, которые есть в DEV, но отсутствуют в PROD
    FOR RES IN (SELECT TABLE_NAME
                FROM ALL_TABLES
                WHERE OWNER = DEV_SCHEMA_NAME
                  AND TABLE_NAME NOT IN (SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = PROD_SCHEMA_NAME))
    LOOP
        TEXT_RESULT := TEXT_RESULT || 'CREATE TABLE ' || PROD_SCHEMA_NAME || '.' || RES.TABLE_NAME ||
                       ' AS (SELECT * FROM ' || DEV_SCHEMA_NAME || '.' || RES.TABLE_NAME || ' WHERE 1=0);' || CHR(10);
    END LOOP;

    -- Добавление столбцов в существующие таблицы
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
                TEXT_RESULT := TEXT_RESULT || 'ALTER TABLE ' || PROD_SCHEMA_NAME || '.' || RES.TABLE_NAME || ' ADD ' ||
                               RES2.COLUMN_NAME || ' ' || RES2.DATA_TYPE || ';' || CHR(10);
            END LOOP;
        END IF;
    END LOOP;

    -- Удаление столбцов из таблиц в PROD, которых нет в DEV
    FOR RES IN (SELECT DISTINCT TABLE_NAME
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = PROD_SCHEMA_NAME
                  AND (TABLE_NAME, COLUMN_NAME) NOT IN
                      (SELECT TABLE_NAME, COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE OWNER = DEV_SCHEMA_NAME))
    LOOP
        COUNTER := 0;
        SELECT COUNT(*) INTO COUNTER FROM ALL_TABLES WHERE OWNER = DEV_SCHEMA_NAME AND TABLE_NAME = RES.TABLE_NAME;
        IF COUNTER > 0 THEN
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
        END IF;
    END LOOP;

    -- Удаление таблиц, которые есть в PROD, но отсутствуют в DEV
    FOR RES IN (SELECT TABLE_NAME
                FROM ALL_TABLES
                WHERE OWNER = PROD_SCHEMA_NAME
                  AND TABLE_NAME NOT IN (SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = DEV_SCHEMA_NAME))
    LOOP
        TEXT_RESULT := TEXT_RESULT || 'DROP TABLE ' || PROD_SCHEMA_NAME || '.' || RES.TABLE_NAME ||
                       ' CASCADE CONSTRAINTS;' || CHR(10);
    END LOOP;

    -- Создание процедур, которые есть в DEV, но отсутствуют в PROD
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

    -- Удаление процедур, которые есть в PROD, но отсутствуют в DEV
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'PROCEDURE'
                  AND OWNER = PROD_SCHEMA_NAME
                  AND OBJECT_NAME NOT IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = DEV_SCHEMA_NAME AND OBJECT_TYPE = 'PROCEDURE'))
    LOOP
        TEXT_RESULT := TEXT_RESULT || 'DROP PROCEDURE ' || PROD_SCHEMA_NAME || '.' || RES.OBJECT_NAME || CHR(10);
    END LOOP;

    -- Обновление процедур, которые есть в обеих схемах, но с разным кодом
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'PROCEDURE'
                  AND OWNER = DEV_SCHEMA_NAME
                  AND OBJECT_NAME IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = PROD_SCHEMA_NAME AND OBJECT_TYPE = 'PROCEDURE'))
    LOOP
        -- Сравниваем код процедур
        IF COMPARE_OBJECT_CODE(DEV_SCHEMA_NAME, PROD_SCHEMA_NAME, RES.OBJECT_NAME, 'PROCEDURE') LIKE 'Различие%' THEN
            COUNTER := 0;
            TEXT_RESULT := TEXT_RESULT || '-- Обновление процедуры ' || RES.OBJECT_NAME || ' в ' || PROD_SCHEMA_NAME || CHR(10);
            TEXT_RESULT := TEXT_RESULT || 'CREATE OR REPLACE ';
            FOR RES2 IN (SELECT TEXT
                         FROM ALL_SOURCE
                         WHERE TYPE = 'PROCEDURE'
                           AND NAME = RES.OBJECT_NAME
                           AND OWNER = DEV_SCHEMA_NAME)
            LOOP
                IF COUNTER != 0 THEN
                    TEXT_RESULT := TEXT_RESULT || RTRIM(RES2.TEXT, CHR(10)) || CHR(10);
                ELSE
                    TEXT_RESULT := TEXT_RESULT || RTRIM(PROD_SCHEMA_NAME || '.' || RES2.TEXT, CHR(10)) ||
                                   CHR(10);
                    COUNTER := 1;
                END IF;
            END LOOP;
        END IF;
    END LOOP;

    -- Создание функций, которые есть в DEV, но отсутствуют в PROD
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

    -- Удаление функций, которые есть в PROD, но отсутствуют в DEV
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'FUNCTION'
                  AND OWNER = PROD_SCHEMA_NAME
                  AND OBJECT_NAME NOT IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = DEV_SCHEMA_NAME AND OBJECT_TYPE = 'FUNCTION'))
    LOOP
        TEXT_RESULT := TEXT_RESULT || 'DROP FUNCTION ' || PROD_SCHEMA_NAME || '.' || RES.OBJECT_NAME || CHR(10);
    END LOOP;

    -- Обновление функций, которые есть в обеих схемах, но с разным кодом
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'FUNCTION'
                  AND OWNER = DEV_SCHEMA_NAME
                  AND OBJECT_NAME IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = PROD_SCHEMA_NAME AND OBJECT_TYPE = 'FUNCTION'))
    LOOP
        -- Сравниваем код функций
        IF COMPARE_OBJECT_CODE(DEV_SCHEMA_NAME, PROD_SCHEMA_NAME, RES.OBJECT_NAME, 'FUNCTION') LIKE 'Различие%' THEN
            COUNTER := 0;
            TEXT_RESULT := TEXT_RESULT || '-- Обновление функции ' || RES.OBJECT_NAME || ' в ' || PROD_SCHEMA_NAME || CHR(10);
            TEXT_RESULT := TEXT_RESULT || 'CREATE OR REPLACE ';
            FOR RES2 IN (SELECT TEXT
                         FROM ALL_SOURCE
                         WHERE TYPE = 'FUNCTION'
                           AND NAME = RES.OBJECT_NAME
                           AND OWNER = DEV_SCHEMA_NAME)
            LOOP
                IF COUNTER != 0 THEN
                    TEXT_RESULT := TEXT_RESULT || RTRIM(RES2.TEXT, CHR(10)) || CHR(10);
                ELSE
                    TEXT_RESULT := TEXT_RESULT || RTRIM(PROD_SCHEMA_NAME || '.' || RES2.TEXT, CHR(10)) ||
                                   CHR(10);
                    COUNTER := 1;
                END IF;
            END LOOP;
        END IF;
    END LOOP;

    -- Создание пакетов, которые есть в DEV, но отсутствуют в PROD
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'PACKAGE'
                  AND OWNER = DEV_SCHEMA_NAME
                  AND OBJECT_NAME NOT IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = PROD_SCHEMA_NAME AND OBJECT_TYPE = 'PACKAGE'))
    LOOP
        -- Создание спецификации пакета
        COUNTER := 0;
        TEXT_RESULT := TEXT_RESULT || 'CREATE OR REPLACE PACKAGE ' || PROD_SCHEMA_NAME || '.' || RES.OBJECT_NAME || ' AS' || CHR(10);
        FOR RES2 IN (SELECT TEXT
                     FROM ALL_SOURCE
                     WHERE TYPE = 'PACKAGE'
                       AND NAME = RES.OBJECT_NAME
                       AND OWNER = DEV_SCHEMA_NAME)
        LOOP
            TEXT_RESULT := TEXT_RESULT || RTRIM(RES2.TEXT, CHR(10)) || CHR(10);
        END LOOP;
        TEXT_RESULT := TEXT_RESULT || 'END ' || RES.OBJECT_NAME || ';' || CHR(10);

        -- Создание тела пакета
        TEXT_RESULT := TEXT_RESULT || 'CREATE OR REPLACE PACKAGE BODY ' || PROD_SCHEMA_NAME || '.' || RES.OBJECT_NAME || ' AS' || CHR(10);
        FOR RES2 IN (SELECT TEXT
                     FROM ALL_SOURCE
                     WHERE TYPE = 'PACKAGE BODY'
                       AND NAME = RES.OBJECT_NAME
                       AND OWNER = DEV_SCHEMA_NAME)
        LOOP
            TEXT_RESULT := TEXT_RESULT || RTRIM(RES2.TEXT, CHR(10)) || CHR(10);
        END LOOP;
        TEXT_RESULT := TEXT_RESULT || 'END ' || RES.OBJECT_NAME || ';' || CHR(10);
    END LOOP;

    -- Удаление пакетов, которые есть в PROD, но отсутствуют в DEV
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'PACKAGE'
                  AND OWNER = PROD_SCHEMA_NAME
                  AND OBJECT_NAME NOT IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = DEV_SCHEMA_NAME AND OBJECT_TYPE = 'PACKAGE'))
    LOOP
        TEXT_RESULT := TEXT_RESULT || 'DROP PACKAGE ' || PROD_SCHEMA_NAME || '.' || RES.OBJECT_NAME || ';' || CHR(10);
    END LOOP;

    -- Обновление пакетов, которые есть в обеих схемах, но с разным кодом
    FOR RES IN (SELECT DISTINCT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OBJECT_TYPE = 'PACKAGE'
                  AND OWNER = DEV_SCHEMA_NAME
                  AND OBJECT_NAME IN
                      (SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = PROD_SCHEMA_NAME AND OBJECT_TYPE = 'PACKAGE'))
    LOOP
        -- Сравниваем код спецификации пакета
        IF COMPARE_OBJECT_CODE(DEV_SCHEMA_NAME, PROD_SCHEMA_NAME, RES.OBJECT_NAME, 'PACKAGE') LIKE 'Различие%' THEN
            TEXT_RESULT := TEXT_RESULT || '-- Обновление спецификации пакета ' || RES.OBJECT_NAME || ' в ' || PROD_SCHEMA_NAME || CHR(10);
            TEXT_RESULT := TEXT_RESULT || 'CREATE OR REPLACE PACKAGE ' || PROD_SCHEMA_NAME || '.' || RES.OBJECT_NAME || ' AS' || CHR(10);
            FOR RES2 IN (SELECT TEXT
                         FROM ALL_SOURCE
                         WHERE TYPE = 'PACKAGE'
                           AND NAME = RES.OBJECT_NAME
                           AND OWNER = DEV_SCHEMA_NAME)
            LOOP
                TEXT_RESULT := TEXT_RESULT || RTRIM(RES2.TEXT, CHR(10)) || CHR(10);
            END LOOP;
            TEXT_RESULT := TEXT_RESULT || 'END ' || RES.OBJECT_NAME || ';' || CHR(10);
        END IF;

        -- Сравниваем код тела пакета
        IF COMPARE_OBJECT_CODE(DEV_SCHEMA_NAME, PROD_SCHEMA_NAME, RES.OBJECT_NAME, 'PACKAGE BODY') LIKE 'Различие%' THEN
            TEXT_RESULT := TEXT_RESULT || '-- Обновление тела пакета ' || RES.OBJECT_NAME || ' в ' || PROD_SCHEMA_NAME || CHR(10);
            TEXT_RESULT := TEXT_RESULT || 'CREATE OR REPLACE PACKAGE BODY ' || PROD_SCHEMA_NAME || '.' || RES.OBJECT_NAME || ' AS' || CHR(10);
            FOR RES2 IN (SELECT TEXT
                         FROM ALL_SOURCE
                         WHERE TYPE = 'PACKAGE BODY'
                           AND NAME = RES.OBJECT_NAME
                           AND OWNER = DEV_SCHEMA_NAME)
            LOOP
                TEXT_RESULT := TEXT_RESULT || RTRIM(RES2.TEXT, CHR(10)) || CHR(10);
            END LOOP;
            TEXT_RESULT := TEXT_RESULT || 'END ' || RES.OBJECT_NAME || ';' || CHR(10);
        END IF;
    END LOOP;

    -- Создание индексов, которые есть в DEV, но отсутствуют в PROD
    FOR RES IN (SELECT INDEX_NAME, INDEX_TYPE, TABLE_NAME
                FROM ALL_INDEXES
                WHERE TABLE_OWNER = DEV_SCHEMA_NAME
                  AND INDEX_NAME NOT LIKE 'SYS_%'  -- Исключаем системные индексы
                  AND INDEX_NAME NOT IN
                      (SELECT INDEX_NAME
                       FROM ALL_INDEXES
                       WHERE TABLE_OWNER = PROD_SCHEMA_NAME
                         AND INDEX_NAME NOT LIKE 'SYS_%'))
    LOOP
        SELECT COLUMN_NAME
        INTO TEXT
        FROM ALL_IND_COLUMNS
        WHERE INDEX_NAME = RES.INDEX_NAME
          AND TABLE_OWNER = DEV_SCHEMA_NAME;
        TEXT_RESULT := TEXT_RESULT || 'CREATE ' || RES.INDEX_TYPE || ' INDEX ' || RES.INDEX_NAME || ' ON ' ||
                       PROD_SCHEMA_NAME || '.' || RES.TABLE_NAME || '(' || TEXT || ');' || CHR(10);
    END LOOP;

    -- Удаление индексов, которые есть в PROD, но отсутствуют в DEV
    FOR RES IN (SELECT INDEX_NAME
                FROM ALL_INDEXES
                WHERE TABLE_OWNER = PROD_SCHEMA_NAME
                  AND INDEX_NAME NOT LIKE 'SYS_%'  -- Исключаем системные индексы
                  AND INDEX_NAME NOT IN
                      (SELECT INDEX_NAME
                       FROM ALL_INDEXES
                       WHERE TABLE_OWNER = DEV_SCHEMA_NAME
                         AND INDEX_NAME NOT LIKE 'SYS_%'))
    LOOP
        TEXT_RESULT := TEXT_RESULT || 'DROP INDEX ' || RES.INDEX_NAME || ';' || CHR(10);
    END LOOP;

    -- Возвращаем результат
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
