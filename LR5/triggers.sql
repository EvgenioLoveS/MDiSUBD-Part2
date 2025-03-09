-- Триггер для таблицы Authors
CREATE OR REPLACE TRIGGER trg_authors_audit
BEFORE INSERT OR UPDATE OR DELETE ON Authors
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO Audit_Log (table_name, pk_value, changed_data, operation_type)
        VALUES (
            'AUTHORS',
            TO_CHAR(:NEW.author_id),
            'full_name=' || :NEW.full_name || ', birth_date=' || TO_CHAR(:NEW.birth_date, 'YYYY-MM-DD'),
            'I'
        );
    ELSIF UPDATING THEN
        INSERT INTO Audit_Log (table_name, pk_value, changed_data, operation_type)
        VALUES (
            'AUTHORS',
            TO_CHAR(:OLD.author_id),
            'full_name=' || :OLD.full_name || ', birth_date=' || TO_CHAR(:OLD.birth_date, 'YYYY-MM-DD'),
            'U'
        );
    ELSIF DELETING THEN
        INSERT INTO Audit_Log (table_name, pk_value, changed_data, operation_type)
        VALUES (
            'AUTHORS',
            TO_CHAR(:OLD.author_id),
            'full_name=' || :OLD.full_name || ', birth_date=' || TO_CHAR(:OLD.birth_date, 'YYYY-MM-DD'),
            'D'
        );
    END IF;
END;
/

-- Триггер для таблицы Books
CREATE OR REPLACE TRIGGER trg_books_audit
BEFORE INSERT OR UPDATE OR DELETE ON Books
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO Audit_Log (table_name, pk_value, changed_data, operation_type)
        VALUES (
            'BOOKS',
            TO_CHAR(:NEW.book_id),
            'author_id=' || :NEW.author_id || ', title=' || :NEW.title || ', genre=' || :NEW.genre ||
                ', published_date=' || TO_CHAR(:NEW.published_date, 'YYYY-MM-DD'),
            'I'
        );
    ELSIF UPDATING THEN
        INSERT INTO Audit_Log (table_name, pk_value, changed_data, operation_type)
        VALUES (
            'BOOKS',
            TO_CHAR(:OLD.book_id),
            'author_id=' || :OLD.author_id || ', title=' || :OLD.title || ', genre=' || :OLD.genre ||
                ', published_date=' || TO_CHAR(:OLD.published_date, 'YYYY-MM-DD'),
            'U'
        );
    ELSIF DELETING THEN
        INSERT INTO Audit_Log (table_name, pk_value, changed_data, operation_type)
        VALUES (
            'BOOKS',
            TO_CHAR(:OLD.book_id),
            'author_id=' || :OLD.author_id || ', title=' || :OLD.title || ', genre=' || :OLD.genre ||
                ', published_date=' || TO_CHAR(:OLD.published_date, 'YYYY-MM-DD'),
            'D'
        );
    END IF;
END;
/

-- Триггер для таблицы Book_Copies
CREATE OR REPLACE TRIGGER trg_book_copies_audit
BEFORE INSERT OR UPDATE OR DELETE ON Book_Copies
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO Audit_Log (table_name, pk_value, changed_data, operation_type)
        VALUES (
            'BOOK_COPIES',
            TO_CHAR(:NEW.copy_id),
            'book_id=' || :NEW.book_id || ', copy_number=' || :NEW.copy_number || ', condition=' || :NEW.condition,
            'I'
        );
    ELSIF UPDATING THEN
        INSERT INTO Audit_Log (table_name, pk_value, changed_data, operation_type)
        VALUES (
            'BOOK_COPIES',
            TO_CHAR(:OLD.copy_id),
            'book_id=' || :OLD.book_id || ', copy_number=' || :OLD.copy_number || ', condition=' || :OLD.condition,
            'U'
        );
    ELSIF DELETING THEN
        INSERT INTO Audit_Log (table_name, pk_value, changed_data, operation_type)
        VALUES (
            'BOOK_COPIES',
            TO_CHAR(:OLD.copy_id),
            'book_id=' || :OLD.book_id || ', copy_number=' || :OLD.copy_number || ', condition=' || :OLD.condition,
            'D'
        );
    END IF;
END;
/