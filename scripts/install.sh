#!/usr/bin/env bash
# ============================================================================
# Sovereign Stack — Unified Installer
# One script to rule them all. No sub-scripts, no downloads.
#
# Usage:
#   bash install.sh --local                                    # Phases 1-3
#   bash install.sh --vps --all --domain yourdomain.com        # Phases 4-5
#   bash install.sh --vps --nextcloud --vaultwarden --searxng   # Pick services
#   bash install.sh --check                                    # Pre-flight only
#   bash install.sh --uninstall                                # Remove everything
#   bash install.sh --help                                     # Show help
# ============================================================================

set -o pipefail
export DEBIAN_FRONTEND=noninteractive

# ============================================================================
# COLORS & LOGGING
# ============================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

gen_password() { openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c "$1"; }

# ============================================================================
# CONFIGURATION
# ============================================================================
BASE_DIR="/opt/sovereign-stack"
CREDENTIALS_FILE="/root/sovereign-stack-credentials.txt"

MODE=""
DOMAIN=""
INSTALL_ALL=false
INSTALL_NEXTCLOUD=false
INSTALL_VAULTWARDEN=false
INSTALL_MATRIX=false
INSTALL_SEARXNG=false
INSTALL_IMMICH=false
INSTALL_JITSI=false
INSTALL_ADGUARD=false
INSTALL_WIREGUARD=false
INSTALL_MAIL=false
INSTALL_FORGEJO=false
INSTALL_SECURITY=false
INSTALL_BACKUP=false
CHECK_ONLY=false
UNINSTALL=false

# ============================================================================
# HELP
# ============================================================================
show_help() {
    echo "Sovereign Stack — Unified Installer"
    echo ""
    echo "Usage: bash install.sh [MODE] [OPTIONS]"
    echo ""
    echo "MODES:"
    echo "  --local           Run local setup (Phases 1-3: essentials, browser, FOSS apps)"
    echo "  --vps             Run VPS deploy (Phases 4-5: services, hardening, integration)"
    echo "  --check           Run pre-flight checks only (no install)"
    echo "  --uninstall       Remove all Sovereign Stack services and data"
    echo ""
    echo "VPS SERVICE OPTIONS (use with --vps):"
    echo "  --all             Install all services"
    echo "  --nextcloud       Files, calendar, office"
    echo "  --vaultwarden     Password manager"
    echo "  --matrix          Encrypted chat (Element)"
    echo "  --searxng         Private search engine"
    echo "  --immich          Photo backup (like Google Photos)"
    echo "  --jitsi           Video calls"
    echo "  --adguard         DNS + ad blocker"
    echo "  --wireguard       VPN"
    echo "  --mail            Email server (Stalwart)"
    echo "  --forgejo         Git hosting"
    echo "  --security        UFW + fail2ban + CrowdSec"
    echo "  --backup          Encrypted backup to cloud"
    echo "  --domain FQDN     Your domain (for auto-HTTPS via Caddy)"
    echo ""
    echo "EXAMPLES:"
    echo "  bash install.sh --local"
    echo "  bash install.sh --vps --all --domain example.com"
    echo "  bash install.sh --vps --nextcloud --vaultwarden --searxng"
    echo "  bash install.sh --check"
    echo "  bash install.sh --uninstall"
    echo ""
    exit 0
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_help
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --local)        MODE="local" ;;
            --vps)          MODE="vps" ;;
            --check|--dry-run) CHECK_ONLY=true; MODE="check" ;;
            --uninstall)    UNINSTALL=true; MODE="uninstall" ;;
            --all)          INSTALL_ALL=true ;;
            --nextcloud)    INSTALL_NEXTCLOUD=true ;;
            --vaultwarden)  INSTALL_VAULTWARDEN=true ;;
            --matrix)       INSTALL_MATRIX=true ;;
            --searxng)      INSTALL_SEARXNG=true ;;
            --immich)       INSTALL_IMMICH=true ;;
            --jitsi)        INSTALL_JITSI=true ;;
            --adguard)      INSTALL_ADGUARD=true ;;
            --wireguard)    INSTALL_WIREGUARD=true ;;
            --mail)         INSTALL_MAIL=true ;;
            --forgejo)      INSTALL_FORGEJO=true ;;
            --security)     INSTALL_SECURITY=true ;;
            --backup)       INSTALL_BACKUP=true ;;
            --domain)
                if [[ $# -gt 1 ]]; then
                    DOMAIN="$2"; shift
                else
                    err "--domain requires a value"
                    exit 1
                fi
                ;;
            -h|--help)      show_help ;;
            *) warn "Unknown option: $1" ;;
        esac
        shift
    done

    if $INSTALL_ALL; then
        INSTALL_NEXTCLOUD=true; INSTALL_VAULTWARDEN=true
        INSTALL_MATRIX=true; INSTALL_SEARXNG=true
        INSTALL_IMMICH=true; INSTALL_JITSI=true
        INSTALL_ADGUARD=true; INSTALL_WIREGUARD=true
        INSTALL_MAIL=true; INSTALL_FORGEJO=true
        INSTALL_SECURITY=true; INSTALL_BACKUP=true
    fi
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================
preflight_check() {
    local has_critical_failure=false
    local has_warning=false

    echo ""
    echo -e "${CYAN}━━━ Pre-flight Checks ━━━${NC}"
    echo ""

    # 1. Root check (only critical for VPS mode)
    if [[ $EUID -eq 0 ]]; then
        echo -e "${GREEN}[OK]${NC} Running as root"
    else
        if [[ "$MODE" == "vps" ]]; then
            echo -e "${RED}[FAIL]${NC} Not running as root (required for VPS mode)"
            has_critical_failure=true
        else
            echo -e "${YELLOW}[WARN]${NC} Not running as root (some operations may need sudo)"
            has_warning=true
        fi
    fi

    # 2. RAM check
    local ram_kb ram_gb
    ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ram_gb=$(( ram_kb / 1024 / 1024 ))
    if [[ $ram_gb -ge 8 ]]; then
        echo -e "${GREEN}[OK]${NC} RAM: ${ram_gb}GB (minimum: 4GB)"
    elif [[ $ram_gb -ge 4 ]]; then
        echo -e "${YELLOW}[WARN]${NC} RAM: ${ram_gb}GB (minimum: 4GB) — Ollama requires 8GB+"
        has_warning=true
    else
        echo -e "${YELLOW}[WARN]${NC} RAM: ${ram_gb}GB (minimum: 4GB, recommended: 8GB for Ollama)"
        has_warning=true
    fi

    # 3. Disk space check
    local disk_avail_kb disk_avail_gb
    disk_avail_kb=$(df / --output=avail | tail -1 | tr -d ' ')
    disk_avail_gb=$(( disk_avail_kb / 1024 / 1024 ))
    if [[ $disk_avail_gb -ge 20 ]]; then
        echo -e "${GREEN}[OK]${NC} Disk: ${disk_avail_gb}GB free (minimum: 20GB)"
    else
        echo -e "${YELLOW}[WARN]${NC} Disk: ${disk_avail_gb}GB free (minimum: 20GB)"
        has_warning=true
    fi

    # 4. OS check
    local os_id os_version os_pretty
    os_id=$(. /etc/os-release 2>/dev/null && echo "$ID" || echo "unknown")
    os_version=$(. /etc/os-release 2>/dev/null && echo "$VERSION_ID" || echo "unknown")
    os_pretty=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Unknown OS")
    if [[ "$os_id" == "ubuntu" && ( "$os_version" == "22.04" || "$os_version" == "24.04" ) ]]; then
        echo -e "${GREEN}[OK]${NC} OS: $os_pretty"
    else
        echo -e "${YELLOW}[WARN]${NC} OS: $os_pretty (tested on Ubuntu 22.04/24.04)"
        has_warning=true
    fi

    # 5. Docker check
    if command -v docker &>/dev/null; then
        echo -e "${GREEN}[OK]${NC} Docker: installed"
    else
        echo -e "${GREEN}[OK]${NC} Docker: not installed (will be installed)"
    fi

    # 6. Port checks (VPS mode only)
    if [[ "$MODE" == "vps" || "$MODE" == "check" ]]; then
        local ports_to_check=(8080 8081 8082 8083 8084 8085 8086 8087 3000 53 51820)
        local ports_in_use=()
        for port in "${ports_to_check[@]}"; do
            if ss -tlnp 2>/dev/null | grep -q ":${port} " || ss -ulnp 2>/dev/null | grep -q ":${port} "; then
                ports_in_use+=("$port")
            fi
        done
        if [[ ${#ports_in_use[@]} -eq 0 ]]; then
            echo -e "${GREEN}[OK]${NC} Ports: all required ports are free"
        else
            echo -e "${YELLOW}[WARN]${NC} Ports already in use: ${ports_in_use[*]}"
            has_warning=true
        fi
    fi

    # 7. Internet connectivity
    if curl -sf --max-time 5 https://hub.docker.com >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} Internet: connected"
    elif curl -sf --max-time 5 https://1.1.1.1 >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} Internet: connected"
    else
        echo -e "${RED}[FAIL]${NC} Internet: no connectivity detected"
        has_critical_failure=true
    fi

    echo ""

    if [[ "$has_critical_failure" == true ]]; then
        err "Critical pre-flight check(s) failed. Cannot continue."
        exit 1
    fi
    if [[ "$has_warning" == true ]]; then
        warn "Some checks raised warnings. Review above before proceeding."
    else
        log "All pre-flight checks passed."
    fi
    echo ""
}

# ============================================================================
# DETECT PACKAGE MANAGER
# ============================================================================
detect_pkg_manager() {
    if command -v apt &>/dev/null; then
        PKG="apt"
    elif command -v dnf &>/dev/null; then
        PKG="dnf"
    elif command -v pacman &>/dev/null; then
        PKG="pacman"
    else
        err "Unsupported package manager. Install manually."
        exit 1
    fi
}

# ############################################################################
#
# PHASE 1: HERO — Linux Post-Install Essentials
#
# ############################################################################
run_phase1() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║   Phase 1: Hero                       ║"
    echo "  ║   Linux Post-Install Essentials       ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo -e "${NC}"

    detect_pkg_manager

    step "Updating system"
    case $PKG in
        apt)    sudo apt-get update -y && sudo apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ;;
        dnf)    sudo dnf upgrade -y ;;
        pacman) sudo pacman -Syu --noconfirm ;;
    esac
    log "System updated"

    step "Installing essentials"
    PACKAGES="curl wget git htop neofetch vim unzip"
    case $PKG in
        apt)    sudo apt-get install -y $PACKAGES ;;
        dnf)    sudo dnf install -y $PACKAGES ;;
        pacman) sudo pacman -S --noconfirm $PACKAGES ;;
    esac
    log "Essential packages installed"

    step "Installing Flatpak (universal app store)"
    case $PKG in
        apt)    sudo apt-get install -y flatpak ;;
        dnf)    sudo dnf install -y flatpak ;;
        pacman) sudo pacman -S --noconfirm flatpak ;;
    esac
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    log "Flatpak installed — you can now install apps from Flathub"

    step "Basic security"
    if command -v ufw &>/dev/null; then
        sudo ufw --force enable
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh
        log "Firewall (UFW) enabled"
    elif command -v firewall-cmd &>/dev/null; then
        sudo systemctl enable --now firewalld
        log "Firewall (firewalld) enabled"
    else
        warn "No firewall found. Consider installing ufw."
    fi

    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get install -y unattended-upgrades
        sudo dpkg-reconfigure -plow unattended-upgrades 2>/dev/null || true
        log "Automatic security updates enabled"
    fi

    step "System info"
    neofetch 2>/dev/null || true

    echo ""
    log "Phase 1: Hero — COMPLETE"
}

