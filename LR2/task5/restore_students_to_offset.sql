CREATE OR REPLACE PROCEDURE restore_students_to_offset(
    p_minutes_ago IN NUMBER -- Количество минут назад
)
IS
    v_restore_time TIMESTAMP;
BEGIN
    -- Вычисляем временную метку
    v_restore_time := SYSTIMESTAMP - INTERVAL '1' MINUTE * p_minutes_ago;

    -- Вызываем основную процедуру восстановления
    restore_students_to_time(v_restore_time);
END restore_students_to_offset;
/