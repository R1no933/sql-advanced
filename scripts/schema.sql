CREATE TABLE customers
(
    customer_id SERIAL PRIMARY KEY,
    name        TEXT,
    email       TEXT
);
CREATE TABLE products
(
    product_id SERIAL PRIMARY KEY,
    name       TEXT,
    price      NUMERIC(10, 2)
);

CREATE TABLE orders
(
    order_id    SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    product_id  INT REFERENCES products(product_id),
    created_at  TIMESTAMP NOT NULL,
    amount      NUMERIC(10, 2),
    status      TEXT
);