# ############################################################################
#
# PHASE 2: GUARDIAN — Firefox Hardening
#
# ############################################################################
run_phase2() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   Phase 2: Guardian                       ║"
    echo "  ║   Browser Hardening                       ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"

    detect_pkg_manager

    step "Ensuring Firefox is installed"

    FIREFOX_IS_SNAP=false
    if command -v snap &>/dev/null && snap list firefox &>/dev/null 2>&1; then
        FIREFOX_IS_SNAP=true
        log "Firefox detected as snap package"
    fi

    if command -v firefox &>/dev/null; then
        log "Firefox already installed: $(firefox --version 2>/dev/null || echo 'detected')"
    else
        case $PKG in
            apt)    sudo apt-get install -y firefox ;;
            dnf)    sudo dnf install -y firefox ;;
            pacman) sudo pacman -S --noconfirm firefox ;;
            *)      warn "Install Firefox manually from https://www.mozilla.org/firefox/" ;;
        esac
        if command -v firefox &>/dev/null; then
            log "Firefox installed"
        else
            warn "Firefox installation may have failed. Continuing anyway."
        fi
    fi

    step "Finding Firefox profile"

    if $FIREFOX_IS_SNAP; then
        FIREFOX_DIR="$HOME/snap/firefox/common/.mozilla/firefox"
    else
        FIREFOX_DIR="$HOME/.mozilla/firefox"
    fi

    PROFILE=""
    if [[ -d "$FIREFOX_DIR" ]]; then
        PROFILE=$(find "$FIREFOX_DIR" -maxdepth 1 -name "*.default-release" -type d 2>/dev/null | head -1)
        if [[ -z "$PROFILE" ]]; then
            PROFILE=$(find "$FIREFOX_DIR" -maxdepth 1 -name "*.default" -type d 2>/dev/null | head -1)
        fi
    fi

    if [[ -z "${PROFILE:-}" ]]; then
        warn "No Firefox profile found. Creating a temporary profile..."
        firefox --headless &>/dev/null &
        FIREFOX_PID=$!
        for i in $(seq 1 10); do
            sleep 1
            if [[ -d "$FIREFOX_DIR" ]]; then
                PROFILE=$(find "$FIREFOX_DIR" -maxdepth 1 -name "*.default-release" -type d 2>/dev/null | head -1)
                [[ -n "$PROFILE" ]] && break
                PROFILE=$(find "$FIREFOX_DIR" -maxdepth 1 -name "*.default" -type d 2>/dev/null | head -1)
                [[ -n "$PROFILE" ]] && break
            fi
        done
        if kill -0 "$FIREFOX_PID" 2>/dev/null; then
            kill "$FIREFOX_PID" 2>/dev/null || true
            for i in $(seq 1 5); do
                kill -0 "$FIREFOX_PID" 2>/dev/null || break
                sleep 1
            done
            kill -9 "$FIREFOX_PID" 2>/dev/null || true
        fi
        wait "$FIREFOX_PID" 2>/dev/null || true
    fi

    if [[ -n "${PROFILE:-}" ]]; then
        step "Hardening Firefox (user.js)"
        cat > "$PROFILE/user.js" << 'USERJS'
