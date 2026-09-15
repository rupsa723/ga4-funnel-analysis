-- ══════════════════════════════════════════════════════════════
-- FILE:     12_geography_analysis.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     12 of 12 — does geography explain anything?
-- FOLLOWS:  11_checkout_abandonment — the last device test fails,
--           and channel tiers hold at checkout
-- LEADS TO: end of sequence. QUERY 3 closes the attribution
--           question opened in 00 QUERY 4 and 02 QUERY 3
-- SOURCE:   ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- 4,848 orders spread over more than a hundred countries is enough
-- to rank the larger markets on revenue and order value and not
-- enough to say anything about the long tail, so every query here
-- carries a minimum-session threshold.
--
-- The store ships from the United States, so international
-- sessions face shipping cost and delivery time that domestic ones
-- do not, and lower conversion outside the US would be the
-- expected result. QUERY 1 shows it does not happen.
--
-- QUERY 3 does more than describe markets. Because it holds
-- country constant, it is the test that shows the channel mix is
-- produced by site mechanics rather than by marketing, and that
-- the attribution gap is uniform rather than source-specific.
-- Bounce by country is in 03_bounce_rate QUERY 3.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: TOP MARKETS BY REVENUE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Rank markets and compare each one's share of sessions
-- against its share of revenue
-- ─────────────────────────────────────────────────────────────

WITH totals AS (
    SELECT COUNT(*) AS t_sessions, SUM(revenue) AS t_revenue
    FROM `ga4_analysis.sessions`
)
SELECT
    IFNULL(s.country, '(not set)')                                  AS country,
    COUNT(*)                                                        AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNT(*), MAX(t.t_sessions)), 2)        AS pct_of_sessions,
    COUNTIF(s.purchased = 1)                                        AS purchases,
    ROUND(SUM(s.revenue), 2)                                        AS revenue,
    ROUND(100 * SAFE_DIVIDE(SUM(s.revenue), MAX(t.t_revenue)), 2)   AS pct_of_revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.purchased = 1), COUNT(*)), 2) AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(s.revenue), COUNTIF(s.purchased = 1)), 2) AS aov,
    ROUND(SAFE_DIVIDE(SUM(s.revenue), COUNT(*)), 2)                 AS rev_per_session
FROM `ga4_analysis.sessions` s
CROSS JOIN totals t
GROUP BY country
HAVING COUNT(*) >= 50
ORDER BY revenue DESC
LIMIT 20;

-- ── RESULT ───────────────────────────────────────────────────
-- country          sessions  %sess  purch   revenue   %rev   CVR     AOV  rev/sess
-- United States     158,155  43.92  2,117  $160,573  44.34  1.34   75.85      1.02
-- India              33,769   9.38    449   $34,986   9.66  1.33   77.92      1.04
-- Canada             26,824   7.45    390   $32,799   9.06  1.45   84.10      1.22
-- United Kingdom     11,327   3.15    151   $11,458   3.16  1.33   75.88      1.01
-- Spain               6,667   1.85     99    $7,681   2.12  1.48   77.59      1.15
-- France              7,162   1.99    102    $6,650   1.84  1.42   65.20      0.93
-- China               6,258   1.74     80    $6,623   1.83  1.28   82.79      1.06
-- Japan               4,732   1.31     76    $5,752   1.59  1.61   75.68      1.22
-- Turkey              3,646   1.01     54    $5,345   1.48  1.48   98.98      1.47
-- Germany             6,393   1.78     81    $5,288   1.46  1.27   65.28      0.83
-- Italy               4,998   1.39     55    $4,967   1.37  1.10   90.31      0.99
-- Australia           3,341   0.93     46    $4,378   1.21  1.38   95.17      1.31
-- Taiwan              6,057   1.68     80    $4,238   1.17  1.32   52.98      0.70
-- Brazil              3,596   1.00     55    $4,177   1.15  1.53   75.95      1.16
-- Netherlands         4,073   1.13     61    $3,991   1.10  1.50   65.43      0.98
-- Singapore           4,741   1.32     55    $3,824   1.06  1.16   69.53      0.81
-- South Korea         4,523   1.26     52    $3,543   0.98  1.15   68.13      0.78
-- Mexico              3,031   0.84     42    $3,211   0.89  1.39   76.45      1.06
-- Malaysia            1,872   0.52     31    $3,121   0.86  1.66  100.68      1.67
-- Poland              3,142   0.87     50    $2,989   0.83  1.59   59.78      0.95
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Revenue share tracks session share almost exactly in the
--      two largest markets: the United States takes 43.92% of
--      sessions and 44.34% of revenue, India 9.38% and 9.66%. The
--      store monetises international traffic at the same rate as
--      domestic traffic
--   2. Conversion is flat. Eighteen of the twenty markets fall
--      between 1.10% and 1.66%, spanning 158,155 sessions down to
--      1,872. Country does not predict whether someone buys
--   3. Where markets differ is basket size. Order value runs from
--      $52.98 in Taiwan to $100.68 in Malaysia, a factor of 1.9,
--      against a conversion spread of 1.5
--   4. Canada is the one large market that beats its traffic
--      share: 7.45% of sessions and 9.06% of revenue on an $84.10
--      order value. Taiwan under-indexes for the opposite reason,
--      converting normally at the lowest order value in the top
--      twenty
--   5. This export carries no shipping cost, delivery time,
--      currency or tax data, so the order-value differences cannot
--      be explained from within it
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: MARKETS RANKED BY EFFICIENCY
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: The same markets ordered by revenue per session, with a
-- higher threshold so the ranking is not led by a market that
-- recorded one large order
-- ─────────────────────────────────────────────────────────────

