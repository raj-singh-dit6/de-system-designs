-- Analytics star schema for member sales reporting.
-- Grain of fact_sales_order_line: one product line on one member order.

CREATE SCHEMA analytics;

CREATE TABLE analytics.member_application_reference (
    application_reference_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    membership_id TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL,
    date_of_birth DATE NOT NULL,
    mobile_no CHAR(8) NOT NULL,
    above_18 BOOLEAN NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE analytics.dim_member (
    member_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    membership_id TEXT NOT NULL UNIQUE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL,
    above_18 BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE analytics.dim_product (
    product_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_name TEXT NOT NULL,
    manufacturer_name TEXT NOT NULL,
    current_unit_cost NUMERIC(12, 2) NOT NULL CHECK (current_unit_cost >= 0),
    current_unit_weight_kg NUMERIC(10, 3) NOT NULL CHECK (current_unit_weight_kg > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (item_name, manufacturer_name)
);

CREATE TABLE analytics.dim_order_status (
    order_status_key SMALLINT PRIMARY KEY,
    status_name TEXT NOT NULL UNIQUE,
    CHECK (status_name IN ('pending', 'processing', 'completed', 'cancelled'))
);

INSERT INTO analytics.dim_order_status (order_status_key, status_name) VALUES
    (1, 'pending'),
    (2, 'processing'),
    (3, 'completed'),
    (4, 'cancelled');

CREATE TABLE analytics.fact_sales_order_line (
    order_id BIGINT NOT NULL,
    order_line_number SMALLINT NOT NULL CHECK (order_line_number > 0),
    member_key BIGINT NOT NULL REFERENCES analytics.dim_member (member_key),
    product_key BIGINT NOT NULL REFERENCES analytics.dim_product (product_key),
    order_status_key SMALLINT NOT NULL REFERENCES analytics.dim_order_status (order_status_key),
    ordered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    unit_weight_kg NUMERIC(10, 3) NOT NULL CHECK (unit_weight_kg > 0),
    line_total_price NUMERIC(14, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    line_total_weight_kg NUMERIC(12, 3) GENERATED ALWAYS AS (quantity * unit_weight_kg) STORED,
    PRIMARY KEY (order_id, order_line_number)
);

CREATE INDEX fact_sales_order_line_member_idx
    ON analytics.fact_sales_order_line (member_key);
CREATE INDEX fact_sales_order_line_product_idx
    ON analytics.fact_sales_order_line (product_key);
CREATE INDEX fact_sales_order_line_status_idx
    ON analytics.fact_sales_order_line (order_status_key);
CREATE INDEX fact_sales_order_line_ordered_at_idx
    ON analytics.fact_sales_order_line (ordered_at);
