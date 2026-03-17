import random
import subprocess
from datetime import datetime, timedelta

OUT_FILE = "test_data.sql"

LAST_M  = ["Иванов","Петров","Сидоров","Козлов","Смирнов","Морозов","Волков","Новиков","Попов","Михайлов", "Соколов", "Лебедев", "Козлов", "Степанов"]
LAST_F  = ["Иванова","Петрова","Сидорова","Козлова","Смирнова","Морозова","Волкова","Новикова","Попова","Михайлова", "Соколова", "Лебедева", "Степанова"]
FIRST_M = ["Алексей","Дмитрий","Сергей","Андрей","Игорь","Олег","Павел","Максим","Николай","Артём", "Владимир", "Евгений", "Денис", "Антон"]
FIRST_F = ["Мария","Анна","Елена","Ольга","Татьяна","Наталья","Светлана","Ирина","Екатерина","Юлия", "Анастасия", "Виктория", "Ксения", "Дарья"]
MIDDLE_M= ["Петрович","Сергеевич","Иванович","Владимирович","Дмитриевич","Николаевич","Алексеевич", "Андреевич", "Евгеньевич", "Максимович", "Олегович"]
MIDDLE_F= ["Петровна","Сергеевна","Ивановна","Владимировна","Дмитриевна","Николаевна","Алексеевна", "Андреевна", "Евгеньевна", "Максимовна", "Олеговна"]
CITIES  = ["Москва","Санкт-Петербург","Новосибирск","Казань","Екатеринбург", "Нижний Новгород", "Челябинск", "Самара", "Омск", "Ростов-на-Дону"]
STREETS = ["Ленина","Мира","Советская","Кирова","Гагарина", "Пушкина", "Лермонтова", "Горького", "Чехова", "Толстого", "Маяковского"]
COMPANIES=["ДолгВозврат","СправедливоеРешение","ФинансКонтроль", "АбсолютВзыскание", "НадежныйПартнер"]

N_ADDR      = 30
N_BRANCH    = 10
N_EMPLOYEE  = 50
N_CLIENT    = 200
N_LOAN      = 150

PAY_METHODS  = ["Наличные","Карта","Перевод"]

