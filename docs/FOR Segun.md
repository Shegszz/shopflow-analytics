# FOR Segun — ShopFlow Analytics Pipeline

*Everything you need to understand this project: what it does, how it works, why we built it this way, and what to say when someone asks you about it in an interview.*

---

## The Big Picture — What Are We Actually Building?

Imagine you own an online shop. Every day, customers are placing orders, buying products, abandoning carts, coming back, never coming back. All of that generates data — thousands of rows of it, every single day.

Now imagine your boss asks: *"How did we do yesterday? Which products are killing it? Which customers are about to leave us?"*

Without this pipeline, you'd open Excel, download a CSV from somewhere, clean it up manually, plug the numbers into a dashboard, and send a report. Then do it all again tomorrow. And the day after. Forever.

**This pipeline kills that entire workflow.** You build it once, automate it, and every morning the dashboard already has last night's numbers — clean, tested, and ready. Nobody touched anything. It just happened.

That's the magic. That's what you're selling when you talk about this project.

---

## The Architecture — A Railway Metaphor

Think of this pipeline as a railway system.

**The raw data is cargo** — it starts messy, unformatted, inconsistent. Like goods arriving at a port from multiple ships.

**BigQuery raw layer is the port warehouse** — everything gets stored here first, as-is. We don't touch it yet.

**dbt staging models are the sorting facility** — workers (SQL transformations) unpack the cargo, clean it, standardise it, throw away anything broken.

**dbt mart models are the retail distribution centres** — the clean goods are now packaged into specific products: daily revenue reports, customer segments, product rankings. Business-ready.

**Power BI is the shop floor** — where business users actually see the product. They don't know or care about the railway. They just see fresh, accurate information.

**GitHub Actions is the train conductor** — it makes sure the whole railway runs on schedule, every day at 6am, whether you're awake or not.

---

## The Stack — Why Each Tool Was Chosen

### Python + Pandas + Faker
Python is the workhorse. It generates realistic synthetic e-commerce data (using Faker — a library that creates fake-but-believable names, emails, cities, amounts) and loads it into BigQuery.

Why synthetic data? Because real e-commerce companies don't give you their transaction data for a portfolio project. Synthetic data lets you build a pipeline that looks and behaves exactly like a production system without needing access to private data. **This is what real engineers do when building proof-of-concept systems.**

### Google BigQuery
BigQuery is Google's cloud data warehouse. It stores massive amounts of structured data and lets you query it with SQL — except it runs at a scale that would crush a regular database.

We chose it because:
1. **It has a free tier** — you can run this entire project for free as long as you stay under 10GB of data processed per month
2. **dbt supports it natively** — they were made for each other
3. **Power BI connects to it directly** — no extra steps
4. **It's what real Analytics Engineers use** — Moniepoint, Flutterwave, any serious data company is on BigQuery, Snowflake, or Redshift. Putting BigQuery on your CV is putting the right word in the right place.

### dbt (data build tool)
This is the most important new tool in this project. Let me explain it properly.

Before dbt, Analytics Engineers wrote transformation SQL directly in BigQuery or Snowflake. The problem? No version control, no testing, no documentation, no way to understand what depends on what. It was chaos.

dbt changed that. Now you write your SQL transformations as `.sql` files, put them in a Git repository (version controlled, like your FPL project), and dbt handles the rest — running them in the right order, testing the results, generating documentation.

Think of it this way: **dbt does for SQL what Git did for code.** It made SQL a serious engineering discipline.

The two main concepts to understand:

**Staging models** — these are like a first wash. You take the raw dirty data and clean it up: fix typos, cast columns to the right types, add simple derived columns. You don't do complex business logic here. Just clean.

**Mart models** — this is where the business intelligence lives. You combine the clean staging tables and build the actual metrics: daily revenue with rolling averages, RFM customer segments, category performance. This is what the dashboard reads from.

Why this separation matters: if the raw data format changes tomorrow (say, the date column is now called `created_date` instead of `order_date`), you only change one staging model. All your mart models downstream are untouched. **Isolation is how engineers stay sane.**

### GitHub Actions
You already know this from your FPL project. Same concept here. A YAML file tells GitHub to run your pipeline on a schedule. The difference in this project is that the pipeline is more complex — it runs Python ingestion THEN dbt THEN dbt tests. If any step fails, the whole pipeline fails and you'd get notified.

