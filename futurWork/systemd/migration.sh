#!/bin/sh
migration_stage2_file_name="migration-stage2.sh"
script_path="$PWD"

NETWORK=0
_FIRMWARENONFREE=""

. /etc/os-release

MIGRATION_TMP=$(mktemp -d /tmp/MIGRATION-XXXXXXXX)
cd "$MIGRATION_TMP" || exit 1

# REMOVE SOME SYSTEMD RELATED PACKAGES THAT GET IN THE WAY
# Don't remove fonts-quicksand ,breaks desktop-base
REMOVE_LIST="\
dbus-user-session \
libnss-systemd \
libpam-systemd \
plymouth-label \
plymouth \
udev \
libudev1"

# ORDER MATTERS!
DEVUAN_LIST="
libeudev1 \
util-linux \
libelogind0 \
elogind \
libpam-elogind \
eudev \
insserv \
startpar \
sysv-rc \
initscripts \
sysvinit-core \
init"
DEVUAN_LIST="$DEVUAN_LIST dbus dbus-x11 libdbus-1-3"

# Prepare for next Debian release and detect version
if test "$VERSION_ID" = "10" ; then
	DEVUAN_CODENAME="beowulf"
	DEVUAN_KEYRING="devuan-keyring_2022.09.04_all.deb"
	REMOVE_LIST="$REMOVE_LIST libplymouth4 iio-sensor-proxy"
	DEVUAN_LIST="$DEVUAN_LIST debian-pulseaudio-config-override"
elif test "$VERSION_ID" = "11" ; then
	DEVUAN_CODENAME="chimaera"
	DEVUAN_KEYRING="devuan-keyring_2022.09.04_all.deb"
	REMOVE_LIST="$REMOVE_LIST libplymouth5 systemd-timesyncd"
elif test "$VERSION_ID" = "12" ; then
	DEVUAN_CODENAME="daedalus"
	DEVUAN_KEYRING="devuan-keyring_2023.05.28_all.deb"
	REMOVE_LIST="$REMOVE_LIST libplymouth5 systemd-timesyncd"
	DEVUAN_LIST="$DEVUAN_LIST dbus-session-bus-common \
				dbus-bin \
				dbus-system-bus-common \
				dbus-daemon \
				libelogind-compat orphan-sysvinit-scripts chrony"
	_FIRMWARENONFREE=" non-free-firmware"
else
	echo "Unsupported Debian Version: $VERSION"
	echo "Exiting..."
	exit 1
fi

DOWNLOAD_LIST="network-manager libnm0 network-manager-gnome"
grep -q " contrib" /etc/apt/sources.list && _CONTRIB=" contrib"
grep -q " non-free " /etc/apt/sources.list && _NONFREE=" non-free"

echo "Detected: Debian $VERSION"

# SET PATH
export PATH="/bin:/usr/bin:/sbin:/usr/sbin"

# CHECK FOR ROOT
ID=$(id -u)
if test "$ID" -ne 0 ; then
	echo "You need root permissions to run this script. Exiting..."
	exit 1
fi

# TEST NETWORK AS MIGRATION WILL FAIL IF NOT ONLINE
NETWORK=$(printf "GET /nm HTTP/1.1\\r\\nHost: network-test.debian.org\\r\\n\\r\\n" | nc -w1 network-test.debian.org 80 | grep -c "NetworkManager is online")
if test "$NETWORK" -ne 1 ; then
	echo "Your network seems to be down. "
	echo "Cannot connect to the Internet. Exiting..."
	exit 1
fi

if [ ! -f "/etc/apt/sources.list.d/devuan.list" ];then
	# ADD DEVUAN REPOS
	tee /etc/apt/sources.list.d/devuan.list <<- EOF > /dev/null
	deb http://deb.devuan.org/merged $DEVUAN_CODENAME main$_CONTRIB$_NONFREE$_FIRMWARENONFREE
	deb http://deb.devuan.org/merged $DEVUAN_CODENAME-updates main$_CONTRIB$_NONFREE$_FIRMWARENONFREE
	deb http://deb.devuan.org/merged $DEVUAN_CODENAME-security main$_CONTRIB$_NONFREE$_FIRMWARENONFREE
	EOF
	
	# PIN PREFERENCE FOR DEVUAN PACKGES
	tee /etc/apt/preferences.d/"$DEVUAN_CODENAME" <<- EOF > /dev/null
	Package: *
	Pin: origin "deb.devuan.org"
	Pin-Priority: 900
	EOF
