-- ══════════════════════════════════════════════════════════════
-- FILE:     03_bounce_rate.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     3 of 12 — does the traffic engage, and is the metric
--           that measures engagement trustworthy?
-- FOLLOWS:  02_channel_attribution — the traffic mix, and the fact
--           that one third of revenue is internally referred
-- LEADS TO: 04_bounce_rate_by_channel — whether the source of a
--           session predicts whether it engages
-- SOURCE:   ga4_analysis.sessions,
--           bigquery-public-data.ga4_obfuscated_sample_ecommerce
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- Three definitions are stored on the sessions table:
--
--   is_bounce_ga4       session_engaged never set to 1. GA4's own
--                       definition, the inverse of engagement rate
--   is_bounce_pageview  one page view or fewer and no
--                       user_engagement event. Closest to the
--                       Universal Analytics definition
--   is_bounce_10sec     under ten seconds of total engagement time
--
-- The GA4 definition is adopted as primary because it is the one a
-- stakeholder can reproduce in the GA4 interface. That is a choice
-- rather than a correctness claim.
--
-- Two construction traps this file is built to avoid. The
-- denominator must count sessions, either COUNT(DISTINCT
-- session_id) or COUNT(*) on a session-grain table; counting
-- session_id on an event-level table inflates it and returns a
-- bounce rate that looks plausible and is wrong. The numerator
-- must be built from every event type; a bounce rate computed from
-- funnel events alone measures funnel non-progression, which is a
-- different quantity wearing the same name.
--
-- QUERY 1 measures it. QUERY 2 and 3 test whether device or
-- country explains it. QUERY 4 tests whether the metric is
-- comparable across the window, and QUERY 5 goes to the raw export
-- to find out why it is not.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: OVERALL BOUNCE RATE, THREE DEFINITIONS
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Establish the site figure and the spread between
-- definitions
-- ─────────────────────────────────────────────────────────────

SELECT
    COUNT(*)                                                              AS total_sessions,
    COUNTIF(is_bounce_ga4 = 1)                                            AS bounced_ga4,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2)     AS bounce_ga4_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_pageview = 1), COUNT(*)), 2) AS bounce_pageview_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_10sec = 1), COUNT(*)), 2)   AS bounce_10sec_pct,
    ROUND(AVG(page_views), 2)                                             AS avg_page_views,
    ROUND(AVG(total_engagement_msec) / 1000, 1)                           AS avg_engagement_sec
FROM `ga4_analysis.sessions`;

-- ── RESULT ───────────────────────────────────────────────────
-- total_sessions        360,129
-- bounced_ga4           118,197
-- bounce_ga4_pct          32.82
-- bounce_pageview_pct     14.75
-- bounce_10sec_pct        53.58
-- avg_page_views           3.75
-- avg_engagement_sec       70.3
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. The three definitions span 39 percentage points on the same
--      360,129 sessions, so a bounce figure quoted without its
--      definition carries no information
--   2. The GA4 definition sits between the other two because
--      session_engaged is set by a ten-second threshold, a
--      conversion, or a second page view. It captures sessions the
--      page-view rule misses and excuses sessions the ten-second
--      rule condemns
--   3. 53.58% under the ten-second rule against 14.75% under the
--      page-view rule means a large population views more than one
--      page quickly. Skimming rather than accidental arrival
--   4. QUERY 4 shows this pooled figure is not a single site
--      metric
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: BOUNCE RATE BY DEVICE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Test whether device explains engagement. All three
-- definitions are run, because the result here is an absence of
-- variation and an absence only means something if it survives a
-- change of definition
-- ─────────────────────────────────────────────────────────────

SELECT
    device_category,
    COUNT(*)                                                               AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2)      AS bounce_ga4_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_pageview = 1), COUNT(*)), 2) AS bounce_pageview_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_10sec = 1), COUNT(*)), 2)    AS bounce_10sec_pct,
    ROUND(AVG(page_views), 2)                                              AS avg_page_views,
    ROUND(AVG(total_engagement_msec) / 1000, 1)                            AS avg_engagement_sec
