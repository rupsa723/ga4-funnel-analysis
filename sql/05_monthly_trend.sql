-- ══════════════════════════════════════════════════════════════
-- FILE:     05_monthly_trend.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     5 of 12 — how does the picture move across the window?
-- FOLLOWS:  04_bounce_rate_by_channel — acquisition source is the
--           only dimension so far that explains engagement
-- LEADS TO: 06_funnel_by_channel — whether source also explains
--           where the funnel leaks
-- SOURCE:   ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- The window runs 1 November 2020 to 31 January 2021, spanning
-- Black Friday, Christmas and the post-holiday fall. Three months
-- cannot separate seasonality from trend, so everything here
-- describes this window rather than the store's trajectory.
--
-- QUERY 1 takes the monthly view. QUERY 2 takes the daily view,
-- which is where the revenue collection failure found in
-- 00 QUERY 6 becomes visible. QUERY 3 splits the trend by channel.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: MONTHLY OVERVIEW
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Volume, orders, revenue, conversion, order value and
-- the supporting measures, month by month
-- ─────────────────────────────────────────────────────────────

SELECT
    session_month,
    COUNT(*)                                                              AS sessions,
    COUNTIF(purchased = 1)                                                AS purchases,
    ROUND(SUM(revenue), 2)                                                AS revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)         AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNTIF(purchased = 1)), 2)           AS aov,
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNT(*)), 2)                         AS rev_per_session,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2)     AS bounce_ga4_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(channel != 'Unknown'), COUNT(*)), 2)  AS channel_coverage_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(user_type = 'New'), COUNT(*)), 2)     AS pct_new,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_cart = 1), COUNT(*)), 2)      AS pct_reached_cart,
    COUNTIF(has_session_start = 0)                                        AS sessions_without_start,
    MIN(session_date)                                                     AS first_date,
    MAX(session_date)                                                     AS last_date
FROM `ga4_analysis.sessions`
GROUP BY session_month
ORDER BY session_month;

-- ── RESULT ───────────────────────────────────────────────────
-- month    sessions  purch    revenue   CVR    AOV  rev/sess  bounce  cover  %new  %cart  no_start
-- 2020-11   108,401  1,618  $144,290  1.49  89.18      1.33   42.55  78.29 66.19   2.03     1,851
-- 2020-12   133,351  2,115  $160,525  1.59  75.90      1.20   45.84  74.23 72.59   6.34     1,558
-- 2021-01   118,377  1,115   $57,350  0.94  51.43      0.48    9.25  68.38 75.06   3.83     1,863
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. December is the volume peak on every measure: 133,351
--      sessions, 2,115 orders, $160,525. November reaches $144,290
--      on 25,000 fewer sessions, which is why its revenue per
--      session is the highest of the three at $1.33
--   2. January revenue falls 64% below December on 11% fewer
--      sessions. Traffic held and buying did not. QUERY 2 shows
--      part of that fall is a collection failure rather than
--      trading
--   3. Cart reach runs 2.03%, 6.34%, 3.83%. December visitors were
--      three times more likely to fill a cart than November
--      visitors while converting at a similar rate, so November
--      traffic was smaller and better qualified and December
--      traffic was broader
--   4. Channel coverage falls steadily from 78.29% to 68.38%, so a
--      channel that appears to shrink month over month may be
--      losing attribution rather than traffic
--   5. New session share climbs from 66.19% to 75.06% while
--      revenue collapses, consistent with 08_new_vs_returning
--      where returning sessions carry 67% of revenue
--   6. sessions_without_start is stable near 1.5% in all three
--      months, confirming the finding in 00 QUERY 3
--   7. Two columns here are not usable as printed. The January
--      bounce figure reflects a tracking change (03 QUERY 4 and
--      5), and January revenue and order value are understated by
--      a collection failure (QUERY 2 below)
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: DAILY TREND
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Monthly grain hides Black Friday, Cyber Monday, the
-- Christmas shutdown, and the revenue failure isolated in
-- 00_data_quality_checks QUERY 6
-- ─────────────────────────────────────────────────────────────

SELECT
    session_date,
    FORMAT_DATE('%a', session_date)                                   AS day_of_week,
    COUNT(*)                                                          AS sessions,
    COUNTIF(purchased = 1)                                            AS purchases,
    ROUND(SUM(revenue), 2)                                            AS revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)     AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNTIF(purchased = 1)), 2)       AS aov
FROM `ga4_analysis.sessions`
GROUP BY session_date
ORDER BY session_date;

