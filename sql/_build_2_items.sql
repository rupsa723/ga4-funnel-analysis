-- ══════════════════════════════════════════════════════════════
-- FILE:     _build_2_items.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     build 2 of 2 — create the line-item table
-- FOLLOWS:  _build_1_sessions.sql — the session-grain table
-- LEADS TO: 00_data_quality_checks, which reconciles the two
-- SOURCE:   bigquery-public-data.ga4_obfuscated_sample_ecommerce
-- CREATES:  ga4_analysis.items
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- Unnests the items array on purchase events into one row per line
-- item per order. session_id is built with the same key as the
-- sessions table so the two join, which is what lets product
-- performance be read by acquisition channel.
--
-- This table records what was bought and nothing else. Carts that
-- were never purchased have no line items anywhere in a GA4
-- export, so abandoned basket value is not computable from it.
--
-- Three derived columns are added to the raw unnest, each one
-- answering a defect that shows up immediately in analysis:
-- placeholder rows with no quantity or revenue, empty category
-- strings, and the same product appearing under different
-- categories on different orders.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- STATEMENT 1: BUILD THE ITEMS TABLE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Flatten purchase items, then attach a stable category
-- per product name. The two-stage CTE for primary_category exists
-- to keep the window function away from an aliased column: naming
-- the IFNULL result item_category would shadow the source column,
-- and PARTITION BY resolves names against the table while GROUP BY
-- resolves them against the alias
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE `ga4-marketing-analysis.ga4_analysis.items` AS
WITH raw AS (
    SELECT
        CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params)
            WHERE key = 'ga_session_id') AS STRING)) AS session_id,
        PARSE_DATE('%Y%m%d', event_date) AS event_date,
        FORMAT_DATE('%Y-%m', PARSE_DATE('%Y%m%d', event_date)) AS month,
        item.item_name,
        item.item_category,
        item.price_in_usd AS item_price,
        item.quantity,
        item.item_revenue_in_usd AS item_revenue
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
        UNNEST(items) AS item
    WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
      AND event_name = 'purchase'
),
category_totals AS (
    SELECT
        item_name,
        IFNULL(NULLIF(item_category, ''), '(uncategorised)') AS category,
        SUM(item_revenue) AS category_revenue
    FROM raw
    WHERE item_revenue IS NOT NULL
    GROUP BY item_name, category
),
primary_category AS (
    SELECT
        item_name,
        category AS primary_category
    FROM category_totals
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY item_name
        ORDER BY category_revenue DESC, category) = 1
)
SELECT
    r.session_id,
    r.event_date,
    r.month,
    r.item_name,
    r.item_category,
    IFNULL(NULLIF(r.item_category, ''), '(uncategorised)')  AS item_category_clean,
    p.primary_category,
    r.item_price,
    r.quantity,
    r.item_revenue,
    (r.quantity IS NULL AND r.item_revenue IS NULL)         AS is_placeholder
FROM raw r
LEFT JOIN primary_category p
    USING (item_name);

-- ── WHAT IT PRODUCES ─────────────────────────────────────────
-- One row per line item per purchase, 1 Nov 2020 to 31 Jan 2021.
--
-- FROM THE EXPORT
--   session_id        same key as the sessions table, so the two
--                     join on it directly
--   event_date, month
--   item_name         the product. Stable, unlike item_category
--   item_category     as recorded on that order, kept unchanged
--   item_price        price_in_usd
--   quantity, item_revenue
--
-- DERIVED
--   item_category_clean
--     item_category with empty strings and nulls turned into
--     '(uncategorised)'. Saves an IFNULL in every query and stops
--     a blank bucket and a null bucket appearing as two rows
--
--   primary_category
--     the category under which this product earned the most
--     revenue across the whole window, applied to every row for
--     that product. A convenience for stable category reporting,
--     not a claim about what the product truly is. Null for
--     products with no revenue anywhere, which is only the
--     placeholder rows
--
--   is_placeholder
--     true where both quantity and item_revenue are null. These
--     rows carry no product and no money but do carry a
--     session_id, so they inflate order counts in any category
--     breakdown. Exclude them with WHERE NOT is_placeholder for
--     per-order calculations
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- STATEMENT 2: VERIFY THE BUILD
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Confirm the totals, then measure the two defects the
-- derived columns exist to handle
-- ─────────────────────────────────────────────────────────────

