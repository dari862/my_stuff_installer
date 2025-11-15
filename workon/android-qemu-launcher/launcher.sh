#!/bin/bash

# Exit on first error
set -e

# Change the workdir to the script location
cd "$(dirname "$0")"

# Load the configuration files
. ./vm.conf

if [ -f "$CUSTOM_CONFIG_PATH" ]; then
    . $CUSTOM_CONFIG_PATH
fi

# Core components for global use within the scope of this project.
require_root () {
    if [[ $(/usr/bin/id -u) -ne 0 ]]; then
        echo "This action reqires the root privileges"
        exit 1
    fi
}

# Drive image (qcow2) managing utilities
__driveutils_load_modules () {
    echo "[ Loading the kernel modules ]"
    modprobe -v nbd max_part=8
}

__driveutils_unload_modules () {
    echo "[ Unloading the kernel modules ]"
    rmmod -v nbd
}

__driveutils_nbd_connect () {
    echo "[ Connecting the drive to NBD ]"
    qemu-nbd --connect=/dev/nbd0 $DRIVE_PATH
}

__driveutils_nbd_disconnect () {
    echo "[ Disconnecting the drive from NBD ]"
    qemu-nbd --disconnect /dev/nbd0
}

__driveutils_nbd_mount () {
    echo "[ Mounting the drive image to the '$(realpath $DRIVE_MOUNT_PATH)' directory]"

    mount_tries=1
    until mount /dev/nbd0p1 "$DRIVE_MOUNT_PATH"; do
        echo "- Attempting to mount the drive. Attempt: $mount_tries"

        if ((mount_tries >= 5)); then
            echo "[ Can not mount the drive. Shutting down. ]"
            set +e
            __driveutils_nbd_umount
            __driveutils_nbd_disconnect
            __driveutils_unload_modules
            __driveutils_mountdir_delete
            exit 1
        fi

        ((mount_tries++))
        sleep 2
    done

    echo "[ Drive was successfully mounted ]"
}

__driveutils_nbd_umount () {
    echo "[ Unmounting the drive image from the '$(realpath $DRIVE_MOUNT_PATH)' directory]"
    umount -v "$DRIVE_MOUNT_PATH"
    echo "[ Drive was successfully unmounted ]"
}

__driveutils_mountdir_create () {
    echo "[ Creating the mount dir ]"
    mkdir -v -p "$DRIVE_MOUNT_PATH"
}

__driveutils_mountdir_delete () {
    echo "[ Removing the mount dir ]"
    rm -rfv "$DRIVE_MOUNT_PATH"
}


# Load kernel modules and mount the drive to a local folder inside the root
# of current project
driveutils_mount () {
    require_root

    __driveutils_load_modules
    __driveutils_nbd_connect
    __driveutils_mountdir_create
    __driveutils_nbd_mount
}

# Unmount the drive and unload the kernel modules
driveutils_umount () {
    require_root

    __driveutils_nbd_umount
    __driveutils_nbd_disconnect
    __driveutils_unload_modules
    __driveutils_mountdir_delete
}

