-- Реализация триггеров для таблиц STUDENTS и GROUPS

DROP SEQUENCE groups_seq;
DROP SEQUENCE  students_seq;

-- 1. Создание последовательностей для генерации автоинкрементных ключей

-- Последовательность для таблицы GROUPS
CREATE SEQUENCE groups_seq START WITH 1 INCREMENT BY 1;

-- Последовательность для таблицы STUDENTS
CREATE SEQUENCE students_seq START WITH 1 INCREMENT BY 1;


-- 2. Триггер для генерации автоинкрементного ключа в таблице GROUPS
CREATE OR REPLACE TRIGGER groups_bir
BEFORE INSERT ON GROUPS
FOR EACH ROW
BEGIN
    IF :NEW.ID IS NULL THEN
        SELECT groups_seq.NEXTVAL INTO :NEW.ID FROM dual;
    END IF;
END;
/


-- 3. Триггер для генерации автоинкрементного ключа в таблице STUDENTS
CREATE OR REPLACE TRIGGER students_bir
BEFORE INSERT ON STUDENTS
FOR EACH ROW
BEGIN
    IF :NEW.ID IS NULL THEN
        SELECT students_seq.NEXTVAL INTO :NEW.ID FROM dual;
    END IF;
END;
/


-- 4. Триггер для проверки уникальности поля NAME в таблице GROUPS
CREATE OR REPLACE TRIGGER groups_name_unique
BEFORE INSERT OR UPDATE ON GROUPS
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION; -- Делаем проверку в независимой транзакции
    v_count NUMBER;
BEGIN
    -- Проверяем уникальность имени группы
    SELECT COUNT(*) INTO v_count
    FROM GROUPS
    WHERE NAME = :NEW.NAME AND ID != :NEW.ID; -- Исключаем текущую строку при обновлении

    -- Если имя уже существует, выбрасываем исключение
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Группа с таким именем уже существует!');
    END IF;

    -- Завершаем автономную транзакцию
    COMMIT;
END;
/


-- 5. Создаем триггер для проверки уникальности ID GROUPS
CREATE OR REPLACE TRIGGER groups_id_unique
BEFORE INSERT OR UPDATE ON GROUPS
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION; -- Избегаем ошибки ORA-04091
    v_count NUMBER;
BEGIN
    -- Проверяем уникальность ID с помощью автономной транзакции
    SELECT COUNT(*) INTO v_count
    FROM GROUPS
    WHERE ID = :NEW.ID;

    -- Если ID уже существует, выбрасываем исключение
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Группа с таким ID уже существует!');
    END IF;
END;
/


-- 6. Создаем составной триггер для проверки уникальности ID STUDENTS
CREATE OR REPLACE TRIGGER students_id_unique
FOR INSERT OR UPDATE ON STUDENTS
COMPOUND TRIGGER

    -- Переменная для хранения нового ID
    new_id STUDENTS.ID%TYPE;

    -- Этап BEFORE EACH ROW: сохраняем новое значение ID
    BEFORE EACH ROW IS
    BEGIN
        new_id := :NEW.ID;
    END BEFORE EACH ROW;

    -- Этап AFTER STATEMENT: проверяем уникальность ID
    AFTER STATEMENT IS
        v_count NUMBER;
    BEGIN
        -- Проверяем, существует ли уже студент с таким ID
        SELECT COUNT(*) INTO v_count
        FROM STUDENTS
        WHERE ID = new_id;

        -- Если ID уже существует, выбрасываем исключение
        IF v_count > 1 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Студент с таким ID уже существует!');
        END IF;
    END AFTER STATEMENT;
END students_id_unique;
/







