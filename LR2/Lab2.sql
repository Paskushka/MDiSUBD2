CREATE USER C##pask IDENTIFIED BY password;
GRANT CONNECT, RESOURCE TO C##pask;
ALTER USER C##pask DEFAULT TABLESPACE users;

ALTER SESSION SET CURRENT_SCHEMA = C##pask;
CONNECT C##pask/password;
ALTER USER C##pask QUOTA UNLIMITED ON USERS;
SELECT USER FROM dual;
GRANT CREATE SESSION TO C##pask;

/*Test*/
SELECT * FROM GROUPS;
SELECT * FROM STUDENTS;

DROP TABLE GROUPS
DROP TABLE STUDENTS

DELETE FROM groups WHERE group_id = 5;
DELETE FROM students WHERE student_id = 5;

INSERT INTO groups (group_id, group_name) VALUES (5, 'Oe');
INSERT INTO groups (group_name) VALUES ('Two');
INSERT INTO groups (group_name) VALUES ('Three');
INSERT INTO groups (group_name) VALUES ('Four');

INSERT INTO groups (group_name) VALUES ('Five');
INSERT INTO groups (group_name) VALUES ('NINE');

INSERT INTO students (student_id, student_name, group_id) VALUES (2, '1', 3);
INSERT INTO students (student_name, group_id) VALUES ('2', 2);
INSERT INTO students (student_name, group_id) VALUES ('3', 3);
INSERT INTO students (student_name, group_id) VALUES ('4', 1);

INSERT INTO students (student_name, group_id) VALUES ('5', 2);
UPDATE students SET group_id = 2 WHERE student_id = 1;
DELETE FROM students WHERE student_id = 5;
SELECT * FROM students_logs;

BEGIN
    restore_students_from_logs(NULL, INTERVAL '1' MINUTE);
END;
/

BEGIN
    restore_students_from_logs(TIMESTAMP '2025-03-10 18:17:33', NULL);
END;
/

/*///////////Task1/////////*/


CREATE TABLE groups (
    group_id NUMBER NOT NULL,
    group_name VARCHAR2(20) NOT NULL,
    C_VAL NUMBER DEFAULT 0 NOT NULL
);

CREATE TABLE students (
    student_id NUMBER NOT NULL,
    student_name VARCHAR2(20) NOT NULL,
    group_id NUMBER NOT NULL
);

/*///////////Task2/////////*/

CREATE SEQUENCE seq_group_id START WITH 1;
CREATE SEQUENCE seq_student_id START WITH 1;

DROP SEQUENCE seq_group_id;
DROP SEQUENCE seq_student_id;

CREATE OR REPLACE TRIGGER trg_auto_group_id
BEFORE INSERT ON groups
FOR EACH ROW
BEGIN
    IF :NEW.group_id IS NULL THEN
        :NEW.group_id := seq_group_id.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_auto_student_id
BEFORE INSERT ON students
FOR EACH ROW
BEGIN
    IF :NEW.student_id IS NULL THEN
   :NEW.student_id := seq_student_id.NEXTVAL;
    END IF;
END;
/


CREATE OR REPLACE TRIGGER trg_unique_group_id
BEFORE INSERT OR UPDATE ON groups
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    IF INSERTING THEN
        SELECT COUNT(*) INTO v_count FROM groups WHERE group_id = :NEW.group_id;
        
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Ошибка: group_id должен быть уникальным');
        END IF;
    END IF;
    
    IF UPDATING THEN
        NULL; 
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_unique_student_id
BEFORE INSERT ON students
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;  
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM students WHERE student_id = :NEW.student_id;
    
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Ошибка: student_id должен быть уникальным');
    END IF;
    COMMIT;  
END;
/

CREATE OR REPLACE TRIGGER trg_unique_group_name
BEFORE INSERT ON groups
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;  
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM groups WHERE LOWER(group_name) = LOWER(:NEW.group_name); 
    
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Ошибка: Название группы должно быть уникальным');
    END IF;
    COMMIT;  
END;
/

/*///////////Task3/////////*/

CREATE OR REPLACE PACKAGE global_variables AS
    check_delete BOOLEAN := FALSE;
END global_variables;
/

