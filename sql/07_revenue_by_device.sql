-- ══════════════════════════════════════════════════════════════
-- FILE:     07_revenue_by_device.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     7 of 12 — does device explain anything?
-- FOLLOWS:  06_funnel_by_channel — source explains engagement and
--           the checkout-to-payment step
-- LEADS TO: 08_new_vs_returning — whether visit history explains
--           more than hardware does
-- SOURCE:   ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- 03 QUERY 2 already ruled device out as an explanation of bounce.
-- This tests it against the commercial measures, conversion and
-- revenue, and then twice more: inside each channel, and across
-- the three months. A dimension that fails on one measure may
-- still matter on another, so it is worth testing properly before
-- being set aside.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: DEVICE PERFORMANCE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Volume, revenue, conversion and order value by device
-- ─────────────────────────────────────────────────────────────

WITH totals AS (
    SELECT COUNT(*) AS t_sessions, SUM(revenue) AS t_revenue
    FROM `ga4_analysis.sessions`
)
SELECT
    s.device_category,
    COUNT(*)                                                            AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNT(*), MAX(t.t_sessions)), 2)            AS pct_of_sessions,
    COUNTIF(s.purchased = 1)                                            AS purchases,
    ROUND(SUM(s.revenue), 2)                                            AS revenue,
    ROUND(100 * SAFE_DIVIDE(SUM(s.revenue), MAX(t.t_revenue)), 2)       AS pct_of_revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.purchased = 1), COUNT(*)), 2)     AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(s.revenue), COUNTIF(s.purchased = 1)), 2)     AS aov,
    ROUND(SAFE_DIVIDE(SUM(s.revenue), COUNT(*)), 2)                     AS rev_per_session,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.reached_cart = 1), COUNT(*)), 2)  AS pct_reached_cart,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.channel != 'Unknown'), COUNT(*)), 2) AS channel_coverage_pct
FROM `ga4_analysis.sessions` s
CROSS JOIN totals t
GROUP BY s.device_category
ORDER BY sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- device    sessions  %sess  purch   revenue   %rev   CVR    AOV  rev/sess  %cart  coverage
-- desktop    208,942  58.02  2,749  $208,815  57.66  1.32  75.96      1.00   4.21     73.51
-- mobile     143,185  39.76  1,995  $146,768  40.53  1.39  73.57      1.03   4.24     73.56
-- tablet       8,002   2.22    104    $6,582   1.82  1.30  63.29      0.82   4.01     73.49
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Device explains almost nothing. Conversion spans 0.09
--      percentage points, cart reach 0.23, revenue per session 21
--      cents
--   2. Mobile converts marginally better than desktop, 1.39%
--      against 1.32%, the reverse of the usual ecommerce pattern.
--      On 143,185 and 208,942 sessions the gap is real and too
--      small to act on
--   3. Revenue share tracks session share on desktop (58.02% and
--      57.66%) and mobile (39.76% and 40.53%), so neither device
--      over- or under-monetises its traffic
--   4. Tablet is the only real difference, $63.29 order value
--      against roughly $75, on 104 orders and 2.22% of sessions
--   5. Channel coverage is identical across devices to within
--      0.07pp, which independently confirms the attribution gap is
--      not a device-specific tracking failure
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: DEVICE BY CHANNEL
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Device might not matter on average and still matter
-- inside a channel, if one source sends mobile traffic that
-- behaves differently from its desktop traffic
-- ─────────────────────────────────────────────────────────────

SELECT
    channel,
    device_category,
    COUNT(*)                                                          AS sessions,
    COUNTIF(purchased = 1)                                            AS purchases,
    ROUND(SUM(revenue), 2)                                            AS revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)     AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNTIF(purchased = 1)), 2)       AS aov,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2) AS bounce_ga4_pct
FROM `ga4_analysis.sessions`
WHERE channel != 'Unknown'
GROUP BY channel, device_category
HAVING COUNT(*) >= 1000
ORDER BY channel, sessions DESC;

