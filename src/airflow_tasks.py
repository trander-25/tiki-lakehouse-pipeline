"""Thin wrappers for Airflow tasks.

Keep these callables lightweight at import time so DAG parsing doesn't fail
when optional runtime dependencies aren't installed in the scheduler environment.
"""

from __future__ import annotations


def run_analytics_report() -> None:
    """Generate and save the latest analytics charts.

    Notes:
        - Imports are intentionally inside the function to avoid importing
          heavy plotting dependencies (duckdb/matplotlib/seaborn) during DAG parsing.
    """

    from src.analytics_plot import main as analytics_main

    analytics_main()
