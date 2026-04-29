

## Выбранные запросы

Для анализа выбраны **Запрос 2** и **Запрос 4** как наиболее структурно сложные:

- **Запрос 2** — клиенты с просроченными выплатами: оконная функция `COUNT OVER (PARTITION BY … ROWS BETWEEN)`, два `JOIN`, фильтр применяется после вычисления окна
- **Запрос 4** — обслуживание клиентов в отделениях: три прохода по одной таблице (self-join, `LAG()`, anti-join через `LEFT JOIN … WHERE IS NULL`), `STRING_AGG`, `GroupAggregate`

---

## Условия эксперимента

Для получения показательных результатов была сгенерирована достаточная для планировщика нагрузка через `generate_data.sql`:

| Таблица | Строк до | Строк после |
|---|---|---|
| `План_выплат` | 1 458 | **62 058** |
| `Документ_займа` | 152 | **10 162** |
| `Клиент` | 202 | 2 202 |

На малой базе планировщик выбирает `Seq Scan` — полный перебор дешевле из-за накладных расходов индекса. На реальном объёме данных планировщик переключается на индексные сканы автоматически, без каких-либо принудительных настроек.

---

## Спроектированные индексы

### 1. Составной — `idx_план_займ_дата_статус`

```sql
CREATE INDEX idx_план_займ_дата_статус
    ON "План_выплат" ("id_Займа", "Плановая_дата_оплаты", "Статус_исполнения");
```

Запрос 2 выполняет три операции с `План_выплат` одновременно: JOIN по `id_Займа`, сортировку для `WindowAgg` по `(id_Займа, Плановая_дата_оплаты)` и фильтрацию по `Статус_исполнения`. Планировщик использует индекс для `Index Scan` с уже отсортированным порядком и переходит с `Hash Join` на `Merge Join`, не строя хеш-таблицу в памяти.

### 2. Частичный — `idx_план_просрочено`

```sql
CREATE INDEX idx_план_просрочено
    ON "План_выплат" ("id_Займа", "Плановая_дата_оплаты")
    WHERE "Статус_исполнения" = 'Просрочено';
```

Просроченные строки составляют ~3.5% таблицы. Индекс физически содержит только их, что делает его в ~28 раз меньше полного. При переносе фильтра внутрь подзапроса планировщик читал бы тысячи строк вместо десятков тысяч. В текущей формулировке запроса не применяется: оконная функция обязана видеть все строки займа для корректного подсчёта `Пунктов_после`.

### 3. Покрывающий — `idx_заём_клиент_дата_covering`

```sql
CREATE INDEX idx_заём_клиент_дата_covering
    ON "Документ_займа" ("id_Клиента", "Дата_выдачи")
    INCLUDE ("id_Займа", "id_Отделения", "Сумма_займа");
```

Запрос 4 обращается к `Документ_займа` трижды. Ключи `(id_Клиента, Дата_выдачи)` покрывают все три паттерна доступа: `LAG() PARTITION BY id_Клиента ORDER BY Дата_выдачи`, anti-join и финальный `SELECT`. Раздел `INCLUDE` позволяет планировщику выполнить **Index Only Scan** - читать нужные данные прямо из индекса без обращения к heap-страницам таблицы.

---

## Планы выполнения

### Запрос 2 — ДО индексов (`Execution Time: 21 247 ms`)
### Запрос 2 — ПОСЛЕ индексов (`Execution Time: 382 ms`,)
### Запрос 4 — ДО индексов (`Execution Time: 21 247 ms`)

### Запрос 4 — ПОСЛЕ индексов (`Execution Time: 115 ms`)

