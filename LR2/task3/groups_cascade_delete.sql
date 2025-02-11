-- Реализация триггера для каскадного удаления между таблицами STUDENTS и GROUPS

-- 1. Триггер для каскадного удаления студентов при удалении группы
CREATE OR REPLACE TRIGGER groups_cascade_delete
BEFORE DELETE ON GROUPS
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION; -- Независимая транзакция
BEGIN
    DELETE FROM STUDENTS WHERE GROUP_ID = :OLD.ID;
    COMMIT; -- Фиксируем удаление студентов
END;
/