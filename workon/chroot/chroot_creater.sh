#!/bin/sh
set -e

ERROR() {
	_msg_="${1-}"
	printf "\033[0;31m[$0]${_msg_}[ERROR]\033[0m\n"
	exit 1
}

SUCCESS() {
	_msg_="${1-}"
	printf "\033[0;32m[$0]${_msg_}[SUCCESS]\033[0m\n"
}

INFO() {
	_msg_="${1-}"
	printf "\033[1;35m[$0]${_msg_}[INFO]\033[0m\n"
}

if [ "$(id -u)" -ne 0 ];then
    ERROR "This script must be run as root!"
fi

INFO "Installing debootstrap and schroot, if missing."

DEPS="
    debootstrap
    schroot
"

for dep in ${DEPS};do
    if ! command -v "$dep" > /dev/null;then
        INFO "Installing missing dependency \"$dep\"."
        apt-get install --no-install-recommends --yes "$dep"
    fi
done

ARCH=amd64
CHROOT_DIR=
CHROOT_GROUP=
CHROOT_NAME=
CHROOT_USER=
DEBIAN_RELEASE=
DRY_RUN=false
PERSONALITY=linux
PROFILE=
TYPE=plain

usage() {
    echo "Usage: $0 [args]"
    echo
    echo "Args:"
    echo "-c, --chroot   : The name of the chroot jail."
    echo "-d, --dir      : The directory in which to install the chroot (defaults to /srv/chroot)."
    echo "-t, --type     : The name of the type of the chroot. Defaults to 'plain'."
    echo "-u, --user     : The name of the chroot user. Must be a user on the host machine."
    echo "-g, --group    : The name of the chroot group. Must be a group on the host machine."
    echo "-p, --profile  : The name of the profile. See the README for more information."
    echo "-r, --release  : The Debian release that will be bootstrapped in the jail:"
    echo "      - jessie     (8)"
    echo "      - stretch    (9)"
    echo "      - buster    (10)"
    echo "      - bullseye  (11)"
    echo "      - bookworm  (12)"
    echo "--32           : Set this flag if the chroot is to be 32-bit on a 64-bit system."
    echo "--dry-run      : Write the config to STDOUT and exit (will not run the program)."
    echo "-h, --help     : Show usage."
    exit "$1"
}

create_schroot_config_file(){
	tee "/etc/schroot/chroot.d/$CHROOT_NAME" <<- EOF >/dev/null 2>&1
	[$CHROOT_NAME]
	description=Debian ($DEBIAN_RELEASE)
	type=$TYPE
	directory=$CHROOT_DIR
	personality=$PERSONALITY
	profile=$PROFILE
	users=$CHROOT_USER
	root-users=$CHROOT_USER
	groups=$CHROOT_GROUP
	root-groups=$CHROOT_GROUP
	EOF
}

if [ "$#" -eq 0 ];then
    usage 1
fi

while [ "$#" -gt 0 ];do
    OPT="$1"
    case $OPT in
        --32) PERSONALITY=linux32 ;;
        -c|--chroot) shift; CHROOT_NAME=$1 ;;
        -d|--dir) shift; CHROOT_DIR=$1 ;;
        --dry-run) DRY_RUN=true ;;
        -g|--group) shift; CHROOT_GROUP=$1 ;;
        -h|--help) usage 0 ;;
        -p|--profile) shift; PROFILE=$1 ;;
        -r|--release) shift; DEBIAN_RELEASE=$1 ;;
        -t|--type) shift; TYPE=$1 ;;
        -u|--user) shift; CHROOT_USER=$1 ;;
    esac
    shift
done

if [ -z "$CHROOT_NAME" ] || [ -z "$DEBIAN_RELEASE" ];then
    ERROR "The CHROOT_NAME and the DEBIAN_RELEASE must be specified."
fi

if [ -z "$CHROOT_USER" ] && [ -z "$CHROOT_GROUP" ];then
    ERROR "The CHROOT_USER or the CHROOT_GROUP must be specified."
fi

if [ -z "$CHROOT_DIR" ];then
    CHROOT_DIR="$(pwd)/$CHROOT_NAME"
    INFO "\"--dir\" not set, defaulting to $CHROOT_DIR (the current working directory + the chroot name)."
fi

if "$DRY_RUN";then
    create_schroot_config_file
    exit 0
fi

INFO "Installing the chroot to $CHROOT_DIR.  This can take \"a while\" depending on your system resources..."

# Create a config entry for the jail.
INFO "Installing schroot config to /etc/schroot/chroot.d/$CHROOT_NAME."

# Note that "plain" schroot types (the default) don't run setup scripts and mount filesystems.
create_schroot_config_file

# Create the dir where the jail is installed.
mkdir -p "$CHROOT_DIR"

# Finally, create the jail itself.
#debootstrap --no-check-gpg $DEBIAN_RELEASE /srv/chroot/$CHROOT_NAME file:///home/$CHROOT_USER/mnt
if debootstrap \
    --arch="$ARCH" \
    --variant=minbase \
    "$DEBIAN_RELEASE" "$CHROOT_DIR" http://deb.debian.org/debian
then
    # See /etc/schroot/default/copyfiles for files to be copied into the new chroot.
    SUCCESS "Chroot installed in $CHROOT_DIR!"
    INFO "You can now enter the chroot by issuing the following command:"
    # If only the \"--group\" was given and no \"--user\", use "USERNAME" as a placeholder.
    INFO "\n\tschroot -u ${CHROOT_USER:-USERNAME} -c $CHROOT_NAME -d /\n"
    INFO "Have fun! Weeeeeeeeeeeee"
else
    ERROR "Something went terribly wrong!"
    ERROR "Are you trying to overwrite an existing chroot?"
fi

