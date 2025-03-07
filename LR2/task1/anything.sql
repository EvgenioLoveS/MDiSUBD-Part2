DROP TABLE GROUPS;
DROP TABLE STUDENTS;
DROP TABLE STUDENTS_LOG;


DELETE GROUPS;
DELETE STUDENTS;
DELETE STUDENTS_LOG;

select * from STUDENTS;
select * from GROUPS;
select * from STUDENTS_LOG;

INSERT INTO GROUPS (ID, NAME, C_VAL) VALUES (1,'Group B', 0);
INSERT INTO GROUPS (ID, NAME, C_VAL) VALUES (2, 'Group B', 0);

INSERT INTO STUDENTS (ID, NAME, GROUP_ID) VALUES (1, 'Name1Group1', 1);
INSERT INTO STUDENTS (ID, NAME, GROUP_ID) VALUES (2, 'Name2Group1', 1);
INSERT INTO STUDENTS (ID, NAME, GROUP_ID) VALUES (3, 'Name3Group1', 1);
INSERT INTO STUDENTS (ID, NAME, GROUP_ID) VALUES (3, 'Name1Group2', 2);
INSERT INTO STUDENTS (ID, NAME, GROUP_ID) VALUES (4, 'Name2Group2', 2);

DELETE FROM GROUPS WHERE ID = 1;

BEGIN
    restore_students(p_offset => INTERVAL '15' SECOND);
END;
/

BEGIN
    restore_students(p_offset => INTERVAL '2' MINUTE);
END;
/

BEGIN
    restore_students(p_time => TO_TIMESTAMP('2025-02-23 15:29:01.527000', 'YYYY-MM-DD HH24:MI:SS.FF'));
END;
/

