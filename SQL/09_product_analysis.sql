-- ══════════════════════════════════════════════════════════════
-- FILE: 09_product_analysis.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Product-level analysis using items_clean.csv
--              covering top products, category performance,
--              monthly trends and channel-product relationship
-- ══════════════════════════════════════════════════════════════

-- ── BUSINESS CONTEXT ─────────────────────────────────────────
-- This file answers product and category-level questions:
--   Q1: Which products generate the most revenue?
--   Q2: Which categories drive the most revenue?
--   Q3: Which product leads each category?
--   Q4: How do categories trend month over month?
--   Q5: Which channel drives purchases of which category?
--
-- Data source: items_clean.csv — contains ONLY purchase events
-- with one row per item per purchase transaction.
-- Joined with master_events.csv on session_id for Q5.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- Q1: TOP 10 PRODUCTS BY REVENUE
-- ══════════════════════════════════════════════════════════════

SELECT
    item_name,
    SUM(item_revenue)    AS total_revenue,
    SUM(quantity)        AS total_quantity,
    COUNT(session_id)    AS no_of_orders
FROM `ga4_analysis.items_clean`
GROUP BY item_name
ORDER BY total_revenue DESC
LIMIT 10;

-- ── RESULTS ──────────────────────────────────────────────────
-- item_name                            revenue   qty   orders
-- Google Zip Hoodie F/C                $13,788   273    256
-- Google Crewneck Sweatshirt Navy      $10,714   236    225
-- Google Men's Tech Fleece Grey         $9,965   134    123
-- Google Badge Heavyweight Pullover     $9,712   201    184
-- Super G Unisex Joggers                $9,529   308    285
-- Google Crewneck Sweatshirt Green      $8,382   184    177
-- Google Sherpa Zip Hoodie Charcoal     $6,397   115    105
-- Google Men's Puff Jacket Black        $6,187    64     63
-- Google Men's Tech Fleece Vest         $5,549    84     77
-- Google Women's Puff Jacket Black      $5,313    57     56
--
-- KEY INSIGHT: All top 10 products are Apparel items.
-- Super G Joggers sells most units (308) but ranks 5th by
-- revenue — lower price point than hoodies and jackets.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- Q2: REVENUE BY CATEGORY
-- ══════════════════════════════════════════════════════════════
-- AOV = Average Order Value = Revenue ÷ Number of Orders
-- Filters out null, blank and '(not set)' categories
-- ─────────────────────────────────────────────────────────────

SELECT
    item_category,
    SUM(item_revenue)                              AS total_revenue,
    SUM(quantity)                                  AS total_quantity,
    COUNT(session_id)                              AS no_of_orders,
    ROUND(SUM(item_revenue) / COUNT(session_id), 2) AS aov
FROM `ga4_analysis.items_clean`
WHERE item_category IS NOT NULL
  AND item_category != ''
  AND item_category != '(not set)'
GROUP BY item_category
ORDER BY total_revenue DESC;

-- ── RESULTS (TOP 5) ──────────────────────────────────────────
-- category          revenue    qty    orders   AOV
-- Apparel           $171,727   5,447   4,984   $34.46
-- New                $25,813   2,132   1,445   $17.86
-- Bags               $23,860   1,053     704   $33.89
-- Campus Collection  $20,061   2,184   1,497   $13.40
-- Accessories        $17,815   2,006   1,276   $13.96
--
-- KEY INSIGHT: Apparel generates 7x more revenue than the
-- next category. Gift Cards have the highest AOV ($42.67)
-- but lowest order volume. Revenue is heavily concentrated
-- in Apparel — a business risk if seasonal demand drops.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- Q3: TOP PRODUCT PER CATEGORY
-- ══════════════════════════════════════════════════════════════
-- Uses RANK() window function partitioned by category to find
-- the #1 revenue-generating product within each category.
-- Two CTEs: first aggregate revenue, then rank within category.
-- ─────────────────────────────────────────────────────────────

WITH category_revenue AS (
    -- Aggregate revenue per product per category
    SELECT
        item_category,
        item_name,
        SUM(item_revenue) AS total_revenue
    FROM `ga4_analysis.items_clean`
    GROUP BY item_category, item_name
),
category_rank AS (
    -- Rank products within each category by revenue
    -- PARTITION BY category restarts rank for each category
    SELECT
        item_category,
        item_name,
        total_revenue,
        RANK() OVER (
            PARTITION BY item_category
            ORDER BY total_revenue DESC
        ) AS rnk
    FROM category_revenue
)
SELECT
    item_category,
    item_name,
    total_revenue
