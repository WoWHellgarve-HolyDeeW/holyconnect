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
- **Designed for most Windows 10/11 PCs and laptops** — just copy 2 files and double-click

## How It Works

```
┌─────────────┐    USB Cable     ┌──────────────┐     Wi-Fi/4G     ┌──────────┐
│  Pi-Star    │◄─────────────────►│  Windows PC  │◄────────────────►│ Internet │
│ 192.168.7.2 │   RNDIS Network  │ 192.168.7.1  │       NAT       │          │
└─────────────┘                   └──────────────┘                  └──────────┘
```

## Quick Start

### Step 1: Install on Pi (one time)

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

### Step 2: Connect to Windows

1. Copy the `windows/` folder to the target PC (or USB stick)
2. Connect Pi to PC via **USB cable** (use the **DATA** port on Pi, not PWR)
3. Double-click **`HolyConnect.bat`**
4. The script does everything automatically and opens the Pi-Star dashboard

That's it!

## What's in the Box

```
holyconnect/
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
| **DHCP fallback** | Pi tries DHCP first, falls back to static 192.168.7.2 |
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

## FAQ

**Q: Do I need a laptop to use my hotspot in the car?**
A: Yes, with HolyConnect you need a PC/laptop. Consider getting a USB Wi-Fi dongle for the Pi as a standalone alternative.

**Q: What if the PC's internet IP changes? (mobile hotspot, etc.)**
A: No problem. NAT adapts automatically. The Pi↔PC link is always 192.168.7.x.

**Q: Does this modify Pi-Star?**
A: It only adds a USB gadget service and network config. Pi-Star itself is untouched.

**Q: First time on a new PC — do I need to install drivers manually?**
A: Usually no. The MS OS Descriptors make Windows auto-detect it. On older Windows versions, the script guides you through a one-time manual driver install (~30 seconds).

**Q: Will this mess with Hyper-V, Docker, WSL or VPN networking?**
A: Current versions do not delete other Windows NAT rules. If `192.168.7.0/24` is already claimed, HolyConnect reuses that NAT when possible or keeps USB access local-only.

**Q: What if auto-detect picks the wrong internet adapter on a weird PC?**
A: Most PCs are fully automatic. For edge cases, run `HolyConnect.ps1 -InternetAdapterName "Adapter Name"` once from an elevated PowerShell window.

**Q: Can I use Wi-Fi dongle AND USB tethering?**
A: The Pi Zero W has only one USB port. You can use either a USB cable (HolyConnect) or a Wi-Fi dongle, not both simultaneously (unless you add a USB hub with OTG adapter).

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
- Output of the script

Pull requests welcome!

## License

MIT — see [LICENSE](LICENSE)

## Credits

Born from a dead Wi-Fi chip on a Pi Zero W and the stubbornness to not give up on a perfectly good MMDVM hotspot.

73 de HolyConnect!
