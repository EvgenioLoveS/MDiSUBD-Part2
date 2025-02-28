CREATE OR REPLACE TRIGGER update_c_val
AFTER INSERT OR UPDATE OR DELETE ON STUDENTS
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        BEGIN
            UPDATE GROUPS
            SET C_VAL = C_VAL + 1
            WHERE ID = :NEW.GROUP_ID;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('Группа ' || :NEW.GROUP_ID || ' не найдена.');
        END;
    ELSIF UPDATING THEN
        IF :OLD.GROUP_ID != :NEW.GROUP_ID THEN
            BEGIN
                UPDATE GROUPS
                SET C_VAL = C_VAL - 1
                WHERE ID = :OLD.GROUP_ID;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            BEGIN
                UPDATE GROUPS
                SET C_VAL = C_VAL + 1
                WHERE ID = :NEW.GROUP_ID;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    DBMS_OUTPUT.PUT_LINE('Группа ' || :NEW.GROUP_ID || ' не найдена.');
            END;
        END IF;
    ELSIF DELETING THEN
        IF NOT cascade_ctx.g_is_cascade_delete THEN
            BEGIN
                UPDATE GROUPS
                SET C_VAL = C_VAL - 1
                WHERE ID = :OLD.GROUP_ID;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    DBMS_OUTPUT.PUT_LINE('Группа ' || :OLD.GROUP_ID || ' не найдена.');
            END;
        END IF;
    END IF;
END;
/