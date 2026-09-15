# SQL analysis — GA4 Digital Marketing Funnel Analysis

Google Merchandise Store, 1 November 2020 – 31 January 2021, from
`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`.

All queries run against `ga4_analysis.sessions` (360,129 rows, one per session)
and `ga4_analysis.items` (one row per line item per purchase). Five queries go
back to the raw export where the session tables cannot answer the question;
those are marked in the file header. Prefix the dataset with your project ID if
BigQuery does not resolve `ga4_analysis` by default.

## The sequence

Run the two build files first, in order. `_build_1_sessions.sql` defines the two
URL functions and creates the session table; `_build_2_items.sql` creates the
line-item table. Every derived column is computed during the build rather than
added afterwards, because a BigQuery project without billing cannot run DML, so
a schema change means re-running the build.

The numbered files run in order and each one answers a question raised by the
one before.

| # | File | Question | Answer |
|---|---|---|---|
| — | `_build_1_sessions.sql`, `_build_2_items.sql` | Build the two tables | 360,129 sessions and one row per line item |
| 00 | `00_data_quality_checks.sql` | Can the tables be trusted? | Yes, with three defects recorded |
| 01 | `01_funnel_analysis.sql` | Where does the funnel lose people? | Before checkout, and 41% of orders span more than one visit |
| 02 | `02_channel_attribution.sql` | Where does the traffic come from? | And a third of revenue is internally referred |
| 03 | `03_bounce_rate.sql` | Does the traffic engage? | Not device or country, and the metric is unstable over time |
| 04 | `04_bounce_rate_by_channel.sql` | Does the source explain engagement? | Yes — a 20pp spread |
| 05 | `05_monthly_trend.sql` | How does it move across the window? | December peaks, January carries a revenue defect |
| 06 | `06_funnel_by_channel.sql` | Does the source explain where it leaks? | Yes — at one step, by 44pp |
| 07 | `07_revenue_by_device.sql` | Does device explain anything? | No, on any measure |
| 08 | `08_new_vs_returning.sql` | Does visit history explain anything? | Yes — most of the revenue |
| 09 | `09_product_analysis.sql` | What did they buy? | Apparel, broadly, under an unreliable taxonomy |
| 10 | `10_landing_page_analysis.sql` | Where do sessions arrive? | A quarter of traffic lands where nothing sells |
| 11 | `11_checkout_abandonment.sql` | What happens to near-buyers? | 61% park the cart; new customers stall at shipping |
| 12 | `12_geography_analysis.sql` | Does geography explain anything? | Order value only, and it closes the attribution question |

Each file follows the same shape: purpose, then per query a purpose line, the
SQL, the result, and what it means. Recommendations and anything about how to
present or document the work are kept out of the query files.

## Still to run

Everything has been run except three validation columns in file 00. None changes
a published figure.

| Query | What is still missing |
|---|---|
| `00` QUERY 1 | `null_session_ids`, `negative_revenue_rows`, `purchases_with_zero_revenue` |
| `00` QUERY 4 | The unattributed profile, currently derived from `02` and `04` |
| `00` QUERY 6 | `orders_with_zero_revenue` and `pct_orders_zero_revenue` |
| `00` QUERY 7 | `int_value_is_1` and `int_only_events` |

`00` QUERY 1's grain check and QUERY 2's reconciliation were both closed by the
verification queries in the two build files: 360,129 rows against 360,129
distinct session IDs, and 4,846 of 4,848 orders present in the items table.

## Headline figures

| Metric | Value |
|---|---|
| Sessions | 360,129 |
| Purchases | 4,848 |
| Revenue | $362,165 (item table agrees at $362,110) |
| Conversion rate | 1.35% all sessions · 1.83% attributed · 0.79% single-session |
| Average order value | $74.70 |
| Channel coverage | 73.53% |
| Bounce rate | 32.82% pooled — not a single site metric, see 03 |

## Defects found in the data

- **Revenue collection fails from 26 January 2021.** Orders continue at normal
  conversion while revenue falls to zero by 31 January. January revenue is
  understated by roughly $16,000; corrected January order value is $63.96
  rather than $51.43. `00` QUERY 6 and `05` QUERY 2.
- **The engagement flag is assigned differently in January.** Two bounce
  definitions collapse while the third rises. Nov–Dec bounce is 44.37%,
  January 9.25%. `03` QUERY 4–5.
- **`session_engaged` is stored as an integer on 6%–9% of events** and the table
  build reads only the string value, so those are discarded. `00` QUERY 7.
- **`item_category` is not stable per product.** The same item name appears
  under different categories on different orders, so category totals are
  approximate and the product-level view is the reliable one. `09` QUERY 3.
- **A `(not set)` category row covers 409 orders** carrying 448 item rows, all
  with null quantity and null revenue. `09` QUERY 2, `_build_2_items` QUERY 2.

## Structural limitations

- No cost data in GA4 exports, so return on ad spend is not computable.
- `session_start` carries no source parameter; channel comes from the first
  non-null source anywhere in the session.
- 26.47% of sessions carry no channel. Those sessions average 1.51 page views
  and 11.5 seconds and produced one order and $12. The unattributed share is
  26.16%–27.39% in every one of the eight largest markets, which is what makes
  channel comparison sound despite the gap.
- `add_shipping_info` fires alongside `begin_checkout` (99.98% overlap), so the
  funnel has six real stages rather than seven.
- 5,272 sessions (1.46%) have no `session_start` event. They are longer and
  convert better than average, so filtering them out would bias the funnel.
- Abandoned cart contents are not recoverable; the items table is built from
  purchase events only.
- `user_pseudo_id` is a cookie, so returning-visitor counts undercount genuine
  repeat visitors.
- Shipping cost, delivery time, currency and tax are absent, so the order-value
  differences between markets cannot be explained from this export.

## Reading a file

Every file opens with a header naming its step in the sequence, what the previous
file established, and the question it hands to the next one. Inside, each query
carries its purpose, the SQL, the result it returned, and what that result means.

Recommendations, dashboard guidance and documentation notes are deliberately not
in these files. A query file should say what the data shows and stop there.

## Running them

1. Create a BigQuery project — the free sandbox is enough — and a dataset named
   `ga4_analysis` in the **US multi-region**, matching the public dataset's
   location. Cross-region queries fail.
2. Run `_build_1_sessions.sql`, then `_build_2_items.sql`. Each ends with
   verification queries; check those before going further.
3. Run `00` and confirm 360,129 rows and $362,165.
4. Run `01` through `12` in order.

The sandbox permits DDL but not DML, so `CREATE TABLE` works and `UPDATE` does
not. Any schema change means re-running a build file rather than patching a
table. Sandbox tables also expire after 60 days, which makes re-running the two
builds routine rather than a recovery.

A full scan of the window is roughly 2 GB against a 1 TB monthly free allowance.
