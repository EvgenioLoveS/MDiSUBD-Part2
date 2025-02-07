CREATE OR REPLACE PROCEDURE Insert_MyTable(p_id NUMBER, p_val NUMBER)
IS
BEGIN
    INSERT INTO MyTable (id, val) VALUES (p_id, p_val);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Запись успешно добавлена: ID = ' || p_id || ', VAL = ' || p_val || '.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: Запись с ID ' || p_id || ' уже существует.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка при вставке: ' || SQLERRM);
END;
/

CREATE OR REPLACE PROCEDURE Update_MyTable(p_id NUMBER, p_val NUMBER)
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM MyTable WHERE id = p_id;

    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: Запись с ID ' || p_id || ' не найдена.');
    ELSE
        UPDATE MyTable SET val = p_val WHERE id = p_id;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Обновление успешно: ID ' || p_id || ' теперь имеет значение ' || p_val || '.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка при обновлении: ' || SQLERRM);
END;
/

CREATE OR REPLACE PROCEDURE Delete_MyTable(p_id NUMBER)
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM MyTable WHERE id = p_id;

    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: Запись с ID ' || p_id || ' не найдена.');
    ELSE
        DELETE FROM MyTable WHERE id = p_id;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Удаление успешно: запись с ID ' || p_id || ' удалена.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка при удалении: ' || SQLERRM);
END;
/
