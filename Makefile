.PHONY: help setup setup-hooks venv install run stop clean crawl dbt-run dbt-test dbt-docs lint format test airflow clean-all

# Default target: show help
help:
	@echo "Tiki Lakehouse Pipeline - Make Commands"
	@echo "========================================"
	@echo ""
	@echo "Setup & Environment:"
	@echo "  make setup           - Initialize venv, install deps, and setup pre-commit"
	@echo "  make setup-hooks     - Install pre-commit hooks"
	@echo "  make venv            - Create Python virtual environment"
	@echo "  make install         - Install dependencies from uv.lock"
	@echo ""
	@echo "Infrastructure:"
	@echo "  make run             - Start Docker containers (infrastructure stack)"
	@echo "  make stop            - Stop Docker containers gracefully"
	@echo "  make clean-docker    - Remove Docker containers and volumes (WARNING: data loss)"
	@echo ""
	@echo "Data Pipeline:"
	@echo "  make crawl           - Run Tiki data crawler (ingestion)"
	@echo "  make dbt-run         - Execute dbt transformations (staging → marts)"
	@echo "  make dbt-test        - Run dbt tests and validations"
	@echo "  make dbt-docs        - Generate and serve dbt documentation"
	@echo "  make analytics       - Generate analytics reports"
	@echo ""
	@echo "Development:"
	@echo "  make lint            - Check code quality (black, flake8, sqlfluff)"
	@echo "  make format          - Auto-format code with black"
	@echo "  make test            - Run pytest unit tests"
	@echo ""
	@echo "Airflow Orchestration:"
	@echo "  make airflow         - Start Airflow standalone server"
	@echo "  make airflow-reset   - Reset Airflow state (WARNING: lose DAG history)"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean           - Remove venv, logs, cache, build artifacts"
	@echo "  make clean-all       - Full reset: remove venv, Docker, logs, artifacts"
	@echo ""

# Setup: Initialize venv, install deps, and pre-commit hooks
setup: venv install setup-hooks
	@echo "✓ Setup complete. Ready to develop!"

# Create Python virtual environment using uv
venv:
	@echo "Creating Python virtual environment..."
	uv venv
	@echo "✓ Virtual environment created"

# Install dependencies from uv.lock
install:
	@echo "Installing dependencies from uv.lock..."
	uv sync
	@echo "✓ Dependencies installed"

# Install and configure pre-commit hooks
setup-hooks:
	@echo "Setting up pre-commit hooks..."
	uv run pre-commit install || pip install pre-commit && pre-commit install
	@echo "✓ Pre-commit hooks installed"

# Start Docker infrastructure stack
run: docker-check
	@echo "Starting Docker services..."
	docker compose up -d
	@echo "✓ Docker services started"
	@echo ""
	@echo "Service endpoints:"
	@echo "  - MinIO Console:  http://localhost:9001 (admin / password)"
	@echo "  - Trino UI:       http://localhost:8082 (admin)"
	@echo "  - Superset:       http://localhost:8088 (admin / password)"
	@echo "  - Postgres:       localhost:5432"
	@echo ""
	@echo "Waiting for services to initialize... (30 seconds)"
	@sleep 30
	@echo "✓ All services ready!"

# Stop Docker services gracefully
stop:
	@echo "Stopping Docker services..."
	docker compose stop
	@echo "✓ Docker services stopped"

# Check if Docker is installed
docker-check:
	@command -v docker >/dev/null 2>&1 || (echo "ERROR: Docker is not installed"; exit 1)
	@command -v docker-compose >/dev/null 2>&1 || (echo "ERROR: Docker Compose is not installed"; exit 1)

# Run the Tiki crawler (data ingestion)
crawl:
	@echo "Running Tiki crawler..."
	uv run python crawler/fetch_tiki.py
	@echo "✓ Crawler completed"

# Run dbt transformations (all models)
dbt-run:
	@echo "Running dbt transformations..."
	cd dbt_tiki && uv run dbt run
	@echo "✓ dbt transformations completed"

# Run dbt tests
dbt-test:
	@echo "Running dbt tests and validations..."
	cd dbt_tiki && uv run dbt test
	@echo "✓ dbt tests completed"

# Generate and serve dbt documentation
dbt-docs:
	@echo "Generating dbt documentation..."
	cd dbt_tiki && uv run dbt docs generate
	@echo "✓ dbt documentation generated"
	@echo ""
	@echo "Serving dbt docs on http://localhost:8000"
	@echo "Press Ctrl+C to stop"
	cd dbt_tiki && uv run dbt docs serve

# Generate analytics reports
analytics:
	@echo "Generating analytics reports..."
	uv run python src/analytics_plot.py
	@echo "✓ Analytics reports generated"

# Code formatting (black)
format:
	@echo "Formatting Python code..."
	uv run black crawler/ src/ dags/
	cd dbt_tiki && uv run sqlfluff format models
	@echo "✓ Code formatted"

# Lint and check code quality
lint:
	@echo "Linting Python code..."
	uv run black --check crawler/ src/ dags/ || true
	uv run flake8 crawler/ src/ dags/ || true
	@echo ""
	@echo "Linting SQL code..."
	cd dbt_tiki && uv run sqlfluff lint models || true
	@echo "✓ Linting completed"

# Run pytest tests
test:
	@echo "Running pytest unit tests..."
	uv run pytest crawler/tests/ -v
	@echo "✓ Tests completed"

# Start Airflow standalone server
airflow:
	@echo "Starting Airflow standalone server..."
	@echo ""
	./run_airflow.sh

# Reset Airflow state (careful: loses DAG history)
airflow-reset:
	@echo "WARNING: This will reset Airflow state and lose all DAG history"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		rm -rf airflow_home/logs airflow_home/*.db; \
		echo "✓ Airflow state reset"; \
	fi

# Clean: Remove venv, logs, cache, and artifacts
clean:
	@echo "Cleaning up local artifacts..."
	rm -rf .venv
	rm -rf airflow_home/logs
	rm -rf dbt_tiki/target
	rm -rf .pytest_cache
	rm -rf *.egg-info
	rm -rf __pycache__
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	@echo "✓ Cleanup completed"

# Full clean: Remove Docker, venv, and all generated files (WARNING: data loss)
clean-all: clean clean-docker
	@echo "✓ Full cleanup completed"

# Remove Docker containers and volumes
clean-docker:
	@echo "WARNING: This will remove Docker containers and volumes (data loss)"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		echo "✓ Docker cleanup completed"; \
	fi

.PHONY: help