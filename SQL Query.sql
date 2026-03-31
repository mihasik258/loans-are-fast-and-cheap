CREATE EXTENSION IF NOT EXISTS tablefunc;

-- запрос 1: план выплат на следующую неделю
SELECT v.Клиент, v.Общая_задолженность, v.Погашено, v.Выплатить_за_неделю, pd.Пн, pd.Вт, pd.Ср, pd.Чт, pd.Пт, pd.Сб, pd.Вс
FROM (
    SELECT к.Фамилия || ' ' || к.Имя AS Клиент,
        SUM(п.Остаток_погашения_основы + п.Остаток_погашения_процентов + п.Остаток_погашения_штрафа) AS Общая_задолженность,
        SUM(CASE WHEN п.Статус_исполнения = 'Оплачено' THEN п.Остаток_погашения_основы + п.Остаток_погашения_процентов ELSE 0 END) AS Погашено,
        SUM(CASE WHEN п.Плановая_дата_оплаты BETWEEN CAST(date_trunc('week', CURRENT_DATE) AS DATE) + 7 AND CAST(date_trunc('week', CURRENT_DATE) AS DATE) + 13 THEN п.Остаток_погашения_основы + п.Остаток_погашения_процентов ELSE 0 END) AS Выплатить_за_неделю
    FROM План_выплат п
    JOIN Документ_займа з ON п.id_Займа = з.id_Займа
    JOIN Клиент к ON з.id_Клиента = к.id_Клиента
    GROUP BY к.Фамилия, к.Имя
    HAVING SUM(CASE WHEN п.Плановая_дата_оплаты BETWEEN CAST(date_trunc('week', CURRENT_DATE) AS DATE) + 7 AND CAST(date_trunc('week', CURRENT_DATE) AS DATE) + 13 THEN 1 ELSE 0 END) > 0
) v
JOIN crosstab(
    'SELECT к.Фамилия || '' '' || к.Имя,
        CASE EXTRACT(ISODOW FROM п.Плановая_дата_оплаты) WHEN 1 THEN ''1_Пн'' WHEN 2 THEN ''2_Вт'' WHEN 3 THEN ''3_Ср'' WHEN 4 THEN ''4_Чт'' WHEN 5 THEN ''5_Пт'' WHEN 6 THEN ''6_Сб'' WHEN 7 THEN ''7_Вс'' END,
        ROUND(SUM(п.Остаток_погашения_основы + п.Остаток_погашения_процентов), 2)
    FROM План_выплат п
    JOIN Документ_займа з ON п.id_Займа = з.id_Займа
    JOIN Клиент к ON з.id_Клиента = к.id_Клиента
    WHERE п.Плановая_дата_оплаты BETWEEN CAST(date_trunc(''week'', CURRENT_DATE) AS DATE) + 7 AND CAST(date_trunc(''week'', CURRENT_DATE) AS DATE) + 13
    GROUP BY к.Фамилия, к.Имя, п.Плановая_дата_оплаты ORDER BY 1, 2',
    'VALUES (''1_Пн''),(''2_Вт''),(''3_Ср''),(''4_Чт''),(''5_Пт''),(''6_Сб''),(''7_Вс'')'
) AS pd (Клиент TEXT, Пн NUMERIC, Вт NUMERIC, Ср NUMERIC, Чт NUMERIC, Пт NUMERIC, Сб NUMERIC, Вс NUMERIC) USING (Клиент)
ORDER BY v.Клиент;

-- запрос 2: клиенты с просроченными выплатами
SELECT Клиент, id_Плана, Плановая_дата_оплаты, Дней_просрочки, Пунктов_после, Штраф
FROM (
    SELECT к.Фамилия || ' ' || к.Имя AS Клиент, п.id_Плана, п.Плановая_дата_оплаты, п.Статус_исполнения,
        (CURRENT_DATE - п.Плановая_дата_оплаты) AS Дней_просрочки,
        COUNT(*) OVER (PARTITION BY п.id_Займа ORDER BY п.Плановая_дата_оплаты ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) - 1 AS Пунктов_после,
        ROUND((п.Остаток_погашения_основы + п.Остаток_погашения_процентов) * з.Пени_процент_день * (CURRENT_DATE - п.Плановая_дата_оплаты) / 100.0, 2) AS Штраф
    FROM План_выплат п
    JOIN Документ_займа з ON п.id_Займа = з.id_Займа
    JOIN Клиент к ON з.id_Клиента = к.id_Клиента
) t
WHERE Статус_исполнения = 'Просрочено'
ORDER BY Клиент, Плановая_дата_оплаты;

-- запрос 3: статистика займов по месяцам
SELECT t.Год, t.Месяц, t.Всего_договоров, t.Общая_сумма, t.Уник_клиентов,
    (SELECT со.Фамилия || ' ' || со.Имя 
    FROM Документ_займа з2 
    JOIN Сотрудник со ON з2.id_Бухгалтера = со.id_Сотрудника 
    WHERE CAST(EXTRACT(YEAR FROM з2.Дата_выдачи) AS INTEGER) = t.Год AND CAST(EXTRACT(MONTH FROM з2.Дата_выдачи) AS INTEGER) = t.Месяц 
    GROUP BY со.id_Сотрудника, со.Фамилия, со.Имя 
    ORDER BY COUNT(*) DESC LIMIT 1) AS Лучший_сотрудник,
    (SELECT COUNT(*) 
    FROM Документ_займа з2 
    WHERE CAST(EXTRACT(YEAR FROM з2.Дата_выдачи) AS INTEGER) = t.Год AND CAST(EXTRACT(MONTH FROM з2.Дата_выдачи) AS INTEGER) = t.Месяц 
    GROUP BY з2.id_Бухгалтера ORDER BY COUNT(*) DESC LIMIT 1) AS Кол_у_лучшего
