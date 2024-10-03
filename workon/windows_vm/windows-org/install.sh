#!/bin/sh
set -eu

RAM_SIZE="4G"
CPU_CORES="2"
DISK_SIZE="64G"
VERSION="win11"

export DEBCONF_NOWARNINGS="yes"
export DEBIAN_FRONTEND="noninteractive"
export DEBCONF_NONINTERACTIVE_SEEN="true"

if [ ! -f "/drivers.tar.xz" ] || [ ! -f "/run/entry.sh" ];then
	sudo apt-get update
	
	sudo apt-get --no-install-recommends -y install \
        	bc \
        	curl \
        	7zip \
        	wsdd \
        	samba \
        	xz-utils \
        	wimtools \
        	dos2unix \
        	cabextract \
        	genisoimage \
        	libxml2-utils
        	
	sudo apt-get --no-install-recommends -y install \
        	ovmf \
        	swtpm \
        	procps \
        	dnsmasq \
        	qemu-utils \
        	genisoimage \
        	ca-certificates \
        	netcat-openbsd \
        	qemu-system
        	
	sudo apt-get clean
	sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
	
	sudo mkdir -p "/storage"
	mkdir -p /tmp/windows_installer
	
	wget https://github.com/qemus/virtiso/releases/download/v0.1.262/virtio-win-0.1.262.tar.xz -P /tmp/windows_installer
	cp -r run/ /tmp/windows_installer
	mv -f /tmp/windows_installer/virtio-win-* /tmp/windows_installer/drivers.tar.xz
	chmod 664 /tmp/windows_installer/drivers.tar.xz
	chmod 755 -R /tmp/windows_installer/run/
	sudo chown root:root -R /tmp/windows_installer
	sudo mv -f /tmp/windows_installer/run/* /run
	sudo mv -f /tmp/windows_installer/drivers.tar.xz /
fi
sudo bash /run/entry.sh "${RAM_SIZE}" "${CPU_CORES}" "${DISK_SIZE}" "${VERSION}"
