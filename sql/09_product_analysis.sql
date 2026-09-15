-- ══════════════════════════════════════════════════════════════
-- FILE:     09_product_analysis.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     9 of 12 — what did the converting sessions buy?
-- FOLLOWS:  08_new_vs_returning — repeat visits explain most of
--           the revenue
-- LEADS TO: 10_landing_page_analysis — where sessions arrive, and
--           whether the pages match what sells
-- SOURCE:   ga4_analysis.items, ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- The items table holds one row per line item per purchase, so it
-- describes what people bought and never what they looked at. Any
-- statement about product interest, browsing, or demand for items
-- that were not purchased is outside what it supports.
--
-- Total item revenue is $362,110 against $362,165 in the sessions
-- table, reconciled in 00 QUERY 2.
--
-- QUERY 1 ranks products, QUERY 2 categories, QUERY 3 the leader
-- inside each category, QUERY 4 the same by month, QUERY 5 by
-- acquisition channel. QUERY 2 and QUERY 3 together expose a
-- taxonomy problem that limits what the category view can carry.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: TOP 10 PRODUCTS BY REVENUE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Establish whether revenue is concentrated in a few
-- products or spread across the catalogue
-- ─────────────────────────────────────────────────────────────

WITH totals AS (
    SELECT SUM(item_revenue) AS t_revenue FROM `ga4_analysis.items`
)
SELECT
    i.item_name,
    ANY_VALUE(i.item_category)                                      AS item_category,
    SUM(i.quantity)                                                 AS units_sold,
    COUNT(DISTINCT i.session_id)                                    AS orders,
    ROUND(SUM(i.item_revenue), 2)                                   AS revenue,
    ROUND(100 * SAFE_DIVIDE(SUM(i.item_revenue), MAX(t.t_revenue)), 2) AS pct_of_item_revenue,
    ROUND(SAFE_DIVIDE(SUM(i.item_revenue), SUM(i.quantity)), 2)     AS avg_unit_price
FROM `ga4_analysis.items` i
CROSS JOIN totals t
GROUP BY i.item_name
ORDER BY revenue DESC
LIMIT 10;

-- ── RESULT ───────────────────────────────────────────────────
-- product                                  category      units  orders  revenue   %rev   unit $
-- Google Zip Hoodie F/C                    Apparel         273     225  $13,788   3.81   50.51
-- Google Crewneck Sweatshirt Navy          Uncategorized   236     190  $10,714   2.96   45.40
-- Google Men's Tech Fleece Grey            Apparel         134      93   $9,965   2.75   74.37
-- Google Badge Heavyweight Pullover Black  Apparel         201     154   $9,712   2.68   48.32
-- Super G Unisex Joggers                   Shop by Brand   308     227   $9,529   2.63   30.94
-- Google Crewneck Sweatshirt Green         Apparel         184     152   $8,382   2.31   45.55
-- Google Sherpa Zip Hoodie Charcoal        Apparel         115      94   $6,397   1.77   55.63
-- Google Men's Puff Jacket Black           Apparel          64      55   $6,187   1.71   96.67
-- Google Men's Tech Fleece Vest Charcoal   Apparel          84      63   $5,549   1.53   66.06
-- Google Women's Puff Jacket Black         Apparel          57      47   $5,313   1.47   93.21
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Revenue is not concentrated. The top ten products account
--      for 23.62% of item revenue and no single product exceeds
--      3.81%
--   2. Nine of the ten are outerwear or sweatshirts and the window
--      is November to January, so this ranking is seasonal rather
--      than a permanent bestseller list
--   3. Unit prices in the top ten span $30.94 to $96.67, so
--      products reach the top by two different routes. Super G
--      Unisex Joggers sells the most units at the lowest price;
--      Google Men's Puff Jacket Black sells 64 units at $96.67
--   4. The second-ranked product carries no category. QUERY 2 and
--      QUERY 3 show how far that problem extends
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: REVENUE BY CATEGORY
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: The same revenue viewed by category, and a check on
-- whether the category field is usable
-- ─────────────────────────────────────────────────────────────

