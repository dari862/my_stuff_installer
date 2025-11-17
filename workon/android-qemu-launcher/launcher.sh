#!/bin/bash
set -e
cd "$(dirname "$0")"
. ./vm.conf

echo "Starting the VM in normal mode"
qemu-system-x86_64 -enable-kvm -M q35 -m $RAM_SIZE -smp $CPU_CORES -cpu host -drive file="$DRIVE_PATH",if=virtio -usb -device virtio-tablet -device virtio-keyboard -device qemu-xhci,id=xhci -device virtio-vga-gl -display sdl,gl=on -machine vmport=off -net nic,model=virtio-net-pci -net user,hostfwd=tcp::$ADB_PORT-:5555 -name $WINDOW_TITLE -audio pa,model=ac97