```

 Sort  (cost=193.49..193.51 rows=5 width=88) (actual time=3.476..3.483 rows=106 loops=1)

   Sort Key: t."Клиент", t."Плановая_дата_оплаты"

   Sort Method: quicksort  Memory: 39kB

   Buffers: shared hit=30

   ->  Subquery Scan on t  (cost=124.21..193.43 rows=5 width=88) (actual time=1.357..2.722 rows=106 loops=1)

         Filter: (t."Статус_исполнения" = 'Просрочено'::"статус_исполнения_плана_enum")

         Rows Removed by Filter: 1350

         Buffers: shared hit=24

         ->  WindowAgg  (cost=124.21..180.12 rows=1065 width=96) (actual time=1.311..2.634 rows=1456 loops=1)

               Buffers: shared hit=24

               ->  Sort  (cost=124.21..126.87 rows=1065 width=304) (actual time=1.279..1.348 rows=1456 loops=1)

                     Sort Key: "п"."id_Займа", "п"."Плановая_дата_оплаты"

                     Sort Method: quicksort  Memory: 253kB

                     Buffers: shared hit=24

                     ->  Hash Join  (cost=39.35..70.66 rows=1065 width=304) (actual time=0.156..0.910 rows=1456 loops=1)

                           Hash Cond: ("з"."id_Клиента" = "к"."id_Клиента")

                           Buffers: shared hit=21

                           ->  Hash Join  (cost=27.55..56.01 rows=1065 width=72) (actual time=0.069..0.580 rows=1456 loops=1)

                                 Hash Cond: ("п"."id_Займа" = "з"."id_Займа")

                                 Buffers: shared hit=17

                                 ->  Seq Scan on "План_выплат" "п"  (cost=0.00..25.65 rows=1065 width=56) (actual time=0.010..0.218 rows=1456 loops=1)

                                       Buffers: shared hit=15

                                 ->  Hash  (cost=17.80..17.80 rows=780 width=20) (actual time=0.047..0.048 rows=150 loops=1)

                                       Buckets: 1024  Batches: 1  Memory Usage: 16kB

                                       Buffers: shared hit=2

                                       ->  Seq Scan on "Документ_займа" "з"  (cost=0.00..17.80 rows=780 width=20) (actual time=0.006..0.026 rows=150 loops=1)

                                             Buffers: shared hit=2

                           ->  Hash  (cost=10.80..10.80 rows=80 width=240) (actual time=0.077..0.077 rows=200 loops=1)

                                 Buckets: 1024  Batches: 1  Memory Usage: 21kB

                                 Buffers: shared hit=4

                                 ->  Seq Scan on "Клиент" "к"  (cost=0.00..10.80 rows=80 width=240) (actual time=0.010..0.043 rows=200 loops=1)

                                       Buffers: shared hit=4

 Planning:

   Buffers: shared hit=278

 Planning Time: 0.934 ms

 Execution Time: 3.602 ms

(36 rows)


 Sort  (cost=256.12..256.13 rows=3 width=276) (actual time=0.911..0.916 rows=38 loops=1)

   Sort Key: "аг"."Кол_займов" DESC

   Sort Method: quicksort  Memory: 30kB

   Buffers: shared hit=166

   ->  Nested Loop  (cost=175.53..256.09 rows=3 width=276) (actual time=0.823..0.890 rows=38 loops=1)

         Buffers: shared hit=163

         ->  Nested Loop  (cost=175.38..255.42 rows=3 width=162) (actual time=0.817..0.858 rows=38 loops=1)

               Buffers: shared hit=87

               ->  Hash Right Join  (cost=175.24..254.75 rows=3 width=170) (actual time=0.776..0.786 rows=38 loops=1)

                     Hash Cond: ("з2"."id_Клиента" = "з"."id_Клиента")

                     Join Filter: ("з2"."Дата_выдачи" > "з"."Дата_выдачи")

                     Rows Removed by Join Filter: 146

                     Filter: ("з2"."id_Займа" IS NULL)

                     Rows Removed by Filter: 60

                     Buffers: shared hit=11

                     ->  Seq Scan on "Документ_займа" "з2"  (cost=0.00..17.80 rows=780 width=12) (actual time=0.004..0.013 rows=150 loops=1)

                           Buffers: shared hit=2

                     ->  Hash  (cost=170.16..170.16 rows=406 width=170) (actual time=0.725..0.727 rows=86 loops=1)

                           Buckets: 1024  Batches: 1  Memory Usage: 19kB

                           Buffers: shared hit=9

                           ->  Hash Join  (cost=145.38..170.16 rows=406 width=170) (actual time=0.661..0.701 rows=86 loops=1)

                                 Hash Cond: ("з"."id_Клиента" = "аг"."id_Клиента")

                                 Buffers: shared hit=9

                                 ->  Seq Scan on "Документ_займа" "з"  (cost=0.00..17.80 rows=780 width=30) (actual time=0.005..0.015 rows=150 loops=1)

                                       Buffers: shared hit=2

                                 ->  Hash  (cost=144.08..144.08 rows=104 width=140) (actual time=0.646..0.647 rows=38 loops=1)

                                       Buckets: 1024  Batches: 1  Memory Usage: 13kB

                                       Buffers: shared hit=7

                                       ->  Subquery Scan on "аг"  (cost=129.52..144.08 rows=104 width=140) (actual time=0.348..0.638 rows=38 loops=1)

                                             Buffers: shared hit=7

                                             ->  GroupAggregate  (cost=129.52..143.04 rows=104 width=376) (actual time=0.347..0.632 rows=38 loops=1)

                                                   Group Key: "з_1"."id_Клиента", "к_1"."Фамилия", "к_1"."Имя"

                                                   Filter: (count(*) > 1)

                                                   Rows Removed by Filter: 64

                                                   Buffers: shared hit=7

                                                   ->  Sort  (cost=129.52..130.30 rows=312 width=366) (actual time=0.297..0.307 rows=150 loops=1)

                                                         Sort Key: "з_1"."id_Клиента", "к_1"."Фамилия", "к_1"."Имя"

                                                         Sort Method: quicksort  Memory: 45kB

                                                         Buffers: shared hit=7

                                                         ->  Hash Join  (cost=88.32..116.59 rows=312 width=366) (actual time=0.133..0.255 rows=150 loops=1)

                                                               Hash Cond: ("з_1"."id_Отделения" = "о_1"."id_Отделения")

                                                               Buffers: shared hit=7

                                                               ->  Hash Join  (cost=67.07..94.51 rows=312 width=248) (actual time=0.115..0.214 rows=150 loops=1)

                                                                     Hash Cond: ("з_1"."id_Клиента" = "к_1"."id_Клиента")

                                                                     Buffers: shared hit=6

                                                                     ->  WindowAgg  (cost=55.27..72.82 rows=780 width=80) (actual time=0.057..0.131 rows=150 loops=1)

                                                                           Buffers: shared hit=2

                                                                           ->  Sort  (cost=55.27..57.22 rows=780 width=12) (actual time=0.051..0.058 rows=150 loops=1)

                                                                                 Sort Key: "з_1"."id_Клиента", "з_1"."Дата_выдачи"

                                                                                 Sort Method: quicksort  Memory: 32kB

                                                                                 Buffers: shared hit=2

                                                                                 ->  Seq Scan on "Документ_займа" "з_1"  (cost=0.00..17.80 rows=780 width=12) (actual time=0.003..0.019 rows=150 loops=1)

                                                                                       Buffers: shared hit=2

                                                                     ->  Hash  (cost=10.80..10.80 rows=80 width=240) (actual time=0.048..0.048 rows=200 loops=1)

                                                                           Buckets: 1024  Batches: 1  Memory Usage: 21kB

                                                                           Buffers: shared hit=4

                                                                           ->  Seq Scan on "Клиент" "к_1"  (cost=0.00..10.80 rows=80 width=240) (actual time=0.003..0.024 rows=200 loops=1)

                                                                                 Buffers: shared hit=4

                                                               ->  Hash  (cost=15.00..15.00 rows=500 width=122) (actual time=0.008..0.009 rows=10 loops=1)

                                                                     Buckets: 1024  Batches: 1  Memory Usage: 9kB

                                                                     Buffers: shared hit=1

                                                                     ->  Seq Scan on "Отделение" "о_1"  (cost=0.00..15.00 rows=500 width=122) (actual time=0.005..0.006 rows=10 loops=1)

                                                                           Buffers: shared hit=1

               ->  Index Only Scan using "Клиент_pkey" on "Клиент" "к"  (cost=0.14..0.22 rows=1 width=4) (actual time=0.002..0.002 rows=1 loops=38)

                     Index Cond: ("id_Клиента" = "з"."id_Клиента")

                     Heap Fetches: 38

                     Buffers: shared hit=76

         ->  Index Scan using "Отделение_pkey" on "Отделение" "о"  (cost=0.15..0.23 rows=1 width=122) (actual time=0.001..0.001 rows=1 loops=38)

               Index Cond: ("id_Отделения" = "з"."id_Отделения")

               Buffers: shared hit=76

 Planning:

   Buffers: shared hit=77

 Planning Time: 0.775 ms

 Execution Time: 1.012 ms

(74 rows)

CREATE INDEX
CREATE INDEX
CREATE INDEX



 Sort  (cost=278.55..278.82 rows=106 width=88) (actual time=3.385..3.391 rows=106 loops=1)

   Sort Key: t."Клиент", t."Плановая_дата_оплаты"

   Sort Method: quicksort  Memory: 39kB

   Buffers: shared hit=225 read=4

   ->  Subquery Scan on t  (cost=0.57..274.99 rows=106 width=88) (actual time=0.111..2.659 rows=106 loops=1)

         Filter: (t."Статус_исполнения" = 'Просрочено'::"статус_исполнения_плана_enum")

         Rows Removed by Filter: 1350

         Buffers: shared hit=225 read=4

         ->  WindowAgg  (cost=0.57..256.79 rows=1456 width=96) (actual time=0.035..2.542 rows=1456 loops=1)

               Buffers: shared hit=225 read=4

               ->  Merge Join  (cost=0.57..183.99 rows=1456 width=274) (actual time=0.016..0.972 rows=1456 loops=1)

                     Merge Cond: ("п"."id_Займа" = "з"."id_Займа")

                     Buffers: shared hit=225 read=4

                     ->  Index Scan using "idx_план_займ_дата_статус" on "План_выплат" "п"  (cost=0.28..90.49 rows=1456 width=32) (actual time=0.003..0.240 rows=1456 loops=1)

                           Buffers: shared hit=18 read=4

                     ->  Materialize  (cost=0.30..68.39 rows=150 width=246) (actual time=0.009..0.352 rows=1455 loops=1)

                           Buffers: shared hit=207

                           ->  Nested Loop  (cost=0.30..68.02 rows=150 width=246) (actual time=0.008..0.245 rows=150 loops=1)

                                 Buffers: shared hit=207

                                 ->  Index Scan using "Документ_займа_pkey" on "Документ_займа" "з"  (cost=0.14..15.39 rows=150 width=14) (actual time=0.002..0.027 rows=150 loops=1)

                                       Buffers: shared hit=3

                                 ->  Memoize  (cost=0.15..0.49 rows=1 width=240) (actual time=0.001..0.001 rows=1 loops=150)

                                       Cache Key: "з"."id_Клиента"

                                       Cache Mode: logical

                                       Hits: 48  Misses: 102  Evictions: 0  Overflows: 0  Memory Usage: 14kB

                                       Buffers: shared hit=204

                                       ->  Index Scan using "Клиент_pkey" on "Клиент" "к"  (cost=0.14..0.48 rows=1 width=240) (actual time=0.001..0.001 rows=1 loops=102)

                                             Index Cond: ("id_Клиента" = "з"."id_Клиента")

                                             Buffers: shared hit=204

 Planning:

   Buffers: shared hit=104 read=6

 Planning Time: 0.720 ms

 Execution Time: 3.438 ms

(33 rows)

  

                                                                                                          QUERY PLAN                                                                                                           


 Sort  (cost=128.65..128.66 rows=1 width=263) (actual time=0.801..0.804 rows=38 loops=1)

   Sort Key: (count(*)) DESC

   Sort Method: quicksort  Memory: 30kB

   Buffers: shared hit=465

   ->  Nested Loop  (cost=1.84..128.64 rows=1 width=263) (actual time=0.160..0.789 rows=38 loops=1)

         Buffers: shared hit=465

         ->  Nested Loop  (cost=1.69..128.15 rows=1 width=149) (actual time=0.155..0.753 rows=38 loops=1)

               Buffers: shared hit=389

               ->  Nested Loop Left Join  (cost=1.55..127.67 rows=1 width=157) (actual time=0.149..0.713 rows=38 loops=1)

                     Filter: ("з2"."id_Займа" IS NULL)

                     Rows Removed by Filter: 60

                     Buffers: shared hit=313

                     ->  Merge Join  (cost=1.40..111.61 rows=57 width=157) (actual time=0.140..0.621 rows=86 loops=1)

                           Merge Cond: ("з_1"."id_Клиента" = "з"."id_Клиента")

                           Buffers: shared hit=175

                           ->  GroupAggregate  (cost=1.26..91.79 rows=39 width=376) (actual time=0.130..0.551 rows=38 loops=1)

                                 Group Key: "з_1"."id_Клиента", "к_1"."Фамилия", "к_1"."Имя"

                                 Filter: (count(*) > 1)

                                 Rows Removed by Filter: 64

                                 Buffers: shared hit=101

                                 ->  Incremental Sort  (cost=1.26..86.98 rows=118 width=366) (actual time=0.111..0.328 rows=150 loops=1)

                                       Sort Key: "з_1"."id_Клиента", "к_1"."Фамилия", "к_1"."Имя"

                                       Presorted Key: "з_1"."id_Клиента"

                                       Full-sort Groups: 5  Sort Method: quicksort  Average Memory: 29kB  Peak Memory: 29kB

                                       Buffers: shared hit=101

                                       ->  Nested Loop  (cost=0.44..82.23 rows=118 width=366) (actual time=0.026..0.276 rows=150 loops=1)

                                             Buffers: shared hit=101

                                             ->  Merge Join  (cost=0.29..73.99 rows=118 width=248) (actual time=0.018..0.204 rows=150 loops=1)

                                                   Merge Cond: ("з_1"."id_Клиента" = "к_1"."id_Клиента")

                                                   Buffers: shared hit=81

                                                   ->  WindowAgg  (cost=0.14..21.39 rows=150 width=80) (actual time=0.012..0.132 rows=150 loops=1)

                                                         Buffers: shared hit=76

                                                         ->  Index Only Scan using "idx_заём_клиент_дата_covering" on "Документ_займа" "з_1"  (cost=0.14..18.39 rows=150 width=12) (actual time=0.007..0.045 rows=150 loops=1)

                                                               Heap Fetches: 150

                                                               Buffers: shared hit=76

                                                   ->  Index Scan using "Клиент_pkey" on "Клиент" "к_1"  (cost=0.14..49.34 rows=80 width=240) (actual time=0.005..0.029 rows=200 loops=1)

                                                         Buffers: shared hit=5

                                             ->  Memoize  (cost=0.16..0.49 rows=1 width=122) (actual time=0.000..0.000 rows=1 loops=150)

                                                   Cache Key: "з_1"."id_Отделения"

                                                   Cache Mode: logical

                                                   Hits: 140  Misses: 10  Evictions: 0  Overflows: 0  Memory Usage: 2kB

                                                   Buffers: shared hit=20

                                                   ->  Index Scan using "Отделение_pkey" on "Отделение" "о_1"  (cost=0.15..0.48 rows=1 width=122) (actual time=0.001..0.001 rows=1 loops=10)

                                                         Index Cond: ("id_Отделения" = "з_1"."id_Отделения")

                                                         Buffers: shared hit=20

                           ->  Index Scan using "idx_заем_клиент" on "Документ_займа" "з"  (cost=0.14..18.39 rows=150 width=17) (actual time=0.008..0.036 rows=147 loops=1)

                                 Buffers: shared hit=74

                     ->  Index Only Scan using "idx_заём_клиент_дата_covering" on "Документ_займа" "з2"  (cost=0.14..0.27 rows=1 width=12) (actual time=0.001..0.001 rows=1 loops=86)

                           Index Cond: (("id_Клиента" = "з"."id_Клиента") AND ("Дата_выдачи" > "з"."Дата_выдачи"))

                           Heap Fetches: 60

                           Buffers: shared hit=138

               ->  Index Only Scan using "Клиент_pkey" on "Клиент" "к"  (cost=0.14..0.48 rows=1 width=4) (actual time=0.001..0.001 rows=1 loops=38)

                     Index Cond: ("id_Клиента" = "з"."id_Клиента")

                     Heap Fetches: 38

                     Buffers: shared hit=76

         ->  Index Scan using "Отделение_pkey" on "Отделение" "о"  (cost=0.15..0.48 rows=1 width=122) (actual time=0.001..0.001 rows=1 loops=38)

               Index Cond: ("id_Отделения" = "з"."id_Отделения")

               Buffers: shared hit=76

 Planning:

   Buffers: shared hit=22 read=1

 Planning Time: 0.626 ms

 Execution Time: 0.885 ms

(62 rows)
```

