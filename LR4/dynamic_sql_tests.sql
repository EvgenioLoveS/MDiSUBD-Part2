--------------------------------------------------
-- Блок 1: SELECT запросы
--------------------------------------------------

-- Тест 1.1: Простой SELECT запрос (выборка книг и авторов, опубликованных после 1860 года)
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "b.title, a.author_name, b.published_year",
    "tables": "books b, authors a",
    "join_conditions": "b.author_id = a.author_id",
    "where_conditions": "b.published_year > 1860"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_title         VARCHAR2(200);
  v_author_name   VARCHAR2(100);
  v_published_year NUMBER;

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 1.1: Простой SELECT запрос (выборка книг и авторов, опубликованных после 1860 года)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_title, v_author_name, v_published_year;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Title: ' || v_title || ', Author: ' || v_author_name ||
                         ', Year: ' || v_published_year);
  END LOOP;

  CLOSE v_cursor;
END;
/

-- Тест 1.2: SELECT запрос с GROUP BY (подсчет количества книг для каждого автора)
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "a.author_name, COUNT(b.book_id) AS book_count",
    "tables": "books b, authors a",
    "join_conditions": "b.author_id = a.author_id",
    "group_by": "a.author_name"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_author_name VARCHAR2(100);
  v_book_count  NUMBER;

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 1.2: SELECT запрос с GROUP BY (подсчет количества книг для каждого автора)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_author_name, v_book_count;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Author: ' || v_author_name || ', Book Count: ' || v_book_count);
  END LOOP;

  CLOSE v_cursor;
END;
/

-- Тест 1.3: SELECT запрос с GROUP BY и WHERE (подсчет количества книг для авторов, опубликованных после 1860 года)
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "a.author_name, COUNT(b.book_id) AS book_count",
    "tables": "books b, authors a",
    "join_conditions": "b.author_id = a.author_id",
    "where_conditions": "b.published_year > 1860",
    "group_by": "a.author_name"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_author_name VARCHAR2(100);
  v_book_count  NUMBER;

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 1.3: SELECT запрос с GROUP BY и WHERE (подсчет количества книг для авторов, опубликованных после 1860 года)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_author_name, v_book_count;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Author: ' || v_author_name || ', Book Count: ' || v_book_count);
  END LOOP;

  CLOSE v_cursor;
END;
/

--------------------------------------------------
-- Блок 2: Вложенные запросы
--------------------------------------------------

-- Тест 2.1: SELECT запрос с подзапросом (IN) (выборка книг, опубликованных после 1860 года)
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "b.title, a.author_name",
    "tables": "books b, authors a",
    "join_conditions": "b.author_id = a.author_id",
    "where_conditions": "b.book_id IN (SELECT book_id FROM books WHERE published_year > 1860)"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_title       VARCHAR2(200);
  v_author_name VARCHAR2(100);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 2.1: SELECT запрос с подзапросом (IN) (выборка книг, опубликованных после 1860 года)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_title, v_author_name;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Title: ' || v_title || ', Author: ' || v_author_name);
  END LOOP;

  CLOSE v_cursor;
END;
/

-- Тест 2.2: SELECT запрос с подзапросом (NOT IN) (выборка книг, не опубликованных после 1860 года)
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "b.title, a.author_name",
    "tables": "books b, authors a",
    "join_conditions": "b.author_id = a.author_id",
    "where_conditions": "b.book_id NOT IN (SELECT book_id FROM books WHERE published_year > 1860)"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_title       VARCHAR2(200);
  v_author_name VARCHAR2(100);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 2.2: SELECT запрос с подзапросом (NOT IN) (выборка книг, не опубликованных после 1860 года)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_title, v_author_name;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Title: ' || v_title || ', Author: ' || v_author_name);
  END LOOP;

  CLOSE v_cursor;
END;
/

-- Тест 2.3: SELECT запрос с подзапросом (EXISTS) (выборка авторов, у которых есть книги, опубликованные после 1860 года)
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "a.author_name",
    "tables": "authors a",
    "where_conditions": "EXISTS (SELECT 1 FROM books b WHERE b.author_id = a.author_id AND b.published_year > 1860)"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_author_name VARCHAR2(100);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 2.3: SELECT запрос с подзапросом (EXISTS) (выборка авторов, у которых есть книги, опубликованные после 1860 года)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_author_name;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Author: ' || v_author_name);
  END LOOP;

  CLOSE v_cursor;
