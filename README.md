# GA4 Digital Marketing Funnel Analysis

**Where is the funnel leaking, and which channels actually drive revenue?**
End-to-end analysis of 3 months of real GA4 ecommerce data (Google Merchandise Store) — from BigQuery extraction to an interactive Power BI dashboard and an A/B test recommendation.

![SQL](https://img.shields.io/badge/SQL-BigQuery-4285F4?style=flat&logo=google-cloud&logoColor=white)
![Python](https://img.shields.io/badge/Python-pandas-3776AB?style=flat&logo=python&logoColor=white)
![PowerBI](https://img.shields.io/badge/Power%20BI-DAX-F2C811?style=flat&logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/Status-Completed-2A9D8F?style=flat)

---

## 🖥️ Dashboard Preview

<!-- Replace the line below with your screenshot once exported.
     In GitHub: drag a PNG into the repo (e.g. /assets/dashboard.png) then reference it here. -->
![Power BI Dashboard](assets/dashboard.png)

> *3-page Power BI dashboard built directly on raw CSVs with DAX — funnel, channel quality, and product seasonality.*

---

## 🎯 Headline Insights

- **Only 0.7% of sessions convert** — the funnel loses 83% of users at the very first step (Session Start → View Item).
- **Referral traffic is the hidden winner:** **$21.90 revenue/session — 14x better than Google Paid** ($1.54), which generated just $40 in 3 months.
- **8x traffic growth, but revenue/session fell 66%** — more visitors did *not* mean more money. A quality problem, not a volume problem.
- **Returning users convert 2x higher** and drive 2.7x more revenue/session — yet 81% of traffic is first-timers. Retention is underinvested.
- **47% of revenue rides on Apparel**, which fell 60% post-holiday — a concentrated seasonal risk.

---

## 🧰 What This Demonstrates

**SQL (BigQuery)** — CTEs, window functions (`LAG`, `FIRST_VALUE`, `RANK`, `PARTITION BY`), multi-table joins, conditional aggregation
**Python (pandas)** — channel-label engineering and a reproducible CSV pipeline from raw event data
**Power BI / DAX** — `CALCULATE`+`FILTER`, `ADDCOLUMNS`, `DISTINCTCOUNT`, calculated columns, 3-page storytelling layout
**Analytics judgment** — funnel diagnosis, channel attribution, cohort segmentation, and honest data-limitation documentation

---

## 🔧 Pipeline

```
BigQuery (extract) → Python (clean & merge) → BigQuery SQL (analysis) → Power BI (dashboard) → Presentation + A/B brief
```

**Data:** `bigquery-public-data.ga4_obfuscated_sample_ecommerce` · Nov 2020 – Jan 2021 (92 days)
**Outputs:** `master_events.csv` (52,939 rows), `items_clean.csv` (16,003 rows), 10 SQL files, `.pbix` dashboard, 12-slide deck

> **Note:** GA4 `session_start` events carry no channel data, so attribution is rebuilt from `begin_checkout` and `purchase` events. This (and other limitations) are documented in [the full project notes](#-more-detail).

---

## 📂 More Detail

- **SQL queries:** [`/sql`](sql/) — 10 files, from funnel drop-off to product-channel joins
- **Data prep:** [`data_preparation.py`](data_preparation.py)
- **Dashboard:** [`ga4 dashboard.pbix`](ga4%20dashboard.pbix) · [PDF export](ga4%20dashboard.pdf)
- **Presentation:** [`GA4_Funnel_Analysis.pptx`](GA4_Funnel_Analysis.pptx)

---

**Rupsa Chaudhuri** · [LinkedIn](https://www.linkedin.com/in/rupsa-chaudhuri/) · [GitHub](https://github.com/rupsa723)