-- ── RESULT (92 rows — excerpts) ──────────────────────────────
--
-- PEAK TRADING DAYS
-- date          day  sessions  purch   revenue   CVR     AOV
-- 2020-11-24    Tue     4,422     97   $10,097  2.19  104.09
-- 2020-11-27    Fri     3,977     89    $6,439  2.24   72.35   Black Friday
-- 2020-11-30    Mon     4,583    126   $11,944  2.75   94.79   Cyber Monday
-- 2020-12-08    Tue     7,562    107    $8,197  1.41   76.61   traffic peak
-- 2020-12-09    Wed     6,282    133   $10,997  2.12   82.68
-- 2020-12-10    Thu     5,993    130   $10,893  2.17   83.79
-- 2020-12-16    Wed     5,528    115   $10,877  2.08   94.58
--
-- CHRISTMAS SHUTDOWN
-- 2020-12-24    Thu     2,798     22    $1,192  0.79   54.18
-- 2020-12-25    Fri     2,645     17      $552  0.64   32.47
-- 2020-12-26    Sat     2,676     16      $734  0.60   45.88
--
-- REVENUE COLLECTION FAILURE
-- 2021-01-25    Mon     3,906     58    $3,027  1.48   52.19
-- 2021-01-26    Tue     4,089     49    $1,217  1.20   24.84
-- 2021-01-27    Wed     4,599     51      $457  1.11    8.96
-- 2021-01-28    Thu     4,216     55      $128  1.30    2.33
-- 2021-01-29    Fri     3,791     53      $190  1.40    3.58
-- 2021-01-30    Sat     2,900     26      $159  0.90    6.12
-- 2021-01-31    Sun     2,841     18        $0  0.00    0.00
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Cyber Monday is the best single day in the dataset:
--      $11,944 and a 2.75% conversion rate, the highest of the 92
--      days. Black Friday is not a spike. Its 3,977 sessions are
--      below the November weekday average and its revenue is
--      ordinary, though its 2.24% conversion is strong. For this
--      store the event lands on Monday
--   2. Traffic peaks on 8 December at 7,562 sessions, but the best
--      revenue days cluster from 9 to 16 December, which is a
--      shipping-deadline pattern rather than a traffic pattern
--   3. Trading collapses from 24 December and does not recover in
--      the remaining five weeks. Christmas Day takes $552
--   4. From 26 January, revenue falls apart while orders continue
--      and conversion holds between 0.90% and 1.40%. This is the
--      collection failure quantified in 00 QUERY 6: 252 orders
--      carrying $2,151 where roughly $16,100 would be expected
--   5. Corrected, January average order value is $63.96 rather
--      than $51.43, and the window's series is $89.18, $75.90,
--      $63.96. Conversion needs no correction
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: MONTHLY TREND BY CHANNEL
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Which channels drove the December peak and which ones
-- fell away in January
-- ─────────────────────────────────────────────────────────────

SELECT
    channel,
    session_month,
    COUNT(*)                                                        AS sessions,
    COUNTIF(purchased = 1)                                          AS purchases,
    ROUND(SUM(revenue), 2)                                          AS revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)   AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNTIF(purchased = 1)), 2)     AS aov,
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNT(*)), 2)                   AS rev_per_session
FROM `ga4_analysis.sessions`
WHERE channel != 'Unknown'
GROUP BY channel, session_month
ORDER BY channel, session_month;

-- ── RESULT ───────────────────────────────────────────────────
-- channel         month    sessions  purch   revenue   CVR    AOV  rev/sess
-- Direct          2020-11    13,253    106    $7,589  0.80  71.59      0.57
-- Direct          2020-12    15,536    146   $13,097  0.94  89.71      0.84
-- Direct          2021-01     9,050     63    $3,913  0.70  62.11      0.43
-- Google Organic  2020-11    26,842    560   $49,735  2.09  88.81      1.85
-- Google Organic  2020-12    34,603    705   $46,816  2.04  66.41      1.35
-- Google Organic  2021-01    34,900    339   $16,351  0.97  48.23      0.47
-- Google Paid     2020-11     2,680     11      $823  0.41  74.82      0.31
-- Google Paid     2020-12     3,200     27    $1,676  0.84  62.07      0.52
-- Google Paid     2021-01     1,792      9      $648  0.50  72.00      0.36
-- Obfuscated      2020-11     2,142     57    $4,085  2.66  71.67      1.91
-- Obfuscated      2020-12     2,569    102    $6,977  3.97  68.40      2.72
-- Obfuscated      2021-01     1,683     36    $2,057  2.14  57.14      1.22
-- Other           2020-11    11,206     79    $6,424  0.70  81.32      0.57
-- Other           2020-12    12,700     74    $5,159  0.58  69.72      0.41
-- Other           2021-01     8,884     44    $2,267  0.50  51.52      0.26
-- Referral        2020-11     7,302    322   $27,867  4.41  86.54      3.82
-- Referral        2020-12     8,469    442   $34,546  5.22  78.16      4.08
-- Referral        2021-01     6,625    230   $11,998  3.47  52.17      1.81
-- Self-Referral   2020-11    21,444    482   $47,755  2.25  99.08      2.23
-- Self-Referral   2020-12    21,915    619   $52,254  2.82  84.42      2.38
-- Self-Referral   2021-01    18,016    394   $20,116  2.19  51.06      1.12
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Google Organic grows in absolute sessions across the whole
--      window, 26,842 to 34,900, while total traffic falls in
--      January. Its share rises from 24.8% to 29.5% and it is the
--      only channel that grew
--   2. Google Organic conversion halves in January, 2.04% to
--      0.97%, the largest fall of any channel. More sessions
--      converting at less than half the rate is a change in what
--      the traffic wants, and this export carries no query or
--      landing-intent data that could identify it
--   3. Referral holds up best. Even in January it converts at
--      3.47% and returns $1.81 per session, above every other
--      channel's best month except Self-Referral's
--   4. Google Paid records 11, 27 and 9 orders across the three
--      months. Nothing in this table supports a conclusion about
--      paid performance beyond its size
--   5. Average order value falls in January for every single
--      channel, by between 28% and 40%. A decline that uniform
--      across unrelated sources is not a channel effect; it is the
--      revenue collection failure landing on all of them, which
--      corroborates QUERY 2
-- ─────────────────────────────────────────────────────────────