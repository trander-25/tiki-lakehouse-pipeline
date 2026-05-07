# Tiki Lakehouse Pipeline

A local data engineering project that demonstrates an end-to-end lakehouse workflow for crawling product data from Tiki, storing it in MinIO, transforming it with dbt and DuckDB, orchestrating jobs with Airflow, and serving analytics through Trino and Superset.

This repository uses `uv` for Python dependency management and Docker Compose for the supporting services.

## Project Overview

The project follows a Medallion-style data flow:

- **Bronze**: raw product data is collected by the crawler and uploaded to MinIO.
- **Silver**: dbt staging models clean, type, and standardize the raw data.
- **Gold**: dbt marts build dimensional and fact tables for analytics and reporting.

The goal is to provide a practical, reproducible local data platform that is easy to run, inspect, and extend.

## Architecture

Add your architecture image here.

Suggested file:

```text
assets/architecture.png
```

Suggested flow:

- Tiki source data -> crawler -> MinIO raw bucket
- Airflow -> dbt staging -> dbt marts
- Trino -> Superset for serving and visualization
- Postgres -> metastore and Superset backend

## Tech Stack

| Component | Purpose |
| --- | --- |
| Python 3.10+ | Runtime for crawler, Airflow helpers, and analytics scripts |
| uv | Python package and environment manager |
| Apache Airflow 2.11.1 | Pipeline orchestration |
| Astronomer Cosmos 1.14.1 | dbt integration inside Airflow |
| dbt-core 1.11.8 | Transformation framework |
| dbt-duckdb 1.10.1 | DuckDB adapter for dbt |
| DuckDB 1.5.2 | Local analytical engine |
| MinIO | S3-compatible object storage |
| Postgres 15 | Metadata store and Superset backend |
| Trino | Query layer |
| Apache Superset | Dashboard and BI layer |
| OpenLineage 1.46.0 | Lineage support |

## Repository Structure

```text
tiki-lakehouse-pipeline/
├── crawler/                  # Tiki ingestion scripts
├── dags/                     # Airflow DAGs
├── dbt_tiki/                 # dbt project
├── src/                      # Shared Python helpers
├── trino/                    # Trino config and catalogs
├── airflow_home/             # Local Airflow state
├── docker-compose.yaml       # Local services
├── Makefile                  # Common developer commands
├── run_airflow.sh            # Airflow launcher
├── run_project.sh            # End-to-end convenience script
├── pyproject.toml            # Python project metadata
└── uv.lock                   # Locked dependency graph
```

## Key Project Files

- `crawler/fetch_tiki.py`: collects raw product data from Tiki.
- `dags/tiki_lakehouse_pipeline.py`: Airflow DAG for crawl -> dbt -> analytics.
- `src/airflow_dbt.py`: reusable Cosmos helpers for dbt task groups.
- `src/airflow_tasks.py`: lightweight task wrappers to keep DAG parsing clean.
- `dbt_tiki/models/staging/`: staging models for the Silver layer.
- `dbt_tiki/models/marts/`: dimension and fact models for the Gold layer.

## Prerequisites

- Linux or macOS
- Python 3.10 or newer
- Docker and Docker Compose
- `uv` installed on the host machine

Recommended system resources:

- 8 GB RAM or more
- At least 5 GB free disk space
- Free ports: 8081, 8082, 8088, 9000, 9001, 5432

## Local Setup

### 1. Prepare environment files

```bash
cp .env.example .env
```

Edit `.env` if you want to change credentials, ports, or local paths.

### 2. Create the Python environment

```bash
uv venv
uv sync
```

### 3. Start the local services

```bash
docker compose up -d
```

Wait for MinIO, Postgres, Trino, and Superset to finish starting.

### 4. Start Airflow

```bash
./run_airflow.sh
```

The script creates the required Airflow directories, initializes the metadata database, and launches Airflow in standalone mode.

## Execution Steps

### Option 1: Run the full flow manually

```bash
make crawl
make dbt-run
make airflow
```

### Option 2: Use the one-command helper

```bash
./run_project.sh
```

This helper starts the Docker stack, prepares the Python environment if needed, runs the crawler, and executes dbt.

### Option 3: Run each stage separately

```bash
make crawl
make dbt-run
make dbt-test
make dbt-docs
make airflow
```

## Data Flow

1. The crawler fetches product information from Tiki and writes raw outputs to MinIO.
2. Airflow orchestrates the daily workflow.
3. dbt staging models clean the raw data and prepare it for modeling.
4. dbt marts build dimension and fact tables for analytics.
5. Trino queries the curated data, and Superset uses Trino to power dashboards.

## Monitoring and Access

| Service | URL | Notes |
| --- | --- | --- |
| Airflow | http://localhost:8081 | Local standalone UI |
| MinIO Console | http://localhost:9001 | Object storage browser |
| MinIO API | http://localhost:9000 | S3-compatible endpoint |
| Trino | http://localhost:8082 | Query engine endpoint |
| Superset | http://localhost:8088 | BI and dashboard layer |

Default local credentials are defined in `.env.example` and can be changed in `.env`.

## Airflow Orchestration

The main DAG is `tiki_lakehouse_daily_pipeline`.

Typical task flow:

- `crawl_tiki_data`
- `dbt_staging`
- `dbt_dimensions`
- `dbt_facts`
- `analytics`

## Makefile Reference

| Command | Description |
| --- | --- |
| `make help` | Show available commands |
| `make setup` | Create the virtual environment and install dependencies |
| `make run` | Start the Docker services |
| `make stop` | Stop the Docker services |
| `make crawl` | Run the crawler |
| `make dbt-run` | Run dbt transformations |
| `make dbt-test` | Run dbt tests |
| `make dbt-docs` | Generate and serve dbt documentation |
| `make lint` | Run code and SQL lint checks |
| `make format` | Format Python and SQL files |
| `make test` | Run Python tests |
| `make airflow` | Start Airflow standalone |
| `make clean` | Remove local caches and generated files |

## Image Placeholders

Add the images you want to use in these spots:

- Architecture diagram
- Airflow DAG view
- MinIO bucket view
- Superset dashboard
- Analytics chart output

Suggested folder:

```text
assets/
```

Suggested filenames:

```text
assets/architecture.png
assets/airflow-dag.png
assets/minio-bucket.png
assets/superset-dashboard.png
assets/analytics-chart.png
```

## Notes

- Use `uv sync` after changing dependencies in `pyproject.toml`.
- Use `docker compose down` to stop the local stack when you are done.
- The project is intended for local development and demonstration.

---

Last updated: May 2026
