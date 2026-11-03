#!/usr/bin/env bash
set -e

echo "=========================================================="
echo " Lenovo LOQ Linux dGPU Freeze Fix Uninstaller"
echo "=========================================================="
echo ""

# 1. Stop and remove user service
echo "[1/3] Removing user auto-refresh service..."
systemctl --user stop auto-refresh.service 2>/dev/null || true
systemctl --user disable auto-refresh.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/auto-refresh.service"
rm -f "$HOME/.local/bin/auto-refresh.sh"
systemctl --user daemon-reload

# 2. Remove system-level configs
echo "[2/3] Removing udev and modprobe configurations..."
sudo rm -f /etc/udev/rules.d/80-nvidia-fix-loq.rules
sudo rm -f /etc/modprobe.d/nvidia-runtimepm.conf
sudo udevadm control --reload-rules

# 3. Update initramfs
echo "[3/3] Updating initramfs..."
sudo update-initramfs -u

echo ""
echo "=========================================================="
echo " Uninstallation completed. System restored to default."
echo "=========================================================="
