# Phase 2: Guardian — Harden Your Browser

> *"Every tab you open tells a story. Make sure only you can read it."*

---

## Why Your Browser Matters Most

Your browser is the single biggest privacy leak on your computer:

- **Chrome** sends every URL you visit to Google (for "safe browsing"), syncs all bookmarks/passwords/history to Google servers, and has a unique advertising ID tied to your identity
- **Edge** does the same but for Microsoft
- **Safari** sends OCSP checks to Apple for every site you visit

**Firefox is open source, doesn't phone home (when configured), and lets you control everything.**

---

## Step 1: Install Firefox

Most Linux distros include Firefox. If not:

```bash
# Debian/Ubuntu/Mint
sudo apt install -y firefox

# Fedora
sudo dnf install -y firefox

# Arch
sudo pacman -S firefox

# Or use Flatpak (any distro)
flatpak install flathub org.mozilla.firefox
```

---

## Step 2: Essential Extensions

Install these in order of importance:

### Tier 1 — Must have

| Extension | What It Does | Install |
|-----------|-------------|---------|
| **uBlock Origin** | Blocks ads, trackers, malware domains. The single most important extension. | [Install](https://addons.mozilla.org/firefox/addon/ublock-origin/) |
| **Privacy Badger** | Learns which domains track you and blocks them automatically | [Install](https://addons.mozilla.org/firefox/addon/privacy-badger17/) |
| **Cookie AutoDelete** | Deletes cookies when you close a tab — sites can't track you across sessions | [Install](https://addons.mozilla.org/firefox/addon/cookie-autodelete/) |

### Tier 2 — Strongly recommended

| Extension | What It Does | Install |
|-----------|-------------|---------|
| **Multi-Account Containers** | Isolates sites in separate "containers" — Google can't see your banking tabs | [Install](https://addons.mozilla.org/firefox/addon/multi-account-containers/) |
| **Decentraleyes** | Serves common libraries (jQuery, etc.) locally instead of from Google CDNs | [Install](https://addons.mozilla.org/firefox/addon/decentraleyes/) |
| **ClearURLs** | Removes tracking parameters from URLs (utm_source, fbclid, etc.) | [Install](https://addons.mozilla.org/firefox/addon/clearurls/) |

### Tier 3 — Power users

| Extension | What It Does | Install |
|-----------|-------------|---------|
| **NoScript** | Blocks JavaScript by default — whitelist only trusted sites | [Install](https://addons.mozilla.org/firefox/addon/noscript/) |
| **uMatrix** | Fine-grained control over what each site can load (advanced) | [Install](https://addons.mozilla.org/firefox/addon/umatrix/) |
| **CanvasBlocker** | Prevents canvas fingerprinting | [Install](https://addons.mozilla.org/firefox/addon/canvasblocker/) |

---

## Step 3: Harden Firefox Settings

### Automated (user.js)

Run the install script:
```bash
curl -fsSL https://raw.githubusercontent.com/Michae2xl/sovereign-stack/main/install.sh -o install.sh
bash install.sh --local
```

### Manual (about:config)

Open Firefox, type `about:config` in the address bar, accept the warning, and set:

#### Privacy

| Setting | Value | Why |
|---------|-------|-----|
| `privacy.trackingprotection.enabled` | `true` | Blocks known trackers |
| `privacy.trackingprotection.socialtracking.enabled` | `true` | Blocks social media trackers (Facebook pixel, etc.) |
| `privacy.resistFingerprinting` | `true` | Makes your browser look generic to fingerprinting scripts |
| `privacy.firstparty.isolate` | `true` | Isolates cookies to the site that created them |

#### Security

| Setting | Value | Why |
|---------|-------|-----|
| `dom.security.https_only_mode` | `true` | Forces HTTPS everywhere |
| `media.peerconnection.enabled` | `false` | Prevents WebRTC from leaking your real IP (even behind VPN) |
| `geo.enabled` | `false` | Disables geolocation API |
| `network.cookie.cookieBehavior` | `5` | Blocks cross-site cookies |

#### Telemetry (disable all)

| Setting | Value |
|---------|-------|
| `toolkit.telemetry.enabled` | `false` |
| `toolkit.telemetry.unified` | `false` |
| `datareporting.healthreport.uploadEnabled` | `false` |
| `datareporting.policy.dataSubmissionEnabled` | `false` |
| `browser.ping-centre.telemetry` | `false` |
| `browser.newtabpage.activity-stream.feeds.telemetry` | `false` |
| `browser.newtabpage.activity-stream.telemetry` | `false` |

#### Performance & Prefetching

| Setting | Value | Why |
|---------|-------|-----|
| `network.prefetch-next` | `false` | Don't pre-load links (leaks your browsing intent) |
| `network.dns.disablePrefetch` | `true` | Don't pre-resolve DNS (same reason) |
| `network.predictor.enabled` | `false` | Don't predict connections |
| `browser.search.suggest.enabled` | `false` | Don't send keystrokes to search engine |

#### Annoyances

| Setting | Value | Why |
|---------|-------|-----|
| `extensions.pocket.enabled` | `false` | Pocket is owned by Mozilla but still a third-party service |
| `browser.newtabpage.activity-stream.showSponsored` | `false` | No sponsored content on new tab |
| `browser.newtabpage.activity-stream.showSponsoredTopSites` | `false` | No sponsored top sites |

---

## Step 4: Change Default Search Engine

### Option 1: DuckDuckGo (easy, no setup)
1. Firefox → Settings → Search → Default Search Engine → DuckDuckGo

### Option 2: Brave Search (better results, independent index)
1. Go to `search.brave.com`
2. Right-click the address bar → "Add Brave Search"
3. Set as default in Settings → Search

### Option 3: SearXNG (self-hosted, Phase 4)
After Phase 4, you'll have your own search engine. Add it:
1. Go to your SearXNG instance
2. Right-click address bar → "Add SearXNG"
3. Set as default

---

## Step 5: Tor Browser (Maximum Anonymity)

For when you need real anonymity (not just privacy):

```bash
# Debian/Ubuntu/Mint
sudo apt install -y torbrowser-launcher
torbrowser-launcher

# Fedora
sudo dnf install -y torbrowser-launcher
torbrowser-launcher

# Or download directly from https://www.torproject.org/
```

**When to use Tor Browser:**
- Researching sensitive topics
- Accessing .onion services
- When you need your ISP to not see what you're browsing
- Whistleblowing or journalism

**Don't use Tor Browser for:**
- Logging into personal accounts (defeats the purpose)
- Everyday browsing (too slow, many sites break)

---

## Step 6: DNS-over-HTTPS (DoH)

Your ISP can see every domain you visit via DNS queries. Fix that:

### Firefox built-in DoH
1. Settings → Privacy & Security → scroll to "DNS over HTTPS"
2. Enable → Select provider:
   - **Cloudflare** (fast, decent privacy)
   - **NextDNS** (configurable, blocks ads)
   - **Custom** → use your own AdGuard Home after Phase 4

### System-wide (better)
After Phase 4, point all your devices to your own AdGuard Home DNS.

---

## Browser Fingerprinting

Even without cookies, sites can identify you through your browser's unique fingerprint (screen size, fonts, GPU, timezone, etc.).

**Test your fingerprint:**
- [coveryourtracks.eff.org](https://coveryourtracks.eff.org/)
- [browserleaks.com](https://browserleaks.com/)

**What helps:**
- `privacy.resistFingerprinting = true` (makes many values generic)
- Tor Browser (everyone looks the same)
- CanvasBlocker extension
- Keep your browser window at common sizes (don't maximize on unusual resolutions)

---

## Multiple Browsers Strategy

For maximum compartmentalization:

| Browser | Use For | Extensions |
|---------|---------|------------|
| **Firefox (hardened)** | Daily browsing, work | Full privacy stack |
| **Tor Browser** | Anonymous research, .onion sites | None (don't add any) |
| **Brave** | Sites that break in hardened Firefox | Built-in shields |
| **Chromium (ungoogled)** | Sites that require Chrome | Minimal |

---

## Phase 2 Checklist

- [ ] Firefox installed and set as default browser
- [ ] uBlock Origin installed and enabled
- [ ] Privacy Badger installed
- [ ] Cookie AutoDelete installed and configured
- [ ] Multi-Account Containers set up (work, personal, banking)
- [ ] Firefox hardened via about:config or user.js
- [ ] Default search changed to DuckDuckGo/Brave Search
- [ ] Telemetry disabled
- [ ] WebRTC disabled
- [ ] HTTPS-only mode enabled
- [ ] Tor Browser installed (optional)
- [ ] Tested fingerprint at coveryourtracks.eff.org

**You are now a Guardian.** Your browsing is private.

→ [Next: Phase 3 — Warrior (Replace Google Apps)](phase3-warrior.md)
