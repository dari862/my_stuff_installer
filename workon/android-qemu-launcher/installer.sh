#!/bin/bash
# https://github.com/maximilionus/android-qemu-launcher
set -e
provided_Android_image="${2:-}"
if [ -z "$provided_Android_image" ]; then
	echo "Error: No path to Android image provided. Exiting."
	exit 1
fi
provided_Android_image="$(realpath "${provided_Android_image}")"
current_script_path="$(dirname $0)"
APP_NAME="Android Qemu Launcher"
ENTRY_NAME="$(echo "$APP_NAME" | sed 's/ /-/g')"
SCRIPT_NAME="launcher.sh"
SCRIPT_NAME_PATH="$current_script_path/${SCRIPT_NAME}"
ICON_PATH="./desktop_icon.svg"
ICON_PATH="$(realpath "${ICON_PATH}")"
_qemu_drive_size="${_qemu_drive_size:-20G}"
launcher_desktop_file_path="$HOME/.local/share/applications/${ENTRY_NAME}.desktop"
vm_conf_file="$current_script_path/vm.conf"

pre_install(){	
	mkdir -p -v "$(dirname "$DRIVE_PATH")"
	if [ ! -f "$vm_conf_file" ];then
		tee "$vm_conf_file" <<- EOF > /dev/null 2>&1
			# VM window title
			WINDOW_TITLE="Android VM"
			
			# Size of max RAM, allocated for this VM in MB.
			# The default is 4GB, and that's more than enough.
			RAM_SIZE=4096
			
			# Number of CPU cores available for VM.
			# By default will use 75% of cores.
			CPU_CORES=$(( $(nproc) - $(nproc) / 4 ))
			
			# Android Debug Bridge port forwards to this port on localhost.
			# This is the only way to use adb with VM, works only with ADB_ENABLED=true.
			ADB_PORT=4444
			
			# Path to the VM drive default location.
			# All dirs will be created automatically on "init" call.
			DRIVE_PATH="./drives/android-image.qcow2.img"
			
			# Path to the VM drive mount location when using the "drive" CLI commands.
			DRIVE_MOUNT_PATH="./mnt/"
		EOF
	fi
	. "$vm_conf_file"
}

install_vm_via_qemu(){
	if qemu-img create -f qcow2 "$DRIVE_PATH" $_qemu_drive_size;then
		qemu-system-x86_64 -enable-kvm-M q35 -m $RAM_SIZE -smp $CPU_CORES -cpu host -drive file="$DRIVE_PATH",if=virtio -usb -device virtio-tablet -device virtio-keyboard -device qemu-xhci,id=xhci -device virtio-vga-gl -display sdl,gl=on -machine vmport=off -net nic,model=virtio-net-pci -net user,hostfwd=tcp::$ADB_PORT-:5555 -name "$WINDOW_TITLE - Install" -cdrom "$provided_Android_image"
	fi
}

post_install_qemu(){
	if [ ! -f "$SCRIPT_NAME_PATH" ];then
		tee "$SCRIPT_NAME_PATH" <<- EOF > /dev/null 2>&1
			#!/bin/sh
			set -e
			echo "Starting the VM in normal mode"
			qemu-system-x86_64 -enable-kvm -M q35 -m $RAM_SIZE -smp $CPU_CORES -cpu host -drive file="$DRIVE_PATH",if=virtio -usb -device virtio-tablet -device virtio-keyboard -device qemu-xhci,id=xhci -device virtio-vga-gl -display sdl,gl=on -machine vmport=off -net nic,model=virtio-net-pci -net user,hostfwd=tcp::$ADB_PORT-:5555 -name "$WINDOW_TITLE" -audio pa,model=ac97
			
		EOF
	fi
	chmod +x "$SCRIPT_NAME_PATH"
}

install_vm_via_virtmanager(){
	:
}

post_install_virtmanager(){
	:
}

create_launcher_desktop_file(){
	tee "$launcher_desktop_file_path" <<- EOF > /dev/null 2>&1
	[Desktop Entry]
	Name=${APP_NAME}
	Exec=$SCRIPT_NAME_PATH
	Icon=$ICON_PATH
	Type=Application
	Categories=Graphics;
	EOF
}

pre_install

echo "Directories initialized."
if command -v qemu-img >/dev/null 2>&1;then
	install_vm_via_qemu
	post_install_qemu
fi

create_launcher_desktop_file
