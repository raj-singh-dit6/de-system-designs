# Data Engineer technical assessment

This repository contains the implementation, generated data, and design documentation for the Data Engineer technical assessment. The project demonstrates batch ingestion and data-quality validation first, followed by database and cloud-system-design deliverables.

## Project scope

| Section | Purpose | Status |
| --- | --- | --- |
| [Section 1: Membership application pipeline](section-1-pipeline/README.md) | Process hourly application batches, validate eligibility, and publish successful and unsuccessful records separately. | Implemented |
| [Airflow Docker setup](airflow/README.md) | Orchestrate the Section 1 pipeline with an hourly Airflow DAG. | Implemented |
| [Section 2: Sales analytics database](section-2-database/README.md) | Load successful memberships and report sales through a PostgreSQL star schema. | Implemented |
| [Section 3: System designs](section-3-system-design/) | Define database access controls and image-processing cloud architecture. | Implemented |

## Setup

Section 1 requires Python 3 only and has no third-party dependencies. The optional Airflow scheduler requires Docker Compose v2.

```bash
git clone https://github.com/raj-singh-dit6/de-system-designs.git
cd de-system-designs
make test
```

## Section 1: Membership application pipeline

### Run locally

Run the membership pipeline locally:

```bash
make run-pipeline
```

The pipeline reads all CSV files in `section-1-pipeline/input/` and writes consolidated result files to:

- `section-1-pipeline/output/successful/successful_applications.csv`
- `section-1-pipeline/output/unsuccessful/unsuccessful_applications.csv`

See the [Section 1 README](section-1-pipeline/README.md) for validation rules, output schema, and assumptions.

### Airflow scheduling

The local Airflow 3.3.2 setup runs the `membership_application_pipeline` DAG hourly. The DAG executes the same `run_pipeline.sh` script used by `make run-pipeline`, so its results are written to the normal Section 1 output folders.

```bash
make airflow-init  # Run once to initialize Airflow metadata.
make airflow-up    # Start the API server, scheduler, and DAG processor.
```

Open <http://localhost:8080> to view or manually trigger the DAG. The local setup disables authentication and grants administrator access to every visitor; it is for development and assessment demonstration only. Use `make airflow-logs` to follow scheduler logs and `make airflow-down` to stop the services.

See the [Airflow README](airflow/README.md) for prerequisites, Airflow 3 upgrade notes, and lifecycle details.

### Pipeline architecture

```text
Hourly CSV batches --> Airflow DAG --> Python validation and transformation --> Successful output CSV
                                              |
                                              +------------------------------> Unsuccessful output CSV with rejection reasons
```

The pipeline records validation failures for each rejected row, supporting downstream consumers and data-quality investigation.

## Section 2: Sales analytics database

Section 2 provides a self-initialising PostgreSQL 16 sales analytics database.
It loads successful membership applications from Section 1 into a reporting
star schema and includes sample product and sales-order data for local review.

```bash
docker compose -f section-2-database/docker-compose.yml up --build -d
```

The design includes dimensions for members, products, and order statuses, plus
a sales-order-line fact table. It also supplies the requested top-spending and
most-frequently-purchased-item SQL queries. See the
[Section 2 README](section-2-database/README.md) for the data model, SQL
scripts, database access, and reporting queries.

## Section 3: System designs

Section 3 contains two presentation-based architecture designs:

- [System design 1: Datawarehouse Governance Strategy](section-3-system-design/system-design-1/README.md) defines least-privilege PostgreSQL access for analytics, sales, and logistics applications.
- [System design 2: Cloud image-processing platform](section-3-system-design/system-design-2/README.md) defines an AWS architecture for API and Kafka ingestion, ECS image processing, seven-day retention, and BI analytics.

Each design folder includes its supporting documentation and PowerPoint deck.

## Decision notes

- The Section 1 implementation uses the Python standard library to keep local execution and assessment review simple.
- Airflow invokes the existing pipeline script rather than duplicating transformation logic in the DAG.
- Invalid applications are retained in a separate output rather than discarded, with all detected rejection reasons recorded.
- Age is calculated against the assessment's fixed reference date of 1 January 2022.
