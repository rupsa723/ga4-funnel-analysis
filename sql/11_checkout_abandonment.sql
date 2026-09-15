-- ══════════════════════════════════════════════════════════════
-- FILE:     11_checkout_abandonment.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     11 of 12 — what happens to the sessions that get
--           closest to buying?
-- FOLLOWS:  10_landing_page_analysis — a quarter of traffic lands
--           on pages that sell almost nothing
-- LEADS TO: 12_geography_analysis — the last dimension left to
--           test
-- SOURCE:   ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- The checkout sequence has an interior. add_shipping_info and
-- add_payment_info sit between begin_checkout and purchase, so a
-- session that started buying can be placed at the step where it
-- stopped rather than counted as one undifferentiated abandonment.
--
-- 15,188 sessions add something to a cart and 2,848 of those same
-- sessions order. The gap is the highest-intent traffic the store
-- loses inside a single visit, and it is small enough to describe
-- precisely rather than in percentages.
--
-- Every row here is a session, not a person. A visitor who
-- abandons on Tuesday and buys on Thursday appears as one
-- abandonment and one purchase, and 01_funnel_analysis QUERY 2
-- shows that pattern accounts for 2,000 of the 4,848 orders.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: WHERE CART SESSIONS STOP
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Place every session that reached a cart at its furthest
-- stage. The CASE runs in reverse order so each session lands in
-- exactly one band
-- ─────────────────────────────────────────────────────────────

WITH cart_sessions AS (
    SELECT * FROM `ga4_analysis.sessions` WHERE reached_cart = 1
),
totals AS (
    SELECT COUNT(*) AS t_cart FROM cart_sessions
)
SELECT
    CASE
        WHEN c.purchased = 1        THEN '5. Completed purchase'
        WHEN c.reached_payment = 1  THEN '4. Stopped after payment info'
        WHEN c.reached_shipping = 1 THEN '3. Stopped after shipping info'
        WHEN c.reached_checkout = 1 THEN '2. Stopped at checkout start'
        ELSE                             '1. Never started checkout'
    END                                                             AS furthest_stage,
    COUNT(*)                                                        AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNT(*), MAX(t.t_cart)), 2)            AS pct_of_cart_sessions,
    ROUND(AVG(c.page_views), 2)                                     AS avg_page_views,
    ROUND(AVG(c.total_engagement_msec) / 1000, 1)                   AS avg_engagement_sec,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(c.user_type = 'Returning'), COUNT(*)), 2) AS pct_returning
FROM cart_sessions c
CROSS JOIN totals t
GROUP BY furthest_stage
ORDER BY furthest_stage;

-- ── RESULT ───────────────────────────────────────────────────
-- furthest stage                  sessions   % of cart   pages   engage_s   %returning
-- 1. Never started checkout          9,226       60.75   11.30      322.8        39.84
-- 3. Stopped after shipping info     2,104       13.85   39.62      463.7        23.24
-- 4. Stopped after payment info      1,010        6.65   26.36      704.5        58.42
-- 5. Completed purchase              2,848       18.75   33.31      947.9        61.48
-- Total cart sessions               15,188
--
-- Band 2 returns no rows. Only two sessions fire begin_checkout
-- without add_shipping_info and neither stopped there
-- (01_funnel_analysis QUERY 3)
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. 60.75% of cart sessions never start checkout, three times
--      more common than any other stopping point
--   2. Those 9,226 sessions average 11.3 page views and 322.8
--      seconds. Five minutes of browsing is not accidental, so
--      this is deliberate cart-parking, and 01_funnel_analysis
--      QUERY 2 finds the other half of the behaviour in the 5,147
--      sessions that later begin checkout with nothing added
--   3. Engagement time rises monotonically with how far a session
--      gets: 322.8, 463.7, 704.5, 947.9 seconds. Buying at this
--      store takes about sixteen minutes of engaged time
--   4. The shipping-info stall is the most first-time-heavy group
--      on the table. Only 23.24% of those 2,104 sessions are
--      returning visitors, against 61.48% of completed purchases
--      and 58.42% of payment-stage stalls. New customers reach the
--      address form and stop
--   5. That group also has the highest page-view count of any
--      band, 39.62, with the second lowest engagement time. Heavy
--      navigation and little dwelling, ending at the point where
--      shipping cost and delivery date would appear. The export
--      carries neither, so what they saw there cannot be
--      established from this data
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: ABANDONERS BY CHANNEL AND DEVICE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: The last test of device, at the one step where a small
-- screen would plausibly cost something, alongside the channel
-- split
-- ─────────────────────────────────────────────────────────────

SELECT
    channel,
    device_category,
    COUNT(*)                                                        AS checkout_sessions,
    COUNTIF(purchased = 1)                                          AS completed,
    COUNTIF(purchased = 0)                                          AS abandoned,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 0), COUNT(*)), 2)   AS abandonment_pct,
    ROUND(AVG(IF(purchased = 0, total_engagement_msec, NULL)) / 1000, 1) AS abandoner_engagement_sec,
    ROUND(AVG(IF(purchased = 1, total_engagement_msec, NULL)) / 1000, 1) AS purchaser_engagement_sec
