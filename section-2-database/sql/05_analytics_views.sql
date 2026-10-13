-- Read-only analytical contracts. These views intentionally omit member email
-- and application-reference data so analysts can work with sales and
-- membership measures without direct access to unnecessary personal data.

CREATE OR REPLACE VIEW analytics.v_analytics_sales_membership AS
SELECT
    sales_line.order_id,
    sales_line.order_line_number,
    sales_line.ordered_at,
    order_status.status_name AS order_status,
    member.membership_id,
    member.first_name,
    member.last_name,
    member.above_18,
    product.item_name,
    product.manufacturer_name,
    sales_line.quantity,
    sales_line.unit_price,
    sales_line.unit_weight_kg,
    sales_line.line_total_price,
    sales_line.line_total_weight_kg
FROM analytics.fact_sales_order_line AS sales_line
JOIN analytics.dim_member AS member ON member.member_key = sales_line.member_key
JOIN analytics.dim_product AS product ON product.product_key = sales_line.product_key
JOIN analytics.dim_order_status AS order_status
    ON order_status.order_status_key = sales_line.order_status_key;

CREATE OR REPLACE VIEW analytics.v_analytics_member_sales_summary AS
SELECT
    member.membership_id,
    member.first_name,
    member.last_name,
    member.above_18,
    COUNT(DISTINCT sales_line.order_id) AS total_order_count,
    COUNT(DISTINCT sales_line.order_id)
        FILTER (WHERE order_status.status_name = 'completed') AS completed_order_count,
    COALESCE(
        SUM(sales_line.line_total_price)
            FILTER (WHERE order_status.status_name = 'completed'),
        0
    ) AS completed_order_spending,
    COALESCE(
        SUM(sales_line.line_total_weight_kg)
            FILTER (WHERE order_status.status_name = 'completed'),
        0
    ) AS completed_order_weight_kg,
    MAX(sales_line.ordered_at) AS most_recent_order_at
FROM analytics.dim_member AS member
LEFT JOIN analytics.fact_sales_order_line AS sales_line
    ON sales_line.member_key = member.member_key
LEFT JOIN analytics.dim_order_status AS order_status
    ON order_status.order_status_key = sales_line.order_status_key
GROUP BY member.member_key, member.membership_id, member.first_name, member.last_name, member.above_18;
