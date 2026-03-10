DROP TABLE IF EXISTS Договор_о_сотрудничестве CASCADE;
DROP TABLE IF EXISTS План_выплат CASCADE;
DROP TABLE IF EXISTS Платёжный_документ CASCADE;
DROP TABLE IF EXISTS Расписка CASCADE;
DROP TABLE IF EXISTS Документ_займа CASCADE;
DROP TABLE IF EXISTS Анкета_клиента CASCADE;
DROP TABLE IF EXISTS Клиент CASCADE;
DROP TABLE IF EXISTS Сотрудник CASCADE;
DROP TABLE IF EXISTS Отделение CASCADE;
DROP TABLE IF EXISTS Коллекторское_агентство CASCADE;
DROP TABLE IF EXISTS Категория_клиента CASCADE;
DROP TABLE IF EXISTS Тип_начисления CASCADE;
DROP TABLE IF EXISTS Должность CASCADE;
DROP TABLE IF EXISTS Тип_отделения CASCADE;
DROP TABLE IF EXISTS Адрес CASCADE;
CREATE TABLE Адрес (
    ID_Адреса SERIAL PRIMARY KEY,
    Город VARCHAR(100) NOT NULL,
    Улица VARCHAR(100) NOT NULL,
    Дом VARCHAR(20) NOT NULL,
    Корпус VARCHAR(10),
    Индекс CHAR(6)
);
CREATE TABLE Тип_отделения (
    ID_Типа SERIAL PRIMARY KEY,
    Название VARCHAR(50) NOT NULL UNIQUE,
    Макс_сумма DECIMAL(15, 2) NOT NULL CHECK (Макс_сумма > 0),
    Код_типа SMALLINT NOT NULL UNIQUE
);
CREATE TABLE Должность (
    ID_Должности SERIAL PRIMARY KEY,
    Название VARCHAR(50) NOT NULL UNIQUE,
    Штатный_код INT NOT NULL UNIQUE,
    Базовый_оклад DECIMAL(15, 2) NOT NULL CHECK (Базовый_оклад >= 0)
);
CREATE TABLE Тип_начисления (
    ID_Типа_начисления SERIAL PRIMARY KEY,
    Название VARCHAR(50) NOT NULL UNIQUE,
    Код SMALLINT NOT NULL UNIQUE
);
CREATE TABLE Категория_клиента (
    ID_Категории SERIAL PRIMARY KEY,
    Название VARCHAR(50) NOT NULL UNIQUE,
    Код SMALLINT NOT NULL UNIQUE
);
CREATE TABLE Отделение (
    ID_Отделения SERIAL PRIMARY KEY,
    Номер_лицензии VARCHAR(50) NOT NULL UNIQUE,
    Дата_выдачи_лицензии DATE NOT NULL,
    ID_Типа INT NOT NULL REFERENCES Тип_отделения(ID_Типа),
    ID_Адреса INT NOT NULL REFERENCES Адрес(ID_Адреса)
);
CREATE TABLE Сотрудник (
    ID_Сотрудника SERIAL PRIMARY KEY,
    Фамилия VARCHAR(50) NOT NULL,
    Имя VARCHAR(50) NOT NULL,
    Отчество VARCHAR(50),
    Паспорт_серия CHAR(4) NOT NULL,
    Паспорт_номер CHAR(6) NOT NULL,
    ИНН CHAR(12) NOT NULL UNIQUE,
    Телефон VARCHAR(15),
    Email VARCHAR(100),
    Дата_найма DATE NOT NULL,
    Дата_увольнения DATE,
    ID_Должности INT NOT NULL REFERENCES Должность(ID_Должности),
    ID_Отделения INT NOT NULL REFERENCES Отделение(ID_Отделения),
    ID_Руководителя INT REFERENCES Сотрудник(ID_Сотрудника),
    CONSTRAINT uq_паспорт_сотрудника UNIQUE (Паспорт_серия, Паспорт_номер),
    CONSTRAINT chk_увольнение CHECK (
        Дата_увольнения IS NULL
        OR Дата_увольнения >= Дата_найма
    )
);
CREATE TABLE Клиент (
    ID_Клиента SERIAL PRIMARY KEY,
    Фамилия VARCHAR(50) NOT NULL,
    Имя VARCHAR(50) NOT NULL,
    Отчество VARCHAR(50),
    Дата_рождения DATE NOT NULL,
    Паспорт_серия CHAR(4) NOT NULL,
    Паспорт_номер CHAR(6) NOT NULL,
    Паспорт_выдан_кем VARCHAR(200),
    Паспорт_дата_выдачи DATE,
    Контактный_телефон VARCHAR(15),
    CONSTRAINT uq_паспорт_клиента UNIQUE (Паспорт_серия, Паспорт_номер)
);
CREATE TABLE Анкета_клиента (
    ID_Анкеты SERIAL PRIMARY KEY,
    Уровень_риска SMALLINT,
    Дата_первого_обращения DATE NOT NULL,
    ID_Клиента INT NOT NULL REFERENCES Клиент(ID_Клиента),
    ID_Отделения INT NOT NULL REFERENCES Отделение(ID_Отделения),
    ID_Регистратора INT NOT NULL REFERENCES Сотрудник(ID_Сотрудника),
    ID_Категории INT NOT NULL REFERENCES Категория_клиента(ID_Категории),
    CONSTRAINT uq_клиент_отделение UNIQUE (ID_Клиента, ID_Отделения)
);
CREATE TABLE Коллекторское_агентство (
    ID_Агентства SERIAL PRIMARY KEY,
    Полное_наименование VARCHAR(150) NOT NULL,
    Краткое_наименование VARCHAR(50),
    ИНН_Агентства CHAR(10) NOT NULL UNIQUE,
    Контактный_телефон VARCHAR(15),
    ID_Адреса INT NOT NULL REFERENCES Адрес(ID_Адреса)
);
CREATE TABLE Документ_займа (
    ID_Займа SERIAL PRIMARY KEY,
    Дата_выдачи DATE NOT NULL,
    Сумма_займа DECIMAL(15, 2) NOT NULL CHECK (Сумма_займа > 0),
    Тип_выплат VARCHAR(20) NOT NULL CHECK (Тип_выплат IN ('Единовременный', 'По частям')),
    Количество_дней SMALLINT NOT NULL CHECK (Количество_дней > 0),
    Крайняя_дата_возврата DATE NOT NULL,
    Процентная_ставка_день DECIMAL(5, 2) NOT NULL CHECK (Процентная_ставка_день >= 0),
    Пени_процент_день DECIMAL(5, 2) NOT NULL CHECK (Пени_процент_день >= 0),
    Текущий_статус VARCHAR(20) NOT NULL DEFAULT 'Активен' CHECK (
        Текущий_статус IN ('Активен', 'Закрыт', 'Просрочен', 'Передан')
    ),
    ID_Клиента INT NOT NULL REFERENCES Клиент(ID_Клиента),
    ID_Отделения INT NOT NULL REFERENCES Отделение(ID_Отделения),
    ID_Бухгалтера INT NOT NULL REFERENCES Сотрудник(ID_Сотрудника),
    CONSTRAINT chk_дата_возврата CHECK (Крайняя_дата_возврата > Дата_выдачи)
);
CREATE TABLE Расписка (
    ID_Расписки SERIAL PRIMARY KEY,
    Текст_обязательства TEXT NOT NULL,
    Сумма_прописью VARCHAR(200) NOT NULL,
    Сумма_числом DECIMAL(15, 2) NOT NULL CHECK (Сумма_числом > 0),
    Дата_подписания DATE NOT NULL,
    Согласие_на_обработку_пд BOOLEAN NOT NULL DEFAULT TRUE,
    ID_Займа INT NOT NULL UNIQUE REFERENCES Документ_займа(ID_Займа),
    ID_Клиента INT NOT NULL REFERENCES Клиент(ID_Клиента),
    ID_Кассира INT NOT NULL REFERENCES Сотрудник(ID_Сотрудника)
);
CREATE TABLE Платёжный_документ (
    ID_Платежа SERIAL PRIMARY KEY,
    Номер_квитанции VARCHAR(50) NOT NULL UNIQUE,
    Дата_время_платежа TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Назначение_платежа VARCHAR(200),
    Внесенная_сумма DECIMAL(15, 2) NOT NULL CHECK (Внесенная_сумма > 0),
    Способ_оплаты VARCHAR(50) NOT NULL CHECK (
        Способ_оплаты IN ('Наличные', 'Карта', 'Перевод')
    ),
    ID_Клиента INT NOT NULL REFERENCES Клиент(ID_Клиента),
    ID_Кассира INT NOT NULL REFERENCES Сотрудник(ID_Сотрудника)
);
CREATE TABLE План_выплат (
    ID_Плана BIGSERIAL PRIMARY KEY,
    Плановая_дата_оплаты DATE NOT NULL,
    Остаток_погашения_основы DECIMAL(15, 2) NOT NULL CHECK (Остаток_погашения_основы >= 0),
    Остаток_погашения_процентов DECIMAL(15, 2) NOT NULL CHECK (Остаток_погашения_процентов >= 0),
    Остаток_погашения_штрафа DECIMAL(15, 2) NOT NULL DEFAULT 0 CHECK (Остаток_погашения_штрафа >= 0),
    Статус_исполнения VARCHAR(20) NOT NULL DEFAULT 'Ожидает' CHECK (
        Статус_исполнения IN ('Ожидает', 'Оплачено', 'Просрочено')
    ),
    ID_Займа INT NOT NULL REFERENCES Документ_займа(ID_Займа),
    ID_Бухгалтера INT NOT NULL REFERENCES Сотрудник(ID_Сотрудника),
    ID_Платежа INT REFERENCES Платёжный_документ(ID_Платежа),
    ID_Типа_начисления INT NOT NULL REFERENCES Тип_начисления(ID_Типа_начисления)
);
CREATE TABLE Договор_о_сотрудничестве (
    ID_Договора SERIAL PRIMARY KEY,
    Регистрационный_номер VARCHAR(50) NOT NULL UNIQUE,
    Дата_подписания DATE NOT NULL,
    Статус_договора VARCHAR(20) NOT NULL DEFAULT 'В работе' CHECK (
        Статус_договора IN ('В работе', 'Исполнен', 'Расторгнут')
    ),
    ID_Займа INT NOT NULL UNIQUE REFERENCES Документ_займа(ID_Займа),
    ID_Агентства INT NOT NULL REFERENCES Коллекторское_агентство(ID_Агентства),
    ID_Бухгалтера INT NOT NULL REFERENCES Сотрудник(ID_Сотрудника),
    ID_Плана INT REFERENCES План_выплат(ID_Плана)
);
CREATE INDEX idx_сотрудник_отделение ON Сотрудник(ID_Отделения);
CREATE INDEX idx_сотрудник_должность ON Сотрудник(ID_Должности);
CREATE INDEX idx_анкета_клиент ON Анкета_клиента(ID_Клиента);
CREATE INDEX idx_анкета_отделение ON Анкета_клиента(ID_Отделения);
CREATE INDEX idx_заем_клиент ON Документ_займа(ID_Клиента);
CREATE INDEX idx_заем_отделение ON Документ_займа(ID_Отделения);
CREATE INDEX idx_план_заем ON План_выплат(ID_Займа);
CREATE INDEX idx_платеж_клиент ON Платёжный_документ(ID_Клиента);
CREATE INDEX idx_договор_заем ON Договор_о_сотрудничестве(ID_Займа);