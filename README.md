
# Tiki Lakehouse Pipeline

A small, end-to-end lakehouse demo project:

- **Ingestion**: crawl product data from Tiki and land it in **MinIO (S3-compatible)**
- **Orchestration**: run pipelines in **Apache Airflow** (local standalone)
- **Transformations**: model data with **dbt** (DuckDB + S3/MinIO)
- **Query**: explore data via **Trino** (Iceberg catalog)
- **BI**: visualize with **Apache Superset**

This repository is designed for local development on Linux/macOS.

## Architecture

Data flow (typical):

1. `crawler/` fetches raw JSON → writes Parquet → uploads to MinIO bucket `raw-data`
2. `dbt_tiki/` builds staging + marts models, outputting marts to `s3://lakehouse/dbt_marts/`
3. Trino reads from the lakehouse catalogs; Superset connects to Trino for dashboards

## Repository layout

- `docker-compose.yaml`: MinIO + Postgres + Trino + Superset
- `run_airflow.sh`: local Airflow (standalone) runner
- `dags/`: Airflow DAGs (example: `0_test_symlink_dag`)
- `crawler/`: Tiki crawler (uploads to MinIO)
- `dbt_tiki/`: dbt project (DuckDB + MinIO S3)
- `trino/`: Trino config and catalogs
- `airflow_home/`: local Airflow state (created at runtime)

## Prerequisites

- Python **>= 3.10** (see `pyproject.toml`)
- Docker + Docker Compose
- Recommended: `uv`

## Configuration

Copy the example env file and adjust values if needed:

```bash
cp .env.example .env
```

Notes:

- Docker services use `.env` for credentials.
- The crawler can also read values from `.env` (via `python-dotenv`).
- Trino catalog configs are mounted from `trino/etc/catalog/*.properties` and currently contain **hard-coded** credentials/endpoints. If you change MinIO/Postgres credentials in `.env`, update those catalog files to match.

## Run the lakehouse stack (Docker Compose)

Start services:

```bash
docker compose up -d
```

Stop services:

```bash
docker compose down
```

Reset everything (including volumes):

```bash
docker compose down -v
```

### Service endpoints

- MinIO API: http://localhost:9000
- MinIO Console: http://localhost:9001
- Postgres: `localhost:5432`
- Trino: http://localhost:8080
- Superset: http://localhost:8088

Superset admin credentials come from `.env` (`SUPERSET_ADMIN_USER`, `SUPERSET_ADMIN_PASSWORD`).

## Local development (Python)

### 1) Create environment + install dependencies

Using `uv`:

```bash
uv venv
source .venv/bin/activate
uv pip install -e .
```

If you don't use `uv`, a normal virtualenv also works.

### 2) Run the crawler (land raw data to MinIO)

Make sure Docker services are running (at least MinIO):

```bash
docker compose up -d minio minio-init
```

Then run the crawler:

```bash
python crawler/fetch_tiki.py
```

Output:

- A local preview CSV is written to `preview_data/`
- A Parquet file is uploaded to MinIO bucket `raw-data` under `tiki_products/`

Optional crawler env vars (set in `.env`):

- `TIKI_COOKIE`, `TIKI_GUEST_TOKEN`, `TIKI_PROXY`

### 3) Run dbt transforms

The dbt project lives in `dbt_tiki/`.

```bash
cd dbt_tiki
dbt debug
dbt build
```

By default:

- DuckDB file is `dbt_tiki/tiki.duckdb`
- `dbt_project.yml` sets marts to materialize to `s3://lakehouse/dbt_marts/` as Parquet
- Individual models can override output location (example: `models/marts/fct_tiki_book.sql` currently writes to `s3://raw-data/marts/...`)

Important:

- `dbt_tiki/profiles.yml` currently contains local MinIO credentials and endpoint (`localhost:9000`).
- If you changed MinIO credentials in `.env`, update `profiles.yml` accordingly.

## Airflow (local standalone)

Start Airflow:

```bash
bash run_airflow.sh
```

Airflow uses:

- `AIRFLOW_HOME`: `./airflow_home` (or the value from `.env`)
- Metadata DB: `airflow_home/airflow.db`
- Web UI: http://localhost:8081

Admin password:

- Airflow standalone stores generated credentials in `airflow_home/simple_auth_manager_passwords.json.generated`.

### Example DAG

The example DAG `0_test_symlink_dag` is located in `dags/test_af.py` and can be triggered manually from the UI.

## Troubleshooting

- If Superset fails to start on first run, try: `docker compose restart superset`
- If ports are busy, stop conflicting processes or change exposed ports in `docker-compose.yaml`

## License

Internal / educational use (add a license if you plan to publish).

