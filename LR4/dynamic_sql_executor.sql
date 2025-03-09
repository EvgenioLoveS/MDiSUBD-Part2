CREATE OR REPLACE PROCEDURE dynamic_sql_executor (
  p_json    IN  CLOB,
  p_cursor  OUT SYS_REFCURSOR,
  p_rows    OUT NUMBER,
  p_message OUT VARCHAR2
) AS
  -- Константы для типов запросов
  c_query_type_select CONSTANT VARCHAR2(10) := 'SELECT';
  c_query_type_insert CONSTANT VARCHAR2(10) := 'INSERT';
  c_query_type_update CONSTANT VARCHAR2(10) := 'UPDATE';
  c_query_type_delete CONSTANT VARCHAR2(10) := 'DELETE';
  c_query_type_ddl    CONSTANT VARCHAR2(10) := 'DDL';

  -- Локальные переменные
  v_json_obj          JSON_OBJECT_T;
  v_query_type        VARCHAR2(50);
  v_query             VARCHAR2(32767);
  v_filter_clause     VARCHAR2(32767);

  -- Подпрограммы
  PROCEDURE parse_json_conditions(
    p_json_obj IN JSON_OBJECT_T,
    p_join_conditions OUT VARCHAR2,
    p_where_conditions OUT VARCHAR2,
    p_subquery_conditions OUT VARCHAR2,
    p_group_by OUT VARCHAR2
  ) IS
  BEGIN
    BEGIN
      p_join_conditions := p_json_obj.get_String('join_conditions');
    EXCEPTION WHEN NO_DATA_FOUND THEN
      p_join_conditions := NULL;
    END;

    BEGIN
      p_where_conditions := p_json_obj.get_String('where_conditions');
    EXCEPTION WHEN NO_DATA_FOUND THEN
      p_where_conditions := NULL;
    END;

    BEGIN
      p_subquery_conditions := p_json_obj.get_String('subquery_conditions');
    EXCEPTION WHEN NO_DATA_FOUND THEN
      p_subquery_conditions := NULL;
    END;

    BEGIN
      p_group_by := p_json_obj.get_String('group_by');
    EXCEPTION WHEN NO_DATA_FOUND THEN
      p_group_by := NULL;
    END;
  END parse_json_conditions;

  FUNCTION build_filter_clause(
    p_join_conditions IN VARCHAR2,
    p_where_conditions IN VARCHAR2,
    p_subquery_conditions IN VARCHAR2
  ) RETURN VARCHAR2 IS
    v_filter_clause VARCHAR2(32767);
  BEGIN
    v_filter_clause := NULL;

    IF p_join_conditions IS NOT NULL AND TRIM(p_join_conditions) IS NOT NULL THEN
      v_filter_clause := p_join_conditions;
    END IF;

    IF p_where_conditions IS NOT NULL AND TRIM(p_where_conditions) IS NOT NULL THEN
      IF v_filter_clause IS NOT NULL THEN
        v_filter_clause := v_filter_clause || ' AND ' || p_where_conditions;
      ELSE
        v_filter_clause := p_where_conditions;
      END IF;
    END IF;

    IF p_subquery_conditions IS NOT NULL AND TRIM(p_subquery_conditions) IS NOT NULL THEN
      IF v_filter_clause IS NOT NULL THEN
        v_filter_clause := v_filter_clause || ' AND ' || p_subquery_conditions;
      ELSE
        v_filter_clause := p_subquery_conditions;
      END IF;
    END IF;

    RETURN v_filter_clause;
  END build_filter_clause;

  PROCEDURE execute_dml(
    p_query_type IN VARCHAR2,
    p_table IN VARCHAR2,
    p_columns IN VARCHAR2,
    p_values IN VARCHAR2,
    p_set_clause IN VARCHAR2,
    p_filter_clause IN VARCHAR2,
    p_rows OUT NUMBER,
    p_message OUT VARCHAR2
  ) IS
    v_query VARCHAR2(32767);
  BEGIN
    IF p_query_type = c_query_type_insert THEN
      v_query := 'INSERT INTO ' || p_table || ' (' || p_columns || ') VALUES (' || p_values || ')';
    ELSIF p_query_type = c_query_type_update THEN
      v_query := 'UPDATE ' || p_table || ' SET ' || p_set_clause;
      IF p_filter_clause IS NOT NULL AND TRIM(p_filter_clause) IS NOT NULL THEN
        v_query := v_query || ' WHERE ' || p_filter_clause;
      END IF;
    ELSIF p_query_type = c_query_type_delete THEN
      v_query := 'DELETE FROM ' || p_table;
      IF p_filter_clause IS NOT NULL AND TRIM(p_filter_clause) IS NOT NULL THEN
        v_query := v_query || ' WHERE ' || p_filter_clause;
      END IF;
    END IF;

    EXECUTE IMMEDIATE v_query;
    p_rows := SQL%ROWCOUNT;
    p_message := 'DML операция ' || p_query_type || ' выполнена.';
  END execute_dml;

  PROCEDURE create_trigger(
    p_table IN VARCHAR2,
    p_trigger_name IN VARCHAR2,
    p_pk_field IN VARCHAR2,
    p_sequence_name IN VARCHAR2,
    p_message IN OUT VARCHAR2
  ) IS
    v_trigger_sql VARCHAR2(32767);
  BEGIN
    BEGIN
      EXECUTE IMMEDIATE 'CREATE SEQUENCE ' || p_sequence_name;
    EXCEPTION WHEN OTHERS THEN
      NULL; -- Последовательность уже существует
    END;

    v_trigger_sql :=
      'CREATE OR REPLACE TRIGGER ' || p_trigger_name || ' ' ||
      'BEFORE INSERT ON ' || p_table || ' ' ||
      'FOR EACH ROW ' ||
      'WHEN (new.' || p_pk_field || ' IS NULL) ' ||
      'BEGIN ' ||
      '  SELECT ' || p_sequence_name || '.NEXTVAL INTO :new.' || p_pk_field || ' FROM dual; ' ||
      'END;';

    EXECUTE IMMEDIATE v_trigger_sql;
    p_message := p_message || ' Триггер ' || p_trigger_name || ' создан.';
  END create_trigger;