END;
/

-- Тест 2.4: SELECT запрос с подзапросом (NOT EXISTS) (выборка авторов, у которых нет книг, опубликованных после 1860 года)
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "a.author_name",
    "tables": "authors a",
    "where_conditions": "NOT EXISTS (SELECT 1 FROM books b WHERE b.author_id = a.author_id AND b.published_year > 1860)"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_author_name VARCHAR2(100);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 2.4: SELECT запрос с подзапросом (NOT EXISTS) (выборка авторов, у которых нет книг, опубликованных после 1860 года)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_author_name;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Author: ' || v_author_name);
  END LOOP;

  CLOSE v_cursor;
END;
/

--------------------------------------------------
-- Блок 3: DML запросы (INSERT, UPDATE, DELETE)
--------------------------------------------------

-- Тест 3.1: INSERT запрос (добавление нового читателя)
DECLARE
  v_json_input CLOB := '{
    "query_type": "INSERT",
    "table": "readers",
    "columns": "reader_id, reader_name, contact_info",
    "values": "1003, ''Alexey Sidorov'', ''alexey@example.com''"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 3.1: INSERT запрос (добавление нового читателя)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);
  DBMS_OUTPUT.PUT_LINE('Количество затронутых строк: ' || v_rows);
END;
/

-- Тест 3.2: UPDATE запрос (увеличение года публикации книги с book_id = 101 на 1 год)
DECLARE
  v_json_input CLOB := '{
    "query_type": "UPDATE",
    "table": "books",
    "set_clause": "published_year = published_year + 1",
    "where_conditions": "book_id = 101"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 3.2: UPDATE запрос (увеличение года публикации книги с book_id = 101 на 1 год)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);
  DBMS_OUTPUT.PUT_LINE('Количество затронутых строк: ' || v_rows);
END;
/

-- Тест 3.3: DELETE запрос (удаление записей о выдаче книг для читателя с reader_id = 1002)
DECLARE
  v_json_input CLOB := '{
    "query_type": "DELETE",
    "table": "book_issues",
    "where_conditions": "reader_id = 1002"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 3.3: DELETE запрос (удаление записей о выдаче книг для читателя с reader_id = 1002)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);
  DBMS_OUTPUT.PUT_LINE('Количество затронутых строк: ' || v_rows);
END;
/

--------------------------------------------------
-- Блок 4: DDL запросы
--------------------------------------------------

-- Тест 4.1: CREATE TABLE (создание таблицы library_logs)
DECLARE
  v_json_input CLOB := '{
    "query_type": "DDL",
    "ddl_command": "CREATE TABLE",
    "table": "library_logs",
    "fields": "log_id NUMBER, log_message VARCHAR2(500), log_date DATE"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 4.1: CREATE TABLE (создание таблицы library_logs)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);
END;
/

-- Тест 4.2: DROP TABLE (удаление таблицы library_logs)
DECLARE
  v_json_input CLOB := '{
    "query_type": "DDL",
    "ddl_command": "DROP TABLE",
    "table": "library_logs"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 4.2: DROP TABLE (удаление таблицы library_logs)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);
END;
/

--------------------------------------------------
-- Блок 5: Создание таблицы с триггером и вставка данных
--------------------------------------------------

-- Тест 5.1: Создание таблицы с триггером (создание таблицы library_audit с триггером для генерации audit_id)
DECLARE
  v_json_input CLOB := '{
    "query_type": "DDL",
    "ddl_command": "CREATE TABLE",
    "table": "library_audit",
    "fields": "audit_id NUMBER, book_id NUMBER, action VARCHAR2(50), action_date DATE",
    "generate_trigger": "true",
    "trigger_name": "library_audit_trigger",
    "pk_field": "audit_id",
    "sequence_name": "library_audit_seq"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 5.1: Создание таблицы с триггером (создание таблицы library_audit с триггером для генерации audit_id)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);
END;
/

-- Тест 5.2: Вставка данных в таблицу с триггером
DECLARE
  v_json_input CLOB := '{
    "query_type": "INSERT",
    "table": "library_audit",
    "columns": "book_id, action, action_date",
    "values": "101, ''INSERT'', SYSDATE"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 5.2: Вставка данных в таблицу с триггером (проверка работы триггера для генерации audit_id)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);
  DBMS_OUTPUT.PUT_LINE('Количество затронутых строк: ' || v_rows);
