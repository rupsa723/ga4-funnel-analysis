-- ══════════════════════════════════════════════════════════════
-- FILE:     10_landing_page_analysis.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     10 of 12 — where do sessions arrive, and is it where
--           the money is?
-- FOLLOWS:  09_product_analysis — Apparel is 47% of revenue
-- LEADS TO: 11_checkout_abandonment — what happens to the sessions
--           that get closest to buying
-- REQUIRES: _build_1_sessions.sql — ga4_analysis.page_path,
--           ga4_analysis.page_label, and the entry_path and
--           entry_page_label columns on ga4_analysis.sessions
-- SOURCE:   ga4_analysis.sessions,
--           bigquery-public-data.ga4_obfuscated_sample_ecommerce
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- Two questions. Which pages do sessions start on and how do those
-- sessions perform, answered from the sessions table. And which
-- pages get the most traffic overall, answered from page_view
-- events on the raw export, since the sessions table holds only
-- the entry page.
--
-- Counting entries ranks pages by traffic. Attaching bounce,
-- conversion and revenue to each entry page ranks them by what
-- they are worth, and the two rankings disagree sharply.
--
-- URL normalisation is defined in _build_1_sessions.sql:
-- entry_path is the grouping key and entry_page_label is the
-- display name, so 'Apparel > Mens' replaces the full URL. QUERY 4
-- calls the function directly because it reads the raw export,
-- where the stored columns do not exist.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: TOP ENTRY PAGES
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Rank entry points by volume, with URL variants merged
-- ─────────────────────────────────────────────────────────────

SELECT
    entry_page_label                                                AS page,
    COUNT(*)                                                        AS sessions,
    ROUND(100 * COUNT(*) /
        (SELECT COUNT(*) FROM `ga4_analysis.sessions`), 2)          AS pct_of_sessions
FROM `ga4_analysis.sessions`
GROUP BY page
ORDER BY sessions DESC
LIMIT 15;

-- ── RESULT ───────────────────────────────────────────────────
-- page                                sessions   % of sessions
-- Homepage                             161,673           44.89
-- Apparel                               40,174           11.16
-- Shop By Brand > YouTube               25,300            7.03
-- Apparel > Google Dino Game Tee        18,793            5.22
-- Store home                            14,972            4.16
-- Apparel > Mens > Mens T Shirts         7,237            2.01
-- Lifestyle > Drinkware                  5,746            1.60
-- Apparel > Mens                         5,502            1.53
-- Sign in                                4,313            1.20
-- Lifestyle > Bags                       4,183            1.16
-- Basket                                 4,173            1.16
-- Shop By Brand > Google                 3,909            1.09
-- Clearance                              3,445            0.96
-- New                                    3,085            0.86
-- Policy: Frequently Asked Questions      3,015            0.84
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. The homepage receives 44.89% of all entries once its nine
--      URL variants are merged. At raw-URL grain it appears as
--      three separate mid-sized rows, which understates the most
--      important page on the site by nearly a factor of two
--   2. Four pages account for 68.3% of all entries: homepage,
--      Apparel, the YouTube brand page and the Dino Game Tee
--      product page
--   3. Basket and Sign in are entry pages for 8,486 sessions
--      between them. Nobody arrives at a basket from outside, so
--      these are returning visitors resuming a saved cart, which
--      is the same behaviour 01_funnel_analysis QUERY 2 measures
--      as 5,147 sessions beginning checkout with nothing added
--   4. Below the top four the list drops sharply. The fifth page
--      takes 4.16% and the fifteenth takes 0.84%, so entry traffic
--      is concentrated in a handful of pages and everything else
--      is a long tail
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: ENTRY PAGE PERFORMANCE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Attach engagement, conversion and revenue to each entry
-- page. Restricted to pages with at least 500 sessions so the
-- rates rest on a usable base
-- ─────────────────────────────────────────────────────────────

SELECT
    entry_page_label                                                  AS page,
    COUNT(*)                                                          AS sessions,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2) AS bounce_ga4_pct,
    ROUND(AVG(page_views), 2)                                         AS avg_page_views,
    ROUND(AVG(total_engagement_msec) / 1000, 1)                       AS avg_engagement_sec,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_view_item = 1), COUNT(*)), 2) AS pct_view_item,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(reached_cart = 1), COUNT(*)), 2)  AS pct_cart,
    COUNTIF(purchased = 1)                                            AS purchases,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)     AS cvr_pct,
    ROUND(SUM(revenue), 2)                                            AS revenue,
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNT(*)), 2)                     AS rev_per_session
FROM `ga4_analysis.sessions`
GROUP BY page
HAVING COUNT(*) >= 500
ORDER BY sessions DESC
LIMIT 30;