WITH totals AS (
    SELECT SUM(item_revenue) AS t_revenue FROM `ga4_analysis.items`
)
SELECT
    IFNULL(i.item_category, '(uncategorised)')                      AS item_category,
    COUNT(DISTINCT i.item_name)                                     AS distinct_products,
    SUM(i.quantity)                                                 AS units_sold,
    COUNT(DISTINCT i.session_id)                                    AS orders,
    ROUND(SUM(i.item_revenue), 2)                                   AS revenue,
    ROUND(100 * SAFE_DIVIDE(SUM(i.item_revenue), MAX(t.t_revenue)), 2) AS pct_of_item_revenue,
    ROUND(SAFE_DIVIDE(SUM(i.item_revenue), COUNT(DISTINCT i.session_id)), 2) AS revenue_per_order,
    ROUND(SAFE_DIVIDE(SUM(i.item_revenue), SUM(i.quantity)), 2)     AS avg_unit_price
FROM `ga4_analysis.items` i
CROSS JOIN totals t
GROUP BY item_category
ORDER BY revenue DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- category                products  units  orders   revenue   %rev   rev/order  unit $
-- Apparel                       95  5,447   2,627  $171,727  47.42      65.37   31.53
-- New                           44  2,132     942   $25,813   7.13      27.40   12.11
-- Bags                          23  1,053     513   $23,860   6.59      46.51   22.66
-- Campus Collection             67  2,184     761   $20,061   5.54      26.36    9.19
-- Accessories                   41  2,006     794   $17,815   4.92      22.44    8.88
-- Uncategorized Items           14    810     441   $17,394   4.80      39.44   21.47
-- Shop by Brand                 17  1,198     662   $16,960   4.68      25.62   14.16
-- Drinkware                     11  1,104     550   $15,807   4.37      28.74   14.32
-- Lifestyle                     14    816     460   $13,423   3.71      29.18   16.45
-- Clearance                     31    906     499   $11,476   3.17      23.00   12.67
-- Office                        17  2,075     562    $9,078   2.51      16.15    4.37
-- (blank)                      136    594     206    $7,319   2.02      35.53   12.32
-- Google                         4    683     232    $3,115   0.86      13.43    4.56
-- Gift Cards                     3     58      10    $2,475   0.68     247.50   42.67
-- Small Goods                    4    197     159    $1,737   0.48      10.92    8.82
-- Stationery                     8    712     190    $1,532   0.42       8.06    2.15
-- Writing Instruments            5    417     132      $870   0.24       6.59    2.09
-- Notebooks & Journals           3    111      34      $695   0.19      20.44    6.26
-- Electronics Accessories        1     57      41      $579   0.16      14.12   10.16
-- Fun                            1    158      36      $270   0.07       7.50    1.71
-- Black Lives Matter             1      2       2      $104   0.03      52.00   52.00
-- (not set)                      1   null     409      null   null        null    null
-- TOTAL                              22,720          $362,110
-- 396 distinct products across 22 category values
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Apparel is 47.42% of item revenue, more than the next six
--      categories combined, from 95 products and 2,627 orders at
--      $65.37 per order and the highest unit price outside Gift
--      Cards
--   2. The category field is not reliable. Three buckets are
--      unusable: "Uncategorized Items" holds $17,394 across 14
--      products, a blank category holds 136 products and $7,319,
--      and a "(not set)" row covers 409 orders with no units and
--      no revenue recorded. Together they touch more than $24,700
--      and 1,056 orders. The (not set) orders carry 448 item rows
--      between them, so some hold more than one placeholder
--   3. "New" is a merchandising label rather than a product type,
--      so its $25,813 double-describes items that also belong to a
--      real category
--   4. The "(not set)" row is a data defect rather than a
--      category: 409 orders carry item rows with null category,
--      null quantity and null revenue. They inflate order counts
--      in any category breakdown without contributing revenue, and
--      need WHERE item_revenue IS NOT NULL for any per-order
--      calculation
--   5. Gift Cards average $247.50 per order, the highest of any
--      category, on 10 orders
--   6. Office sells 2,075 units for $9,078, a $4.37 average unit
--      price. The same pattern holds for Stationery and Writing
--      Instruments: high volume, negligible revenue
--   7. QUERY 3 shows the taxonomy problem is worse than three bad
--      buckets
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: LEADING PRODUCT WITHIN EACH CATEGORY
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Measure how much of each category rests on one product
--
-- Written the obvious way, this query fails with:
--   "PARTITION BY expression references column item_category
--    which is neither grouped nor aggregated"
--
-- Cause: aliasing IFNULL(item_category, ...) AS item_category
-- shadows the underlying column. GROUP BY resolves that name to
-- the alias, but PARTITION BY inside a window function resolves
-- names against the underlying table, where item_category is
-- ungrouped. The same identifier means two different things in two
-- clauses of one statement.
--
-- Fix: compute the IFNULL in a CTE under a different name, then
-- group and partition on that name
-- ─────────────────────────────────────────────────────────────

