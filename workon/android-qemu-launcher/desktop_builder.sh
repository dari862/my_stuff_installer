#!/bin/sh
APP_NAME="Android Qemu Launcher"
ENTRY_NAME="android-qemu-launcher"
SCRIPT_NAME="./launcher.sh"
ICON_PATH="./desktop_icon.svg"

echo "[Desktop Entry]" > $HOME/.local/share/applications/${ENTRY_NAME}.desktop
echo "Name=${APP_NAME}" >> $HOME/.local/share/applications/${ENTRY_NAME}.desktop
echo "Exec=$(realpath ${SCRIPT_NAME})" >> $HOME/.local/share/applications/${ENTRY_NAME}.desktop
echo "Icon=$(realpath ${ICON_PATH})" >> $HOME/.local/share/applications/${ENTRY_NAME}.desktop
echo "Type=Application" >> $HOME/.local/share/applications/${ENTRY_NAME}.desktop
echo "Categories=Graphics;" >> $HOME/.local/share/applications/${ENTRY_NAME}.desktop
