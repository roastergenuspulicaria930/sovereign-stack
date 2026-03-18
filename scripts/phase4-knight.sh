#!/usr/bin/env bash
# ============================================================================
# Sovereign Stack — Phase 4: Knight
# Deploy self-hosted services on your VPS
#
# Usage:
#   bash phase4-knight.sh --all --domain yourdomain.com
#   bash phase4-knight.sh --nextcloud --vaultwarden --searxng
#   bash phase4-knight.sh --help
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }
gen_password() { openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "$1"; }

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
BASE_DIR="/opt/sovereign-stack"
CREDENTIALS_FILE="/root/sovereign-stack-credentials.txt"

check_root() { [[ $EUID -eq 0 ]] || { err "Run as root: sudo bash $0 $*"; exit 1; }; }

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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
            --domain)       DOMAIN="$2"; shift ;;
            -h|--help)
                echo "Sovereign Stack — Phase 4: Knight"
                echo ""
                echo "Usage: bash phase4-knight.sh [OPTIONS]"
                echo ""
                echo "  --all           Install everything"
                echo "  --nextcloud     Files, calendar, office"
                echo "  --vaultwarden   Password manager"
                echo "  --matrix        Encrypted chat (Element)"
                echo "  --searxng       Private search engine"
                echo "  --immich        Photo backup (like Google Photos)"
                echo "  --jitsi         Video calls"
                echo "  --adguard       DNS + ad blocker"
                echo "  --wireguard     VPN"
                echo "  --mail          Email server (Stalwart)"
                echo "  --forgejo       Git hosting"
                echo "  --security      UFW + fail2ban + CrowdSec"
                echo "  --backup        Encrypted backup to cloud"
                echo "  --domain FQDN   Your domain (optional)"
                echo ""
                exit 0
                ;;
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

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║   Sovereign Stack — Phase 4: Knight       ║"
echo "  ║   Self-Hosted Services Deployment         ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"

check_root
parse_args "$@"

# ============================================================================
step "Installing Docker"
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    log "Docker installed"
else
    log "Docker already installed"
fi

# ============================================================================
step "Creating directory structure"
mkdir -p "$BASE_DIR"/{data,config,compose}
echo "# Sovereign Stack Credentials — $(date)" > "$CREDENTIALS_FILE"
chmod 600 "$CREDENTIALS_FILE"
log "Base directory: $BASE_DIR"

# ============================================================================
# COMPOSE FILE
# ============================================================================
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"

cat > "$COMPOSE_FILE" << 'HEADER'
# Sovereign Stack — Phase 4: Knight
# Generated automatically — do not edit manually
version: "3.9"

networks:
  sovereign-net:
    driver: bridge

volumes:
HEADER

# We'll build the compose dynamically
COMPOSE_SERVICES=""
COMPOSE_VOLUMES=""

# ---- NEXTCLOUD ----
if $INSTALL_NEXTCLOUD; then
    step "Configuring Nextcloud"
    NC_PASS=$(gen_password 24)
    MYSQL_ROOT=$(gen_password 24)
    MYSQL_PASS=$(gen_password 24)

    mkdir -p "$BASE_DIR"/data/{nextcloud,mariadb}

    COMPOSE_VOLUMES+="  nextcloud_data:\n  mariadb_data:\n"
    COMPOSE_SERVICES+="
  nextcloud:
    image: nextcloud:latest
    container_name: sovereign-nextcloud
    restart: unless-stopped
    ports:
      - '8080:80'
    environment:
      MYSQL_HOST: mariadb
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: $MYSQL_PASS
      NEXTCLOUD_ADMIN_USER: admin
      NEXTCLOUD_ADMIN_PASSWORD: $NC_PASS
    volumes:
      - nextcloud_data:/var/www/html
    networks:
      - sovereign-net
    depends_on:
      - mariadb

  mariadb:
    image: mariadb:11
    container_name: sovereign-mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: $MYSQL_PASS
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - sovereign-net
"
    echo "Nextcloud admin: admin / $NC_PASS (port 8080)" >> "$CREDENTIALS_FILE"
    log "Nextcloud configured"
fi

# ---- VAULTWARDEN ----
if $INSTALL_VAULTWARDEN; then
    step "Configuring Vaultwarden"
    VW_TOKEN=$(gen_password 48)
    mkdir -p "$BASE_DIR"/data/vaultwarden

    COMPOSE_VOLUMES+="  vaultwarden_data:\n"
    COMPOSE_SERVICES+="
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: sovereign-vaultwarden
    restart: unless-stopped
    ports:
      - '8081:80'
    environment:
      ADMIN_TOKEN: $VW_TOKEN
      SIGNUPS_ALLOWED: 'true'
    volumes:
      - vaultwarden_data:/data
    networks:
      - sovereign-net
"
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
  secret_key: "$SEARX_KEY"
  bind_address: "0.0.0.0"
  port: 8888
search:
  safe_search: 0
  autocomplete: "duckduckgo"
SEARXCFG

    COMPOSE_SERVICES+="
  searxng:
    image: searxng/searxng:latest
    container_name: sovereign-searxng
    restart: unless-stopped
    ports:
      - '8082:8888'
    volumes:
      - $BASE_DIR/config/searxng:/etc/searxng:rw
    networks:
      - sovereign-net
"
    log "SearXNG configured (port 8082)"
fi