// Sovereign Stack — Firefox Hardening
// Privacy
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.firstparty.isolate", true);

// HTTPS-only
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// Cookies
user_pref("network.cookie.cookieBehavior", 5);
user_pref("network.cookie.lifetimePolicy", 2);

// Disable telemetry
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);

// Disable WebRTC leak
user_pref("media.peerconnection.enabled", false);

// Disable geolocation
user_pref("geo.enabled", false);

// Disable Pocket
user_pref("extensions.pocket.enabled", false);

// Disable prefetching
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);

// Search
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);

// DRM (optional — disable if you don't use Netflix/Spotify in browser)
// user_pref("media.eme.enabled", false);
USERJS
        log "Firefox hardened with user.js"
    else
        warn "Could not find Firefox profile — apply settings manually via about:config"
    fi

    step "Recommended extensions (install manually)"
    echo ""
    echo "  Open Firefox and install these extensions:"
    echo ""
    echo "  1. uBlock Origin (ad + tracker blocker)"
    echo "     https://addons.mozilla.org/firefox/addon/ublock-origin/"
    echo ""
    echo "  2. Privacy Badger (learns to block trackers)"
    echo "     https://addons.mozilla.org/firefox/addon/privacy-badger17/"
    echo ""
    echo "  3. Cookie AutoDelete (clears cookies on tab close)"
    echo "     https://addons.mozilla.org/firefox/addon/cookie-autodelete/"
    echo ""
    echo "  4. Multi-Account Containers (isolate sites)"
    echo "     https://addons.mozilla.org/firefox/addon/multi-account-containers/"
    echo ""
    echo "  5. Decentraleyes (local CDN emulation)"
    echo "     https://addons.mozilla.org/firefox/addon/decentraleyes/"
    echo ""

    step "Installing Tor Browser (optional, for maximum anonymity)"
    if ! command -v torbrowser-launcher &>/dev/null; then
        case $PKG in
            apt)    sudo apt-get install -y torbrowser-launcher && log "Tor Browser launcher installed" || warn "Tor Browser launcher install failed" ;;
            dnf)    sudo dnf install -y torbrowser-launcher && log "Tor Browser launcher installed" || warn "Tor Browser launcher install failed" ;;
            pacman) warn "Install from AUR: yay -S tor-browser" ;;
            *)      warn "Install Tor Browser from https://www.torproject.org/" ;;
        esac
    else
        log "Tor Browser launcher already installed"
    fi

    echo ""
    log "Phase 2: Guardian — COMPLETE"
}

# ############################################################################
#
# PHASE 3: WARRIOR — FOSS App Replacements
#
# ############################################################################
run_phase3() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   Phase 3: Warrior                        ║"
    echo "  ║   Replace Google Apps with FOSS            ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"

    if ! command -v flatpak &>/dev/null; then
        warn "Flatpak not installed. Run --local first or install manually."
        warn "sudo apt install -y flatpak && flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
        return 1
    fi

    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

    INSTALL_FAILURES=0

    install_app() {
        local id=$1
        local name=$2
        local replaces=$3
        if flatpak list --app 2>/dev/null | grep -q "$id"; then
            log "$name already installed"
        else
            echo -n "  Installing $name (replaces $replaces)... "
            if flatpak install -y --noninteractive flathub "$id" &>/dev/null; then
                echo -e "${GREEN}done${NC}"
            else
                echo -e "${YELLOW}failed — install manually: flatpak install flathub $id${NC}"
                INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
            fi
        fi
    }

    step "Office & Productivity"
    install_app "org.libreoffice.LibreOffice"         "LibreOffice"       "Google Docs/Sheets/Slides"
    install_app "org.signal.Signal"                    "Signal"            "Google Messages/WhatsApp"
    install_app "net.cozic.joplin_desktop"             "Joplin"            "Google Keep"
    install_app "org.standardnotes.app"                "Standard Notes"    "Google Keep (alt)"
    install_app "org.thunderbird.Thunderbird"          "Thunderbird"       "Gmail client"

    step "Media"
    install_app "io.freetubeapp.FreeTube"              "FreeTube"          "YouTube"
    install_app "org.videolan.VLC"                     "VLC"               "Google Play Movies"
    install_app "org.gimp.GIMP"                        "GIMP"              "Google Photos editor"

    step "Security & Privacy"
    install_app "com.bitwarden.desktop"                "Bitwarden"         "Chrome passwords"
    install_app "org.keepassxc.KeePassXC"              "KeePassXC"         "Google Authenticator (desktop)"

    step "Communication"
    install_app "im.element.Element"                   "Element"           "Discord/Slack/Teams"

    step "Development (optional)"
    install_app "com.vscodium.codium"                  "VSCodium"          "VS Code (without telemetry)"

    step "Summary of installed apps"
    echo ""
    echo "  Installed FOSS apps:"
    flatpak list --app --columns=name 2>/dev/null | head -20
    echo ""

    if [[ $INSTALL_FAILURES -gt 0 ]]; then
        warn "$INSTALL_FAILURES app(s) failed to install. You can install them manually with flatpak."
    fi

    step "Manual steps remaining"
    echo ""
    echo "  1. EMAIL: Sign up at https://proton.me (free plan available)"
    echo "     -> Forward your Gmail to ProtonMail"
    echo "     -> After 30 days, stop using Gmail"
    echo ""
    echo "  2. SEARCH: Set DuckDuckGo or Brave Search as default"
    echo "     -> In Firefox: Settings -> Search -> Default Search Engine"
    echo ""
    echo "  3. MAPS: Install OsmAnd or Organic Maps on your phone"
    echo "     -> F-Droid (Android): https://f-droid.org"
    echo "     -> Or from app stores"
    echo ""
    echo "  4. PHONE (advanced): GrapheneOS on a Pixel phone"
    echo "     -> https://grapheneos.org/install"
    echo ""
    echo "  5. EXPORT GOOGLE DATA:"
    echo "     -> Go to https://takeout.google.com"
    echo "     -> Select all services -> Export -> Download"
    echo "     -> Import into your new apps"
    echo ""

    log "Phase 3: Warrior — COMPLETE"
}