WITH agg AS (
    SELECT
        IFNULL(item_category, '(uncategorised)') AS category,
        item_name,
        SUM(quantity)     AS units_sold,
        SUM(item_revenue) AS revenue
    FROM `ga4_analysis.items`
    GROUP BY category, item_name
)
SELECT
    category AS item_category,
    item_name,
    units_sold,
    ROUND(revenue, 2) AS revenue,
    ROUND(100 * SAFE_DIVIDE(revenue,
        SUM(revenue) OVER (PARTITION BY category)), 2) AS pct_of_category_revenue
FROM agg
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY category
    ORDER BY revenue DESC) = 1
ORDER BY revenue DESC;

-- ── RESULT ───────────────────────────────────────────────────
-- category                  leading product                        units  revenue  % of cat
-- Apparel                   Google Zip Hoodie F/C                    271  $13,692      7.97
-- Shop by Brand             Super G Unisex Joggers                   289   $8,947     52.75
-- Uncategorized Items       Google Crewneck Sweatshirt Navy          136   $6,204     35.67
-- Drinkware                 Google Canteen Bottle Black              268   $5,303     33.55
-- Bags                      Google Utility BackPack                   53   $5,256     22.03
-- Accessories               Google Campus Bike                       131   $4,352     24.43
-- Lifestyle                 Google Perk Thermal Tumbler              193   $3,236     24.11
-- Campus Collection         Google NYC Campus Zip Hoodie              97   $3,231     16.11
-- New                       Google Heathered Pom Beanie              253   $3,132     12.13
-- Office                    Google Metallic Notebook Set             350   $1,797     19.80
-- Clearance                 Google Hemp Tote                         100   $1,296     11.29
-- Gift Cards                Gift Card- $100.00                        12   $1,200     48.48
-- Google                    Google Laptop and Cell Phone Stickers    412   $1,084     34.80
-- Small Goods               Daddy Works at Google Book                45     $736     42.37
-- Stationery                #IamRemarkable Journal                    89     $633     41.32
-- Electronics Accessories   Google See-No Hear-No Set                 57     $579    100.00
-- (blank)                   Google Sherpa Zip Hoodie Charcoal          8     $441      6.03
-- Notebooks & Journals      Google Small Standard Journal Navy        58     $368     52.95
-- Writing Instruments       Google Light Pen Blue                    155     $283     32.53
-- Fun                       Google Mini Kick Ball                    158     $270    100.00
-- Black Lives Matter        BLM Unisex Pullover Hoodie                 2     $104    100.00
-- (not set)                 (not set)                               null     null      null
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. item_category is not a stable attribute of a product. The
--      same item_name appears under different categories on
--      different orders. Compare against QUERY 1:
--        Google Zip Hoodie F/C          273 units total, 271 in Apparel
--        Super G Unisex Joggers         308 units total, 289 in Shop by Brand
--        Google Crewneck Sweatshirt Navy 236 units total, 136 in Uncategorized
--        Google Sherpa Zip Hoodie       115 units total,   8 in (blank)
--      The Crewneck Sweatshirt splits almost evenly between two
--      category values, and the Sherpa Hoodie appears in both
--      Apparel and the blank bucket
--   2. Category totals in QUERY 2 are therefore approximate. The
--      product-level view in QUERY 1 groups by name and is not
--      affected, so it is the more reliable of the two
--   3. Apparel's leader holds 7.97% of the category, so the
--      largest revenue category rests on no single product. It has
--      95 products and none of them carries it
--   4. Six categories rest heavily on one product: Shop by Brand
--      52.75%, Notebooks & Journals 52.95%, Gift Cards 48.48%,
--      Small Goods 42.37%, Stationery 41.32%, Uncategorized Items
--      35.67%
--   5. Three categories read 100% because they contain a single
--      product: Electronics Accessories, Fun, Black Lives Matter
--   6. Gift Cards' leader is the $100 card at 12 units, all sold
--      in January, which is the whole of the category's January
--      revenue
--   7. The "(not set)" row returns a null product name alongside
--      null units and revenue, confirming that those 409 orders
--      carry placeholder line items rather than real ones
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 4: MONTHLY SALES TREND BY CATEGORY
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Site order value falls across the window. This
-- separates a mix shift between categories from a fall in basket
-- size within them
-- ─────────────────────────────────────────────────────────────