FROM `ga4_analysis.sessions`
GROUP BY device_category
ORDER BY sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- device    sessions   ga4    pageview   10sec   pages   engage_s
-- desktop    208,942  32.81     14.80    53.68    3.76      69.8
-- mobile     143,185  32.83     14.67    53.44    3.74      71.4
-- tablet       8,002  33.07     14.95    53.60    3.67      65.3
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Device does not explain engagement. The spread is 0.26pp on
--      the GA4 definition, 0.28pp on the page-view definition and
--      0.24pp on the ten-second definition
--   2. Average page views vary by 0.09 and engagement time by 6.1
--      seconds across devices. On 360,129 sessions that is flat
--   3. Tablet is marginally worst on every measure and carries
--      2.22% of sessions
--   4. This rules device out as a cause of bounce; it does not
--      establish that the mobile experience is good, only that it
--      is no worse than desktop on this metric. 07 and 11 test
--      device against conversion and checkout completion
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: BOUNCE RATE BY COUNTRY
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Test whether market explains engagement. Restricted to
-- countries with at least 50 sessions, below which a single
-- session moves the rate by more than two percentage points
-- ─────────────────────────────────────────────────────────────

SELECT
    country,
    COUNT(*)                                                               AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2)      AS bounce_ga4_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_10sec = 1), COUNT(*)), 2)    AS bounce_10sec_pct,
    ROUND(AVG(page_views), 2)                                              AS avg_page_views,
    COUNTIF(purchased = 1)                                                 AS purchases,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)          AS cvr_pct,
    ROUND(SUM(revenue), 2)                                                 AS revenue
FROM `ga4_analysis.sessions`
WHERE country IS NOT NULL
GROUP BY country
HAVING COUNT(*) >= 50
ORDER BY sessions DESC
LIMIT 25;

-- ── RESULT (top 25 by sessions) ──────────────────────────────
-- country          sessions   ga4    10sec   pages   purch   CVR    revenue
-- United States     158,155  32.90   53.67    3.81   2,117  1.34  $160,573
-- India              33,769  32.81   53.61    3.64     449  1.33   $34,986
-- Canada             26,824  32.27   52.58    3.78     390  1.45   $32,799
-- United Kingdom     11,327  32.65   53.79    3.72     151  1.33   $11,458
-- France              7,162  33.54   54.19    3.60     102  1.42    $6,650
-- Spain               6,667  32.10   53.26    3.84      99  1.48    $7,681
-- Germany             6,393  33.33   54.62    3.53      81  1.27    $5,288
-- China               6,258  32.93   53.58    3.85      80  1.28    $6,623
-- Taiwan              6,057  32.71   54.14    3.76      80  1.32    $4,238
-- Italy               4,998  32.21   52.84    3.85      55  1.10    $4,967
-- Singapore           4,741  33.45   54.23    3.78      55  1.16    $3,824
-- Japan               4,732  32.57   53.38    3.78      76  1.61    $5,752
-- South Korea         4,523  32.79   54.41    3.58      52  1.15    $3,543
-- Netherlands         4,073  32.65   53.62    3.89      61  1.50    $3,991
-- Turkey              3,646  32.04   52.77    3.89      54  1.48    $5,345
-- Brazil              3,596  31.70   53.75    3.68      55  1.53    $4,177
-- Australia           3,341  33.91   54.50    3.66      46  1.38    $4,378
-- Indonesia           3,244  33.08   54.50    3.42      26  0.80    $2,124
-- Poland              3,142  31.25   52.20    3.70      50  1.59    $2,989
-- Mexico              3,031  32.43   52.13    4.05      42  1.39    $3,211
-- (not set)           2,882  33.73   53.78    3.52      34  1.18    $1,565
-- Russia              2,336  33.60   53.30    3.86      40  1.71    $2,378
-- Hong Kong           2,208  32.20   52.54    3.73      33  1.49    $1,995
-- Ireland             2,147  32.51   53.14    3.96      32  1.49    $2,483
-- Sweden              1,966  32.60   51.42    3.69      23  1.17    $1,256
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Country does not explain engagement either. Across 25
--      markets spanning 158,155 sessions down to 1,966, the GA4
--      bounce rate moves between 31.25% and 33.91%, a 2.66pp
--      spread, and the ten-second definition between 51.42% and
--      54.62%
--   2. Conversion is nearly as flat: 22 of the 25 markets sit
--      between 1.10% and 1.71%. Indonesia at 0.80% is the only
--      market meaningfully below the pack
--   3. Average page views run 3.42 to 4.05, so session depth is
--      not geographic either
--   4. Two dimensions are now ruled out. 04 tests the third
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 4: IS THE METRIC STABLE ACROSS THE WINDOW?
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Test whether the adopted definition is comparable
-- month to month, by checking whether the other two definitions
-- move with it
-- ─────────────────────────────────────────────────────────────

