-- ══════════════════════════════════════════════════════════════
-- FILE:     04_bounce_rate_by_channel.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     4 of 12 — does the traffic source explain engagement?
-- FOLLOWS:  03_bounce_rate — device and country both fail to
--           explain bounce, and the metric is unstable over time
-- LEADS TO: 05_monthly_trend — how the whole picture moves across
--           the window
-- SOURCE:   ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- Two dimensions have already been ruled out. This tests the
-- third, and it is the one that works.
--
-- Bounce by channel is only worth charting if bounced sessions can
-- be attributed. Where coverage is poor the chart collapses into a
-- single Unknown bar and restates the attribution gap rather than
-- saying anything about channels. Here 63.51% of bounced sessions
-- carry a channel, which is enough. One caveat stands: bounced
-- sessions are shorter than average and short sessions are less
-- likely to have picked up a source, so attributed bounced
-- sessions are not a random sample of all bounced sessions.
--
-- QUERY 1 takes the rate view, QUERY 2 the volume view, QUERY 3
-- crosses channel with visit history to resolve a contradiction
-- that surfaces in 08.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: BOUNCE RATE WITHIN EACH CHANNEL
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Of the traffic attributed to each channel, what share
-- left without engaging. All three definitions, to test whether
-- the ranking is a property of the traffic or of the metric
-- ─────────────────────────────────────────────────────────────

SELECT
    channel,
    COUNT(*)                                                               AS sessions,
    COUNTIF(is_bounce_ga4 = 1)                                             AS bounced,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2)      AS bounce_ga4_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_pageview = 1), COUNT(*)), 2) AS bounce_pageview_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_10sec = 1), COUNT(*)), 2)    AS bounce_10sec_pct,
    ROUND(AVG(page_views), 2)                                              AS avg_page_views,
    ROUND(AVG(total_engagement_msec) / 1000, 1)                            AS avg_engagement_sec,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)          AS cvr_pct
FROM `ga4_analysis.sessions`
GROUP BY channel
ORDER BY sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- channel          sessions  bounced    ga4  pageview   10sec  pages  engage_s   CVR
-- Google Organic     96,345   24,317  25.24      9.46   46.86   4.45      84.7  1.66
-- Unknown            95,318   43,131  45.25     28.51   77.99   1.51      11.5  0.00
-- Self-Referral      61,375   16,828  27.42      6.82   37.58   4.98     111.4  2.44
-- Direct             37,839   12,714  33.60     12.80   48.67   4.04      75.0  0.83
-- Other              32,790   10,248  31.25     12.24   48.49   3.93      69.7  0.60
-- Referral           22,396    5,611  25.05      9.44   38.90   5.97     132.7  4.44
-- Google Paid         7,672    2,519  32.83     13.30   48.46   3.80      66.5  0.61
-- Obfuscated          6,394    2,829  44.24     10.12   57.30   4.29      98.9  3.05
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Source explains engagement where device and country did
--      not. Bounce varies by 20 percentage points across channels,
--      from 25.05% for Referral to 45.25% for Unknown, against a
--      0.26pp spread across devices and 2.66pp across countries
--   2. The ranking holds across all three definitions for every
--      channel except Obfuscated. Referral, Google Organic and
--      Self-Referral are lowest on all three; Direct, Other and
--      Google Paid sit in the middle on all three
--   3. Obfuscated is the exception and it is informative. It ranks
--      second worst on the GA4 definition, second best on the
--      page-view definition, mid-pack on the ten-second
--      definition, and converts at 3.05% with 98.9 seconds of
--      engagement. A bucket that reorders itself depending on the
--      definition is a mixture of unrelated masked sources rather
--      than a channel with behaviour of its own
--   4. Google Paid bounces at 32.83%, close to the site average,
--      and converts at 0.61%. Its traffic engages normally and
--      then does not buy, which locates the problem after arrival
--      rather than at it
--   5. Unknown at 45.25% with 1.51 page views is the attribution
--      gap showing through, not a channel result
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: WHAT THE BOUNCED POPULATION IS MADE OF
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: The inverse cut. QUERY 1 asks how much of each channel
-- bounces; this asks which channels the bounced sessions came
-- from. A channel with a low rate can still be the largest single
-- source of bounces if it is large enough
-- ─────────────────────────────────────────────────────────────

WITH bounced AS (
    SELECT * FROM `ga4_analysis.sessions` WHERE is_bounce_ga4 = 1
),
totals AS (
    SELECT COUNT(*) AS t_bounced FROM bounced
)
SELECT
    b.channel,
    COUNT(*)                                                    AS bounced_sessions,
    ROUND(100 * SAFE_DIVIDE(COUNT(*), MAX(t.t_bounced)), 2)     AS pct_of_all_bounces
