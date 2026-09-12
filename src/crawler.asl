(module asl-crawler/crawler
  :d "Parallel stealth web crawler pipeline, HTTP fetch generator, and pool in pure ASL."
  :x [CrawlJob CrawlResult CrawlPool
      crawl-job make-crawl-job make-pool pool-jobs
      crawl-ok crawl-err status-ok? curl-args crawl-doc crawl-asn
      make-success-result make-failure-result is-successful-status build-curl-fetch-args
      crawl-to-doc crawl-to-asn
      is-waf-blocked? cache-fallback-jobs strip-cache-decorations
      normalize-crawl-response crawl-with-fallback]
  :i [(stealth :a st)
      (asl-text/text :a txt)])

(dfs CrawlPool
  (:f concurrency I64 "Parallel worker concurrency limit")
  (:f timeout-ms I64 "Default network timeout in milliseconds")
  (:f profile st/StealthProfile "Default stealth anti-fingerprinting profile"))

(dfs CrawlJob
  (:f url Str "Target web page URL")
  (:f profile st/StealthProfile "Stealth anti-fingerprinting profile")
  (:f timeout-ms I64 "Network timeout in milliseconds")
  (:f follow-redirects Bool "Allow following 301/302 HTTP redirects")
  (:f max-retries I64 "Retry attempts on network failure"))

(dfs CrawlResult
  (:f url Str "Target URL")
  (:f status-code I64 "HTTP response status code")
  (:f raw-html Str "Raw fetched HTML content")
  (:f char-count I64 "Content payload character length")
  (:f is-success Bool "True if request succeeded with 2xx status")
  (:f error-msg Str "Error description if failed"))

(df crawl-job [(url Str) (profile st/StealthProfile)] -> CrawlJob
  :d "Constructs standard CrawlJob with 15s timeout and redirect following."
  (CrawlJob
    :url url
    :profile profile
    :timeout-ms 15000
    :follow-redirects true
    :max-retries 2))

(df make-crawl-job [(url Str) (profile st/StealthProfile)] -> CrawlJob
  (crawl-job url profile))


(df make-pool [(concurrency I64) (profile st/StealthProfile)] -> CrawlPool
  :d "Constructs parallel in-memory CrawlPool for concurrent fetch tasks."
  (CrawlPool
    :concurrency concurrency
    :timeout-ms 15000
    :profile profile))

(df pool-jobs [(pool CrawlPool) (urls (List Str))] -> (List CrawlJob)
  :d "Batches URLs into CrawlJobs bound to pool profile and timeout."
  (map (fn [(url Str)] -> CrawlJob
         (CrawlJob
           :url url
           :profile (.-profile pool)
           :timeout-ms (.-timeout-ms pool)
           :follow-redirects true
           :max-retries 2))
       urls))

(df crawl-ok [(url Str) (status-code I64) (raw-html Str)] -> CrawlResult
  (CrawlResult
    :url url
    :status-code status-code
    :raw-html raw-html
    :char-count (string-length raw-html)
    :is-success true
    :error-msg ""))

(df crawl-err [(url Str) (error-msg Str)] -> CrawlResult
  (CrawlResult
    :url url
    :status-code 0
    :raw-html ""
    :char-count 0
    :is-success false
    :error-msg error-msg))

(df status-ok? [(status I64)] -> Bool
  (and (>= status 200) (< status 300)))

(df curl-args [(job CrawlJob)] -> (List Str)
  :d "Builds safe, injection-free argument list for executing curl with stealth profile."
  (let [(timeout-sec (/ (.-timeout-ms job) 1000))
        (headers (st/build-headers (.-profile job)))
        (header-args (st/curl-headers headers))
        (base (list "-sSL"
                    "--max-time" (string-from-int64 timeout-sec)
                    "--compressed"
                    (.-url job)))]
    (list-append header-args base)))

(df crawl-doc [(result CrawlResult)] -> txt/ExtractedDoc
  :d "Extracts structured ExtractedDoc from crawl result using asl-text HTML parser."
  (if (.-is-success result)
      (txt/extract-html (.-raw-html result) (.-url result))
      (txt/ExtractedDoc
        :title (.-url result)
        :content ""
        :format "error"
        :source (.-url result)
        :char-count 0)))

(df crawl-asn [(result CrawlResult)] -> Str
  :d "Serializes crawled HTML payload directly into compact canonical ASN document expression."
  (let [(doc (crawl-doc result))]
    (txt/doc-to-asn doc)))

