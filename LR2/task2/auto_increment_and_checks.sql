DROP SEQUENCE groups_seq;
DROP SEQUENCE  students_seq;

-- 1. Создание последовательностей для генерации автоинкрементных ключей
CREATE SEQUENCE groups_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE students_seq START WITH 1 INCREMENT BY 1;


-- 2. Триггер для генерации автоинкрементного ключа в таблице GROUPS
CREATE OR REPLACE TRIGGER groups_bir
BEFORE INSERT ON GROUPS
FOR EACH ROW
BEGIN
    IF :NEW.ID IS NULL THEN
        :NEW.ID := groups_seq.NEXTVAL;
    END IF;
END;
/


-- 3. Триггер для генерации автоинкрементного ключа в таблице STUDENTS
CREATE OR REPLACE TRIGGER students_bir
BEFORE INSERT ON STUDENTS
FOR EACH ROW
BEGIN
    IF :NEW.ID IS NULL THEN
        :NEW.ID := students_seq.NEXTVAL;
    END IF;
END;
/


-- 4. Триггер для проверки уникальности поля NAME в таблице GROUPS
CREATE OR REPLACE PACKAGE pkg_groups_validation IS
    TYPE t_name_table IS TABLE OF VARCHAR2(100) INDEX BY PLS_INTEGER;
    g_names t_name_table;
END pkg_groups_validation;
/

CREATE OR REPLACE TRIGGER trg_groups_before
BEFORE INSERT OR UPDATE ON GROUPS
FOR EACH ROW
BEGIN
    -- Сохраняем новое значение имени в коллекции
    pkg_groups_validation.g_names(pkg_groups_validation.g_names.COUNT + 1) := :NEW.NAME;
END;
/

CREATE OR REPLACE TRIGGER trg_groups_after
AFTER INSERT OR UPDATE ON GROUPS
DECLARE
    v_count NUMBER;
BEGIN
    -- Проверяем уникальность имен из коллекции
    FOR i IN 1 .. pkg_groups_validation.g_names.COUNT LOOP
        SELECT COUNT(*)
        INTO v_count
        FROM GROUPS
        WHERE NAME = pkg_groups_validation.g_names(i);

        IF v_count > 1 THEN
            -- Если найдено больше одной записи с таким именем, выбрасываем ошибку
            RAISE_APPLICATION_ERROR(-20001, 'Имя должно быть уникальным: ' || pkg_groups_validation.g_names(i));
        END IF;
    END LOOP;

    -- Очищаем коллекцию
    pkg_groups_validation.g_names.DELETE;
END;
/
