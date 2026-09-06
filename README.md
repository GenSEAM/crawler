# @genseam/asl-crawler (Native AgentScript Stealth Crawler)

Autonomous, stealth web crawling engine, GoogleBot/browser impersonator, and system browser detector in pure AgentScript (ASL).

## Key Capabilities
- **Stealth Anti-Fingerprinting Profiles**: Realistic User-Agent, `Sec-CH-UA`, client hints, and navigation headers (`make-chrome-profile`, `make-safari-profile`).
- **GoogleBot Impersonator Mode**: Bypass restrictive paywalls and access search-optimized public pages (`make-googlebot-profile`).
- **System Browser Discovery**: Auto-detects locally installed Chrome, Brave, Chromium, Edge, and Safari on macOS and Linux (`detect-system-browsers`).
- **CDP Headless Launch Vectors**: Generates injection-free process arguments for automated headless browser page scraping (`build-cdp-launch-args`).
- **High-Performance Curl Vectors**: Compiles stealth HTTP requests into safe curl argument lists with automatic gzip/brotli compression (`build-curl-fetch-args`).
- **Zero Foreign Runtime**: 100% pure AgentScript (`.asl`).

## Usage
```scheme
(import (asl-crawler/stealth :a st))
(import (asl-crawler/crawler :a cr))

;; 1. Construct GoogleBot crawl job
(let [(profile (st/make-googlebot-profile))
      (job (cr/make-crawl-job "https://example.com" profile))
      (args (cr/build-curl-fetch-args job))]
  ;; Execute via asl-sh or harness
  args)
```
