-- ══════════════════════════════════════════════════════════════
-- FILE:     01_funnel_analysis.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     1 of 12 — where does the funnel lose people?
-- FOLLOWS:  00_data_quality_checks — the tables reconcile and the
--           session denominator is 360,129
-- LEADS TO: 02_channel_attribution — where the traffic came from
-- SOURCE:   ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- Each funnel stage is stored on the sessions table as a 0/1 flag
-- set by MAX(IF(...)) over the session's events, so a session
-- counts at a stage if it ever fired that event.
--
-- Those flags can be read two ways. Independently: did the session
-- ever reach this stage? Sequentially: did it reach this stage
-- having reached every prior one? Running both is not a formality
-- here, because they disagree by 2,000 orders.
--
-- QUERY 1 measures the funnel. QUERY 2 measures it again under the
-- sequential reading. QUERY 3 tests whether one of the stages is
-- an independent step at all.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: SEVEN-STAGE FUNNEL WITH STEP DROP-OFF
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Stage counts, share of all sessions, and conversion
-- from one step to the next. Stage 0 is included so the 1.46% of
-- sessions with no session_start (00 QUERY 3) appears on the same
-- table rather than needing separate explanation
-- ─────────────────────────────────────────────────────────────

WITH c AS (
    SELECT
        COUNT(*)                        AS all_sessions,
        COUNTIF(has_session_start = 1)  AS s1,
        COUNTIF(reached_view_item = 1)  AS s2,
        COUNTIF(reached_cart = 1)       AS s3,
        COUNTIF(reached_checkout = 1)   AS s4,
        COUNTIF(reached_shipping = 1)   AS s5,
        COUNTIF(reached_payment = 1)    AS s6,
        COUNTIF(purchased = 1)          AS s7
    FROM `ga4_analysis.sessions`
),
stages AS (
    SELECT 0 AS stage_no, 'All Sessions' AS stage, all_sessions AS sessions FROM c
    UNION ALL SELECT 1, 'Session Start',  s1 FROM c
    UNION ALL SELECT 2, 'View Item',      s2 FROM c
    UNION ALL SELECT 3, 'Add to Cart',    s3 FROM c
    UNION ALL SELECT 4, 'Begin Checkout', s4 FROM c
    UNION ALL SELECT 5, 'Shipping Info',  s5 FROM c
    UNION ALL SELECT 6, 'Payment Info',   s6 FROM c
    UNION ALL SELECT 7, 'Purchase',       s7 FROM c
)
SELECT
    stage_no,
    stage,
    sessions,
    ROUND(100 * SAFE_DIVIDE(sessions,
        MAX(IF(stage_no = 0, sessions, NULL)) OVER ()), 2)  AS pct_of_all_sessions,
    sessions - LAG(sessions) OVER (ORDER BY stage_no)       AS change_from_prev,
    ROUND(100 * SAFE_DIVIDE(sessions,
        LAG(sessions) OVER (ORDER BY stage_no)), 2)         AS step_conv_pct,
    ROUND(100 - 100 * SAFE_DIVIDE(sessions,
        LAG(sessions) OVER (ORDER BY stage_no)), 2)         AS step_dropoff_pct
FROM stages
ORDER BY stage_no;

-- ── RESULT ───────────────────────────────────────────────────
-- stage             sessions   % of all   step conv   step drop
-- All Sessions       360,129     100.00           —           —
-- Session Start      354,857      98.54       98.54        1.46
-- View Item           77,020      21.39       21.70       78.30
-- Add to Cart         15,188       4.22       19.72       80.28
-- Begin Checkout      11,106       3.08       73.12       26.88
-- Shipping Info       11,105       3.08       99.99        0.01
-- Payment Info         6,815       1.89       61.37       38.63
-- Purchase             4,848       1.35       71.14       28.86
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. The two largest losses are before checkout. 277,837
--      sessions end without viewing a product, and 61,832 of the
--      77,020 that view one never add anything to a cart
--   2. Once a session begins checkout, 43.7% of it completes
--      (4,848 of 11,106). Checkout is not where volume is lost
--   3. The largest late-funnel loss is Shipping Info to Payment
--      Info at 38.63%, where address entry and shipping cost
--      disclosure sit. Payment Info to Purchase loses a further
--      1,967 sessions
--   4. Shipping Info drops 0.01% from Begin Checkout, which is not
--      a plausible step. QUERY 3 resolves it
--   5. Relative scale of the two big losses: one percentage point
--      at Shipping to Payment moves 111 sessions forward, which
--      convert onward at 71.14%, so about 79 orders. One
--      percentage point at Session Start to View Item moves 3,549
--      sessions forward, which convert onward at 6.29%, so about
--      223 orders
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: STRICT SEQUENTIAL FUNNEL
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: The same flags with each stage conditional on every
-- prior stage. The difference between this table and QUERY 1 is
-- the volume of stage-skipping
-- ─────────────────────────────────────────────────────────────

