"""
ShopFlow Analytics Pipeline
============================
Generates realistic e-commerce data and loads it into BigQuery.

On first run: generates 2 years of historical data.
On daily runs: generates only today's orders (simulating live e-commerce).

Usage:
    python ingestion/generate_and_load.py --mode full   # First run
    python ingestion/generate_and_load.py --mode daily  # Daily GitHub Actions run
"""

import os
import argparse
import random
from datetime import datetime, timedelta, date

import pandas as pd
from faker import Faker
from google.cloud import bigquery
from dotenv import load_dotenv

load_dotenv()

fake = Faker("en_US")
random.seed(42)

# ── CONFIG ────────────────────────────────────────────────────────────────────
PROJECT_ID  = os.getenv("GCP_PROJECT_ID")
DATASET_ID  = "shopflow_raw"
LOCATION    = "US"

CATEGORIES = {
    "Electronics":    {"subcategories": ["Phones", "Laptops", "Accessories"], "margin": 0.25},
    "Clothing":       {"subcategories": ["Men", "Women", "Kids"],             "margin": 0.55},
    "Home & Garden":  {"subcategories": ["Furniture", "Decor", "Tools"],      "margin": 0.45},
    "Sports":         {"subcategories": ["Fitness", "Outdoor", "Team Sports"],"margin": 0.40},
    "Books":          {"subcategories": ["Fiction", "Non-Fiction", "Kids"],   "margin": 0.30},
    "Beauty":         {"subcategories": ["Skincare", "Makeup", "Haircare"],   "margin": 0.60},
    "Food & Grocery": {"subcategories": ["Snacks", "Beverages", "Organic"],   "margin": 0.20},
    "Toys":           {"subcategories": ["Educational", "Outdoor", "Games"],  "margin": 0.50},
}

US_STATES = [
    "California", "Texas", "Florida", "New York", "Illinois",
    "Pennsylvania", "Ohio", "Georgia", "North Carolina", "Michigan",
    "New Jersey", "Virginia", "Washington", "Arizona", "Massachusetts",
]

PAYMENT_METHODS  = ["Credit Card", "Debit Card", "PayPal", "Apple Pay", "Google Pay"]
ORDER_STATUSES   = ["completed", "completed", "completed", "returned", "cancelled"]
CUSTOMER_SEGS    = ["Regular", "Regular", "Premium", "VIP", "New"]


# ── GENERATORS ───────────────────────────────────────────────────────────────

def generate_customers(n: int = 2000) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        signup = fake.date_between(start_date="-2y", end_date="today")
        rows.append({
            "customer_id":       f"CUST-{i:05d}",
            "first_name":        fake.first_name(),
            "last_name":         fake.last_name(),
            "email":             fake.email(),
            "city":              fake.city(),
            "state":             random.choice(US_STATES),
            "signup_date":       signup.isoformat(),
            "customer_segment":  random.choice(CUSTOMER_SEGS),
            "created_at":        datetime.utcnow().isoformat(),
        })
    return pd.DataFrame(rows)


def generate_products(n: int = 120) -> pd.DataFrame:
    rows = []
    pid  = 1
    per_cat = n // len(CATEGORIES)
    for category, meta in CATEGORIES.items():
        for _ in range(per_cat):
            cost    = round(random.uniform(5, 300), 2)
            margin  = meta["margin"]
            selling = round(cost / (1 - margin), 2)
            rows.append({
                "product_id":     f"PROD-{pid:04d}",
                "product_name":   fake.catch_phrase(),
                "category":       category,
                "subcategory":    random.choice(meta["subcategories"]),
                "cost_price":     cost,
                "selling_price":  selling,
                "stock_quantity": random.randint(10, 500),
                "created_at":     datetime.utcnow().isoformat(),
            })
            pid += 1
    return pd.DataFrame(rows)


