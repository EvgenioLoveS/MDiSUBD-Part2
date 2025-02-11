CREATE OR REPLACE PROCEDURE restore_students_to_time(
    p_restore_time IN TIMESTAMP -- Временная метка, на которую нужно восстановить данные
)
IS
BEGIN
    -- Удаляем все текущие данные из таблицы STUDENTS
    DELETE FROM STUDENTS;

    -- Вставляем данные, которые были актуальны на указанный момент времени
    FOR rec IN (
        SELECT sa.STUDENT_ID AS ID, sa.NEW_NAME AS NAME, sa.NEW_GROUP_ID AS GROUP_ID
        FROM STUDENTS_AUDIT sa
        WHERE sa.OPERATION_DATE <= p_restore_time
          AND sa.OPERATION IN ('INSERT', 'UPDATE')
        ORDER BY sa.OPERATION_DATE DESC
    ) LOOP
        -- Используем MERGE для вставки или обновления данных
        MERGE INTO STUDENTS s
        USING (SELECT rec.ID AS ID FROM dual) src
        ON (s.ID = src.ID)
        WHEN NOT MATCHED THEN
            INSERT (ID, NAME, GROUP_ID)
            VALUES (rec.ID, rec.NAME, rec.GROUP_ID);
    END LOOP;

    -- Применяем изменения (обновления и удаления) до указанного момента времени
    FOR rec IN (
        SELECT sa.OPERATION, sa.STUDENT_ID, sa.OLD_NAME, sa.NEW_NAME, sa.OLD_GROUP_ID, sa.NEW_GROUP_ID
        FROM STUDENTS_AUDIT sa
        WHERE sa.OPERATION_DATE <= p_restore_time
        ORDER BY sa.OPERATION_DATE
    ) LOOP
        IF rec.OPERATION = 'UPDATE' THEN
            -- Обновляем запись
            UPDATE STUDENTS
            SET NAME = rec.NEW_NAME,
                GROUP_ID = rec.NEW_GROUP_ID
            WHERE ID = rec.STUDENT_ID;
        ELSIF rec.OPERATION = 'DELETE' THEN
            -- Удаляем запись
            DELETE FROM STUDENTS
            WHERE ID = rec.STUDENT_ID;
        END IF;
    END LOOP;

    COMMIT; -- Фиксируем изменения
END restore_students_to_time;
/



