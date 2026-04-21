-- Триггер 1: Проверка суммы при оформлении документа займа
-- 1) Сумма займа не превышает максимум для типа отделения
-- 2) Общий долг клиента по активным займам — не более 2 млн рублей
CREATE OR REPLACE FUNCTION trg_check_сумма_займа()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_макс_сумма  DECIMAL(15,2);
    v_долг_клиента DECIMAL(15,2);
    v_оплаченная_основа DECIMAL(15,2);
BEGIN
    SELECT то.Макс_сумма INTO v_макс_сумма
    FROM Отделение о
    JOIN Тип_отделения то ON о.ID_Типа = то.ID_Типа
    WHERE о.ID_Отделения = NEW.ID_Отделения;
    IF NEW.Сумма_займа > v_макс_сумма THEN
        RAISE EXCEPTION 'Сумма займа (%) превышает лимит отделения (%)',
            NEW.Сумма_займа, v_макс_сумма;
    END IF;

    SELECT COALESCE(SUM(Сумма_займа), 0) INTO v_долг_клиента
    FROM Документ_займа
    WHERE ID_Клиента = NEW.ID_Клиента
      AND Текущий_статус NOT IN ('Закрыт', 'Передан');

    SELECT COALESCE(SUM(п.Остаток_погашения_основы), 0) INTO v_оплаченная_основа
    FROM План_выплат п
    JOIN Документ_займа дз ON п.ID_Займа = дз.ID_Займа
    WHERE дз.ID_Клиента = NEW.ID_Клиента
      AND дз.Текущий_статус NOT IN ('Закрыт', 'Передан')
      AND (п.Статус_исполнения = 'Оплачено' OR п.ID_Платежа IS NOT NULL);

    v_долг_клиента := v_долг_клиента - v_оплаченная_основа;

    IF v_долг_клиента + NEW.Сумма_займа > 2000000 THEN
        RAISE EXCEPTION 'Клиент уже должен % руб. Новый заём (%) превысит лимит 2 000 000',
            v_долг_клиента, NEW.Сумма_займа;
    END IF;
    RAISE NOTICE 'Займ ID=% выдан, сумма % руб., отделение ID=%, лимит отделения %',
        NEW.ID_Займа, NEW.Сумма_займа, NEW.ID_Отделения, v_макс_сумма;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_сумма_займа ON Документ_займа;
CREATE TRIGGER trg_check_сумма_займа
BEFORE INSERT ON Документ_займа
FOR EACH ROW
EXECUTE FUNCTION trg_check_сумма_займа();

-- Триггер 2: Проверка оплаты пункта плана выплат
-- 1) Сумма оплаченных пунктов не превышает сумму займа
-- 2) При оплате последнего пункта заём переходит в статус «Закрыт»
CREATE OR REPLACE FUNCTION trg_check_оплата_плана()
RETURNS trigger
LANGUAGE plpgsql
AS $$
    DECLARE
        v_сумма_платежа  DECIMAL(15,2);
        v_уже_оплачено   DECIMAL(15,2);
        v_текущий_пункт  DECIMAL(15,2);
        v_осталось       INT;
    BEGIN
        SELECT Внесенная_сумма INTO v_сумма_платежа
        FROM Платёжный_документ WHERE ID_Платежа = NEW.ID_Платежа;

        SELECT COALESCE(SUM(Остаток_погашения_основы + Остаток_погашения_процентов + Остаток_погашения_штрафа), 0) INTO v_уже_оплачено
        FROM План_выплат
        WHERE ID_Платежа = NEW.ID_Платежа AND ID_Плана <> NEW.ID_Плана;
        
        v_текущий_пункт := NEW.Остаток_погашения_основы + NEW.Остаток_погашения_процентов + NEW.Остаток_погашения_штрафа;
        
        IF v_уже_оплачено + v_текущий_пункт > v_сумма_платежа THEN
            RAISE EXCEPTION 'Оплата превысит сумму платежного документа. Уже оплачено: %, текущий пункт: %, лимит: %',
                v_уже_оплачено, v_текущий_пункт, v_сумма_платежа;
        END IF;
    SELECT COUNT(*) INTO v_осталось
    FROM План_выплат
    WHERE ID_Займа = NEW.ID_Займа AND ID_Платежа IS NULL AND ID_Плана <> NEW.ID_Плана;

    IF v_осталось = 0 THEN
        UPDATE Документ_займа SET Текущий_статус = 'Закрыт' WHERE ID_Займа = NEW.ID_Займа;
        RAISE NOTICE 'Заём ID=% полностью погашен, статус - Закрыт', NEW.ID_Займа;
    ELSE
        RAISE NOTICE 'Пункт ID=% оплачен, осталось пунктов: %', NEW.ID_Плана, v_осталось;
    END IF;
    NEW.Статус_исполнения := 'Оплачено';
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_оплата_плана ON План_выплат;
CREATE TRIGGER trg_check_оплата_плана
BEFORE UPDATE ON План_выплат
FOR EACH ROW
WHEN (OLD.ID_Платежа IS NULL AND NEW.ID_Платежа IS NOT NULL)
EXECUTE FUNCTION trg_check_оплата_плана();