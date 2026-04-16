# HolyConnect

**USB tethering solution for Pi-Star MMDVM hotspots with dead Wi-Fi.**

Connect your Raspberry Pi Zero W running Pi-Star to a Windows 10/11 PC or laptop via USB cable. No Wi-Fi needed.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## The Problem

The BCM43430 Wi-Fi chip on Raspberry Pi Zero W boards is known to fail, especially on MMDVM hotspot boards from AliExpress (PIMMDVM01 and similar). When Wi-Fi dies, you lose all access to Pi-Star — no dashboard, no SSH, no configuration.

## The Solution

HolyConnect turns the Pi Zero W's USB port into a virtual network adapter using **USB RNDIS over configfs** with **Microsoft OS Descriptors**. This means:

- **Windows auto-detects it** as a network adapter (no manual driver install on most PCs)
- **Stable 192.168.7.x link** between Pi and PC
- **Internet sharing via NAT** — Pi-Star can reach DMR/YSF/D-Star reflectors through the PC's internet
- **Built for Windows 10/11 PCs and laptops** — after one-time SD flash/prep, normal use is just USB cable plus double-click

## How It Works

```
┌─────────────┐    USB Cable     ┌──────────────┐     Wi-Fi/4G     ┌──────────┐
│  Pi-Star    │◄─────────────────►│  Windows PC  │◄────────────────►│ Internet │
│ 192.168.7.2 │   RNDIS Network  │ 192.168.7.1  │       NAT       │          │
└─────────────┘                   └──────────────┘                  └──────────┘
```

## Quick Start

### Step 1: Flash and prepare the SD card on Windows (recommended, one time)

