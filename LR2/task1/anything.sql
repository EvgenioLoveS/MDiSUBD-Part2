-- Дроп таблицы --

DROP TABLE GROUPS;
DROP TABLE STUDENTS;
DROP TABLE STUDENTS_AUDIT;

-- Тест первой таски --

select * from STUDENTS;
select * from GROUPS;
select * from STUDENTS_AUDIT;

-- Тест второй таски --

-- Попытка вставить дублирующееся имя группы
INSERT INTO GROUPS (NAME) VALUES ('Group B');
-- Попытка вставить дублирующийся ID группы
INSERT INTO GROUPS (ID, NAME) VALUES (1, 'Group B'); -- Ошибка: "Группа с таким ID уже существует!"
-- Попытка вставить дублирующийся ID студента
INSERT INTO STUDENTS (ID, NAME, GROUP_ID) VALUES (2, 'Jane Doe', 1); -- Ошибка: "Студент с таким ID уже существует!"

-- Тест третьей таски --

-- Вставляем студентов в группу
INSERT INTO STUDENTS (NAME, GROUP_ID) VALUES ('John 1', 2);
INSERT INTO STUDENTS (NAME, GROUP_ID) VALUES ('Jane 2', 2);
-- Удаляем группу
DELETE FROM GROUPS WHERE ID = 2;

-- Тест четвертой таски --

INSERT INTO STUDENTS (NAME, GROUP_ID) VALUES ('NameOfGroup1', 1);

-- Тест пятой таски --
INSERT INTO GROUPS (NAME) VALUES ('Group A');
INSERT INTO STUDENTS (NAME, GROUP_ID) VALUES ('Anna', 1);
INSERT INTO STUDENTS (NAME, GROUP_ID) VALUES ( 'Dima', 1);
INSERT INTO STUDENTS (NAME, GROUP_ID) VALUES ( 'Zhenya', 1);
UPDATE STUDENTS SET NAME = 'Jane Smith' WHERE ID = 2;
DELETE FROM STUDENTS WHERE ID = 1;

CALL restore_students_to_time(TO_TIMESTAMP('2025-02-10 21:30:26.745000', 'YYYY-MM-DD HH24:MI:SS.FF'));
CALL restore_students_to_offset(199);

-- Тест шестой таски --

INSERT INTO GROUPS (NAME,C_VAL) VALUES ('Group A', 0);

INSERT INTO STUDENTS (ID, NAME, GROUP_ID) VALUES (1, 'test2', 5);

DELETE FROM STUDENTS WHERE id = 2;

DELETE STUDENTS_AUDIT;
DELETE GROUPS;
DELETE STUDENTS;