# ############################################################################
#
# PHASE 4: KNIGHT — Deploy Self-Hosted Services
#
# ############################################################################
run_phase4() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   Phase 4: Knight                         ║"
    echo "  ║   Self-Hosted Services Deployment         ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"

    # ---- DOCKER ----
    step "Installing Docker"
    if ! command -v docker &>/dev/null; then
        if ! curl -fsSL https://get.docker.com | sh; then
            err "Docker installation failed. Cannot continue."
            exit 1
        fi
        systemctl enable --now docker
        log "Docker installed"
    else
        log "Docker already installed"
    fi

    if ! docker compose version &>/dev/null; then
        if command -v docker-compose &>/dev/null; then
            warn "Using docker-compose v1 (docker compose plugin not found)"
        else
            err "Neither 'docker compose' nor 'docker-compose' found"
            exit 1
        fi
    fi

    # ---- DIRECTORY STRUCTURE ----
    step "Creating directory structure"
    mkdir -p "$BASE_DIR"/{data,config,compose}

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "# Sovereign Stack Credentials — $(date)" > "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
    else
        echo "" >> "$CREDENTIALS_FILE"
        echo "# --- Updated: $(date) ---" >> "$CREDENTIALS_FILE"
    fi
    log "Base directory: $BASE_DIR"

    # ---- BUILD COMPOSE FILE ----
    COMPOSE_FILE="$BASE_DIR/docker-compose.yml"
    COMPOSE_TMP=$(mktemp -d)
    VOLUMES_FILE="$COMPOSE_TMP/volumes"
    SERVICES_FILE="$COMPOSE_TMP/services"
    touch "$VOLUMES_FILE" "$SERVICES_FILE"

    add_volume() {
        echo "  $1:" >> "$VOLUMES_FILE"
    }

    append_service() {
        cat >> "$SERVICES_FILE"
    }

    # ---- NEXTCLOUD ----
    if $INSTALL_NEXTCLOUD; then
        step "Configuring Nextcloud"
        NC_PASS=$(gen_password 24)
        MYSQL_ROOT=$(gen_password 24)
        MYSQL_PASS=$(gen_password 24)

        mkdir -p "$BASE_DIR"/data/{nextcloud,mariadb}

        add_volume "nextcloud_data"
        add_volume "mariadb_data"

        append_service << SVCEOF

  nextcloud:
    image: nextcloud:latest
    container_name: sovereign-nextcloud
    restart: unless-stopped
    ports:
      - '8080:80'
    environment:
      MYSQL_HOST: 'mariadb'
      MYSQL_DATABASE: 'nextcloud'
      MYSQL_USER: 'nextcloud'
      MYSQL_PASSWORD: '${MYSQL_PASS}'
      NEXTCLOUD_ADMIN_USER: 'admin'
      NEXTCLOUD_ADMIN_PASSWORD: '${NC_PASS}'
    volumes:
      - nextcloud_data:/var/www/html
    networks:
      - sovereign-net
    depends_on:
      mariadb:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/status.php"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  mariadb:
    image: mariadb:11
    container_name: sovereign-mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: '${MYSQL_ROOT}'
      MYSQL_DATABASE: 'nextcloud'
      MYSQL_USER: 'nextcloud'
      MYSQL_PASSWORD: '${MYSQL_PASS}'
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
SVCEOF

        echo "Nextcloud admin: admin / $NC_PASS (port 8080)" >> "$CREDENTIALS_FILE"
        log "Nextcloud configured"
    fi

    # ---- VAULTWARDEN ----
    if $INSTALL_VAULTWARDEN; then
        step "Configuring Vaultwarden"
        VW_TOKEN=$(gen_password 48)
        mkdir -p "$BASE_DIR"/data/vaultwarden

        add_volume "vaultwarden_data"

        append_service << SVCEOF

  vaultwarden:
    image: vaultwarden/server:latest
    container_name: sovereign-vaultwarden
    restart: unless-stopped
    ports:
      - '8081:80'
    environment:
      ADMIN_TOKEN: '${VW_TOKEN}'
      SIGNUPS_ALLOWED: 'true'
    volumes:
      - vaultwarden_data:/data
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/alive"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
SVCEOF

        echo "Vaultwarden admin token: $VW_TOKEN (port 8081)" >> "$CREDENTIALS_FILE"
        log "Vaultwarden configured"
    fi

    # ---- SEARXNG ----
    if $INSTALL_SEARXNG; then
        step "Configuring SearXNG"
        SEARX_KEY=$(gen_password 32)
        mkdir -p "$BASE_DIR"/config/searxng

        cat > "$BASE_DIR/config/searxng/settings.yml" << SEARXCFG
use_default_settings: true
general:
  debug: false
  instance_name: "Sovereign Search"
server:
  secret_key: "${SEARX_KEY}"
  bind_address: "0.0.0.0"
  port: 8888
search:
  safe_search: 0
  autocomplete: "duckduckgo"
