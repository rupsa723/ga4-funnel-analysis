-- ══════════════════════════════════════════════════════════════
-- FILE:     _build_1_sessions.sql
-- PROJECT:  GA4 Digital Marketing Funnel Analysis
-- STEP:     build 1 of 2 — create the session-grain table
-- FOLLOWS:  nothing. This is the first file to run
-- LEADS TO: _build_2_items.sql, then 00_data_quality_checks
-- SOURCE:   bigquery-public-data.ga4_obfuscated_sample_ecommerce
-- CREATES:  ga4_analysis.page_path, ga4_analysis.page_label,
--           ga4_analysis.sessions
-- ══════════════════════════════════════════════════════════════

-- ── PURPOSE ──────────────────────────────────────────────────
-- Turns 4,295,584 event rows into 360,129 session rows, one per
-- session, with every measure the analysis needs already derived.
-- Doing the derivation once here rather than in each analysis
-- query is what keeps the numbered files short and keeps a
-- definition from drifting between them.
--
-- Session identity is user_pseudo_id concatenated with
-- ga_session_id. Everything else is an aggregate over that key.
--
-- Two URL functions are defined first because the table stores
-- normalised versions of the entry page. The functions are
-- persistent so that queries reading the raw export, where no
-- session column exists, can call them too.
--
-- SANDBOX NOTE: a project without billing cannot run DML, so
-- columns cannot be added to this table afterwards with ALTER plus
-- UPDATE. Any change to the schema means re-running this file.
-- CREATE FUNCTION and CREATE OR REPLACE TABLE are DDL and run in
-- the free tier.
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- STATEMENT 1: page_path — the URL grouping key
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Raw page_location values carry the hostname on every
-- row, and the same page appears under several hostnames, several
-- letter cases, and with or without query strings. This reduces
-- all of those to one string so they group together
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION `ga4-marketing-analysis.ga4_analysis.page_path`(url STRING) AS (
    RTRIM(
        LOWER(
            REGEXP_REPLACE(
                REGEXP_REPLACE(IFNULL(url, ''), r'^https?://[^/]+', ''),
                r'[?#].*$', '')
        ), '/')
);

-- ── WHAT IT PRODUCES ─────────────────────────────────────────
--   'https://shop.googlemerchandisestore.com/Google+Redesign/Apparel/Mens'
--     -> '/google+redesign/apparel/mens'
--   'https://www.googlemerchandisestore.com/'  -> ''
--   'https://googlemerchandisestore.com/?utm=x' -> ''
--
--   Six distinct homepage URLs reduce to the empty string, and two
--   YouTube brand-page URLs differing only in case reduce to one.
--   Use this for GROUP BY and joins, never for display
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- STATEMENT 2: page_label — the URL display name
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Take the path and make it readable. Names the utility
-- pages, drops the /google+redesign/ prefix that sits on almost
-- every path, turns plus signs back into spaces and renders
-- remaining slashes as a breadcrumb separator
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION `ga4-marketing-analysis.ga4_analysis.page_label`(url STRING) AS ((
    SELECT
        CASE
            WHEN p = ''                     THEN 'Homepage'
            WHEN p = '/store.html'          THEN 'Store home'
            WHEN p = '/basket.html'         THEN 'Basket'
            WHEN p = '/signin.html'         THEN 'Sign in'
            WHEN p = '/asearch.html'        THEN 'Site search results'
            WHEN p = '/yourinfo.html'       THEN 'Checkout: your information'
            WHEN p = '/payment.html'        THEN 'Checkout: payment'
            WHEN p LIKE '/store-policies/%' THEN CONCAT('Policy: ',
                INITCAP(REPLACE(REGEXP_REPLACE(p, r'^/store-policies/', ''), '-', ' ')))
            ELSE REPLACE(INITCAP(REPLACE(REPLACE(
                REGEXP_REPLACE(p, r'^/(google\+redesign/)?', ''),
                '+', ' '), '/', ' > ')), 'Youtube', 'YouTube')
        END
    FROM (SELECT `ga4-marketing-analysis.ga4_analysis.page_path`(url) AS p)
));

