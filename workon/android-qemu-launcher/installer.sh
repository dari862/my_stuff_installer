#!/bin/bash
# https://github.com/maximilionus/android-qemu-launcher
set -e
provided_Android_image=${2:-}
if [ -z "$provided_Android_image" ]; then
	echo "Error: No path to Android image provided. Exiting."s
	exit 1
fi
APP_NAME="Android Qemu Launcher"
ENTRY_NAME="android-qemu-launcher"
SCRIPT_NAME="./launcher.sh"
ICON_PATH="./desktop_icon.svg"

cd "$(dirname $0)"
. "vm.conf"
_qemu_drive_size="${_qemu_drive_size:-20G}"

mkdir -p -v $(dirname "$DRIVE_PATH")

echo "Directories initialized."
if qemu-img create -f qcow2 "$DRIVE_PATH" $_qemu_drive_size;then
	qemu-system-x86_64 -enable-kvm-M q35 -m $RAM_SIZE -smp $CPU_CORES -cpu host -drive file=$DRIVE_PATH,if=virtio -usb -device virtio-tablet -device virtio-keyboard -device qemu-xhci,id=xhci -device virtio-vga-gl -display sdl,gl=on -machine vmport=off -net nic,model=virtio-net-pci -net user,hostfwd=tcp::$ADB_PORT-:5555 -name "$WINDOW_TITLE - Install" -cdrom "$provided_Android_image"
	
	
	echo "[Desktop Entry]" > $HOME/.local/share/applications/"${ENTRY_NAME}".desktop
	echo "Name=${APP_NAME}" >> $HOME/.local/share/applications/"${ENTRY_NAME}".desktop
	echo "Exec=$(realpath ${SCRIPT_NAME})" >> $HOME/.local/share/applications/"${ENTRY_NAME}".desktop
	echo "Icon=$(realpath ${ICON_PATH})" >> $HOME/.local/share/applications/"${ENTRY_NAME}".desktop
	echo "Type=Application" >> $HOME/.local/share/applications/"${ENTRY_NAME}".desktop
	echo "Categories=Graphics;" >> $HOME/.local/share/applications/"${ENTRY_NAME}".desktop
fi