WITH c AS (
    SELECT
        COUNT(*) AS all_sessions,
        COUNTIF(reached_view_item = 1) AS s2,
        COUNTIF(reached_view_item = 1 AND reached_cart = 1) AS s3,
        COUNTIF(reached_view_item = 1 AND reached_cart = 1
            AND reached_checkout = 1) AS s4,
        COUNTIF(reached_view_item = 1 AND reached_cart = 1
            AND reached_checkout = 1 AND reached_shipping = 1) AS s5,
        COUNTIF(reached_view_item = 1 AND reached_cart = 1
            AND reached_checkout = 1 AND reached_shipping = 1
            AND reached_payment = 1) AS s6,
        COUNTIF(reached_view_item = 1 AND reached_cart = 1
            AND reached_checkout = 1 AND reached_shipping = 1
            AND reached_payment = 1 AND purchased = 1) AS s7
    FROM `ga4_analysis.sessions`
),
stages AS (
    SELECT 1 AS stage_no, 'All Sessions'   AS stage, all_sessions AS sessions FROM c
    UNION ALL SELECT 2, 'View Item',       s2 FROM c
    UNION ALL SELECT 3, 'Add to Cart',     s3 FROM c
    UNION ALL SELECT 4, 'Begin Checkout',  s4 FROM c
    UNION ALL SELECT 5, 'Shipping Info',   s5 FROM c
    UNION ALL SELECT 6, 'Payment Info',    s6 FROM c
    UNION ALL SELECT 7, 'Purchase',        s7 FROM c
)
SELECT
    stage_no,
    stage,
    sessions AS strict_sessions,
    ROUND(100 * SAFE_DIVIDE(sessions,
        LAG(sessions) OVER (ORDER BY stage_no)), 2) AS step_conv_pct
FROM stages
ORDER BY stage_no;

-- ── RESULT ───────────────────────────────────────────────────
-- stage             strict     independent    gap    step conv
-- All Sessions     360,129         360,129       0          —
-- View Item         77,020          77,020       0      21.39
-- Add to Cart       15,173          15,188      15      19.70
-- Begin Checkout     5,959          11,106   5,147      39.27
-- Shipping Info      5,959          11,105   5,146     100.00
-- Payment Info       3,858           6,815   2,957      64.74
-- Purchase           2,848           4,848   2,000      73.82
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. The top of the funnel is genuinely sequential. Only 15
--      sessions add to a cart without viewing a product
--   2. The break is entirely at checkout. 5,147 sessions begin
--      checkout without having added anything to a cart in that
--      session, so nearly half of all checkout traffic arrives
--      with a cart already filled
--   3. 2,000 of the 4,848 orders, 41.3%, come from sessions that
--      skipped at least one earlier stage. Two in five purchases
--      finish a job started in an earlier session
--   4. The single-session conversion rate is 0.79% (2,848 of
--      360,129). The 1.35% in QUERY 1 counts orders completed in
--      sessions that did not contain the whole journey. Both are
--      correct and they answer different questions
--   5. QUERY 1 is therefore a session funnel, not a customer
--      journey. Its 80.28% view-to-cart loss is not 61,832 people
--      rejecting the product; an unknown share of them browse on
--      one visit and buy on another
--   6. The same effect appears from other angles:
--      08_new_vs_returning QUERY 3 shows users with 3 to 5
--      sessions buy at 10.75% against 0.48% for single-session
--      users, and 10_landing_page_analysis shows basket.html is
--      the entry page for 4,173 sessions converting at 5.97%
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: IS SHIPPING INFO A SEPARATE STAGE?
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: begin_checkout covers 11,106 sessions and
-- add_shipping_info covers 11,105. Either the two events fire
-- together, or a coincidence is hiding a genuine step
-- ─────────────────────────────────────────────────────────────

SELECT
    COUNTIF(reached_checkout = 1 AND reached_shipping = 1) AS both_fired,
    COUNTIF(reached_checkout = 1 AND reached_shipping = 0) AS checkout_only,
    COUNTIF(reached_checkout = 0 AND reached_shipping = 1) AS shipping_only,
    COUNTIF(reached_checkout = 1)                          AS any_checkout,
    ROUND(100 * SAFE_DIVIDE(
        COUNTIF(reached_checkout = 1 AND reached_shipping = 1),
        COUNTIF(reached_checkout = 1)), 2)                 AS pct_overlap
FROM `ga4_analysis.sessions`;

-- ── RESULT ───────────────────────────────────────────────────
-- both_fired      11,104
-- checkout_only        2
-- shipping_only        1
-- any_checkout    11,106
-- pct_overlap      99.98
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   Three sessions out of 11,106 fired one event without the
--   other. add_shipping_info carries no information that
--   begin_checkout does not already carry: the store collects
--   shipping details on the checkout entry screen and fires both
--   events in the same interaction. The funnel has six real
--   stages, and the 0.01% drop at stage 5 is an artefact of the
--   tagging rather than a step anyone passes through.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- WHERE THIS LEAVES THE ANALYSIS
-- ══════════════════════════════════════════════════════════════
-- 360,129 sessions in, 4,848 orders out, 1.35% end to end, and
-- 0.79% within a single visit. Two thirds of the loss is browsing
-- behaviour and one third sits between shipping and payment.
--
-- The funnel is a whole-site average across traffic of very
-- different quality, and it cannot say why sessions stop. The next
-- files partition it: by acquisition source (02, 04, 06), by time
-- (05), by device (07), by visit history (08), by product (09), by
-- landing page (10), by checkout step (11) and by market (12).
-- ─────────────────────────────────────────────────────────────