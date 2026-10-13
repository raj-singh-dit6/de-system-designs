FROM postgres:16.15

# PostgreSQL executes these files, in lexical order, only when it creates a
# new database cluster. The processed Section 1 output is copied in as a
# read-only seed source for the member-reference load.
# PostgreSQL runs these files, in lexical order, when it initializes an empty
# volume. The final file loads the local mock catalogue and sales fixtures.
COPY section-2-database/sql/01_star_schema.sql /docker-entrypoint-initdb.d/
COPY section-2-database/sql/02_load_successful_members.sql /docker-entrypoint-initdb.d/
COPY section-2-database/sql/03_analyst_queries.sql /docker-entrypoint-initdb.d/
COPY section-2-database/sql/04_load_mock_sales_data.sql /docker-entrypoint-initdb.d/
COPY section-1-pipeline/output/successful/successful_applications.csv /seed/successful_applications.csv
COPY section-2-database/mock-data/ /mock-data/
