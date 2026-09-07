(module asl-crawler/stealth-crawler-test
  :d "Unit tests for Stealth Profiles, Extension CORS Relay, WAF Challenge Detection, Public Cache Failover, and Crawl Normalization."
  :x [test-stealth-profiles
      test-extension-relay-bridge
      test-waf-challenge-detection
      test-cache-fallback-generation
      test-cache-decorations-strip
      test-crawl-with-fallback
      test-normalize-crawl-response
      run-tests]
  :i [(stealth :a st)
      (crawler :a cr)])

(df test-stealth-profiles [] -> Bool
  :d "Verifies modern rotating User-Agents, Client Hints, and navigation headers."
  (let [(g-prof (st/make-googlebot-profile))
        (c-prof (st/make-chrome-profile))
        (s-prof (st/make-safari-profile))]
    (assert (string-contains? (.-user-agent g-prof) "Googlebot") "googlebot ua mismatch")
    (assert (string-contains? (.-user-agent c-prof) "Chrome/128") "chrome ua mismatch")
    (assert (string-contains? (.-user-agent s-prof) "Safari") "safari ua mismatch")
    (assert (string-contains? (.-sec-ch-ua c-prof) "Google Chrome") "client hints sec-ch-ua mismatch")
    (let [(hdrs (st/build-headers c-prof))
          (ch-hdrs (filter (fn [(h Str)] -> Bool (string-starts-with? h "Sec-CH-UA:")) hdrs))]
      (assert (> (list-length hdrs) 5) "header list length too short")
      (assert (> (list-length ch-hdrs) 0) "sec-ch-ua header missing"))
    true))

(df test-extension-relay-bridge [] -> Bool
  :d "Verifies WebExtension cross-origin relay message formatting and response handling."
  (let [(req (st/format-relay-request "https://protected-origin.com/api" "GET" (list "Accept: application/json") ""))
        (resp (st/parse-relay-response 200 (list "Content-Type: application/json") "{\"status\":\"ok\"}"))
        (err-resp (st/parse-relay-response 403 (list) "Forbidden"))]
    (assert (= (.-action req) "asl_fetch_relay") "action must be asl_fetch_relay")
    (assert (= (.-method req) "GET") "method must be GET")
    (assert (= (.-url req) "https://protected-origin.com/api") "url mismatch")
    (assert (= (.-success resp) true) "200 response must be marked success")
    (assert (= (.-success err-resp) false) "403 response must be marked failure")
    true))

(df test-waf-challenge-detection [] -> Bool
  :d "Verifies detection of Cloudflare, DataDome, and WAF interstitial challenges"
  (let [(cf-page "<!DOCTYPE html><html><title>Just a moment...</title><body>Checking your browser before accessing site.</body></html>")
        (cf-page2 "<html><body>Attention Required! | Cloudflare cf-chl-bypass</body></html>")
        (rate-limit-page "Too many requests. Please complete the security check.")
        (clean-page "<!DOCTYPE html><html><head><title>Normal Site</title></head><body><h1>Welcome</h1></body></html>")]
    (assert (= (cr/is-waf-blocked? 403 cf-page) true) "cloudflare 403 must be detected")
    (assert (= (cr/is-waf-blocked? 503 cf-page2) true) "cloudflare 503 must be detected")
    (assert (= (cr/is-waf-blocked? 429 rate-limit-page) true) "429 challenge must be detected")
    (assert (= (cr/is-waf-blocked? 200 clean-page) false) "clean 200 page must not be flagged as waf")
    (assert (= (cr/is-waf-blocked? 404 "Page not found") false) "standard 404 must not be flagged as waf")
    true))

