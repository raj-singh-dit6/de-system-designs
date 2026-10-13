# E-commerce sales star schema

```mermaid
erDiagram
    DIM_MEMBER ||--o{ FACT_SALES_ORDER_LINE : places
    DIM_PRODUCT ||--o{ FACT_SALES_ORDER_LINE : appears_on
    DIM_ORDER_STATUS ||--o{ FACT_SALES_ORDER_LINE : has
    MEMBER_APPLICATION_REFERENCE }o..|| DIM_MEMBER : canonicalizes_to

    DIM_MEMBER {
        bigint member_key PK
        text membership_id UK
        text first_name
        text last_name
        text email
        boolean above_18
    }
    DIM_PRODUCT {
        bigint product_key PK
        text item_name
        text manufacturer_name
        numeric current_unit_cost
        numeric current_unit_weight_kg
        boolean is_active
    }
    DIM_ORDER_STATUS {
        smallint order_status_key PK
        text status_name UK
    }
    FACT_SALES_ORDER_LINE {
        bigint order_id PK
        smallint order_line_number PK
        bigint member_key FK
        bigint product_key FK
        smallint order_status_key FK
        timestamptz ordered_at
        integer quantity
        numeric unit_price
        numeric unit_weight_kg
        numeric line_total_price
        numeric line_total_weight_kg
    }
    MEMBER_APPLICATION_REFERENCE {
        bigint application_reference_key PK
        text membership_id
        date date_of_birth
    }
```

`fact_sales_order_line` has one row for each product line in an order. Its
stored price and weight measures preserve the values at the time of sale. The
product dimension stores the current catalogue attributes; it is not used to
recalculate historical order totals.

There is deliberately no `dim_date`. The stated reports do not require date
attributes, and `ordered_at` supplies the timestamp needed for filtering. A
date dimension can be added when calendar reporting becomes a requirement.