SEARXCFG

        append_service << SVCEOF

  searxng:
    image: searxng/searxng:latest
    container_name: sovereign-searxng
    restart: unless-stopped
    ports:
      - '8082:8888'
    volumes:
      - ${BASE_DIR}/config/searxng:/etc/searxng:rw
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8888/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
SVCEOF

        log "SearXNG configured (port 8082)"
    fi

    # ---- IMMICH ----
    if $INSTALL_IMMICH; then
        step "Configuring Immich"
        IMMICH_DB_PASS=$(gen_password 24)

        add_volume "immich_upload"
        add_volume "immich_pgdata"

        append_service << SVCEOF

  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: sovereign-immich
    restart: unless-stopped
    ports:
      - '8083:2283'
    environment:
      DB_HOSTNAME: 'immich-db'
      DB_USERNAME: 'postgres'
      DB_PASSWORD: '${IMMICH_DB_PASS}'
      DB_DATABASE_NAME: 'immich'
      REDIS_HOSTNAME: 'immich-redis'
    volumes:
      - immich_upload:/usr/src/app/upload
    networks:
      - sovereign-net
    depends_on:
      immich-db:
        condition: service_healthy
      immich-redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:2283/api/server/ping"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

  immich-db:
    image: tensorchord/pgvecto-rs:pg16-v0.2.0
    container_name: sovereign-immich-db
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: '${IMMICH_DB_PASS}'
      POSTGRES_USER: 'postgres'
      POSTGRES_DB: 'immich'
    volumes:
      - immich_pgdata:/var/lib/postgresql/data
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d immich"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  immich-redis:
    image: redis:7-alpine
    container_name: sovereign-immich-redis
    restart: unless-stopped
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
SVCEOF

        echo "Immich DB password: $IMMICH_DB_PASS (port 8083)" >> "$CREDENTIALS_FILE"
        log "Immich configured"
    fi

    # ---- MATRIX + ELEMENT ----
    if $INSTALL_MATRIX; then
        step "Configuring Matrix/Synapse + Element"
        MATRIX_PG_PASS=$(gen_password 24)
        MATRIX_SECRET=$(gen_password 48)

        add_volume "synapse_data"
        add_volume "matrix_pgdata"

        append_service << SVCEOF

  synapse:
    image: matrixdotorg/synapse:latest
    container_name: sovereign-synapse
    restart: unless-stopped
    ports:
      - '8084:8008'
    environment:
      SYNAPSE_SERVER_NAME: '${DOMAIN:-localhost}'
      SYNAPSE_REPORT_STATS: 'no'
    volumes:
      - synapse_data:/data
    networks:
      - sovereign-net
    depends_on:
      matrix-db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8008/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

  matrix-db:
    image: postgres:16-alpine
    container_name: sovereign-matrix-db
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: '${MATRIX_PG_PASS}'
      POSTGRES_USER: 'synapse'
      POSTGRES_DB: 'synapse'
    volumes:
      - matrix_pgdata:/var/lib/postgresql/data
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U synapse -d synapse"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s

  element:
    image: vectorim/element-web:latest
    container_name: sovereign-element
    restart: unless-stopped
    ports:
      - '8085:80'
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:80/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
SVCEOF

        echo "Matrix/Synapse DB password: $MATRIX_PG_PASS (port 8084)" >> "$CREDENTIALS_FILE"
        echo "Element Web UI: port 8085" >> "$CREDENTIALS_FILE"
        log "Matrix + Element configured"
    fi

    # ---- JITSI ----
    if $INSTALL_JITSI; then
        step "Configuring Jitsi Meet"
        JITSI_SECRET=$(gen_password 32)

        append_service << SVCEOF

  jitsi:
    image: jitsi/web:stable
    container_name: sovereign-jitsi
    restart: unless-stopped
    ports:
      - '8086:80'
    environment:
      ENABLE_AUTH: '0'
      PUBLIC_URL: 'http://${DOMAIN:-localhost}:8086'
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
SVCEOF

        log "Jitsi Meet configured (port 8086)"
    fi

    # ---- ADGUARD HOME ----
    if $INSTALL_ADGUARD; then
        step "Configuring AdGuard Home"
        mkdir -p "$BASE_DIR"/data/adguard/{work,conf}

        append_service << SVCEOF

  adguard:
    image: adguard/adguardhome:latest
    container_name: sovereign-adguard
    restart: unless-stopped
    ports:
      - '3000:3000'
      - '53:53/tcp'
      - '53:53/udp'
    volumes:
      - ${BASE_DIR}/data/adguard/work:/opt/adguardhome/work
      - ${BASE_DIR}/data/adguard/conf:/opt/adguardhome/conf
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
SVCEOF

        log "AdGuard Home configured (setup: port 3000, DNS: port 53)"
    fi

    # ---- FORGEJO ----
    if $INSTALL_FORGEJO; then
        step "Configuring Forgejo"
        add_volume "forgejo_data"

        append_service << SVCEOF

  forgejo:
    image: codeberg/forgejo:latest
    container_name: sovereign-forgejo
    restart: unless-stopped
    ports:
      - '8087:3000'
      - '2222:22'
    environment:
      USER_UID: '1000'
      USER_GID: '1000'
    volumes:
      - forgejo_data:/data
    networks:
      - sovereign-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/v1/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
SVCEOF

        log "Forgejo configured (port 8087, SSH: 2222)"
    fi

    # ---- ASSEMBLE COMPOSE FILE ----
    step "Writing docker-compose.yml"

    {
        cat << 'HEADER'
# Sovereign Stack — Auto-generated docker-compose.yml
# Do not edit manually — regenerate with install.sh

networks:
  sovereign-net:
    driver: bridge

HEADER

        echo "volumes:"
        if [[ -s "$VOLUMES_FILE" ]]; then
            sort -u "$VOLUMES_FILE"
        else
            echo "  {}"
        fi
        echo ""

        echo "services:"
        if [[ -s "$SERVICES_FILE" ]]; then
            cat "$SERVICES_FILE"
        else
            echo "  # No services selected"
        fi
    } > "$COMPOSE_FILE"

    rm -rf "$COMPOSE_TMP"

    log "Compose file written: $COMPOSE_FILE"

    # Validate YAML
    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$COMPOSE_FILE'))" 2>/dev/null; then
            log "YAML syntax validated"
        else
            warn "YAML validation failed — check $COMPOSE_FILE manually"
        fi
    fi

    # ---- START SERVICES ----
    step "Starting services"
    cd "$BASE_DIR"
    if docker compose version &>/dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi
    log "All services starting..."

    step "Service status"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep sovereign || warn "No sovereign containers running yet. Check: docker ps"

    step "Credentials saved"
    echo ""
    cat "$CREDENTIALS_FILE"
    echo ""
    warn "SAVE THESE CREDENTIALS. File: $CREDENTIALS_FILE"

    log "Phase 4: Knight — COMPLETE"
}

# ############################################################################
#
# PHASE 5: SOVEREIGN — Integration, Hardening, VPN, Backups
#
# ############################################################################
run_phase5() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   Phase 5: Sovereign                      ║"
    echo "  ║   Full Integration & Hardening            ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"

    [[ $EUID -eq 0 ]] || { err "Phase 5 requires root"; exit 1; }

    # Detect default network interface automatically
    DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '{print $5}' | head -1)
    if [[ -z "$DEFAULT_IFACE" ]]; then
        DEFAULT_IFACE="eth0"
        warn "Could not detect default network interface, falling back to eth0"
    else
        log "Detected default network interface: $DEFAULT_IFACE"
    fi

    # ---- CADDY REVERSE PROXY ----
    step "1. Caddy Reverse Proxy (auto-HTTPS)"
    if [[ -n "$DOMAIN" ]]; then
        mkdir -p /opt/sovereign-stack/caddy

        cat > /opt/sovereign-stack/caddy/Caddyfile << CADDY
# Sovereign Stack — Caddy Reverse Proxy
{
    email admin@${DOMAIN}
}

cloud.${DOMAIN} {
    reverse_proxy localhost:8080
}

vault.${DOMAIN} {
    reverse_proxy localhost:8081
}

search.${DOMAIN} {
    reverse_proxy localhost:8082
}

