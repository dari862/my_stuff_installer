#!/bin/bash
# xvkbd
# JustAGuy Linux - DWM Setup
# https://github.com/drewgrif/dwm-setup

set -e
# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/suckless"
TEMP_DIR="/tmp/dwm_$$"
LOG_FILE="$HOME/dwm-install.log"

# Logging and cleanup
exec > >(tee -a "$LOG_FILE") 2>&1
trap "rm -rf $TEMP_DIR" EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
msg() { echo -e "${CYAN}$*${NC}"; }

cd "$SCRIPT_DIR"

if command -v  apt-get >/dev/null 2>&2;then
    # Update system
    msg "Updating system..."
    sudo apt-get update && sudo apt-get upgrade -y

    msg "Installing build dependencies..."
    sudo apt-get install -y  cmake pkg-config build-essential sxhkd || die "Failed to install build tools"
elif command -v  pacman >/dev/null 2>&2;then
    msg "Installing build dependencies..."
    sudo pacman -Sy  base-devel libx11 libxft libxinerama || die "Failed to install build tools"
fi
# Copy configs
msg "Setting up configuration..."
mkdir -p "$CONFIG_DIR"
cp -r suckless/* "$CONFIG_DIR"/ || die "Failed to copy configs"
cd "$CONFIG_DIR"

# Build suckless tools
msg "Building suckless tools..."
for tool in dwm slstatus st; do
    cd "$tool" || die "Cannot find $tool"
    make && sudo make clean install || die "Failed to build $tool"
    cd ..
done

# Create desktop entry for DWM
sudo mkdir -p /usr/share/xsessions
sudo tee /usr/share/xsessions/dwm.desktop >/dev/null 2>&2 <<EOF
[Desktop Entry]
Name=dwm
Comment=Dynamic window manager
Exec=dwm
Type=XSession
EOF

sudo tee /usr/share/applications/st.desktop >/dev/null 2>&2 <<EOF
[Desktop Entry]
Name=st
Comment=Simple Terminal
Exec=st
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
EOF

msg "Downloading wallpaper directory..."
cd "$CONFIG_DIR"
git clone --depth 1 --filter=blob:none --sparse https://github.com/drewgrif/butterscripts.git "$TEMP_DIR/butterscripts-wallpaper" || die "Failed to clone butterscripts"
cd "$TEMP_DIR/butterscripts-wallpaper"
git sparse-checkout set wallpaper || die "Failed to set sparse-checkout"
cp -r wallpaper "$CONFIG_DIR" || die "Failed to copy wallpaper directory"

msg "done"
