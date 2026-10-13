"""Hourly orchestration of the Section 1 membership-application batch pipeline."""

import pendulum

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG, literal


with DAG(
    dag_id="membership_application_pipeline",
    description="Processes all membership application CSV batches dropped into the input folder.",
    schedule="@hourly",
    start_date=pendulum.datetime(2022, 1, 1, tz="Singapore"),
    catchup=False,
    tags=["membership", "assessment"],
) as dag:
    run_membership_pipeline = BashOperator(
        task_id="process_membership_applications",
        # Prevent Airflow from treating the mounted .sh path as a Jinja template file.
        bash_command=literal("/opt/pipeline/run_pipeline.sh"),
    )