fi

echo "Setting date and time"
get_date_from_here=""
list_to_test="debian.com ipinfo.io 104.16.132.229"
	
for test in ${list_to_test};do
	ping -c 1 "$test" > /dev/null 2>&1 && get_date_from_here="$test" && break
done
		
if [ -z "$get_date_from_here" ];then 
	echo "failed to ping all of this: ${list_to_test}" && exit 1
else
	date -s "$(curl --head -sL --max-redirs 0 "$get_date_from_here" 2>&1 | sed -n 's/^ *Date: *//p')" > /dev/null 2>&1
	__timezone="$(curl -s https://ipinfo.io/ 2>/dev/null | grep timezone | awk -F: '{print $2}' | sed 's/"//g;s/,//g;s/ //g')"
	ln -sf /usr/share/zoneinfo/"$__timezone" /etc/localtime
	hwclock --systohc
fi
# Allow time change to propagate
sleep 5

# STOP THE TIMERS FOR apt-get TO AVOID INTERFERENCES (FILE LOCKS)
systemctl stop apt-daily.timer
systemctl stop apt-daily-upgrade.timer

if ! ls /etc/apt/trusted.gpg.d/devuan* > /dev/null 2>&1;then
	# DOWNLOAD DEVUAN KEYRING AND IMPLICIT TEST FOR NETWORK
	echo "Downloading Devuan Keyring: $DEVUAN_KEYRING"
	
	if ! wget http://deb.devuan.org/devuan/pool/main/d/devuan-keyring/"$DEVUAN_KEYRING"  > /dev/null 2>&1 ; then
		if ! curl -O -s http://deb.devuan.org/devuan/pool/main/d/devuan-keyring/"$DEVUAN_KEYRING" > /dev/null 2>&1 ; then
			echo "Could not download Devuan Keyring: $DEVUAN_KEYRING"
			echo "Exiting..."
			exit 1
		fi
	fi
	
	# INSTALL DEVUAN KEYRING
	echo "Installing $DEVUAN_KEYRING"
	dpkg -i "$DEVUAN_KEYRING" > /dev/null 2>&1
fi

# UPDATE
echo "Updating repositories"
apt-get update

for DEB in $DEVUAN_LIST
do
	apt-get download "$DEB" > /dev/null 2>&1
	if test $? -ne 0 ; then
		echo "Downloading $DEB...failed, exiting..."
		exit 1
	fi
	echo "Downloading $DEB...done"
done
if dpkg -L task-xfce-desktop > /dev/null 2>&1 ; then
	echo "Detected XFCE DE"
	# INSTALL DEVUAN PACKAGES TO INIT MIGRATION
	apt-get install task-xfce-desktop --no-install-recommends -y
fi

apt-get install -y $DOWNLOAD_LIST

for DEB in $REMOVE_LIST
do
	echo "Removing $DEB"
	dpkg --purge --force-all "$DEB" > /dev/null 2>&1
done

# DETECT LIBSYSTEMD AND SAVE A COPY TO KEEP apt-get and SYSTEMCTL HAPPY
LIBSYSTEMD=$(dpkg -L libsystemd0 | grep ".so.0.")
echo "Saving a copy of '$LIBSYSTEMD'" 
cp "$LIBSYSTEMD" "$LIBSYSTEMD".bak


# BEGIN TO REMOVE SYSTEMD
echo "Removing systemd-sysv"
dpkg --purge --force-all systemd-sysv > /dev/null 2>&1
# Don't remove it here we need it to reboot the box
#dpkg --purge --force-all systemd
#if test "$VERSION_ID" != "12" ; then
	echo "Removing libsystemd0"
	dpkg --purge --force-all libsystemd0 > /dev/null 2>&1
#fi
if test ! -f "$LIBSYSTEMD" ; then
# RESTORE LIBSYSTEMD
	echo "Restore a temporary copy of '$LIBSYSTEMD'"
	echo "to keep apt-get and systemctl working"
	cp "$LIBSYSTEMD".bak "$LIBSYSTEMD"
fi

# FORCE INSTALL DEVUAN PACKAGES TO BE SURE
for DEBNAME in $DEVUAN_LIST
do
	echo "Installing $DEBNAME"
	dpkg -i --force-all ./"$DEBNAME"*.deb > /dev/null 2>&1
