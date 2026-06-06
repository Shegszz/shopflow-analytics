# ShopFlow Analytics Pipeline

> End-to-end automated e-commerce analytics pipeline - from raw data generation to a self-updating Power BI dashboard. Zero manual steps.

---

## What This Does

Every day at 06:00 UTC, this pipeline automatically:

1. **Generates & ingests** new e-commerce transaction data into BigQuery
2. **Transforms** raw tables into clean, analysis-ready models using dbt
3. **Tests** data quality across every layer of the pipeline
4. **Updates** the Power BI dashboard with fresh insights — no human intervention

Business teams wake up to a dashboard that already reflects yesterday's performance.

---

## Architecture

```
REST API / Data Generator
        │
        ▼
  Python (Pandas)          ← Ingestion layer
        │
        ▼
  BigQuery (Raw Layer)     ← shopflow_raw dataset
        │
        ▼
  dbt (Transform Layer)    ← Staging → Marts
        │
        ├── mart_daily_revenue
        ├── mart_product_performance
        ├── mart_customer_segments (RFM)
        └── mart_regional_performance
        │
        ▼
  Power BI Dashboard       ← Direct BigQuery connector
        │
        ▼
  GitHub Actions           ← Orchestrates everything, daily at 06:00 UTC
```

---

## Dashboard Views

| Page | Key Metrics |
|---|---|
| Revenue Overview | Daily revenue, 7-day rolling avg, MTD, day-over-day change |
| Product Performance | Revenue by category, gross margin %, top products |
| Customer Segments | RFM segmentation, Champions vs At Risk vs Lost |
| Regional Analysis | Revenue by US state, avg order value by geography |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Data Generation & Ingestion | Python (Pandas, Faker, google-cloud-bigquery) |
| Data Warehouse | Google BigQuery |
| Transformation & Testing | dbt (dbt-bigquery) |
| Orchestration | GitHub Actions (cron schedule) |
| Visualisation | Power BI (DirectQuery → BigQuery) |

---

## Setup Guide

### Prerequisites
- Python 3.11+
- Google Cloud account (free tier works)
- Power BI Desktop (free)
- GitHub account

### Step 1 - Google Cloud Setup
1. Create a new project at [console.cloud.google.com](https://console.cloud.google.com)
2. Enable the **BigQuery API**
3. Create a **Service Account** → download the JSON key
4. Grant the service account `BigQuery Admin` role

### Step 2 - Local Setup
```bash
git clone https://github.com/YOUR_USERNAME/shopflow-analytics.git
cd shopflow-analytics

pip install -r requirements.txt

cp .env.template .env
# Edit .env → add your GCP_PROJECT_ID
```

### Step 3 - Run the Initial Historical Load
```bash
python ingestion/generate_and_load.py --mode full
```
This generates 2 years of e-commerce history and loads it into BigQuery.

### Step 4 - Configure dbt
```bash
cp dbt_project/profiles.yml.template ~/.dbt/profiles.yml
# Edit profiles.yml → add your GCP_PROJECT_ID and keyfile path

cd dbt_project
dbt deps
dbt run
dbt test
```

### Step 5 - GitHub Actions Automation
1. Push code to GitHub
2. Go to **Settings → Secrets and Variables → Actions**
3. Add two secrets:
   - `GCP_PROJECT_ID` → your project ID string
   - `GCP_SERVICE_ACCOUNT_KEY` → paste the entire JSON key file content
4. The pipeline will now run automatically every day at 06:00 UTC

### Step 6 - Connect Power BI
1. Open Power BI Desktop
2. **Get Data → Google BigQuery**
3. Sign in with your Google account
4. Navigate to your project → `shopflow_marts` dataset
5. Load the four mart tables
6. Build your dashboard

---

## Data Quality

dbt runs automated tests on every layer:
- **Uniqueness** - no duplicate IDs
- **Not-null** - required fields always present
- **Accepted values** - status fields match expected enums
- **Range checks** - no negative revenues or impossible margins

If any test fails, the GitHub Actions pipeline fails loudly and no bad data reaches the dashboard.

---

## Project Structure

```
shopflow-analytics/
├── ingestion/
│   └── generate_and_load.py     # Data generation + BigQuery loader
├── dbt_project/
│   ├── models/
│   │   ├── staging/             # Clean + type raw tables
│   │   │   ├── stg_orders.sql
│   │   │   ├── stg_customers.sql
│   │   │   ├── stg_products.sql
│   │   │   └── stg_order_items.sql
│   │   ├── marts/               # Business intelligence tables
│   │   │   ├── mart_daily_revenue.sql
│   │   │   ├── mart_product_performance.sql
│   │   │   ├── mart_customer_segments.sql
│   │   │   └── mart_regional_performance.sql
│   │   └── schema.yml           # Source definitions + tests
│   └── dbt_project.yml
├── .github/workflows/
│   └── pipeline.yml             # Daily automation
├── requirements.txt
└── README.md
```

---

## Author

**Segun Bakare** - Analytics Engineer
[Portfolio](https://shegszz.github.io) · [LinkedIn](https://linkedin.com/in/segun-bakare-d) · [GitHub](https://github.com/Shegszz)
