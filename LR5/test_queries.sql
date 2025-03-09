-- 1. Вставка тестовых данных
BEGIN
    -- Добавляем авторов
    INSERT INTO Authors (full_name, birth_date) VALUES ('Лев Толстой', TO_DATE('1828-09-09', 'YYYY-MM-DD'));
    INSERT INTO Authors (full_name, birth_date) VALUES ('Федор Достоевский', TO_DATE('1821-11-11', 'YYYY-MM-DD'));
    COMMIT;

    -- Добавляем книги
    INSERT INTO Books (author_id, title, genre, published_date) VALUES (1, 'Война и мир', 'Роман', TO_DATE('1869-01-01', 'YYYY-MM-DD'));
    INSERT INTO Books (author_id, title, genre, published_date) VALUES (2, 'Преступление и наказание', 'Роман', TO_DATE('1866-01-01', 'YYYY-MM-DD'));
    COMMIT;

    -- Добавляем экземпляры книг
    INSERT INTO Book_Copies (book_id, copy_number, condition) VALUES (1, 'A123', 'Новая');
    INSERT INTO Book_Copies (book_id, copy_number, condition) VALUES (2, 'B456', 'Б/у');
    COMMIT;
END;
/

BEGIN
    INSERT INTO Books (author_id, title, genre, published_date) VALUES (1, 'Анна Каренина', 'Роман', TO_DATE('1877-01-01', 'YYYY-MM-DD'));
    INSERT INTO Books (author_id, title, genre, published_date) VALUES (2, 'Идиот', 'Роман', TO_DATE('1869-01-01', 'YYYY-MM-DD'));
    INSERT INTO Books (author_id, title, genre, published_date) VALUES (1, 'Воскресение', 'Роман', TO_DATE('1899-01-01', 'YYYY-MM-DD'));
    COMMIT;
END;
/

-- 2. Проверка вставленных данных
SELECT * FROM Authors;
SELECT * FROM Books;
SELECT * FROM Book_Copies;
SELECT * FROM Audit_Log; -- Проверяем, что изменения записаны в журнал

-- 3. Обновление данных
BEGIN
    -- Обновляем имя автора
    UPDATE Authors SET full_name = 'Лев Николаевич Толстой' WHERE author_id = 1;
    COMMIT;

    -- Обновляем название книги
    UPDATE Books SET title = 'Война и мир (издание 2023)' WHERE book_id = 1;
    COMMIT;

    -- Обновляем состояние экземпляра книги
    UPDATE Book_Copies SET condition = 'Хорошая' WHERE copy_id = 1;
    COMMIT;
END;
/

-- 4. Удаление данных
BEGIN
    -- Удаляем экземпляр книги
    DELETE FROM Book_Copies WHERE copy_id = 1;
    COMMIT;
END;
/

-- 5. Откат изменений до определенной временной метки
BEGIN
    TIMETRAVEL_PKG.RESTORE(TIMESTAMP '2025-03-09 23:10:03.323000');
END;
/

-- 6. Откат изменений на указанный интервал назад
BEGIN
    TimeTravel_PKG.RESTORE(60000); -- 60000 миллисекунд = 1 минут
END;
/

-- 7. Создание отчета с указанием времени
BEGIN
    -- Создаем отчет, начиная с указанного времени
    Report_PKG.Create_Report(TO_TIMESTAMP('2025-03-09 23:10:03.308000', 'YYYY-MM-DD HH24:MI:SS.FF'));
END;
/

-- 8. Создание отчета без указания времени (с момента последнего отчета)
BEGIN
    -- Создаем отчет, начиная с момента последнего отчета
    Report_PKG.Create_Report;
END;
/

-- 9. Проверка отчетов
SELECT * FROM Reports_Logs; -- Проверяем, что отчеты созданы и сохранены

-- 10. Очистка всех таблиц
BEGIN
    -- Очищаем таблицы в обратном порядке, чтобы избежать ошибок внешних ключей
    EXECUTE IMMEDIATE 'TRUNCATE TABLE Book_Copies';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE Books';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE Authors';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE Audit_Log';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE Reports_Logs';
    COMMIT;
END;
/