-- ══════════════════════════════════════════════════════════════
-- FILE: 10_landing_page_analysis.sql
-- PROJECT: GA4 Digital Marketing Funnel Analysis
-- DESCRIPTION: Identifies top visited pages and top entry pages
--              to understand user navigation patterns and where
--              users first land when they visit the store
-- ══════════════════════════════════════════════════════════════

-- ── BUSINESS CONTEXT ─────────────────────────────────────────
-- Landing page analysis answers two questions:
--   1. Which pages get the most total traffic?
--   2. Which pages do users land on first (entry pages)?
--
-- The difference matters because:
--   - Top visited pages show what users navigate TO
--   - Top entry pages show where users START their journey
--   - Pages that are highly visited but rarely entry pages
--     are destination pages (e.g. checkout) reached through
--     the funnel rather than direct arrival
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 1: TOP 10 MOST VISITED PAGES
-- ══════════════════════════════════════════════════════════════
-- Counts all events per page_location across all event types
-- to find the most frequently visited URLs in the dataset
-- ─────────────────────────────────────────────────────────────

SELECT
    page_location,
    COUNT(user_pseudo_id) AS total_visits
FROM `ga4_analysis.master_events`
GROUP BY page_location
ORDER BY total_visits DESC
LIMIT 10;

-- ── RESULTS ──────────────────────────────────────────────────
-- page_location                                          visits
-- /Google+Redesign/Apparel (category page)               6,169
-- / (homepage - shop.googlemerchandisestore.com)          5,360
-- / (homepage - googlemerchandisestore.com)               3,431
-- /Google+Redesign/Shop+by+Brand/YouTube                  3,273
-- /store.html                                             2,919
-- /yourinfo.html (checkout info page)                     2,350
-- /Google+Redesign/Apparel/Mens                           2,211
-- / (homepage - www.googlemerchandisestore.com)           1,910
-- /Google+Redesign/Clearance                              1,827
-- /Google+Redesign/Apparel/Google+Dino+Game+Tee           1,583
--
-- KEY INSIGHTS:
--   1. Apparel category is most visited (6,169) — confirms
--      Apparel as the dominant product category
--   2. Three homepage URLs (shop., googlemerchandise., www.)
--      appear separately — should be consolidated via URL
--      normalisation for cleaner analytics
--   3. yourinfo.html (checkout page) at #6 — heavily visited
--      as users progress through the funnel
--   4. YouTube brand page at #4 — strong brand channel presence
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: TOP 10 ENTRY PAGES
-- ══════════════════════════════════════════════════════════════
-- Entry page = the first page a user sees in their session
-- We use session_start events because GA4 fires session_start
-- at the very beginning of every session — the page_location
-- on session_start IS the entry page for that session
-- ─────────────────────────────────────────────────────────────

SELECT
    page_location,
    COUNT(user_pseudo_id) AS sessions_entering_here
FROM `ga4_analysis.master_events`
WHERE event_name = 'session_start'
GROUP BY page_location
ORDER BY sessions_entering_here DESC
LIMIT 10;

-- ── RESULTS ──────────────────────────────────────────────────
-- page_location                                          sessions
-- / (homepage - shop.googlemerchandisestore.com)          5,360
-- /Google+Redesign/Apparel (category page)                5,076
-- / (homepage - googlemerchandisestore.com)               3,431
-- /Google+Redesign/Shop+by+Brand/YouTube                  2,378
-- / (homepage - www.googlemerchandisestore.com)           1,910
-- /store.html                                             1,603
-- /Google+Redesign/Apparel/Google+Dino+Game+Tee           1,397
-- /Google+Redesign/Apparel/Mens/Mens+T+Shirts               647
-- /Google+Redesign/Lifestyle/Drinkware                      571
-- /Google+Redesign/Lifestyle/Bags                           424
--
-- KEY INSIGHTS:
--   1. Homepage is the #1 entry page (5,360 sessions) but #2
--      for total visits — users start at homepage then navigate
--      to Apparel, not the other way around
--   2. Apparel category is the #2 entry page (5,076 sessions)
--      — significant traffic arrives with purchase intent
--      already knowing they want Apparel
--   3. yourinfo.html (checkout page) disappears from entry pages
--      completely — nobody lands on checkout directly, they
--      navigate there through the funnel (expected behaviour)
--   4. Drinkware and Bags appear in entry pages but not in top
--      visited pages — these category visitors arrive directly
--      from external links but don't browse widely
-- ─────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
-- COMPARISON SUMMARY
-- ══════════════════════════════════════════════════════════════
-- Page                    Top Visited    Top Entry    Difference
-- Apparel category        #1 (6,169)     #2 (5,076)   navigated TO
-- Homepage (shop.)        #2 (5,360)     #1 (5,360)   start point
-- YouTube brand           #4 (3,273)     #4 (2,378)   both entry & dest
-- yourinfo.html           #6 (2,350)     NOT in top   pure funnel page
-- Dino Game Tee           #10 (1,583)    #7 (1,397)   direct product entry
--
-- BUSINESS RECOMMENDATION:
--   The three separate homepage URLs should be consolidated
--   via URL normalisation or redirects. Fragmented homepage
--   tracking inflates session counts and makes entry page
--   analysis harder to interpret cleanly.
-- ─────────────────────────────────────────────────────────────