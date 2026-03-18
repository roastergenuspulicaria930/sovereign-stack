# Phase 4: Knight — Build Your Own Castle

> *"A knight doesn't rent his castle. He builds it."*

---

## What Is Self-Hosting?

Instead of storing your files on Google Drive (Google's server), you store them on **your own server** running Nextcloud. Instead of using Google Search, you run **your own search engine** (SearXNG). Instead of trusting LastPass, you run **your own password manager** (Vaultwarden).

**You need:** A VPS (Virtual Private Server) — a computer in a datacenter that you rent. ~€6-18/month.

---

## Step 1: Get a VPS

### Recommended Providers

| Provider | Privacy | Price (8GB) | Location | Payment |
|----------|---------|-------------|----------|---------|
| **Hetzner** | GDPR, good | ~€9/mo | Germany/Finland | Card, PayPal |
| **Njalla** | Excellent, zero KYC | ~€15/mo | Sweden | Crypto only |
| **1984.is** | Excellent | ~€15/mo | Iceland | Card, crypto |
| **Contabo** | OK | ~€6/mo | Germany | Card, PayPal |
| **BuyVM** | Good | ~$7/mo | Luxembourg/US | Card, crypto |

**For maximum privacy:** Njalla (founded by Pirate Bay co-founder, accepts only crypto, registers domain in their name).

**For best value:** Hetzner or Contabo.

### Minimum specs

| | Minimum | Recommended |
|---|---------|-------------|
| **RAM** | 4GB | 8GB+ |
| **CPU** | 2 vCPUs | 4+ vCPUs |
| **Disk** | 40GB SSD | 80GB+ SSD |
| **OS** | Ubuntu 22.04 | Ubuntu 24.04 |
| **Bandwidth** | 1TB | Unlimited |

### Order your VPS

1. Sign up at your chosen provider
2. Choose Ubuntu 24.04 LTS as the OS
3. Select the plan with at least 4GB RAM
4. Note your server IP and root password

---

## Step 2: Initial Server Setup

```bash
# Connect to your server
ssh root@YOUR_SERVER_IP

# Update everything
apt update && apt upgrade -y

# Set timezone
timedatectl set-timezone UTC

# Create a non-root user (optional but recommended)
adduser sovereign
usermod -aG sudo sovereign
```

### SSH Key Authentication

On your **local machine:**
```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "your@email.com"

# Copy to server
ssh-copy-id root@YOUR_SERVER_IP

# Test login without password
ssh root@YOUR_SERVER_IP
```

After confirming key auth works:
```bash
# On the server: disable password authentication
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
```

---

## Step 3: Get a Domain (Optional but Recommended)

A domain gives you nice URLs like `cloud.yourdomain.com` instead of `123.45.67.89:8080`.

### Privacy-friendly domain registrars

| Registrar | Privacy | Notes |
|-----------|---------|-------|
| **Njalla** | Best | Registers in their name, you're anonymous |
| **Porkbun** | Good | Cheap, free WHOIS privacy |
| **Namecheap** | Good | Free WHOIS privacy |

### DNS setup

Point these subdomains to your VPS IP:

```
A    @           → YOUR_VPS_IP
A    cloud       → YOUR_VPS_IP
A    vault       → YOUR_VPS_IP
A    search      → YOUR_VPS_IP
A    photos      → YOUR_VPS_IP
A    chat        → YOUR_VPS_IP
A    element     → YOUR_VPS_IP
A    meet        → YOUR_VPS_IP
A    git         → YOUR_VPS_IP
A    dns         → YOUR_VPS_IP
```

**No domain?** Everything works via IP:port or Tor .onion addresses.

---

## Step 4: Deploy Services

### Automated (recommended)

```bash
# SSH into your VPS
ssh root@YOUR_SERVER_IP

# Download and run
curl -fsSL https://raw.githubusercontent.com/Michae2xl/sovereign-stack/main/install.sh -o install.sh
chmod +x install.sh

# Install everything
bash install.sh --vps --all --domain yourdomain.com

# Or pick what you need
bash install.sh --vps --nextcloud --vaultwarden --searxng --domain yourdomain.com
```

### What each flag installs

| Flag | Service | Replaces | Port |
|------|---------|----------|------|
| `--nextcloud` | Nextcloud + MariaDB | Google Drive/Docs/Calendar | 8080 |
| `--vaultwarden` | Vaultwarden | LastPass/1Password | 8081 |
| `--searxng` | SearXNG | Google Search | 8082 |
| `--immich` | Immich + PostgreSQL + Redis | Google Photos | 8083 |
| `--matrix` | Synapse + Element + PostgreSQL | WhatsApp/Discord | 8084/8085 |
| `--jitsi` | Jitsi Meet | Zoom/Google Meet | 8086 |
| `--forgejo` | Forgejo | GitHub/GitLab | 8087 |
| `--adguard` | AdGuard Home | Google DNS/Pi-hole | 3000/53 |
| `--wireguard` | WireGuard | NordVPN/ExpressVPN | 51820 |
| `--mail` | Stalwart Mail | Gmail (server-side) | 25/143/993 |
| `--security` | UFW + fail2ban + CrowdSec | — | — |
| `--backup` | Encrypted backup + rclone | — | — |

---

## Service-by-Service Setup

### Nextcloud (Google Drive/Docs/Calendar replacement)

After deployment, go to `http://YOUR_IP:8080` (or `https://cloud.yourdomain.com`).

**First login:** admin / (password from credentials file)

**Essential setup:**
1. Install recommended apps: Calendar, Contacts, Talk, Office
2. Create your user account (don't use admin daily)
3. Install Nextcloud desktop client on your computer
4. Install Nextcloud app on your phone
5. Enable 2FA: Settings → Security → Two-Factor Authentication

**Sync your data:**
```bash
# On your computer: install Nextcloud client
flatpak install flathub com.nextcloud.desktopclient.nextcloud

# On phone: install from F-Droid or Play Store
```

**Import from Google:**
1. Upload Google Takeout files to Nextcloud
2. Import contacts: Contacts app → Import VCF file
3. Import calendar: Calendar app → Import ICS file

---

### Vaultwarden (Password Manager)

Go to `http://YOUR_IP:8081` (or `https://vault.yourdomain.com`).

**Setup:**
1. Create your account
2. Import passwords from Bitwarden/Chrome export (CSV)
3. Install browser extension: use Bitwarden extension, point it to your server
   - Settings → Self-hosted → Server URL: `https://vault.yourdomain.com`
4. Install mobile app: Bitwarden app → Settings → Self-hosted

**Admin panel:** `https://vault.yourdomain.com/admin` (use admin token from credentials file)

---

### SearXNG (Private Search)

Go to `http://YOUR_IP:8082` (or `https://search.yourdomain.com`).

**Set as default in Firefox:**
1. Visit your SearXNG instance
2. Right-click the address bar → "Add SearXNG"
3. Firefox Settings → Search → Default Search Engine → SearXNG

**Tips:**
- SearXNG aggregates results from Google, Bing, DuckDuckGo, and more — without telling them who you are
- Add `!g` for Google results, `!ddg` for DuckDuckGo, `!w` for Wikipedia

---

### Immich (Google Photos replacement)

Go to `http://YOUR_IP:8083` (or `https://photos.yourdomain.com`).

**Setup:**
1. Create admin account
2. Install mobile app (available on F-Droid, Play Store, App Store)
3. Set server URL in app
4. Enable auto-backup for photos and videos
5. Upload Google Photos export

**Features:**
- AI-powered face recognition and search (runs locally)
- Memories ("On this day")
- Shared albums
- Map view
- Identical UX to Google Photos

---

### Matrix/Element (WhatsApp/Discord replacement)

**Synapse (server):** `http://YOUR_IP:8084`
**Element (web client):** `http://YOUR_IP:8085` (or `https://element.yourdomain.com`)

**Setup:**
1. Open Element web client
2. Change homeserver to your domain
3. Register an account
4. Create rooms and invite people
5. Install Element on phone and desktop

**Bridges (connect to other platforms):**
- WhatsApp bridge: [mautrix-whatsapp](https://docs.mau.fi/bridges/go/whatsapp/)
- Telegram bridge: [mautrix-telegram](https://docs.mau.fi/bridges/python/telegram/)
- Signal bridge: [mautrix-signal](https://docs.mau.fi/bridges/go/signal/)

---

### AdGuard Home (Network-wide ad blocking)

Go to `http://YOUR_IP:3000` for initial setup.

**Setup:**
1. Complete the setup wizard
2. Add blocklists:
   - AdGuard DNS filter (default)
   - OISD blocklist: `https://big.oisd.nl`
   - Steven Black's hosts: `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
3. Point your devices' DNS to your VPS IP
4. Or use WireGuard VPN (all traffic goes through your server's DNS)

---

### WireGuard (Your Own VPN)

The install script (`install.sh --vps`) sets this up. After it's running:

**On your phone:**
1. Install WireGuard app
2. Scan QR code or import config
3. Connect

**On your desktop:**
```bash
# Install WireGuard
sudo apt install -y wireguard

# Copy config (from server)
sudo nano /etc/wireguard/wg0.conf
# Paste your client config

# Connect
sudo wg-quick up wg0

# Auto-connect on boot
sudo systemctl enable wg-quick@wg0
```

---

## Monitoring Your Stack

After deployment, you have:

| URL | What |
|-----|------|
| `YOUR_IP:9000` | Portainer — Docker management GUI |
| `YOUR_IP:3100` | Grafana — Metrics dashboards |
| `YOUR_IP:9090` | Prometheus — Raw metrics |

---

## Troubleshooting

**Service won't start?**
```bash
# Check container logs
docker logs sovereign-nextcloud
docker logs sovereign-vaultwarden

# Check all containers
docker ps -a

# Restart everything
cd /opt/sovereign-stack && docker compose restart
```

**Out of RAM?**
```bash
# Check memory usage
free -h
docker stats --no-stream

# Enable swap
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
```

**Can't access from outside?**
```bash
# Check firewall
sudo ufw status

# Open needed ports
sudo ufw allow 8080/tcp  # Nextcloud
sudo ufw allow 8081/tcp  # Vaultwarden
# etc.
```

---

## Phase 4 Checklist

- [ ] VPS ordered and accessible via SSH
- [ ] SSH key authentication configured
- [ ] Domain pointed to VPS (optional)
- [ ] Install script executed (`install.sh --vps`)
- [ ] Nextcloud running and accessible
- [ ] Vaultwarden running, passwords imported
- [ ] SearXNG running, set as default search
- [ ] Immich running, photos uploading
- [ ] Matrix/Element running (optional)
- [ ] AdGuard Home configured with blocklists
- [ ] Credentials saved securely

**You are now a Knight.** You built your castle.

→ [Next: Phase 5 — Sovereign (Full Integration)](phase5-sovereign.md)
