#!/bin/bash
echo "=== Dell Workstation Inventory Script ==="
echo "User: $(whoami) | Date: $(date) | Hostname: $(hostname)"
echo "=================================================="

echo "1. System Identification:"
sudo dmidecode -t system 2>/dev/null | grep -E 'Manufacturer|Product Name|Serial Number|UUID|Version|SKU' \
  || { echo "Manufacturer: $(cat /sys/class/dmi/id/board_vendor 2>/dev/null)"; \
       echo "Product Name: $(cat /sys/class/dmi/id/product_name 2>/dev/null)"; \
       echo "Serial Number: $(cat /sys/class/dmi/id/product_serial 2>/dev/null)"; }
echo ""

echo "2. CPU:"
lscpu | grep -E 'Model name|Socket|Thread|Core|CPU\(s\)|NUMA|CPU MHz'
echo ""

echo "3. Memory/RAM:"
free -h
echo "Detailed DIMMs:"
sudo dmidecode -t memory 2>/dev/null | grep -E 'Size:|Speed:|Manufacturer:|Part Number:|Locator:' | head -30
echo ""

echo "4. Storage:"
lsblk -d -o NAME,SIZE,MODEL,TRAN,ROTA,TYPE
df -hT
if command -v zpool >/dev/null 2>&1; then
  echo "ZFS pools:"
  zpool status 2>/dev/null || true
  zpool list -v 2>/dev/null || true
  zfs get encryption,special_small_blocks,compression rpool 2>/dev/null || true
fi
echo ""

echo "5. GPUs & Graphics:"
lspci -nnk | grep -E 'VGA|3D|Display|NVIDIA|AMD|ATI|Controller' -A 3
echo "NVIDIA status:"
if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi; else echo "No nvidia-smi found."; fi
echo "AMD DRI:"
ls -la /dev/dri/ 2>/dev/null || echo "No /dev/dri"
echo ""

echo "6. PCIe/Expansion:"
lspci -tv 2>/dev/null | head -40
echo ""

echo "7. Motherboard & BIOS:"
sudo dmidecode -t baseboard 2>/dev/null | grep -E 'Manufacturer|Product|Version' \
  || echo "Board: $(cat /sys/class/dmi/id/board_name 2>/dev/null)"
sudo dmidecode -t bios 2>/dev/null | grep -E 'Vendor|Version|Release Date' \
  || echo "BIOS: $(cat /sys/class/dmi/id/bios_version 2>/dev/null)"
echo ""

echo "8. Kernel & OS:"
uname -a
cat /etc/os-release 2>/dev/null
echo ""

echo "9. USB:"
lsusb
echo "=================================================="
echo "=== End of Report - Paste this full output back ==="