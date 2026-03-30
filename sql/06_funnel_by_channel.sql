-- ══════════════════════════════════════════════════════════════
-- FILE: 06_funnel_by_channel.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Funnel drop-off analysis broken down by
--              marketing channel — shows where each channel
--              loses users across the 6 funnel stages
-- ══════════════════════════════════════════════════════════════

-- ── BUSINESS CONTEXT ─────────────────────────────────────────
-- The overall funnel (01_funnel_analysis.sql) showed us WHERE
-- users drop off. This query adds the WHO — which marketing
-- channel is responsible for the drop-offs?
--
-- This answers: "Does Google Organic drop off at a different
-- stage than Direct or Referral? Which channel has the most
-- committed buyers once they start the funnel?"
-- ─────────────────────────────────────────────────────────────

-- ── IMPORTANT DATA LIMITATION ────────────────────────────────
-- Channel data coverage varies significantly by funnel stage:
--
--   session_start     →   0% channel coverage
--   view_item         →  22% channel coverage
--   begin_checkout    →  89% channel coverage
--   purchase          →  91% channel coverage
--
-- Because session_start carries NO channel information, the
-- session counts at Stage 1 are unreliable per channel.
-- This causes negative drop-off % at Stage 2 for some channels
-- (e.g. Direct shows 147 view_item sessions > 145 session_start
-- sessions). This happens because some sessions are counted
-- under 'Unknown' at session_start but correctly attributed
-- to their real channel at deeper events.
--
-- RECOMMENDATION: Trust the lower funnel stages (add_to_cart
-- onwards) for channel comparison. Session Start counts per
-- channel should NOT be used for business decisions.
-- ─────────────────────────────────────────────────────────────

WITH funnel_counts AS (
    -- Count distinct sessions per channel per funnel stage
    -- PARTITION BY channel in the window functions ensures
    -- LAG and FIRST_VALUE calculate within each channel only
    SELECT
        channel,
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
    GROUP BY channel, funnel_stage
)

SELECT
    channel,
    funnel_stage,
    sessions,

    -- Drop-off % between this stage and the previous stage
    -- PARTITION BY channel → calculates within each channel
    -- Without PARTITION BY, LAG would compare across channels
    ROUND(
        (LAG(sessions) OVER (PARTITION BY channel ORDER BY funnel_stage) - sessions) * 100.0
        / LAG(sessions) OVER (PARTITION BY channel ORDER BY funnel_stage)
    , 1) AS dropoff_pct,

    -- CVR from top = sessions at this stage ÷ sessions at stage 1
    -- FIRST_VALUE always returns the stage 1 count for that channel
    ROUND(
        sessions * 100.0
        / FIRST_VALUE(sessions) OVER (PARTITION BY channel ORDER BY funnel_stage)
    , 1) AS cvr_from_top_pct

FROM funnel_counts
ORDER BY channel, funnel_stage;

-- ── RESULTS SUMMARY (LOWER FUNNEL — RELIABLE STAGES) ─────────
-- channel         ATC→Checkout  Checkout→Pay  Pay→Purchase  Final CVR
-- Google Organic  33.3%drop     31.7%drop     26.8%drop     9.8%
-- Self-Referral   41.7%drop     30.1%drop     31.5%drop     9.5%
-- Referral        31.0%drop     35.0%drop     30.8%drop     9.2%
-- Direct          12.8%drop     34.1%drop     59.3%drop     7.6%
-- Google Paid     44.4%drop     20.0%drop     25.0%drop     12.0%
-- Unknown         54.9%drop     79.7%drop     31.3%drop     0.0%
--
-- KEY INSIGHTS:
--   1. UNKNOWN CHANNEL has massive drop-off at every stage
--      (89% at view_item, 94% at add_to_cart). These are
--      low-intent sessions with no purchase behaviour.
--
--   2. GOOGLE ORGANIC has the smoothest funnel progression
--      with consistent ~30% drop-off at each lower stage.
--      Best quality real marketing channel.
--
--   3. DIRECT has a very high drop-off at Payment Info→Purchase
--      (59.3%). Users start checkout but abandon at payment.
--      Possible friction: payment options, trust, UX issues.
--      Strong A/B test candidate.
--
--   4. GOOGLE PAID has the highest final CVR (12%) but only
--      3 purchases from 25 sessions — too small to be
--      statistically significant.
--
--   5. SESSION START COUNTS ARE UNRELIABLE per channel due to
--      0% channel coverage on session_start events. Negative
--      drop-off % at Stage 2 for some channels is a data
--      artefact, not real behaviour.
-- ─────────────────────────────────────────────────────────────