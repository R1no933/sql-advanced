-- Запрос 1 --
-- Вывести все имена покупателей, название продуктов и сумму и статус заказов с начала года до 2025-03-01--
-- Фактическое время выполнения запроса: ~10s, строк: 8_082_216 --
SELECT o.amount, o.status, p.name, c.name
FROM orders AS o
         JOIN products p ON o.product_id = p.product_id
         JOIN customers c ON o.customer_id = c.customer_id
WHERE o.created_at BETWEEN '2025-01-01' AND '2025-03-01';

-- Анализ запроса 1 (без индексов и партиций)--
--         ->  Seq Scan on orders o  (cost=0.00..1217230.00 rows=8155230 width=25) --
--         (actual time=0.009..2581.915 rows=8082216 loops=1) --
--               ->  Seq Scan on products p  (cost=0.00..35.00 rows=2000 width=16) --
--               (actual time=0.004..0.113 rows=2000 loops=1) --
--                  ->  Seq Scan on customers c  (cost=0.00..39.00 rows=2000 width=17) --
--                  (actual time=110.059..110.180 rows=2000 loops=1) --
EXPLAIN ANALYZE
SELECT o.amount, o.status, p.name, c.name
FROM orders AS o
         JOIN products p ON o.product_id = p.product_id
         JOIN customers c ON o.customer_id = c.customer_id
WHERE o.created_at BETWEEN '2025-01-01' AND '2025-03-01';

-- Оптимизация запроса 1 (индексы) --
-- Для оптимизации запроса создадим покрывающий индекс где --
-- created_at - для фильтрации через WHERE --
-- customer_id, product_id для JOINов --
-- amount, status для SELECT (данные будут уже в индексе)
CREATE INDEX idx_orders_covered ON orders(created_at, customer_id, product_id)
INCLUDE (amount, status);

DROP INDEX idx_orders_covered; -- для чистоты проверки 2 запроса и его оптимизации --

-- Анализ запроса 1 (с покрывающим индексом)--
--         ->  Index Only Scan using idx_orders_covered on orders o  (cost=0.56..396337.16 rows=8155230 width=25)
--         (actual time=0.115..860.064 rows=8082216 loops=1) --
-- Время и стоимость запроса запроса уменьшились в разы --
-- По products и customers остался seq scan так как для postgres по ним дешевле провести полное сканирование --
-- Так как в таблицах по 2000 записей всего(мало данных) --
EXPLAIN ANALYZE
SELECT o.amount, o.status, p.name, c.name
FROM orders AS o
         JOIN products p ON o.product_id = p.product_id
         JOIN customers c ON o.customer_id = c.customer_id
WHERE o.created_at BETWEEN '2025-01-01' AND '2025-03-01';

-- Запрос 2 --
-- Делаем запрос с низкой селективностью для вызова index scan --
-- Фактическое время выполнения запроса: ~4s, строк: 136_936 (~ 0.2%)
SELECT * FROM orders
WHERE created_at BETWEEN '2025-04-01' AND '2025-04-02';

-- Анализ запроса 2 (без индексов и партиций) --
-- Gather  (cost=1000.00..793263.07 rows=125335 width=37) (actual time=13.493..2658.048 rows=136936 loops=1) --
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE created_at BETWEEN '2025-04-01' AND '2025-04-02';

-- Создаем индекс --
CREATE INDEX idx_orders_created_at ON orders(created_at);
DROP INDEX idx_orders_created_at; -- для дропа индекса и проверки работы партиций --

-- Анализ запроса 2 (с индексом)--
-- Index Scan using idx_orders_created_at on orders  (cost=0.44..444977.06 rows=125335 width=37) --
--          (actual time=0.056..928.556 rows=136936 loops=1) --
-- Время и стоимость при использовании индексов уменьшилось --
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE created_at BETWEEN '2025-04-01' AND '2025-04-02';

-- Вывод --
-- Индексы хорошо себя показывают на низкоселективных запросах, однако если выборка большая (более 20-30%) --
-- для постгрес дешевле и быстрее использовать seq scan --

-- Партиции --
-- Создадим партиции для таблицы orders по столбцу created_at по 1 партиции для каждого месяца --
-- Используем дополнительную таблицу, так как в постгрес нельзя испльзовать ALTER TABLE для создания партиций --
CREATE TABLE orders_new
(
    order_id SERIAL,
    customer_id INT REFERENCES customers(customer_id),
    product_id INT REFERENCES products(product_id),
    created_at TIMESTAMP NOT NULL,
    amount NUMERIC(10, 2),
    status TEXT,
    PRIMARY KEY (order_id, created_at) -- составной РК так как а партиционированных таблицах первичный ключ должен включать все колонки партицирования --
) PARTITION BY RANGE (created_at);

