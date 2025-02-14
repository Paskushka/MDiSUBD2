CREATE TABLE MyTable (
    id NUMBER PRIMARY KEY,
    val NUMBER
);

SELECT * FROM MyTable;

DROP TABLE MyTable;



DECLARE
    num NUMBER;
BEGIN
    FOR i IN 1..10000 LOOP
        num := MOD(DBMS_RANDOM.RANDOM, 100) + 1;
        
        INSERT INTO MyTable (id, val) 
        VALUES (i, num);
    END LOOP;
    
    COMMIT;
END;



CREATE OR REPLACE FUNCTION Task3
RETURN VARCHAR2
IS
    even NUMBER := 0;
    odd NUMBER := 0;
BEGIN
    SELECT COUNT(CASE WHEN MOD(val, 2) = 0 THEN 1 END),
           COUNT(CASE WHEN MOD(val, 2) = 1 OR MOD(val, 2) = -1 THEN 1 END)
    INTO even, odd
    FROM MyTable;

    IF even > odd THEN
        RETURN 'TRUE';
    ELSIF odd > even THEN
        RETURN 'FALSE';
    ELSE
        RETURN 'EQUAL';
    END IF;
END;


BEGIN
    DBMS_OUTPUT.PUT_LINE(Task3());
END;



CREATE OR REPLACE FUNCTION Task4(new_id NUMBER)
RETURN VARCHAR2
IS
    new_val VARCHAR2(4000);
    new_command VARCHAR2(4000);
BEGIN
    SELECT val INTO new_val
    FROM MyTable
    WHERE id = new_id;

    new_command := 'INSERT INTO MyTable (id, val) VALUES (' || 
                        new_id || ', ''' || new_val || ''');';

    RETURN new_command;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'Нет записи для ID: ' || new_id;
    WHEN OTHERS THEN
        RETURN 'Ошибка';
END;



BEGIN
    DBMS_OUTPUT.PUT_LINE(Task4(1));
END;



CREATE OR REPLACE PROCEDURE InsertTable (new_val IN NUMBER) AS 
    new_id NUMBER;
BEGIN
    SELECT COALESCE(MAX(id), 0) + 1 INTO new_id FROM MyTable;

    INSERT INTO MyTable (id, val)
    VALUES (new_id, new_val);
    COMMIT;
END InsertTable;



CREATE OR REPLACE PROCEDURE UpdateTable (new_id IN NUMBER, new_val IN NUMBER) AS
BEGIN
    UPDATE MyTable
    SET val = new_val
    WHERE id = new_id;
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Такого ID не существует.');
    ELSE
        COMMIT;
    END IF;
END UpdateTable;




CREATE OR REPLACE PROCEDURE DeleteTable (new_id IN NUMBER) AS
BEGIN
    DELETE FROM MyTable
    WHERE id = new_id;
    IF SQL%ROWCOUNT > 0 THEN
        UPDATE MyTable
        SET id = id - 1
        WHERE id > new_id;

        COMMIT;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Такого ID не существует.');
    END IF;
END DeleteTable;



BEGIN
    InsertTable(100);
END;

BEGIN
    UpdateTable(2, 200);
END;

BEGIN
    DeleteTable(10);
END;



CREATE OR REPLACE FUNCTION Task6 (salary IN NUMBER,bonus IN NUMBER) RETURN NUMBER AS
    reward NUMBER;
BEGIN
    IF salary IS NULL OR bonus IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Ввод не может быть null');
        RETURN NULL;
    END IF;

    IF salary <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Зарплата не может быть отрицательной');
        RETURN NULL;
    END IF;

    IF bonus < 0 THEN
        DBMS_OUTPUT.PUT_LINE('Процент годовых перемиальных не может быть отрицательным');
        RETURN NULL;
    END IF;

    IF TRUNC(bonus) != bonus THEN
        DBMS_OUTPUT.PUT_LINE('Процент годовых перемиальных должен быть целым числом');
        RETURN NULL;
    END IF;

    reward := (1 + bonus / 100) * 12 *salary;

    RETURN reward;
END Task6;

BEGIN
    DBMS_OUTPUT.PUT_LINE(Task6(10, 9));
END;