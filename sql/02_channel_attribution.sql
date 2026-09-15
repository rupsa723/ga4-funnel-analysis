-- ══════════════════════════════════════════════════════════════
-- FILE:     02_channel_attribution.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     2 of 12 — where does the traffic come from?
-- FOLLOWS:  01_funnel_analysis — 1.35% of sessions order, and the
--           losses are concentrated before checkout
-- LEADS TO: 03_bounce_rate — whether that traffic engages at all
-- SOURCE:   ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- Channel is derived in the table build with a CASE over
-- session_source and session_medium, taken from the first non-null
-- source across the session's events. 00 QUERY 5 established why:
-- session_start carries no source in this export, so first-event
-- attribution is not available.
--
-- QUERY 1 ranks the channels. QUERY 2 removes the unattributed
-- bucket so channels are compared on a clean base. QUERY 3 opens
-- the CASE statement and shows what each label is actually made
-- of, which changes how the largest revenue line in QUERY 1 should
-- be read.
--
-- No cost data exists in GA4 exports, so return on ad spend cannot
-- be computed anywhere in this project. Efficiency here means
-- revenue per session.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: CHANNEL PERFORMANCE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Volume, revenue, conversion, order value and engagement
-- for every channel. Percentages come from a totals CTE rather
-- than a window function over a ROLLUP, which would count the
-- total row as an extra group and halve every share
-- ─────────────────────────────────────────────────────────────

WITH totals AS (
    SELECT
        COUNT(*)     AS t_sessions,
        SUM(revenue) AS t_revenue
    FROM `ga4_analysis.sessions`
)
SELECT
    s.channel,
    COUNT(*)                                                            AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNT(*), MAX(t.t_sessions)), 2)            AS pct_of_sessions,
    COUNTIF(s.purchased = 1)                                            AS purchases,
    ROUND(SUM(s.revenue), 2)                                            AS revenue,
    ROUND(100 * SAFE_DIVIDE(SUM(s.revenue), MAX(t.t_revenue)), 2)       AS pct_of_revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.purchased = 1), COUNT(*)), 2)     AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(s.revenue), COUNTIF(s.purchased = 1)), 2)     AS aov,
    ROUND(SAFE_DIVIDE(SUM(s.revenue), COUNT(*)), 2)                     AS rev_per_session,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.is_bounce_ga4 = 1), COUNT(*)), 2) AS bounce_pct,
    ROUND(AVG(s.page_views), 2)                                         AS avg_page_views,
    ROUND(AVG(s.total_engagement_msec) / 1000, 1)                       AS avg_engagement_sec,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.reached_view_item = 1), COUNT(*)), 2) AS pct_view_item
FROM `ga4_analysis.sessions` s
CROSS JOIN totals t
GROUP BY s.channel
ORDER BY revenue DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- channel          sessions  %sess  purch    revenue  %rev   CVR    AOV   rev/sess  bounce  pages  engage_s
-- Self-Referral      61,375  17.04  1,495  $120,125  33.17  2.44  80.35     1.96   27.42   4.98    111.4
-- Google Organic     96,345  26.75  1,604  $112,902  31.17  1.66  70.39     1.17   25.24   4.45     84.7
-- Referral           22,396   6.22    994   $74,411  20.55  4.44  74.86     3.32   25.05   5.97    132.7
-- Direct             37,839  10.51    315   $24,599   6.79  0.83  78.09     0.65   33.60   4.04     75.0
-- Other              32,790   9.11    197   $13,850   3.82  0.60  70.30     0.42   31.25   3.93     69.7
-- Obfuscated          6,394   1.78    195   $13,119   3.62  3.05  67.28     2.05   44.24   4.29     98.9
-- Google Paid         7,672   2.13     47    $3,147   0.87  0.61  66.96     0.41   32.83   3.80     66.5
-- Unknown            95,318  26.47      1       $12   0.00  0.00  12.00     0.00   45.25   1.51     11.5
-- ALL               360,129 100.00  4,848  $362,165 100.00  1.35  74.70     1.01   32.82   3.75     70.3
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Referral is the most efficient traffic in the dataset:
--      4.44% conversion and $3.32 per session against a $1.01
--      average, on 6.22% of sessions, with the highest engagement
--      of any channel at 132.7 seconds
--   2. Google Organic is the largest source by sessions, 96,345,
--      and returns $112,902 at 1.66% conversion
--   3. Google Paid is weakest on every measure: 0.61% conversion,
--      $0.41 per session, 47 orders across three months. Without
--      cost data this says paid sessions convert worse than
--      organic ones; it does not say the campaign lost money
--   4. Direct converts at 0.83%, below the site average, which is
--      the reverse of the usual pattern where direct traffic
--      carries returning intent
--   5. Obfuscated is Google's privacy masking applied to real
--      sources. It converts at 3.05%, so masked traffic behaves
--      like normal traffic and is not noise
--   6. Self-Referral leads on revenue. QUERY 3 shows it is not an
--      acquisition channel
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: ATTRIBUTED SESSIONS ONLY
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: The same table with Unknown removed. 00 QUERY 4
-- established that unattributed sessions are near-empty rather
-- than a biased sample, so this is the correct base for comparing
-- channels against each other
-- ─────────────────────────────────────────────────────────────