-- ── RESULT ───────────────────────────────────────────────────
-- Site baselines: bounce 32.82% · 3.75 pages · 70.3 sec
--                 21.39% view item · 1.35% CVR · $1.01 per session
--
-- page                            sessions  bounce  pages  engage_s  view%  cart%  purch   CVR   revenue  rev/sess
-- Homepage                         161,673   26.10   4.96      92.0  20.61   5.75  2,731  1.69  $199,740     1.24
-- Apparel                           40,174   37.21   2.16      30.7   8.85   1.46    138  0.34   $11,963     0.30
-- Shop By Brand > YouTube           25,300   29.38   2.42      43.6  18.28   2.53     61  0.24    $2,006     0.08
-- Apparel > Google Dino Game Tee    18,793   54.41   1.52       6.9  11.71   0.07      1  0.01       $73     0.00
-- Store home                        14,972   37.35   2.27      34.3   9.28   1.88    103  0.69    $7,589     0.51
-- Apparel > Mens > Mens T Shirts     7,237   17.15   3.97      95.1  34.57   6.48     48  0.66    $2,328     0.32
-- Lifestyle > Drinkware              5,746   47.89   2.19      44.7   9.66   1.98     45  0.78    $3,034     0.53
-- Apparel > Mens                     5,502   38.51   4.11      99.6  30.75   7.02    142  2.58   $13,720     2.49
-- Sign in                            4,313   28.24   4.73      79.0  14.07   3.99     89  2.06    $6,070     1.41
-- Lifestyle > Bags                   4,183   46.86   2.15      56.4  12.10   1.67     13  0.31    $1,372     0.33
-- Basket                             4,173   38.87   5.06     106.6  25.21   9.15    249  5.97   $23,955     5.74
-- Shop By Brand > Google             3,909   22.23   6.04     174.3  42.95  12.41    162  4.14   $13,863     3.55
-- Clearance                          3,445   44.88   3.89     105.8  25.92   7.84     89  2.58    $5,825     1.69
-- New                                3,085   46.87   3.57      88.5  23.18   5.41     72  2.33    $4,355     1.41
-- Policy: Frequently Asked Qs        3,015   37.08   1.67      33.9   3.12   0.73      5  0.17      $235     0.08
-- Apparel > YouTube Icon Hoodie      2,430   49.30   1.98      15.5   4.28   0.66      4  0.16       $72     0.03
-- Stationery > Stickers              2,380   27.61   2.88      52.5  26.05   5.00     10  0.42      $345     0.14
-- Site search results                1,710   46.67   2.49      69.4  15.79   2.69     13  0.76      $825     0.48
-- Apparel > Hats                     1,624   34.91   3.12      68.7  27.71   7.39     27  1.66    $1,758     1.08
-- Accessories > Chrome Dinosaur      1,609   40.46   2.12      25.6  88.19   0.87      8  0.50      $456     0.28
-- Accessories                        1,600   49.44   1.87      19.0  10.69   0.56      0  0.00        $0     0.00
-- Bags > Backpacks                   1,549   25.31   3.24      60.3  35.77   3.10      2  0.13      $216     0.14
-- Apparel > Womens                   1,367   43.53   4.26     108.5  29.19   8.41     60  4.39    $5,696     4.17
-- Eco Friendly                       1,354   51.99   3.12      81.2  21.27   3.99     26  1.92    $2,142     1.58
-- Campus Collection                  1,343   51.38   2.81      70.1  18.91   4.47     17  1.27    $1,266     0.94
-- Accessories > Campus Bike          1,079   30.03   2.59      47.0  91.29   1.85      5  0.46      $355     0.33
-- Office                               995   40.00   2.33      30.2   9.75   1.21      1  0.10       $16     0.02
-- Apparel > Kids                       987   44.58   4.23     102.2  27.86   7.09     35  3.55    $2,115     2.14
-- Accessories > Noogler Android          928   27.69   3.55     69.6  93.86   2.69      9  0.97      $267     0.29
-- Stationery                           840   41.67   2.88      75.2  20.71   4.52      6  0.71      $158     0.19
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Three high-volume entry pages perform far below the site
--      and absorb 84,267 sessions between them, 23.4% of all
--      traffic, returning $14,042 or 3.9% of revenue:
--        Apparel                40,174 sessions, 0.34% CVR, $0.30/sess
--        Shop By Brand>YouTube  25,300 sessions, 0.24% CVR, $0.08/sess
--        Dino Game Tee          18,793 sessions, 0.01% CVR, $0.00/sess
--      Nearly a quarter of traffic lands somewhere that sells
--      almost nothing
--   2. The Dino Game Tee page is the worst entry point in the
--      dataset: 54.41% bounce, 1.52 page views, 6.9 seconds and
--      one order across 18,793 sessions. Its cart rate is 0.07%.
--      Seven seconds is not a product evaluation, so the traffic
--      reaching it does not want the product
--   3. The Apparel category page is the second largest entry page
--      and converts at a quarter of the site rate on 2.16 page
--      views. 09_product_analysis QUERY 2 shows Apparel is 47.42%
--      of all revenue, so the best-selling category has the
--      weakest major landing page
--   4. The homepage is the site's engine. 161,673 sessions at
--      26.10% bounce, 4.96 page views, 92 seconds, 1.69%
--      conversion and $1.24 per session, carrying $199,740 or
--      55.2% of all revenue. It beats the site average on every
--      one of those measures
--   5. Basket is the highest revenue-per-session entry page at
--      $5.74 and converts at 5.97%. Sessions that begin at a saved
--      cart are the most valuable traffic on the site, and Sign in
--      behaves similarly at 2.06% and $1.41
--   6. Shop By Brand > Google is the best category-style entry
--      page: 4.14% conversion, $3.55 per session, 174.3 seconds,
--      42.95% reaching a product view. The YouTube brand page is
--      built the same way and returns $0.08. Two brand pages, one
--      worth 44 times the other per session
--   7. Gendered and age subcategories convert well above the site:
--      Apparel > Womens 4.39% and $4.17 per session, Apparel >
--      Kids 3.55% and $2.14, Apparel > Mens 2.58% and $2.49
--   8. Product-page entries show inflated view-item rates by
--      construction. Chrome Dinosaur reads 88.19%, Campus Bike
--      91.29% and Noogler Android 93.86% because landing on a
--      product page fires view_item. They are not comparable to
--      category entries
--   9. Deep category pages behave best on engagement. Mens T
--      Shirts has the lowest bounce of any page at 17.15% with
--      95.1 seconds. Visitors arriving at a specific subcategory
--      engage; visitors arriving at a broad one do not. Accessories
--      is the clearest case of the opposite: 1,600 sessions,
--      49.44% bounce and zero orders
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: HOW MUCH URL FRAGMENTATION THE NORMALISATION REMOVES
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Count how many raw URLs collapse into each path, so the
-- scale of the fragmentation is measured rather than asserted
-- ─────────────────────────────────────────────────────────────