def rand_date(start_date, end_date):
    if start_date >= end_date:
        return start_date
    delta = end_date - start_date
    int_delta = (delta.days * 24 * 60 * 60) + delta.seconds
    random_second = random.randrange(int_delta) if int_delta > 0 else 0
    return start_date + timedelta(seconds=random_second)

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
        if not rows: return
        cs = ", ".join(cols)
        for r in rows:
            vs = ", ".join(fmt(v) for v in r)
            lines.append(f"INSERT INTO {table} ({cs}) VALUES ({vs});")
        lines.append("")

    # --- 0. СПРАВОЧНИКИ ---
    ins("Тип_отделения", ["Название", "Макс_сумма"], [
        ("Малое", 100000.00),
        ("Среднее", 500000.00),
        ("Крупное", 1000000.00)
    ])
    
    ins("Должность", ["Название", "Базовый_оклад"], [
        ("Директор", 120000.00),
        ("Бухгалтер", 80000.00),
        ("Кассир", 55000.00)
    ])
    
    ins("Тип_начисления", ["Название"], [
        ("Регулярный",),
        ("Штрафной",),
        ("Досрочный",)
    ])
    
    ins("Категория_клиента", ["Название"], [
        ("Новичок",),
        ("Стандарт",),
        ("VIP",),
        ("Ненадежный",)
    ])

    # --- 1. АДРЕСА ---
    addrs = []
    for i in range(N_ADDR):
        addrs.append((random.choice(CITIES), random.choice(STREETS), str(random.randint(1,120)),
                      str(random.randint(1,5)) if random.random()<.3 else None,
                      f"{random.randint(100000,999999)}"))
    ins("Адрес", ["Город","Улица","Дом","Корпус","Индекс"], addrs)

    # --- 2. ОТДЕЛЕНИЯ ---
    brs = []
    for i in range(N_BRANCH):
        lic_date = rand_date(datetime(2015,1,1), datetime(2020,1,1))
        brs.append((f"ЛИЦ-{i+1:03d}-{lic_date.year}", lic_date.strftime("%Y-%m-%d"),
                   random.randint(1,3), i%N_ADDR + 1))
    ins("Отделение", ["Номер_лицензии","Дата_выдачи_лицензии","ID_Типа","ID_Адреса"], brs)

    # --- 3. СОТРУДНИКИ ---
    emps = []
    for i in range(N_EMPLOYEE):
        ln, fn, mn = rand_person()
        pos = (i % 3) + 1 # 1=Директор, 2=Бухгалтер, 3=Кассир
        br = (i % N_BRANCH) + 1
        mgr = 1 if pos != 1 else None
        hired = rand_date(datetime(2020,1,1), datetime(2023,1,1))
        emps.append((ln, fn, mn, f"45{random.randint(10,99)}", f"{random.randint(100000,999999)}",
                     f"{random.randint(100000000000,999999999999)}", f"+79{random.randint(10000000,99999999)}",
                     f"emp_{i+1}@fm.ru", hired.strftime("%Y-%m-%d"), None, pos, br, mgr))
    ins("Сотрудник", ["Фамилия","Имя","Отчество","Паспорт_серия","Паспорт_номер",
                       "ИНН","Телефон","Email","Дата_найма","Дата_увольнения",
                       "ID_Должности","ID_Отделения","ID_Руководителя"], emps)

    # --- 4. КЛИЕНТЫ ---
    cls = []
    for i in range(N_CLIENT):
        ln, fn, mn = rand_person()
        birth = rand_date(datetime(1960,1,1), datetime(2003,1,1))
        pass_date = rand_date(birth + timedelta(days=14*365), birth + timedelta(days=20*365))
        if pass_date > datetime.now(): pass_date = datetime.now() - timedelta(days=30)
        
        cls.append((ln, fn, mn, birth.strftime("%Y-%m-%d"), f"46{random.randint(10,99)}",
                    f"{random.randint(100000,999999)}", f"ОВД {random.choice(CITIES)}",
                    pass_date.strftime("%Y-%m-%d"), f"+78{random.randint(10000000,99999999)}"))
    ins("Клиент", ["Фамилия","Имя","Отчество","Дата_рождения","Паспорт_серия","Паспорт_номер",
                    "Паспорт_выдан_кем","Паспорт_дата_выдачи","Контактный_телефон"], cls)

    # --- 5. АНКЕТЫ КЛИЕНТОВ ---
    profs = []
    aid = 1
    for cl_idx in range(N_CLIENT):
        cl_id = cl_idx + 1
        pass_d = datetime.strptime(cls[cl_idx][7], "%Y-%m-%d")
        
        num_profiles = random.choices([1, 2], weights=[80, 20])[0]
        used_brs = set()
        for _ in range(num_profiles):
            br = random.randint(1, N_BRANCH)
            if br in used_brs: continue
            used_brs.add(br)
            cshs = [e_idx+1 for e_idx, e in enumerate(emps) if e[10]==3 and e[11]==br]
            reg = random.choice(cshs) if cshs else random.choice([e_idx+1 for e_idx, e in enumerate(emps) if e[10]==3])
            prof_d = rand_date(pass_d + timedelta(days=30), datetime(2023,12,31))
            profs.append((random.randint(1,5), prof_d.strftime("%Y-%m-%d"), cl_id, br, reg, random.randint(1,4)))
            aid += 1
    ins("Анкета_клиента", ["Уровень_риска","Дата_первого_обращения",
                            "ID_Клиента","ID_Отделения","ID_Регистратора","ID_Категории"], profs)
    ags = [(f'ООО "{random.choice(COMPANIES)}-{i+1}"', f"КА-{i+1}",
            f"{random.randint(1000000000,9999999999)}", f"+7{random.randint(100000000,999999999)}",
            i%N_ADDR + 1) for i in range(5)]
    ins("Коллекторское_агентство", ["Полное_наименование","Краткое_наименование",
                                     "ИНН_Агентства","Контактный_телефон","ID_Адреса"], ags)

    # --- 7. ЗАЙМЫ, РАСПИСКИ, ПЛАНЫ И ПЛАТЕЖИ ---
    loans = []
    recs = []
    plans = []
    pays = []
    ctrs = []
    
    pay_id = 1
    plan_id = 1
    ctr_id = 1
    
    for i in range(N_LOAN):
        loan_id = i + 1
        
        prof = random.choice(profs)
        cl_id = prof[2]
        br_id = prof[3]
        prof_date = datetime.strptime(prof[1], "%Y-%m-%d")
        
        loan_date = rand_date(prof_date + timedelta(days=1), datetime.now() - timedelta(days=100))
        amt = round(random.choice([10000, 25000, 50000, 75000, 100000, 250000, 500000]), 2)
        loan_type = random.choice(["Единовременный", "По частям"])
        days = random.choice([14, 30, 60, 90, 180, 360])
        ret_date = loan_date + timedelta(days=days)
        pct_rate = round(random.uniform(0.5, 2.0), 2)
        pen_rate = round(random.uniform(1.0, 5.0), 2)
        
        accs = [e_idx+1 for e_idx, e in enumerate(emps) if e[10]==2]
        acc = random.choice(accs) if accs else 2
        
        loans.append((loan_date.strftime("%Y-%m-%d"), amt, loan_type, days, ret_date.strftime("%Y-%m-%d"),
                      pct_rate, pen_rate, "Активен", cl_id, br_id, acc))
                      
        cashiers = [e_idx+1 for e_idx, e in enumerate(emps) if e[10]==3 and e[11]==br_id]
        csh = random.choice(cashiers) if cashiers else random.choice([e_idx+1 for e_idx, e in enumerate(emps) if e[10]==3])
        recs.append((f"Обязуюсь вернуть заем №{loan_id}", f"{amt} руб.", amt, 
                     loan_date.strftime("%Y-%m-%d"), True, loan_id, cl_id, csh))
                     
        np = 1 if loan_type == "Единовременный" else (days // 30 if days >= 30 else 2)
        if np == 0: np = 1
        
        base_amt = round(amt / np, 2)
        last_base_amt = round(amt - (base_amt * (np - 1)), 2)
        
        loan_fully_paid = True
        loan_overdue = False
        loan_transferred = False
        
        for p in range(np):
            is_last = (p == np - 1)
            b = last_base_amt if is_last else base_amt
            
            if loan_type == "Единовременный":
                plan_d = ret_date
            else:
                step_days = days / np
                plan_d = loan_date + timedelta(days=int(step_days * (p + 1)))
                
            pct = round(b * pct_rate * (days/np) / 100, 2)
            
            curr = plan_d.replace(hour=0, minute=0, second=0)
            now = datetime.now()
            
            st = "Ожидает"
            pid = None
            pen = 0
            
            if curr < now:
                if random.random() < 0.8:
                    st = "Оплачено"
                else:
                    st = "Просрочено"
                    pen = round(b * pen_rate * (now - curr).days / 100, 2)
            else:
                if random.random() < 0.1:
                    st = "Оплачено"
            
            if st == "Оплачено":
                pay_d = rand_date(loan_date, plan_d)
                pay_amt = round(b + pct + pen, 2)
                if np > 1:
                    purpose = f"Погашение по займу №{loan_id} (часть {p+1} из {np})"
                else:
                    purpose = f"Единовременное полное погашение по займу №{loan_id}"
                
                pays.append((f"КВТ-{pay_id:06d}", pay_d.strftime("%Y-%m-%d %H:%M:%S"),
                             purpose, pay_amt, random.choice(PAY_METHODS), cl_id, csh))
                pid = pay_id
                pay_id += 1
            else:
                loan_fully_paid = False
                if st == "Просрочено":
                    loan_overdue = True
                    if random.random() < 0.3:
                        loan_transferred = True
            plans.append((plan_d.strftime("%Y-%m-%d"), b, pct, pen, st, loan_id, acc, pid, 1))
            plan_id += 1
            
        l_status = "Активен"
        if loan_fully_paid: l_status = "Закрыт"
        elif loan_transferred: l_status = "Передан"
        elif loan_overdue: l_status = "Просрочен"
        loans[-1] = loans[-1][:7] + (l_status,) + loans[-1][8:]
        
        if l_status == "Передан":
            last_plan_id = plan_id - 1
            ctr_date = rand_date(ret_date, datetime.now())
            ctrs.append((f"ДОГ-КОЛ-{ctr_id:03d}", ctr_date.strftime("%Y-%m-%d"),
                         "В работе", loan_id, random.choice(range(1, len(ags)+1)), acc, last_plan_id))
            ctr_id += 1

    ins("Документ_займа", ["Дата_выдачи","Сумма_займа","Тип_выплат","Количество_дней",
                            "Крайняя_дата_возврата","Процентная_ставка_день","Пени_процент_день",
                            "Текущий_статус","ID_Клиента","ID_Отделения","ID_Бухгалтера"], loans)
    ins("Расписка", ["Текст_обязательства","Сумма_прописью","Сумма_числом",
                      "Дата_подписания","Согласие_на_обработку_пд","ID_Займа","ID_Клиента","ID_Кассира"], recs)
    ins("Платёжный_документ", ["Номер_квитанции","Дата_время_платежа","Назначение_платежа",
                                "Внесенная_сумма","Способ_оплаты","ID_Клиента","ID_Кассира"], pays)
    ins("План_выплат", ["Плановая_дата_оплаты","Остаток_погашения_основы",
                         "Остаток_погашения_процентов","Остаток_погашения_штрафа",
                         "Статус_исполнения","ID_Займа","ID_Бухгалтера","ID_Платежа","ID_Типа_начисления"], plans)
    ins("Договор_о_сотрудничестве", ["Регистрационный_номер","Дата_подписания",
                                      "Статус_договора","ID_Займа","ID_Агентства","ID_Бухгалтера","ID_Плана"], ctrs)

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

if __name__ == "__main__":
    print("Generating standalone standalone testing dataset (seed included)...")
    generate()
    print("Test data generated in test_data.sql")
    
    print("\nRunning database setup scripts...")
    db_name = "fast_money"
    
    try:
        subprocess.run(["psql", "-d", db_name, "-c", "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"], check=True)
        
        subprocess.run(["psql", "-d", db_name, "-f", "schema.sql"], check=True)
        
        subprocess.run(["psql", "-d", db_name, "-f", "test_data.sql"], check=True)
        
        print("done")
    except subprocess.CalledProcessError as e:
        print(f"\n error: {e}")
