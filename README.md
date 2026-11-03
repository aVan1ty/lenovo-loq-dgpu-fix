# Lenovo LOQ Linux dGPU Freeze Fix & Auto Refresh Rate Switcher

A complete fix and power optimization toolkit for **Lenovo LOQ / Legion laptops** running Linux (Ubuntu 24.04+, Debian, Fedora) with NVIDIA discrete GPUs under Wayland and X11.

---

## 🛑 The Problem

On modern Lenovo LOQ laptops running Linux with hybrid graphics (Intel UHD / Iris Xe + NVIDIA RTX), unplugging the AC charger causes the laptop to **freeze or hang indefinitely on the Ubuntu logo during shutdown or reboot**.

### Root Cause Analysis

When the charger is unplugged on battery power:
1. **EC/ACPI Power State Drop:** The Lenovo Embedded Controller (EC) aggressively switches power states, causing a momentary PCIe link drop or bus glitch on the discrete GPU while it is sleeping in **D3cold** (complete chip power cutoff).
2. **Surprise Removal Triggered:** Because the kernel attaches the PCIe Hotplug driver (`pciehp`) to the internal root port (`0000:00:01.0:pcie004`), Linux incorrectly assumes the GPU was physically disconnected (*Surprise Removal*).
3. **NVIDIA Kernel Deadlock:** The kernel attempts to unbind the NVIDIA driver (`nv_pci_remove()`). However, active user-space processes (such as Wayland, Chrome, Electron apps, or IDEs) still have open file descriptors on `/dev/nvidia*` (`usage_count > 0`).
4. **Kernel Log Evidence:**
   ```text
   [drm] [nvidia-drm] [GPU ID 0x00000100] Removing device
   [drm] [nvidia-drm] [GPU ID 0x00000100] Unloading driver
   NVRM: Attempting to remove device 0000:01:00.0 with non-zero usage count!
   ```
5. **Shutdown Hang:** The kernel enters an unrecoverable D-state deadlock. When you shut down, `systemd-shutdown` blocks forever waiting for the PCI device to be released.

---

## 💡 The Solution

This repository provides two essential fixes in one automated package:

1. **dGPU Surprise Removal Fix:**
   * **Unbinds `pciehp`** from the internal dGPU root port. The internal GPU is permanently soldered to the motherboard and should never trigger hotplug events.
   * **Keeps the GPU in `D3hot` instead of `D3cold`** (`d3cold_allowed=0` and `NVreg_DynamicPowerManagement=0x01`). The GPU chip powers down internally to save battery (< 1W), but the PCIe link and configuration space remain active so the hardware never drops off the bus.

2. **Auto Refresh Rate & Power Profile Switcher:**
   * **AC Connected:** Automatically sets display to **144Hz** and GNOME power profile to **Balanced**.
   * **Battery (Unplugged):** Automatically sets display to **60Hz** and GNOME power profile to **Power Saver**.
   * Native Wayland support using `gdctl` and GNOME Mutter DBus.

---

## 💻 Tested Hardware & Environment

* **Machine:** Lenovo LOQ 15IRX10 (83JE)
* **Processor:** Intel 13th/14th Gen Core i5 / i7
* **Integrated GPU:** Intel UHD Graphics (Alder Lake / Raptor Lake)
* **Discrete GPU:** NVIDIA GeForce RTX 5050 Mobile / RTX 40-series Mobile (Driver 570+ / 595+ Open Kernel Modules)
* **OS:** Ubuntu 24.04 LTS / 24.10 / Wayland (`mutter 50.1`)

---

## 🚀 Quick Installation

Clone this repository and run the automated installer:

```bash
git clone https://github.com/aVan1ty/lenovo-loq-dgpu-fix.git
cd lenovo-loq-dgpu-fix
chmod +x install.sh
./install.sh
```

### What `install.sh` Does:
1. Copies `/etc/udev/rules.d/80-nvidia-fix-loq.rules` (disables D3cold and unbinds `pciehp`).
2. Copies `/etc/modprobe.d/nvidia-runtimepm.conf` (sets `NVreg_DynamicPowerManagement=0x01`).
3. Updates `initramfs` and reloads udev rules.
4. Installs the user-level systemd service `auto-refresh.service` and background switcher `auto-refresh.sh`.
5. Enables and starts the service immediately.

---

## 🛠️ Manual Installation (Without Scripts)

If you prefer applying the changes manually:

### Step 1: Prevent dGPU Hot-Removal
Create `/etc/udev/rules.d/80-nvidia-fix-loq.rules`:
```udev
# Disable D3cold for NVIDIA dGPU and Root Port
ACTION=="add|bind", SUBSYSTEM=="pci", KERNEL=="0000:01:00.0", ATTR{d3cold_allowed}="0"
ACTION=="add|bind", SUBSYSTEM=="pci", KERNEL=="0000:00:01.0", ATTR{d3cold_allowed}="0"

# Unbind pciehp from dGPU root port
ACTION=="add", SUBSYSTEM=="pci_express", KERNEL=="0000:00:01.0:pcie004", DRIVER=="pciehp", RUN+="/bin/sh -c 'echo 0000:00:01.0:pcie004 > /sys/bus/pci_express/drivers/pciehp/unbind 2>/dev/null || true'"
```

### Step 2: Set NVIDIA Power Management to D3hot
Create `/etc/modprobe.d/nvidia-runtimepm.conf`:
```ini
options nvidia "NVreg_DynamicPowerManagement=0x01"
```

### Step 3: Apply & Update Initramfs
```bash
echo 0 | sudo tee /sys/bus/pci/devices/0000:01:00.0/d3cold_allowed
echo 0 | sudo tee /sys/bus/pci/devices/0000:00:01.0/d3cold_allowed
echo "0000:00:01.0:pcie004" | sudo tee /sys/bus/pci_express/drivers/pciehp/unbind 2>/dev/null || true
sudo udevadm control --reload-rules
sudo update-initramfs -u
```

---

## 🗑️ Uninstallation

To revert everything back to standard Ubuntu defaults:

```bash
cd lenovo-loq-dgpu-fix
chmod +x uninstall.sh
./uninstall.sh
```

---

## 📄 License
MIT License. Free to use, modify, and distribute.