SELECT
    entry_path,
    ANY_VALUE(entry_page_label)                                       AS page,
    COUNT(*)                                                          AS sessions,
    COUNT(DISTINCT entry_page)                                        AS distinct_urls_collapsed,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(is_bounce_ga4 = 1), COUNT(*)), 2) AS bounce_ga4_pct,
    COUNTIF(purchased = 1)                                            AS purchases,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased = 1), COUNT(*)), 2)     AS cvr_pct,
    ROUND(SUM(revenue), 2)                                            AS revenue
FROM `ga4_analysis.sessions`
GROUP BY entry_path
HAVING COUNT(*) >= 500
ORDER BY sessions DESC
LIMIT 25;

-- ── RESULT (top rows) ────────────────────────────────────────
-- entry_path                              page                      sessions  URLs  bounce  purch   revenue   CVR
-- (empty)                                 Homepage                   161,673     9   26.10  2,731  $199,740  1.69
-- /google+redesign/apparel                Apparel                     40,174     1   37.21    138   $11,963  0.34
-- /google+redesign/shop+by+brand/youtube  Shop By Brand > YouTube     25,300     6   29.38     61    $2,006  0.24
-- /google+redesign/apparel/google+dino…   Dino Game Tee               18,793     3   54.41      1       $73  0.01
-- /store.html                             Store home                  14,972     3   37.35    103    $7,589  0.69
-- /google+redesign/apparel/mens/mens+t…   Mens T Shirts                7,237     3   17.15     48    $2,328  0.66
-- /google+redesign/lifestyle/drinkware    Lifestyle > Drinkware        5,746     2   47.89     45    $3,034  0.78
-- /google+redesign/apparel/mens           Apparel > Mens               5,502     4   38.51    142   $13,720  2.58
-- /signin.html                            Sign in                      4,313     1   28.24     89    $6,070  2.06
-- /google+redesign/lifestyle/bags         Lifestyle > Bags             4,183     3   46.86     13    $1,372  0.31
-- /basket.html                            Basket                       4,173     1   38.87    249   $23,955  5.97
-- /google+redesign/shop+by+brand/google   Shop By Brand > Google       3,909     2   22.23    162   $13,863  4.14
-- /google+redesign/clearance              Clearance                    3,445     2   44.88     89    $5,825  2.58
-- /google+redesign/new                    New                          3,084     2   46.89     72    $4,355  2.33
-- /store-policies/frequently-asked-qs     Policy: FAQ                  3,015     1   37.08      5      $235  0.17
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Nine distinct URLs serve the homepage and six serve the
--      YouTube brand page. Ten of the fifteen largest entry points
--      collapse more than one URL, so fragmentation is the normal
--      condition of this dataset rather than a homepage quirk
--   2. Merged, the homepage is 44.89% of entries and $199,740, or
--      55.2% of revenue, at 26.10% bounce against a 32.82% site
--      rate and 1.69% conversion against 1.35%. Left fragmented it
--      reads as three unremarkable mid-sized pages
--   3. The hosts do not perform alike. At raw-URL grain the shop
--      subdomain took 96,178 of those sessions at 2.46%
--      conversion and $1.79 per session, while the bare and www
--      hosts took 65,442 between them at 0.52% and 0.62%, or
--      $0.44 and $0.38 per session. Same page, one fifth the
--      value, which is further evidence for the cross-host
--      problem in 02_channel_attribution QUERY 3
--   4. The 'New' row shows the label and the path disagreeing by
--      one session: QUERY 1 groups 3,085 under the label and this
--      query finds 3,084 under the path. A second path produces
--      the same label, which is why entry_path is the join key
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 4: MOST VISITED PAGES (RAW TABLE)
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Count page_view events rather than sessions, to
-- separate pages people navigate to from pages people arrive on.
-- Calls page_label directly because the raw export has no
-- normalised column
-- ─────────────────────────────────────────────────────────────