SELECT
    IFNULL(item_category, '(uncategorised)')            AS item_category,
    month,
    SUM(quantity)                                       AS units_sold,
    COUNT(DISTINCT session_id)                          AS orders,
    ROUND(SUM(item_revenue), 2)                         AS revenue,
    ROUND(SAFE_DIVIDE(SUM(item_revenue),
        COUNT(DISTINCT session_id)), 2)                 AS revenue_per_order,
    ROUND(SAFE_DIVIDE(SUM(item_revenue), SUM(quantity)), 2) AS avg_unit_price,
    ROUND(100 * SAFE_DIVIDE(SUM(item_revenue),
        SUM(SUM(item_revenue)) OVER (PARTITION BY month)), 2) AS pct_of_month_revenue
FROM `ga4_analysis.items`
GROUP BY item_category, month
ORDER BY item_category, month;

-- ── RESULT (largest categories) ──────────────────────────────
-- category            month     units  orders   revenue  rev/order  unit $  %month
-- Apparel             2020-11   2,427   1,005   $75,070      74.70   30.93   52.02
-- Apparel             2020-12   2,181   1,145   $66,962      58.48   30.70   41.72
-- Apparel             2021-01     839     477   $29,695      62.25   35.39   51.82
-- New                 2020-11     786     331    $9,330      28.19   11.87    6.47
-- New                 2020-12   1,066     454   $13,584      29.92   12.74    8.46
-- New                 2021-01     280     157    $2,899      18.46   10.35    5.06
-- Bags                2020-11     374     156    $7,297      46.78   19.51    5.06
-- Bags                2020-12     520     257   $13,373      52.04   25.72    8.33
-- Bags                2021-01     159     100    $3,190      31.90   20.06    5.57
-- Campus Collection   2020-11     850     275    $7,926      28.82    9.32    5.49
-- Campus Collection   2020-12     998     355    $9,924      27.95    9.94    6.18
-- Campus Collection   2021-01     336     131    $2,211      16.88    6.58    3.86
-- Accessories         2020-11     786     248    $6,402      25.81    8.15    4.44
-- Accessories         2020-12     857     356    $7,589      21.32    8.86    4.73
-- Accessories         2021-01     363     190    $3,824      20.13   10.53    6.67
-- Drinkware           2020-11     422     211    $6,222      29.49   14.74    4.31
-- Drinkware           2020-12     565     254    $7,812      30.76   13.83    4.87
-- Drinkware           2021-01     117      85    $1,773      20.86   15.15    3.09
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. The December order-value drop is a mix shift, not a price
--      cut. Apparel's average unit price is flat across the window
--      at $30.93, $30.70, $35.39, while its share of monthly
--      revenue falls from 52.02% to 41.72% in December and
--      recovers to 51.82% in January
--   2. December buyers moved into cheaper categories: Bags rose
--      from 5.06% to 8.33% of revenue, New from 6.47% to 8.46%,
--      Campus Collection from 5.49% to 6.18%
--   3. Apparel revenue per order falls from $74.70 to $58.48 in
--      December while unit price holds, so December Apparel
--      baskets contained fewer garments rather than cheaper ones
--   4. January unit prices rise in several categories while
--      revenue per order falls: smaller baskets of more expensive
--      items
--   5. January figures here are depressed by the revenue
--      collection failure in 05 QUERY 2, so January category
--      revenue is a lower bound
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 5: CATEGORY BY ACQUISITION CHANNEL
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Join purchased items back to the session that bought
-- them, to test whether order-value differences between channels
-- come from what each one sells
-- ─────────────────────────────────────────────────────────────

SELECT
    s.channel,
    IFNULL(i.item_category, '(uncategorised)')                  AS item_category,
    COUNT(DISTINCT i.session_id)                                AS orders,
    SUM(i.quantity)                                             AS units_sold,
    ROUND(SUM(i.item_revenue), 2)                               AS revenue,
    ROUND(SAFE_DIVIDE(SUM(i.item_revenue),
        COUNT(DISTINCT i.session_id)), 2)                       AS revenue_per_order,
    ROUND(100 * SAFE_DIVIDE(SUM(i.item_revenue),
        SUM(SUM(i.item_revenue)) OVER (PARTITION BY s.channel)), 2) AS pct_of_channel_revenue
