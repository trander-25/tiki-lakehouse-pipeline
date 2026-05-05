#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# 1. Load environment variables from .env (bash-safe)
if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

# 2. Ensure AIRFLOW_HOME exists
: "${AIRFLOW_HOME:=$ROOT_DIR/airflow_home}"
mkdir -p "$AIRFLOW_HOME"

# 2.1 Ensure DAGS_FOLDER is set and exists
: "${AIRFLOW__CORE__DAGS_FOLDER:=$ROOT_DIR/dags}"
mkdir -p "$AIRFLOW__CORE__DAGS_FOLDER"
export AIRFLOW__CORE__DAGS_FOLDER

# 3. Ensure DB path is valid (avoid falling back to /airflow.db)
: "${AIRFLOW__DATABASE__SQL_ALCHEMY_CONN:=sqlite:///${AIRFLOW_HOME}/airflow.db}"

run_airflow() {
  if command -v uv >/dev/null 2>&1; then
    AIRFLOW__CORE__DAGS_FOLDER="$AIRFLOW__CORE__DAGS_FOLDER" uv run airflow "$@"
  else
    AIRFLOW__CORE__DAGS_FOLDER="$AIRFLOW__CORE__DAGS_FOLDER" airflow "$@"
  fi
}

# 4. Initialize DB (explicit) then run standalone
run_airflow db migrate
run_airflow standalone