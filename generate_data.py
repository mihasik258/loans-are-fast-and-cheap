import random
from datetime import datetime, timedelta

OUT_FILE = "test_data.sql"

LAST_M  = ["Иванов","Петров","Сидоров","Козлов","Смирнов","Морозов","Волков","Новиков","Попов","Михайлов"]
LAST_F  = ["Иванова","Петрова","Сидорова","Козлова","Смирнова","Морозова","Волкова","Новикова","Попова","Михайлова"]
FIRST_M = ["Алексей","Дмитрий","Сергей","Андрей","Игорь","Олег","Павел","Максим","Николай","Артём"]
FIRST_F = ["Мария","Анна","Елена","Ольга","Татьяна","Наталья","Светлана","Ирина","Екатерина","Юлия"]
MIDDLE_M= ["Петрович","Сергеевич","Иванович","Владимирович","Дмитриевич","Николаевич","Алексеевич"]
MIDDLE_F= ["Петровна","Сергеевна","Ивановна","Владимировна","Дмитриевна","Николаевна","Алексеевна"]
CITIES  = ["Москва","Санкт-Петербург","Новосибирск","Казань","Екатеринбург"]
STREETS = ["Ленина","Мира","Советская","Кирова","Гагарина"]
COMPANIES=["ДолгВозврат","СправедливоеРешение","ФинансКонтроль"]

N_ADDR      = 20
N_BRANCH    = 5
N_EMPLOYEE  = 25
N_CLIENT    = 50
N_LOAN      = 40
N_PAYMENT   = 60

LOAN_STATUSES= ["Активен","Закрыт","Просрочен","Передан"]
PLAN_STATUSES= ["Ожидает","Оплачено","Просрочено"]
PAY_METHODS  = ["Наличные","Карта","Перевод"]

def rand_date(start_days_ago, end_days_ago=0):
    d = datetime.now() - timedelta(days=random.randint(end_days_ago, start_days_ago))
    return d.strftime("%Y-%m-%d")

def rand_datetime(start_days_ago, end_days_ago=0):
    d = datetime.now() - timedelta(days=random.randint(end_days_ago, start_days_ago),
                                    hours=random.randint(0,23), minutes=random.randint(0,59))
    return d.strftime("%Y-%m-%d %H:%M:%S")

def rand_person():
    is_male = random.random() < 0.5
    if is_male: return random.choice(LAST_M), random.choice(FIRST_M), random.choice(MIDDLE_M)
    return random.choice(LAST_F), random.choice(FIRST_F), random.choice(MIDDLE_F)

def esc(s): return str(s).replace("'","''")

def fmt(v):
    if v is None: return "NULL"
    if isinstance(v, bool): return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)): return str(v)
    return f"'{esc(v)}'"

