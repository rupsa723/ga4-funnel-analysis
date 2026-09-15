-- ══════════════════════════════════════════════════════════════
-- FILE:     08_new_vs_returning.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     8 of 12 — does visit history explain anything?
-- FOLLOWS:  07_revenue_by_device — device explains nothing on any
--           commercial measure
-- LEADS TO: 09_product_analysis — what the converting sessions
--           actually bought
-- SOURCE:   ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- user_type is set from the first_visit event: a session that
-- fired first_visit is New, everything else is Returning. This is
-- read from the event rather than inferred. Counting sessions per
-- user_pseudo_id would produce a similar split, but it infers
-- newness from session count instead of taking it from the event
-- that records it, and the two disagree whenever a session is
-- split or a cookie is cleared.
--
-- user_pseudo_id is a cookie, so a visitor who clears cookies or
-- switches browser or device appears as new, and Returning
-- undercounts genuine repeat visitors. The window is 92 days, so a
-- customer who last bought in September registers as new.
--
-- QUERY 1 compares the two groups. QUERY 2 removes the
-- unattributed bucket to test one explanation of a contradiction
-- in QUERY 1. QUERY 3 replaces the binary split with a graded one.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: NEW VERSUS RETURNING
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Volume, revenue, conversion, engagement and funnel
-- progression for both groups
-- ─────────────────────────────────────────────────────────────

WITH totals AS (
    SELECT COUNT(*) AS t_sessions, SUM(revenue) AS t_revenue
    FROM `ga4_analysis.sessions`
)
SELECT
    s.user_type,
    COUNT(*)                                                            AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNT(*), MAX(t.t_sessions)), 2)            AS pct_of_sessions,
    COUNTIF(s.purchased = 1)                                            AS purchases,
    ROUND(SUM(s.revenue), 2)                                            AS revenue,
    ROUND(100 * SAFE_DIVIDE(SUM(s.revenue), MAX(t.t_revenue)), 2)       AS pct_of_revenue,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.purchased = 1), COUNT(*)), 2)     AS cvr_pct,
    ROUND(SAFE_DIVIDE(SUM(s.revenue), COUNTIF(s.purchased = 1)), 2)     AS aov,
    ROUND(SAFE_DIVIDE(SUM(s.revenue), COUNT(*)), 2)                     AS rev_per_session,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.is_bounce_ga4 = 1), COUNT(*)), 2) AS bounce_ga4_pct,
    ROUND(AVG(s.page_views), 2)                                         AS avg_page_views,
    ROUND(AVG(s.total_engagement_msec) / 1000, 1)                       AS avg_engagement_sec,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.reached_view_item = 1), COUNT(*)), 2) AS pct_view_item,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(s.reached_checkout = 1), COUNT(*)), 2)  AS pct_checkout,
    COUNT(DISTINCT s.user_pseudo_id)                                    AS distinct_users,
    ROUND(SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT s.user_pseudo_id)), 2)   AS sessions_per_user
FROM `ga4_analysis.sessions` s
CROSS JOIN totals t
GROUP BY s.user_type
ORDER BY sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
--                        New       Returning
-- sessions           257,400         102,729
-- pct_of_sessions      71.47           28.53
-- purchases            1,736           3,112
-- revenue           $117,801        $244,364
-- pct_of_revenue       32.53           67.47
-- cvr_pct               0.67            3.03
-- aov                 $67.86          $78.52
-- rev_per_session      $0.46           $2.38
-- bounce_ga4_pct       29.55           41.00
-- avg_page_views        3.56            4.22
-- avg_engagement_sec    60.0            96.2
-- pct_view_item        19.80           25.36
-- pct_checkout          2.27            5.13
-- distinct_users     257,314          54,652
-- sessions_per_user     1.00            1.88
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Visit history explains more than device or country did.
--      Returning sessions are 28.53% of traffic and 67.47% of
--      revenue, converting at 3.03% against 0.67% and worth $2.38
--      per session against $0.46
--   2. They also spend more per order, $78.52 against $67.86, so
--      the advantage is not only frequency
--   3. They reach checkout at 5.13% against 2.27%, so the
--      advantage builds through the funnel rather than appearing
--      only at the order
--   4. 54,652 returning users generated 102,729 sessions, 1.88
--      each. New sessions are 1.00 per user by definition
--   5. One figure contradicts the rest: returning sessions bounce
--      at 41.00% against 29.55%, while viewing more pages,
--      engaging longer and converting 4.5 times better. QUERY 2
--      tests whether that is an attribution artefact
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: THE SAME COMPARISON ON ATTRIBUTED SESSIONS ONLY
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Remove the unattributed bucket from both groups. If the
-- bounce inversion disappears, it was an artefact of where the
-- attribution gap falls
-- ─────────────────────────────────────────────────────────────