END;
/

-- Тест 5.3: Проверка данных в таблице library_audit
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "audit_id, book_id, action, action_date",
    "tables": "library_audit"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_audit_id    NUMBER;
  v_book_id     NUMBER;
  v_action      VARCHAR2(50);
  v_action_date DATE;

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 5.3: Проверка данных в таблице library_audit (проверка корректности вставки данных и работы триггера)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_audit_id, v_book_id, v_action, v_action_date;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Audit ID: ' || v_audit_id || ', Book ID: ' || v_book_id ||
                         ', Action: ' || v_action || ', Action Date: ' || TO_CHAR(v_action_date, 'YYYY-MM-DD HH24:MI:SS'));
  END LOOP;

  CLOSE v_cursor;
END;
/

--------------------------------------------------
-- Блок 6: Вывод данных из всех таблиц
--------------------------------------------------

-- Тест 6.1: Вывод данных из таблицы authors
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "author_id, author_name",
    "tables": "authors"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_author_id   NUMBER;
  v_author_name VARCHAR2(100);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 6.1: Вывод данных из таблицы authors (проверка содержимого таблицы authors)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_author_id, v_author_name;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Author ID: ' || v_author_id || ', Author Name: ' || v_author_name);
  END LOOP;

  CLOSE v_cursor;
END;
/

-- Тест 6.2: Вывод данных из таблицы books
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "book_id, title, author_id, published_year",
    "tables": "books"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_book_id        NUMBER;
  v_title          VARCHAR2(200);
  v_author_id      NUMBER;
  v_published_year NUMBER;

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 6.2: Вывод данных из таблицы books (проверка содержимого таблицы books)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_book_id, v_title, v_author_id, v_published_year;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Book ID: ' || v_book_id || ', Title: ' || v_title ||
                         ', Author ID: ' || v_author_id || ', Year: ' || v_published_year);
  END LOOP;

  CLOSE v_cursor;
END;
/

-- Тест 6.3: Вывод данных из таблицы readers
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "reader_id, reader_name, contact_info",
    "tables": "readers"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_reader_id    NUMBER;
  v_reader_name  VARCHAR2(100);
  v_contact_info VARCHAR2(200);

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 6.3: Вывод данных из таблицы readers (проверка содержимого таблицы readers)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_reader_id, v_reader_name, v_contact_info;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Reader ID: ' || v_reader_id || ', Reader Name: ' || v_reader_name ||
                         ', Contact Info: ' || v_contact_info);
  END LOOP;

  CLOSE v_cursor;
END;
/

-- Тест 6.4: Вывод данных из таблицы book_issues
DECLARE
  v_json_input CLOB := '{
    "query_type": "SELECT",
    "select_columns": "issue_id, book_id, reader_id, issue_date, return_date",
    "tables": "book_issues"
  }';

  v_cursor  SYS_REFCURSOR;
  v_rows    NUMBER;
  v_message VARCHAR2(4000);

  v_issue_id    NUMBER;
  v_book_id     NUMBER;
  v_reader_id   NUMBER;
  v_issue_date  DATE;
  v_return_date DATE;

BEGIN
  dynamic_sql_executor(
    p_json    => v_json_input,
    p_cursor  => v_cursor,
    p_rows    => v_rows,
    p_message => v_message
  );

  DBMS_OUTPUT.PUT_LINE('Тест 6.4: Вывод данных из таблицы book_issues (проверка содержимого таблицы book_issues)');
  DBMS_OUTPUT.PUT_LINE('Результат операции: ' || v_message);

  LOOP
    FETCH v_cursor INTO v_issue_id, v_book_id, v_reader_id, v_issue_date, v_return_date;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Issue ID: ' || v_issue_id || ', Book ID: ' || v_book_id ||
                         ', Reader ID: ' || v_reader_id || ', Issue Date: ' || TO_CHAR(v_issue_date, 'YYYY-MM-DD') ||
                         ', Return Date: ' || NVL(TO_CHAR(v_return_date, 'YYYY-MM-DD'), 'NULL'));
  END LOOP;

  CLOSE v_cursor;
END;
/