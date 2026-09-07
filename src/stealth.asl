(module asl-crawler/stealth
  :d "Stealth identity profiles, GoogleBot impersonator, and browser anti-fingerprinting headers in pure ASL."
  :x [StealthKind StealthProfile
      stealth-googlebot stealth-chrome stealth-safari stealth-mobile
      googlebot-profile chrome-profile safari-profile curl-headers
      make-googlebot-profile make-chrome-profile make-safari-profile make-profile
      build-headers format-curl-header-args
      ExtensionRelayMessage ExtensionRelayResponse
      format-relay-request parse-relay-response]
  :i [])

(dfe StealthKind
  (:c google-bot [] "GoogleBot search indexing spider")
  (:c chrome-stealth [] "Desktop Chrome macOS/Windows stealth browser")
  (:c safari-stealth [] "Desktop Safari macOS modern WebKit")
  (:c mobile-safari [] "Mobile iPhone Safari"))

(dfs StealthProfile
  (:f kind StealthKind "Profile category")
  (:f user-agent Str "Full User-Agent string")
  (:f accept Str "HTTP Accept header")
  (:f accept-language Str "HTTP Accept-Language header")
  (:f sec-ch-ua Str "Client hints Sec-CH-UA header")
  (:f sec-fetch-dest Str "Sec-Fetch-Dest header")
  (:f sec-fetch-mode Str "Sec-Fetch-Mode header")
  (:f sec-fetch-site Str "Sec-Fetch-Site header"))

(df stealth-googlebot [] -> StealthKind
  (google-bot))

(df stealth-chrome [] -> StealthKind
  (chrome-stealth))

(df stealth-safari [] -> StealthKind
  (safari-stealth))

(df stealth-mobile [] -> StealthKind
  (mobile-safari))

(df make-googlebot-profile [] -> StealthProfile
  :d "Creates GoogleBot crawler profile with official search crawler user-agent."
  (StealthProfile
    :kind (google-bot)
    :user-agent "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
    :accept "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    :accept-language "en-US,en;q=0.5"
    :sec-ch-ua ""
    :sec-fetch-dest "document"
    :sec-fetch-mode "navigate"
    :sec-fetch-site "none"))

(df make-chrome-profile [] -> StealthProfile
  :d "Creates modern Desktop Chrome profile with realistic client hints and anti-bot headers."
  (StealthProfile
    :kind (chrome-stealth)
    :user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    :accept "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
    :accept-language "en-US,en;q=0.9"
    :sec-ch-ua "\"Chromium\";v=\"128\", \"Not;A=Brand\";v=\"24\", \"Google Chrome\";v=\"128\""
    :sec-fetch-dest "document"
    :sec-fetch-mode "navigate"
    :sec-fetch-site "none"))

(df make-safari-profile [] -> StealthProfile
  :d "Creates modern Desktop Safari profile on macOS."
  (StealthProfile
    :kind (safari-stealth)
    :user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
    :accept "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    :accept-language "en-US,en;q=0.9"
    :sec-ch-ua ""
    :sec-fetch-dest "document"
    :sec-fetch-mode "navigate"
    :sec-fetch-site "none"))

(df make-profile [(kind StealthKind)] -> StealthProfile
  :d "Dispatches profile constructor by StealthKind."
  (mt kind
    ((google-bot) (make-googlebot-profile))
    ((chrome-stealth) (make-chrome-profile))
    ((safari-stealth) (make-safari-profile))
    ((mobile-safari) (make-safari-profile))))

(df build-headers [(profile StealthProfile)] -> (List Str)
  :d "Compiles stealth profile fields into an ordered list of HTTP headers."
  (let [(base (list (str "User-Agent: " (.-user-agent profile))
                    (str "Accept: " (.-accept profile))
                    (str "Accept-Language: " (.-accept-language profile))
                    "Upgrade-Insecure-Requests: 1"
                    (str "Sec-Fetch-Dest: " (.-sec-fetch-dest profile))
                    (str "Sec-Fetch-Mode: " (.-sec-fetch-mode profile))
                    (str "Sec-Fetch-Site: " (.-sec-fetch-site profile))))
        (ch-ua (.-sec-ch-ua profile))]
    (if (> (string-length ch-ua) 0)
        (list-cons (str "Sec-CH-UA: " ch-ua) base)
        base)))

(df googlebot-profile [] -> StealthProfile
  (make-googlebot-profile))

(df chrome-profile [] -> StealthProfile
  (make-chrome-profile))

(df safari-profile [] -> StealthProfile
  (make-safari-profile))

(df curl-headers [(headers (List Str))] -> (List Str)
  :d "Expands a list of headers into curl command line flag pairs e.g. -H Header: Val."
  (format-curl-header-args headers))

(df format-curl-header-args [(headers (List Str))] -> (List Str)
  :d "Expands a list of headers into curl command line flag pairs e.g. -H Header: Val."
  (fold-left (fn [(acc (List Str)) (hdr Str)] -> (List Str)
               (list-append acc (list "-H" hdr)))
             (list)
             headers))

(dfs ExtensionRelayMessage
  (:f action Str "Worker action identifier")
  (:f url Str "Target request URL")
  (:f method Str "HTTP method e.g. GET")
  (:f headers (List Str) "HTTP request headers")
  (:f body Str "Request payload body"))

(dfs ExtensionRelayResponse
  (:f status-code I64 "HTTP response status code")
  (:f headers (List Str) "HTTP response headers")
  (:f body Str "HTTP response body")
  (:f success Bool "True if request succeeded with 2xx status"))

(df format-relay-request [(url Str) (method Str) (headers (List Str)) (body Str)] -> ExtensionRelayMessage
  :d "Formats ExtensionRelayMessage for WebExtension background worker invocation."
  (ExtensionRelayMessage
    :action "asl_fetch_relay"
    :url url
    :method method
    :headers headers
    :body body))

(df parse-relay-response [(status-code I64) (headers (List Str)) (body Str)] -> ExtensionRelayResponse
  :d "Parses WebExtension background worker fetch response payload."
  (ExtensionRelayResponse
    :status-code status-code
    :headers headers
    :body body
    :success (and (>= status-code 200) (< status-code 300))))

