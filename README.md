# @genseam/asl-crawler (Parallel Stealth Web Crawler)

High-concurrency parallel stealth web crawling engine, GoogleBot/browser impersonator, and system browser detector in pure AgentScript (ASL).

## Key Capabilities
- **Parallel Crawl Pool**: In-memory concurrent request dispatcher (`make-pool`, `pool-jobs`).
- **Stealth Anti-Fingerprinting Profiles**: Realistic User-Agent, `Sec-CH-UA`, client hints, and navigation headers (`chrome-profile`, `safari-profile`).
- **GoogleBot Impersonator Mode**: Bypass restrictive paywalls and access search-optimized public pages (`googlebot-profile`).
- **System Browser Discovery**: Auto-detects locally installed Chrome, Brave, Chromium, Edge, and Safari on macOS and Linux (`macos-browsers`, `linux-browsers`).
- **CDP Headless Launch Vectors**: Generates injection-free process arguments for automated headless browser page scraping (`cdp-args`).
- **High-Performance Curl Vectors**: Compiles stealth HTTP requests into safe curl argument lists with automatic gzip/brotli compression (`curl-args`, `curl-headers`).
- **Zero Foreign Runtime**: 100% pure AgentScript (`.asl`).

## Usage
```scheme
(import (asl-crawler/stealth :a st))
(import (asl-crawler/crawler :a cr))

;; 1. Construct GoogleBot crawl job
(let [(profile (st/googlebot-profile))
      (job (cr/crawl-job "https://example.com" profile))
      (args (cr/curl-args job))]
  ;; Execute via asl-sh or harness
  args)

;; 2. Parallel Crawl Pool
(let [(pool (cr/make-pool 8 (st/chrome-profile)))
      (jobs (cr/pool-jobs pool (list "https://a.com" "https://b.com")))]
  jobs)
```