def generate():
    lines = []
    
    def ins(table, cols, rows):
        cs = ", ".join(cols)
        for r in rows:
            vs = ", ".join(fmt(v) for v in r)
            lines.append(f"INSERT INTO {table} ({cs}) VALUES ({vs});")
        lines.append("")

    addrs = [(i+100, random.choice(CITIES), random.choice(STREETS), str(random.randint(1,120)),
              str(random.randint(1,5)) if random.random()<.3 else None,
              f"{random.randint(100000,999999)}") for i in range(N_ADDR)]
    ins("Адрес", ["ID_Адреса", "Город","Улица","Дом","Корпус","Индекс"], addrs)

    brs = [(i+100, f"ЛИЦ-{i+100:03d}-2020", rand_date(1800,365),
            random.randint(1,3), i+100) for i in range(N_BRANCH)]
    ins("Отделение", ["ID_Отделения", "Номер_лицензии","Дата_выдачи_лицензии","ID_Типа","ID_Адреса"], brs)

    emps = []
    for i in range(N_EMPLOYEE):
        ln,fn,mn = rand_person()
        pos = (i%3)+1
        br = (i%N_BRANCH)+100
        mgr = 1 if pos != 1 else None
        emps.append((i+100, ln,fn,mn, f"45{(i%100):02d}", f"100{(i%1000):03d}", f"{i+100:012d}",
                      f"+79{random.randint(10000000,99999999)}", f"emp_{i+100}@fm.ru", 
                      rand_date(1500,180), None, pos, br, mgr))
    ins("Сотрудник", ["ID_Сотрудника", "Фамилия","Имя","Отчество","Паспорт_серия","Паспорт_номер",
                       "ИНН","Телефон","Email","Дата_найма","Дата_увольнения",
                       "ID_Должности","ID_Отделения","ID_Руководителя"], emps)

    cls = []
    for i in range(N_CLIENT):
        ln,fn,mn = rand_person()
        bd = rand_date(365*65, 365*18)
        cls.append((i+100, ln,fn,mn, bd, f"46{(i%100):02d}", f"200{(i%1000):03d}", f"ОВД {random.choice(CITIES)}", 
                     rand_date(365*10,365*2), f"+78{random.randint(10000000,99999999)}"))
    ins("Клиент", ["ID_Клиента", "Фамилия","Имя","Отчество","Дата_рождения","Паспорт_серия","Паспорт_номер",
                    "Паспорт_выдан_кем","Паспорт_дата_выдачи","Контактный_телефон"], cls)

    profs = []
    aid = 100
    for cl in range(100, N_CLIENT+100):
        for br in random.sample(range(100,N_BRANCH+100), min(random.choice([1,1,2]),N_BRANCH)):
            cshs = [e[0] for e in emps if e[11]==3 and e[12]==br]
            reg = random.choice(cshs) if cshs else 1
            profs.append((aid, random.randint(1,5), rand_date(1095,30), cl, br, reg, random.randint(1,4)))
            aid += 1
    ins("Анкета_клиента", ["ID_Анкеты", "Уровень_риска","Дата_первого_обращения",
                            "ID_Клиента","ID_Отделения","ID_Регистратора","ID_Категории"], profs)

    ags = [(i+100, f'ООО "{random.choice(COMPANIES)}-{i+100}"', f"КА-{i+100}",
            f"{i+100:010d}", f"+7{random.randint(100000000,999999999)}",
            100+i) for i in range(3)]
    ins("Коллекторское_агентство", ["ID_Агентства", "Полное_наименование","Краткое_наименование",
                                     "ИНН_Агентства","Контактный_телефон","ID_Адреса"], ags)

    loans = []
    for i in range(N_LOAN):
        cl = random.randint(100,N_CLIENT+99)
        br = random.randint(100,N_BRANCH+99)
        accs = [e[0] for e in emps if e[11]==2 and e[12]==br]
        acc = random.choice(accs) if accs else 2
        d = rand_date(730,60)
        days = random.choice([7,14,30,60,90])
        amt = round(random.uniform(5000,500000),2)
        ret = (datetime.strptime(d,"%Y-%m-%d")+timedelta(days=days)).strftime("%Y-%m-%d")
        loans.append((i+100, d, amt, random.choice(["Единовременный","По частям"]), days, ret,
                       round(random.uniform(.5,3),2), round(random.uniform(1,5),2),
                       random.choice(LOAN_STATUSES), cl, br, acc))
    ins("Документ_займа", ["ID_Займа", "Дата_выдачи","Сумма_займа","Тип_выплат","Количество_дней",
                            "Крайняя_дата_возврата","Процентная_ставка_день","Пени_процент_день",
                            "Текущий_статус","ID_Клиента","ID_Отделения","ID_Бухгалтера"], loans)

    recs = [(i+100, f"Обязуюсь вернуть заем №{i+100} в полном объеме.", f"{loans[i][2]} руб.",
             loans[i][2], loans[i][1], True, i+100, loans[i][9],
             loans[i][11]) for i in range(N_LOAN)]
    ins("Расписка", ["ID_Расписки", "Текст_обязательства","Сумма_прописью","Сумма_числом",
                      "Дата_подписания","Согласие_на_обработку_пд","ID_Займа","ID_Клиента","ID_Кассира"], recs)

    pays = [(i+100, f"КВТ-{i+100:06d}", rand_datetime(730,30), "Погашение задолженности",
             round(random.uniform(1000,100000),2), random.choice(PAY_METHODS),
             random.randint(100,N_CLIENT+99), 3) for i in range(N_PAYMENT)]
    ins("Платёжный_документ", ["ID_Платежа", "Номер_квитанции","Дата_время_платежа","Назначение_платежа",
                                "Внесенная_сумма","Способ_оплаты","ID_Клиента","ID_Кассира"], pays)

    plans = []
    plan_cnt = 100
    for li in range(N_LOAN):
        loan_type = loans[li][3]
        loan_days = loans[li][4]
        loan_end_date = loans[li][5]
        loan_amt = loans[li][2]
        loan_pct_rate = loans[li][6]
        d0 = datetime.strptime(loans[li][1],"%Y-%m-%d")
        accs = [e[0] for e in emps if e[11]==2]
        acc = random.choice(accs) if accs else 2
        
        np = 1 if loan_type == "Единовременный" else random.randint(2, 4)
        for p in range(np):
            if loan_type == "Единовременный":
                pd = loan_end_date
            else:
                pd = (d0 + timedelta(days=int(loan_days * (p + 1) / np))).strftime("%Y-%m-%d")
                
            base = round(loan_amt / np, 2)
            pct = round(base * loan_pct_rate * loan_days / np / 100, 2)
            pen = round(random.uniform(0, 5000), 2) if random.random() < .2 else 0
            st = random.choice(PLAN_STATUSES)
            pid = random.randint(100, N_PAYMENT + 99) if st == "Оплачено" and random.random() < .7 else None
            plans.append((plan_cnt, pd, base, pct, pen, st, li + 100, acc, pid, random.randint(1, 3)))
            plan_cnt += 1
    ins("План_выплат", ["ID_Плана", "Плановая_дата_оплаты","Остаток_погашения_основы",
                         "Остаток_погашения_процентов","Остаток_погашения_штрафа",
                         "Статус_исполнения","ID_Займа","ID_Бухгалтера","ID_Платежа","ID_Типа_начисления"], plans)

    trans = [i for i in range(N_LOAN) if loans[i][8]=="Передан"]
    ctrs = []
    for idx,li in enumerate(trans):
        accs = [e[0] for e in emps if e[11]==2]
        acc = random.choice(accs) if accs else 2
        rp = [p[0] for p in plans if p[6]==li+100]
        pr = rp[-1] if rp else None
        ctrs.append((idx+100, f"ДОГ-КОЛ-{idx+100:03d}", rand_date(365,30),
                      random.choice(["В работе","Исполнен"]), li+100,
                      random.randint(1,2), acc, pr))
    ins("Договор_о_сотрудничестве",
        ["ID_Договора", "Регистрационный_номер","Дата_подписания",
         "Статус_договора","ID_Займа",
         "ID_Агентства","ID_Бухгалтера","ID_Плана"], ctrs)

    tables_seqs = [
        ("Адрес", "ID_Адреса"), ("Тип_отделения", "ID_Типа"), ("Должность", "ID_Должности"),
        ("Тип_начисления", "ID_Типа_начисления"), ("Категория_клиента", "ID_Категории"),
        ("Отделение", "ID_Отделения"), ("Сотрудник", "ID_Сотрудника"), ("Клиент", "ID_Клиента"),
        ("Анкета_клиента", "ID_Анкеты"), ("Коллекторское_агентство", "ID_Агентства"),
        ("Документ_займа", "ID_Займа"), ("Расписка", "ID_Расписки"),
        ("Платёжный_документ", "ID_Платежа"), ("План_выплат", "ID_Плана"),
        ("Договор_о_сотрудничестве", "ID_Договора")
    ]
    
    lines.append("DO $$")
    lines.append("DECLARE")
    lines.append("    actual_t text;")
    lines.append("    actual_pk text;")
    lines.append("    s text;")
    lines.append("    m bigint;")
    lines.append("BEGIN")
    for t, pk in tables_seqs:
        lines.append(f"    SELECT c.relname, a.attname INTO actual_t, actual_pk FROM pg_class c JOIN pg_attribute a ON c.oid = a.attrelid WHERE c.relname ILIKE '{t}' AND a.attname ILIKE '{pk}';")
        lines.append(f"    s := pg_get_serial_sequence(actual_t, actual_pk);")
        lines.append(f"    IF s IS NOT NULL THEN")
        lines.append(f"        EXECUTE format('SELECT COALESCE(MAX(%I), 1) FROM %I', actual_pk, actual_t) INTO m;")
        lines.append(f"        PERFORM setval(s, m);")
        lines.append(f"    END IF;")
    lines.append("END $$;")

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

if __name__ == "__main__":
    generate()
