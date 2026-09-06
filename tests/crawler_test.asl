(module asl-crawler/tests/crawler-test
  :d "Unit verification test suite for stealth crawler, GoogleBot impersonation, browser detection, and pool."
  :x [run-tests]
  :i [(stealth :a st)
      (browser-detector :a bd)
      (crawler :a cr)])

(df test-googlebot-profile [] -> Bool
  (let [(p (st/googlebot-profile))
        (hdrs (st/build-headers p))]
    (and (string-contains? (.-user-agent p) "Googlebot")
         (> (list-length hdrs) 4))))

(df test-chrome-stealth-profile [] -> Bool
  (let [(p (st/chrome-profile))
        (hdrs (st/build-headers p))
        (args (st/curl-headers hdrs))]
    (and (string-contains? (.-sec-ch-ua p) "Google Chrome")
         (and (> (list-length hdrs) 5)
              (> (list-length args) 10)))))

(df test-browser-candidates [] -> Bool
  (let [(mac-cands (bd/macos-browsers))
        (linux-cands (bd/linux-browsers))]
    (and (= (list-length mac-cands) 5)
         (= (list-length linux-cands) 4))))

(df test-cdp-launch-args [] -> Bool
  (let [(cand (bd/make-candidate "Chrome" "/Applications/Google Chrome.app" (bd/kind-chrome) "macos"))
        (args (bd/cdp-args cand 9222 "https://example.com" true))]
    (and (list-contains? args "--headless=new")
         (and (list-contains? args "--remote-debugging-port=9222")
              (list-contains? args "https://example.com")))))

(df test-curl-fetch-args [] -> Bool
  (let [(job (cr/make-crawl-job "https://news.ycombinator.com" (st/googlebot-profile)))
        (args (cr/curl-args job))]
    (and (list-contains? args "-sSL")
         (and (list-contains? args "https://news.ycombinator.com")
              (list-contains? args "--compressed")))))

(df test-crawl-results [] -> Bool
  (let [(succ (cr/crawl-ok "https://example.com" 200 "<html><body>ok</body></html>"))
        (fail (cr/crawl-err "https://example.com" "Connection timed out"))]
    (and (cr/status-ok? (.-status-code succ))
         (and (.-is-success succ)
              (and (not (.-is-success fail))
                   (= (.-byte-count succ) 30))))))

(df test-crawl-to-doc [] -> Bool
  (let [(succ (cr/crawl-ok "https://example.com" 200 "<html><head><title>Test Page</title></head><body>Hello world</body></html>"))
        (doc (cr/crawl-doc succ))
        (asn (cr/crawl-asn succ))]
    (and (= (.-title doc) "Test Page")
         (and (string-contains? (.-content doc) "Hello world")
              (string-contains? asn ":doc :title \"Test Page\"")))))

(df test-crawl-pool [] -> Bool
  (let [(pool (cr/make-pool 4 (st/safari-profile)))
        (jobs (cr/pool-jobs pool (list "https://a.com" "https://b.com")))]
    (and (= (.-concurrency pool) 4)
         (= (list-length jobs) 2))))

(df run-tests [] -> Bool
  (and (test-googlebot-profile)
       (and (test-chrome-stealth-profile)
            (and (test-browser-candidates)
                 (and (test-cdp-launch-args)
                      (and (test-curl-fetch-args)
                           (and (test-crawl-results)
                                (and (test-crawl-to-doc)
                                     (test-crawl-pool)))))))))