FROM (
    SELECT CAST(EXTRACT(YEAR FROM Дата_выдачи) AS INTEGER) AS Год, CAST(EXTRACT(MONTH FROM Дата_выдачи) AS INTEGER) AS Месяц,
        COUNT(*) AS Всего_договоров, SUM(Сумма_займа) AS Общая_сумма, COUNT(DISTINCT id_Клиента) AS Уник_клиентов
    FROM Документ_займа
    WHERE EXTRACT(YEAR FROM Дата_выдачи) >= EXTRACT(YEAR FROM CURRENT_DATE) - 1
    GROUP BY CAST(EXTRACT(YEAR FROM Дата_выдачи) AS INTEGER), CAST(EXTRACT(MONTH FROM Дата_выдачи) AS INTEGER)
) t
ORDER BY t.Год, t.Месяц;
-- запрос 4: обслуживание клиентов в отделениях
SELECT аг.ФИО, аг.Отделения, аг.Кол_займов, аг.Займов_на_отделение, з.Дата_выдачи AS Дата_последнего, з.Сумма_займа AS Сумма_последнего, то_.Название || ' (' || о.Номер_лицензии || ')' AS Отделение_последнего, аг.Чаще_раза_в_месяц
FROM Документ_займа з
JOIN Клиент к ON з.id_Клиента = к.id_Клиента
JOIN Отделение о ON з.id_Отделения = о.id_Отделения
JOIN Тип_отделения то_ ON о.id_Типа = то_.id_Типа
LEFT JOIN Документ_займа з2 ON з2.id_Клиента = з.id_Клиента AND з2.Дата_выдачи > з.Дата_выдачи
JOIN (
    SELECT з.id_Клиента, к.Фамилия || ' ' || к.Имя AS ФИО, STRING_AGG(DISTINCT то_.Название || ' (' || о.Номер_лицензии || ')', ', ') AS Отделения, COUNT(*) AS Кол_займов, ROUND(CAST(COUNT(*) AS NUMERIC) / COUNT(DISTINCT з.id_Отделения), 2) AS Займов_на_отделение,
        CASE WHEN AVG(интервал) < 30 THEN 'Да' ELSE 'Нет' END AS Чаще_раза_в_месяц
    FROM (
        SELECT з.*, CAST((з.Дата_выдачи - LAG(з.Дата_выдачи) OVER (PARTITION BY з.id_Клиента ORDER BY з.Дата_выдачи)) AS INTEGER) AS интервал
        FROM Документ_займа з
    ) з
    JOIN Клиент к ON з.id_Клиента = к.id_Клиента
    JOIN Отделение о ON з.id_Отделения = о.id_Отделения
    JOIN Тип_отделения то_ ON о.id_Типа = то_.id_Типа
    GROUP BY з.id_Клиента, к.Фамилия, к.Имя
    HAVING COUNT(*) > 1
) аг ON аг.id_Клиента = з.id_Клиента
WHERE з2.id_Займа IS NULL
ORDER BY аг.Кол_займов DESC;

-- запрос 5: коллекторские агентства
SELECT кa.Полное_наименование AS Агентство, COUNT(DISTINCT д.id_Договора) AS Кол_договоров, COUNT(DISTINCT з.id_Клиента) AS Уник_должников,
    SUM(COALESCE(п.Остаток_погашения_основы, 0) + COALESCE(п.Остаток_погашения_процентов, 0) + COALESCE(п.Остаток_погашения_штрафа, 0)) AS Общая_сумма,
    MAX(д.Дата_подписания) AS Дата_последнего,
    (SELECT SUM(COALESCE(п2.Остаток_погашения_основы, 0) + COALESCE(п2.Остаток_погашения_процентов, 0) + COALESCE(п2.Остаток_погашения_штрафа, 0)) 
    FROM Договор_о_сотрудничестве д2 
    JOIN Документ_займа з2 ON д2.id_Займа = з2.id_Займа 
    LEFT JOIN План_выплат п2 ON з2.id_Займа = п2.id_Займа WHERE д2.id_Агентства = кa.id_Агентства 
    GROUP BY д2.id_Договора 
    ORDER BY SUM(COALESCE(п2.Остаток_погашения_основы, 0) + COALESCE(п2.Остаток_погашения_процентов, 0) + COALESCE(п2.Остаток_погашения_штрафа, 0)) DESC LIMIT 1) AS Крупнейшая_задолж,
    (SELECT д2.Дата_подписания 
    FROM Договор_о_сотрудничестве д2 
    JOIN Документ_займа з2 ON д2.id_Займа = з2.id_Займа 
    LEFT JOIN План_выплат п2 ON з2.id_Займа = п2.id_Займа 
    WHERE д2.id_Агентства = кa.id_Агентства 
    GROUP BY д2.id_Договора, д2.Дата_подписания 
    ORDER BY SUM(COALESCE(п2.Остаток_погашения_основы, 0) + COALESCE(п2.Остаток_погашения_процентов, 0) + COALESCE(п2.Остаток_погашения_штрафа, 0)) DESC LIMIT 1) AS Дата_крупнейшей
FROM Коллекторское_агентство кa
JOIN Договор_о_сотрудничестве д ON кa.id_Агентства = д.id_Агентства
JOIN Документ_займа з ON д.id_Займа = з.id_Займа
LEFT JOIN План_выплат п ON з.id_Займа = п.id_Займа
GROUP BY кa.id_Агентства, кa.Полное_наименование
ORDER BY Кол_договоров DESC;