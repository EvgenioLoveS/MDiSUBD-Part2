CREATE OR REPLACE PACKAGE BODY TimeTravel_PKG IS
    PROCEDURE Restore(p_target_time IN TIMESTAMP) IS
    BEGIN
        -- 1. Восстановление DELETE операций (в обратном порядке)
        FOR rec IN (SELECT * FROM Audit_Log
                   WHERE table_name = 'BOOK_COPIES'
                   AND operation_type = 'D'
                   AND change_time > p_target_time
                   ORDER BY change_time DESC) LOOP
            INSERT INTO Book_Copies (copy_id, book_id, copy_number, condition)
            VALUES (
                TO_NUMBER(rec.pk_value),
                TO_NUMBER(REGEXP_SUBSTR(rec.changed_data, 'book_id=([^,]+)', 1, 1, NULL, 1)),
                REGEXP_SUBSTR(rec.changed_data, 'copy_number=([^,]+)', 1, 1, NULL, 1),
                REGEXP_SUBSTR(rec.changed_data, 'condition=([^,]+)', 1, 1, NULL, 1)
            );
        END LOOP;

        FOR rec IN (SELECT * FROM Audit_Log
                   WHERE table_name = 'BOOKS'
                   AND operation_type = 'D'
                   AND change_time > p_target_time
                   ORDER BY change_time DESC) LOOP
            INSERT INTO Books (book_id, author_id, title, genre, published_date)
            VALUES (
                TO_NUMBER(rec.pk_value),
                TO_NUMBER(REGEXP_SUBSTR(rec.changed_data, 'author_id=([^,]+)', 1, 1, NULL, 1)),
                REGEXP_SUBSTR(rec.changed_data, 'title=([^,]+)', 1, 1, NULL, 1),
                REGEXP_SUBSTR(rec.changed_data, 'genre=([^,]+)', 1, 1, NULL, 1),
                TO_DATE(REGEXP_SUBSTR(rec.changed_data, 'published_date=([^,]+)', 1, 1, NULL, 1), 'YYYY-MM-DD')
            );
        END LOOP;

        FOR rec IN (SELECT * FROM Audit_Log
                   WHERE table_name = 'AUTHORS'
                   AND operation_type = 'D'
                   AND change_time > p_target_time
                   ORDER BY change_time DESC) LOOP
            INSERT INTO Authors (author_id, full_name, birth_date)
            VALUES (
                TO_NUMBER(rec.pk_value),
                REGEXP_SUBSTR(rec.changed_data, 'full_name=([^,]+)', 1, 1, NULL, 1),
                TO_DATE(REGEXP_SUBSTR(rec.changed_data, 'birth_date=([^,]+)', 1, 1, NULL, 1), 'YYYY-MM-DD')
            );
        END LOOP;

        -- 2. Восстановление UPDATE операций
        FOR rec IN (SELECT * FROM Audit_Log
                   WHERE table_name = 'AUTHORS'
                   AND operation_type = 'U'
                   AND change_time > p_target_time
                   ORDER BY change_time DESC) LOOP
            UPDATE Authors
            SET full_name = REGEXP_SUBSTR(rec.changed_data, 'full_name=([^,]+)', 1, 1, NULL, 1),
                birth_date = TO_DATE(REGEXP_SUBSTR(rec.changed_data, 'birth_date=([^,]+)', 1, 1, NULL, 1), 'YYYY-MM-DD')
            WHERE author_id = TO_NUMBER(rec.pk_value);
        END LOOP;

        FOR rec IN (SELECT * FROM Audit_Log
                   WHERE table_name = 'BOOKS'
                   AND operation_type = 'U'
                   AND change_time > p_target_time
                   ORDER BY change_time DESC) LOOP
            UPDATE Books
            SET author_id = TO_NUMBER(REGEXP_SUBSTR(rec.changed_data, 'author_id=([^,]+)', 1, 1, NULL, 1)),
                title = REGEXP_SUBSTR(rec.changed_data, 'title=([^,]+)', 1, 1, NULL, 1),
                genre = REGEXP_SUBSTR(rec.changed_data, 'genre=([^,]+)', 1, 1, NULL, 1),
                published_date = TO_DATE(REGEXP_SUBSTR(rec.changed_data, 'published_date=([^,]+)', 1, 1, NULL, 1), 'YYYY-MM-DD')
            WHERE book_id = TO_NUMBER(rec.pk_value);
        END LOOP;

        FOR rec IN (SELECT * FROM Audit_Log
                   WHERE table_name = 'BOOK_COPIES'
                   AND operation_type = 'U'
                   AND change_time > p_target_time
                   ORDER BY change_time DESC) LOOP
            UPDATE Book_Copies
            SET book_id = TO_NUMBER(REGEXP_SUBSTR(rec.changed_data, 'book_id=([^,]+)', 1, 1, NULL, 1)),
                copy_number = REGEXP_SUBSTR(rec.changed_data, 'copy_number=([^,]+)', 1, 1, NULL, 1),
                condition = REGEXP_SUBSTR(rec.changed_data, 'condition=([^,]+)', 1, 1, NULL, 1)
            WHERE copy_id = TO_NUMBER(rec.pk_value);
        END LOOP;

        -- 3. Восстановление INSERT операций (в обратном порядке)
        FOR rec IN (SELECT * FROM Audit_Log
                   WHERE table_name = 'BOOK_COPIES'
                   AND operation_type = 'I'
                   AND change_time > p_target_time
                   ORDER BY change_time DESC) LOOP
            DELETE FROM Book_Copies WHERE copy_id = TO_NUMBER(rec.pk_value);
        END LOOP;

        FOR rec IN (SELECT * FROM Audit_Log
                   WHERE table_name = 'BOOKS'
                   AND operation_type = 'I'
                   AND change_time > p_target_time
                   ORDER BY change_time DESC) LOOP
            DELETE FROM Books WHERE book_id = TO_NUMBER(rec.pk_value);
        END LOOP;

        FOR rec IN (SELECT * FROM Audit_Log
                   WHERE table_name = 'AUTHORS'
                   AND operation_type = 'I'
                   AND change_time > p_target_time
                   ORDER BY change_time DESC) LOOP
            DELETE FROM Authors WHERE author_id = TO_NUMBER(rec.pk_value);
        END LOOP;

        -- Удаление записей из журнала изменений после восстановления
        DELETE FROM Audit_Log WHERE change_time > p_target_time;
        COMMIT;
    END Restore;

    PROCEDURE Restore(p_interval IN NUMBER) IS
        v_target_time TIMESTAMP;
    BEGIN
        v_target_time := SYSTIMESTAMP - (p_interval / (24 * 60 * 60 * 1000));
        Restore(v_target_time);
    END Restore;
END TimeTravel_PKG;
/