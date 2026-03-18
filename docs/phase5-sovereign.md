# Phase 5: Sovereign — Full Digital Sovereignty

> *"The sovereign answers to no one. Every byte is yours."*

---

## What This Phase Does

You've replaced the apps (Phase 3) and built the infrastructure (Phase 4). Now you **connect everything**, **harden it**, and **close every leak**.

After this phase:
- All your devices route through your own VPN
- All DNS queries go through your own ad-blocking DNS
- All files sync to your own cloud
- All passwords live on your own server
- Everything is backed up and encrypted
- You can access your stack from anywhere via Tor .onion
- Google has zero data on your ongoing life

---

## Step 1: Caddy Reverse Proxy (Auto-HTTPS)

Caddy gives you automatic HTTPS certificates for all your services.

```bash
# Run the install script
ssh root@YOUR_VPS_IP
curl -fsSL https://raw.githubusercontent.com/Michae2xl/sovereign-stack/main/install.sh -o install.sh
bash install.sh --vps --domain yourdomain.com
```

**What it configures:**

| Subdomain | Service |
|-----------|---------|
| `cloud.yourdomain.com` | Nextcloud |
| `vault.yourdomain.com` | Vaultwarden |
| `search.yourdomain.com` | SearXNG |
| `photos.yourdomain.com` | Immich |
| `chat.yourdomain.com` | Matrix/Synapse |
| `element.yourdomain.com` | Element Web |
| `meet.yourdomain.com` | Jitsi Meet |
| `git.yourdomain.com` | Forgejo |

All automatically HTTPS. Caddy handles Let's Encrypt certificates.

---

## Step 2: WireGuard VPN

Your own VPN means:
- Your ISP can't see what you browse (traffic is encrypted to your VPS)
- You can access all services securely from anywhere
- All DNS queries go through your AdGuard Home

### Server setup (done by `install.sh --vps`)

The script creates `/etc/wireguard/wg0.conf` with a server config.

### Add a client (phone/laptop)

**On your VPS:**
```bash
# Generate client keys
CLIENT_PRIVKEY=$(wg genkey)
CLIENT_PUBKEY=$(echo "$CLIENT_PRIVKEY" | wg pubkey)
SERVER_PUBKEY=$(cat /etc/wireguard/publickey 2>/dev/null || wg show wg0 public-key)
SERVER_IP=$(curl -s ifconfig.me)

echo "Client private key: $CLIENT_PRIVKEY"
echo "Client public key:  $CLIENT_PUBKEY"

# Add client to server config
cat >> /etc/wireguard/wg0.conf << PEER

[Peer]
PublicKey = $CLIENT_PUBKEY
AllowedIPs = 10.66.66.2/32
PEER

# Restart WireGuard
wg-quick down wg0 && wg-quick up wg0

# Generate client config
cat << CLIENT

[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = 10.66.66.2/24
DNS = 10.66.66.1

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CLIENT
```

**On your phone:**
1. Install WireGuard app
2. Add tunnel → Create from scratch → paste the client config
3. Or scan QR code (generate with `qrencode -t ansiutf8 < client.conf`)
4. Enable the tunnel

**On your laptop:**
```bash
sudo apt install -y wireguard
sudo nano /etc/wireguard/wg0.conf  # paste client config
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0  # auto-connect on boot
```

---

## Step 3: DNS Configuration (AdGuard Home)

### Point all devices to your DNS

**Via WireGuard (recommended):**
The client config already sets `DNS = 10.66.66.1` — all DNS goes through your AdGuard Home when VPN is active.

**Manual (without VPN):**
- **Linux:** Edit `/etc/resolv.conf` or use NetworkManager → DNS → your VPS IP
- **Phone:** Settings → WiFi → DNS → your VPS IP
- **Router:** Change DNS to your VPS IP (covers all devices)

### Recommended blocklists

Add in AdGuard Home → Filters → DNS Blocklists:

| List | URL | What it blocks |
|------|-----|----------------|
| **OISD Big** | `https://big.oisd.nl` | Ads, trackers, malware (comprehensive) |
| **Steven Black** | `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts` | Ads + malware |
| **HaGeZi Pro** | `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt` | Pro-level blocking |

---

## Step 4: Connect All Devices

### Phone Setup Checklist

| App | Action |
|-----|--------|
| **WireGuard** | Install, import config, enable always-on |
| **Nextcloud** | Install, add server URL, enable auto-upload |
| **Bitwarden** | Install, set self-hosted URL, login |
| **Element** | Install, set homeserver to your domain |
| **Immich** | Install, set server URL, enable auto-backup |
| **Aegis** | Already set up from Phase 3 |
| **Signal** | Already set up from Phase 3 |
| **OsmAnd** | Already set up from Phase 3 |
| **NewPipe** | Already set up from Phase 3 |

### Desktop Setup Checklist