def generate_orders(
    customers: pd.DataFrame,
    products: pd.DataFrame,
    start_date: date,
    end_date: date,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Returns (orders_df, order_items_df)."""
    customer_ids = customers["customer_id"].tolist()
    product_ids  = products["product_id"].tolist()

    orders      = []
    order_items = []
    order_id    = 1
    item_id     = 1

    current = start_date
    while current <= end_date:
        # Weekends get more orders; simulate seasonality
        base_orders = random.randint(30, 80)
        if current.weekday() >= 5:          # Sat/Sun
            base_orders = int(base_orders * 1.4)
        if current.month in (11, 12):       # Holiday season boost
            base_orders = int(base_orders * 1.6)

        for _ in range(base_orders):
            oid        = f"ORD-{order_id:07d}"
            cid        = random.choice(customer_ids)
            status     = random.choice(ORDER_STATUSES)
            ship_days  = random.randint(1, 7) if status != "cancelled" else 0
            order_ts   = datetime.combine(current, datetime.min.time()) + timedelta(
                hours=random.randint(0, 23), minutes=random.randint(0, 59)
            )

            # 1-5 items per order
            n_items    = random.randint(1, 5)
            item_pids  = random.choices(product_ids, k=n_items)
            order_total = 0.0

            for pid in item_pids:
                prod      = products[products["product_id"] == pid].iloc[0]
                qty       = random.randint(1, 4)
                unit_price= float(prod["selling_price"])
                discount  = random.choice([0, 0, 0, 5, 10, 15, 20])
                line_total = round(unit_price * qty * (1 - discount / 100), 2)
                order_total += line_total

                order_items.append({
                    "order_item_id":   f"ITEM-{item_id:08d}",
                    "order_id":        oid,
                    "product_id":      pid,
                    "quantity":        qty,
                    "unit_price":      unit_price,
                    "discount_pct":    discount,
                    "line_total":      line_total,
                })
                item_id += 1

            orders.append({
                "order_id":        oid,
                "customer_id":     cid,
                "order_date":      order_ts.date().isoformat(),
                "order_timestamp": order_ts.isoformat(),
                "order_status":    status,
                "payment_method":  random.choice(PAYMENT_METHODS),
                "shipping_days":   ship_days,
                "order_total":     round(order_total, 2),
            })
            order_id += 1

        current += timedelta(days=1)

    return pd.DataFrame(orders), pd.DataFrame(order_items)


# ── BIGQUERY HELPERS ──────────────────────────────────────────────────────────

def get_client() -> bigquery.Client:
    return bigquery.Client(project=PROJECT_ID)


def ensure_dataset(client: bigquery.Client) -> None:
    ds = bigquery.Dataset(f"{PROJECT_ID}.{DATASET_ID}")
    ds.location = LOCATION
    client.create_dataset(ds, exists_ok=True)
    print(f"✓ Dataset `{DATASET_ID}` ready")


def load_table(
    client: bigquery.Client,
    df: pd.DataFrame,
    table_name: str,
    mode: str = "WRITE_TRUNCATE",
) -> None:
    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"
    job_config = bigquery.LoadJobConfig(
        write_disposition=mode,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()
    print(f"✓ Loaded {len(df):,} rows → `{table_name}`")


# ── MAIN ──────────────────────────────────────────────────────────────────────

def run_full_load() -> None:
    """Generate 2 years of history and load everything."""
    print("\n── FULL HISTORICAL LOAD ──────────────────────────")
    client    = get_client()
    ensure_dataset(client)

    customers = generate_customers(n=2000)
    products  = generate_products(n=120)

    end_date   = date.today()
    start_date = end_date - timedelta(days=730)   # 2 years back
    orders, items = generate_orders(customers, products, start_date, end_date)

    print(f"\nGenerated:")
    print(f"  Customers  : {len(customers):,}")
    print(f"  Products   : {len(products):,}")
    print(f"  Orders     : {len(orders):,}")
    print(f"  Order Items: {len(items):,}\n")

    load_table(client, customers, "raw_customers",   "WRITE_TRUNCATE")
    load_table(client, products,  "raw_products",    "WRITE_TRUNCATE")
    load_table(client, orders,    "raw_orders",      "WRITE_TRUNCATE")
    load_table(client, items,     "raw_order_items", "WRITE_TRUNCATE")

    print("\n✅ Full historical load complete.")


def run_daily_load() -> None:
    """Generate only today's orders and APPEND them."""
    print("\n── DAILY INCREMENTAL LOAD ────────────────────────")
    client   = get_client()
    today    = date.today()

    # Pull existing customer/product IDs from BigQuery
    customers = client.query(
        f"SELECT customer_id FROM `{PROJECT_ID}.{DATASET_ID}.raw_customers`"
    ).to_dataframe()
    products = client.query(
        f"SELECT product_id, selling_price FROM `{PROJECT_ID}.{DATASET_ID}.raw_products`"
    ).to_dataframe()

    orders, items = generate_orders(customers, products, today, today)

    print(f"Generated for {today}: {len(orders)} orders, {len(items)} items")

    load_table(client, orders, "raw_orders",      "WRITE_APPEND")
    load_table(client, items,  "raw_order_items", "WRITE_APPEND")

    print("\n✅ Daily incremental load complete.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ShopFlow data pipeline")
    parser.add_argument(
        "--mode",
        choices=["full", "daily"],
        default="daily",
        help="full = 2yr history load | daily = today's orders only",
    )
    args = parser.parse_args()

    if args.mode == "full":
        run_full_load()
    else:
        run_daily_load()
