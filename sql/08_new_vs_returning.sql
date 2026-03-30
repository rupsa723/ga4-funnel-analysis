-- ══════════════════════════════════════════════════════════════
-- FILE: 08_new_vs_returning.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Compares behaviour of new vs returning users
--              across sessions, purchases, revenue and CVR%
-- ══════════════════════════════════════════════════════════════

-- ── BUSINESS CONTEXT ─────────────────────────────────────────
-- New users are visiting the store for the first time.
-- Returning users have visited before — they already know
-- the brand, the products, and the checkout process.
--
-- Understanding the difference helps answer:
--   - Are first-time visitors converting or just browsing?
--   - How much more valuable is a returning visitor?
--   - Should marketing focus on acquisition or retention?
-- ─────────────────────────────────────────────────────────────

-- ── DATA LIMITATION NOTE ─────────────────────────────────────
-- The ideal approach would use GA4's built-in 'first_visit'
-- event to identify new users. However, first_visit was not
-- included in the original data download (only 6 funnel events
-- were downloaded to stay within BigQuery's 56K row limit).
--
-- APPROXIMATION USED:
--   Users with only 1 session  → labelled as 'New'
--   Users with 2+ sessions     → labelled as 'Returning'
--
-- This is a reasonable approximation within our 3-month
-- window (Nov 2020 – Jan 2021) but may slightly overcount
-- New users (a user could have 1 session and still be
-- returning from before the data window).
-- ─────────────────────────────────────────────────────────────

WITH user_labels AS (
    -- Label each user as New or Returning based on session count
    -- Users with only 1 distinct session = New
    -- Users with 2+ distinct sessions = Returning
    SELECT
        user_pseudo_id,
        CASE
            WHEN COUNT(DISTINCT session_id) = 1 THEN 'New'
            ELSE 'Returning'
        END AS user_type
    FROM `ga4_analysis.master_events`
    GROUP BY user_pseudo_id
)

-- Join user labels back to master_events so we can calculate
-- all metrics (sessions, purchases, revenue, CVR) per user type
-- in a single GROUP BY — no need for separate revenue/session CTEs
SELECT
    u.user_type,

    -- Total sessions for each user group
    COUNT(DISTINCT m.session_id)                                    AS sessions,

    -- Purchase sessions: count sessions where a purchase fired
    COUNT(DISTINCT CASE
        WHEN m.event_name = 'purchase'
        THEN m.session_id END)                                      AS purchases,

    -- Total revenue
    ROUND(SUM(CAST(m.revenue AS FLOAT64)), 2)                      AS revenue,

    -- Average revenue generated per session
    ROUND(SUM(CAST(m.revenue AS FLOAT64)) /
          COUNT(DISTINCT m.session_id), 2)                         AS revenue_per_session,

    -- Conversion rate: purchase sessions ÷ total sessions × 100
    ROUND(COUNT(DISTINCT CASE
        WHEN m.event_name = 'purchase'
        THEN m.session_id END) * 100.0 /
          COUNT(DISTINCT m.session_id), 2)                         AS cvr_pct

FROM `ga4_analysis.master_events` m
JOIN user_labels u ON m.user_pseudo_id = u.user_pseudo_id
GROUP BY u.user_type
ORDER BY u.user_type;

-- ── RESULTS ──────────────────────────────────────────────────
-- user_type   sessions  purchases  revenue   Rev/Session  CVR%
-- New         22,730    134        $6,546    $0.29        0.59%
-- Returning    5,418     64        $4,258    $0.79        1.18%
-- ─────────────────────────────────────────────────────────────

-- ── KEY INSIGHTS ─────────────────────────────────────────────
-- 1. RETURNING USERS ARE 2X MORE LIKELY TO PURCHASE
--    CVR: New = 0.59% vs Returning = 1.18%
--    A returning visitor is twice as likely to buy compared
--    to a first-time visitor. Brand familiarity and trust
--    built from previous visits drives higher conversion.
--
-- 2. RETURNING USERS SPEND 2.7X MORE PER SESSION
--    Revenue per session: New = $0.29 vs Returning = $0.79
--    Each returning visit is nearly 3x more valuable than
--    a new visit. Retaining customers pays significantly more
--    than acquiring new ones on a per-session basis.
--
-- 3. NEW USERS DOMINATE TRAFFIC (81% of sessions)
--    22,730 new sessions vs 5,418 returning sessions.
--    The store is heavily acquisition-driven. Given that
--    returning users are far more valuable, investing in
--    retention strategies (email remarketing, loyalty programs)
--    could significantly improve overall revenue efficiency.
--
-- 4. RETURNING USERS GENERATE 39% OF REVENUE FROM 19% OF SESSIONS
--    $4,258 / $10,804 total = 39% of revenue
--    Despite being a minority of traffic, returning users
--    punch well above their weight in revenue contribution.
-- ─────────────────────────────────────────────────────────────