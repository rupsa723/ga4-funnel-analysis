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
-- NOTE ON BOUNCE RATE BY CHANNEL:
--   Bounce rate by channel CANNOT be reliably calculated from
--   this dataset. Channel (source/medium) information is only
--   attached to deeper funnel events — NOT session_start.
--   Since bounced sessions consist of only one session_start
--   event, they all show as 'Unknown' channel. See dedicated
--   file 04_bounce_rate_by_channel.sql for full explanation.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: OVERALL BOUNCE RATE
-- ══════════════════════════════════════════════════════════════
-- Result: 52,939 sessions | 23,055 bounced | 43.55% bounce rate
-- ─────────────────────────────────────────────────────────────

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
    -- Total sessions across the entire dataset
    SELECT COUNT(session_id) AS total_sessions
    FROM `ga4_analysis.master_events`
)
SELECT
    MAX(total_sessions)                             AS total_sessions,
    COUNT(*)                                        AS bounced_sessions,
    ROUND(COUNT(*) / MAX(total_sessions) * 100, 2) AS bounce_rate_pct
FROM bounced, total;

-- ── RESULTS ──────────────────────────────────────────────────
-- total_sessions   bounced_sessions   bounce_rate_pct
-- 52,939           23,055             43.55%
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: BOUNCE RATE BY DEVICE CATEGORY
-- ══════════════════════════════════════════════════════════════
-- Each session belongs to exactly ONE device, so we can safely
-- add device_category to the GROUP BY alongside session_id.
-- This labels each session with its device without changing
-- the session-level grouping logic.
--
-- We JOIN bounced and total on device_category so each device's
-- bounced sessions are divided by THAT device's total sessions.
-- Without the JOIN, a cross join would produce wrong numbers.
-- ─────────────────────────────────────────────────────────────

WITH bounced AS (
    -- Bounced sessions labelled with device category
    SELECT
        session_id,
        device_category,
        COUNT(event_name) AS events
    FROM `ga4_analysis.master_events`
    GROUP BY session_id, device_category
    HAVING events = 1
),
total AS (
    -- Total sessions per device category
    SELECT
        device_category,
        COUNT(session_id) AS total_sessions
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
-- desktop          30,781          13,581            44.12%
-- mobile           20,779           9,187            44.21%
-- tablet            1,379             576            41.77%
--
-- KEY INSIGHT: Bounce rate is nearly identical across all
-- devices (~44%). The problem is NOT device-specific.
-- Focus should be on traffic quality and landing page
-- relevance rather than device-specific UX fixes.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: BOUNCE RATE BY COUNTRY (TOP MARKETS)
-- ══════════════════════════════════════════════════════════════
-- Same pattern as device — swap device_category for country.
-- Only showing countries with 50+ sessions for reliability.
-- Small sample sizes (e.g. 5 sessions, 100% bounce) are
-- statistically meaningless and should not be actioned.
-- ─────────────────────────────────────────────────────────────

WITH bounced AS (
    -- Bounced sessions labelled with country
    SELECT
        session_id,
        country,
        COUNT(event_name) AS events
    FROM `ga4_analysis.master_events`
    GROUP BY session_id, country
    HAVING events = 1
),
total AS (
    -- Total sessions per country
    SELECT
        country,
        COUNT(session_id) AS total_sessions
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
HAVING MAX(total_sessions) >= 50          -- exclude tiny samples
ORDER BY total_sessions DESC;

-- ── RESULTS (TOP 10) ─────────────────────────────────────────
-- country          total_sessions  bounced  bounce_rate%
-- United States    24,050          10,257   42.65%
-- India             4,652           2,253   48.43%
-- Canada            4,051           1,779   43.92%
-- United Kingdom    1,479             752   50.85%
-- Spain             1,078             429   39.80%
-- France            1,059             448   42.30%
-- Germany           1,045             452   43.25%
-- Singapore           889             300   33.75%
-- Taiwan              848             405   47.76%
-- China               824             395   47.94%
--
-- KEY INSIGHTS:
--   1. US dominates traffic (24K of 52K sessions) — healthy
--      42.65% bounce rate, priority market
--   2. India is #2 market with slightly higher bounce (48.43%)
--      May indicate pricing, currency, or shipping barriers
--   3. UK, Italy, Turkey, Indonesia all above 50% — worth
--      investigating for localisation improvements
--   4. Singapore has lowest bounce (33.75%) among top markets
--      — high intent traffic, strong conversion potential
-- ─────────────────────────────────────────────────────────────