SELECT
    user_type,
    COUNT(*)                                                            AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2)   AS bounce_ga4_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_10sec = 1), COUNT(*)), 2) AS bounce_10sec_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)       AS cvr_pct,
    ROUND(AVG(page_views), 2)                                           AS avg_page_views,
    ROUND(AVG(total_engagement_msec) / 1000, 1)                         AS avg_engagement_sec,
    ROUND(SUM(revenue), 2)                                              AS revenue
FROM `ga4_analysis.sessions`
WHERE channel != 'Unknown'
GROUP BY user_type
ORDER BY sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
--                        New       Returning
-- sessions           183,669          81,142
-- bounce_ga4_pct       24.86           36.23
-- bounce_10sec_pct     43.12           48.59
-- cvr_pct               0.94            3.84
-- avg_page_views        4.34            5.04
-- avg_engagement_sec    79.8           118.1
-- revenue           $117,789        $244,364
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. The inversion survives. Returning still bounces 11.4 points
--      higher once unattributed sessions are removed from both
--      groups, and the ten-second definition agrees in direction,
--      48.59% against 43.12%
--   2. So it is not an attribution artefact.
--      04_bounce_rate_by_channel QUERY 3 shows why: 37,356 of the
--      102,729 returning sessions are Self-Referral, which bounce
--      at 39.25% and convert at 3.60% simultaneously. That is two
--      populations averaged together, produced by the hostname
--      splitting described in 02 QUERY 3. The opening fragment
--      ends immediately, the continuation carries the order, and
--      both are labelled Returning
--   3. On attributed sessions the conversion gap widens to 0.94%
--      against 3.84%, and returning sessions average 118.1 seconds
--      against 79.8. Every engagement measure except bounce
--      favours returning visitors
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: VALUE BY SESSION COUNT
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Replace the binary split with a graded one, to see
-- whether value accumulates with each return or concentrates in a
-- small group of frequent visitors
-- ─────────────────────────────────────────────────────────────

WITH user_sessions AS (
    SELECT
        user_pseudo_id,
        COUNT(*)                AS session_count,
        SUM(revenue)            AS user_revenue,
        COUNTIF(purchased = 1)  AS user_purchases
    FROM `ga4_analysis.sessions`
    GROUP BY user_pseudo_id
)
SELECT
    CASE
        WHEN session_count = 1               THEN '1 session'
        WHEN session_count = 2               THEN '2 sessions'
        WHEN session_count BETWEEN 3 AND 5   THEN '3-5 sessions'
        WHEN session_count BETWEEN 6 AND 10  THEN '6-10 sessions'
        ELSE '11+ sessions'
    END                                                AS session_band,
    COUNT(*)                                           AS users,
    SUM(session_count)                                 AS sessions,
    SUM(user_purchases)                                AS purchases,
    ROUND(SUM(user_revenue), 2)                        AS revenue,
    ROUND(SAFE_DIVIDE(SUM(user_revenue), COUNT(*)), 2) AS revenue_per_user,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(user_purchases > 0), COUNT(*)), 2) AS pct_users_who_bought
FROM user_sessions
GROUP BY session_band
ORDER BY MIN(session_count);

-- ── RESULT ───────────────────────────────────────────────────
-- band            users   sessions   purch    revenue  rev/user  % bought
-- 1 session     222,790    222,790   1,078    $64,364     $0.29      0.48
-- 2 sessions     29,536     59,072     938    $63,840     $2.16      3.10
-- 3-5 sessions   14,247     50,768   1,696   $130,562     $9.16     10.75
-- 6-10 sessions   3,226     23,446   1,000    $89,588    $27.77     24.46
-- 11+ sessions      355      4,053     136    $13,811    $38.90     29.30
-- TOTAL         270,154    360,129   4,848   $362,165     $1.34      1.79
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Revenue per user rises from $0.29 to $38.90 across the
--      bands, a 134-fold increase, and does not plateau. The curve
--      decelerates but never flattens
--   2. The largest single step is the second visit. Users who come
--      back once are 6.5 times more likely to buy, 3.10% against
--      0.48%, and worth 7.4 times as much, $2.16 against $0.29.
--      No later increment comes close to that multiple
--   3. 47,364 users, 17.5% of the base, had more than one session.
--      They account for 38.1% of sessions, 77.8% of orders and
--      82.2% of revenue
--   4. The 3 to 5 session band is the commercial core: 14,247
--      users, 5.3% of the base, generating $130,562 or 36.0% of
--      revenue
--   5. 82.5% of users visit once, buy at 0.48% and produce 17.8%
--      of revenue
--   6. This is the same fact 01_funnel_analysis QUERY 2 found from
--      the session side, where 41.3% of orders came from sessions
--      that skipped an earlier stage. Buying at this store is
--      normally a multi-session process, so a session-level funnel
--      measures a two-visit job one visit at a time and will
--      always understate it
-- ─────────────────────────────────────────────────────────────