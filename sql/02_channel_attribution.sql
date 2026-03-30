-- ══════════════════════════════════════════════════════════════
-- FILE: 02_channel_attribution.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Measures sessions, purchases, revenue, revenue
--              per session and CVR for each marketing channel
-- ══════════════════════════════════════════════════════════════

-- ── BUSINESS CONTEXT ─────────────────────────────────────────
-- Channel attribution answers: "Which marketing channel drives
-- the most revenue and sends the highest quality visitors?"
--
-- IMPORTANT NOTES ON DATA:
--   1. 'Unknown' channel excluded — 26,054 sessions with 0.04%
--      CVR, likely bots/internal visits, would skew results
--   2. 'Obfuscated' channel excluded — data is masked/hidden,
--      cannot be trusted for business decisions
--
-- KEY FINDINGS:
--   - Self-Referral drives the most volume (113 purchases, $5,380)
--     but this is internal Google ecosystem traffic, not a real
--     external marketing channel
--   - Referral is the hidden gem — only 98 sessions but $21.90
--     revenue per session, highest quality traffic by far
--   - Google Paid is underperforming — only $40 total revenue,
--     worst revenue per session at $1.54. Ad spend questionable.
--   - Google Organic is the strongest REAL marketing channel —
--     306 sessions, 30 purchases, 9.8% CVR
-- ─────────────────────────────────────────────────────────────

WITH revenue_ AS (
    -- Step 1: Get purchase count and revenue per channel
    -- Only looking at purchase events since revenue is only
    -- recorded at the moment of transaction
    SELECT
        channel,
        COUNT(DISTINCT session_id)          AS purchase,
        SUM(CAST(revenue AS FLOAT64))       AS revenue
    FROM `ga4_analysis.master_events`
    WHERE event_name = 'purchase'
    GROUP BY channel
),

all_sessions AS (
    -- Step 2: Get total session count per channel
    -- Counts ALL events (not just purchases) to capture
    -- every visit that came from each channel
    SELECT
        channel,
        COUNT(DISTINCT session_id)          AS sessions
    FROM `ga4_analysis.master_events`
    GROUP BY channel
)

-- Step 3: Join both CTEs on channel and calculate KPIs
-- revenue_per_session = how much each visit is worth on average
-- CVR = what % of sessions from this channel result in a purchase
SELECT
    a.channel,
    a.sessions,
    r.purchase,
    r.revenue,
    ROUND(r.revenue / a.sessions, 2)            AS revenue_per_session,
    ROUND(r.purchase * 100.0 / a.sessions, 1)   AS cvr_pct
FROM all_sessions a
JOIN revenue_ r ON a.channel = r.channel
WHERE a.channel NOT IN ('Unknown', 'Obfuscated')  -- exclude unreliable channels
ORDER BY r.revenue DESC;                           -- highest revenue first

-- ── RESULTS SUMMARY ──────────────────────────────────────────
-- Channel          Sessions  Purchases  Revenue   Rev/Session  CVR%
-- Self-Referral    1,222     113        $5,380    $4.40        9.2%
-- Google Organic     306      30        $1,002    $3.27        9.8%
-- Referral            98       9        $2,146   $21.90        9.2%
-- Direct             148      11          $425    $2.87        7.4%
-- Google Paid         26       3           $40    $1.54       11.5%
--
-- BEST CHANNEL BY REVENUE:        Self-Referral ($5,380)
-- BEST CHANNEL BY QUALITY:        Referral ($21.90 per session)
-- WORST CHANNEL BY ROI:           Google Paid ($40 total revenue)
-- STRONGEST REAL MKTG CHANNEL:    Google Organic (9.8% CVR)
-- ─────────────────────────────────────────────────────────────