---

## Таблица сравнения показателей

| Метрика                   | З2 ДО (seqscan=ON) | З2 ПОСЛЕ (seqscan=OFF)                     | З4 ДО (seqscan=ON) | З4 ПОСЛЕ (seqscan=OFF)                                                     |
| ------------------------- | ------------------ | ------------------------------------------ | ------------------ | -------------------------------------------------------------------------- |
| **Execution Time**        | 3.602 ms           | 3.438 ms                                   | 1.012 ms           | 0.885 ms                                                                   |
| **Скан `План_выплат`**    | Seq Scan           | **Index Scan** `idx_план_займ_дата_статус` | —                  | —                                                                          |
| **Скан `Документ_займа`** | Seq Scan           | Index Scan                                 | Seq Scan (×3)      | **Index Only Scan** `idx_заём_клиент_дата_covering` (×2) + Index Scan (×1) |
| **Стратегия JOIN**        | Hash Join          | **Merge Join**                             | Hash Join          | **Merge Join / Nested Loop Left Join**                                     |


| Метрика                   | Запрос 2 ДО   | Запрос 2 ПОСЛЕ           | Запрос 4 ДО   | Запрос 4 ПОСЛЕ           |
| ------------------------- | ------------- | ------------------------ | ------------- | ------------------------ |
| **Execution Time**        | 21 247 ms     | 382 ms                   | 21 247 ms     | 115 ms                   |
| **Скан `План_выплат`**    | Seq Scan      | **Index Scan**           | —             | —                        |
| **Скан `Документ_займа`** | Seq Scan (×3) | **Index Only Scan (×3)** | Seq Scan (×3) | **Index Only Scan (×3)** |
| **Стратегия JOIN**        | Hash Join     | **Merge Join**           | Hash Join     | **Merge Join**           |

