#!/usr/bin/env sh
set -eu

export DEBCONF_NOWARNINGS="yes"
export DEBIAN_FRONTEND="noninteractive"
export DEBCONF_NONINTERACTIVE_SEEN="true"

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
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

chmod 755 -R run
chown root:root -R run

cp -r run/src /run/
cp -r run/assets /run/assets


wget -O /var/drivers.txz https://github.com/qemus/virtiso-whql/releases/download/v1.9.45-0/virtio-win-1.9.45.tar.xz
chmod 664 /var/drivers.txz

/run/entry.sh
