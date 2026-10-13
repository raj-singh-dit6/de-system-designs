# Data Engineer technical assessment

This repository contains the implementation, generated data, and design documentation for the Data Engineer technical assessment. The project demonstrates batch ingestion and data-quality validation first, followed by database and cloud-system-design deliverables.

## Project scope

| Section | Purpose | Status |
| --- | --- | --- |
| [Section 1: Membership application pipeline](section-1-pipeline/README.md) | Process hourly application batches, validate eligibility, and publish successful and unsuccessful records separately. | Implemented |
| Section 2: Database | Model membership and sales transactions in PostgreSQL. | Planned |
| Section 3: System design | Define database access controls and image-processing cloud architecture. | Planned |

## Setup

Section 1 requires Python 3 only; it has no third-party dependencies.

```bash
git clone https://github.com/raj-singh-dit6/de-system-designs.git
cd de-system-designs/section-1-pipeline
python3 -m unittest discover -s tests -v
```

## Usage

Run the membership pipeline from its directory:

```bash
./run_pipeline.sh
```

The pipeline reads all CSV files in `section-1-pipeline/input/` and writes consolidated result files to:

- `section-1-pipeline/output/successful/successful_applications.csv`
- `section-1-pipeline/output/unsuccessful/unsuccessful_applications.csv`

See the [Section 1 README](section-1-pipeline/README.md) for validation rules, hourly scheduling, output schema, and assumptions.

## Architecture

```text
Hourly CSV batches
       |
       v
Input directory --> Python validation and transformation --> Successful output CSV
                         |
                         +-------------------------------> Unsuccessful output CSV with rejection reasons
```

The pipeline records validation failures for each rejected row, supporting downstream consumers and data-quality investigation.

## Decision notes

- The Section 1 implementation uses the Python standard library to keep local execution and assessment review simple.
- Invalid applications are retained in a separate output rather than discarded, with all detected rejection reasons recorded.
- Age is calculated against the assessment's fixed reference date of 1 January 2022.
