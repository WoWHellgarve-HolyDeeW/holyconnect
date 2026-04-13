#!/bin/bash
###############################################################################
#  HolyConnect - Pi-Star USB Tethering Setup
#  https://github.com/WoWHellgarve-HolyDeeW/holyconnect
#
#  Sets up USB RNDIS gadget with Microsoft OS Descriptors so Windows
#  auto-detects the Pi as a network adapter. No manual driver install needed.
#
#  USAGE (from Pi-Star SSH or via systemd.run):
#    sudo bash /boot/install.sh
#
#  WHAT IT DOES:
#    1. Creates configfs USB RNDIS gadget with MS OS Descriptors
#    2. Creates systemd service to start gadget at boot
#    3. Configures usb0 network (DHCP with static fallback)
#    4. Enables SSH
#    5. Reboots
#
#  COMPATIBLE WITH:
#    - Pi-Star 4.x on Raspberry Pi Zero W / Zero 2 W
#    - Raspberry Pi OS style systems using /boot, systemd, dhcpcd and dwc2 OTG
###############################################################################

set +e  # Don't abort on non-critical errors
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

HOLYCONNECT_VERSION="1.0.1"
GADGET_SCRIPT="/usr/local/bin/usb-gadget.sh"
GADGET_SERVICE="/etc/systemd/system/usb-gadget.service"
LOG="/boot/holyconnect_install.log"

# Redirect output to log
exec > >(tee "$LOG") 2>&1

echo "========================================"
echo "  HolyConnect v${HOLYCONNECT_VERSION}"
echo "  Pi-Star USB Tethering Installer"
echo "========================================"
echo "Date: $(date)"
echo "Host: $(hostname)"
echo "Kernel: $(uname -r)"
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this installer as root (sudo bash /boot/install.sh)."
    exit 1
fi

if [ ! -f /boot/cmdline.txt ] || [ ! -f /boot/config.txt ]; then
    echo "ERROR: This installer expects a Pi-Star / Raspberry Pi OS style /boot partition."
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: systemctl not found. This installer requires systemd."
    exit 1
fi

if [ ! -f /etc/dhcpcd.conf ]; then
    echo "ERROR: /etc/dhcpcd.conf not found. This installer currently supports Pi-Star / Raspberry Pi OS style networking."
    exit 1
fi

# Wait for boot to settle
sleep 5

# ============================================
#  1. REMOUNT FILESYSTEMS READ-WRITE
# ============================================
echo "[1/8] Mounting filesystems read-write..."
mount -o remount,rw / 2>/dev/null || true
mount -o remount,rw /boot 2>/dev/null || true

# ============================================
#  2. UPDATE CMDLINE.TXT
# ============================================
echo "[2/8] Updating /boot/cmdline.txt..."
CMDLINE=$(cat /boot/cmdline.txt)

# Remove old systemd.run params (leftover from boot-time install)
CMDLINE=$(echo "$CMDLINE" | sed 's/ systemd\.run=[^ ]*//g')
CMDLINE=$(echo "$CMDLINE" | sed 's/ systemd\.run_success_action=[^ ]*//g')
CMDLINE=$(echo "$CMDLINE" | sed 's/ systemd\.run_failure_action=[^ ]*//g')

# Ensure dwc2 is in modules-load, remove g_ether (configfs replaces it)
if ! echo "$CMDLINE" | grep -q "modules-load=dwc2"; then
    CMDLINE="$CMDLINE modules-load=dwc2"
fi
CMDLINE=$(echo "$CMDLINE" | sed 's/modules-load=dwc2,g_ether/modules-load=dwc2/')

echo "$CMDLINE" > /boot/cmdline.txt
echo "  cmdline: $CMDLINE"

# Ensure dtoverlay=dwc2 in config.txt
if ! grep -q "^dtoverlay=dwc2" /boot/config.txt; then
    echo "dtoverlay=dwc2" >> /boot/config.txt
    echo "  Added dtoverlay=dwc2 to config.txt"
fi

# ============================================
#  3. CREATE USB GADGET SCRIPT
# ============================================
echo "[3/8] Creating USB gadget script..."
cat > "$GADGET_SCRIPT" << 'GADGETEOF'
#!/bin/bash
# HolyConnect - USB RNDIS Gadget with Microsoft OS Descriptors
# This makes Windows auto-detect Pi as a network adapter without manual driver install.

GADGET_DIR="/sys/kernel/config/usb_gadget/holyconnect"

# Load kernel module
modprobe libcomposite 2>/dev/null || true

# Tear down existing gadget cleanly
if [ -d "$GADGET_DIR" ]; then
    echo "" > "$GADGET_DIR/UDC" 2>/dev/null || true
    rm -f "$GADGET_DIR/os_desc/c.1" 2>/dev/null
    rm -f "$GADGET_DIR/configs/c.1/rndis.usb0" 2>/dev/null
    rmdir "$GADGET_DIR/configs/c.1/strings/0x409" 2>/dev/null
    rmdir "$GADGET_DIR/configs/c.1" 2>/dev/null
    rmdir "$GADGET_DIR/functions/rndis.usb0" 2>/dev/null
    rmdir "$GADGET_DIR/strings/0x409" 2>/dev/null
    rmdir "$GADGET_DIR" 2>/dev/null
fi

# Create gadget
mkdir -p "$GADGET_DIR"
cd "$GADGET_DIR"

