CREATE OR REPLACE PACKAGE Report_PKG IS
    PROCEDURE Create_Report(p_start_time IN TIMESTAMP);
    PROCEDURE Create_Report;
END Report_PKG;
/

CREATE OR REPLACE PACKAGE BODY Report_PKG IS
    last_report_time TIMESTAMP := TO_TIMESTAMP('1900-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS');

    PROCEDURE Create_Report(p_start_time IN TIMESTAMP) IS
        v_ins_authors    NUMBER;
        v_upd_authors    NUMBER;
        v_del_authors    NUMBER;
        v_ins_books      NUMBER;
        v_upd_books      NUMBER;
        v_del_books      NUMBER;
        v_ins_copies     NUMBER;
        v_upd_copies     NUMBER;
        v_del_copies     NUMBER;
        v_report         VARCHAR2(4000);
    BEGIN
        -- Подсчет изменений для Authors
        SELECT COUNT(*) INTO v_ins_authors FROM Audit_Log WHERE table_name = 'AUTHORS' AND operation_type = 'I' AND change_time >= p_start_time;
        SELECT COUNT(*) INTO v_upd_authors FROM Audit_Log WHERE table_name = 'AUTHORS' AND operation_type = 'U' AND change_time >= p_start_time;
        SELECT COUNT(*) INTO v_del_authors FROM Audit_Log WHERE table_name = 'AUTHORS' AND operation_type = 'D' AND change_time >= p_start_time;

        -- Подсчет изменений для Books
        SELECT COUNT(*) INTO v_ins_books FROM Audit_Log WHERE table_name = 'BOOKS' AND operation_type = 'I' AND change_time >= p_start_time;
        SELECT COUNT(*) INTO v_upd_books FROM Audit_Log WHERE table_name = 'BOOKS' AND operation_type = 'U' AND change_time >= p_start_time;
        SELECT COUNT(*) INTO v_del_books FROM Audit_Log WHERE table_name = 'BOOKS' AND operation_type = 'D' AND change_time >= p_start_time;

        -- Подсчет изменений для Book_Copies
        SELECT COUNT(*) INTO v_ins_copies FROM Audit_Log WHERE table_name = 'BOOK_COPIES' AND operation_type = 'I' AND change_time >= p_start_time;
        SELECT COUNT(*) INTO v_upd_copies FROM Audit_Log WHERE table_name = 'BOOK_COPIES' AND operation_type = 'U' AND change_time >= p_start_time;
        SELECT COUNT(*) INTO v_del_copies FROM Audit_Log WHERE table_name = 'BOOK_COPIES' AND operation_type = 'D' AND change_time >= p_start_time;

        -- Формирование отчета
        v_report := '<html><head><title>Change report</title></head><body>';
        v_report := v_report || '<h1>Change report from ' || TO_CHAR(p_start_time, 'YYYY-MM-DD HH24:MI:SS') || '</h1>';
        v_report := v_report || '<table border="1" cellspacing="0" cellpadding="4">';
        v_report := v_report || '<tr><th>Table</th><th>INSERT</th><th>UPDATE</th><th>DELETE</th></tr>';
        v_report := v_report || '<tr><td>AUTHORS</td><td>' || v_ins_authors || '</td><td>' || v_upd_authors || '</td><td>' || v_del_authors || '</td></tr>';
        v_report := v_report || '<tr><td>BOOKS</td><td>' || v_ins_books || '</td><td>' || v_upd_books || '</td><td>' || v_del_books || '</td></tr>';
        v_report := v_report || '<tr><td>BOOK_COPIES</td><td>' || v_ins_copies || '</td><td>' || v_upd_copies || '</td><td>' || v_del_copies || '</td></tr>';
        v_report := v_report || '</table></body></html>';

        -- Сохранение отчета
        INSERT INTO Reports_Logs (report_date, report_content) VALUES (SYSTIMESTAMP, v_report);
        COMMIT;

        DBMS_OUTPUT.PUT_LINE(v_report);
        last_report_time := SYSTIMESTAMP;
    END Create_Report;

    PROCEDURE Create_Report IS
    BEGIN
        Create_Report(last_report_time);
    END Create_Report;
END Report_PKG;
/