| App | Action |
|-----|--------|
| **WireGuard** | Install, import config, enable on boot |
| **Nextcloud Client** | Install, add server URL, select sync folders |
| **Bitwarden Extension** | In Firefox, set self-hosted URL |
| **Element Desktop** | Install, set homeserver |
| **SearXNG** | Set as default search in Firefox |
| **Firefox** | Already hardened from Phase 2 |

### Router (Optional, Maximum Coverage)

If you can flash your router with OpenWrt:
1. Set WireGuard VPN at router level → all devices protected
2. Set DNS to your AdGuard Home → all devices ad-blocked
3. No per-device config needed

---

## Step 5: Encrypted Backups

### What the script configures

- **Daily at 3 AM:** Database dumps + volume backups
- **Encrypted with GPG AES-256**
- **Cron job** in `/opt/sovereign-stack/backup.sh`

### Set up remote backup (rclone)

```bash
# Configure rclone for your cloud storage
rclone config

# Options:
# - Mega.nz (50GB free, E2E encrypted)
# - Backblaze B2 ($0.005/GB/mo)
# - Wasabi ($5.99/TB/mo)
# - Another VPS via SFTP
```

Edit `/opt/sovereign-stack/backup.sh` and uncomment the rclone line:
```bash
rclone copy "$BACKUP_DIR.tar.gz.gpg" remote:sovereign-backups/
```

### Test backup and restore

```bash
# Run backup manually
/opt/sovereign-stack/backup.sh

# Test restore
gpg --decrypt backup.tar.gz.gpg | tar xzf -
```

### Backup passphrase

Create and save your backup passphrase:
```bash
# Generate a strong passphrase
openssl rand -base64 32 > /root/.backup-passphrase
chmod 600 /root/.backup-passphrase

# SAVE THIS SOMEWHERE SAFE (password manager, printed, etc.)
cat /root/.backup-passphrase
```

---

## Step 6: Server Hardening

### What the script does automatically

- **UFW Firewall** — only allows SSH, HTTP, HTTPS, DNS, WireGuard
- **fail2ban** — blocks IPs after 5 failed SSH attempts
- **SSH key auth** — reminder to disable password auth

### Additional hardening (manual)

```bash
# Change SSH port (obscurity helps reduce noise)
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
systemctl restart sshd
ufw allow 2222/tcp
ufw delete allow ssh

# Install CrowdSec (collaborative security)
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash
apt install -y crowdsec crowdsec-firewall-bouncer-iptables

# Enable automatic security updates
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Disable root login via SSH
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd
```

---

## Step 7: Tor .onion Services (Optional)

Access your stack from anywhere without exposing your server IP.

```bash
# Install Tor
apt install -y tor

# Configure hidden services
cat >> /etc/tor/torrc << 'TOR'

HiddenServiceDir /var/lib/tor/sovereign-cloud/
HiddenServicePort 80 127.0.0.1:8080

HiddenServiceDir /var/lib/tor/sovereign-vault/
HiddenServicePort 80 127.0.0.1:8081

HiddenServiceDir /var/lib/tor/sovereign-search/
HiddenServicePort 80 127.0.0.1:8082
TOR

systemctl restart tor

# Get your .onion addresses
cat /var/lib/tor/sovereign-cloud/hostname
cat /var/lib/tor/sovereign-vault/hostname
cat /var/lib/tor/sovereign-search/hostname
```

Now you can access `cloud.xxxxx.onion` from Tor Browser — no domain or IP needed.

---

## Step 8: Email Migration (Final)

If you deployed Stalwart Mail in Phase 4:

### DNS records for email

Add to your domain DNS:
```
MX     @     → mail.yourdomain.com (priority 10)
A      mail  → YOUR_VPS_IP
TXT    @     → "v=spf1 mx ~all"
```

### DKIM and DMARC (improves deliverability)
Stalwart generates DKIM keys automatically. Add the TXT records it provides.

### Migration path
1. Keep ProtonMail as primary for now
2. Set up forwarding: ProtonMail → your server (or vice versa)
3. Test sending/receiving
4. Gradually move accounts to your domain email
5. After 90 days: make your domain email primary

---

## Step 9: Monitoring

### Grafana Dashboard

Access Grafana at `YOUR_IP:3100` (default: admin/admin).

**Add data sources:**
1. Prometheus: `http://prometheus:9090`
2. Import community dashboards:
   - Docker monitoring: Dashboard ID `893`
   - Node Exporter: Dashboard ID `1860`

### Uptime monitoring