done

# CHECK FOR INITTAB AND INSTALL IF MISSING
if test -f /etc/inittab ; then
	echo "Checking for existence of /etc/inittab: found"
else
	echo "Checking for existence of /etc/inittab: not found"
	echo "Copying /usr/share/sysvinit/inittab to /etc/inittab"
	cp /usr/share/sysvinit/inittab /etc/inittab
fi

# INSTRUCTIONS FOR STAGE 2
INFOTMP=$(mktemp Info-XXXXXXXX.txt)
{ echo "********************************************************************************"; \
echo "*  and run the stage 2 script in a root shell:                                 *" ; \
echo "$script_path/${migration_stage2_file_name}" ; \
echo "********************************************************************************" ; } | tee "$script_path/$INFOTMP"
echo "You can find these instructions in the file: $script_path/$INFOTMP"

tee "$script_path"/"${migration_stage2_file_name}" <<- EOF > /dev/null
#!/bin/sh
# CHECK FOR ROOT
ID=\$(id -u)
if test "\$ID" -ne 0 ; then
	echo "You need root permissions to run this script. Exiting..."
	exit 1
fi
echo "Setting PATH=/bin:/usr/bin:/sbin:/usr/sbin"
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
EOF

if dpkg-query -W systemd-coredump > /dev/null 2>&1 ; then
	echo "dpkg --purge --force-all systemd-coredump" >> "$script_path"/"${migration_stage2_file_name}"
fi

echo "dpkg --purge --force-all systemd" >> "$script_path"/"${migration_stage2_file_name}"

if dpkg-query -W libsystemd-shared > /dev/null 2>&1 ; then
	echo "dpkg --purge --force-all libsystemd-shared" >> "$script_path"/"${migration_stage2_file_name}"
fi

tee -a "$script_path"/"${migration_stage2_file_name}" <<- EOF > /dev/null
apt-get install -f -y
# elogind reinstalled for PARANOIA
apt-get install --reinstall elogind -y
echo "Setting date and time."	
date -s "$(curl --head -sL --max-redirs 0 "$get_date_from_here" 2>&1 | sed -n 's/^ *Date: *//p')" > /dev/null 2>&1
ln -sf /usr/share/zoneinfo/"$__timezone" /etc/localtime
hwclock --systohc
sleep 5
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
echo "Removing saved copy of $LIBSYSTEMD.bak"
rm -f ${LIBSYSTEMD}.bak
# test if libsystemd0 was sucked in again by some installed
# package otherwise remove it
dpkg -S $LIBSYSTEMD > /dev/null 2>&1
if test \$? -eq 1 ; then
	echo "Removing temporary copy of $LIBSYSTEMD"
	#rm -f $LIBSYSTEMD
fi

# Don't run apt-get autoremove --purge or we risk deleting some conf files
# from packages we erroneously removed
apt-get autoremove -y
# At this stage journalctl doesn't work anymore
# make sure we can get the logs if needed
# if it is already installed apt-get will tell us
apt-get install rsyslog -y
apt-get install bootlogd -y
# Needed to update the grub boot screen
update-grub
echo "Hit Enter to reboot"
read -r DUMMY
echo \$DUMMY
reboot
EOF

chmod 766 "$script_path/${migration_stage2_file_name}"
# Same ownership as current running script
chown --reference="$script_path/$0" "$script_path/${migration_stage2_file_name}"
chmod 666 "$script_path/$INFOTMP"

# CLEANUP
rm -f /etc/apt/preferences.d/"$DEVUAN_CODENAME"
rm -f /etc/apt/sources.list.d/devuan.list


tee /etc/apt/sources.list <<- EOF > /dev/null

deb http://deb.devuan.org/merged $DEVUAN_CODENAME main$_CONTRIB$_NONFREE$_FIRMWARENONFREE
deb http://deb.devuan.org/merged $DEVUAN_CODENAME-updates main$_CONTRIB$_NONFREE$_FIRMWARENONFREE
deb http://deb.devuan.org/merged $DEVUAN_CODENAME-security main$_CONTRIB$_NONFREE$_FIRMWARENONFREE
EOF

# DONE
echo "You can reboot now"
echo "Hit Enter to reboot"
read -r DUMMY
echo "$DUMMY"
reboot