-- ── WHAT IT PRODUCES ─────────────────────────────────────────
--   '.../Google+Redesign/Apparel/Mens'        -> 'Apparel > Mens'
--   '.../Google+Redesign/Shop+by+Brand/YouTube'
--                                  -> 'Shop By Brand > YouTube'
--   '.../basket.html'                         -> 'Basket'
--   '.../store-policies/frequently-asked-questions/'
--                     -> 'Policy: Frequently Asked Questions'
--
--   Use this for display. Two pages with different paths could in
--   principle produce the same label, so it is not a safe join key
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- STATEMENT 3: BUILD THE SESSIONS TABLE
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Flatten events to sessions. The events CTE pulls the
-- event_params values out of their nested arrays once, so the
-- aggregation reads plain columns. The agg CTE does the flattening
-- and the outer SELECT adds everything derived from the aggregates
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE `ga4-marketing-analysis.ga4_analysis.sessions` AS
WITH events AS (
    SELECT
        CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params)
            WHERE key = 'ga_session_id') AS STRING)) AS session_id,
        user_pseudo_id,
        PARSE_DATE('%Y%m%d', event_date) AS event_date,
        event_timestamp,
        event_name,
        device.category AS device_category,
        geo.country AS country,
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS source,
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS medium,
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_engaged') AS session_engaged,
        (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_msec,
        ecommerce.purchase_revenue_in_usd AS revenue
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
agg AS (
    SELECT
        session_id,
        ANY_VALUE(user_pseudo_id) AS user_pseudo_id,
        MIN(event_date) AS session_date,
        FORMAT_DATE('%Y-%m', MIN(event_date)) AS session_month,
        COUNT(*) AS total_events,
        COUNTIF(event_name = 'page_view') AS page_views,
        MAX(IF(session_engaged = '1', 1, 0)) AS is_engaged,
        SUM(IFNULL(engagement_msec, 0)) AS total_engagement_msec,
        COUNTIF(event_name = 'user_engagement') AS engagement_events,
        MAX(IF(event_name = 'session_start', 1, 0)) AS has_session_start,
        MAX(IF(event_name = 'first_visit', 1, 0)) AS is_first_visit,
        MAX(IF(event_name = 'view_item', 1, 0)) AS reached_view_item,
        MAX(IF(event_name = 'add_to_cart', 1, 0)) AS reached_cart,
        MAX(IF(event_name = 'begin_checkout', 1, 0)) AS reached_checkout,
        MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS reached_shipping,
        MAX(IF(event_name = 'add_payment_info', 1, 0)) AS reached_payment,
        MAX(IF(event_name = 'purchase', 1, 0)) AS purchased,
        SUM(IF(event_name = 'purchase', IFNULL(revenue, 0), 0)) AS revenue,
        ANY_VALUE(device_category) AS device_category,
        ANY_VALUE(country) AS country,
        ARRAY_AGG(source IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS session_source,
        ARRAY_AGG(medium IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS session_medium,
        ARRAY_AGG(page_location IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS entry_page
    FROM events
    GROUP BY session_id
)
SELECT
    *,
    CASE
        WHEN session_source IS NULL THEN 'Unknown'
        WHEN session_source = '(data deleted)' THEN 'Obfuscated'
        WHEN session_source LIKE '%google%' AND session_medium = 'cpc' THEN 'Google Paid'
        WHEN session_source LIKE '%google%' AND session_medium = 'organic' THEN 'Google Organic'
        WHEN session_source LIKE '%google%' AND session_medium = 'referral' THEN 'Self-Referral'
        WHEN session_source IN ('(direct)','direct') OR session_medium IN ('(none)','none') THEN 'Direct'
        WHEN session_medium = 'referral' THEN 'Referral'
        ELSE 'Other'
    END AS channel,
    IF(is_first_visit = 1, 'New', 'Returning') AS user_type,
    IF(is_engaged = 0, 1, 0) AS is_bounce_ga4,
    IF(page_views <= 1 AND engagement_events = 0, 1, 0) AS is_bounce_pageview,
    IF(total_engagement_msec < 10000, 1, 0) AS is_bounce_10sec,
    `ga4-marketing-analysis.ga4_analysis.page_path`(entry_page)  AS entry_path,
    `ga4-marketing-analysis.ga4_analysis.page_label`(entry_page) AS entry_page_label
FROM agg;

-- ── WHAT IT PRODUCES ─────────────────────────────────────────
-- 360,129 rows, one per session, 1 Nov 2020 to 31 Jan 2021.
--
-- IDENTITY AND TIME
--   session_id          user_pseudo_id + ga_session_id
--   user_pseudo_id      the cookie, not a person
--   session_date        earliest event date in the session
--   session_month       'YYYY-MM' of session_date
--
-- VOLUME AND ENGAGEMENT
--   total_events            all events in the session
--   page_views              page_view events
--   is_engaged              session_engaged reached '1' at least once
--   total_engagement_msec   sum of engagement_time_msec
--   engagement_events       user_engagement events
--
-- COVERAGE FLAGS
--   has_session_start   session_start fired. 1.46% of sessions
--                       lack it, and they are longer and convert
--                       better than average, so it is a delivery
--                       gap and not a filter
--   is_first_visit      first_visit fired
--
-- FUNNEL FLAGS, each 1 if the event ever fired in the session
--   reached_view_item, reached_cart, reached_checkout,
--   reached_shipping, reached_payment, purchased
--   These are independent flags. A session can carry a later flag
--   without an earlier one, and 41.3% of orders do
--
-- COMMERCE AND CONTEXT
--   revenue             purchase_revenue_in_usd summed over
--                       purchase events. Some sessions fire more
--                       than one purchase, which summing handles
--   device_category, country
--
-- ACQUISITION
--   session_source, session_medium
--                       first non-null value in event_timestamp
--                       order. session_start carries no source in
--                       this export, so first-event attribution is
--                       not available
--   entry_page          first non-null page_location, same rule
--
-- DERIVED IN THE OUTER SELECT
--   channel             CASE over source and medium
--   user_type           New if first_visit fired, else Returning
--   is_bounce_ga4       GA4's definition, is_engaged = 0
--   is_bounce_pageview  one page view or fewer, no engagement event
--   is_bounce_10sec     under ten seconds of engagement
--   entry_path          entry_page through page_path, for grouping
--   entry_page_label    entry_page through page_label, for display
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- STATEMENT 4: VERIFY THE BUILD
-- ══════════════════════════════════════════════════════════════
-- PURPOSE: Confirm grain, totals and that the URL normalisation
-- behaved. Run both parts before touching the numbered files
-- ─────────────────────────────────────────────────────────────

-- 4a. Grain and totals
SELECT
    COUNT(*)                                        AS row,
    COUNT(DISTINCT session_id)                      AS distinct_sessions,
    COUNT(DISTINCT user_pseudo_id)                  AS distinct_users,
    COUNTIF(purchased = 1)                          AS purchases,
    ROUND(SUM(revenue), 2)                          AS revenue,
    MIN(session_date)                               AS first_date,
    MAX(session_date)                               AS last_date,
    COUNTIF(entry_path IS NULL OR entry_page_label IS NULL) AS unlabelled_rows
FROM `ga4-marketing-analysis.ga4_analysis.sessions`;

-- 4b. URL variants collapsing
SELECT
    entry_page_label,
    entry_path,
    COUNT(DISTINCT entry_page) AS distinct_urls_collapsed,
    COUNT(*)                   AS sessions
FROM `ga4-marketing-analysis.ga4_analysis.sessions`
GROUP BY entry_page_label, entry_path
ORDER BY sessions DESC
LIMIT 10;

-- ── RESULT ───────────────────────────────────────────────────
-- 4a
-- rows      distinct_sessions  distinct_users  purchases   revenue
-- 360,129             360,129         270,154      4,848  $362,165
-- first_date 2020-11-01 · last_date 2021-01-31 · unlabelled_rows 0
--
-- 4b
-- label                             path                              URLs  sessions
-- Homepage                          (empty)                              9   161,673
-- Apparel                           /google+redesign/apparel             1    40,174
-- Shop By Brand > YouTube           /google+redesign/shop+by+brand/…     6    25,300
-- Apparel > Google Dino Game Tee    /google+redesign/apparel/google+…    3    18,793
-- Store home                        /store.html                          3    14,972
-- Apparel > Mens > Mens T Shirts    /google+redesign/apparel/mens/…      3     7,237
-- Lifestyle > Drinkware             /google+redesign/lifestyle/drink…    2     5,746
-- Apparel > Mens                    /google+redesign/apparel/mens        4     5,502
-- Sign in                           /signin.html                         1     4,313
-- Lifestyle > Bags                  /google+redesign/lifestyle/bags      3     4,183
-- ─────────────────────────────────────────────────────────────

-- ── WHAT IT MEANS ────────────────────────────────────────────
--   1. Grain holds: 360,129 rows and 360,129 distinct session_ids
--      with no collisions, so COUNT(*) is a session count
--      everywhere downstream. 270,154 distinct users across those
--      sessions
--   2. Every session carries a path and a label; zero unlabelled
--      rows means no entry_page value defeated the normalisation
--   3. The homepage is served by nine distinct URLs, not the three
--      hostnames it appears to have. Hostname, letter case, query
--      string and trailing slash each split it further. Merged it
--      is 161,673 sessions
--   4. Fragmentation is not confined to the homepage. Nine of the
--      ten largest entry points collapse more than one URL, and
--      the YouTube brand page collapses six. Any page-level report
--      built on raw page_location understates every page it
--      touches
--   5. A caution on the label: 10_landing_page_analysis QUERY 1
--      groups 3,085 sessions under 'New' while QUERY 3 finds 3,084
--      under the path /google+redesign/new. One session reaches
--      the same label by a different path, which is exactly why
--      entry_path is the join key and entry_page_label is only for
--      display
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- KNOWN DEFECT NOT CORRECTED IN THIS BUILD
-- ══════════════════════════════════════════════════════════════
-- is_engaged reads session_engaged out of value.string_value only.
-- The export also stores that parameter as an integer on 6.04% of
-- November events, 7.16% of December and 9.01% of January, and
-- those events are currently discarded. The share grows month by
-- month, so the omission also skews the bounce series.
-- 00_data_quality_checks QUERY 7 measures it.
--
-- The correction is two edits to STATEMENT 3. In the events CTE,
-- add:
--
--   (SELECT value.int_value FROM UNNEST(event_params)
--    WHERE key = 'session_engaged') AS session_engaged_int,
--
-- and in the agg CTE, replace the is_engaged line with:
--
--   MAX(IF(session_engaged = '1'
--       OR session_engaged_int = 1, 1, 0)) AS is_engaged,
--
-- Applying it changes is_bounce_ga4, so every bounce figure
-- recorded in 03, 04, 05, 07, 08, 10, 11 and 12 becomes stale,
-- along with the 44.37% and 32.82% in the README. It is a correct
-- fix and it needs its own re-run pass rather than being folded
-- into a build change made for another reason.
-- ─────────────────────────────────────────────────────────────