WITH attributed AS (
    SELECT * FROM `ga4_analysis.sessions` WHERE channel != 'Unknown'
),
totals AS (
    SELECT COUNT(*) AS t_sessions, SUM(revenue) AS t_revenue FROM attributed
)
SELECT
    a.channel,
    COUNT(*)                                                        AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNT(*), MAX(t.t_sessions)), 2)        AS pct_of_attributed,
    COUNTIF(a.purchased = 1)                                        AS purchases,
    ROUND(SUM(a.revenue), 2)                                        AS revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(a.purchased = 1), COUNT(*)), 2) AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(a.revenue), COUNT(*)), 2)                 AS rev_per_session
FROM attributed a
CROSS JOIN totals t
GROUP BY a.channel
ORDER BY revenue DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- Base: 264,811 sessions, $362,153, 4,847 purchases, 1.83% CVR
--
-- channel          sessions  %attrib  purch    revenue   CVR   rev/sess
-- Self-Referral      61,375    23.18  1,495  $120,125  2.44      1.96
-- Google Organic     96,345    36.38  1,604  $112,902  1.66      1.17
-- Referral           22,396     8.46    994   $74,411  4.44      3.32
-- Direct             37,839    14.29    315   $24,599  0.83      0.65
-- Other              32,790    12.38    197   $13,850  0.60      0.42
-- Obfuscated          6,394     2.41    195   $13,119  3.05      2.05
-- Google Paid         7,672     2.90     47    $3,147  0.61      0.41
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   Removing the unattributed bucket changes no channel's own
--   conversion rate, because the bucket contributed one order.
--   What it changes is the base: 1.83% is the conversion rate
--   among sessions that could be attributed, against 1.35% across
--   all measured traffic. The ranking of channels is identical
--   either way, which is what makes the comparison safe despite
--   26.47% missing attribution.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: RAW SOURCE AND MEDIUM BEHIND THE MAPPING
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Open the CASE statement. Shows what each channel label
-- collapses, whether the catch-all buckets hide anything worth
-- naming, and whether the labels mean what they appear to mean
-- ─────────────────────────────────────────────────────────────

SELECT
    channel,
    IFNULL(session_source, '(null)') AS session_source,
    IFNULL(session_medium, '(null)') AS session_medium,
    COUNT(*)                         AS sessions,
    COUNTIF(purchased = 1)           AS purchases,
    ROUND(SUM(revenue), 2)           AS revenue
FROM `ga4_analysis.sessions`
GROUP BY channel, session_source, session_medium
HAVING COUNT(*) >= 100
ORDER BY channel, sessions DESC;

