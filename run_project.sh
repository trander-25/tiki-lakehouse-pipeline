#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting Tiki Lakehouse Project..."

# 1. Check for .env file
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Copying from .env.example..."
    cp .env.example .env
fi

# 2. Start Infrastructure
echo "🐳 Starting Docker containers..."
make run

# 3. Wait for services to be ready
echo "⏳ Waiting for services to initialize (30s)..."
# We wait a bit to ensure MinIO and Postgres are up before crawling
sleep 30

# 4. Setup environment if .venv doesn't exist
if [ ! -d .venv ]; then
    echo "📦 Setting up Python environment..."
    make setup
fi

# 5. Run Crawler
echo "🕷️  Running Tiki Crawler..."
make crawl

# 5.5 Setup Raw Table Schema in Trino
echo "🗃️  Setting up raw table schema in Trino..."
uv run python src/setup_raw_table.py

# 6. Run dbt transformations
echo "🔨 Running dbt transformations..."
make dbt-run

# 7. Generate local analytics report
echo "📈 Generating local analytics report..."
make analytics

echo "✅ Project is up and running!"
echo "------------------------------------------------"
echo "🔗 MinIO Console: http://localhost:9001 (admin / minio_password)"
echo "🔗 Superset: http://localhost:8088 (admin / admin_password)"
echo "------------------------------------------------"