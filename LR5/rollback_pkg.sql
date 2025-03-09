CREATE OR REPLACE PACKAGE TimeTravel_PKG IS
    -- Перегруженная процедура для восстановления данных до указанной даты и времени
    PROCEDURE Restore(p_target_time IN TIMESTAMP);

    -- Перегруженная процедура для восстановления данных на указанное количество миллисекунд назад
    PROCEDURE Restore(p_interval IN NUMBER);
END TimeTravel_PKG;
/

CREATE OR REPLACE PACKAGE BODY TimeTravel_PKG IS
    PROCEDURE Restore(p_target_time IN TIMESTAMP) IS
    BEGIN
        -- Восстановление для таблицы Authors
        FOR rec IN (SELECT * FROM Audit_Log WHERE table_name = 'AUTHORS' AND change_time > p_target_time ORDER BY change_time DESC) LOOP
            IF rec.operation_type = 'I' THEN
                DELETE FROM Authors WHERE author_id = TO_NUMBER(rec.pk_value);
            ELSIF rec.operation_type = 'U' THEN
                UPDATE Authors
                SET full_name = REGEXP_SUBSTR(rec.changed_data, 'full_name=([^,]+)', 1, 1, NULL, 1),
                    birth_date = TO_DATE(REGEXP_SUBSTR(rec.changed_data, 'birth_date=([^,]+)', 1, 1, NULL, 1), 'YYYY-MM-DD')
                WHERE author_id = TO_NUMBER(rec.pk_value);
            ELSIF rec.operation_type = 'D' THEN
                INSERT INTO Authors (author_id, full_name, birth_date)
                VALUES (
                    TO_NUMBER(rec.pk_value),
                    REGEXP_SUBSTR(rec.changed_data, 'full_name=([^,]+)', 1, 1, NULL, 1),
                    TO_DATE(REGEXP_SUBSTR(rec.changed_data, 'birth_date=([^,]+)', 1, 1, NULL, 1), 'YYYY-MM-DD')
                );
            END IF;
        END LOOP;

        -- Восстановление для таблицы Books
        FOR rec IN (SELECT * FROM Audit_Log WHERE table_name = 'BOOKS' AND change_time > p_target_time ORDER BY change_time DESC) LOOP
            IF rec.operation_type = 'I' THEN
                DELETE FROM Books WHERE book_id = TO_NUMBER(rec.pk_value);
            ELSIF rec.operation_type = 'U' THEN
                UPDATE Books
                SET author_id = TO_NUMBER(REGEXP_SUBSTR(rec.changed_data, 'author_id=([^,]+)', 1, 1, NULL, 1)),
                    title = REGEXP_SUBSTR(rec.changed_data, 'title=([^,]+)', 1, 1, NULL, 1),
                    genre = REGEXP_SUBSTR(rec.changed_data, 'genre=([^,]+)', 1, 1, NULL, 1),
                    published_date = TO_DATE(REGEXP_SUBSTR(rec.changed_data, 'published_date=([^,]+)', 1, 1, NULL, 1), 'YYYY-MM-DD')
                WHERE book_id = TO_NUMBER(rec.pk_value);
            ELSIF rec.operation_type = 'D' THEN
                INSERT INTO Books (book_id, author_id, title, genre, published_date)
                VALUES (
                    TO_NUMBER(rec.pk_value),
                    TO_NUMBER(REGEXP_SUBSTR(rec.changed_data, 'author_id=([^,]+)', 1, 1, NULL, 1)),
                    REGEXP_SUBSTR(rec.changed_data, 'title=([^,]+)', 1, 1, NULL, 1),
                    REGEXP_SUBSTR(rec.changed_data, 'genre=([^,]+)', 1, 1, NULL, 1),
                    TO_DATE(REGEXP_SUBSTR(rec.changed_data, 'published_date=([^,]+)', 1, 1, NULL, 1), 'YYYY-MM-DD')
                );
            END IF;
        END LOOP;

        -- Восстановление для таблицы Book_Copies
        FOR rec IN (SELECT * FROM Audit_Log WHERE table_name = 'BOOK_COPIES' AND change_time > p_target_time ORDER BY change_time DESC) LOOP
            IF rec.operation_type = 'I' THEN
                DELETE FROM Book_Copies WHERE copy_id = TO_NUMBER(rec.pk_value);
            ELSIF rec.operation_type = 'U' THEN
                UPDATE Book_Copies
                SET book_id = TO_NUMBER(REGEXP_SUBSTR(rec.changed_data, 'book_id=([^,]+)', 1, 1, NULL, 1)),
                    copy_number = REGEXP_SUBSTR(rec.changed_data, 'copy_number=([^,]+)', 1, 1, NULL, 1),
                    condition = REGEXP_SUBSTR(rec.changed_data, 'condition=([^,]+)', 1, 1, NULL, 1)
                WHERE copy_id = TO_NUMBER(rec.pk_value);
            ELSIF rec.operation_type = 'D' THEN
                INSERT INTO Book_Copies (copy_id, book_id, copy_number, condition)
                VALUES (
                    TO_NUMBER(rec.pk_value),
                    TO_NUMBER(REGEXP_SUBSTR(rec.changed_data, 'book_id=([^,]+)', 1, 1, NULL, 1)),
                    REGEXP_SUBSTR(rec.changed_data, 'copy_number=([^,]+)', 1, 1, NULL, 1),
                    REGEXP_SUBSTR(rec.changed_data, 'condition=([^,]+)', 1, 1, NULL, 1)
                );
            END IF;
        END LOOP;

        -- Удаление записей из журнала изменений после восстановления
        DELETE FROM Audit_Log WHERE change_time > p_target_time;
        COMMIT;
    END Restore;

    PROCEDURE Restore(p_interval IN NUMBER) IS
        v_target_time TIMESTAMP;
    BEGIN
        v_target_time := SYSTIMESTAMP - (p_interval / (24 * 60 * 60 * 1000));
        Restore(v_target_time); -- Вызов перегруженной процедуры
    END Restore;
END TimeTravel_PKG;
/