SELECT
    IFNULL(country, '(not set)')                                  AS country,
    COUNT(*)                                                      AS sessions,
    COUNTIF(purchased = 1)                                        AS purchases,
    ROUND(SUM(revenue), 2)                                        AS revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2) AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNT(*)), 2)                 AS rev_per_session,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2) AS bounce_ga4_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(channel != 'Unknown'), COUNT(*)), 2) AS channel_coverage_pct
FROM `ga4_analysis.sessions`
GROUP BY country
HAVING COUNT(*) >= 1000 AND COUNTIF(purchased = 1) >= 20
ORDER BY rev_per_session DESC
LIMIT 20;

-- ── RESULT ───────────────────────────────────────────────────
-- country          sessions  purch   revenue   CVR  rev/sess  bounce  coverage
-- Malaysia            1,872     31    $3,121  1.66      1.67   33.81     71.79
-- Thailand            1,586     27    $2,562  1.70      1.62   32.41     73.08
-- Turkey              3,646     54    $5,345  1.48      1.47   32.04     74.08
-- Australia           3,341     46    $4,378  1.38      1.31   33.91     73.69
-- Greece              1,337     21    $1,725  1.57      1.29   30.89     73.90
-- Colombia            1,701     31    $2,130  1.82      1.25   32.75     73.78
-- Japan               4,732     76    $5,752  1.61      1.22   32.57     72.72
-- Canada             26,824    390   $32,799  1.45      1.22   32.27     73.57
-- Ireland             2,147     32    $2,483  1.49      1.16   32.51     75.97
-- Brazil              3,596     55    $4,177  1.53      1.16   31.70     73.53
-- Spain               6,667     99    $7,681  1.48      1.15   32.10     73.11
-- China               6,258     80    $6,623  1.28      1.06   32.93     73.33
-- Mexico              3,031     42    $3,211  1.39      1.06   32.43     73.61
-- India              33,769    449   $34,986  1.33      1.04   32.81     73.84
-- Vietnam             1,537     22    $1,604  1.43      1.04   35.78     75.21
-- United States     158,155  2,117  $160,573  1.34      1.02   32.90     73.47
-- Russia              2,336     40    $2,378  1.71      1.02   32.65     75.39
-- United Kingdom     11,327    151   $11,458  1.33      1.01   32.65     73.42
-- Italy               4,998     55    $4,967  1.10      0.99   32.65     74.17
-- Netherlands         4,073     61    $3,991  1.50      0.98   32.65     74.34
-- Threshold: 1,000+ sessions and 20+ orders
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. The United States ranks sixteenth on revenue per session,
--      behind Malaysia, Thailand, Turkey, Australia and Canada.
--      The home market is average
--   2. Channel coverage sits between 71.79% and 75.97% in all
--      twenty markets, so the attribution gap is a uniform limit
--      rather than a geographic collection failure
--   3. Bounce runs 30.89% to 35.78% across the same twenty
--      markets, confirming 03_bounce_rate QUERY 3
--   4. The top of this ranking rests on 21 to 31 orders per
--      market, so a handful of large baskets moves it. Malaysia's
--      $1.67 per session comes from 31 orders
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: CHANNEL MIX WITHIN TOP MARKETS
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Hold country constant and look at the channel split.
-- This is the test that distinguishes a marketing pattern from a
-- site-mechanics pattern
-- ─────────────────────────────────────────────────────────────

