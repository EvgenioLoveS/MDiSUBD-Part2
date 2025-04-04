-- Вставка тестовых данных (без указания ID)
BEGIN
    -- Добавляем авторов (ID генерируются автоматически)
    INSERT INTO Authors (full_name, birth_date) VALUES ('Лев Толстой', TO_DATE('1828-09-09', 'YYYY-MM-DD'));
    INSERT INTO Authors (full_name, birth_date) VALUES ('Федор Достоевский', TO_DATE('1821-11-11', 'YYYY-MM-DD'));
    COMMIT;

    -- Добавляем книги (используем подзапросы для получения author_id)
    INSERT INTO Books (author_id, title, genre, published_date)
    VALUES (
        (SELECT author_id FROM Authors WHERE full_name = 'Лев Толстой'),
        'Война и мир',
        'Роман',
        TO_DATE('1869-01-01', 'YYYY-MM-DD')
    );

    INSERT INTO Books (author_id, title, genre, published_date)
    VALUES (
        (SELECT author_id FROM Authors WHERE full_name = 'Федор Достоевский'),
        'Преступление и наказание',
        'Роман',
        TO_DATE('1866-01-01', 'YYYY-MM-DD')
    );
    COMMIT;

    -- Добавляем экземпляры книг (используем подзапросы для получения book_id)
    INSERT INTO Book_Copies (book_id, copy_number, condition)
    VALUES (
        (SELECT book_id FROM Books WHERE title = 'Война и мир'),
        'A123',
        'Новая'
    );

    INSERT INTO Book_Copies (book_id, copy_number, condition)
    VALUES (
        (SELECT book_id FROM Books WHERE title = 'Преступление и наказание'),
        'B456',
        'Б/у'
    );
    COMMIT;
END;
/

-- Обновление данных (используем подзапросы вместо явных ID)
BEGIN
    -- Обновляем имя автора
    UPDATE Authors
    SET full_name = 'Лев Николаевич Толстой'
    WHERE full_name = 'Лев Толстой';
    COMMIT;

    -- Обновляем название книги
    UPDATE Books
    SET title = 'Война и мир (издание 2023)'
    WHERE title = 'Война и мир';
    COMMIT;

    -- Обновляем состояние экземпляра книги
    UPDATE Book_Copies
    SET condition = 'Хорошая'
    WHERE copy_number = 'A123';
    COMMIT;
END;
/

-- Удаление данных (используем подзапросы вместо явных ID)
BEGIN
    DELETE FROM Book_Copies
    WHERE copy_number = 'A123';
    COMMIT;
END;
/


BEGIN
    TIMETRAVEL_PKG.RESTORE(TIMESTAMP '2025-04-04 20:30:14.203000');
END;
/


BEGIN
    TimeTravel_PKG.RESTORE(180000); -- 60000 миллисекунд = 1 минут
END;
/


BEGIN
    -- Создаем отчет, начиная с указанного времени
    Report_PKG.Create_Report(TO_TIMESTAMP('2025-04-04 02:32:41.163000', 'YYYY-MM-DD HH24:MI:SS.FF'));
END;
/


BEGIN
    -- Создаем отчет, начиная с момента последнего отчета
    Report_PKG.Create_Report;
END;
/