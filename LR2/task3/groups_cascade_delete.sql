-- Реализация триггера для каскадного удаления между таблицами STUDENTS и GROUPS

-- 1. Триггер для каскадного удаления студентов при удалении группы
CREATE OR REPLACE TRIGGER groups_cascade_delete
BEFORE DELETE ON GROUPS
FOR EACH ROW
BEGIN
    -- Удаляем всех студентов, связанных с удаляемой группой
    DELETE FROM STUDENTS
    WHERE GROUP_ID = :OLD.ID;
END;
/




-- Вставляем группу
INSERT INTO GROUPS (NAME) VALUES ('Group A');

-- Вставляем студентов в группу
INSERT INTO STUDENTS (NAME, GROUP_ID) VALUES ('John 1', 2);
INSERT INTO STUDENTS (NAME, GROUP_ID) VALUES ('Jane 2', 2);

-- Проверяем группы
SELECT * FROM GROUPS;
-- Проверяем студентов
SELECT * FROM STUDENTS;

-- Удаляем группу
DELETE FROM GROUPS WHERE ID = 2;