#!/usr/bin/env bash

# Auto Refresh Rate & Power Mode Switcher for Lenovo LOQ / Linux Wayland
# AC: 144Hz & Balanced Mode
# Battery: 60Hz & Power Saver Mode

AC_ONLINE_PATH="/sys/class/power_supply/ACAD/online"
MONITOR="eDP-1"
WAYLAND_MODE_144="1920x1080@144.001"
WAYLAND_MODE_60="1920x1080@60.001"
X11_RES="1920x1080"
X11_RATE_144="144"
X11_RATE_60="60"

last_state=""

# Clean exit handler
cleanup() {
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

apply_state() {
    if [[ ! -f "$AC_ONLINE_PATH" ]]; then
        return 1
    fi

    local current_state
    current_state=$(cat "$AC_ONLINE_PATH" 2>/dev/null)

    # Ignore if state hasn't changed (prevents duplicate runs from multiple upower events)
    if [[ -n "$last_state" && "$current_state" == "$last_state" ]]; then
        return 0
    fi
    last_state="$current_state"

    if [[ "$current_state" == "1" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] AC plugged in (online=1): Setting 144Hz & Balanced mode..."
        if [[ "$XDG_SESSION_TYPE" == "wayland" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
            gdctl set --logical-monitor --primary --monitor "$MONITOR" --mode "$WAYLAND_MODE_144" 2>/dev/null || true
        else
            xrandr --output "$MONITOR" --mode "$X11_RES" --rate "$X11_RATE_144" 2>/dev/null || true
        fi
        if command -v powerprofilesctl &>/dev/null; then
            powerprofilesctl set balanced 2>/dev/null || true
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] On battery (online=0): Setting 60Hz & Power Saver mode..."
        if [[ "$XDG_SESSION_TYPE" == "wayland" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
            gdctl set --logical-monitor --primary --monitor "$MONITOR" --mode "$WAYLAND_MODE_60" 2>/dev/null || true
        else
            xrandr --output "$MONITOR" --mode "$X11_RES" --rate "$X11_RATE_60" 2>/dev/null || true
        fi
        if command -v powerprofilesctl &>/dev/null; then
            powerprofilesctl set power-saver 2>/dev/null || true
        fi
    fi
}

# Run on startup
apply_state

# Monitor power events via upower
upower --monitor | while read -r _event; do
    apply_state
done
