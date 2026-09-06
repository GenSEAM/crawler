(module asl-crawler/browser-detector
  :d "System browser detection and headless automation launcher for Chrome, Brave, Safari, and Chromium."
  :x [BrowserKind BrowserCandidate
      kind-chrome kind-brave kind-edge kind-safari kind-chromium
      make-candidate macos-browsers linux-browsers cdp-args
      get-macos-candidates get-linux-candidates build-cdp-launch-args]
  :i [])

(dfe BrowserKind
  (:c browser-chrome [] "Google Chrome")
  (:c browser-brave [] "Brave Privacy Browser")
  (:c browser-edge [] "Microsoft Edge")
  (:c browser-safari [] "Apple Safari")
  (:c browser-chromium [] "Open-source Chromium"))

(dfs BrowserCandidate
  (:f name Str "Human-readable browser name")
  (:f path Str "Absolute path to executable binary")
  (:f kind BrowserKind "Browser engine variant")
  (:f os Str "Operating system (macos, linux)"))

(df kind-chrome [] -> BrowserKind
  (browser-chrome))

(df kind-brave [] -> BrowserKind
  (browser-brave))

(df kind-edge [] -> BrowserKind
  (browser-edge))

(df kind-safari [] -> BrowserKind
  (browser-safari))

(df kind-chromium [] -> BrowserKind
  (browser-chromium))

(df make-candidate [(name Str) (path Str) (kind BrowserKind) (os Str)] -> BrowserCandidate
  (BrowserCandidate
    :name name
    :path path
    :kind kind
    :os os))

(df get-macos-candidates [] -> (List BrowserCandidate)
  :d "Returns priority list of standard macOS browser installation paths."
  (list
    (make-candidate "Google Chrome" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" (browser-chrome) "macos")
    (make-candidate "Brave Browser" "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" (browser-brave) "macos")
    (make-candidate "Microsoft Edge" "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" (browser-edge) "macos")
    (make-candidate "Chromium" "/Applications/Chromium.app/Contents/MacOS/Chromium" (browser-chromium) "macos")
    (make-candidate "Safari" "/Applications/Safari.app/Contents/MacOS/Safari" (browser-safari) "macos")))

(df get-linux-candidates [] -> (List BrowserCandidate)
  :d "Returns priority list of standard Linux browser installation paths."
  (list
    (make-candidate "Google Chrome" "/usr/bin/google-chrome" (browser-chrome) "linux")
    (make-candidate "Chromium" "/usr/bin/chromium-browser" (browser-chromium) "linux")
    (make-candidate "Brave" "/usr/bin/brave-browser" (browser-brave) "linux")
    (make-candidate "Chromium Binary" "/usr/bin/chromium" (browser-chromium) "linux")))

(df macos-browsers [] -> (List BrowserCandidate)
  :d "Returns priority list of standard macOS browser installation paths."
  (get-macos-candidates))

(df linux-browsers [] -> (List BrowserCandidate)
  :d "Returns priority list of standard Linux browser installation paths."
  (get-linux-candidates))

(df cdp-args [(browser BrowserCandidate) (port I64) (url Str) (headless Bool)] -> (List Str)
  :d "Builds stealth Chrome DevTools Protocol (CDP) process arguments for automated page scraping."
  (build-cdp-launch-args browser port url headless))

(df build-cdp-launch-args [(browser BrowserCandidate) (port I64) (url Str) (headless Bool)] -> (List Str)
  :d "Builds stealth Chrome DevTools Protocol (CDP) process arguments for automated page scraping."
  (let [(base (list (.-path browser)
                    (str "--remote-debugging-port=" (string-from-int64 port))
                    "--no-first-run"
                    "--no-default-browser-check"
                    "--disable-blink-features=AutomationControlled"
                    "--disable-infobars"
                    "--window-size=1920,1080"
                    url))]
    (if headless
        (list-cons "--headless=new" base)
        base)))
