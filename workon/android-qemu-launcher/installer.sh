#!/bin/bash
# https://github.com/maximilionus/android-qemu-launcher
set -e
# install_mode option are : qemu and virtmanager
install_mode="${1:-qemu}"
provided_Android_image="${2:-android}"
if [ "$provided_Android_image" = "android" ]; then
	iso_url="https://sourceforge.net/projects/android-x86/files/Release%209.0/android-x86_64-9.0-r2.iso"
	iso_name="android-x86_64-9.0-r2.iso"
elif [ "$provided_Android_image" = "bliss" ]; then
	iso_url="https://sourceforge.net/projects/android-x86/files/Release%209.0/android-x86_64-9.0-r2.iso"
	iso_name="android-x86_64-9.0-r2.iso"
else
	echo "provided_Android_image = $provided_Android_image not supported !!"
	exit 1
fi

current_script_path="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
provided_Android_image="${current_script_path}/${iso_name}"
APP_NAME="Android Qemu Launcher"
ENTRY_NAME="$(echo "$APP_NAME" | sed 's/ /-/g')"
SCRIPT_NAME="launcher.sh"
SCRIPT_NAME_PATH="$current_script_path/${SCRIPT_NAME}"
ICON_PATH="$current_script_path/desktop_icon.svg"
_qemu_drive_size="${_qemu_drive_size:-20G}"
launcher_desktop_file_path="$HOME/.local/share/applications/${ENTRY_NAME}.desktop"
vm_conf_file="$current_script_path/vm.conf"
base64_icon="PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjxzdmcKICAgdmlld0JveD0iMCAwIDUxMi4wMDAwMSA1MTIuMDAwMDIiCiAgIGVuYWJsZS1iYWNrZ3JvdW5kPSJuZXcgMCAwIDkxOC42IDUxNS4xIgogICB2ZXJzaW9uPSIxLjEiCiAgIGlkPSJzdmcxIgogICBzb2RpcG9kaTpkb2NuYW1lPSJkZXNrdG9wX2ljb25fc3F1YXJlLnN2ZyIKICAgd2lkdGg9IjUxMiIKICAgaGVpZ2h0PSI1MTIiCiAgIGlua3NjYXBlOnZlcnNpb249IjEuMyAoMGUxNTBlZDZjNCwgMjAyMy0wNy0yMSkiCiAgIHhtbG5zOmlua3NjYXBlPSJodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy9uYW1lc3BhY2VzL2lua3NjYXBlIgogICB4bWxuczpzb2RpcG9kaT0iaHR0cDovL3NvZGlwb2RpLnNvdXJjZWZvcmdlLm5ldC9EVEQvc29kaXBvZGktMC5kdGQiCiAgIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICAgeG1sbnM6c3ZnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPGRlZnMKICAgICBpZD0iZGVmczEiIC8+CiAgPHNvZGlwb2RpOm5hbWVkdmlldwogICAgIGlkPSJuYW1lZHZpZXcxIgogICAgIHBhZ2Vjb2xvcj0iIzUwNTA1MCIKICAgICBib3JkZXJjb2xvcj0iI2VlZWVlZSIKICAgICBib3JkZXJvcGFjaXR5PSIxIgogICAgIGlua3NjYXBlOnNob3dwYWdlc2hhZG93PSJmYWxzZSIKICAgICBpbmtzY2FwZTpwYWdlb3BhY2l0eT0iMCIKICAgICBpbmtzY2FwZTpwYWdlY2hlY2tlcmJvYXJkPSJmYWxzZSIKICAgICBpbmtzY2FwZTpkZXNrY29sb3I9IiM1MDUwNTAiCiAgICAgaW5rc2NhcGU6Y2xpcC10by1wYWdlPSJmYWxzZSIKICAgICBzaG93Ym9yZGVyPSJ0cnVlIgogICAgIGxhYmVsc3R5bGU9ImRlZmF1bHQiCiAgICAgaW5rc2NhcGU6em9vbT0iMC41MDM0ODM1OCIKICAgICBpbmtzY2FwZTpjeD0iODIuNDI1NzI3IgogICAgIGlua3NjYXBlOmN5PSIxODMuNzIiCiAgICAgaW5rc2NhcGU6d2luZG93LXdpZHRoPSIyNTYwIgogICAgIGlua3NjYXBlOndpbmRvdy1oZWlnaHQ9IjEzNzEiCiAgICAgaW5rc2NhcGU6d2luZG93LXg9IjAiCiAgICAgaW5rc2NhcGU6d2luZG93LXk9IjMyIgogICAgIGlua3NjYXBlOndpbmRvdy1tYXhpbWl6ZWQ9IjEiCiAgICAgaW5rc2NhcGU6Y3VycmVudC1sYXllcj0iWE1MSURfMV8iIC8+CiAgPHN0eWxlCiAgICAgdHlwZT0idGV4dC9jc3MiCiAgICAgaWQ9InN0eWxlMSI+LnN0MHtmaWxsOiMzRERDODQ7fTwvc3R5bGU+CiAgPGcKICAgICBpZD0iWE1MSURfMV8iCiAgICAgaW5rc2NhcGU6bGFiZWw9IlhNTElEXzFfIgogICAgIHRyYW5zZm9ybT0idHJhbnNsYXRlKDAsMC4wMDM3NjM3NSkiPgogICAgPHBhdGgKICAgICAgIGNsYXNzPSJzdDAiCiAgICAgICBkPSJNIDUxMC45NTU2MiwzOTguOTYyMjcgSCAxLjA0NDM3OTQgQyA5LjIwNDI5MTgsMzEyLjUzMzgyIDU4LjYwNzg0MSwyMzguNzA2MDUgMTMxLjU0NzQ2LDE5OS4xODMyIEwgODkuMjQ5MTUsMTI1LjkxMDUyIGMgLTIuMzg2OTE0LC00LjEwNzcxIC0wLjk5OTE3NCwtOS4zMjU2MSAzLjEwODU0MSwtMTEuNzEyNTMgNC4xMDc2OTcsLTIuMzg2OTEgOS4zMjU1ODksLTAuOTk5MTcgMTEuNzEyNTA5LDMuMTA4NTQgbCA0Mi44NTM0Myw3NC4yMTYzNCBjIDMyLjY5NTE1LC0xNC45MzIwOSA2OS40OTgwMiwtMjMuMjU4NTMgMTA5LjA3NjM4LC0yMy4yNTg1MyAzOS41NzgzNCwwIDc2LjM4MTIxLDguMzI2NDQgMTA5LjA3NjM3LDIzLjI1ODUzIGwgNDIuODUzNDIsLTc0LjIxNjM0IGMgMi4zMzE0LC00LjEwNzcxIDcuNjA0ODEsLTUuNDk1NDUgMTEuNjU3LC0zLjEwODU0IDQuMDUyMjEsMi4zODY5MiA1LjQ5NTQ2LDcuNjA0ODIgMy4xMDg1NSwxMS43MTI1MyBsIC00Mi4yOTgzMiw3My4yNzI2OCBjIDcyLjk5NTEzLDM5LjUyMjg1IDEyMi4zOTg2OCwxMTMuMzUwNjIgMTMwLjU1ODU5LDE5OS43NzkwNyB6IE0gMzczLjAxNDI1LDMyNy4zNTQ4OCBjIDExLjgyMzU2LDAgMjEuNDI2NywtOS42MDMxNiAyMS4zNzEyLC0yMS4zNzEyIDAsLTExLjc2ODAzIC05LjU0NzY0LC0yMS4zNzEyIC0yMS4zNzEyLC0yMS4zNzEyIC0xMS43NjgwMywwIC0yMS4zNzEyLDkuNTQ3NjYgLTIxLjM3MTIsMjEuMzcxMiAwLDExLjc2ODA0IDkuNTQ3NjYsMjEuMzcxMiAyMS4zNzEyLDIxLjM3MTIgeiBtIC0yMzQuMDg0MDEsMCBjIDExLjgyMzU0LDAgMjEuNDI2NzEsLTkuNjAzMTYgMjEuMzcxMTksLTIxLjM3MTIgMCwtMTEuNzY4MDMgLTkuNTQ3NjUsLTIxLjM3MTIgLTIxLjM3MTE5LC0yMS4zNzEyIC0xMS43NjgwNCwwIC0yMS4zNzExOSw5LjU0NzY2IC0yMS4zNzExOSwyMS4zNzEyIDAsMTEuNzY4MDQgOS41NDc2NCwyMS4zNzEyIDIxLjM3MTE5LDIxLjM3MTIgeiIKICAgICAgIGlkPSJwYXRoMSIKICAgICAgIHN0eWxlPSJzdHJva2Utd2lkdGg6MC41NTUwOTYiIC8+CiAgPC9nPgo8L3N2Zz4K
"

