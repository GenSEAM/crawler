(module asl-crawler/tests/crawler-test
  :d "Unit verification test suite for stealth crawler, GoogleBot impersonation, browser detection, and pool."
  :x [test-googlebot-profile
      test-chrome-stealth-profile
      test-browser-candidates
      test-cdp-launch-args
      test-curl-fetch-args
      test-crawl-results
      test-crawl-to-doc
      test-crawl-pool
      run-tests]
  :i [(stealth :a st)
      (browser-detector :a bd)
      (crawler :a cr)])

(df test-googlebot-profile [] -> Bool
  (let [(p (st/googlebot-profile))
        (hdrs (st/build-headers p))]
    (assert (string-contains? (.-user-agent p) "Googlebot") "user-agent must contain Googlebot")
    (assert (> (list-length hdrs) 4) "headers length must exceed 4")
    true))

(df test-chrome-stealth-profile [] -> Bool
  (let [(p (st/chrome-profile))
        (hdrs (st/build-headers p))
        (args (st/curl-headers hdrs))]
    (assert (string-contains? (.-sec-ch-ua p) "Google Chrome") "sec-ch-ua must contain Google Chrome")
    (assert (> (list-length hdrs) 5) "chrome headers length must exceed 5")
    (assert (> (list-length args) 10) "curl header args length must exceed 10")
    true))

(df test-browser-candidates [] -> Bool
  (let [(mac-cands (bd/macos-browsers))
        (linux-cands (bd/linux-browsers))]
    (assert (= (list-length mac-cands) 5) "mac candidates count must be 5")
    (assert (= (list-length linux-cands) 4) "linux candidates count must be 4")
    true))

(df test-cdp-launch-args [] -> Bool
  (let [(cand (bd/make-candidate "Chrome" "/Applications/Google Chrome.app" (bd/kind-chrome) "macos"))
        (args (bd/cdp-args cand 9222 "https://example.com" true))]
    (assert (list-contains? args "--headless=new") "headless flag missing")
    (assert (list-contains? args "--remote-debugging-port=9222") "debugging port missing")
    (assert (list-contains? args "https://example.com") "target url missing")
    true))

(df test-curl-fetch-args [] -> Bool
  (let [(job (cr/make-crawl-job "https://news.ycombinator.com" (st/googlebot-profile)))
        (args (cr/curl-args job))]
    (assert (list-contains? args "-sSL") "sSL flag missing")
    (assert (list-contains? args "https://news.ycombinator.com") "target url missing")
    (assert (list-contains? args "--compressed") "compressed flag missing")
    true))

(df test-crawl-results [] -> Bool
  (let [(succ (cr/crawl-ok "https://example.com" 200 "<html><body>ok</body></html>"))
        (fail (cr/crawl-err "https://example.com" "Connection timed out"))]
    (assert (cr/status-ok? (.-status-code succ)) "status should be ok")
    (assert (.-is-success succ) "succ should be success")
    (assert (not (.-is-success fail)) "fail should not be success")
    (assert (= (.-byte-count succ) 30) "byte count mismatch")
    true))

(df test-crawl-to-doc [] -> Bool
  (let [(succ (cr/crawl-ok "https://example.com" 200 "<html><head><title>Test Page</title></head><body>Hello world</body></html>"))
        (doc (cr/crawl-doc succ))
        (asn (cr/crawl-asn succ))]
    (assert (= (.-title doc) "Test Page") "doc title mismatch")
    (assert (string-contains? (.-content doc) "Hello world") "doc content mismatch")
    (assert (string-contains? asn ":doc :title \"Test Page\"") "asn format mismatch")
    true))

(df test-crawl-pool [] -> Bool
  (let [(pool (cr/make-pool 4 (st/safari-profile)))
        (jobs (cr/pool-jobs pool (list "https://a.com" "https://b.com")))]
    (assert (= (.-concurrency pool) 4) "concurrency mismatch")
    (assert (= (list-length jobs) 2) "jobs count mismatch")
    true))

(df run-tests [] -> Bool
  (and (test-googlebot-profile)
       (test-chrome-stealth-profile)
       (test-browser-candidates)
       (test-cdp-launch-args)
       (test-curl-fetch-args)
       (test-crawl-results)
       (test-crawl-to-doc)
       (test-crawl-pool)))
