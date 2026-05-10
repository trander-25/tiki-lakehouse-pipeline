#!/usr/bin/env bash

################################################################################
# Tiki Lakehouse Pipeline - Airflow Launcher
#
# Purpose: Initialize Airflow environment, validate prerequisites, run standalone
# Usage: ./run_airflow.sh
#
# Features:
#   - Strict error handling (set -euo pipefail)
#   - Environment validation
#   - Automatic directory creation
#   - Idempotent operations
#   - Clear error messages
################################################################################

set -euo pipefail

# ===== Configuration =====
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$ROOT_DIR"

# Logging
LOG_FILE="${PROJECT_ROOT}/logs/airflow_launcher.log"
DEBUG="${DEBUG:-0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ===== Helper Functions =====

log_info() {
    local msg="$1"
    echo -e "${GREEN}[INFO]${NC} ${msg}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] ${msg}" >> "${LOG_FILE}"
}

log_warn() {
    local msg="$1"
    echo -e "${YELLOW}[WARN]${NC} ${msg}" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] ${msg}" >> "${LOG_FILE}"
}

log_error() {
    local msg="$1"
    echo -e "${RED}[ERROR]${NC} ${msg}" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] ${msg}" >> "${LOG_FILE}"
}

# Ensure log directory exists
ensure_log_dir() {
    mkdir -p "$(dirname "${LOG_FILE}")"
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check Python
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python 3 is not installed"
        exit 1
    fi
    local py_version=$(python3 --version 2>&1 | awk '{print $2}')
    log_info "Python version: ${py_version}"
    
    # Check uv (optional but recommended)
    if ! command -v uv >/dev/null 2>&1; then
        log_warn "uv not found. Falling back to system Python"
    else
        local uv_version=$(uv --version 2>&1)
        log_info "uv version: ${uv_version}"
    fi
    
    # Check .env file exists
    if [[ ! -f "${PROJECT_ROOT}/.env" ]]; then
        log_warn ".env file not found. Using defaults"
        if [[ -f "${PROJECT_ROOT}/.env.example" ]]; then
            log_info "Creating .env from .env.example"
            cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
        fi
    fi
}

# Load environment variables from .env safely
load_env() {
    log_info "Loading environment configuration..."
    
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        # Use set -a/+a to source .env without affecting current shell
        set -a
        # shellcheck disable=SC1091
        source "${PROJECT_ROOT}/.env"
        set +a
        log_info "Environment loaded from .env"
    fi
}

# Setup Airflow directories
setup_directories() {
    log_info "Setting up Airflow directories..."
    
    # Ensure AIRFLOW_HOME is set
    : "${AIRFLOW_HOME:=${PROJECT_ROOT}/airflow_home}"
    export AIRFLOW_HOME
    
    # Create necessary directories
    mkdir -p "${AIRFLOW_HOME}"
    mkdir -p "${AIRFLOW_HOME}/logs"
    mkdir -p "${AIRFLOW_HOME}/plugins"
    mkdir -p "${PROJECT_ROOT}/logs"
    
    # Ensure DAGS_FOLDER points to the project dags directory
    : "${AIRFLOW__CORE__DAGS_FOLDER:=${PROJECT_ROOT}/dags}"
    export AIRFLOW__CORE__DAGS_FOLDER
    
    log_info "AIRFLOW_HOME: ${AIRFLOW_HOME}"
    log_info "DAGS_FOLDER: ${AIRFLOW__CORE__DAGS_FOLDER}"
}

# Configure Airflow environment
setup_airflow_config() {
    log_info "Configuring Airflow environment..."
    
    # Database connection (default: SQLite in AIRFLOW_HOME)
    : "${AIRFLOW__DATABASE__SQL_ALCHEMY_CONN:=sqlite:///${AIRFLOW_HOME}/airflow.db}"
    export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
    
    # IMPORTANT: Pin to Airflow 2 XCom backend
    # Prevents override from shell environment with Airflow 3 path
    : "${AIRFLOW__CORE__XCOM_BACKEND:=airflow.models.xcom.BaseXCom}"
    export AIRFLOW__CORE__XCOM_BACKEND
    
    # Load examples disabled to avoid clutter
    : "${AIRFLOW__CORE__LOAD_EXAMPLES:=False}"
    export AIRFLOW__CORE__LOAD_EXAMPLES
    
    # Sequential executor for local development
    : "${AIRFLOW__CORE__EXECUTOR:=SequentialExecutor}"
    export AIRFLOW__CORE__EXECUTOR
    
    # Webserver port
    : "${AIRFLOW__WEBSERVER__WEB_SERVER_PORT:=8081}"
    export AIRFLOW__WEBSERVER__WEB_SERVER_PORT
    
    # Disable authentication for local standalone
    : "${AIRFLOW__WEBSERVER__EXPOSE_CONFIG:=True}"
    export AIRFLOW__WEBSERVER__EXPOSE_CONFIG
    
    log_info "Airflow configuration ready"
    log_info "  - Database: ${AIRFLOW__DATABASE__SQL_ALCHEMY_CONN}"
    log_info "  - XCom Backend: ${AIRFLOW__CORE__XCOM_BACKEND}"
    log_info "  - Executor: ${AIRFLOW__CORE__EXECUTOR}"
    log_info "  - Webserver Port: ${AIRFLOW__WEBSERVER__WEB_SERVER_PORT}"
}

# Wrapper for running Airflow commands
run_airflow() {
    if command -v uv >/dev/null 2>&1; then
        # Use uv if available (ensures reproducible environment)
        uv run airflow "$@"
    else
        # Fallback to system airflow
        airflow "$@"
    fi
}

# Initialize Airflow database
initialize_database() {
    log_info "Initializing Airflow database..."
    
    # Run database migration
    if ! run_airflow db migrate 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Database migration failed"
        exit 1
    fi
    
    log_info "Database initialized successfully"
}

# Main execution
main() {
    ensure_log_dir
    log_info "=========================================="
    log_info "Tiki Lakehouse Pipeline - Airflow Launcher"
    log_info "=========================================="
    log_info "Start time: $(date)"
    log_info "Project root: ${PROJECT_ROOT}"
    
    # Validation and setup
    validate_prerequisites
    load_env
    setup_directories
    setup_airflow_config
    
    # Initialize database
    initialize_database
    
    # Start Airflow standalone
    log_info "Starting Airflow standalone server..."
    log_info "Web UI: http://localhost:${AIRFLOW__WEBSERVER__WEB_SERVER_PORT}"
    log_info "Press Ctrl+C to stop"
    log_info "=========================================="
    echo ""
    
    # Run Airflow standalone
    run_airflow standalone
}

# Trap signals for graceful shutdown
trap 'log_info "Received interrupt signal. Shutting down..."; exit 0' SIGINT SIGTERM

# Execute main function
main "$@"