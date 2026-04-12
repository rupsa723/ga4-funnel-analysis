# GA4 Digital Marketing Funnel Analysis
### Google Merchandise Store — BigQuery Public Dataset

![SQL](https://img.shields.io/badge/SQL-BigQuery-4285F4?style=flat&logo=google-cloud&logoColor=white)
![Python](https://img.shields.io/badge/Python-pandas-3776AB?style=flat&logo=python&logoColor=white)
![PowerBI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?style=flat&logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/Status-Completed-2A9D8F?style=flat)

---

## 📌 Business Problem

> **"Which marketing channels drive the most revenue, and where is the funnel leaking?"**

This project analyses 3 months of real GA4 ecommerce event data from the Google Merchandise Store (Nov 2020 – Jan 2021) to identify funnel drop-off points, evaluate channel performance, and produce data-driven recommendations to improve checkout conversion rate.

---

## 🗂️ Project Pipeline

```
BigQuery (extract) → Python (merge & clean) → BigQuery SQL (analysis) → Power BI (dashboard) → Presentation
```

| Stage | Tool | Output |
|---|---|---|
| 1. Data Extraction | Google BigQuery Sandbox | 3 CSVs (dataset.csv, sessions.csv, items.csv) |
| 2. Data Preparation | Python (pandas) | master_events.csv (52,939 rows), items_clean.csv (16,003 rows) |
| 3. SQL Analysis | Google BigQuery | 10 SQL query files covering all KPIs |
| 4. Dashboard | Power BI | 3-page interactive dashboard |
| 5. Presentation | PowerPoint | 12-slide deck with A/B test brief |

---

## 📊 Dataset

- **Source:** `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
- **Period:** November 1, 2020 – January 31, 2021 (92 days)
- **Store:** Google Merchandise Store (shop.googlemerchandisestore.com)
- **Access:** Google BigQuery Sandbox (free, no billing required)

| File | Description | Rows |
|---|---|---|
| `master_events.csv` | All funnel events with channel, device, geo, revenue | 52,939 |
| `items_clean.csv` | Product-level purchase data with categories | 16,003 |

> ⚠️ Raw data files are not uploaded to this repo due to size. See `data_preparation.py` to recreate them from BigQuery.

---

## 🔍 Key Findings

### 1. Funnel Drop-off
| Stage | Sessions | Drop-off % | CVR from Top |
|---|---|---|---|
| Session Start | 27,901 | — | 100% |
| View Item | 4,691 | 83.2% | 16.8% |
| Add to Cart | 811 | 82.7% | 2.9% |
| Begin Checkout | 486 | 40.1% | 1.7% |
| Payment Info | 298 | 38.7% | 1.1% |
| Purchase | 198 | 33.6% | **0.7%** |

**Overall CVR: 0.7%** — only 7 in every 1,000 sessions result in a purchase.

---

### 2. Channel Attribution
| Channel | Sessions | Purchases | Revenue | Rev/Session | CVR% |
|---|---|---|---|---|---|
| Self-Referral | 1,222 | 113 | $5,380 | $4.40 | 9.2% |
| Google Organic | 306 | 30 | $1,002 | $3.27 | 9.8% |
| **Referral** | 98 | 9 | $2,146 | **$21.90** | 9.2% |
| Direct | 148 | 11 | $425 | $2.87 | 7.4% |
| **Google Paid** | 26 | 3 | **$40** | **$1.54** | 11.5% |

- **Referral** is the hidden gem — $21.90 revenue per session, 14x better than Google Paid
- **Google Paid** severely underperforms — only $40 total revenue across 3 months
- **Google Organic** is the strongest real marketing channel at 9.8% CVR

---

### 3. Traffic Quality Declining
| Month | Sessions | CVR% | Rev/Session |
|---|---|---|---|
| Nov 2020 | 2,188 | 0.96% | $0.68 |
| Dec 2020 | 8,325 | 0.76% | $0.64 |
| Jan 2021 | 17,505 | 0.65% | $0.23 |

Traffic grew 8x but revenue per session dropped 66%. **Growing sessions ≠ growing revenue.**

---

### 4. Bounce Rate — 82.29%
| Device | Sessions | Bounced | Bounce Rate |
|---|---|---|---|
| Desktop | 16,388 | 13,581 | 82.87% |
| Mobile | 11,113 | 9,187 | 82.67% |
| Tablet | 698 | 576 | 82.52% |

Bounce rate is virtually identical across all devices — this is a **traffic quality issue**, not a mobile UX problem.

> **Note on bounce rate calculation:** Bounce rate is calculated as sessions where `COUNT(event_name) = 1` divided by `COUNT(DISTINCT session_id)`. An earlier version of this analysis used `COUNT(session_id)` (row count) instead of distinct sessions, producing an incorrect 43.55%. The correct figure is **82.29%**.

---

### 5. New vs Returning Users
| User Type | Sessions | CVR% | Rev/Session | Revenue |
|---|---|---|---|---|
| New | 22,730 | 0.59% | $0.29 | $6,546 |
| Returning | 5,418 | 1.18% | $0.79 | $4,258 |

Returning users are **2x more likely to purchase** and generate **2.7x more revenue per session**. Yet 81% of traffic is first-time visitors — retention is severely underinvested.

---

### 6. Apparel Revenue Concentration
- Apparel = **47% of total revenue** ($171,727 out of $362,110 item revenue)
- All top 10 products are Apparel items
- Apparel revenue fell 60% Nov → Jan ($75,070 → $29,695) — post-holiday demand collapse
- Business risk: over-reliance on one seasonal category

---

## 🗃️ SQL Files

| File | Analysis |
|---|---|
| [`01_funnel_analysis.sql`](sql/01_funnel_analysis.sql) | Overall funnel drop-off — 6 stages, drop-off % and CVR from top |
| [`02_channel_attribution.sql`](sql/02_channel_attribution.sql) | Revenue, purchases, CVR, revenue per session by channel |
| [`03_bounce_rate.sql`](sql/03_bounce_rate.sql) | Bounce rate overall (82.29%), by device and by country |
| [`04_bounce_rate_by_channel.sql`](sql/04_bounce_rate_by_channel.sql) | Attempted channel bounce rate — documented as unreliable data limitation |
| [`05_monthly_trend.sql`](sql/05_monthly_trend.sql) | Month-over-month sessions, revenue, CVR trend |
| [`06_funnel_by_channel.sql`](sql/06_funnel_by_channel.sql) | Funnel drop-off broken down by marketing channel |
| [`07_revenue_by_device.sql`](sql/07_revenue_by_device.sql) | Revenue, CVR and revenue per session by device |
| [`08_new_vs_returning.sql`](sql/08_new_vs_returning.sql) | New vs returning user behaviour comparison |
| [`09_product_analysis.sql`](sql/09_product_analysis.sql) | Top products, categories, monthly trends, channel-product join |
| [`10_landing_page_analysis.sql`](sql/10_landing_page_analysis.sql) | Top visited pages and top entry pages |

---

## 📊 Power BI Dashboard

Three-page dashboard built directly on `master_events.csv` and `items_clean.csv` using DAX measures.

| Page | Title | Focus |
|---|---|---|
| Page 1 | Where Are We Losing Customers? | Funnel drop-off, channel quality, monthly trend |
| Page 2 | Are We Attracting The Right People? | New vs returning, bounce rate, entry pages |
| Page 3 | What Are They Buying? | Category revenue, top products, seasonal trends |

**DAX highlights:** `CALCULATE` with `FILTER`, `ADDCOLUMNS` for bounce rate, `DISTINCTCOUNT` for session-level metrics, `user_type` calculated column for new vs returning segmentation, `DIVIDE` for safe CVR calculation, `FORMAT` for locale-independent currency display.

---

## 🐍 Data Preparation

`data_preparation.py` performs the following steps:

1. Loads `dataset.csv`, `sessions.csv`, `items.csv` downloaded from BigQuery
2. Builds session-level channel mapping from `begin_checkout` and `purchase` events
   (because `session_start` events carry no channel data in this dataset)
3. Assigns clean channel labels: `Self-Referral`, `Google Organic`, `Google Paid`,
   `Direct`, `Referral`, `Obfuscated`, `Unknown`
4. Exports `master_events.csv` (52,939 rows) and `items_clean.csv` (16,003 rows)

---

## ⚠️ Data Limitations

| Limitation | Impact | Resolution |
|---|---|---|
| `session_start` carries no channel data | Bounce rate by channel unreliable | Documented; CVR used as proxy |
| `first_visit` event not downloaded | New vs returning is approximated | Session count per user used as proxy |
| No ad spend data in GA4 exports | ROAS cannot be calculated | Revenue per session used as proxy |
| 3 homepage URLs not consolidated | Inflated homepage visit counts | Noted in landing page analysis |
| Obfuscated dataset | Some fields show `(data deleted)` | Excluded from channel analysis |

---

## 📁 Repository Structure

```
ga4-funnel-analysis/
│
├── README.md
├── data_preparation.py
├── ga4 dashboard.pbix
├── ga4 dashboard.pdf
├── GA4_Funnel_Analysis.pptx
└── sql/
    ├── 01_funnel_analysis.sql
    ├── 02_channel_attribution.sql
    ├── 03_bounce_rate.sql
    ├── 04_bounce_rate_by_channel.sql
    ├── 05_monthly_trend.sql
    ├── 06_funnel_by_channel.sql
    ├── 07_revenue_by_device.sql
    ├── 08_new_vs_returning.sql
    ├── 09_product_analysis.sql
    └── 10_landing_page_analysis.sql
```

---

## 🛠️ Tools & Skills Demonstrated

- **BigQuery SQL** — CTEs, window functions (`LAG`, `FIRST_VALUE`, `RANK`, `PARTITION BY`), multi-table joins, conditional aggregations, `FORMAT_DATE`
- **Python (pandas)** — data merging, channel label engineering, CSV pipeline
- **Power BI** — DAX measures, calculated columns, data modelling, 3-page storytelling dashboard
- **Analytics thinking** — funnel analysis, channel attribution, cohort segmentation, data limitation documentation, business storytelling

---

## 👤 Author

**Rupsa Chaudhuri**
[LinkedIn](https://www.linkedin.com/in/rupsa-chaudhuri/) · [GitHub](https://github.com/rupsa723)

---

*Dataset: [GA4 Obfuscated Sample Ecommerce — Google BigQuery Public Data](https://developers.google.com/analytics/bigquery/web-ecommerce-demo-dataset)*