(df test-cache-fallback-generation [] -> Bool
  :d "Verifies generation of candidate CrawlJobs targeting public web archive mirrors."
  (let [(target "https://news.ycombinator.com/item?id=42")
        (jobs (cr/cache-fallback-jobs target))]
    (assert (= (list-length jobs) 3) "cache fallback jobs must contain 3 targets")
    (let [(j1 (option-or (list-get jobs 0) (cr/crawl-job "" (st/chrome-profile))))
          (j2 (option-or (list-get jobs 1) (cr/crawl-job "" (st/chrome-profile))))
          (j3 (option-or (list-get jobs 2) (cr/crawl-job "" (st/chrome-profile))))]
      (assert (string-starts-with? (.-url j1) "https://web.archive.org/web/") "wayback machine prefix mismatch")
      (assert (string-starts-with? (.-url j2) "https://archive.is/newest/") "archive.today prefix mismatch")
      (assert (string-starts-with? (.-url j3) "https://webcache.googleusercontent.com/search?q=cache:") "google cache prefix mismatch")
      (assert (string-contains? (.-url j1) target) "target url missing from wayback job")
      (assert (string-contains? (.-url j2) target) "target url missing from archive.today job")
      (assert (string-contains? (.-url j3) target) "target url missing from google cache job"))
    true))

(df test-cache-decorations-strip [] -> Bool
  :d "Verifies stripping of Wayback Machine toolbars and injected banners."
  (let [(injected "<!-- BEGIN WAYBACK TOOLBAR INSERT --><div>Toolbar</div><!-- END WAYBACK TOOLBAR INSERT --><main>Actual content</main>")
        (stripped (cr/strip-cache-decorations injected))]
    (assert (not (string-contains? stripped "BEGIN WAYBACK TOOLBAR INSERT")) "wayback banner must be stripped")
    (assert (string-contains? stripped "<main>Actual content</main>") "actual content must be preserved")
    true))

(df test-crawl-with-fallback [] -> Bool
  :d "Verifies automatic fallback to cached snapshot on primary WAF challenge block."
  (let [(waf-result (cr/crawl-err "https://blocked.com" "403 Forbidden Cloudflare Just a moment..."))
        (cached-html "<html><body>Clean cached article from Wayback Machine</body></html>")
        (resolved (cr/crawl-with-fallback "https://blocked.com" waf-result cached-html))]
    (assert (= (.-is-success resolved) true) "fallback result must be marked success")
    (assert (= (.-status-code resolved) 200) "fallback status must be 200")
    (assert (string-contains? (.-raw-html resolved) "Clean cached article") "cached html must be populated")
    true))

(df test-normalize-crawl-response [] -> Bool
  :d "Verifies normalization of CrawlResult by stripping injected cache decorations."
  (let [(dirty-html "<!-- BEGIN WAYBACK TOOLBAR INSERT --><div>Banner</div><!-- END WAYBACK TOOLBAR INSERT --><article>Snapshot Body</article>")
        (succ-result (cr/crawl-ok "https://web.archive.org/web/test" 200 dirty-html))
        (norm-result (cr/normalize-crawl-response succ-result))
        (err-result (cr/crawl-err "https://failed.com" "Connection timed out"))
        (norm-err (cr/normalize-crawl-response err-result))]
    (assert (= (.-is-success norm-result) true) "normalized result must remain success")
    (assert (not (string-contains? (.-raw-html norm-result) "BEGIN WAYBACK TOOLBAR INSERT")) "toolbar must be stripped")
    (assert (string-contains? (.-raw-html norm-result) "<article>Snapshot Body</article>") "clean content must be preserved")
    (assert (= (.-is-success norm-err) false) "error result must remain error")
    (assert (= (.-error-msg norm-err) "Connection timed out") "error message must be preserved")
    true))

(df run-tests [] -> Bool
  :d "Executes all stealth crawler test cases."
  (and (test-stealth-profiles)
       (test-extension-relay-bridge)
       (test-waf-challenge-detection)
       (test-cache-fallback-generation)
       (test-cache-decorations-strip)
       (test-crawl-with-fallback)
       (test-normalize-crawl-response)))
