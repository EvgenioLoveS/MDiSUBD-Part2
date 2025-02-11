-- Создание таблицы GROUPS
CREATE TABLE GROUPS (
    ID NUMBER PRIMARY KEY,          -- Код группы (первичный ключ)
    NAME VARCHAR2(100) NOT NULL,    -- Название группы
    C_VAL NUMBER DEFAULT 0          -- Количество студентов в группе (по умолчанию 0)
);

-- Создание таблицы STUDENTS
CREATE TABLE STUDENTS (
    ID NUMBER PRIMARY KEY,          -- Код студента (первичный ключ)
    NAME VARCHAR2(100) NOT NULL,    -- Имя студента
    GROUP_ID NUMBER,                -- Код группы (внешний ключ)
    CONSTRAINT fk_group FOREIGN KEY (GROUP_ID) REFERENCES GROUPS(ID) -- Внешний ключ на таблицу GROUPS
);

-- Таблица для журналирования действий над таблицей STUDENTS
CREATE TABLE STUDENTS_AUDIT (
    AUDIT_ID      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Уникальный идентификатор записи
    OPERATION     VARCHAR2(10) NOT NULL,                           -- Тип операции (INSERT, UPDATE, DELETE)
    STUDENT_ID    NUMBER,                                          -- Код студента
    OLD_NAME      VARCHAR2(100),                                   -- Старое значение имени (для UPDATE и DELETE)
    NEW_NAME      VARCHAR2(100),                                   -- Новое значение имени (для INSERT и UPDATE)
    OLD_GROUP_ID  NUMBER,                                          -- Старое значение группы (для UPDATE и DELETE)
    NEW_GROUP_ID  NUMBER,                                          -- Новое значение группы (для INSERT и UPDATE)
    OPERATION_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP             -- Дата и время операции
);