SELECT
    session_month,
    COUNT(*)                                                               AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2)      AS bounce_ga4_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_pageview = 1), COUNT(*)), 2) AS bounce_pageview_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_10sec = 1), COUNT(*)), 2)    AS bounce_10sec_pct,
    ROUND(AVG(page_views), 2)                                              AS avg_page_views,
    ROUND(AVG(total_engagement_msec) / 1000, 1)                            AS avg_engagement_sec,
    ROUND(AVG(engagement_events), 2)                                       AS avg_engagement_events
FROM `ga4_analysis.sessions`
GROUP BY session_month
ORDER BY session_month;

-- ── RESULT ───────────────────────────────────────────────────
-- month     sessions    ga4   pageview   10sec   pages   engage_s   engage_events
-- 2020-11    108,401  42.55     19.04    48.13    4.19       87.8            3.76
-- 2020-12    133,351  45.84     20.43    53.68    3.58       74.6            3.01
-- 2021-01    118,377   9.25      4.42    58.47    3.54       49.5            2.11
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. It is not stable. Two definitions collapse in January and
--      the third rises. GA4 bounce falls from 45.84% to 9.25% and
--      page-view bounce from 20.43% to 4.42%, while ten-second
--      bounce climbs from 53.68% to 58.47%. No single change in
--      visitor behaviour produces that pattern
--   2. The two that collapse depend on engagement flags. The one
--      that rises depends on measured engagement time. Time per
--      session falls steadily across the window, 87.8 to 74.6 to
--      49.5 seconds, and user_engagement events per session fall
--      from 3.76 to 2.11. Sessions got shorter, which should raise
--      bounce under any honest definition
--   3. Instead the engaged flag became near-universal: the share
--      of sessions carrying it runs 57.45%, 54.16%, 90.75%
--   4. The pooled 32.82% is a blend of two measurement regimes.
--      Under the consistent November to December regime, bounce is
--      44.37%, or 107,253 of 241,752 sessions. January alone is
--      9.25%
--   5. Comparisons within a single month remain valid on any
--      definition, and the device, country and channel breakdowns
--      are unaffected because they pool all three months equally.
--      Only comparisons across time are broken
--   6. is_bounce_10sec is the definition that survives the window,
--      because it is derived from a continuously measured quantity
--      rather than a flag and it agrees in direction with
--      engagement time and engagement events
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 5: SESSION_ENGAGED COVERAGE (RAW TABLE)
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Go underneath the sessions table to find what changed
-- in January
-- ─────────────────────────────────────────────────────────────

SELECT
    FORMAT_DATE('%Y-%m', PARSE_DATE('%Y%m%d', event_date))              AS month,
    COUNT(*)                                                            AS events,
    COUNTIF((SELECT value.string_value FROM UNNEST(event_params)
             WHERE key = 'session_engaged') IS NOT NULL)                AS with_string_value,
    COUNTIF((SELECT value.int_value FROM UNNEST(event_params)
             WHERE key = 'session_engaged') IS NOT NULL)                AS with_int_value,
    COUNTIF((SELECT value.string_value FROM UNNEST(event_params)
             WHERE key = 'session_engaged') = '1')                      AS string_value_is_1,
    ROUND(100 * SAFE_DIVIDE(
        COUNTIF((SELECT value.string_value FROM UNNEST(event_params)
                 WHERE key = 'session_engaged') IS NOT NULL),
        COUNT(*)), 2)                                                   AS pct_string_coverage
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY month
ORDER BY month;

-- ── RESULT ───────────────────────────────────────────────────
-- month       events    with_string   with_int   flag='1'   coverage
-- 2020-11  1,472,712      1,294,236     88,966  1,081,400      87.88
-- 2020-12  1,612,725      1,384,044    115,423  1,141,570      85.82
-- 2021-01  1,210,147      1,004,641    109,002    887,280      83.02
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Parameter coverage does not explain the collapse. It
--      declines gently from 87.88% to 83.02%, and less coverage
--      raises bounce rather than lowering it
--   2. Flagged events as a share of all events are flat at 73.4%,
--      70.8% and 73.3%. The volume of engagement signal per event
--      did not change
--   3. What changed is its distribution across sessions. Flagged
--      events per engaged session run 17.4 in November, 15.8 in
--      December and 8.3 in January, while the share of sessions
--      carrying at least one flag jumps from 57.45% to 90.75%.
--      The same quantity of signal spread over roughly twice as
--      many sessions
--   4. That is a tracking configuration change in how the property
--      assigns session_engaged. The export gives no way to
--      identify which setting, and the honest statement is that
--      the metric changed rather than the visitors
--   5. Separately, 6% to 9% of events store session_engaged as an
--      integer and the table build reads only the string value.
--      See 00_data_quality_checks QUERY 7
-- ─────────────────────────────────────────────────────────────