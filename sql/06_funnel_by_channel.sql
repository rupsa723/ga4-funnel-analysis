-- ══════════════════════════════════════════════════════════════
-- FILE:     06_funnel_by_channel.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     6 of 12 — does the traffic source explain where the
--           funnel leaks?
-- FOLLOWS:  05_monthly_trend — the shape of the window, and a
--           revenue defect in its final week
-- LEADS TO: 07_revenue_by_device — the same test applied to
--           hardware
-- SOURCE:   ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- 01_funnel_analysis measured a whole-site funnel across traffic
-- of very different quality. 04 established that source predicts
-- engagement. This tests whether it also predicts where sessions
-- stop.
--
-- Unknown is excluded throughout. Those sessions average 1.51 page
-- views, so including them would flatten every comparison against
-- a bucket that is definitionally short.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: FUNNEL STAGE REACH BY CHANNEL
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Cumulative reach at each stage, against each channel's
-- own session count so channels of different size are comparable
-- ─────────────────────────────────────────────────────────────

SELECT
    channel,
    COUNT(*)                                                                  AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_view_item = 1), COUNT(*)), 2)     AS pct_view_item,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_cart = 1), COUNT(*)), 2)          AS pct_cart,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_checkout = 1), COUNT(*)), 2)      AS pct_checkout,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_payment = 1), COUNT(*)), 2)       AS pct_payment,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)             AS pct_purchase
FROM `ga4_analysis.sessions`
WHERE channel != 'Unknown'
GROUP BY channel
ORDER BY sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- channel          sessions   view    cart   checkout   payment   purchase
-- Google Organic     96,345  26.84    5.17       4.29      2.45       1.66
-- Self-Referral      61,375  29.97    6.58       4.33      3.31       2.44
-- Direct             37,839  22.81    4.24       2.98      1.20       0.83
-- Other              32,790  21.83    3.84       2.79      0.95       0.60
-- Referral           22,396  32.81    9.05       7.77      5.89       4.44
-- Google Paid         7,672  21.58    3.53       2.35      0.83       0.61
-- Obfuscated          6,394  23.91    6.66       5.49      4.27       3.05
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Referral leads at every stage. It is 1.5 times the site
--      average on product views, 32.81% against 21.39%, and 3.3
--      times on orders, 4.44% against 1.35%. Its advantage
--      compounds rather than sitting in one step
--   2. Google Paid and Other are nearly identical in the top half,
--      21.58% and 21.83% product views, and separate only slightly
--      lower down. Neither reaches 1% conversion
--   3. Direct and Other reach checkout at 2.98% and 2.79% and
--      payment at 1.20% and 0.95%. Something between those two
--      stages costs them most of their remaining traffic
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: STEP-TO-STEP CONVERSION BY CHANNEL
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Conditional conversion at each transition, which
-- isolates where a channel underperforms instead of showing
-- accumulated loss
-- ─────────────────────────────────────────────────────────────

SELECT
    channel,
    COUNT(*)                                                       AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_view_item = 1),
        COUNT(*)), 2)                                              AS session_to_view_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_cart = 1),
        COUNTIF(reached_view_item = 1)), 2)                        AS view_to_cart_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_checkout = 1),
        COUNTIF(reached_cart = 1)), 2)                             AS cart_to_checkout_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_payment = 1),
        COUNTIF(reached_checkout = 1)), 2)                         AS checkout_to_payment_pct,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1),
        COUNTIF(reached_payment = 1)), 2)                          AS payment_to_purchase_pct
FROM `ga4_analysis.sessions`
WHERE channel != 'Unknown'
GROUP BY channel
HAVING COUNT(*) >= 5000
ORDER BY sessions DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- channel          sessions  sess>view  view>cart  cart>chkout  chkout>pay  pay>purch
-- Google Organic     96,345      26.84      19.25        82.93       57.18      67.94
-- Self-Referral      61,375      29.97      21.96        65.77       76.48      73.57
-- Direct             37,839      22.81      18.61        70.24       40.16      69.54
-- Other              32,790      21.83      17.59        72.76       33.95      63.34
-- Referral           22,396      32.81      27.58        85.84       75.80      75.36
-- Google Paid         7,672      21.58      16.36        66.42       35.56      73.44
-- Obfuscated          6,394      23.91      27.86        82.39       77.78      71.43
-- SITE                           21.70      19.72        73.12       61.37      71.14
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Four of the five steps are reasonably tight across
--      channels: product view rate spans 11pp, view-to-cart 11pp,
--      cart-to-checkout 20pp, payment-to-purchase 12pp.
--      Checkout-to-payment spans 44 percentage points, from 33.95%
--      to 77.78%. That single step is where channels diverge
--   2. The split is not a quality gradient. Referral (75.80%),
--      Self-Referral (76.48%) and Obfuscated (77.78%) sit together
--      at the top; Direct (40.16%), Other (33.95%) and Google Paid
--      (35.56%) sit together at the bottom; Google Organic is
--      alone in the middle at 57.18%
--   3. In absolute sessions, Google Organic loses most at this
--      step: 4,133 reach checkout and 2,360 reach payment, a loss
--      of 1,773. Direct loses 674 and Other 604. Site-wide the
--      step loses 4,291
--   4. Two explanations fit. The first is that Direct, Other and
--      Google Paid visitors balk at something disclosed at
--      checkout. The second is session fragmentation: if a
--      checkout journey crosses a host boundary, the first
--      fragment records begin_checkout with no payment under
--      whichever channel acquired the visitor, and the second
--      carries the payment under Self-Referral
--   5. The second explanation predicts what is observed, because
--      Self-Referral consists of continuation fragments and sits
--      at the top of exactly this column.
--      02_channel_attribution QUERY 3 and 01_funnel_analysis
--      QUERY 2 supply the supporting evidence. The first
--      explanation cannot be excluded from this export
--   6. Google Paid has 47 orders across 7,672 sessions, so its
--      73.44% payment-to-purchase rate rests on 64 sessions
--      reaching payment and will swing on a handful of orders
-- ─────────────────────────────────────────────────────────────