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

select * from STUDENTS;