"""dbt/Cosmos helpers for Airflow DAGs.

The goal is to keep DAG files declarative and avoid repeating Cosmos boilerplate.
"""

from __future__ import annotations

from pathlib import Path

from cosmos.airflow.task_group import DbtTaskGroup
from cosmos.config import ExecutionConfig, ProfileConfig, ProjectConfig, RenderConfig
from cosmos.constants import TestBehavior


def discover_model_names(models_dir: Path, prefix: str) -> list[str]:
    """Return dbt model names based on filenames.

    Example:
        - `dim_products.sql` -> model name `dim_products`

    Notes:
        - dbt selection in v1.11 does not support wildcards like `dim_*`, so we
          pass an explicit list of model names to Cosmos.
    """

    return sorted(path.stem for path in models_dir.glob(f"{prefix}*.sql"))


def make_dbt_task_group(
    *,
    group_id: str,
    select: list[str],
    dbt_project_dir: Path,
    profiles_yml: Path,
    target: str,
    dbt_executable_path: str,
) -> DbtTaskGroup:
    """Create a Cosmos dbt TaskGroup for a given model selection."""

    project_config = ProjectConfig(
        dbt_project_path=dbt_project_dir,
        # Avoid network calls during DAG parsing/execution.
        # This project already vendors packages under `dbt_packages/`.
        install_dbt_deps=False,
        copy_dbt_packages=True,
    )

    profile_config = ProfileConfig(
        profile_name="dbt_tiki",
        target_name=target,
        profiles_yml_filepath=profiles_yml,
    )

    execution_config = ExecutionConfig(dbt_executable_path=dbt_executable_path)

    render_config = RenderConfig(
        select=select,
        # We only need model runs for this pipeline; tests can be executed separately.
        test_behavior=TestBehavior.NONE,
    )

    return DbtTaskGroup(
        group_id=group_id,
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=render_config,
    )