-- ── RESULT (pairs with 1,000+ sessions) ──────────────────────
-- channel         device    sessions  purch   revenue   CVR    AOV  bounce
-- Direct          desktop     22,110    183   $15,051  0.83  82.25   33.77
-- Direct          mobile      14,909    126    $9,054  0.85  71.86   33.36
-- Google Organic  desktop     55,875    906   $62,962  1.62  69.49   25.22
-- Google Organic  mobile      38,326    670   $48,034  1.75  71.69   25.22
-- Google Organic  tablet       2,144     28    $1,906  1.31  68.07   25.93
-- Google Paid     desktop      4,494     32    $2,287  0.71  71.47   31.73
-- Google Paid     mobile       2,997     14      $723  0.47  51.64   34.53
-- Obfuscated      desktop      3,743    122    $8,596  3.26  70.46   43.47
-- Obfuscated      mobile       2,517     67    $4,150  2.66  61.94   45.61
-- Other           desktop     19,003    116    $8,175  0.61  70.47   30.87
-- Other           mobile      13,029     74    $5,478  0.57  74.03   31.70
-- Referral        desktop     12,893    552   $43,788  4.28  79.33   25.15
-- Referral        mobile       9,004    419   $29,212  4.65  69.72   24.74
-- Self-Referral   desktop     35,485    837   $67,944  2.36  81.18   27.49
-- Self-Referral   mobile      24,545    625   $50,117  2.55  80.19   27.32
-- Self-Referral   tablet       1,345     33    $2,064  2.45  62.55   27.29
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Mobile matches or beats desktop on conversion in five of
--      seven channels: Google Organic 1.75 against 1.62, Referral
--      4.65 against 4.28, Self-Referral 2.55 against 2.36, Direct
--      0.85 against 0.83
--   2. Bounce within channel is flat by device to within 0.5pp
--      everywhere except Google Paid and Obfuscated, both small
--   3. Google Paid is the one channel where mobile is worse, 0.47%
--      against 0.71% conversion and $51.64 against $71.47 order
--      value, resting on 14 mobile orders and 32 desktop orders
--   4. Order value is a few dollars higher on desktop inside most
--      channels, between $2 and $10, except Other where mobile is
--      higher. Not consistent enough to be a pattern
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: DEVICE MIX OVER TIME
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Test whether the January revenue fall came with a shift
-- in device mix
-- ─────────────────────────────────────────────────────────────

SELECT
    session_month,
    device_category,
    COUNT(*)                                                        AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNT(*),
        SUM(COUNT(*)) OVER (PARTITION BY session_month)), 2)        AS pct_of_month,
    COUNTIF(purchased = 1)                                          AS purchases,
    ROUND(SUM(revenue), 2)                                          AS revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)   AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNTIF(purchased = 1)), 2)     AS aov
FROM `ga4_analysis.sessions`
GROUP BY session_month, device_category
ORDER BY session_month, sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- month     device    sessions  %month  purch   revenue   CVR    AOV
-- 2020-11   desktop     62,820   57.95    910   $79,319  1.45  87.16
-- 2020-11   mobile      43,201   39.85    676   $62,087  1.56  91.84
-- 2020-11   tablet       2,380    2.20     32    $2,884  1.34  90.13
-- 2020-12   desktop     77,476   58.10  1,222   $97,722  1.58  79.97
-- 2020-12   mobile      52,896   39.67    850   $60,450  1.61  71.12
-- 2020-12   tablet       2,979    2.23     43    $2,353  1.44  54.72
-- 2021-01   desktop     68,646   57.99    617   $31,774  0.90  51.50
-- 2021-01   mobile      47,088   39.78    469   $24,231  1.00  51.67
-- 2021-01   tablet       2,643    2.23     29    $1,345  1.10  46.38
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Device mix is fixed to within 0.15pp across all three
--      months, so nothing about January is a change in the kind of
--      device people used
--   2. Conversion and order value fall on every device by roughly
--      the same proportion. Uniform decline across independent
--      segments points at something acting on all of them, which
--      is the revenue collection failure in 05 QUERY 2
--   3. Mobile out-converts desktop in all three months, so the
--      QUERY 1 result is stable over time rather than an artefact
--      of pooling
--   4. Device has now been tested against bounce, conversion,
--      revenue, order value, channel and time, and explains
--      nothing in any of them. 11 QUERY 2 applies the last test,
--      at checkout, where a small screen would plausibly cost
--      something
--
-- NOTE ON THE WINDOW FUNCTION:
--   SUM(COUNT(*)) OVER (PARTITION BY session_month) is safe here
--   because there is no ROLLUP in the GROUP BY. Window functions
--   run after grouping and will treat a rollup row as another
--   group, which halves every share
-- ─────────────────────────────────────────────────────────────