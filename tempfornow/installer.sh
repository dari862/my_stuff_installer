#!/bin/bash
set -e
auto_run_script="true" # true to enable

sudo -v || echo "sudo does not exist."

if [ "$1" == "wifi" ]; then
	wifi_interface="$(ip link | awk -F: '$0 !~ "^[^0-9]"{print $2;getline}' | awk '/w/{ print $0 }')"
	if [ -z "$wifi_interface" ]
	then
		echo "no wifi interface"
		exit 1
	fi
	
	ip link set "$wifi_interface" up
	
	if command -v nmcli &> /dev/null
	then
		nmcli radio wifi on
		while :
		do
			nmcli --ask dev wifi connect && break
		done
	elif command -v wpa_supplicant &> /dev/null
	then
		tmpfile="$(mktemp)"
		echo -e "\n These hotspots are available \n"
		iwlist "$wifi_interface" scan | grep ESSID | sed 's/ESSID://g;s/"//g;s/^                    //g'
		read -p -r "ssid:" ssid_var
		(iw "$wifi_interface" scan | grep 'SSID' | grep "$ssid_var") || (echo "wrong ssid")
		read -p -r "pass:" pass_var 
		wpa_passphrase "$ssid_var" "$pass_var" | tee "$tmpfile"
		wpa_supplicant -B -c "$tmpfile" -i "$wifi_interface" &
		echo "you will wait for few sec"
		sleep 10 
		dhclient "$wifi_interface"
		ping -c4 google.com || (echo "no internet connection" ; exit 1)
		[ -f "$tmpfile" ] && rm "$tmpfile"
		sudo apt-get update
		sudo apt-get install -y network-manager
		killall wpa_supplicant
		nmcli dev wifi connect "$ssid_var" password "$pass_var"	
		unset ssid_var
		unset pass_var
	fi
fi

