from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator


DAG_FILE = Path(__file__).resolve()
_search_root = DAG_FILE.parent
_default_project_root = next(
    (candidate for candidate in (_search_root, *_search_root.parents) if (candidate / "pyproject.toml").exists()),
    _search_root.parent,
)
PROJECT_ROOT = Path(os.getenv("TIKI_LAKEHOUSE_PROJECT_ROOT", str(_default_project_root)))

# Ensure local imports (crawler/, src/) work when this DAG is parsed.
sys.path.insert(0, str(PROJECT_ROOT))

from src.airflow_dbt import discover_model_names, make_dbt_task_group

# Keep Airflow configuration consistent when running locally.
os.environ.setdefault("AIRFLOW_HOME", str(PROJECT_ROOT / "airflow_home"))

DBT_PROJECT_DIR = PROJECT_ROOT / "dbt_tiki"
DBT_PROFILES_YML = DBT_PROJECT_DIR / "profiles.yml"
# Staging models dùng DuckDB syntax (READ_PARQUET, STRPTIME...) nên luôn chạy với
# target 'dev'. Chỉ marts mới cần Trino để ghi Iceberg native vào JDBC Catalog.
DBT_TARGET_STAGING = "dev"  # DuckDB: đọc raw Parquet từ MinIO
DBT_TARGET_MARTS = "dev"  # DuckDB: xuất Parquet ra MinIO
DBT_EXECUTABLE_PATH = os.getenv(
    "DBT_EXECUTABLE_PATH",
    str(Path(sys.executable).with_name("dbt")),
)

# Library compatibility notes (validated against the pinned local environment):
# - apache-airflow==2.11.1
# - astronomer-cosmos==1.14.1
# - dbt-core==1.11.x
# This DAG uses Cosmos' DbtTaskGroup + RenderConfig API that matches Cosmos 1.14.x.

DEFAULT_ARGS = {
    "owner": "tiki_admin",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}


with DAG(
    dag_id="tiki_lakehouse_daily_pipeline",
    default_args=DEFAULT_ARGS,
    description="Daily pipeline: crawl raw data, run dbt (stg -> dim -> fct), then generate analytics",
    schedule="0 0 * * *",
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=["tiki", "lakehouse"],
) as dag:

    # Task 1: Run the crawler.
    # Use `uv run` so Airflow executes within the project's virtual environment.
    task_crawl = BashOperator(
        task_id="crawl_tiki_data",
        bash_command=f"cd '{PROJECT_ROOT}' && uv run python crawler/fetch_tiki.py",
    )

    dbt_stg = make_dbt_task_group(
        group_id="dbt_staging",
        select=["path:models/staging"],
        dbt_project_dir=DBT_PROJECT_DIR,
        profiles_yml=DBT_PROFILES_YML,
        target=DBT_TARGET_STAGING,  # DuckDB: READ_PARQUET syntax
        dbt_executable_path=DBT_EXECUTABLE_PATH,
    )
    marts_dir = DBT_PROJECT_DIR / "models" / "marts"
    dim_models = discover_model_names(marts_dir, prefix="dim_")
    fct_models = discover_model_names(marts_dir, prefix="fct_")

    dbt_dim = make_dbt_task_group(
        group_id="dbt_dimensions",
        select=dim_models,
        dbt_project_dir=DBT_PROJECT_DIR,
        profiles_yml=DBT_PROFILES_YML,
        target=DBT_TARGET_MARTS,  # Trino: ghi Iceberg native
        dbt_executable_path=DBT_EXECUTABLE_PATH,
    )

    dbt_fct = make_dbt_task_group(
        group_id="dbt_facts",
        select=fct_models,
        dbt_project_dir=DBT_PROJECT_DIR,
        profiles_yml=DBT_PROFILES_YML,
        target=DBT_TARGET_MARTS,  # Trino: ghi Iceberg native
        dbt_executable_path=DBT_EXECUTABLE_PATH,
    )

    # Task 5: Generate analytics charts after marts are built.
    # The callable is imported from `src/` to keep this DAG file declarative.
    from src.airflow_tasks import run_analytics_report

    task_analytics = PythonOperator(
        task_id="generate_analytics_report",
        python_callable=run_analytics_report,
    )

    # Enforce the required execution order: stg -> dim -> fct.
    task_crawl >> dbt_stg >> dbt_dim >> dbt_fct >> task_analytics