BEGIN
  -- Парсинг JSON
  BEGIN
    v_json_obj := JSON_OBJECT_T.parse(p_json);
    v_query_type := UPPER(v_json_obj.get_String('query_type'));
  EXCEPTION
    WHEN OTHERS THEN
      p_message := 'Ошибка при парсинге JSON: ' || SQLERRM;
      RETURN;
  END;

  -- Обработка SELECT
  IF v_query_type = c_query_type_select THEN
    DECLARE
      v_select_columns      VARCHAR2(32767);
      v_tables              VARCHAR2(32767);
      v_join_conditions     VARCHAR2(32767);
      v_where_conditions    VARCHAR2(32767);
      v_subquery_conditions VARCHAR2(32767);
      v_group_by            VARCHAR2(32767);
    BEGIN
      v_select_columns := v_json_obj.get_String('select_columns');
      v_tables         := v_json_obj.get_String('tables');
      parse_json_conditions(v_json_obj, v_join_conditions, v_where_conditions, v_subquery_conditions, v_group_by);

      v_filter_clause := build_filter_clause(v_join_conditions, v_where_conditions, v_subquery_conditions);

      v_query := 'SELECT ' || v_select_columns || ' FROM ' || v_tables;
      IF v_filter_clause IS NOT NULL AND TRIM(v_filter_clause) IS NOT NULL THEN
        v_query := v_query || ' WHERE ' || v_filter_clause;
      END IF;
      IF v_group_by IS NOT NULL AND TRIM(v_group_by) IS NOT NULL THEN
        v_query := v_query || ' GROUP BY ' || v_group_by;
      END IF;

      p_message := 'Выполняется SELECT запрос.';
      p_rows    := 0;
      OPEN p_cursor FOR v_query;
    END;

  -- Обработка DML (INSERT, UPDATE, DELETE)
  ELSIF v_query_type IN (c_query_type_insert, c_query_type_update, c_query_type_delete) THEN
    DECLARE
      v_table      VARCHAR2(100);
      v_columns    VARCHAR2(32767);
      v_values     VARCHAR2(32767);
      v_set_clause VARCHAR2(32767);
      v_join_conditions     VARCHAR2(32767);  -- Объявлено здесь
      v_where_conditions    VARCHAR2(32767);  -- Объявлено здесь
      v_subquery_conditions VARCHAR2(32767);  -- Объявлено здесь
      v_group_by            VARCHAR2(32767);  -- Объявлено здесь
    BEGIN
      v_table := v_json_obj.get_String('table');
      IF v_query_type = c_query_type_insert THEN
        v_columns := v_json_obj.get_String('columns');
        v_values  := v_json_obj.get_String('values');
      ELSIF v_query_type = c_query_type_update THEN
        v_set_clause := v_json_obj.get_String('set_clause');
      END IF;

      parse_json_conditions(v_json_obj, v_join_conditions, v_where_conditions, v_subquery_conditions, v_group_by);
      v_filter_clause := build_filter_clause(v_join_conditions, v_where_conditions, v_subquery_conditions);

      execute_dml(v_query_type, v_table, v_columns, v_values, v_set_clause, v_filter_clause, p_rows, p_message);
    END;

  -- Обработка DDL (CREATE TABLE, DROP TABLE)
  ELSIF v_query_type = c_query_type_ddl THEN
    DECLARE
      v_ddl_command      VARCHAR2(50);
      v_table           VARCHAR2(100);
      v_fields          VARCHAR2(32767);
      v_generate_trigger VARCHAR2(5);
      v_trigger_name    VARCHAR2(100);
      v_pk_field        VARCHAR2(100);
      v_sequence_name   VARCHAR2(100);
    BEGIN
      v_ddl_command := UPPER(v_json_obj.get_String('ddl_command'));
      v_table := v_json_obj.get_String('table');

      IF v_ddl_command = 'CREATE TABLE' THEN
        v_fields := v_json_obj.get_String('fields');
        v_query := 'CREATE TABLE ' || v_table || ' (' || v_fields || ')';
        EXECUTE IMMEDIATE v_query;
        p_message := 'Таблица ' || v_table || ' создана.';
        p_rows    := 0;
        p_cursor  := NULL;

        BEGIN
          v_generate_trigger := v_json_obj.get_String('generate_trigger');
        EXCEPTION WHEN NO_DATA_FOUND THEN
          v_generate_trigger := 'false';
        END;

        IF LOWER(v_generate_trigger) = 'true' THEN
          v_trigger_name  := v_json_obj.get_String('trigger_name');
          v_pk_field      := v_json_obj.get_String('pk_field');
          v_sequence_name := v_json_obj.get_String('sequence_name');
          create_trigger(v_table, v_trigger_name, v_pk_field, v_sequence_name, p_message);
        END IF;

      ELSIF v_ddl_command = 'DROP TABLE' THEN
        v_query := 'DROP TABLE ' || v_table;
        EXECUTE IMMEDIATE v_query;
        p_message := 'Таблица ' || v_table || ' удалена.';
        p_rows    := 0;
        p_cursor  := NULL;
      ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Не поддерживаемая DDL команда: ' || v_ddl_command);
      END IF;
    END;

  ELSE
    RAISE_APPLICATION_ERROR(-20001, 'Не поддерживаемый тип запроса: ' || v_query_type);
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    p_message := 'Ошибка: ' || SQLERRM;
    p_rows    := 0;
    p_cursor  := NULL;
END dynamic_sql_executor;
/