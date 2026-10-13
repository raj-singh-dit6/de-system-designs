#!/usr/bin/env python3
"""Process hourly membership-application CSV batches using only the Python standard library."""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Iterable


REFERENCE_DATE = date(2022, 1, 1)
# The provider label may vary; only the required .com or .net domain suffix is fixed.
VALID_EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.(?:com|net)$", re.IGNORECASE)
DATE_FORMATS = ("%Y-%m-%d", "%Y/%m/%d", "%m/%d/%Y", "%d-%m-%Y", "%d/%m/%Y")
HONORIFICS = {"mr", "mrs", "ms", "dr", "prof"}
OUTPUT_FIELDS = (
    "first_name",
    "last_name",
    "email",
    "date_of_birth",
    "mobile_no",
    "above_18",
    "membership_id",
    "validation_errors",
)


@dataclass(frozen=True)
class ProcessResult:
    successful_count: int
    unsuccessful_count: int


def parse_date(value: str) -> date | None:
    """Return a date for supported source formats, or None when parsing fails."""
    for date_format in DATE_FORMATS:
        try:
            return datetime.strptime(value.strip(), date_format).date()
        except ValueError:
            continue
    return None


def split_name(value: str) -> tuple[str, str] | None:
    """Split a name into first and final name components after removing common titles."""
    parts = value.strip().split()
    if parts and parts[0].rstrip(".").lower() in HONORIFICS:
        parts = parts[1:]
    if not parts:
        return None
    if len(parts) == 1:
        return parts[0], ""
    return parts[0], parts[-1]


def is_at_least_18(birthday: date) -> bool:
    """Calculate age against the assessment's fixed reference date."""
    return birthday <= date(REFERENCE_DATE.year - 18, REFERENCE_DATE.month, REFERENCE_DATE.day)


def membership_id(last_name: str, birthday: date) -> str:
    digest = hashlib.sha256(birthday.strftime("%Y%m%d").encode("utf-8")).hexdigest()
    return f"{last_name}_{digest[:5]}"


def transform_row(row: dict[str, str]) -> tuple[bool, dict[str, str]]:
    """Transform one source row and return whether it passed every business rule."""
    errors: list[str] = []
    name = split_name(row.get("name", ""))
    if name is None:
        errors.append("missing_name")
        first_name, last_name = "", ""
    else:
        first_name, last_name = name

    email = row.get("email", "").strip().lower()
    if not VALID_EMAIL_PATTERN.fullmatch(email):
        errors.append("invalid_email")

    mobile_no = row.get("mobile_no", "").strip()
    if not re.fullmatch(r"\d{8}", mobile_no):
        errors.append("invalid_mobile")

    birthday = parse_date(row.get("date_of_birth", ""))
    if birthday is None:
        errors.append("invalid_birthdate")
        formatted_birthday, above_18 = "", ""
    else:
        formatted_birthday = birthday.strftime("%Y%m%d")
        above_18 = str(is_at_least_18(birthday)).lower()
        if not is_at_least_18(birthday):
            errors.append("under_18")

    successful = not errors
    output = {
        "first_name": first_name,
        "last_name": last_name,
        "email": email,
        "date_of_birth": formatted_birthday,
        "mobile_no": mobile_no,
        "above_18": above_18,
        "membership_id": membership_id(last_name, birthday) if successful and birthday else "",
        "validation_errors": ";".join(errors),
    }
    return successful, output


def read_batches(input_directory: Path) -> Iterable[dict[str, str]]:
    """Yield rows from every CSV present at the start of an hourly pipeline run."""
    for csv_path in sorted(input_directory.glob("*.csv")):
        with csv_path.open(newline="", encoding="utf-8-sig") as source:
            reader = csv.DictReader(source)
            required_columns = {"name", "email", "date_of_birth", "mobile_no"}
            if reader.fieldnames is None or not required_columns.issubset(reader.fieldnames):
                raise ValueError(f"{csv_path} is missing one or more required columns: {sorted(required_columns)}")
            for row in reader:
                yield row


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=OUTPUT_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def process_batches(input_directory: Path, output_directory: Path) -> ProcessResult:
    successful_rows: list[dict[str, str]] = []
    unsuccessful_rows: list[dict[str, str]] = []
    for row in read_batches(input_directory):
        successful, transformed = transform_row(row)
        (successful_rows if successful else unsuccessful_rows).append(transformed)

    write_csv(output_directory / "successful" / "successful_applications.csv", successful_rows)
    write_csv(output_directory / "unsuccessful" / "unsuccessful_applications.csv", unsuccessful_rows)
    return ProcessResult(len(successful_rows), len(unsuccessful_rows))


def main() -> None:
    parser = argparse.ArgumentParser(description="Process membership application CSV batches.")
    parser.add_argument("--input-dir", type=Path, default=Path("input"))
    parser.add_argument("--output-dir", type=Path, default=Path("output"))
    args = parser.parse_args()
    result = process_batches(args.input_dir, args.output_dir)
    print(f"Processed {result.successful_count + result.unsuccessful_count} applications: "
          f"{result.successful_count} successful, {result.unsuccessful_count} unsuccessful.")


if __name__ == "__main__":
    main()