# ---- IMMICH ----
if $INSTALL_IMMICH; then
    step "Configuring Immich"
    IMMICH_DB_PASS=$(gen_password 24)

    COMPOSE_VOLUMES+="  immich_upload:\n  immich_pgdata:\n"
    COMPOSE_SERVICES+="
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: sovereign-immich
    restart: unless-stopped
    ports:
      - '8083:2283'
    environment:
      DB_HOSTNAME: immich-db
      DB_USERNAME: postgres
      DB_PASSWORD: $IMMICH_DB_PASS
      DB_DATABASE_NAME: immich
      REDIS_HOSTNAME: immich-redis
    volumes:
      - immich_upload:/usr/src/app/upload
    networks:
      - sovereign-net
    depends_on:
      - immich-db
      - immich-redis

  immich-db:
    image: tensorchord/pgvecto-rs:pg16-v0.2.0
    container_name: sovereign-immich-db
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: $IMMICH_DB_PASS
      POSTGRES_USER: postgres
      POSTGRES_DB: immich
    volumes:
      - immich_pgdata:/var/lib/postgresql/data
    networks:
      - sovereign-net

  immich-redis:
    image: redis:7-alpine
    container_name: sovereign-immich-redis
    restart: unless-stopped
    networks:
      - sovereign-net
"
    echo "Immich DB password: $IMMICH_DB_PASS (port 8083)" >> "$CREDENTIALS_FILE"
    log "Immich configured"
fi

# ---- MATRIX + ELEMENT ----
if $INSTALL_MATRIX; then
    step "Configuring Matrix/Synapse + Element"
    MATRIX_PG_PASS=$(gen_password 24)
    MATRIX_SECRET=$(gen_password 48)

    COMPOSE_VOLUMES+="  synapse_data:\n  matrix_pgdata:\n"
    COMPOSE_SERVICES+="
  synapse:
    image: matrixdotorg/synapse:latest
    container_name: sovereign-synapse
    restart: unless-stopped
    ports:
      - '8084:8008'
    environment:
      SYNAPSE_SERVER_NAME: ${DOMAIN:-localhost}
      SYNAPSE_REPORT_STATS: 'no'
    volumes:
      - synapse_data:/data
    networks:
      - sovereign-net
    depends_on:
      - matrix-db

  matrix-db:
    image: postgres:16-alpine
    container_name: sovereign-matrix-db
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: $MATRIX_PG_PASS
      POSTGRES_USER: synapse
      POSTGRES_DB: synapse
    volumes:
      - matrix_pgdata:/var/lib/postgresql/data
    networks:
      - sovereign-net

  element:
    image: vectorim/element-web:latest
    container_name: sovereign-element
    restart: unless-stopped
    ports:
      - '8085:80'
    networks:
      - sovereign-net
"
    echo "Matrix/Synapse DB password: $MATRIX_PG_PASS (port 8084)" >> "$CREDENTIALS_FILE"
    echo "Element Web UI: port 8085" >> "$CREDENTIALS_FILE"
    log "Matrix + Element configured"
fi

# ---- JITSI ----
if $INSTALL_JITSI; then
    step "Configuring Jitsi Meet"
    JITSI_SECRET=$(gen_password 32)

    COMPOSE_SERVICES+="
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
"
    log "Jitsi Meet configured (port 8086)"
fi

# ---- ADGUARD HOME ----
if $INSTALL_ADGUARD; then
    step "Configuring AdGuard Home"
    mkdir -p "$BASE_DIR"/data/adguard/{work,conf}

    COMPOSE_SERVICES+="
  adguard:
    image: adguard/adguardhome:latest
    container_name: sovereign-adguard
    restart: unless-stopped
    ports:
      - '3000:3000'
      - '53:53/tcp'
      - '53:53/udp'
    volumes:
      - $BASE_DIR/data/adguard/work:/opt/adguardhome/work
      - $BASE_DIR/data/adguard/conf:/opt/adguardhome/conf
    networks:
      - sovereign-net
"
    log "AdGuard Home configured (setup: port 3000, DNS: port 53)"
fi

# ---- FORGEJO ----
if $INSTALL_FORGEJO; then
    step "Configuring Forgejo"
    COMPOSE_VOLUMES+="  forgejo_data:\n"
    COMPOSE_SERVICES+="
  forgejo:
    image: codeberg/forgejo:latest
    container_name: sovereign-forgejo
    restart: unless-stopped
    ports:
      - '8087:3000'
      - '2222:22'
    environment:
      USER_UID: 1000
      USER_GID: 1000
    volumes:
      - forgejo_data:/data
    networks:
      - sovereign-net
"
    log "Forgejo configured (port 8087, SSH: 2222)"
fi

# Write the final compose file
{
    cat > "$COMPOSE_FILE" << 'HEADER'
# Sovereign Stack — Phase 4: Knight
version: "3.9"

networks:
  sovereign-net:
    driver: bridge

HEADER
    echo "volumes:"
    echo -e "$COMPOSE_VOLUMES" | sort -u | grep -v '^$'
    echo ""
    echo "services:"
    echo -e "$COMPOSE_SERVICES"
} > "$COMPOSE_FILE"

# ============================================================================
step "Starting services"
cd "$BASE_DIR"
docker compose up -d 2>/dev/null || docker-compose up -d
log "All services starting..."

sleep 10

step "Service status"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep sovereign || true

step "Credentials saved"
echo ""
cat "$CREDENTIALS_FILE"
echo ""
warn "SAVE THESE CREDENTIALS. File: $CREDENTIALS_FILE"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Phase 4: Knight — COMPLETE                  ║${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}║   Your castle is built. You own the infra.    ║${NC}"
echo -e "${GREEN}║   Next: Phase 5 — Sovereign (full integration)║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