pre_install(){	
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
			DRIVE_DIR="${current_script_path}/drives"
			DRIVE_NAME="android-image.qcow2.img"
			
			# Path to the VM drive mount location when using the "drive" CLI commands.
			DRIVE_MOUNT_PATH="./mnt/"
		EOF
	fi

	. "$vm_conf_file"

	DRIVE_PATH="${DRIVE_DIR}/${DRIVE_NAME}"
	mkdir -p -v "$DRIVE_DIR"

	if [ ! -f "$ICON_PATH" ];then
		echo "$base64_icon" | base64 --decode > "$ICON_PATH" 
	fi

	if [ ! -f "$provided_Android_image" ];then
		wget "${iso_url}"
	fi
}

create_script_2_manage_vm_via_qemu(){
	if [ ! -f "$SCRIPT_NAME_PATH" ];then
		tee "$SCRIPT_NAME_PATH" <<- 'EOF' > /dev/null 2>&1
		#!/bin/sh
		set -e
		. "{vm_conf_file}"
		WINDOW_TITLE="${1:-$WINDOW_TITLE}"
		provided_Android_image="${2:-}"
		cd_arg=""
		if [ -n "$provided_Android_image" ];then
			cd_arg="-cdrom "
		fi
		DRIVE_PATH="${DRIVE_DIR}/${DRIVE_NAME}"
		echo "Starting the VM in normal mode"
		qemu-system-x86_64 -enable-kvm -M q35 -m $RAM_SIZE -smp $CPU_CORES -cpu host -drive file="$DRIVE_PATH",if=virtio -usb -device virtio-tablet -device virtio-keyboard -device qemu-xhci,id=xhci -device virtio-vga-gl -display sdl,gl=on -machine vmport=off -net nic,model=virtio-net-pci -net user,hostfwd=tcp::$ADB_PORT-:5555 -name "$WINDOW_TITLE" -audio pa,model=ac97 ${cd_arg}"${provided_Android_image}"
		EOF
		sed -i "s|{vm_conf_file}|${vm_conf_file}|g" "$SCRIPT_NAME_PATH"
		chmod +x "$SCRIPT_NAME_PATH"
	fi
}

create_script_2_manage_vm_via_virtmanager(){
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

create_vm(){
	if qemu-img create -f qcow2 "$DRIVE_PATH" $_qemu_drive_size;then
		"$SCRIPT_NAME_PATH" "$WINDOW_TITLE - Install" "$provided_Android_image"
	else
		echo "failed to create qcow2"
		exit 1
	fi
}

pre_install

echo "Directories initialized."
if [ "$install_mode" = "qemu" ];then
	create_script_2_manage_vm_via_qemu
elif [ "$install_mode" = "virtmanager" ];then
	create_script_2_manage_vm_via_virtmanager
fi

create_launcher_desktop_file

create_vm