Start from an SD card you are willing to erase and an official Pi-Star image downloaded from [pistar.uk](https://www.pistar.uk/downloads/).

1. Insert the SD card into your Windows PC
2. Download the official Pi-Star `.zip` or extract the `.img` file
3. Extract the full HolyConnect package
4. Recommended: place the Pi-Star `.zip` or `.img` into `holyconnect/pistar-image/`
5. Simplest path: double-click `HolyConnect-Run-First.bat`
6. The launcher auto-detects whether the inserted card already has Pi-Star on it, even if Windows has not assigned a drive letter to the boot partition yet. If yes, it opens `PreparePiStarSD.bat`. If not, it opens `FlashPiStarSD.bat`.
7. The helper auto-detects the Pi-Star `.zip` or `.img`, auto-selects the only safe USB/SD target when there is just one, writes the image to the card, and prepares the first HolyConnect boot automatically

Windows should ask for administrator rights when the launcher starts.

Optional: the flasher now explains the difference between USB use with a PC/laptop and standalone/mobile use with a Wi-Fi dongle + phone hotspot, can ask for the Wi-Fi details before the long write starts, and now lets the user add multiple Wi-Fi networks in one setup. The user still types a normal SSID and password; HolyConnect automatically derives the WPA `psk` when it generates or copies `wpa_supplicant.conf` onto the SD card. If you prefer, you can still place your own `wpa_supplicant.conf` in `holyconnect/pistar-image/`. A template is included as `wpa_supplicant.example.conf`.

### Step 2: First boot on the Pi (one time)

Put the prepared SD card back into the Pi and power it on once.

On that first boot, the Pi runs the installer locally, applies the permanent USB gadget setup, and reboots automatically.

### Alternative if the card already has a clean Pi-Star image

If the SD card was already flashed with Pi-Star and you only need to add the HolyConnect bootstrap:

1. Insert the already-flashed Pi-Star SD card into your Windows PC
2. Simplest path: double-click `HolyConnect-Run-First.bat`
3. It should detect the mounted Pi-Star boot partition automatically and open `PreparePiStarSD.bat`
4. The helper auto-detects the Pi-Star boot partition, copies `install.sh`, and patches the boot files for first boot

No manual `cmdline.txt` editing is needed in the common case.

### Step 3: Connect to Windows (normal use)

After the first-boot prep is done, daily use is simple:

1. Copy the `windows/` folder to the target PC (or USB stick)
2. Connect Pi to PC via **USB cable** (use the **DATA** port on Pi, not PWR)
3. Double-click **`HolyConnect.bat`**
4. The script does everything automatically and opens the Pi-Star dashboard

### Advanced fallback: manual Pi-side install

Copy `pi-setup/install.sh` to the Pi-Star SD card's `/boot` partition, then boot with:

**Option A — Edit cmdline.txt (easiest):**
```
# Add to the END of /boot/cmdline.txt (same line, space-separated):
systemd.run=/boot/install.sh systemd.run_success_action=reboot systemd.run_failure_action=reboot
```

**Option B — Via SSH (if you have access):**
```bash
sudo bash /boot/install.sh
```

The Pi will reboot automatically after installation.

That's it!

## Project Layout

```
holyconnect/
├── START-HERE.txt         # Short first-use guide for extracted ZIP users
├── HolyConnect-Run-First.bat  # One-click first-time launcher for non-technical users
├── HolyConnect-Run-First.ps1  # Auto-detects whether to flash or just prepare the SD card
├── FlashPiStarSD.bat      # One-click flasher for an official Pi-Star image plus HolyConnect bootstrap
├── FlashPiStarSD.ps1      # SD flashing script
├── pistar-image/          # Recommended folder for the official Pi-Star .zip or .img download
│   └── wpa_supplicant.example.conf  # Optional Wi-Fi template for first boot
├── PreparePiStarSD.bat     # One-click SD bootstrap helper for clean Pi-Star cards
├── PreparePiStarSD.ps1     # SD preparation script
├── pi-setup/
│   └── install.sh          # One-time Pi-side installer
├── windows/
│   ├── HolyConnect.bat     # Double-click launcher (auto-elevates)
│   └── HolyConnect.ps1     # Main setup script
├── README.md               # This file
├── README.pt.md            # Portuguese version
└── LICENSE                 # MIT License
```

## Features

| Feature | Details |
|---------|---------|
| **Auto-detect** | Waits for Pi, scans multiple IPs, checks ARP table |
| **Auto-driver** | Tries `pnputil` + device restart before asking for manual install |
| **NAT internet** | Shares PC's internet with Pi via `New-NetNat` without deleting unrelated NAT rules |
| **Bilingual** | Auto-detects system language (English / Portuguese) |
| **No dependencies** | Uses only built-in Windows tools (PowerShell 5.1+) |
| **MS OS Descriptors** | Windows recognizes Pi as RNDIS device automatically |
| **One-click SD flash** | `FlashPiStarSD.bat` writes an official Pi-Star image to the SD card and prepares it for HolyConnect |
| **One-click SD prep** | `PreparePiStarSD.bat` prepares a clean Pi-Star boot partition from Windows before first boot |
| **One-click first-time launcher** | `HolyConnect-Run-First.bat` decides automatically whether to run the flasher or the SD prep helper |
| **DHCP fallback** | Pi tries DHCP first, falls back to static 192.168.7.2 |
| **Persistent logs** | Saves detailed USB / driver / adapter / NAT diagnostics to `windows/logs/*.log` with safe local fallbacks |
| **Support bundle** | Failures auto-export a diagnostics package, and `HolyConnect.ps1 -ExportDiagnostics` generates one on demand |
| **Adapter override** | Optional `-InternetAdapterName` for unusual VPN / corporate / VM-heavy PCs |

## Compatibility

### Pi-side
- Raspberry Pi Zero W, Zero 2 W (any board with USB OTG)
- Pi-Star 4.x (tested with 4.2.3)
- Raspberry Pi OS style systems that use `/boot`, `systemd`, `dhcpcd`, and `dwc2`

### Windows-side
- Windows 10 (1703+) and Windows 11
- PowerShell 5.1+ (built-in)
- Administrator rights required
- No third-party software needed
- On PCs with Hyper-V, WSL, Docker or VPN software, HolyConnect reuses an existing `192.168.7.0/24` NAT or stays local-only instead of changing other Windows NAT rules

### MMDVM Boards Tested
- PIMMDVM01 (AliExpress)
- ZUMspot
- Other boards with Pi Zero W should work

## Compatibility Matrix

These are operating expectations, not blanket guarantees. On USB Wi-Fi dongles, chipset matters more than brand name.

### Windows Scenarios

| Scenario | Status | Expected behavior |
|----------|--------|-------------------|
| Clean Windows 10/11 PC with admin rights | Primary target | Fully automatic in the common case, or one-time guided RNDIS install |
| Hyper-V / WSL / Docker / VPN-heavy PC | Supported with caveats | USB access should work; internet sharing may reuse an existing `192.168.7.0/24` NAT or stay local-only |
| No administrator rights | Not supported | Driver, IP and NAT steps are blocked by Windows by design |
| PC without internet | Supported for local setup | Pi-Star stays reachable over USB, but updates and reflectors will not work |

### USB Wi-Fi Dongle Scenarios

| Dongle family | Status | Notes |
|---------------|--------|-------|
| SMC Networks SMCWUSBS-N3 (EZ Connect N 150Mbps Wireless USB) | Confirmed working | Standalone test succeeded on this setup and the Pi joined a configured Wi-Fi network automatically |
| MT7601U-class 2.4 GHz dongles | Good candidate | Best first choice for standalone/mobile Pi-Star use; still test the exact model |
| RTL8188EU / RTL8188FTV-class 2.4 GHz dongles | Mixed | Often workable, but revisions vary a lot between sellers |
| Unknown dual-band nano dongles | High risk | Avoid unless already verified on Pi-Star; 5 GHz support is especially inconsistent |

### Standalone Diagnostics

After HolyConnect is installed on the Pi, each boot writes `/boot/holyconnect_standalone_status.txt` to the SD boot partition. Use it when standalone/mobile hotspot mode joins Wi-Fi but the dashboard is still not reachable. It records the Wi-Fi interface, MAC, SSID, IPv4, gateway, and the state of `ssh` and `lighttpd`.

## FAQ

**Q: Do I need a laptop to use my hotspot in the car?**
A: Yes, with HolyConnect you need a PC/laptop. Consider getting a USB Wi-Fi dongle for the Pi as a standalone alternative.

**Q: What if the PC's internet IP changes? (mobile hotspot, etc.)**
A: No problem. NAT adapts automatically. The Pi↔PC link is always 192.168.7.x.

**Q: Does this modify Pi-Star?**
A: It only adds a USB gadget service and network config. Pi-Star itself is untouched.

**Q: Do I need to edit cmdline.txt manually?**
A: No in the normal flow. Use `PreparePiStarSD.bat` on a clean Pi-Star SD card from Windows. Manual `cmdline.txt` editing is only the fallback path.

**Q: Do I start from an empty SD card?**
A: If you use `FlashPiStarSD.bat`, yes: start from a card you are willing to erase plus an official Pi-Star `.zip` or `.img` download. That helper writes the Pi-Star image first, then adds the HolyConnect first-boot bootstrap. `PreparePiStarSD.bat` is for cards that already have a clean Pi-Star image on them.

**Q: Where do I put the Pi-Star download?**
A: The recommended place is `holyconnect/pistar-image/`. `FlashPiStarSD.bat` also looks next to the HolyConnect folder and one folder above it, and if it still does not find the file it opens a file picker or asks for the path.

**Q: Can HolyConnect preload Wi-Fi too?**
A: Yes. The normal flow can ask for Wi-Fi details during the flash, let the user add multiple networks, and generate `wpa_supplicant.conf` automatically for that run. The user enters normal Wi-Fi details and HolyConnect automatically derives the WPA `psk` when preparing the SD. If you prefer, you can also place `holyconnect/pistar-image/wpa_supplicant.conf` manually with multiple `network={...}` blocks. This is optional and not required for HolyConnect USB mode.

**Q: Will it connect automatically to a phone hotspot later?**
A: Yes, if that hotspot SSID and password are already present in `wpa_supplicant.conf`. Pi-Star will automatically try known Wi-Fi networks when they are visible. If more than one known network is available, the highest `priority=` entry wins.

**Q: How do I diagnose standalone/mobile mode if the hotspot does not open the dashboard?**
A: Open `/boot/holyconnect_standalone_status.txt` from the SD card. That file shows the Wi-Fi interface, MAC, connected SSID, Wi-Fi IP, gateway, and the state of `ssh`, `lighttpd`, and the USB gadget service. If the phone that provides the hotspot can open the dashboard but another device cannot, that is usually hotspot client isolation rather than a HolyConnect fault.

**Q: Can HolyConnect prepare a stock Pi-Star over USB with only HolyConnect.bat?**
A: No. A stock Pi-Star must be prepared once from the SD card or via SSH first, because the USB gadget does not exist yet.

**Q: First time on a new PC — do I need to install drivers manually?**
A: Usually no. The MS OS Descriptors make Windows auto-detect it. HolyConnect now also tries every built-in Windows RNDIS INF it can find before falling back to the guided one-time manual install.

**Q: Where do I find logs if a new PC fails?**
A: HolyConnect writes a timestamped log to `windows/logs/` next to the script when possible. If that folder is not writable, it falls back to `%ProgramData%\HolyConnect\logs` or `%TEMP%\HolyConnect`. The log includes USB detection, driver install attempts, adapter selection, routes and NAT state.

**Q: How do I create a diagnostics package for support?**
A: Failures now try to auto-export a diagnostics package to `windows/diagnostics/` (with `%ProgramData%\HolyConnect\diagnostics` and `%TEMP%\HolyConnect\diagnostics` as fallbacks). To generate one on a successful run, start an elevated PowerShell window and run `HolyConnect.ps1 -ExportDiagnostics`.

**Q: Will this mess with Hyper-V, Docker, WSL or VPN networking?**
A: Current versions do not delete other Windows NAT rules. If `192.168.7.0/24` is already claimed, HolyConnect reuses that NAT when possible or keeps USB access local-only.

**Q: What if auto-detect picks the wrong internet adapter on a weird PC?**
A: Most PCs are fully automatic. For edge cases, run `HolyConnect.ps1 -InternetAdapterName "Adapter Name"` once from an elevated PowerShell window.

**Q: Can I use Wi-Fi dongle AND USB tethering?**
A: Not for HolyConnect on a Pi Zero W. The same USB data port is used in device mode for HolyConnect and in host mode for an external Wi-Fi dongle, so this is a one-or-the-other choice. Use HolyConnect first for setup, then disconnect the PC and switch the data port to an OTG adapter + Wi-Fi dongle for standalone use.

## Technical Details

### USB Gadget (configfs)
- VID: `0x0525` (Linux Foundation)
- PID: `0xa4a2` (Linux-USB Ethernet/RNDIS Gadget)
- MS OS Descriptor vendor code: `0xcd`
- MS OS signature: `MSFT100`
- RNDIS compatible ID: `RNDIS`
- RNDIS sub-compatible ID: `5162001`

### Networking
- Pi static fallback: `192.168.7.2/24`
- Windows static: `192.168.7.1/24`
- NAT name: `HolyConnectNAT`
- NAT prefix: `192.168.7.0/24`
- Pi gateway: `192.168.7.1`
- Pi DNS: `8.8.8.8`, `8.8.4.4`

## Contributing

Found a bug? Have a board that doesn't work? Open an issue with:
- Your Pi model and Pi-Star version
- The MMDVM board model
- Windows version
- The generated HolyConnect diagnostics package (or at least the log file)

See [CONTRIBUTING.md](CONTRIBUTING.md) for reporting guidelines and support details.

GitHub issue templates are included for bug reports and compatibility reports.

Pull requests welcome!

## License

MIT — see [LICENSE](LICENSE)

## Credits

Born from a dead Wi-Fi chip on a Pi Zero W and the stubbornness to not give up on a perfectly good MMDVM hotspot.

73 de HolyConnect!