# USB Device Descriptor
echo 0x0525 > idVendor       # Linux Foundation
echo 0xa4a2 > idProduct      # Linux-USB Ethernet/RNDIS Gadget
echo 0x0200 > bcdUSB         # USB 2.0
echo 0x0100 > bcdDevice
echo 0x02   > bDeviceClass   # Communications
echo 0x00   > bDeviceSubClass
echo 0x00   > bDeviceProtocol

# Microsoft OS Descriptors - CRITICAL for Windows auto-detection
# These tell Windows to use the built-in RNDIS driver automatically
echo 1       > os_desc/use
echo 0xcd    > os_desc/b_vendor_code
echo MSFT100 > os_desc/qw_sign

# Device strings
mkdir -p strings/0x409
echo "HC$(cat /proc/cpuinfo | grep Serial | awk '{print $3}' | tail -c 9)" > strings/0x409/serialnumber
echo "HolyConnect"          > strings/0x409/manufacturer
echo "Pi-Star USB Tether"   > strings/0x409/product

# Create RNDIS function with MS OS compatible IDs
mkdir -p functions/rndis.usb0
echo RNDIS   > functions/rndis.usb0/os_desc/interface.rndis/compatible_id
echo 5162001 > functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id

# Create configuration
mkdir -p configs/c.1/strings/0x409
echo "RNDIS Network" > configs/c.1/strings/0x409/configuration
echo 250             > configs/c.1/MaxPower

# Link function to configuration
ln -sf functions/rndis.usb0 configs/c.1/

# Link OS descriptors to configuration
ln -sf configs/c.1 os_desc/

# Bind to USB Device Controller
UDC=$(ls /sys/class/udc 2>/dev/null | head -1)
if [ -n "$UDC" ]; then
    echo "$UDC" > UDC
    echo "HolyConnect: RNDIS gadget active on $UDC"
else
    echo "HolyConnect: ERROR - No UDC found"
    exit 1
fi
GADGETEOF
chmod +x "$GADGET_SCRIPT"
echo "  Created: $GADGET_SCRIPT"

# ============================================
#  4. CREATE SYSTEMD SERVICE
# ============================================
echo "[4/8] Creating systemd service..."
cat > "$GADGET_SERVICE" << 'SVCEOF'
[Unit]
Description=HolyConnect USB RNDIS Gadget
DefaultDependencies=no
After=systemd-modules-load.service
Before=sysinit.target network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/usb-gadget.sh

[Install]
WantedBy=sysinit.target
SVCEOF
systemctl daemon-reload
systemctl enable usb-gadget.service
echo "  Service enabled"

# ============================================
#  5. CONFIGURE NETWORK (DHCP + STATIC FALLBACK)
# ============================================
echo "[5/8] Configuring usb0 network..."

# Remove any old usb0 config from dhcpcd.conf (handles re-runs cleanly)
sed -i '/# HolyConnect/,/^$/d' /etc/dhcpcd.conf 2>/dev/null
sed -i '/# USB RNDIS gadget/,/^$/d' /etc/dhcpcd.conf 2>/dev/null
sed -i '/# USB Ethernet gadget/,/^$/d' /etc/dhcpcd.conf 2>/dev/null
sed -i '/^interface usb0$/,/^$/d' /etc/dhcpcd.conf 2>/dev/null
sed -i '/^profile holyconnect_static$/,/^$/d' /etc/dhcpcd.conf 2>/dev/null
# Remove trailing blank lines
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' /etc/dhcpcd.conf 2>/dev/null

# Add clean config: try DHCP first (for ICS/NAT with DHCP server), fallback to static
cat >> /etc/dhcpcd.conf << 'DHCPEOF'

# HolyConnect - USB tethering network config
# Tries DHCP first; falls back to static if no DHCP server
interface usb0
fallback holyconnect_static

profile holyconnect_static
static ip_address=192.168.7.2/24
static routers=192.168.7.1
static domain_name_servers=8.8.8.8 8.8.4.4
DHCPEOF
echo "  dhcpcd.conf updated (DHCP + fallback 192.168.7.2)"

# ============================================
#  6. ENABLE SSH
# ============================================
echo "[6/8] Enabling SSH..."
systemctl enable ssh 2>/dev/null || true
touch /boot/ssh 2>/dev/null || true
echo "  SSH enabled"

# ============================================
#  7. UPDATE /ETC/MODULES
# ============================================
echo "[7/8] Updating kernel modules..."
sed -i '/^g_ether$/d' /etc/modules 2>/dev/null
grep -q "^dwc2$" /etc/modules 2>/dev/null || echo "dwc2" >> /etc/modules
grep -q "^libcomposite$" /etc/modules 2>/dev/null || echo "libcomposite" >> /etc/modules
echo "  /etc/modules: dwc2, libcomposite"

# ============================================
#  8. DONE - REBOOT
# ============================================
echo ""
echo "========================================"
echo "  HolyConnect installed successfully!"
echo "  Rebooting in 5 seconds..."
echo "========================================"
echo ""
echo "After reboot:"
echo "  1. Connect Pi to PC via USB (DATA port)"
echo "  2. Run HolyConnect.bat on Windows"
echo "  3. Dashboard: http://192.168.7.2/"
echo ""

sync
mount -o remount,ro / 2>/dev/null || true
mount -o remount,ro /boot 2>/dev/null || true
sleep 5
reboot -f