This is called **orchestration** — making sure tasks happen in the right order, automatically. In big companies, they use tools like Airflow or Prefect for this. GitHub Actions is the lightweight, free version — and for a portfolio project, it's perfect.

### Power BI
The dashboard. Connects directly to BigQuery via the built-in connector. You point it at the mart tables, drag and drop visuals, and you're done.

The key thing to understand: Power BI is reading from BigQuery mart tables, not from raw data. This means the dashboard is always reading **pre-aggregated, tested, clean data.** It's fast. It's accurate. It never shows inconsistent numbers because dbt tests would have caught the inconsistency before it got here.

---

## The Data Model — Four Marts

Here's what we built and why each one matters:

### 1. mart_daily_revenue
The core revenue table. One row per day. Contains:
- Total orders and unique customers that day
- Gross revenue (only completed orders — returned and cancelled orders don't count as revenue)
- 7-day rolling average (smooths out daily noise — a Monday spike doesn't make Tuesday look terrible)
- Month-to-date cumulative revenue (CFO's favourite number)
- Day-over-day percentage change

**Why the rolling average matters:** Raw daily revenue looks like a heartbeat monitor — up, down, up, down. Nobody can make decisions from that. The 7-day rolling average shows the actual trend underneath the noise. This is a real data skill that separates analysts who understand statistics from those who just make charts.

### 2. mart_product_performance
Revenue and margin breakdown by category and subcategory, by month. Answers:
- Which categories make the most money?
- Which categories have the best margins? (Not always the same answer)
- Where are discounts being used, and are they hurting margins?

**The margin vs revenue distinction** is one of the most important things in retail analytics. Electronics might generate huge revenue but thin margins. Beauty products might have modest revenue but 60% margins. A naive analyst looks at revenue and says "push electronics." A smart analyst looks at gross profit and says "push beauty." This model shows both.

### 3. mart_customer_segments (RFM)
RFM stands for Recency, Frequency, Monetary — the classic customer segmentation framework used by every serious e-commerce business since the 1990s.

The idea: not all customers are equal. Some buy all the time and spend a lot (Champions). Some used to buy but haven't in months (At Risk). Some bought once and disappeared (Lost). Each segment needs a completely different marketing response.

How the scoring works: we give each customer a score from 1-5 on each dimension using `ntile(5)` — a SQL window function that divides everyone into equal fifths. Then we combine the scores to assign a segment label.

**Why this impresses interviewers:** RFM is taught in business school. When you drop this in conversation — "I built an RFM segmentation model using window functions in dbt" — you're speaking the language of people who've been doing analytics for 20 years.

### 4. mart_regional_performance
Revenue broken down by US state and month. Powers a map visual in the dashboard. Simple but important — geographic performance gaps are often the first thing a VP of Sales asks about.

---

## The Testing Layer — Why It Matters More Than You Think

Every model has tests defined in `schema.yml`. These run automatically as part of the pipeline.

Here's why this is a big deal: **a dashboard that shows wrong numbers is worse than no dashboard.** Wrong numbers get trusted, decisions get made on them, money gets lost, someone gets fired.

Data tests are how engineers protect themselves and their business from that outcome.

The tests in this project:
- **Unique + not_null on IDs** — if an order_id appears twice, something went very wrong in the ingestion
- **Accepted values** — order status can only be "completed", "returned", or "cancelled". If we see "Completed" (capital C) or "complete" or "done", something's wrong with the source data
- **Range checks** — revenue can't be negative. Margin can't be over 100%. If it is, the model has a bug

When you run `dbt test` and all 20+ tests pass, you know the data is clean. When one fails, you fix it before it reaches the dashboard.

**In interviews, say this:** "I built data quality tests into the pipeline so that if the upstream data ever changes format or has errors, the pipeline fails loudly rather than silently serving bad data to the dashboard." That sentence alone separates you from 90% of candidates.

---

## Bugs You'll Hit and How to Fix Them

### Bug 1: BigQuery Authentication Fails
**Symptom:** `google.auth.exceptions.DefaultCredentialsError`
**Cause:** Python can't find your service account credentials
**Fix:** Make sure your `.env` file has the right project ID AND your service account JSON key is in the right path. Better yet, run `gcloud auth application-default login` in your terminal — this sets up credentials automatically for local development.

### Bug 2: dbt Can't Find the Source Tables
**Symptom:** `Compilation Error: Relation 'shopflow_raw.raw_orders' not found`
**Cause:** The Python ingestion hasn't run yet, so the tables don't exist in BigQuery
**Fix:** Always run the Python ingestion script FIRST before running dbt. The order is: Python → dbt. Every time.

### Bug 3: dbt Test Failures on `accepted_values`
**Symptom:** dbt test fails saying "order_status" has unexpected values
**Cause:** The Faker library or your generation script produced a status string that doesn't match the expected list
**Fix:** Check `schema.yml` — your accepted values list needs to match exactly what the ingestion script produces. Case-sensitive. Trim whitespace.

### Bug 4: Power BI Can't Connect to BigQuery
**Symptom:** Authentication error in Power BI
**Cause:** You're trying to use the service account JSON in Power BI, but Power BI uses OAuth — it wants your personal Google account
**Fix:** In Power BI, use "Sign in with Google" using the same Google account that owns the GCP project. Power BI will authenticate via OAuth and get access to BigQuery automatically.

### Bug 5: GitHub Actions Fails at dbt Step
**Symptom:** Pipeline runs Python fine, then crashes at `dbt run`
**Cause:** The `profiles.yml` in the GitHub Actions workflow has a typo or the secret isn't formatted correctly
**Fix:** The `GCP_SERVICE_ACCOUNT_KEY` secret should be the entire JSON file content — copy-paste the whole thing. Also make sure there are no line breaks or quote issues in the profiles.yml configuration in the workflow file.

---

## How to Talk About This Project in an Interview

The interviewers at Vega-type companies will ask you to walk them through a project. Here's the script:

**Opening (10 seconds):**
"I built a fully automated e-commerce analytics pipeline. It ingests data, transforms it through a dbt model layer in BigQuery, and serves a self-updating Power BI dashboard — all on a daily GitHub Actions schedule."

**When they ask how it works (the walk-through):**
"The ingestion layer is a Python script that generates realistic transaction data and loads it into BigQuery's raw layer. dbt then runs two layers of transformations — staging models that clean and type the raw data, and mart models that build the actual business metrics: daily revenue with rolling averages, product margin analysis, RFM customer segmentation, and regional breakdown. Each layer has automated data quality tests. The whole thing runs on a GitHub Actions cron job every morning."

**When they ask why dbt:**
"dbt brings software engineering discipline to SQL — version control, modular transforms, automated testing, and documentation. Without it, your transformation logic lives in a database somewhere, nobody knows what depends on what, and changes break things silently. dbt makes the transformation layer as auditable as your application code."

**When they ask about the testing:**
"I defined uniqueness, not-null, accepted-values, and range tests on every model. If any test fails in the pipeline, the whole run fails and the dashboard doesn't get updated — which protects the business from making decisions on bad data."

**The money line:**
"The business team gets fresh insights every morning without anyone manually running anything. I built it once and it runs itself."

---

## What This Project Adds to Your Profile

- **dbt** → you can now honestly put this on your CV and defend it
- **BigQuery** → cloud data warehouse experience, the #1 gap you had
- **RFM segmentation** → serious analytics credential that resonates with business stakeholders
- **Data quality testing** → shows engineering discipline, not just analysis
- **e-commerce domain** → relevant to most of the companies you're targeting (Moniepoint, Flutterwave, Field Intelligence all touch transactional data)

This, combined with the FPL project, means you now have two completely different domains (sports analytics + e-commerce) both demonstrating the same core architecture (Python → pipeline → automated dashboard). That's no longer a coincidence — that's a pattern. That's an Analytics Engineer's portfolio.

---

## The Lesson That Applies Everywhere

The single most important thing this project teaches you:

**Engineers separate concerns.**

Raw data lives in the raw layer. Clean data lives in staging. Business logic lives in marts. The dashboard touches only marts.

If you break that rule — if you put business logic in staging, or if your dashboard queries raw tables — you create a system that's impossible to maintain, impossible to test, and impossible to trust.

Every time something breaks (and it will), you'll know exactly which layer to look at. That's not luck. That's architecture.

The FPL project taught you to automate. This project teaches you to *structure* your automation. Both skills together is what makes you an Analytics Engineer, not just someone who wrote a cool script.

---

*Built by Segun Bakare — Analytics Engineer | shegszz.github.io*