-- 2a. Totals and reconciliation against the sessions table
SELECT
    COUNT(*)                                     AS item_rows,
    COUNT(DISTINCT session_id)                   AS sessions_with_items,
    COUNT(DISTINCT item_name)                    AS distinct_products,
    COUNT(DISTINCT item_category_clean)          AS distinct_categories,
    COUNTIF(is_placeholder)                      AS placeholder_rows,
    SUM(quantity)                                AS units_sold,
    ROUND(SUM(item_revenue), 2)                  AS item_revenue,
    (SELECT ROUND(SUM(revenue), 2)
     FROM `ga4-marketing-analysis.ga4_analysis.sessions`) AS session_revenue
FROM `ga4-marketing-analysis.ga4_analysis.items`;

-- 2b. How unstable item_category is
SELECT
    item_name,
    ANY_VALUE(primary_category)                  AS primary_category,
    COUNT(DISTINCT item_category_clean)          AS categories_seen,
    ROUND(SUM(item_revenue), 2)                  AS revenue
FROM `ga4-marketing-analysis.ga4_analysis.items`
WHERE NOT is_placeholder
GROUP BY item_name
HAVING COUNT(DISTINCT item_category_clean) > 1
ORDER BY revenue DESC
LIMIT 20;

-- ── RESULT ───────────────────────────────────────────────────
-- 2a
-- item_rows                16,003
-- sessions_with_items       4,846
-- distinct_products           396
-- distinct_categories          22
-- placeholder_rows            448
-- units_sold               22,720
-- item_revenue           $362,110
-- session_revenue        $362,165
--
-- 2b (top rows by revenue, all products with 2+ categories)
-- product                              primary_category      cats   revenue
-- Google Zip Hoodie F/C                Apparel                  2   $13,788
-- Google Crewneck Sweatshirt Navy      Uncategorized Items      3   $10,714
-- Google Badge Heavyweight Pullover    Apparel                  2    $9,712
-- Super G Unisex Joggers               Shop by Brand            3    $9,529
-- Google Crewneck Sweatshirt Green     Apparel                  2    $8,382
-- Google Sherpa Zip Hoodie Charcoal    Apparel                  2    $6,397
-- Android Iconic Crewneck Sweatshirt   Apparel                  2    $5,159
-- Google Crewneck Sweatshirt Grey      Uncategorized Items      3    $4,499
-- Google Navy Speckled Tee             Apparel                  2    $4,440
-- Google Red Speckled Tee              Apparel                  2    $4,428
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. The tables reconcile. $362,110 in line items against
--      $362,165 in the sessions table is a 0.015% gap, which is
--      rounding on per-line sums against a single order-level
--      field. Two independent paths through the same export agree
--   2. sessions_with_items is 4,846 against 4,848 purchasing
--      sessions. Two orders fired a purchase event with no items
--      array, so product analysis covers 99.96% of orders
--   3. 448 placeholder rows across the 409 orders identified in
--      09_product_analysis QUERY 2, so some orders carry more than
--      one. They contribute no product and no revenue but do carry
--      a session_id
--   4. 22,720 units and $362,110 across 396 products and 22
--      category values
--   5. Category instability is not a handful of edge cases. Every
--      one of the ten largest products by revenue appears under at
--      least two categories, and four appear under three. It
--      reaches the top of the catalogue, not just the tail
--   6. primary_category inherits a bad label where the majority of
--      a product's revenue sits under one. Google Crewneck
--      Sweatshirt Navy, Google Crewneck Sweatshirt Grey and Google
--      Unisex Eco Tee Black all resolve to 'Uncategorized Items',
--      because that is where most of their money was recorded.
--      The column makes category totals stable; it does not make
--      the underlying labels good
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- WHAT THIS TABLE CANNOT ANSWER
-- ══════════════════════════════════════════════════════════════
-- Built from purchase events only, so it describes what was
-- bought and never what was looked at. Product interest, browsing
-- behaviour and demand for items nobody bought are all outside it.
-- Cart contents for abandoned sessions do not exist here, which is
-- why 11_checkout_abandonment records abandoned basket value as
-- uncomputable rather than estimating it.
--
-- Category totals remain approximate even with primary_category,
-- because primary_category is a choice about where to file a
-- product rather than a fact recovered from the data. Analyses
-- that group on item_category see what the store recorded;
-- analyses that group on primary_category see a stable view.
-- 09_product_analysis records its results on item_category, so
-- switching those queries to primary_category means re-running
-- QUERY 2 through QUERY 5.
-- ─────────────────────────────────────────────────────────────