photos.${DOMAIN} {
    reverse_proxy localhost:8083
}

chat.${DOMAIN} {
    reverse_proxy localhost:8084
}

element.${DOMAIN} {
    reverse_proxy localhost:8085
}

meet.${DOMAIN} {
    reverse_proxy localhost:8086
}

git.${DOMAIN} {
    reverse_proxy localhost:8087
}
CADDY

        if docker ps -a --format '{{.Names}}' | grep -q '^sovereign-caddy$'; then
            docker stop sovereign-caddy 2>/dev/null || true
            docker rm sovereign-caddy 2>/dev/null || true
        fi

        docker run -d \
            --name sovereign-caddy \
            --restart unless-stopped \
            --network host \
            -v /opt/sovereign-stack/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
            -v caddy_data:/data \
            -v caddy_config:/config \
            caddy:latest

        if docker ps | grep -q sovereign-caddy; then
            log "Caddy running with auto-HTTPS for *.${DOMAIN}"
        else
            err "Caddy failed to start. Check: docker logs sovereign-caddy"
        fi
    else
        warn "No domain provided — skipping HTTPS. Access services by IP:port"
    fi

    # ---- SERVER HARDENING ----
    if $INSTALL_SECURITY || $INSTALL_ALL; then
        step "2. Server Hardening"

        # UFW Firewall
        if command -v ufw &>/dev/null; then
            ufw --force reset
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow 22/tcp
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw allow 53/tcp
            ufw allow 53/udp
            ufw allow 51820/udp
            ufw --force enable
            log "UFW firewall configured"
        else
            apt-get install -y ufw
            if command -v ufw &>/dev/null; then
                ufw --force reset
                ufw default deny incoming
                ufw default allow outgoing
                ufw allow 22/tcp
                ufw allow 80/tcp
                ufw allow 443/tcp
                ufw allow 53/tcp
                ufw allow 53/udp
                ufw allow 51820/udp
                ufw --force enable
                log "UFW installed and configured"
            else
                warn "UFW installation failed"
            fi
        fi

        # fail2ban
        if ! command -v fail2ban-client &>/dev/null; then
            apt-get install -y fail2ban
        fi
        if command -v fail2ban-client &>/dev/null; then
            cat > /etc/fail2ban/jail.local << 'F2B'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
F2B
            systemctl enable --now fail2ban
            log "fail2ban enabled (SSH protection)"
        else
            warn "fail2ban installation failed"
        fi

        # SSH hardening notice
        if ! grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
            warn "Consider disabling SSH password auth:"
            warn "  1. Add your SSH key: ssh-copy-id root@server"
            warn "  2. Set PasswordAuthentication no in /etc/ssh/sshd_config"
            warn "  3. Restart: systemctl restart sshd"
        fi
    fi

    # ---- ENCRYPTED BACKUPS ----
    if $INSTALL_BACKUP || $INSTALL_ALL; then
        step "3. Encrypted Backups"

        if ! command -v rclone &>/dev/null; then
            curl -fsSL https://rclone.org/install.sh | bash
            if command -v rclone &>/dev/null; then
                log "rclone installed"
            else
                warn "rclone installation failed"
            fi
        else
            log "rclone already installed"
        fi

        DOCKER_VOLUME_DIR=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null)/volumes
        if [[ ! -d "$DOCKER_VOLUME_DIR" ]]; then
            DOCKER_VOLUME_DIR="/var/lib/docker/volumes"
            warn "Could not detect Docker volume path, using default: $DOCKER_VOLUME_DIR"
        else
            log "Docker volume path: $DOCKER_VOLUME_DIR"
        fi

        cat > /opt/sovereign-stack/backup.sh << 'BACKUP'
#!/usr/bin/env bash
# Sovereign Stack — Daily Encrypted Backup
set -euo pipefail

BACKUP_DIR="/opt/sovereign-stack/backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup..."

# Dump databases (ignore errors if container not running)
docker exec sovereign-mariadb mysqldump -u root --all-databases 2>/dev/null > "$BACKUP_DIR/mariadb.sql" || echo "  [skip] MariaDB not running"
docker exec sovereign-matrix-db pg_dumpall -U synapse 2>/dev/null > "$BACKUP_DIR/matrix-pg.sql" || echo "  [skip] Matrix DB not running"
docker exec sovereign-immich-db pg_dumpall -U postgres 2>/dev/null > "$BACKUP_DIR/immich-pg.sql" || echo "  [skip] Immich DB not running"

# Detect Docker volume directory dynamically
DOCKER_VOL_DIR="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null)/volumes"
if [[ ! -d "$DOCKER_VOL_DIR" ]]; then
    DOCKER_VOL_DIR="/var/lib/docker/volumes"
fi

# Backup named volumes
for vol_name in $(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E '(nextcloud_data|vaultwarden_data|forgejo_data|synapse_data)'); do
    vol_path="$DOCKER_VOL_DIR/$vol_name"
    if [[ -d "$vol_path" ]]; then
        echo "  Backing up volume: $vol_name"
        tar czf "$BACKUP_DIR/${vol_name}.tar.gz" -C "$DOCKER_VOL_DIR" "$vol_name" 2>/dev/null || echo "  [warn] Failed to backup $vol_name"
    fi
done

# Encrypt
if command -v gpg &>/dev/null && [[ -f /root/.backup-passphrase ]]; then
    tar czf - "$BACKUP_DIR" | gpg --symmetric --cipher-algo AES256 --batch --passphrase-file /root/.backup-passphrase -o "$BACKUP_DIR.tar.gz.gpg"
    rm -rf "$BACKUP_DIR"
    echo "[$(date)] Encrypted backup: $BACKUP_DIR.tar.gz.gpg"
else
    echo "[$(date)] Unencrypted backup in: $BACKUP_DIR"
    echo "  To enable encryption: echo 'your-passphrase' > /root/.backup-passphrase && chmod 600 /root/.backup-passphrase"
fi

# Upload (configure rclone first: rclone config)
# rclone copy "$BACKUP_DIR.tar.gz.gpg" remote:sovereign-backups/

