-- 1. Top 10 members by completed-order spending.
SELECT
    member.membership_id,
    member.first_name,
    member.last_name,
    SUM(sales_line.line_total_price) AS total_spending
FROM analytics.fact_sales_order_line AS sales_line
JOIN analytics.dim_member AS member ON member.member_key = sales_line.member_key
JOIN analytics.dim_order_status AS order_status
    ON order_status.order_status_key = sales_line.order_status_key
WHERE order_status.status_name = 'completed'
GROUP BY member.member_key, member.membership_id, member.first_name, member.last_name
ORDER BY total_spending DESC, member.membership_id
LIMIT 10;

-- 2. Top 3 products by quantity purchased on completed orders.
SELECT
    product.item_name,
    product.manufacturer_name,
    SUM(sales_line.quantity) AS total_quantity_bought
FROM analytics.fact_sales_order_line AS sales_line
JOIN analytics.dim_product AS product ON product.product_key = sales_line.product_key
JOIN analytics.dim_order_status AS order_status
    ON order_status.order_status_key = sales_line.order_status_key
WHERE order_status.status_name = 'completed'
GROUP BY product.product_key, product.item_name, product.manufacturer_name
ORDER BY total_quantity_bought DESC, product.item_name, product.manufacturer_name
LIMIT 3;