SELECT
    `ga4_analysis.page_label`(
        (SELECT value.string_value FROM UNNEST(event_params)
         WHERE key = 'page_location'))  AS page,
    COUNT(*)                            AS page_views,
    COUNT(DISTINCT user_pseudo_id)      AS distinct_users,
    ROUND(SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT user_pseudo_id)), 2) AS views_per_user
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'page_view'
GROUP BY page
ORDER BY page_views DESC
LIMIT 15;

-- ── RESULT ───────────────────────────────────────────────────
-- page                             page_views    users   views/user
-- Homepage                            287,647  130,840         2.20
-- Apparel                              81,685   50,194         1.63
-- Basket                               78,900   22,728         3.47
-- Store home                           73,594   32,339         2.28
-- Apparel > Mens                       47,676   22,324         2.14
-- Shop By Brand > YouTube              43,572   28,412         1.53
-- Sign in                              40,887   21,518         1.90
-- Clearance                            38,340   20,941         1.83
-- New                                  28,952   18,317         1.58
-- Apparel > Google Dino Game Tee       28,136   19,401         1.45
-- Site search results                  27,315   14,906         1.83
-- Lifestyle > Drinkware                25,854   15,607         1.66
-- Lifestyle > Bags                     22,760   14,538         1.57
-- Campus Collection                    20,903   15,559         1.34
-- Checkout: your information           19,706    9,689         2.03
--
-- VISITED VERSUS ENTERED
-- page                     visits rank   entry rank   reading
-- Homepage                           1            1   start point
-- Apparel                            2            2   both
-- Basket                             3           11   pure funnel page
-- Store home                         4            5   both
-- Apparel > Mens                     5            8   navigated to
-- Sign in                            7            9   pure funnel page
-- Clearance                          8           13   navigated to
-- Dino Game Tee                     10            4   pure entry page
-- Checkout: your information        15    not in top   pure funnel page
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Basket is the third most viewed page with 78,900 views from
--      22,728 users, 3.47 views per user, the highest ratio on the
--      list. Only 15,188 sessions ever fire add_to_cart, so people
--      are opening the basket repeatedly across sessions. That is
--      cart persistence seen from a third angle, after
--      01_funnel_analysis QUERY 2 and 08 QUERY 3
--   2. The Dino Game Tee inverts the usual pattern: tenth on
--      views, fourth on entries, 1.45 views per user. A page much
--      stronger as an entry than as a destination is receiving
--      external traffic that the site itself does not send anyone
--      to
--   3. The checkout information page draws 19,706 views from 9,689
--      users while 11,106 sessions begin checkout. Roughly 2 views
--      per user of a page that should be seen once per order, and
--      4,848 orders result. Consistent with the shipping-stage
--      stall in 11_checkout_abandonment QUERY 1, where 2,104
--      sessions stop after entering shipping details
--   4. Sign in draws 40,887 views from 21,518 users, more than the
--      YouTube brand page. On a store with 4,848 orders, that many
--      sign-in views points at an account step more people start
--      than finish, though this export cannot confirm it
--   5. Apparel ranks second on both lists and still converts at
--      0.34% on entry. High traffic and low value at once
--   6. Merged, the homepage takes 287,647 views, 3.5 times the
--      next page, from 130,840 users
-- ─────────────────────────────────────────────────────────────