# source lib
script_fullpath=$(dirname "$(readlink -f "$0")")
[ "$(echo "${script_fullpath}" | grep "/proc/*")" ] && script_fullpath="/tmp"
cd "${script_fullpath}"
if ! . lib 2>/dev/null; then
	wget -q https://raw.githubusercontent.com/dari862/my_stuff_installer/main/tempfornow/lib
	if ! . lib 2>/dev/null; then
		echo "Error: Failed to locate lib from ${script_fullpath}" >&2
		exit 1
	fi
fi

check_for_SUDO

keep_Sudo_refresed &

purge_some_unnecessary_pakages="Y"
disable_some_unnecessary_services="Y"
update_grub_image="Y"
autoclean_and_autoremove="Y"
reboot_now="Y"

if [ "$auto_run_script" != "true" ];then
	if [ "$(do_you_want_2_run_this_yes_or_no 'do you want to purge some unnecessary pakages?')" != "Y" ];then
	purge_some_unnecessary_pakages=""
	fi
	
	if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to disable some unnecessary services?')" != "Y" ];then
	disable_some_unnecessary_services=""
	fi
	
	if [ "$(do_you_want_2_run_this_yes_or_no 'update grub image?')" != "Y" ];then
	update_grub_image=""
	fi
	
	if [ "$(do_you_want_2_run_this_yes_or_no 'run autoclean and autoremove?')" != "Y" ];then
	autoclean_and_autoremove=""
	fi
	
	if [ "$(do_you_want_2_run_this_yes_or_no 'reboot?')" != "Y" ];then
	reboot_now=""
	fi
fi

check_and_run_else_download_and_run "Installapps_list"

check_and_run_else_download_and_run "prepare_script_"

clear

_unattended_upgrades_ stop

### Fix broken packages for good measure (why not?)
$sudoaptinstall -f 2>/dev/null || show_em "failed to $sudoaptinstall -f"

show_m "running Installapps_list script"
./Installapps_list

show_m "git clone distro files"
git_clone_Array=(
my_stuff
Theme_Stuff
)
for getthis in "${git_clone_Array[@]}"; do
	show_m "git clone ${getthis}"
	if [ ! -d "${tmp_folder}/${getthis}" ]; then 
		git clone --depth=1 "https://github.com/dari862/${getthis}.git" "${tmp_folder}/${getthis}"
	else
		show_m "${getthis} Folder does exsist"
	fi
done

cd "${tmp_folder}"
[ ! -d "${Custom_distro_dir_name}" ] && mv my_stuff "${Custom_distro_dir_name}"

# test if in virtual machine
if [ "$(hostnamectl | grep "Chassis:" | grep -o "vm")" == "vm" ]
then
	# disable vsync from picom (vsync in virtual machine make issues)
	show_m "picom vm"
	sed -i 's|# vsync = false|vsync = false;|g' "${Custom_distro_dir_name}"/skel/.config/picom.conf
	sed -i 's|# vsync = false|vsync = false;|g' "${Custom_distro_dir_name}"/skel/.config/picom.conf.bunsenlab
	sed -i 's|vsync = true;|# vsync = true|g' "${Custom_distro_dir_name}"/skel/.config/picom.conf
	sed -i 's|vsync = true;|# vsync = true|g' "${Custom_distro_dir_name}"/skel/.config/picom.conf.bunsenlab
fi

mv "${Custom_distro_dir_name}"/lib/xsessions/*_openbox.desktop "${Custom_distro_dir_name}"/lib/xsessions/"${Custom_distro_dir_name}"_openbox.desktop
mv "${Custom_distro_dir_name}"/lib/xsessions/*_bspwm.desktop "${Custom_distro_dir_name}"/lib/xsessions/"${Custom_distro_dir_name}"_bspwm.desktop
mv "${Custom_distro_dir_name}"/lib/lightdm/lightdm.conf.d/50_*.conf "${Custom_distro_dir_name}"/lib/lightdm/lightdm.conf.d/50_"${Custom_distro_dir_name}".conf
mv "${Custom_distro_dir_name}"/lib/lightdm/lightdm-gtk-greeter.conf.d/50_*.conf "${Custom_distro_dir_name}"/lib/lightdm/lightdm-gtk-greeter.conf.d/50_"${Custom_distro_dir_name}".conf
mv "${Custom_distro_dir_name}"/lib/openbox_rc/*_rc.xml "${Custom_distro_dir_name}"/lib/openbox_rc/"${Custom_distro_dir_name}"_rc.xml
mv "${Custom_distro_dir_name}"/skel/.config/conky/scripts/DmDmDmdMdMdM_weather.sh "${Custom_distro_dir_name}"/skel/.config/conky/scripts/"${Custom_distro_dir_name}"_weather.sh

mkdir -p "${Custom_distro_dir_name}"/bin/not_add_2_path/updater

if [[ "$(CHECK_IF_THIS_LAPTOP)"  = true ]];then 
	show_m "this is laptop"
	touch "${Custom_distro_dir_name}"/this_is_laptop
	mv /tmp/envycontrol_updater_DmDmDmdMdMdM "${Custom_distro_dir_name}"/bin/not_add_2_path/updater/envycontrol_updater
fi

find "${Custom_distro_dir_name}"/. -type f -exec sed -i "s/DmDmDmdMdMdM/${Custom_distro_dir_name}/g" {} +
find "${Custom_distro_dir_name}"/. -type f -exec sed -i "s/mDmDmDmDmDmDmD/${Custom_distro_name}/g" {} +

##################################################################################
#my_linux.git

#run_fixes_
show_m "change ownership to root"
sudo chown -R root:root "${Custom_distro_dir_name}"

show_m "moving usr_share"
sudo mv "${Custom_distro_dir_name}" /usr/share/
sudo ln -sf /usr/share/"${Custom_distro_dir_name}"/lib/xsessions/*_openbox.desktop /usr/share/xsessions

for f in /usr/share/"${Custom_distro_dir_name}"/applications/* ; do
	sudo ln -sf "$f" /usr/share/applications
done

mkdir -p "/usr/share/lightdm/lightdm.conf.d"
mkdir -p "/usr/share/lightdm/lightdm-gtk-greeter.conf.d"
sudo ln -sf /usr/share/"${Custom_distro_dir_name}"/lib/lightdm/lightdm.conf.d/50_"${Custom_distro_dir_name}".conf /usr/share/lightdm/lightdm.conf.d
sudo ln -sf /usr/share/"${Custom_distro_dir_name}"/lib/lightdm/lightdm-gtk-greeter.conf.d/50_"${Custom_distro_dir_name}".conf /usr/share/lightdm/lightdm-gtk-greeter.conf.d

show_m "update alternatives apps"
sudo /usr/share/"${Custom_distro_dir_name}"/bin/bin/my-alternatives install
show_m "installing update-notification"
sudo /usr/share/"${Custom_distro_dir_name}"/bin/bin/update-notification -I
if [ -f /usr/share/"${Custom_distro_dir_name}"/this_is_laptop ]; then 
	show_m "runing envycontrol_updater"
	sudo /usr/share/"${Custom_distro_dir_name}"/bin/not_add_2_path/updater/envycontrol_updater
fi
##################################################################################
#Theme_Stuff.git
show_m "chown of Theme_Stuff to root"
sudo chown -R root:root "${tmp_folder}"/Theme_Stuff

show_m "moving Theme_Stuff to /usr/share/${Custom_distro_dir_name}/Theme_Stuff"
sudo mv "${tmp_folder}"/Theme_Stuff /usr/share/"${Custom_distro_dir_name}"

show_m "Moving themes from /usr/share/themes that exist in Theme_Stuff /usr/share/${Custom_distro_dir_name}/backup"
sudo mkdir -p /usr/share/themes
sudo mkdir -p /usr/share/"${Custom_distro_dir_name}"/backup/themes
for d in /usr/share/"${Custom_distro_dir_name}"/Theme_Stuff/themes/* ; do
	Directory_name=${d##*/}
	[ -d "/usr/share/themes/${Directory_name}" ] && sudo mv "/usr/share/themes/${Directory_name}" /usr/share/"${Custom_distro_dir_name}"/backup/themes
	sudo ln -sf "$d" /usr/share/themes
