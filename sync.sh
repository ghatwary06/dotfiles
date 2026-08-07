#!/usr/bin/env bash
# Pull the live config on this machine into the repo.
#
# Copy-based, not symlink-based: the repo is a snapshot you push, and the real
# configs stay where the apps expect them. Run this, look at `git diff`, commit.
#
# Deliberately an EXPLICIT list rather than a copy-everything-and-ignore rule.
# ~/.config is full of application state, caches, vendored trees and browser
# profiles; an allowlist can't leak one by accident.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HOME"

# Whole directories. rsync --delete so a file removed upstream is removed here.
DIRS=(
    .config/quickshell/panel   # side panel, bar strip, dashboard
    .config/waybar
    .config/rofi
    .config/kitty
    .config/fastfetch
    .config/swaync
    .config/yazi
    .config/btop
    .config/nvim
    .config/gtk-4.0
)

# Individual files, where the directory around them is mostly junk or state.
FILES=(
    .config/hypr/hyprland.lua
    .config/hypr/rice.lua
    .config/hypr/monitors.lua
    .config/hypr/hyprland.conf
    .config/hypr/rice.conf
    .config/hypr/monitors.conf
    .config/hypr/workspaces.conf
    .config/hypr/hyprlock.conf
    .config/hypr/hypridle.conf
    .config/hypr/screenshot-delayed.sh

    .config/niri/config.kdl

    .config/gtk-3.0/settings.ini
    .config/gtk-3.0/gtk.css
    .config/gtk-3.0/colors.css
    .gtkrc-2.0

    .config/cava/config
    .config/fish/config.fish

    .local/bin/hypr-log-capture
    .local/bin/wallfetch
    .local/bin/speaker
    .config/systemd/user/hypr-log-capture.service
    .config/systemd/user/easyeffects-service.service
)

for d in "${DIRS[@]}"; do
    [[ -d $d ]] || { echo "skip (missing): $d"; continue; }
    mkdir -p "$REPO/$d"
    rsync -a --delete \
        --exclude '*.bak' --exclude '*~' --exclude '.git' \
        "$d/" "$REPO/$d/"
done

for f in "${FILES[@]}"; do
    [[ -f $f ]] || { echo "skip (missing): $f"; continue; }
    mkdir -p "$REPO/$(dirname "$f")"
    cp -p "$f" "$REPO/$f"
done

echo
echo "synced into $REPO — review with: git -C '$REPO' status"
