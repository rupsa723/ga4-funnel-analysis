-- ══════════════════════════════════════════════════════════════
-- FILE: 03_bounce_rate.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Bounce rate analysis — overall, by device
--              category, and by country
-- ══════════════════════════════════════════════════════════════

-- ── BUSINESS CONTEXT ─────────────────────────────────────────
-- Bounce rate = % of sessions where the user triggered only ONE
-- event and left without any further interaction.
--
-- A bounced session means: the user landed on the site but
-- found nothing worth clicking on — they left immediately.
--
-- IMPORTANT CORRECTION NOTE:
--   The total CTE must use COUNT(DISTINCT session_id) not
--   COUNT(session_id). The raw table has multiple rows per
--   session (one per event), so COUNT without DISTINCT counts
--   rows not sessions, producing a falsely low bounce rate.
--   Correct formula: bounced sessions / distinct total sessions
--
-- NOTE ON BOUNCE RATE BY CHANNEL:
--   Bounce rate by channel CANNOT be reliably calculated from
--   this dataset. Channel (source/medium) information is only
--   attached to deeper funnel events, NOT session_start.
--   Since bounced sessions consist of only one session_start
--   event, they all show as Unknown channel. See dedicated
--   file 04_bounce_rate_by_channel.sql for full explanation.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: OVERALL BOUNCE RATE
-- ══════════════════════════════════════════════════════════════

WITH bounced AS (
    -- Sessions with only 1 event = bounced sessions
    -- HAVING filters to keep only sessions with exactly 1 event
    SELECT
        session_id,
        COUNT(event_name) AS events
    FROM `ga4_analysis.master_events`
    GROUP BY session_id
    HAVING events = 1
),
total AS (
    -- IMPORTANT: Use COUNT(DISTINCT session_id) not COUNT(session_id)
    -- The table has multiple rows per session (one per event).
    -- COUNT without DISTINCT counts rows, not sessions, giving
    -- a falsely low bounce rate of 43.55% instead of 82.29%
    SELECT COUNT(DISTINCT session_id) AS total_sessions
    FROM `ga4_analysis.master_events`
)
SELECT
    MAX(total_sessions)                             AS total_sessions,
    COUNT(*)                                        AS bounced_sessions,
    ROUND(COUNT(*) / MAX(total_sessions) * 100, 2) AS bounce_rate_pct
FROM bounced, total;

-- ── RESULTS ──────────────────────────────────────────────────
-- total_sessions   bounced_sessions   bounce_rate_pct
-- 28,018           23,055             82.29%
--
-- KEY INSIGHT: 82.29% of sessions fire only one event.
-- This aligns with our funnel finding that only 16.81% of
-- sessions reach View Item. Most users land and leave without
-- any product interaction. The real shopping funnel starts
-- at View Item.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: BOUNCE RATE BY DEVICE CATEGORY
-- ══════════════════════════════════════════════════════════════

WITH bounced AS (
    SELECT
        session_id,
        device_category,
        COUNT(event_name) AS events
    FROM `ga4_analysis.master_events`
    GROUP BY session_id, device_category
    HAVING events = 1
),
total AS (
    SELECT
        device_category,
        COUNT(DISTINCT session_id) AS total_sessions
    FROM `ga4_analysis.master_events`
    GROUP BY device_category
)
SELECT
    bounced.device_category,
    MAX(total_sessions)                             AS total_sessions,
    COUNT(*)                                        AS bounced_sessions,
    ROUND(COUNT(*) / MAX(total_sessions) * 100, 2) AS bounce_rate_pct
FROM bounced
JOIN total ON bounced.device_category = total.device_category
GROUP BY bounced.device_category
ORDER BY total_sessions DESC;

-- ── RESULTS ──────────────────────────────────────────────────
-- device_category  total_sessions  bounced_sessions  bounce_rate%
-- desktop          16,388          13,581            82.87%
-- mobile           11,113           9,187            82.67%
-- tablet              698             576            82.52%
--
-- KEY INSIGHT: Bounce rate is nearly identical across all
-- devices (~82-83%). The problem is NOT device-specific.
-- All device types show the same pattern — the issue is
-- universal traffic quality, not a broken mobile experience.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: BOUNCE RATE BY COUNTRY (TOP MARKETS)
-- ══════════════════════════════════════════════════════════════
-- Only showing countries with 50+ sessions for reliability.
-- Small sample sizes are statistically meaningless.
-- ─────────────────────────────────────────────────────────────

WITH bounced AS (
    SELECT
        session_id,
        country,
        COUNT(event_name) AS events
    FROM `ga4_analysis.master_events`
    GROUP BY session_id, country
    HAVING events = 1
),
total AS (
    SELECT
        country,
        COUNT(DISTINCT session_id) AS total_sessions
    FROM `ga4_analysis.master_events`
    GROUP BY country
)
SELECT
    bounced.country,
    MAX(total_sessions)                             AS total_sessions,
    COUNT(*)                                        AS bounced_sessions,
    ROUND(COUNT(*) / MAX(total_sessions) * 100, 2) AS bounce_rate_pct
FROM bounced
JOIN total ON bounced.country = total.country
GROUP BY bounced.country
HAVING total_sessions >= 50
ORDER BY bounce_rate_pct ASC;

-- ── RESULTS (LOWEST BOUNCE = HIGHEST INTENT) ─────────────────
-- country          total_sessions  bounced  bounce_rate%
-- Greece                  104          81    77.88%
-- Vietnam                 121          96    79.34%
-- Singapore               378         300    79.37%
-- Sri Lanka                54          43    79.63%
-- China                   490         395    80.61%
-- United States        12,419      10,257    82.59%
-- India                 2,686       2,253    83.88%
-- Canada                2,112       1,779    84.23%
-- Israel                  118         110    93.22%
-- Slovakia                 47          44    93.62%
--
-- KEY INSIGHTS:
--   1. Greece, Vietnam and Singapore have lowest bounce (~78-79%)
--      among meaningful markets — highest purchase intent
--   2. US is largest market (12,419 sessions) at 82.59%
--   3. Israel and Slovakia show very high bounce (93%+) —
--      likely shipping, currency, or language barriers
--   4. All markets show ~80%+ bounce — confirming the issue
--      is universal low-intent traffic, not geo-specific
-- ─────────────────────────────────────────────────────────────