# Process the CLI args
driveutils_cli_process_args () {
    arguments_arr=("${@}")

    if ([ $# -eq 0 ] || [ "${arguments_arr[0]}" = "help" ]); then
        echo "Usage: ./launcher.sh drive [COMMAND]"
        echo "About: Set of utilities to manage the VM drive."
        echo
        echo "COMMANDS:"
        echo "  help   : (Default) Show this help message."
        echo "  mount  : Mount the VM drive to the path provided with"
        echo "           'DRIVE_MOUNT_PATH' var in the configuration file."
        echo "  umount : Unmount the VM drive and unload all modules."
        echo ""
        echo "NOTES:"
        echo "  The \"mount\" and \"umount\" commands require root privileges"
        echo "  to execute."
    elif ([ "${arguments_arr[0]}" == "mount" ]); then
        driveutils_mount
    elif ([ "${arguments_arr[0]}" == "umount" ]); then
        driveutils_umount
    else
        echo "Error: Invalid argument: \"${arguments_arr[0]}\""
        exit 1
    fi

    exit 0
}


# Default args for qemu
arguments_list=(
    "-enable-kvm"
    "-M" "q35"
    "-m" "$RAM_SIZE"
    "-smp" "$CPU_CORES"
    "-cpu" "host"
    "-drive" "file=$DRIVE_PATH,if=virtio"
    "-usb"
    "-device" "virtio-tablet"
    "-device" "virtio-keyboard"
    "-device" "qemu-xhci,id=xhci"
    "-device" "virtio-vga-gl"
    "-display" "sdl,gl=on"
    "-machine" "vmport=off"
    "-net" "nic,model=virtio-net-pci"
)

# Add config-based args
if [ "$ADB_ENABLE" = true ] ; then
    arguments_list+=("-net" "user,hostfwd=tcp::$ADB_PORT-:5555")
else
    arguments_list+=("-net" "user")
fi

# Process params
# TODO: Split implementation to module
if ([ $# -eq 0 ] || [ "$1" = "run" ]); then
    # Launch the VM in default mode
    arguments_list+=(
        "-name" "$WINDOW_TITLE"
        "-audio" "pa,model=ac97"
    )
    echo "Starting the VM in normal mode"
elif [ "$1" = "install" ]; then
    # Launch installation mode
    if [ -z "$2" ]; then
        echo "Error: No path to Android image provided. Exiting."
        exit 1
    fi

    arguments_list+=(
        "-name" "$WINDOW_TITLE - Install"
        "-cdrom" "$2"
    )

    echo "Starting the VM in installation mode"
    echo
    echo "Please read the manual in ./docs/ for your ROM if its"
    echo "officially supported by this launcher"
    echo
    echo "NOTE: Be sure to select the MBR (DOS) layout for the drive with"
    echo "      ext4 formatting and GRUB bootloader enabled."
elif [ "$1" = "init" ]; then
    # Initialize file structure for this launcher
    mkdir -p -v $(dirname "$DRIVE_PATH")

    echo "Directories initialized."
    read -p "Enter VM drive size (default: 20G): " _qemu_drive_size
    _qemu_drive_size="${_qemu_drive_size:-20G}"
    qemu-img create -f qcow2 "$DRIVE_PATH" $_qemu_drive_size

    echo
    echo "Everything is done. Now you should download the desired"
    echo "Android (x86_64 arch) image and launch this scipt with \"install\""
    echo "argument, providing the path to the image."
    echo
    echo "EXAMPLE:"
    echo "  ./launcher.sh install ~/Downloads/downloaded-android-image.iso"
    exit 0
elif [ "$1" = "drive" ]; then
    driveutils_cli_process_args "${@:2}"
elif [ "$1" = "d_args" ]; then
    echo "Composed arguments array:"
    echo "${arguments_list[@]}"
    exit 0
elif [ "$1" = "help" ]; then
    # Show help messages
    echo "Usage: ./launcher.sh [COMMAND]"
    echo
    echo "COMMANDS:"
    echo "  run             : (Default) Run the Virtual Machine in normal mode."
    echo "  init            : Prepare everything for VM, initialize drives."
    echo "  install <IMAGE> : Run the Virtual Machine in installation mode with"
    echo "                    <IMAGE> path to the Android image to be"
    echo "                    installed."
    echo "  drive <CMD>     : Set of utilities to manage the VM drive."
    echo "  help            : Show this help message."
    echo
    echo "DEBUG COMMANDS:"
    echo "  d_args          : Print the composed array of arguments and exit."
    echo
    echo "NOTES:"
    echo "  \"(Default)\" argument will be selected automatically, if no arguments"
    echo "  are provided to the script."
    exit 0
else
    echo "Error: Invalid argument: $1"
    exit 1
fi

qemu-system-x86_64 "${arguments_list[@]}"
