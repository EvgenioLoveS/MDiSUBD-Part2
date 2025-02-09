-- Реализация триггеров для таблиц STUDENTS и GROUPS

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
    v_count NUMBER;
BEGIN
    -- Проверяем, существует ли уже группа с таким именем
    SELECT COUNT(*) INTO v_count
    FROM GROUPS
    WHERE NAME = :NEW.NAME;

    -- Если имя уже существует, выбрасываем исключение
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Группа с таким именем уже существует!');
    END IF;
END;
/

-- 5. Триггер для проверки уникальности поля ID в таблице GROUPS
CREATE OR REPLACE TRIGGER groups_id_unique
BEFORE INSERT OR UPDATE ON GROUPS
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    -- Проверяем, существует ли уже группа с таким ID
    SELECT COUNT(*) INTO v_count
    FROM GROUPS
    WHERE ID = :NEW.ID;

    -- Если ID уже существует, выбрасываем исключение
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Группа с таким ID уже существует!');
    END IF;
END;
/

-- 6. Триггер для проверки уникальности поля ID в таблице STUDENTS
CREATE OR REPLACE TRIGGER students_id_unique
BEFORE INSERT OR UPDATE ON STUDENTS
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    -- Проверяем, существует ли уже студент с таким ID
    SELECT COUNT(*) INTO v_count
    FROM STUDENTS
    WHERE ID = :NEW.ID;

    -- Если ID уже существует, выбрасываем исключение
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Студент с таким ID уже существует!');
    END IF;
END;
/




-- Попытка вставить дублирующееся имя группы
INSERT INTO GROUPS (NAME) VALUES ('Group B');

-- Попытка вставить дублирующийся ID группы
INSERT INTO GROUPS (ID, NAME) VALUES (1, 'Group B'); -- Ошибка: "Группа с таким ID уже существует!"

-- Попытка вставить дублирующийся ID студента
INSERT INTO STUDENTS (ID, NAME, GROUP_ID) VALUES (2, 'Jane Doe', 1); -- Ошибка: "Студент с таким ID уже существует!"

select * from GROUPS;
select * from STUDENTS;