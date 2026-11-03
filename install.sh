#!/usr/bin/env bash
set -e

# Installer for Lenovo LOQ Linux dGPU Freeze Fix & Auto Refresh Rate Switcher

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo " Lenovo LOQ Linux dGPU Freeze Fix & Power Sync Installer"
echo "=========================================================="
echo ""

# 1. System-level Fix (Requires Root / sudo)
echo "[1/4] Installing system fix (udev rules & NVIDIA modprobe)..."
sudo cp "$SCRIPT_DIR/udev/80-nvidia-fix-loq.rules" /etc/udev/rules.d/
sudo cp "$SCRIPT_DIR/modprobe/nvidia-runtimepm.conf" /etc/modprobe.d/

echo "[2/4] Applying runtime settings (D3hot & unbind pciehp)..."
echo 0 | sudo tee /sys/bus/pci/devices/0000:01:00.0/d3cold_allowed >/dev/null 2>&1 || true
echo 0 | sudo tee /sys/bus/pci/devices/0000:00:01.0/d3cold_allowed >/dev/null 2>&1 || true
echo "0000:00:01.0:pcie004" | sudo tee /sys/bus/pci_express/drivers/pciehp/unbind >/dev/null 2>&1 || true

sudo udevadm control --reload-rules
sudo update-initramfs -u

# 2. User-level Auto Refresh Rate & Power Profile Switcher
echo "[3/4] Installing user auto-refresh service..."
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.config/systemd/user"

cp "$SCRIPT_DIR/bin/auto-refresh.sh" "$HOME/.local/bin/auto-refresh.sh"
chmod +x "$HOME/.local/bin/auto-refresh.sh"

cp "$SCRIPT_DIR/systemd/auto-refresh.service" "$HOME/.config/systemd/user/auto-refresh.service"

echo "[4/4] Activating systemd user service..."
systemctl --user daemon-reload
systemctl --user enable --now auto-refresh.service

echo ""
echo "=========================================================="
echo " Installation completed successfully!"
echo " - dGPU surprise removal on AC disconnect: FIXED."
echo " - Automatic 144Hz (AC) / 60Hz (Battery) switching: ACTIVE."
echo " - Automatic Balanced (AC) / Power Saver (Battery): ACTIVE."
echo "=========================================================="
