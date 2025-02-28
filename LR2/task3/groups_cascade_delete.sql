CREATE OR REPLACE PACKAGE cascade_ctx AS
    g_is_cascade_delete BOOLEAN := FALSE;
END cascade_ctx;
/

CREATE OR REPLACE TRIGGER groups_cascade_delete
BEFORE DELETE ON GROUPS
FOR EACH ROW
BEGIN
    cascade_ctx.g_is_cascade_delete := TRUE;
    DELETE FROM STUDENTS WHERE GROUP_ID = :OLD.ID;
    cascade_ctx.g_is_cascade_delete := FALSE;
EXCEPTION
    WHEN OTHERS THEN
        cascade_ctx.g_is_cascade_delete := FALSE;
        RAISE;
END;
/