done

show_m "Moving icons from /usr/share/icons that exist in Theme_Stuff /usr/share/${Custom_distro_dir_name}/backup"
sudo mkdir -p /usr/share/icons
sudo mkdir -p /usr/share/"${Custom_distro_dir_name}"/backup/icons
for d in /usr/share/"${Custom_distro_dir_name}"/Theme_Stuff/icons/* ; do
	Directory_name=${d##*/}
	[ -d "/usr/share/icons/${Directory_name}" ] && sudo mv "/usr/share/icons/${Directory_name}" /usr/share/"${Custom_distro_dir_name}"/backup/icons
	sudo ln -sf "$d" /usr/share/icons
done

show_m "Moving fonts from /usr/share/fonts that exist in Theme_Stuff /usr/share/${Custom_distro_dir_name}/backup"
sudo mkdir -p /usr/share/fonts
sudo mkdir -p /usr/share/"${Custom_distro_dir_name}"/backup/fonts
for e in /usr/share/"${Custom_distro_dir_name}"/Theme_Stuff/fonts/* ; do
	Directory_name=${e##*/}
	[ -d "/usr/share/fonts/${Directory_name}" ] && sudo mv "/usr/share/fonts/${Directory_name}" /usr/share/"${Custom_distro_dir_name}"/backup/fonts
	sudo ln -sf "$e" /usr/share/fonts
done

show_m "update fonts cache"
sudo fc-cache -vf
show_m "update icons cache"
sudo gtk-update-icon-cache

##################################################################################
# fonts-linuxlibertine break polybar 
# fonts-linuxlibertine installed from libreoffice
if [ "$purge_some_unnecessary_pakages" = "Y" ];then
	show_m "adding fonts-linuxlibertine to purging list (fonts-linuxlibertine break polybar) "
	to_be_purged+=("linuxlibertine")
	show_m "purging apps"
	apt_purge_with_error2info "${to_be_purged[@]}"
fi
##################################################################################

