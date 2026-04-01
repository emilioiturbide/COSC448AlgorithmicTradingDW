"""
ORM-integrated DW loader.

This script:
- Ensures DW schema and ORM tables exist (uses `create_tables.py` logic)
- Executes the server-side `fill_dw_from_agg.sql` to populate dims and fact

Usage: set `DATABASE_URL` env var if needed and run:
    python run_dw_load.py
"""
import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

from sqlalchemy import text
from datetime import datetime, date
from dateutil.relativedelta import relativedelta
from database import engine
from models import Base, SCHEMA


def ensure_schema_and_tables():
    # create schema if not sqlite
    try:
        if engine.dialect.name != "sqlite":
            with engine.connect() as conn:
                conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}"))
                conn.commit()
    except Exception:
        pass

    Base.metadata.create_all(engine)

def create_historical_partitions(start_date, end_date):
    # Create monthly partitions for fact_daily_stock_price for the previous 10 years
    current = start_date
    with engine.begin() as conn:
        while current <= end_date:
            suffix = current.strftime("%Y%m")
            partition_name = f"fact_stock_{suffix}"

            start_val = int(current.strftime("%Y%m01000000"))
            next_month = current + relativedelta(months=1)
            end_val = int(next_month.strftime("%Y%m01000000"))

            sql = f"""
                    CREATE TABLE IF NOT EXISTS {SCHEMA}.{partition_name}
                    PARTITION OF {SCHEMA}.fact_15min_stock_price
                    FOR VALUES FROM ({start_val}) TO ({end_val});
            """
            conn.execute(text(sql))
            current = next_month
        
        # Create default partition for future dates
        default_partition_sql = f"""
            CREATE TABLE IF NOT EXISTS {SCHEMA}.fact_stock_default
            PARTITION OF {SCHEMA}.fact_15min_stock_price DEFAULT;
        """
        conn.execute(text(default_partition_sql))


def run_fill_sql():
    sql_path = Path(__file__).parents[2] / 'data_transformation' / 'fill_dw_from_agg.sql'
    if not sql_path.exists():
        raise SystemExit(f'fill SQL not found: {sql_path}')

    sql_text = sql_path.read_text(encoding='utf-8')
    with engine.begin() as conn:
        conn.execute(text(sql_text))


def main():
    ensure_schema_and_tables()
    print('Schemas and tables ensured.')
    print('Creating partitions...')
    create_historical_partitions(date(2019, 1, 1), date(2026, 12, 1))
    print('Partitions created.')
    print('Running DW load SQL...')
    run_fill_sql()
    print('DW load completed.')


if __name__ == '__main__':
    main()
