"""
===============================================================================
ETL Script: Load Bronze Layer (GitHub -> Postgres)
===============================================================================
Purpose:
    Simulates a real-world pipeline pattern: fetch raw CSVs from a remote
    source (here, GitHub), validate basic shape, then load into the bronze
    schema using psycopg2's fast COPY protocol.

    This decouples "fetch" from "load" -- if the fetch fails (network issue,
    404, rate limit), the load step never runs, and vice versa. Each stage
    can be logged, retried, or replaced independently (e.g. swap GitHub for
    an S3 bucket or an API later without touching the load logic).

Usage:
    python load_bronze_from_github.py
===============================================================================
"""

import io
import time
import requests
import psycopg2

# ------------------------------------------------------------------
# CONFIG - in a real pipeline these would come from env vars / a secrets
# manager (e.g. os.environ["DB_PASSWORD"]), never hardcoded like this.
# ------------------------------------------------------------------
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "retail_analytics_case_study",
    "user": "postgres",
    "password": "your_password_here",
}

# Map: table name -> (source URL, ordered column list matching the CSV header)
SOURCES = {
    "bronze.customer_profiles": {
        "url": "https://github.com/Sohom-01/sql-retail-analytics/blob/main/customer_profiles.csv",
        "columns": ["customer_id", "age", "gender", "location", "join_date"],
    },
    "bronze.product_inventory": {
        "url": "https://github.com/Sohom-01/sql-retail-analytics/blob/main/product_inventory.csv",
        "columns": ["product_id", "product_name", "category", "stock_level", "price"],
    },
    "bronze.sales_transaction": {
        "url": "https://github.com/Sohom-01/sql-retail-analytics/blob/main/sales_transaction.csv",
        "columns": ["transaction_id", "customer_id", "product_id",
                     "quantity_purchased", "transaction_date", "price"],
    },
}


def fetch_csv(url: str) -> io.StringIO:
    """Download a CSV from a URL and return it as an in-memory file-like object.

    Using an in-memory buffer (instead of writing to disk first) avoids
    leaving temp files around and works the same whether you're fetching
    from GitHub, S3, or any other HTTP source.
    """
    response = requests.get(url, timeout=30)
    response.raise_for_status()  # raises if the URL 404s, times out, etc.
    return io.StringIO(response.text)


def load_table(conn, table: str, csv_buffer: io.StringIO, columns: list[str]):
    """Truncate the bronze table and bulk-load the fetched CSV using COPY.

    psycopg2's copy_expert uses the same server-side COPY protocol as the
    SQL command, but streams data over the existing DB connection instead
    of requiring a file path on the server's disk -- this is what lets us
    load data that only ever existed in memory, fetched from the internet.
    """
    col_list = ", ".join(columns)
    with conn.cursor() as cur:
        cur.execute(f"TRUNCATE TABLE {table};")
        cur.copy_expert(
            f"COPY {table}({col_list}) FROM STDIN WITH (FORMAT csv, HEADER true, DELIMITER ',')",
            csv_buffer,
        )
    conn.commit()


def main():
    print("=" * 50)
    print("LOADING BRONZE LAYER (source: GitHub)")
    print("=" * 50)

    conn = psycopg2.connect(**DB_CONFIG)
    batch_start = time.time()

    try:
        for table, meta in SOURCES.items():
            start = time.time()
            print(f"\n>> FETCHING: {meta['url']}")
            csv_buffer = fetch_csv(meta["url"])

            print(f">> TRUNCATING: {table}")
            print(f">> LOADING INTO: {table}")
            load_table(conn, table, csv_buffer, meta["columns"])

            print(f">> Load Duration: {time.time() - start:.2f} seconds")

        print("\n" + "=" * 50)
        print("BRONZE LAYER LOAD COMPLETE")
        print(f">> Total Duration: {time.time() - batch_start:.2f} seconds")
        print("=" * 50)

    except requests.exceptions.RequestException as e:
        print(f"\nERROR fetching data: {e}")
        conn.rollback()
    except psycopg2.Error as e:
        print(f"\nERROR loading data: {e}")
        conn.rollback()
    finally:
        conn.close()


if __name__ == "__main__":
    main()