# Cleanup old backups (keep 7 days)
find /opt/sovereign-stack/backups/ -maxdepth 1 -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo "[$(date)] Backup complete"
BACKUP
        chmod +x /opt/sovereign-stack/backup.sh

        CRON_LINE="0 3 * * * /opt/sovereign-stack/backup.sh >> /var/log/sovereign-backup.log 2>&1"
        if crontab -l 2>/dev/null | grep -qF "/opt/sovereign-stack/backup.sh"; then
            log "Backup cron already configured"
        else
            (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
            log "Daily backup configured (3 AM)"
        fi
        warn "Configure rclone for remote backup: rclone config"
    fi

    # ---- WIREGUARD VPN ----
    if $INSTALL_WIREGUARD || $INSTALL_ALL; then
        step "4. WireGuard VPN"

        if ! command -v wg &>/dev/null; then
            apt-get install -y wireguard
        fi

        if command -v wg &>/dev/null; then
            if [[ ! -f /etc/wireguard/wg0.conf ]]; then
                WG_PRIVKEY=$(wg genkey)
                WG_PUBKEY=$(echo "$WG_PRIVKEY" | wg pubkey)
                SERVER_IP=$(curl -s --max-time 10 ifconfig.me || echo "UNKNOWN")

                cat > /etc/wireguard/wg0.conf << WG
[Interface]
PrivateKey = $WG_PRIVKEY
Address = 10.66.66.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE

# Add clients below:
# [Peer]
# PublicKey = CLIENT_PUBLIC_KEY
# AllowedIPs = 10.66.66.2/32
WG
                chmod 600 /etc/wireguard/wg0.conf

                if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
                    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
                    sysctl -p 2>/dev/null || true
                fi

                systemctl enable --now wg-quick@wg0 || warn "WireGuard failed to start. Check: systemctl status wg-quick@wg0"
                log "WireGuard running on port 51820"
                echo ""
                echo "  Server public key: $WG_PUBKEY"
                echo "  Server IP: $SERVER_IP"
                echo "  Network interface: $DEFAULT_IFACE"
                echo ""
                echo "  To add a client:"
                echo "    1. On client: wg genkey | tee privatekey | wg pubkey > publickey"
                echo "    2. Add [Peer] block to /etc/wireguard/wg0.conf on server"
                echo "    3. Restart: wg-quick down wg0 && wg-quick up wg0"
            else
                log "WireGuard already configured"
            fi
        else
            warn "WireGuard installation failed"
        fi
    fi

    # ---- SOVEREIGNTY CHECKLIST ----
    step "5. Final Sovereignty Checklist"

    echo ""
    echo -e "  ${CYAN}YOUR SERVICES:${NC}"
    if [[ -n "$DOMAIN" ]]; then
        echo "  Cloud:     https://cloud.${DOMAIN}"
        echo "  Passwords: https://vault.${DOMAIN}"
        echo "  Search:    https://search.${DOMAIN}"
        echo "  Photos:    https://photos.${DOMAIN}"
        echo "  Chat:      https://element.${DOMAIN}"
        echo "  Video:     https://meet.${DOMAIN}"
        echo "  Git:       https://git.${DOMAIN}"
    else
        echo "  Cloud:     http://YOUR_IP:8080"
        echo "  Passwords: http://YOUR_IP:8081"
        echo "  Search:    http://YOUR_IP:8082"
        echo "  Photos:    http://YOUR_IP:8083"
        echo "  Chat:      http://YOUR_IP:8085"
        echo "  Video:     http://YOUR_IP:8086"
        echo "  Git:       http://YOUR_IP:8087"
        echo "  DNS:       http://YOUR_IP:3000"
    fi
    echo ""
    echo -e "  ${CYAN}CONNECT YOUR DEVICES:${NC}"
    echo "  [ ] Phone: Install Nextcloud app, Bitwarden app, Element app"
    echo "  [ ] Phone: Set DNS to your AdGuard (VPS_IP or via WireGuard)"
    echo "  [ ] Desktop: Install Nextcloud sync client"
    echo "  [ ] Desktop: Install Bitwarden extension in Firefox"
    echo "  [ ] Desktop: Set SearXNG as default search engine"
    echo "  [ ] Desktop: Connect WireGuard VPN"
    echo "  [ ] All devices: Enable WireGuard"
    echo ""
    echo -e "  ${CYAN}FINAL STEPS:${NC}"
    echo "  [ ] Export Google data from https://takeout.google.com"
    echo "  [ ] Import data to Nextcloud, Immich, Vaultwarden"
    echo "  [ ] Forward Gmail to your new email"
    echo "  [ ] After 30 days: close Gmail"
    echo "  [ ] After 60 days: delete Google account"
    echo ""

    log "Phase 5: Sovereign — COMPLETE"
}

