-- ══════════════════════════════════════════════════════════════
-- FILE: 07_revenue_by_device.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Revenue, purchases, CVR and revenue per session
--              segmented by device category
-- ══════════════════════════════════════════════════════════════

-- ── BUSINESS CONTEXT ─────────────────────────────────────────
-- This query answers: "Do desktop, mobile and tablet users
-- behave differently in terms of purchasing and revenue?"
--
-- Device segmentation is critical for ecommerce because:
--   - Mobile users often browse but purchase on desktop
--   - Poor mobile UX can suppress CVR even with high traffic
--   - Revenue per session reveals spend quality per device
--
-- Two CTEs are built and JOINed on device_category:
--   1. revenue_   → purchase count and revenue per device
--   2. all_sessions → total sessions per device
-- ─────────────────────────────────────────────────────────────

WITH revenue_ AS (
    -- Purchase count and total revenue per device
    -- Only purchase events carry non-null revenue values
    SELECT
        device_category,
        COUNT(DISTINCT session_id)    AS purchase,
        SUM(CAST(revenue AS FLOAT64)) AS revenue
    FROM `ga4_analysis.master_events`
    WHERE event_name = 'purchase'
    GROUP BY device_category
),

all_sessions AS (
    -- Total sessions per device across all event types
    SELECT
        device_category,
        COUNT(DISTINCT session_id) AS sessions
    FROM `ga4_analysis.master_events`
    GROUP BY device_category
)

SELECT
    a.device_category,
    a.sessions,
    r.purchase,
    r.revenue,
    ROUND(r.revenue / a.sessions, 2)          AS revenue_per_session,
    ROUND(r.purchase * 100.0 / a.sessions, 1) AS cvr_pct
FROM all_sessions a
JOIN revenue_ r ON a.device_category = r.device_category
ORDER BY r.revenue DESC;

-- ── RESULTS ──────────────────────────────────────────────────
-- device_category  sessions  purchases  revenue   Rev/Session  CVR%
-- desktop          16,388    112        $7,252    $0.44        0.7%
-- mobile           11,113     79        $3,141    $0.28        0.7%
-- tablet              698      7          $411    $0.59        1.0%
-- ─────────────────────────────────────────────────────────────

-- ── KEY INSIGHTS ─────────────────────────────────────────────
-- 1. DESKTOP DOMINATES REVENUE
--    Desktop generates $7,252 vs mobile's $3,141 despite
--    only having 1.5x more sessions. Desktop users spend
--    more per visit ($0.44 vs $0.28 revenue per session).
--
-- 2. CVR IS IDENTICAL ACROSS DESKTOP AND MOBILE (0.7%)
--    Unlike many ecommerce sites where mobile CVR is much
--    lower, here both devices convert at the same rate.
--    The difference is in spend per transaction, not
--    likelihood of purchasing.
--
-- 3. TABLET HAS HIGHEST CVR (1.0%) BUT SMALL SAMPLE
--    Only 698 tablet sessions — too small to be
--    statistically significant. Do not make business
--    decisions based on tablet numbers alone.
--
-- 4. MOBILE REVENUE OPPORTUNITY
--    Mobile drives 40% of sessions but only 30% of revenue.
--    If mobile revenue per session ($0.28) could be brought
--    closer to desktop ($0.44), revenue would grow
--    significantly without acquiring new traffic.
-- ─────────────────────────────────────────────────────────────