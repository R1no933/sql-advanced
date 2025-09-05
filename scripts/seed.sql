-- 1. Сперва реализуем генератор данных для таблиц customers и products через gs --
-- Так в тз не указано количество записей в данных таблицах, сгенерируем 2000 записей для каждой --
INSERT INTO customers(name, email)
SELECT 'Customer ' || gs,
       'customer' || gs || '@example.com'
FROM generate_series(1, 2000) gs
ON CONFLICT DO NOTHING;

INSERT INTO products(name, price)
SELECT 'Product ' || gs,
       round((random() * 99990 + 10)::NUMERIC, 2)
FROM generate_series(1, 2000) gs
ON CONFLICT DO NOTHING;

-- 2. Генерируем данные для таблицы orders при помощи CTE--
-- customer_id и products_id берем из уже заполненных таблиц в рандомном порядке --
-- данные инсертим по 100к записей чтобы транзакции были короткие и не занимали много времени--
DO
$$
    BEGIN
        FOR i IN 1..500
            LOOP
                INSERT INTO orders (customer_id, product_id, created_at, amount, status)
                WITH batch_data AS (SELECT (SELECT customer_id
                                            FROM customers
                                            OFFSET floor(random() * (SELECT count(*) FROM customers)) LIMIT 1)             as cust_id,
                                           (SELECT product_id
                                            FROM products
                                            OFFSET floor(random() * (SELECT count(*) FROM products)) LIMIT 1)              as prod_id,
                                           now() - (floor(random() * 365) || ' days')::INTERVAL                            as created_date,
                                           round((random() * 999990 + 10)::numeric, 2)                                     as order_amount,
                                           (array ['completed','pending','cancelled','refunded'])[floor(random() * 4) + 1] as order_status
                                    FROM generate_series(1, 100000) -- Партия 100k
                )
                SELECT cust_id, prod_id, created_date, order_amount, order_status
                FROM batch_data;
                COMMIT;
                RAISE NOTICE 'Вставленно % записей', i * 100000;
            END LOOP;
    END
$$

