# Phase 1: Hero — Leave Big Tech OS Behind

> *"The first step to freedom is owning the ground you stand on."*

---

## Why Linux?

Every time you use Windows or macOS, your computer talks to Microsoft or Apple:

- **Windows 11** sends telemetry data, app usage, typing patterns, voice recordings (Cortana), and browsing history to Microsoft. You cannot fully disable this — even "Enterprise" editions still phone home.
- **macOS** sends every app you open to Apple (OCSP checks), Siri recordings, iCloud metadata, and location data. The "privacy-first" marketing hides a data collection machine.

**Linux sends nothing.** Your computer works for you, not for a corporation.

---

## Choosing Your Distro

### For beginners (Windows refugees)

| Distro | Why | Download |
|--------|-----|----------|
| **Linux Mint** | Looks like Windows, everything works out of the box, huge community | [linuxmint.com](https://linuxmint.com/) |
| **Zorin OS** | Beautiful, designed for Windows/Mac switchers | [zorin.com](https://zorin.com/os/) |
| **Pop!_OS** | Great for gaming (Nvidia), clean design | [pop.system76.com](https://pop.system76.com/) |

### For developers

| Distro | Why | Download |
|--------|-----|----------|
| **Fedora** | Latest packages, SELinux security, Red Hat backed | [fedoraproject.org](https://fedoraproject.org/) |
| **Ubuntu** | Largest community, most tutorials | [ubuntu.com](https://ubuntu.com/desktop) |
| **Arch Linux** | Total control, rolling release (advanced) | [archlinux.org](https://archlinux.org/) |

### For maximum privacy

| Distro | Why | Download |
|--------|-----|----------|
| **Tails** | Amnesic (forgets everything on reboot), all traffic via Tor | [tails.net](https://tails.net/) |
| **Whonix** | Full Tor isolation in a VM | [whonix.org](https://www.whonix.org/) |
| **Qubes OS** | Security by compartmentalization (advanced) | [qubes-os.org](https://www.qubes-os.org/) |

**Our recommendation:** Start with **Linux Mint** if you've never used Linux. Move to Fedora or Arch later if you want.

---

## Step-by-Step Installation

### 1. Download your ISO

Go to your chosen distro's website and download the ISO file. Verify the checksum:

```bash
# Example for Linux Mint
sha256sum linuxmint-22-cinnamon-64bit.iso
# Compare with the sha256sum.txt on the download page
```

### 2. Create a bootable USB

**Option A: Ventoy (recommended — supports multiple ISOs)**
1. Download [Ventoy](https://ventoy.net/en/download.html)
2. Install Ventoy on a USB drive (8GB+)
3. Copy the ISO file to the USB — done. You can put multiple ISOs on the same USB.

**Option B: balenaEtcher (simple)**
1. Download [balenaEtcher](https://etcher.balena.io/)
2. Select ISO → Select USB → Flash

**Option C: Command line (Linux/Mac)**
```bash
# Find your USB device
lsblk

# Write ISO to USB (CAREFUL: replace /dev/sdX with your USB device)
sudo dd if=linuxmint-22-cinnamon-64bit.iso of=/dev/sdX bs=4M status=progress
sync
```

### 3. Boot from USB

1. Restart your computer
2. Press the boot menu key during startup:
   - **Dell:** F12
   - **HP:** F9
   - **Lenovo:** F12
   - **ASUS:** F8
   - **Acer:** F12
   - **Mac:** Hold Option key
3. Select your USB drive
4. Choose "Try Linux" to test without installing

### 4. Install

1. Double-click "Install" on the desktop
2. Follow the wizard:
   - Language → Keyboard → Timezone
   - **Disk:** "Erase disk and install" (if replacing Windows entirely)
   - Or "Install alongside Windows" for dual-boot
   - **Encrypt disk:** YES — use a strong passphrase (this encrypts your entire disk with LUKS)
   - Create your user account
3. Wait ~15 minutes → Reboot → Remove USB

### 5. Post-install

Run the install script or do it manually:

```bash
# Automated
curl -fsSL https://raw.githubusercontent.com/Michae2xl/sovereign-stack/main/install.sh -o install.sh
bash install.sh --local
```

**Or manually:**

```bash
# Update everything
sudo apt update && sudo apt upgrade -y

# Essential tools
sudo apt install -y curl wget git htop neofetch vim unzip

# Flatpak (universal app store)
sudo apt install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Firewall
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh

# Automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## Disk Encryption (LUKS)

If you didn't encrypt during install, you can still encrypt your home directory:

```bash
# Install encryption tools
sudo apt install -y ecryptfs-utils

# Encrypt home (log out of your user first, use root/another user)
sudo ecryptfs-migrate-home -u YOUR_USERNAME
```

**Better option:** Reinstall with full disk encryption (LUKS). It's worth the 15 minutes.

---

## What About My Windows Apps?

| Windows App | Linux Alternative | Notes |
|-------------|-------------------|-------|
| Microsoft Office | LibreOffice | Opens .docx/.xlsx/.pptx |
| Adobe Photoshop | GIMP / Krita | Krita for drawing, GIMP for editing |
| Adobe Premiere | Kdenlive / DaVinci Resolve | DaVinci is pro-grade and free |
| Notepad++ | Kate / Geany | Or just use VS Code/Codium |
| 7-Zip | File Roller (built-in) | Or `p7zip` from terminal |
| Games | Steam (native Linux) | Proton runs most Windows games |

**For apps with no Linux alternative:** Use [Bottles](https://usebottles.com/) or [Wine](https://www.winehq.org/) to run Windows apps on Linux.

---

## Dual Boot (Keep Windows)

If you're not ready to go full Linux:

1. Shrink your Windows partition (Disk Management → Shrink Volume)
2. Install Linux on the free space
3. GRUB bootloader lets you choose at startup
4. Over time, you'll use Windows less and less
5. Eventually: delete the Windows partition

---

## Troubleshooting

**WiFi not working?**
```bash
# Check if your card is detected
lspci | grep -i network
# Install missing firmware
sudo apt install -y linux-firmware
sudo reboot
```

**Nvidia GPU issues?**
```bash
# Install proprietary drivers
sudo ubuntu-drivers autoinstall  # Ubuntu/Mint
# or
sudo dnf install akmod-nvidia    # Fedora
sudo reboot
```

**Bluetooth not working?**
```bash
sudo apt install -y bluez blueman
sudo systemctl enable --now bluetooth
```

---

## Phase 1 Checklist

- [ ] Downloaded Linux ISO and verified checksum
- [ ] Created bootable USB
- [ ] Installed Linux (with disk encryption!)
- [ ] Updated system
- [ ] Installed essential tools
- [ ] Enabled firewall
- [ ] Enabled automatic updates
- [ ] Flatpak installed for app management

**You are now a Hero.** Your OS no longer spies on you.

→ [Next: Phase 2 — Guardian (Browser Hardening)](phase2-guardian.md)