FROM `ga4_analysis.items` i
JOIN `ga4_analysis.sessions` s
    USING (session_id)
GROUP BY s.channel, item_category
HAVING COUNT(DISTINCT i.session_id) >= 20
ORDER BY s.channel, revenue DESC;

-- ── RESULT (Apparel row and channel summary; full output is
--    17 rows for Self-Referral, 17 for Google Organic, 17 for
--    Referral, 12 for Direct, 10 for Obfuscated, 7 for Other and
--    1 for Google Paid) ──────────────────────────────────────────
--
-- APPAREL, THE LARGEST ROW IN EVERY CHANNEL
-- channel          orders  units   revenue  rev/order  % of channel
-- Self-Referral       800  1,737   $55,256      69.07         46.90
-- Google Organic      836  1,637   $52,092      62.31         46.71
-- Referral            566  1,265   $38,659      68.30         52.21
-- Direct              171    346   $11,045      64.59         46.58
-- Other               116    232    $7,158      61.71         64.94
-- Obfuscated          114    186    $6,116      53.65         52.86
-- Google Paid          24     44    $1,401      58.38        100.00
--
-- SECOND AND THIRD CATEGORY BY CHANNEL
-- Self-Referral   Bags $9,380 (54.85/order) · New $9,051 (30.17)
-- Google Organic  New $8,046 (26.38) · Campus Collection $6,889 (29.44)
-- Referral        Bags $4,272 (39.56) · New $4,197 (23.98)
-- Direct          New $2,378 (31.29) · Bags $1,589 (44.14)
-- Other           New $1,016 (30.79) · Campus Collection $938 (22.88)
-- Obfuscated      Bags $1,020 (37.78) · New $957 (22.79)
--
-- PLACEHOLDER ROWS CARRIED THROUGH
-- (not set) appears per channel with null units and null revenue:
-- Self-Referral 152 orders · Google Organic 126 · Referral 81 ·
-- Direct 23. Blank-category rows: Google Organic 60 orders /
-- $2,690, Self-Referral 58 / $1,713, Referral 54 / $1,937
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Category mix does not explain the order-value differences
--      between channels. Apparel is 46.90% of Self-Referral's
--      retained revenue and 46.71% of Google Organic's, yet the
--      two channels average $80.35 and $70.39 per order. Nearly
--      identical mixes, a $10 gap
--   2. The gap is inside the categories. Self-Referral takes
--      $69.07 per Apparel order against Google Organic's $62.31,
--      and $54.85 per Bags order against $41.72. Where Google
--      Organic leads (Drinkware, Campus Collection, Uncategorized
--      Items) the categories are small
--   3. Self-Referral baskets are broader. Dividing category-order
--      rows by channel orders gives 2.17 categories per order for
--      Self-Referral against 1.99 for Google Organic, 2.08 for
--      Referral and 1.97 for Direct. Bigger baskets spanning more
--      of the catalogue
--   4. Both of those fit 02_channel_attribution QUERY 3. A
--      Self-Referral session is a continuation carrying a basket
--      that was assembled earlier, so it is further along and
--      fuller than a session that started from scratch
--   5. Referral has the highest Apparel concentration among the
--      large channels at 52.21%, and the second highest revenue
--      per Apparel order at $68.30. It converts best (4.44%) and
--      sells the store's most valuable category most heavily
--   6. Apparel is between 46.58% and 64.94% of retained revenue in
--      every channel. No channel sells a meaningfully different
--      catalogue from any other, which is the same uniformity
--      12_geography_analysis QUERY 3 finds across markets
--   7. The 409 placeholder orders identified in QUERY 2 spread
--      across channels roughly in proportion to order volume, so
--      they are not a channel-specific defect
--
-- READ THE PERCENTAGE COLUMN CAREFULLY:
--   pct_of_channel_revenue is a share of the rows that survived
--   the 20-order threshold, not of the channel's total revenue.
--   BigQuery applies HAVING before the window function, so the
--   partition sums only retained rows. Self-Referral's retained
--   rows total $117,818 against its true $120,125. Google Paid
--   reads 100.00% because only one of its categories cleared the
--   threshold, while $1,746 of its $3,147 sits below it. For
--   shares of true channel revenue, drop the HAVING clause or
--   compute the denominator in a separate CTE
-- ─────────────────────────────────────────────────────────────