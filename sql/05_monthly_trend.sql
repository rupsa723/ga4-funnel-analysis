-- ══════════════════════════════════════════════════════════════
-- FILE: 05_monthly_trend.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Month-over-month trend analysis of sessions,
--              purchases, revenue, CVR% and revenue per session
-- ══════════════════════════════════════════════════════════════

-- ── BUSINESS CONTEXT ─────────────────────────────────────────
-- This query answers: "Is the business growing healthily over
-- the 3-month period, or is growth masking quality problems?"
--
-- We use FORMAT_DATE('%Y-%m', event_date) to group all events
-- into their respective month (2020-11, 2020-12, 2021-01).
--
-- Two CTEs are built and then JOINed on year_month:
--   1. purchase_events → counts sessions that converted
--   2. total_session   → counts all sessions + total revenue
-- ─────────────────────────────────────────────────────────────

WITH purchase_events AS (
    -- Count distinct sessions that resulted in a purchase
    -- per month. We filter to event_name = 'purchase' only.
    SELECT
        FORMAT_DATE('%Y-%m', event_date) AS year_month,
        COUNT(DISTINCT session_id)       AS purchase_sessions
    FROM `ga4_analysis.master_events`
    WHERE event_name = 'purchase'
    GROUP BY year_month
),

total_session AS (
    -- Count ALL sessions and sum revenue per month
    -- SUM revenue is safe here because revenue is only
    -- non-null on purchase events — no double counting
    SELECT
        FORMAT_DATE('%Y-%m', event_date)        AS year_month,
        COUNT(DISTINCT session_id)              AS total_sessions,
        SUM(CAST(revenue AS FLOAT64))           AS total_revenue
    FROM `ga4_analysis.master_events`
    GROUP BY year_month
)

SELECT
    purchase_events.year_month,
    purchase_sessions,
    total_sessions,
    total_revenue,
    ROUND((purchase_sessions / total_sessions) * 100, 2) AS cvr_pct,
    ROUND(total_revenue / total_sessions, 2)             AS revenue_per_session
FROM purchase_events
JOIN total_session ON purchase_events.year_month = total_session.year_month
ORDER BY purchase_events.year_month;

-- ── RESULTS ──────────────────────────────────────────────────
-- year_month  purchases  sessions   revenue   CVR%   Rev/Session
-- 2020-11     21         2,188      $1,483    0.96%  $0.68
-- 2020-12     63         8,325      $5,360    0.76%  $0.64
-- 2021-01     114        17,505     $3,961    0.65%  $0.23
-- ─────────────────────────────────────────────────────────────

-- ── KEY INSIGHTS ─────────────────────────────────────────────
-- 1. TRAFFIC IS GROWING FAST
--    Sessions grew 8x in 3 months (2,188 → 17,505).
--    Purchases also grew (21 → 114). On the surface, positive.
--
-- 2. BUT TRAFFIC QUALITY IS DECLINING
--    CVR dropped from 0.96% → 0.65% month over month.
--    Revenue per session collapsed from $0.68 → $0.23 (66% drop).
--    January brought far more sessions but far less revenue
--    per visit — meaning most new traffic has low purchase intent.
--
-- 3. THE CORE BUSINESS INSIGHT
--    "Growing sessions ≠ growing revenue."
--    A marketing team celebrating 8x traffic growth without
--    monitoring CVR and revenue per session would be missing
--    the real story. The quality of incoming traffic is
--    deteriorating even as volume increases.
--
-- 4. HYPOTHESIS
--    The surge in January sessions is likely driven by low-intent
--    traffic — possibly broader ad targeting, seasonal curiosity
--    traffic post-holidays, or increased bot/referral traffic.
--    This should be investigated further in channel attribution.
-- ─────────────────────────────────────────────────────────────