FROM bounced b
CROSS JOIN totals t
GROUP BY b.channel
ORDER BY bounced_sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- Base: 118,197 bounced sessions, 32.82% of 360,129
--
-- channel          bounced_sessions   % of all bounces
-- Unknown                    43,131              36.49
-- Google Organic             24,317              20.57
-- Self-Referral              16,828              14.24
-- Direct                     12,714              10.76
-- Other                      10,248               8.67
-- Referral                    5,611               4.75
-- Obfuscated                  2,829               2.39
-- Google Paid                 2,519               2.13
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. 63.51% of bounced sessions carry a channel, so this chart
--      describes channels rather than restating the attribution
--      gap
--   2. Google Organic has the lowest bounce rate of any large
--      channel at 25.24% and is still the second largest source of
--      bounced sessions at 24,317, because it is the largest
--      channel. Rate and volume answer different questions
--   3. Google Paid contributes 2.13% of all bounces. Removing its
--      bounce entirely would move the site rate by under one
--      percentage point, so its weakness is a conversion problem
--      rather than an engagement one
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: CHANNEL BY USER TYPE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: 08_new_vs_returning finds returning sessions bouncing
-- more than new ones while converting 4.5 times better. Two
-- explanations are possible: unattributed sessions concentrated
-- among returning users, or something real. This separates them
-- ─────────────────────────────────────────────────────────────

SELECT
    user_type,
    channel,
    COUNT(*)                                                          AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2) AS bounce_ga4_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)     AS cvr_pct,
    ROUND(AVG(page_views), 2)                                         AS avg_page_views,
    ROUND(SUM(revenue), 2)                                            AS revenue
FROM `ga4_analysis.sessions`
GROUP BY user_type, channel
ORDER BY user_type, sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- user_type  channel          sessions   bounce    CVR   pages    revenue
-- New        Google Organic     76,063    24.08   1.14    4.22    $57,363
-- New        Unknown            73,731    41.24   0.00    1.62        $12
-- New        Direct             31,480    31.52   0.43    4.03     $9,167
-- New        Other              29,621    30.29   0.34    3.89     $6,622
-- New        Self-Referral      24,019     9.01   0.62    5.32     $8,330
-- New        Referral           15,228    25.94   2.97    5.24    $33,959
-- New        Google Paid         7,236    32.21   0.46    3.75     $2,348
-- New        Obfuscated             22    27.27   0.00    4.27         $0
-- Returning  Self-Referral      37,356    39.25   3.60    4.76   $111,795
-- Returning  Unknown            21,587    58.93   0.00    1.14         $0
-- Returning  Google Organic     20,282    29.59   3.64    5.33    $55,539
-- Returning  Referral            7,168    23.17   7.56    7.52    $40,452
-- Returning  Obfuscated          6,372    44.30   3.06    4.29    $13,119
-- Returning  Direct              6,359    43.87   2.83    4.09    $15,432
-- Returning  Other               3,169    40.23   3.03    4.28     $7,228
-- Returning  Google Paid           436    43.12   3.21    4.48       $799
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. The attribution explanation fails. 73,731 of the 95,318
--      unattributed sessions are New, so Unknown is 28.6% of new
--      sessions and 21.0% of returning ones. If anything it is
--      more common among first-time visitors
--   2. The inversion is concentrated in specific channels rather
--      than spread evenly. New Self-Referral bounces at 9.01%, the
--      lowest figure anywhere in the dataset; Returning
--      Self-Referral bounces at 39.25% while converting at 3.60%
--      and carrying $111,795. Direct shows the same shape, 31.52%
--      for New against 43.87% for Returning
--   3. High bounce and high conversion inside one cell is two
--      populations averaged together. It matches the mechanism in
--      02_channel_attribution QUERY 3: sessions split across the
--      store's hostnames, where the opening fragment ends
--      immediately and the continuation carries the order, and
--      both are labelled Returning because first_visit fired
--      earlier
--   4. Obfuscated is 6,372 returning sessions against 22 new ones.
--      Google's privacy masking in this dataset falls almost
--      entirely on repeat visitors, which is a property of the
--      export rather than a fact about behaviour
--   5. Referral is the one channel that behaves conventionally on
--      both sides: New converts at 2.97% and Returning at 7.56%,
--      with bounce lower for returning (23.17%) than new (25.94%)
-- ─────────────────────────────────────────────────────────────