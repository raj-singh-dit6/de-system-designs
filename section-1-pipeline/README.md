# Section 1: Membership application pipeline

This hourly batch pipeline consolidates all CSV membership-application files from `input/`, transforms their fields, validates applications, and publishes successful and unsuccessful records to separate folders.

## Run locally

From this directory:

```bash
./run_pipeline.sh
python3 -m unittest discover -s tests -v
```

The project has no third-party Python dependencies.

## Hourly scheduling

Install this crontab entry after replacing the absolute path:

```cron
0 * * * * /absolute/path/to/de-system-designs/section-1-pipeline/run_pipeline.sh >> /absolute/path/to/de-system-designs/section-1-pipeline/pipeline.log 2>&1
```

The scheduler runs at the start of every hour. Each run processes every `.csv` file present in `input/` and replaces the two consolidated output files. In a production deployment, the input directory should be an hourly landing zone and processed files should be archived or moved after a successful run to prevent reprocessing.

## Transformations and validation

| Requirement | Implementation |
| --- | --- |
| Name | Removes common honorifics, then uses the first token as `first_name` and final token as `last_name`. Missing names are unsuccessful. |
| Birthday | Accepts ISO, `YYYY/MM/DD`, `MM/DD/YYYY`, `DD-MM-YYYY`, and `DD/MM/YYYY`; outputs `YYYYMMDD`. |
| Age | `above_18` is evaluated against 1 January 2022. An applicant born on or before 1 January 2004 passes. |
| Mobile | Must contain exactly eight digits. |
| Email | Any valid email provider is accepted when its domain ends in `.com` or `.net`, case-insensitively (for example, `person@company.com` or `person@provider.net`). |
| Membership ID | Successful records receive `<last_name>_<first five SHA256 hex characters of YYYYMMDD>`. |

Unsuccessful rows include all failed rules in `validation_errors`. This preserves an audit trail rather than silently discarding invalid applications.

## Output schema

Both output files have: `first_name`, `last_name`, `email`, `date_of_birth`, `mobile_no`, `above_18`, `membership_id`, and `validation_errors`.

- `output/successful/successful_applications.csv` contains only applications that pass every rule.
- `output/unsuccessful/unsuccessful_applications.csv` contains every rejected record and its reason(s).

## Supplied-dataset run

The checked-in source datasets contain 4,999 applications. Run `./run_pipeline.sh` to regenerate the checked-in successful and unsuccessful consolidated outputs. The rejection file retains every failed rule, including `invalid_mobile`, `under_18`, and `invalid_email`, for auditability.

## Assumptions

- The source files contain `name`, `email`, `date_of_birth`, and `mobile_no` headers.
- Ambiguous slash-formatted dates are interpreted as `MM/DD/YYYY`, matching the source-data convention.
- A person with a single supplied name has an empty `last_name`; this remains valid unless another rule fails.