If you want to monitor from outside:
- [Uptime Kuma](https://github.com/louislam/uptime-kuma) (self-hosted)
- [Healthchecks.io](https://healthchecks.io/) (free tier)

---

## Step 10: The Google Farewell

You've migrated everything. Time to cut the cord.

### Timeline

| When | Action |
|------|--------|
| **Now** | Verify all data is migrated and accessible |
| **Week 1** | Stop using Google services actively |
| **Week 2** | Remove Google apps from phone |
| **Week 4** | Disable Gmail forwarding (you should get no more important emails) |
| **Week 8** | Download final Takeout export |
| **Week 12** | Delete Google account data (or entire account) |

### Before deleting Google Account

Double-check:
- [ ] All emails are in ProtonMail/your server
- [ ] All files are in Nextcloud
- [ ] All photos are in Immich
- [ ] All passwords are in Vaultwarden
- [ ] All contacts are in Nextcloud
- [ ] All calendar events are in Nextcloud
- [ ] YouTube subscriptions exported (FreeTube imports OPML)
- [ ] Google Authenticator codes migrated to Aegis
- [ ] All services using Gmail have been updated to new email
- [ ] Recovery emails on important accounts updated

---

## The Sovereign Stack — Complete

```
┌─────────────────────────────────────────────────────────┐
│                   YOUR DIGITAL LIFE                      │
│                                                          │
│  Phone ──── WireGuard VPN ───┐                          │
│  Laptop ─── WireGuard VPN ──┤                           │
│  Tablet ─── WireGuard VPN ──┤                           │
│                              ▼                           │
│  ┌─── YOUR VPS ────────────────────────────────────┐    │
│  │                                                  │    │
│  │  AdGuard ── blocks ads & trackers for all devices│    │
│  │                                                  │    │
│  │  Nextcloud ── files, calendar, contacts, office  │    │
│  │  Vaultwarden ── passwords for all devices        │    │
│  │  Immich ── photo backup with AI                  │    │
│  │  SearXNG ── private search                       │    │
│  │  Element/Matrix ── encrypted chat                │    │
│  │  Jitsi ── video calls                            │    │
│  │  Forgejo ── code hosting                         │    │
│  │  Stalwart ── email                               │    │
│  │                                                  │    │
│  │  Caddy ── auto-HTTPS for everything              │    │
│  │  WireGuard ── VPN endpoint                       │    │
│  │  Tor ── .onion access                            │    │
│  │  Backup ── encrypted, daily, remote              │    │
│  │  Grafana ── monitoring                           │    │
│  │                                                  │    │
│  └──────────────────────────────────────────────────┘    │
│                                                          │
│  Google: ❌ zero data                                    │
│  Microsoft: ❌ zero data                                 │
│  Apple: ❌ zero data                                     │
│  Meta: ❌ zero data                                      │
│                                                          │
│  YOU: ✅ everything                                      │
└─────────────────────────────────────────────────────────┘
```

---

## Maintenance Schedule

| Frequency | Task |
|-----------|------|
| **Daily** | Automated backups (cron) |
| **Weekly** | Check Grafana dashboards, review AdGuard query log |
| **Monthly** | Update containers: `docker compose pull && docker compose up -d` |
| **Quarterly** | Update Ubuntu: `apt update && apt upgrade -y` |
| **Yearly** | Review services, update blocklists, rotate passwords |

---

## What's Next?

### Want AI agent infrastructure too?

Check out **[Freedom Stack](https://github.com/Michae2xl/freedom-stack)** — the Agent Privacy Cloud. It adds:
- Ollama (local LLM)
- n8n (AI workflow automation)
- Qdrant (vector database)
- Agent Sandbox
- Tor Rotator

Install alongside Sovereign Stack:
```bash
curl -fsSL https://raw.githubusercontent.com/Michae2xl/freedom-stack/main/scripts/install.sh -o install.sh
bash install.sh --agents
```

### Want maximum mobile privacy?

- Flash **GrapheneOS** on a Pixel phone
- Use only F-Droid apps
- Route all traffic through your WireGuard VPN

### Want to help others?

- Star this repo
- Share with friends and family
- Contribute translations, guides, or code
- Help someone through their Phase 1

---

## Final Sovereignty Checklist

- [ ] All devices connected via WireGuard VPN
- [ ] All DNS queries via AdGuard Home
- [ ] All passwords in Vaultwarden
- [ ] All files syncing to Nextcloud
- [ ] All photos backing up to Immich
- [ ] All messages on Signal/Matrix
- [ ] All searches via SearXNG
- [ ] Email on own server or ProtonMail
- [ ] Caddy serving HTTPS on all services
- [ ] Encrypted backups running daily
- [ ] fail2ban + UFW protecting the server
- [ ] Tor .onion services configured (optional)
- [ ] Google data exported
- [ ] Google account emptied or deleted
- [ ] No Chrome, no Google DNS, no Google anything

---

<div align="center">

**You are Sovereign.**

Every byte is yours. Every connection is encrypted.
Every service answers to you. No corporation stands between
you and your digital life.

**Privacy is not a feature. It's a right.**

</div>