-- Создаем партиции по месяцам --
CREATE TABLE orders_09_2024 PARTITION OF orders_new
    FOR VALUES FROM ('2024-09-01') TO ('2024-10-01');

CREATE TABLE orders_10_2024 PARTITION OF orders_new
    FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');

CREATE TABLE orders_11_2024 PARTITION OF orders_new
    FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');

CREATE TABLE orders_12_2024 PARTITION OF orders_new
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

CREATE TABLE orders_01_2025 PARTITION OF orders_new
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE orders_02_2025 PARTITION OF orders_new
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE orders_03_2025 PARTITION OF orders_new
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

CREATE TABLE orders_04_2025 PARTITION OF orders_new
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

CREATE TABLE orders_05_2025 PARTITION OF orders_new
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');

CREATE TABLE orders_06_2025 PARTITION OF orders_new
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

CREATE TABLE orders_07_2025 PARTITION OF orders_new
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');

CREATE TABLE orders_08_2025 PARTITION OF orders_new
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');

CREATE TABLE orders_09_2025 PARTITION OF orders_new
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');

-- Переносим данные из orders в orders_new в цикле партиями чтобы не переполнять WAL--
DO $$
    DECLARE
        batch_size INT := 100000;
        total_records INT := (SELECT COUNT(*) FROM orders);
        batches INT := ceil(total_records / batch_size::float);
        i INT;
    BEGIN
        FOR i IN 0..batches-1 LOOP
                INSERT INTO orders_new (order_id, customer_id, product_id, created_at, amount, status)
                SELECT order_id, customer_id, product_id, created_at, amount, status
                FROM orders
                ORDER BY order_id
                LIMIT batch_size OFFSET i * batch_size;

                RAISE NOTICE 'Перенесено % записей', (i+1) * batch_size;
                COMMIT;
            END LOOP;
    END $$;

-- Тут можно дропунть старую, переимновать новую и получим партиции для таблицы orders но я решил оставить обе --
-- И запросы делать уже к новой таблице для сравнения работы с партициями и без --
-- Запрос 1 --
-- Фактическое время выполнения: ~7s (быстрее чем без партиций) строк: 8_082_216 --
SELECT o.amount, o.status, p.name, c.name
FROM orders_new AS o
         JOIN products p ON o.product_id = p.product_id
         JOIN customers c ON o.customer_id = c.customer_id
WHERE o.created_at BETWEEN '2025-01-01' AND '2025-03-01';

-- Анализ запроса 1 (с партициями)--
--  ->  Seq Scan on orders_01_2025 o_1  (cost=0.00..103362.60 rows=4244991 width=25) (actual time=0.012..556.317 rows=4245711 loops=1) --
--      ->  Seq Scan on orders_02_2025 o_2  (cost=0.00..93398.18 rows=3835713 width=25) (actual time=0.661..500.169 rows=3836505 loops=1) --
--              ->  Seq Scan on orders_03_2025 o_3  (cost=0.00..103353.12 rows=1 width=25) (actual time=468.768..468.768 rows=0 loops=1) --
-- поиск идет по партициям, что сокращает стоимость и время выполнения --
EXPLAIN ANALYZE
SELECT o.amount, o.status, p.name, c.name
FROM orders_new AS o
         JOIN products p ON o.product_id = p.product_id
         JOIN customers c ON o.customer_id = c.customer_id
WHERE o.created_at BETWEEN '2025-01-01' AND '2025-03-01';

-- Запроса 2 --
-- Фактическое время выполнения: ~1s (быстрее чем без партиций) строк: 136_936 --
SELECT * FROM orders_new
WHERE created_at BETWEEN '2025-04-01' AND '2025-04-02';

-- Анализ запроса 1 (с партициями)--
--   ->  Parallel Seq Scan on orders_04_2025 orders_new  (cost=0.00..64028.12 rows=55554 width=37) (actual time=0.034..108.109 rows=45645 loops=3)
-- поиск идет по партициям, что сокращает стоимость и время выполнения --
EXPLAIN ANALYZE
SELECT * FROM orders_new
WHERE created_at BETWEEN '2025-04-01' AND '2025-04-02';

-- Блокировки --
BEGIN;
SELECT * FROM orders
WHERE order_id = 1 FOR UPDATE;  -- row блокировка по id запускаем в первой консоли и будет блокировать пока не выполним COMMIT\ROLLBACK
-- т.е. пока не завершим транзакцию --

BEGIN;
UPDATE orders set status = 'unknown' WHERE order_id = 1;
-- при запуске во 2 консоли получим дедлок, так как 1 запрос еще дерижт нужную нам запись --