if [ "$disable_some_unnecessary_services" = "Y" ];then
	show_m "Disable some unnecessary services"
	
	# INFO: Some boot services included in Debian are unnecesary for most usres (like NetworkManager-wait-online.service, ModemManager.service or pppd-dns.service)
	
	sudo systemctl stop NetworkManager-wait-online.service || show_m "fail to stop NetworkManager-wait-online.service"
	sudo systemctl mask NetworkManager-wait-online.service || show_m "fail to mask NetworkManager-wait-online.service"
	
	sudo systemctl stop wpa_supplicant || show_m "fail to stop wpa_supplicant"
	sudo systemctl disable wpa_supplicant || show_m "fail to disable wpa_supplicant"	# No mask, may be needed by network manager
	
	sudo systemctl stop ModemManager.service || show_m "fail to stop ModemManager.service"
	sudo systemctl disable ModemManager.service || show_m "fail to disable ModemManager.service"
	
	sudo systemctl stop pppd-dns.service || show_m "fail to stop pppd-dns.service"
	sudo systemctl disable pppd-dns.service || show_m "fail to disable pppd-dns.service"
	
	# Disable tracker (Data indexing for GNOME mostly)
	systemctl --user mask tracker-store.service tracker-miner-fs.service tracker-miner-rss.service tracker-extract.service tracker-miner-apps.service tracker-writeback.service || show_m "fail to disable tracker services"
	#systemctl --user mask gvfs-udisks2-volume-monitor.service gvfs-metadata.service gvfs-daemon.service || show_m "fail to disable gvfs.service"
	
	if systemctl status NetworkManager.service &>/dev/null; then
		#apt-get purge ifupdown; rm -rf /etc/network/*
		sudo systemctl networking disable || show_m "fail to disable networking"
	
		#apt-get purge network-dispacher
		sudo systemctl stop systemd-networkd.service || show_m "fail to stop systemd-networkd.service"
		sudo systemctl disable systemd-networkd.service || show_m "fail to disable systemd-networkd.service"
	fi
fi

show_m "clean_up_now"
show_m "removing not needed dotfiles"

mkdir -p /tmp/clean_up_now_trash_folder

move_this_Array=($(ls /usr/share/"${Custom_distro_dir_name}"/skel/.config/))

for movethis in "${move_this_Array[@]}"; do
	[ -e "${HOME}/.config/${movethis}" ] && mv "${HOME}/.config/${movethis}" /tmp/clean_up_now_trash_folder  &> /dev/null;
done

remove_this_Array=(
.xsession-error*
)
for removethis in "${remove_this_Array[@]}"; do
	[ -f "${HOME}/${removethis}" ] && rm -f "${HOME}/${removethis}" &> /dev/null;
done

if [ "$update_grub_image" = "Y" ];then
	show_m "update grub"
	sudo ln -sf /usr/share/"${Custom_distro_dir_name}"/images/wallpapers/default/Networks.png /boot/grub/
	# this package added some grub config
	sudo sync
	sudo update-grub
fi
# install Themes
sudo gtk-update-icon-cache

if [ "$autoclean_and_autoremove" = "Y" ];then
	show_m "autoremove unwanted pakages"
	sudo apt-get autoremove -y
	sudo apt-get autoclean -y
fi
_unattended_upgrades_ start

##################################################################################
# fix
##################################################################################
# terminator
############
if [ -d "/etc/xdg" ];then
	[ ! -d "/etc/xdg/terminator" ] && sudo mkdir -p "/etc/xdg/terminator"
	[ ! -f "/etc/xdg/terminator/config" ] && sudo cp -r /usr/share/"${Custom_distro_dir_name}"/skel/.config/terminator /etc/xdg/terminator
fi

############
# Remove "Set as wallpaper" from Thunar Context Menu and replace it with  "Set as wallpaper" from thunar config uac file
############
__thunar_wall_plug="$(locate thunar | grep wall)"
sudo mv "${__thunar_wall_plug}" "${__thunar_wall_plug}.backup"

##################################################################################

sudo sed -i 's/managed=.*/managed=true/g' /etc/NetworkManager/NetworkManager.conf

show_m "prepare some script"
sudo "${script_fullpath}"/prepare_script_ "${Custom_distro_dir_name}"

show_m "Done"

if [ "$reboot_now" = "Y" ];then
	sudo reboot
fi