SELECT
    country,
    channel,
    COUNT(*)                                                      AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNT(*),
        SUM(COUNT(*)) OVER (PARTITION BY country)), 2)            AS pct_of_country_sessions,
    COUNTIF(purchased = 1)                                        AS purchases,
    ROUND(SUM(revenue), 2)                                        AS revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2) AS cvr_pct
FROM `ga4_analysis.sessions`
WHERE country IN (
    SELECT country
    FROM `ga4_analysis.sessions`
    GROUP BY country
    ORDER BY COUNT(*) DESC
    LIMIT 8
)
GROUP BY country, channel
ORDER BY country, sessions DESC;

-- ── RESULT (share range across all eight markets) ────────────
-- Markets: United States, India, Canada, United Kingdom, France,
--          Germany, China, Spain
--
-- channel          share range        CVR range
-- Google Organic   26.26% - 27.81%    1.36% - 1.91%
-- Unknown          26.16% - 27.39%    0.00%  (1 order in total)
-- Self-Referral    15.99% - 17.50%    2.32% - 2.58%
-- Direct           10.15% - 10.97%    0.30% - 1.29%
-- Other             8.61% -  9.42%    0.32% - 0.73%
-- Referral          5.74% -  6.75%    3.24% - 5.88%
-- Google Paid       2.05% -  2.39%    0.00% - 2.16%
-- Obfuscated        1.45% -  2.06%    1.65% - 7.22%
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Every channel holds essentially the same share of traffic
--      in all eight markets. Google Organic varies by 1.55
--      percentage points across countries as different as the
--      United States, China and Germany; Self-Referral by 1.51.
--      Real acquisition channels do not behave this way, because
--      paid campaigns are targeted by country, referral partners
--      are regional, and organic share depends on local search
--      competition
--   2. A channel mix identical everywhere is produced by site
--      mechanics rather than marketing. This is independent
--      evidence for 02_channel_attribution QUERY 3: Self-Referral
--      is the store's own hostnames referring to each other, which
--      happens at the same rate wherever the visitor is
--   3. It also closes the question opened in 00 QUERY 4. An
--      unattributed share of 26.16% to 27.39% across eight
--      countries is a mechanical collection limit, not a
--      source-specific failure, which is what makes channel
--      comparison sound despite 26.47% missing attribution
--   4. Conversion does vary within channels by country, and
--      Referral is the clearest case: 5.88% in France, 5.18% in
--      Germany, 4.67% in Spain, against 3.24% in China. Referral
--      is the best channel in every market and noticeably better
--      in Western Europe
--   5. Google Paid records zero orders in the United Kingdom on
--      235 sessions and in France on 171. On those volumes zero is
--      unremarkable, and with 20 orders from 3,343 US sessions the
--      channel is negligible in every market
--   6. Direct conversion swings from 0.30% in China to 1.29% in
--      Spain on similar traffic shares, making it the only channel
--      whose behaviour looks genuinely geographic
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- END OF SEQUENCE
-- ══════════════════════════════════════════════════════════════
-- Dimensions tested against engagement, conversion and revenue:
--   device      (03, 07, 11)  explains nothing
--   country     (03, 12)      explains order value only
--   time        (05)          explains volume, and carries two
--                             measurement defects
--   channel     (02, 04, 06)  explains engagement and the
--                             checkout-to-payment step
--   visit count (08)          explains most of the revenue
--   entry page  (10)          explains where the weak traffic goes
-- ─────────────────────────────────────────────────────────────