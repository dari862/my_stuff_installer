#!/usr/bin/env sh
set -eu

export DEBCONF_NOWARNINGS="yes"
export DEBIAN_FRONTEND="noninteractive"
export DEBCONF_NONINTERACTIVE_SEEN="true"

mkdir -p /storage

apt-get update
apt-get --no-install-recommends -y install \
        wsdd \
        samba \
        wimtools \
        dos2unix \
        cabextract \
        libxml2-utils \
        libarchive-tools \
        netcat-openbsd
apt-get install -y novnc python3-websockify tigervnc-standalone-server tigervnc-common
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

chmod 755 -R run
chown root:root -R run

cp -r run/* /run/

wget -O /var/drivers.txz https://github.com/qemus/virtiso-whql/releases/download/v1.9.45-0/virtio-win-1.9.45.tar.xz
chmod 664 /var/drivers.txz

setsid bash /run/entry.sh