-- ── RESULT (rows with 100+ sessions) ─────────────────────────
-- channel         source                            medium      sessions  purch   revenue
-- Direct          (direct)                          (none)        37,786    306   $23,562
-- Google Organic  google                            organic       95,244  1,580  $111,022
-- Google Organic  shop.googlemerchandisestore.com   organic        1,086     24    $1,880
-- Google Paid     google                            cpc            7,672     47    $3,147
-- Obfuscated      (data deleted)                    (data del.)    6,343    190   $12,871
-- Other           <Other>                           <Other>       25,327    125    $8,726
-- Other           <Other>                           organic        4,845     34    $2,262
-- Other           Partners                          affiliate      1,329      2      $167
-- Other           baidu                             organic          696      0        $0
-- Other           bing                              organic          198      8      $629
-- Other           Newsletter_January_2021           email            106      3       $78
-- Other           <Other>                           (data deleted)   100      3      $183
-- Referral        <Other>                           referral      20,381    978   $73,672
-- Referral        creatoracademy.youtube.com        referral         886      2       $34
-- Referral        perksatwork.com                   referral         226     11      $617
-- Referral        coursera.org                      referral         207      0        $0
-- Referral        l.facebook.com                    referral         111      1       $16
-- Self-Referral   shop.googlemerchandisestore.com   referral      52,397  1,332  $109,218
-- Self-Referral   googlemerchandisestore.com        referral       4,095     95    $7,029
-- Self-Referral   analytics.google.com              referral       3,412      1        $0
-- Self-Referral   sites.google.com                  referral         417     28    $1,774
-- Self-Referral   support.google.com                referral         360      2      $122
-- Self-Referral   mail.google.com                   referral         156     22      $993
-- Self-Referral   googleads.g.doubleclick.net       referral         122      0        $0
-- Unknown         (null)                            (null)        94,553      1       $12
-- Unknown         (null)                            organic          756      0        $0
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--
-- SELF-REFERRAL IS NOT AN ACQUISITION CHANNEL
--   1. 56,492 of 61,375 Self-Referral sessions, 92.05%, come from
--      the store's own two hostnames,
--      shop.googlemerchandisestore.com and
--      googlemerchandisestore.com. Those sessions carry $116,247,
--      which is 96.77% of the channel's revenue and 32.1% of all
--      revenue in the dataset
--   2. Genuinely external Google properties account for 933
--      sessions and $2,889: sites.google.com, support.google.com
--      and mail.google.com. A further 3,412 sessions come from
--      analytics.google.com with one order and $0, which is people
--      arriving from the Analytics demo account rather than
--      shoppers
--   3. The mechanism is cross-host session splitting. When a visit
--      crosses a host boundary and the hosts are not configured as
--      one property, the session ends and a new one begins,
--      credited to the previous host as a referral
--   4. A high conversion rate is not evidence against this. A
--      split cuts a journey in the middle, so the second fragment
--      begins close to checkout and converts unusually well. The
--      2.44% conversion rate is the signature of fragmentation,
--      not a defence against it
--   5. Four other results in this project fit only this
--      explanation: 10_landing_page_analysis QUERY 3 collapses six
--      URLs into one homepage path covering 161,673 sessions;
--      06_funnel_by_channel QUERY 2 shows Self-Referral converting
--      76.48% from checkout to payment against 40.16% for Direct;
--      01_funnel_analysis QUERY 2 finds 5,147 sessions beginning
--      checkout with no cart; 12_geography_analysis QUERY 3 shows
--      Self-Referral holding between 15.99% and 17.50% of sessions
--      in all eight largest markets, which no real acquisition
--      channel does
--   6. Consequence for the channel ranking: $120,125, one third of
--      all revenue, was earned by whatever source originally
--      brought the visitor in, and this export cannot trace it
--      back. Combined with the 26.47% of sessions carrying no
--      source at all, attribution covers less of this store's
--      revenue than QUERY 1 suggests
--
-- THE OTHER LABELS
--   7. 'Other' is dominated by <Other>, Google's own bucketing of
--      long-tail sources inside this public dataset, so it cannot
--      be decomposed further. The named sources inside it are
--      small and weak: Partners affiliate sends 1,329 sessions and
--      2 orders, baidu 696 sessions and none, bing 198 and 8, a
--      January newsletter 106 and 3
--   8. Referral is also mostly <Other>, 20,381 sessions carrying
--      978 of its 994 orders. Its 4.44% conversion rate is a
--      property of an unnamed long tail, so nothing specific can
--      be said about which referrers work
--   9. Google Organic includes 1,086 sessions whose source is the
--      shop hostname with medium 'organic'. The same hostname
--      issue reaches into a second channel
--  10. Unknown is 94,553 sessions with both fields null. A further
--      756 have medium 'organic' and no source; the CASE checks
--      source first and never reaches a medium-only branch, so
--      those are mislabelled. It moves 0.2% of sessions
-- ─────────────────────────────────────────────────────────────