CREATE OR REPLACE TRIGGER trg_delete_group_cascade
AFTER DELETE ON groups
FOR EACH ROW
BEGIN
    global_variables.check_delete := TRUE;
    
    DELETE FROM students
    WHERE group_id = :OLD.group_id;  

    global_variables.check_delete := FALSE;
EXCEPTION
    WHEN OTHERS THEN
        global_variables.check_delete := FALSE;
        RAISE;
END;
/

CREATE OR REPLACE TRIGGER trg_check_group_exists
BEFORE INSERT OR UPDATE ON students
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM groups 
    WHERE group_id = :NEW.group_id;  

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20000, 'Ошибка: Группа с ID ' || :NEW.group_id || ' не существует.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER prevent_group_id_update
BEFORE UPDATE OF group_id ON groups
FOR EACH ROW
DECLARE
    students_exist NUMBER;
BEGIN
    SELECT COUNT(*) INTO students_exist
    FROM students
    WHERE group_id = :OLD.group_id;

    IF students_exist > 0 THEN
        RAISE_APPLICATION_ERROR(-20000, 'Ошибка: У этой группы есть студенты. Изменение group_id запрещено.');
    END IF;
END;
/



/*///////////Task4/////////*/

CREATE OR REPLACE PACKAGE student_ctx AS
    TYPE t_group_name_table IS TABLE OF VARCHAR2(255) INDEX BY BINARY_INTEGER;
    g_group_names t_group_name_table;
    PROCEDURE load_group_name(p_group_id NUMBER, p_group_name VARCHAR2);
END student_ctx;
/

CREATE OR REPLACE PACKAGE BODY student_ctx AS
    PROCEDURE load_group_name(p_group_id NUMBER, p_group_name VARCHAR2) IS
    BEGIN
        g_group_names(p_group_id) := p_group_name;
    END load_group_name;
END student_ctx;
/

CREATE OR REPLACE TRIGGER cache_group_on_insert
AFTER INSERT OR UPDATE ON groups
FOR EACH ROW
BEGIN
    student_ctx.load_group_name(:NEW.group_id, :NEW.group_name);
END;
/

CREATE TABLE students_logs (
    LOG_ID NUMBER PRIMARY KEY,
    ACTION_TYPE VARCHAR2(10),
    OLD_ID NUMBER,
    NEW_ID NUMBER,
    OLD_NAME VARCHAR2(10),
    NEW_NAME VARCHAR2(10),
    OLD_GROUP_ID NUMBER,
    NEW_GROUP_ID NUMBER,
    OLD_GROUP_NAME VARCHAR2(10),
    NEW_GROUP_NAME VARCHAR2(10),
    ACTION_TIME TIMESTAMP
);


CREATE SEQUENCE STUDENTS_LOGS_SEQ START WITH 1
/

CREATE OR REPLACE TRIGGER log_student_changes
AFTER INSERT OR UPDATE OR DELETE ON students
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO students_logs (LOG_ID, ACTION_TYPE, NEW_ID, NEW_NAME, NEW_GROUP_ID, NEW_GROUP_NAME, ACTION_TIME)
        VALUES (STUDENTS_LOGS_SEQ.NEXTVAL, 'INSERT', :NEW.student_id, :NEW.student_name, :NEW.group_id, student_ctx.g_group_names(:NEW.group_id), SYSTIMESTAMP);
    ELSIF UPDATING THEN
        INSERT INTO students_logs (LOG_ID, ACTION_TYPE, OLD_ID, NEW_ID, OLD_NAME, NEW_NAME, OLD_GROUP_ID, OLD_GROUP_NAME, NEW_GROUP_ID, NEW_GROUP_NAME, ACTION_TIME)
        VALUES (STUDENTS_LOGS_SEQ.NEXTVAL, 'UPDATE', :OLD.student_id, :NEW.student_id, :OLD.student_name, :NEW.student_name, :OLD.group_id, student_ctx.g_group_names(:OLD.group_id), :NEW.group_id, student_ctx.g_group_names(:NEW.group_id), SYSTIMESTAMP);
    ELSIF DELETING THEN
        INSERT INTO students_logs (LOG_ID, ACTION_TYPE, OLD_ID, OLD_NAME, OLD_GROUP_ID, OLD_GROUP_NAME, ACTION_TIME)
        VALUES (STUDENTS_LOGS_SEQ.NEXTVAL, 'DELETE', :OLD.student_id, :OLD.student_name, :OLD.group_id, student_ctx.g_group_names(:OLD.group_id), SYSTIMESTAMP);
    END IF;
