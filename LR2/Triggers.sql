CREATE SEQUENCE seq_group_id START WITH 1;
CREATE SEQUENCE seq_student_id START WITH 1;

CONNECT C##pask/password;

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
AFTER INSERT OR UPDATE ON groups
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;  
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM groups 
    WHERE LOWER(group_name) = LOWER(:NEW.group_name)
    AND group_id <> :NEW.group_id; 
    
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Ошибка: Название группы должно быть уникальным');
    END IF;
    COMMIT;  
END;
/



CREATE OR REPLACE PACKAGE global_variables AS
    is_group_delete_cascade BOOLEAN := FALSE;
END global_variables;
/

CREATE OR REPLACE TRIGGER trg_delete_group_cascade
AFTER DELETE ON groups
FOR EACH ROW
BEGIN
    global_variables.is_group_delete_cascade := TRUE;
    
    DELETE FROM students
    WHERE group_id = :OLD.group_id;  

    global_variables.is_group_delete_cascade := FALSE;
EXCEPTION
    WHEN OTHERS THEN
        global_variables.is_group_delete_cascade := FALSE;
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
    IF NOT global_variables.is_group_delete_cascade THEN
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