# ############################################################################
#
# POST-DEPLOY HEALTH CHECKS
#
# ############################################################################
health_check() {
    step "Post-Deploy Health Checks"
    echo "  Waiting 30 seconds for services to start..."
    sleep 30

    local all_ok=true

    check_endpoint() {
        local name="$1"
        local url="$2"
        local response
        response=$(curl -sf --max-time 10 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
        if [[ "$response" =~ ^[23] ]]; then
            printf "  ${GREEN}[OK]${NC}   %-14s — %s\n" "$name" "$url"
        else
            printf "  ${RED}[FAIL]${NC} %-14s — %s (not responding)\n" "$name" "$url"
            all_ok=false
        fi
    }

    $INSTALL_NEXTCLOUD  && check_endpoint "Nextcloud"    "http://localhost:8080"
    $INSTALL_VAULTWARDEN && check_endpoint "Vaultwarden"  "http://localhost:8081"
    $INSTALL_SEARXNG    && check_endpoint "SearXNG"      "http://localhost:8082"
    $INSTALL_IMMICH     && check_endpoint "Immich"       "http://localhost:8083"
    $INSTALL_MATRIX     && check_endpoint "Synapse"      "http://localhost:8084"
    $INSTALL_MATRIX     && check_endpoint "Element"      "http://localhost:8085"
    $INSTALL_JITSI      && check_endpoint "Jitsi"        "http://localhost:8086"
    $INSTALL_FORGEJO    && check_endpoint "Forgejo"      "http://localhost:8087"
    $INSTALL_ADGUARD    && check_endpoint "AdGuard"      "http://localhost:3000"

    # Check Caddy if domain was set
    if [[ -n "$DOMAIN" ]]; then
        local caddy_status
        caddy_status=$(docker inspect -f '{{.State.Running}}' sovereign-caddy 2>/dev/null || echo "false")
        if [[ "$caddy_status" == "true" ]]; then
            printf "  ${GREEN}[OK]${NC}   %-14s — running (auto-HTTPS)\n" "Caddy"
        else
            printf "  ${RED}[FAIL]${NC} %-14s — not running\n" "Caddy"
            all_ok=false
        fi
    fi

    echo ""
    if $all_ok; then
        log "All services are healthy."
    else
        warn "Some services are not responding yet. They may need more time to start."
        warn "Check with: docker ps | grep sovereign"
    fi
}

# ############################################################################
#
# UNINSTALL
#
# ############################################################################
run_uninstall() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   Sovereign Stack — Uninstall             ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"

    echo ""
    warn "This will remove all Sovereign Stack services and data."
    echo ""

    # Stop and remove sovereign-* containers
    step "Stopping and removing containers"
    local containers
    containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep '^sovereign-' || true)
    if [[ -n "$containers" ]]; then
        echo "$containers" | while read -r c; do
            docker stop "$c" 2>/dev/null || true
            docker rm "$c" 2>/dev/null || true
            log "Removed container: $c"
        done
    else
        warn "No sovereign-* containers found"
    fi

    # Stop compose stack if running
    if [[ -f /opt/sovereign-stack/docker-compose.yml ]]; then
        cd /opt/sovereign-stack
        if docker compose version &>/dev/null; then
            docker compose down 2>/dev/null || true
        else
            docker-compose down 2>/dev/null || true
        fi
        log "Compose stack stopped"
    fi

    # Remove Docker volumes (with confirmation)
    step "Docker volumes"
    local volumes
    volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E '(nextcloud_data|mariadb_data|vaultwarden_data|immich_upload|immich_pgdata|synapse_data|matrix_pgdata|forgejo_data|caddy_data|caddy_config)' || true)
    if [[ -n "$volumes" ]]; then
        echo "  The following Docker volumes will be removed:"
        echo "$volumes" | sed 's/^/    /'
        echo ""
        read -rp "  Remove these volumes? All data will be lost. [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "$volumes" | while read -r v; do
                docker volume rm "$v" 2>/dev/null || true
                log "Removed volume: $v"
            done
        else
            warn "Volumes kept. Remove manually with: docker volume rm <name>"
        fi
    else
        warn "No sovereign-related Docker volumes found"
    fi

    # Remove /opt/sovereign-stack
    step "Removing data directory"
    if [[ -d /opt/sovereign-stack ]]; then
        rm -rf /opt/sovereign-stack
        log "Removed /opt/sovereign-stack"
    else
        warn "/opt/sovereign-stack not found"
    fi

    # Remove credentials file
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        rm -f "$CREDENTIALS_FILE"
        log "Removed $CREDENTIALS_FILE"
    fi

    # Remove backup cron job
    step "Removing cron jobs"
    if crontab -l 2>/dev/null | grep -qF "/opt/sovereign-stack/backup.sh"; then
        crontab -l 2>/dev/null | grep -vF "/opt/sovereign-stack/backup.sh" | crontab -
        log "Removed backup cron job"
    else
        warn "No backup cron job found"
    fi

    # Remove WireGuard config
    step "Removing WireGuard config"
    if [[ -f /etc/wireguard/wg0.conf ]]; then
        systemctl stop wg-quick@wg0 2>/dev/null || true
        systemctl disable wg-quick@wg0 2>/dev/null || true
        rm -f /etc/wireguard/wg0.conf
        log "Removed WireGuard config"
    else
        warn "No WireGuard config found"
    fi

    # Summary
    echo ""
    step "Uninstall Summary"
    echo "  Removed:"
    echo "    - All sovereign-* Docker containers"
    echo "    - /opt/sovereign-stack directory"
    echo "    - Credentials file"
    echo "    - Backup cron job"
    echo "    - WireGuard config"
    echo ""
    echo "  NOT removed (manual cleanup if desired):"
    echo "    - Docker engine (too dangerous to auto-remove)"
    echo "    - UFW firewall rules (too dangerous to auto-remove)"
    echo "    - fail2ban config"
    echo "    - System packages installed in Phase 1"
    echo ""
    log "Uninstall complete."
}

# ############################################################################
#
# MAIN ENTRY POINT
#
# ############################################################################
main() {
    parse_args "$@"

    case "$MODE" in
        check)
            preflight_check
            log "Check-only mode: exiting without installing."
            exit 0
            ;;
        uninstall)
            run_uninstall
            exit 0
            ;;
        local)
            echo -e "${CYAN}"
            echo "  ╔═══════════════════════════════════════════════════╗"
            echo "  ║   Sovereign Stack — Complete Local Install        ║"
            echo "  ║   Phase 1 (Hero) + Phase 2 (Guardian) + Phase 3  ║"
            echo "  ║   (Warrior)                                       ║"
            echo "  ╚═══════════════════════════════════════════════════╝"
            echo -e "${NC}"

            preflight_check

            echo ""
            echo -e "${GREEN}━━━ PHASE 1: HERO (Linux Essentials) ━━━${NC}"
            echo ""
            if run_phase1; then
                log "Phase 1 completed"
            else
                err "Phase 1 failed"
                exit 1
            fi

            echo ""
            echo -e "${GREEN}━━━ PHASE 2: GUARDIAN (Browser Hardening) ━━━${NC}"
            echo ""
            if run_phase2; then
                log "Phase 2 completed"
            else
                warn "Phase 2 had errors (non-critical, continuing)"
            fi

            echo ""
            echo -e "${GREEN}━━━ PHASE 3: WARRIOR (FOSS Apps) ━━━${NC}"
            echo ""
            if run_phase3; then
                log "Phase 3 completed"
            else
                warn "Phase 3 had errors (non-critical, continuing)"
            fi

            echo ""
            echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                                                   ║${NC}"
            echo -e "${GREEN}║   LOCAL SETUP COMPLETE — Phases 1, 2, 3 done!    ║${NC}"
            echo -e "${GREEN}║                                                   ║${NC}"
            echo -e "${GREEN}║   Your machine is free from Big Tech.             ║${NC}"
            echo -e "${GREEN}║                                                   ║${NC}"
            echo -e "${GREEN}║   Next: bash install.sh --vps --all --domain X    ║${NC}"
            echo -e "${GREEN}║                                                   ║${NC}"
            echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
            ;;
        vps)
            echo -e "${CYAN}"
            echo "  ╔═══════════════════════════════════════════════════╗"
            echo "  ║   Sovereign Stack — Complete VPS Deploy           ║"
            echo "  ║   Phase 4 (Knight) + Phase 5 (Sovereign)         ║"
            echo "  ╚═══════════════════════════════════════════════════╝"
            echo -e "${NC}"

            preflight_check

            echo ""
            echo -e "${GREEN}━━━ PHASE 4: KNIGHT (Deploy Services) ━━━${NC}"
            echo ""
            run_phase4

            echo ""
            echo -e "${GREEN}━━━ PHASE 5: SOVEREIGN (Integration & Hardening) ━━━${NC}"
            echo ""
            run_phase5

            # Post-deploy health checks
            health_check

            echo ""
            echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                                                       ║${NC}"
            echo -e "${GREEN}║   VPS DEPLOY COMPLETE — Phases 4, 5 done!            ║${NC}"
            echo -e "${GREEN}║                                                       ║${NC}"
            echo -e "${GREEN}║   Your castle is built and fortified.                 ║${NC}"
            echo -e "${GREEN}║   You are Sovereign.                                  ║${NC}"
            echo -e "${GREEN}║                                                       ║${NC}"
            echo -e "${GREEN}║   Credentials: /root/sovereign-stack-credentials.txt  ║${NC}"
            echo -e "${GREEN}║                                                       ║${NC}"
            echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
            ;;
        *)
            err "No mode specified. Use --local, --vps, --check, or --uninstall."
            echo ""
            show_help
            ;;
    esac
}

main "$@"
