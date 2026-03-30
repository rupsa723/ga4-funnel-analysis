-- ══════════════════════════════════════════════════════════════
-- FILE: 01_funnel_analysis.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Measures how many sessions reached each stage
--              of the purchase funnel and where drop-offs occur
-- ══════════════════════════════════════════════════════════════

-- ── BUSINESS CONTEXT ─────────────────────────────────────────
-- The funnel has 6 stages:
--   Session Start → View Item → Add to Cart →
--   Begin Checkout → Payment Info → Purchase
--
-- KEY INSIGHT: 83% drop-off from Session Start → View Item
-- This does NOT mean 83% of shoppers lost interest.
-- Reasons for this large drop:
--   1. Many visitors land on non-product pages (homepage, about, blog)
--      and never navigate to the shop section
--   2. Bounce traffic — visitors who land and leave immediately
--   3. Low-intent traffic — our 'Unknown' channel (33,641 sessions)
--      likely contains bots, internal visits, or accidental traffic
--
-- REAL INSIGHT: The funnel for genuine shoppers starts at View Item.
-- Once someone views a product, drop-off rates become more moderate
-- (40% at checkout, 33% at payment) — these are the stages worth
-- optimising with A/B tests.
-- ─────────────────────────────────────────────────────────────

WITH funnel_counts AS (
    -- Step 1: Count distinct sessions per funnel stage
    -- We use COUNT(DISTINCT session_id) because we want to know
    -- how many VISITS reached each stage — not how many events fired.
    -- One session can trigger view_item 10 times but counts as 1 visit.
    SELECT
        CASE
            WHEN event_name = 'session_start'    THEN '1 - Session Start'
            WHEN event_name = 'view_item'        THEN '2 - View Item'
            WHEN event_name = 'add_to_cart'      THEN '3 - Add to Cart'
            WHEN event_name = 'begin_checkout'   THEN '4 - Begin Checkout'
            WHEN event_name = 'add_payment_info' THEN '5 - Add Payment Info'
            WHEN event_name = 'purchase'         THEN '6 - Purchase'
        END AS funnel_stage,
        COUNT(DISTINCT session_id) AS sessions
    FROM `ga4_analysis.master_events`
    GROUP BY funnel_stage
)

-- Step 2: Calculate drop-off % and overall CVR from top
-- LAG()         → gets the previous stage's session count
-- FIRST_VALUE() → always returns session_start count (row 1)
--                 so we can calculate CVR from the very top
SELECT
    funnel_stage,
    sessions,

    -- % of sessions lost between this stage and the previous one
    ROUND(
        (LAG(sessions) OVER (ORDER BY funnel_stage) - sessions) * 100.0
        / LAG(sessions) OVER (ORDER BY funnel_stage)
    , 1) AS dropoff_pct,

    -- % of all sessions (from session_start) that reached this stage
    ROUND(
        sessions * 100.0
        / FIRST_VALUE(sessions) OVER (ORDER BY funnel_stage)
    , 1) AS cvr_from_top_pct

FROM funnel_counts
ORDER BY funnel_stage;

-- ── RESULTS SUMMARY ──────────────────────────────────────────
-- Stage               Sessions   Drop-off%   CVR from Top%
-- 1 - Session Start   27,901     NULL        100.0%
-- 2 - View Item        4,691     83.2%        16.8%
-- 3 - Add to Cart        811     82.7%         2.9%
-- 4 - Begin Checkout     486     40.1%         1.7%
-- 5 - Add Payment Info   298     38.7%         1.1%
-- 6 - Purchase           198     33.6%         0.7%
--
-- BIGGEST LEAK: Session Start → View Item (83.2%)
-- BEST OPPORTUNITY FOR A/B TESTING: View Item → Add to Cart
-- OVERALL PURCHASE CVR: 0.7% of all sessions convert to purchase
-- ─────────────────────────────────────────────────────────────