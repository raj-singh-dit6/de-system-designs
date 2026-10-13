AIRFLOW_COMPOSE := docker compose -f airflow/docker-compose.yml

.DEFAULT_GOAL := help

.PHONY: help test run-pipeline validate airflow-init airflow-up airflow-down airflow-logs

help: ## List available commands.
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## Run the Section 1 unit tests.
	python3 -m unittest discover -s section-1-pipeline/tests -v

run-pipeline: ## Process all membership-application CSV files locally.
	./section-1-pipeline/run_pipeline.sh

validate: ## Validate the Airflow Compose configuration and DAG syntax.
	$(AIRFLOW_COMPOSE) config --quiet
	python3 -c "from pathlib import Path; compile(Path('airflow/dags/membership_application_pipeline.py').read_text(encoding='utf-8'), 'membership_application_pipeline.py', 'exec')"

airflow-init: ## Initialize the local Airflow metadata database.
	$(AIRFLOW_COMPOSE) --profile setup run --rm airflow-init

airflow-up: ## Start the local Airflow API server, scheduler, and DAG processor.
	$(AIRFLOW_COMPOSE) up -d

airflow-down: ## Stop local Airflow services while preserving their metadata volume.
	$(AIRFLOW_COMPOSE) down

airflow-logs: ## Follow scheduler logs for the hourly membership pipeline.
	$(AIRFLOW_COMPOSE) logs -f airflow-scheduler