END;
/


/*///////////Task5/////////*/


CREATE OR REPLACE PROCEDURE restore_students_from_logs(
    p_time TIMESTAMP DEFAULT NULL,
    p_offset INTERVAL DAY TO SECOND DEFAULT NULL
) IS
    v_restore_time TIMESTAMP;
    v_group_exists NUMBER; 
    v_student_exists NUMBER;
    v_count_deleted NUMBER := 0;
BEGIN
    IF p_time IS NOT NULL THEN
        v_restore_time := p_time;
    ELSIF p_offset IS NOT NULL THEN
        v_restore_time := SYSTIMESTAMP - p_offset;
    ELSE
        RAISE_APPLICATION_ERROR(-20000, 'Нужно передать либо p_time, либо p_offset.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('Восстанавливаем данные с ' || TO_CHAR(v_restore_time, 'DD-MM-YYYY HH24:MI:SS'));

    SELECT COUNT(*) INTO v_count_deleted
    FROM students_logs
    WHERE action_time >= v_restore_time
      AND action_type = 'DELETE';

    IF v_count_deleted = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Нет записей DELETE в students_logs. Восстановление не требуется.');
        RETURN;
    END IF;

    FOR record IN (
        SELECT * FROM students_logs
        WHERE action_time >= v_restore_time
          AND action_type = 'DELETE'
        ORDER BY action_time DESC
    ) LOOP
        SELECT COUNT(*) INTO v_student_exists
        FROM students
        WHERE student_id = record.old_id;

        IF v_student_exists = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TRIGGER trg_check_group_exists DISABLE';

            SELECT COUNT(*) INTO v_group_exists
            FROM groups
            WHERE group_id = record.old_group_id;

            IF v_group_exists > 0 THEN
                INSERT INTO students (student_id, student_name, group_id)
                VALUES (record.old_id, record.old_name, record.old_group_id);
                DBMS_OUTPUT.PUT_LINE('Восстановлен студент: ' || record.old_id || ' - ' || record.old_name || ' в группу  c id' || record.old_group_id);
            ELSE
                SELECT group_id INTO record.old_group_id
                FROM (
                    SELECT group_id
                    FROM groups g
                    ORDER BY (SELECT COUNT(*) FROM students s WHERE s.group_id = g.group_id) ASC
                )
                WHERE ROWNUM = 1;

                INSERT INTO students (student_id, student_name, group_id)
                VALUES (record.old_id, record.old_name, record.old_group_id);
                DBMS_OUTPUT.PUT_LINE('Восстановлен студент: ' || record.old_id || ' - ' || record.old_name || ' в группу с id: ' || record.old_group_id);
            END IF;

            EXECUTE IMMEDIATE 'ALTER TRIGGER trg_check_group_exists ENABLE';
        ELSE
            DBMS_OUTPUT.PUT_LINE('Студент ' || record.old_id || ' уже существует, пропускаем.');
        END IF;
    END LOOP;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: ' || SQLERRM);
        ROLLBACK;
END;
/

/*///////////Task6/////////*/


CREATE OR REPLACE TRIGGER trg_update_c_val_on_insert
BEFORE INSERT ON students
FOR EACH ROW
BEGIN
    UPDATE groups
    SET c_val = c_val + 1
    WHERE group_id = :NEW.group_id;
END;
/

CREATE OR REPLACE TRIGGER trg_update_c_val_on_delete
BEFORE DELETE ON students
FOR EACH ROW
BEGIN
    IF NOT global_variables.check_delete THEN
        UPDATE groups
        SET c_val = c_val - 1
        WHERE group_id = :OLD.group_id;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_update_c_val_on_update
BEFORE UPDATE OF group_id ON students
FOR EACH ROW
BEGIN
    IF :OLD.group_id != :NEW.group_id THEN
        UPDATE groups
        SET c_val = c_val - 1
        WHERE group_id = :OLD.group_id;
        UPDATE groups
        SET c_val = c_val + 1
        WHERE group_id = :NEW.group_id;
    END IF;
END;
/