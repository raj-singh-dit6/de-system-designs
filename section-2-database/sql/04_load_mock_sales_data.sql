-- Idempotent local-development fixture loader.
-- Docker runs this after the schema and member loads on a fresh database
-- volume. It can also be run manually to restore the sample fixtures.

CREATE TEMP TABLE product_stage (
    item_name TEXT,
    manufacturer_name TEXT,
    current_unit_cost NUMERIC(12, 2),
    current_unit_weight_kg NUMERIC(10, 3),
    is_active BOOLEAN
);

COPY product_stage
FROM '/mock-data/dim_product.csv'
WITH (FORMAT csv, HEADER true);

INSERT INTO analytics.dim_product (
    item_name,
    manufacturer_name,
    current_unit_cost,
    current_unit_weight_kg,
    is_active
)
SELECT
    item_name,
    manufacturer_name,
    current_unit_cost,
    current_unit_weight_kg,
    is_active
FROM product_stage
ON CONFLICT (item_name, manufacturer_name) DO UPDATE
SET current_unit_cost = EXCLUDED.current_unit_cost,
    current_unit_weight_kg = EXCLUDED.current_unit_weight_kg,
    is_active = EXCLUDED.is_active;

CREATE TEMP TABLE sales_order_line_stage (
    order_id BIGINT,
    order_line_number SMALLINT,
    membership_id TEXT,
    item_name TEXT,
    manufacturer_name TEXT,
    order_status TEXT,
    ordered_at TIMESTAMPTZ,
    quantity INTEGER,
    unit_price NUMERIC(12, 2),
    unit_weight_kg NUMERIC(10, 3)
);

COPY sales_order_line_stage
FROM '/mock-data/fact_sales_order_line.csv'
WITH (FORMAT csv, HEADER true);

INSERT INTO analytics.fact_sales_order_line (
    order_id,
    order_line_number,
    member_key,
    product_key,
    order_status_key,
    ordered_at,
    quantity,
    unit_price,
    unit_weight_kg
)
SELECT
    stage.order_id,
    stage.order_line_number,
    member.member_key,
    product.product_key,
    order_status.order_status_key,
    stage.ordered_at,
    stage.quantity,
    stage.unit_price,
    stage.unit_weight_kg
FROM sales_order_line_stage AS stage
JOIN analytics.dim_member AS member ON member.membership_id = stage.membership_id
JOIN analytics.dim_product AS product
    ON product.item_name = stage.item_name
    AND product.manufacturer_name = stage.manufacturer_name
JOIN analytics.dim_order_status AS order_status
    ON order_status.status_name = stage.order_status
ON CONFLICT (order_id, order_line_number) DO UPDATE
SET member_key = EXCLUDED.member_key,
    product_key = EXCLUDED.product_key,
    order_status_key = EXCLUDED.order_status_key,
    ordered_at = EXCLUDED.ordered_at,
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price,
    unit_weight_kg = EXCLUDED.unit_weight_kg;
