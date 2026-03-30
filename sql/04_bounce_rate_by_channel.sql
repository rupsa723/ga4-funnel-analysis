-- ══════════════════════════════════════════════════════════════
-- FILE: 04_bounce_rate_by_channel.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Attempted bounce rate by channel analysis
--              and explanation of why it cannot be reliably
--              calculated from this dataset
-- ══════════════════════════════════════════════════════════════

-- ── WHY THIS ANALYSIS HAS A DATA LIMITATION ──────────────────
-- In this GA4 dataset, channel (source/medium) information is
-- only attached to DEEPER funnel events:
--
--   session_start     →   0% channel coverage
--   view_item         →  22% channel coverage
--   begin_checkout    →  89% channel coverage
--   purchase          →  91% channel coverage
--
-- A bounced session has only ONE event — almost always
-- session_start — which carries NO channel information.
--
-- Therefore bounced sessions cannot be linked to a channel.
-- They all appear as 'Unknown', making bounce rate by channel
-- unreliable and misleading.
--
-- ANALOGY: Like trying to find out which travel agency sent
-- hotel guests who checked out immediately — but the check-in
-- log never recorded their agency name.
--
-- THIS IS A KNOWN DATA LIMITATION OF THIS DATASET.
-- It should be flagged in any presentation or dashboard.
-- ─────────────────────────────────────────────────────────────

-- ── THE QUERY (run to see the limitation in action) ──────────
WITH bounced AS (
    -- Sessions with only 1 event = bounced
    -- These sessions almost always have channel = 'Unknown'
    -- because session_start carries no channel information
    SELECT
        session_id,
        channel,
        COUNT(event_name) AS events
    FROM `ga4_analysis.master_events`
    GROUP BY session_id, channel
    HAVING events = 1
),
total AS (
    -- Total sessions per channel
    SELECT
        channel,
        COUNT(session_id) AS total_sessions
    FROM `ga4_analysis.master_events`
    GROUP BY channel
)
SELECT
    bounced.channel,
    MAX(total_sessions)                             AS total_sessions,
    COUNT(*)                                        AS bounced_sessions,
    ROUND(COUNT(*) / MAX(total_sessions) * 100, 2) AS bounce_rate_pct
FROM bounced
JOIN total ON bounced.channel = total.channel
GROUP BY bounced.channel
ORDER BY total_sessions DESC;

-- ── ACTUAL OUTPUT ─────────────────────────────────────────────
-- channel         total_sessions  bounced_sessions  bounce_rate%
-- Unknown         33,641          23,047            68.51%   ← all real bounces end up here
-- Self-Referral   12,610               6             0.05%   ← near zero: these sessions went deeper
-- Obfuscated       1,853               2             0.11%   ← same reason
-- Google Organic, Direct, Referral, Google Paid → NOT SHOWN
-- (those channels only appear on non-bounced sessions)
--
-- CONCLUSION: This metric CANNOT be reliably reported.
-- Channels with real traffic (Google Organic, Direct etc.)
-- appear to have 0% bounce rate — which is factually wrong.
-- All bounce traffic is absorbed into 'Unknown'.
--
-- WHAT TO REPORT INSTEAD:
-- Use CVR% by channel from 02_channel_attribution.sql as a
-- proxy for traffic quality. A low CVR channel with high
-- session volume is effectively the same signal as high
-- bounce rate — users are arriving but not engaging.
-- ─────────────────────────────────────────────────────────────