FROM `ga4_analysis.sessions`
WHERE reached_checkout = 1
GROUP BY channel, device_category
HAVING COUNT(*) >= 100
ORDER BY checkout_sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- channel         device    checkout  done  abandoned  abandon%  aband_s  purch_s
-- Google Organic  desktop      2,364   906      1,458     61.68    505.3    868.5
-- Google Organic  mobile       1,681   670      1,011     60.14    535.7    818.5
-- Self-Referral   desktop      1,501   836        665     44.30    511.3    859.5
-- Self-Referral   mobile       1,097   623        474     43.21    538.5    852.3
-- Referral        desktop      1,001   552        449     44.86    586.0    889.8
-- Referral        mobile         701   419        282     40.23    613.9    935.9
-- Direct          desktop        660   183        477     72.27    514.7    903.7
-- Other           desktop        539   116        423     78.48    503.0    970.8
-- Direct          mobile         444   126        318     71.62    486.5    861.6
-- Other           mobile         354    74        280     79.10    474.2    790.5
-- Obfuscated      desktop        216   122         94     43.52    565.0  1,005.8
-- Obfuscated      mobile        127     67         60     47.24    530.2    813.2
-- Google Paid     desktop        109    32         77     70.64    481.7    804.6
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Device does not matter at checkout either. Within every
--      channel, desktop and mobile abandonment differ by under two
--      percentage points, except Referral where mobile is better
--      (40.23% against 44.86%) and Obfuscated where it is worse on
--      127 sessions. This was the last place a mobile experience
--      finding could have survived
--   2. Channel abandonment splits into three tiers regardless of
--      device: 43-47% for Self-Referral, Referral and Obfuscated;
--      60-62% for Google Organic; 70-79% for Direct, Other and
--      Google Paid
--   3. Abandoners engage for 470 to 615 seconds and purchasers for
--      790 to 1,006 seconds, and both ranges hold across every
--      channel. Whatever separates the tiers, it is not that
--      abandoners in weak channels give up faster
--   4. Direct and Other abandon at over 70% while their abandoners
--      engage as long as anyone else's, which is the shape of a
--      decision rather than a distraction. It is also the same
--      grouping 06_funnel_by_channel QUERY 2 finds losing two
--      thirds of checkout sessions before payment, where session
--      fragmentation is the better-supported of the two available
--      explanations
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: ABANDONERS VERSUS PURCHASERS
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: A behavioural profile of the two groups inside checkout
-- traffic
-- ─────────────────────────────────────────────────────────────

SELECT
    IF(purchased = 1, 'Purchased', 'Abandoned')                 AS outcome,
    COUNT(*)                                                    AS sessions,
    ROUND(AVG(total_events), 2)                                 AS avg_events,
    ROUND(AVG(page_views), 2)                                   AS avg_page_views,
    ROUND(AVG(total_engagement_msec) / 1000, 1)                 AS avg_engagement_sec,
    ROUND(AVG(engagement_events), 2)                            AS avg_engagement_events,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(user_type = 'Returning'), COUNT(*)), 2) AS pct_returning,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(channel = 'Unknown'), COUNT(*)), 2)     AS pct_unattributed
FROM `ga4_analysis.sessions`
WHERE reached_checkout = 1
GROUP BY outcome
ORDER BY outcome;

-- ── RESULT ───────────────────────────────────────────────────
--                         Abandoned   Purchased
-- sessions                    6,261       4,845
-- avg_events                 102.74      107.32
-- avg_page_views              35.08       30.97
-- avg_engagement_sec          523.1       869.7
-- avg_engagement_events       33.47       28.71
-- pct_returning               34.44       64.17
-- pct_unattributed             0.06        0.02
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Abandoners view more pages than purchasers, 35.08 against
--      30.97, and fire more engagement events, 33.47 against
--      28.71, while spending 40% less engaged time, 523 seconds
--      against 870. More clicking and less reading
--   2. Total events are almost identical, 102.74 against 107.32,
--      so both groups do a similar amount at the store. The
--      difference is how long they spend doing it
--   3. Returning share is the sharpest divider: 64.17% of
--      purchasers against 34.44% of abandoners. A checkout session
--      by a repeat visitor is roughly twice as likely to complete,
--      the same effect 08_new_vs_returning measures across all
--      traffic
--   4. Checkout traffic is 99.94% attributed. Unattributed
--      sessions essentially never reach checkout, which
--      independently confirms 00 QUERY 4: the Unknown bucket is
--      near-empty sessions rather than a slice of real shoppers
--   5. Cart contents for abandoned sessions are not recoverable.
--      The items table is built from purchase events, so a cart
--      never bought has no line items and abandoned basket value
--      cannot be computed from this export
-- ─────────────────────────────────────────────────────────────