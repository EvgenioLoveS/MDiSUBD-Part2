-- Процедура для удаления таблиц
CREATE OR REPLACE PROCEDURE drop_table_if_exists(table_name IN VARCHAR2) IS
BEGIN
  BEGIN
    -- Попытка заблокировать таблицу в эксклюзивном режиме без ожидания
    EXECUTE IMMEDIATE 'LOCK TABLE ' || table_name || ' IN EXCLUSIVE MODE NOWAIT';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -54 THEN
        DBMS_OUTPUT.PUT_LINE('Таблица ' || table_name || ' заблокирована. Пропускаем удаление.');
        RETURN;
      END IF;
  END;

  -- Удаление таблицы
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ' || table_name || ' CASCADE CONSTRAINTS';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE != -942 THEN
        RAISE;
      END IF;
  END;
END;
/

BEGIN
  drop_table_if_exists('book_issues');
  drop_table_if_exists('books');
  drop_table_if_exists('readers');
  drop_table_if_exists('authors');
  drop_table_if_exists('library_audit');
END;
/

-- Создание таблиц
CREATE TABLE authors (
  author_id   NUMBER PRIMARY KEY,
  author_name VARCHAR2(100) NOT NULL
);
/

CREATE TABLE books (
  book_id    NUMBER PRIMARY KEY,
  title      VARCHAR2(200) NOT NULL,
  author_id  NUMBER,
  published_year NUMBER,
  CONSTRAINT fk_book_author FOREIGN KEY (author_id) REFERENCES authors(author_id)
);
/

CREATE TABLE readers (
  reader_id   NUMBER PRIMARY KEY,
  reader_name VARCHAR2(100) NOT NULL,
  contact_info VARCHAR2(200)
);
/

CREATE TABLE book_issues (
  issue_id    NUMBER PRIMARY KEY,
  book_id     NUMBER,
  reader_id   NUMBER,
  issue_date  DATE DEFAULT SYSDATE,
  return_date DATE,
  CONSTRAINT fk_issue_book FOREIGN KEY (book_id) REFERENCES books(book_id),
  CONSTRAINT fk_issue_reader FOREIGN KEY (reader_id) REFERENCES readers(reader_id)
);
/

-- Вставка начальных данных
INSERT INTO authors (author_id, author_name) VALUES (1, 'Leo Tolstoy');
INSERT INTO authors (author_id, author_name) VALUES (2, 'Fyodor Dostoevsky');
INSERT INTO authors (author_id, author_name) VALUES (3, 'Anton Chekhov');
COMMIT;
/

INSERT INTO books (book_id, title, author_id, published_year) VALUES (101, 'War and Peace', 1, 1869);
INSERT INTO books (book_id, title, author_id, published_year) VALUES (102, 'Crime and Punishment', 2, 1866);
INSERT INTO books (book_id, title, author_id, published_year) VALUES (103, 'The Cherry Orchard', 3, 1904);
COMMIT;
/

INSERT INTO readers (reader_id, reader_name, contact_info) VALUES (1001, 'Ivan Ivanov', 'ivan@example.com');
INSERT INTO readers (reader_id, reader_name, contact_info) VALUES (1002, 'Maria Petrova', 'maria@example.com');
COMMIT;
/

INSERT INTO book_issues (issue_id, book_id, reader_id, issue_date, return_date)
  VALUES (5001, 101, 1001, SYSDATE, NULL);
INSERT INTO book_issues (issue_id, book_id, reader_id, issue_date, return_date)
  VALUES (5002, 102, 1002, SYSDATE, NULL);
COMMIT;
/