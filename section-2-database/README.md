# Section 2: E-commerce analytics database

This directory supplies a self-initialising PostgreSQL 16 database for the
assessment's sales reporting requirements. It is a **star schema**, designed
for read-heavy reporting rather than as the source-of-truth checkout system.

## Model

The schema has three dimensions and one fact table:

| Table | Purpose |
| --- | --- |
| `analytics.dim_member` | One canonical reporting member per membership ID. |
| `analytics.dim_product` | Current item and manufacturer catalogue attributes. |
| `analytics.dim_order_status` | Controlled transaction status values. |
| `analytics.fact_sales_order_line` | One item line on one order, with sale-time price and weight. |

`analytics.member_application_reference` retains all successful Section 1
applications for traceability. Since the Section 1 membership-ID algorithm can
collide, `dim_member` deterministically uses the first loaded application for
each ID while the reference table retains every source record.

See [the schema diagram](diagrams/entity_relationship_diagram.md) for the relationships and
the rationale for intentionally omitting `dim_date`.

## SQL files

| File | Executed purpose |
| --- | --- |
| `sql/01_star_schema.sql` | Creates the analytics schema, dimensions, fact table, checks, indexes, and order statuses. |
| `sql/02_load_successful_members.sql` | Loads Section 1 successful applications into the reference table and member dimension. |
| `sql/03_analyst_queries.sql` | Defines the two requested analyst queries. |
| `sql/04_load_mock_sales_data.sql` | Loads the local product and sales-line fixtures during fresh database initialization. |
| `sql/05_analytics_views.sql` | Creates the read-only sales/member views intended for analysts. |

## Run locally

From the repository root:

```bash
docker compose -f section-2-database/docker-compose.yml up --build -d
docker compose -f section-2-database/docker-compose.yml exec analytics-db \
  psql -U ecommerce_owner -d ecommerce_analytics
```

The database listens on `localhost:5434`. PostgreSQL only runs initialization
scripts when its data directory is empty. To rebuild from the SQL files, stop
and remove this stack's named volume, then start it again:

```bash
docker compose -f section-2-database/docker-compose.yml down --volumes
docker compose -f section-2-database/docker-compose.yml up --build -d
```

## Reporting queries

Run the requested queries after loading sales facts:

```bash
docker compose -f section-2-database/docker-compose.yml exec -T analytics-db \
  psql -U ecommerce_owner -d ecommerce_analytics \
  -f /docker-entrypoint-initdb.d/03_analyst_queries.sql
```

Only `completed` orders contribute to spending and purchase-frequency results;
cancelled and in-progress orders are excluded.

## Analytics views

Analytics should be granted `SELECT` on these views—not on the underlying
tables:

| View | Purpose |
| --- | --- |
| `analytics.v_analytics_sales_membership` | Sales-line analysis with product, order status, and non-sensitive membership attributes. |
| `analytics.v_analytics_member_sales_summary` | One row per member with total and completed-order measures. |

Both views omit member email, mobile number, date of birth, and application
reference records.

## Loading catalogue and order facts

The assessment does not provide product or order source data, so no invented
sales records are seeded. Load product records into `dim_product`, obtain the
dimension keys, then insert one row per order item into
`fact_sales_order_line`. Capture `unit_price` and `unit_weight_kg` from the
sale event so later catalogue changes do not rewrite history.

Small local-development fixtures are available in
[`mock-data/`](mock-data/README.md) and are automatically loaded when Docker
creates a fresh database volume. `dim_product.csv` maps to the product
dimension, while the fact fixture carries readable business identifiers that
the load step resolves to dimension keys.

To load those fixtures after starting the stack, run:

```bash
docker compose -f section-2-database/docker-compose.yml exec -T analytics-db \
  psql -v ON_ERROR_STOP=1 -U ecommerce_owner -d ecommerce_analytics \
  -f /docker-entrypoint-initdb.d/04_load_mock_sales_data.sql
```

This loader is idempotent: product rows are upserted by item/manufacturer and
fact rows by order ID/line number.
