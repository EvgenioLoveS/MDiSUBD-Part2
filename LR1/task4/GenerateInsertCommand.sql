CREATE OR REPLACE FUNCTION Generate_Insert_Command(p_id NUMBER)
RETURN VARCHAR2
IS
    v_val NUMBER;
    v_result VARCHAR2(4000);
BEGIN
    -- Попытка получить значение val для указанного ID
    BEGIN
        SELECT val INTO v_val FROM MyTable WHERE id = p_id;

        -- Формируем строку INSERT
        v_result := 'INSERT INTO MyTable (id, val) VALUES (' || p_id || ', ' || v_val || ');';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Если ID не найден, возвращаем соответствующее сообщение
            v_result := 'ID ' || p_id || ' не найден в таблице MyTable.';
    END;

    RETURN v_result;
END;