FROM category_rank
WHERE rnk = 1
  AND item_category IS NOT NULL
  AND item_category != ''
  AND item_category != '(not set)'
ORDER BY total_revenue DESC;

-- ── RESULTS ──────────────────────────────────────────────────
-- category              top_product                      revenue
-- Apparel               Google Zip Hoodie F/C            $13,692
-- Shop by Brand         Super G Unisex Joggers            $8,947
-- Drinkware             Google Canteen Bottle Black       $5,303
-- Bags                  Google Utility BackPack           $5,256
-- Accessories           Google Campus Bike                $4,352
-- Campus Collection     Google NYC Campus Zip Hoodie      $3,231
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- Q4: MONTHLY SALES TREND BY CATEGORY
-- ══════════════════════════════════════════════════════════════
-- FORMAT_DATE groups event_date into year-month buckets.
-- Shows how each category performed across the 3-month window.
-- ─────────────────────────────────────────────────────────────

SELECT
    FORMAT_DATE('%Y-%m', event_date) AS year_month,
    item_category,
    SUM(item_revenue)                AS total_revenue,
    SUM(quantity)                    AS total_quantity
FROM `ga4_analysis.items_clean`
WHERE item_category IS NOT NULL
  AND item_category != ''
  AND item_category != '(not set)'
GROUP BY year_month, item_category
ORDER BY year_month, total_revenue DESC;

-- ── RESULTS (APPAREL TREND) ───────────────────────────────────
-- year_month   Apparel Revenue   Total Sessions
-- 2020-11      $75,070           2,188
-- 2020-12      $66,962           8,325
-- 2021-01      $29,695           17,505
--
-- KEY INSIGHT: Apparel revenue is falling DESPITE traffic
-- growing 8x. Nov-Dec are holiday shopping months — Apparel
-- is bought as gifts. January brings high-volume but low-intent
-- traffic. Revenue concentration in Apparel creates seasonal
-- risk — diversifying into Bags and Drinkware (more stable
-- categories) would reduce volatility.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- Q5: CHANNEL + CATEGORY ANALYSIS (JOIN)
-- ══════════════════════════════════════════════════════════════
-- Joins items_clean with master_events on session_id to link
-- product purchases to their marketing channel.
--
-- IMPORTANT: master_events is filtered to purchase events ONLY
-- before joining. Without this filter, each item row would join
-- to EVERY event in that session (10-15 rows), multiplying
-- revenue by the number of events — producing wrong numbers.
-- ─────────────────────────────────────────────────────────────

WITH channel_purchases AS (
    -- One row per purchase session with its channel
    SELECT
        session_id,
        channel
    FROM `ga4_analysis.master_events`
    WHERE event_name = 'purchase'
)

SELECT
    cp.channel,
    i.item_category,
    ROUND(SUM(i.item_revenue), 2) AS total_revenue,
    COUNT(i.session_id)           AS orders
FROM `ga4_analysis.items_clean` i
JOIN channel_purchases cp ON i.session_id = cp.session_id
WHERE i.item_category IS NOT NULL
  AND i.item_category != ''
  AND i.item_category != '(not set)'
  AND cp.channel NOT IN ('Unknown', 'Obfuscated')
GROUP BY cp.channel, i.item_category
ORDER BY cp.channel, total_revenue DESC;

-- ── KEY FINDINGS ─────────────────────────────────────────────
-- 1. APPAREL DOMINATES EVERY CHANNEL
--    Every channel's top category is Apparel regardless of
--    how users arrived. No channel uniquely drives Bags,
--    Drinkware or Accessories purchases.
--
-- 2. REFERRAL DRIVES HIGH-VALUE APPAREL ORDERS
--    Referral: $4,521 Apparel revenue from 37 orders
--    = $122 avg per Apparel order vs $32 from Google Organic
--    Referral visitors buy more expensive Apparel items.
--
-- 3. GOOGLE PAID HAS ZERO APPAREL PURCHASES
--    Despite Apparel being the highest-value category,
--    Google Paid drives no Apparel sales — only Drinkware,
--    Accessories and Campus Collection (3 orders total).
--    Paid ads are not reaching the right audience.
--
-- 4. SELF-REFERRAL IS BROADLY DIVERSIFIED
--    Self-Referral drives purchases across all categories
--    including Gift Cards, Google merchandise and Writing
--    Instruments — internal navigation across the ecosystem.
-- ─────────────────────────────────────────────────────────────