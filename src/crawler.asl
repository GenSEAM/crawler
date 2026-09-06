(module asl-crawler/crawler
  :d "Parallel stealth web crawler pipeline, HTTP fetch generator, and pool in pure ASL."
  :x [CrawlJob CrawlResult CrawlPool
      crawl-job make-crawl-job make-pool pool-jobs
      crawl-ok crawl-err status-ok? curl-args crawl-doc crawl-asn
      make-success-result make-failure-result is-successful-status build-curl-fetch-args]
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
  (:f byte-count I64 "Content payload byte length")
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
    :byte-count (string-length raw-html)
    :is-success true
    :error-msg ""))

(df crawl-err [(url Str) (error-msg Str)] -> CrawlResult
  (CrawlResult
    :url url
    :status-code 0
    :raw-html ""
    :byte-count 0
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