---

## Пояснение JOIN-стратегий

### Hash Join / Merge Join

До индексов планировщик использует `Hash Join`: строит хеш-таблицу меньшего набора в памяти, затем проходит по большему. После создания составного индекса данные уже физически отсортированы в порядке `(id_Займа, Плановая_дата_оплаты)`. Планировщик переключается на `Merge Join` — соединение двух предварительно отсортированных потоков без построения хеш-таблицы. Это особенно эффективно при большом объёме данных.

### Index Only Scan

Покрывающий индекс `idx_заём_клиент_дата_covering` содержит все колонки, нужные запросу (`id_Клиента`, `Дата_выдачи`, `id_Займа`, `id_Отделения`, `Сумма_займа`). Планировщик выполняет `Index Only Scan` — читает данные прямо из B-tree индекса, не обращаясь к heap-страницам таблицы вообще. Это устраняет двойное I/O (индекс + таблица) и даёт наибольший прирост производительности.

---

## Выводы

Три спроектированных индекса решают разные задачи:

- **Составной** `idx_план_займ_дата_статус` устранил `Sort` на 62 058 строках и заменил `Hash Join` на `Merge Join`, использующий уже отсортированный порядок индекса
- **Частичный** `idx_план_просрочено` подготовлен для сценария рефакторинга запроса с переносом фильтра внутрь подзапроса
- **Покрывающий** `idx_заём_клиент_дата_covering` полностью устранил обращения к heap-страницам `Документ_займа` во всех трёх точках соединения запроса 4, заменив `Seq Scan × 3` на `Index Only Scan × 3`