(df make-success-result [(url Str) (status-code I64) (raw-html Str)] -> CrawlResult
  (crawl-ok url status-code raw-html))

(df make-failure-result [(url Str) (error-msg Str)] -> CrawlResult
  (crawl-err url error-msg))

(df is-successful-status [(status I64)] -> Bool
  (status-ok? status))

(df build-curl-fetch-args [(job CrawlJob)] -> (List Str)
  (curl-args job))

(df crawl-to-doc [(result CrawlResult)] -> txt/ExtractedDoc
  (crawl-doc result))

(df crawl-to-asn [(result CrawlResult)] -> Str
  (crawl-asn result))

(df is-waf-blocked? [(status-code I64) (body Str)] -> Bool
  :d "Detects Cloudflare, DataDome, Akamai, or Incapsula challenge pages."
  (or (and (or (= status-code 403) (= status-code 503))
           (or (string-contains? body "Just a moment...")
               (or (string-contains? body "Checking your browser")
                   (or (string-contains? body "Attention Required! | Cloudflare")
                       (string-contains? body "cf-chl-bypass")))))
      (or (= status-code 429)
          (string-contains? body "Please complete the security check"))))

(df cache-fallback-jobs [(target-url Str)] -> (List CrawlJob)
  :d "Generates candidate CrawlJobs targeting public web archive mirrors."
  (list (crawl-job (str "https://web.archive.org/web/" target-url) (st/chrome-profile))
        (crawl-job (str "https://archive.is/newest/" target-url) (st/chrome-profile))
        (crawl-job (str "https://webcache.googleusercontent.com/search?q=cache:" target-url) (st/googlebot-profile))))

(df strip-between-markers [(s Str) (start-tag Str) (end-tag Str)] -> Str
  :d "Strips substring bounded by start-tag and end-tag."
  (if (and (string-contains? s start-tag)
           (string-contains? s end-tag))
      (mt (string-index-of s start-tag)
        ((some s-idx)
         (mt (string-index-of s end-tag)
           ((some e-idx)
            (if (>= e-idx s-idx)
                (let [(end-pos (+ e-idx (string-length end-tag)))
                      (prefix (option-or (string-slice s 0 s-idx) ""))
                      (suffix (option-or (string-slice s end-pos (string-length s)) ""))]
                  (str prefix suffix))
                s))
           ((none) s)))
        ((none) s))
      s))

(df strip-cache-decorations [(html Str)] -> Str
  :d "Removes Wayback Machine toolbar and Google Cache notice banners from snapshot HTML."
  (let [(s1 (strip-between-markers html "<!-- BEGIN WAYBACK TOOLBAR INSERT -->" "<!-- END WAYBACK TOOLBAR INSERT -->"))
        (s2 (strip-between-markers s1 "<div id=\"wm-ipp-base\"" "</div>"))
        (s3 (strip-between-markers s2 "<div id=\"google-cache-hdr\"" "</div>"))]
    (string-trim s3)))

(df normalize-crawl-response [(result CrawlResult)] -> CrawlResult
  :d "Strips injected public cache banners and normalizes raw HTML in CrawlResult."
  (if (.-is-success result)
      (let [(cleaned (strip-cache-decorations (.-raw-html result)))]
        (CrawlResult
          :url (.-url result)
          :status-code (.-status-code result)
          :raw-html cleaned
          :char-count (string-length cleaned)
          :is-success (.-is-success result)
          :error-msg (.-error-msg result)))
      result))

(df crawl-with-fallback [(url Str) (primary-result CrawlResult) (fallback-html Str)] -> CrawlResult
  :d "Falls back to cached snapshot HTML if primary request encountered WAF challenge."
  (let [(code (if (= (.-status-code primary-result) 0)
                  (if (string-contains? (.-error-msg primary-result) "403")
                      403
                      (if (string-contains? (.-error-msg primary-result) "503")
                          503
                          (if (string-contains? (.-error-msg primary-result) "429")
                              429
                              0)))
                  (.-status-code primary-result)))
        (body (if (> (string-length (.-raw-html primary-result)) 0)
                  (.-raw-html primary-result)
                  (.-error-msg primary-result)))]
    (if (and (not (.-is-success primary-result))
             (is-waf-blocked? code body))
        (crawl-ok url 200 (strip-cache-decorations fallback-html))
        primary-result)))
