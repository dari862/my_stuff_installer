#!/bin/bash
set -e

if command -v sudo >/dev/null;then
	sudo -v
fi

################################################################################################################################
# Var
################################################################################################################################
internet_status=""
temp_path="/tmp/my_stuff"
lib_file_name="my_stuff_lib"
my_stuff_lib_location="$(find $HOME -type f -name ${lib_file_name} | head -1 || :)"

auto_run_script="false" # true to enable

install_GPU_Drivers="install_GPU"
_cuda_="cuda"
_kernel_open_dkms_="nvidia-kernel-open-dkms"
purge_some_unnecessary_pakages="Y"
disable_some_unnecessary_services="Y"
update_grub_image="Y"
autoclean_and_autoremove="Y"
install_xfce4_panel=xfce4_panel 
install_polybar=polybar 
install_qt5ct=qt5ct 
install_jgmenu=jgmenu 
install_bspwm=bspwm
reboot_now="Y"
enable_contrib=false
enable_nonfree_firmware=false
enable_nonfree=false

mirror="http://deb.debian.org/debian/"
mirror_security="http://security.debian.org/debian-security"
deb_lines_contrib=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v contrib || :)
deb_lines_nonfree_firmware=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v 'non\-free\-firmware' || :)
deb_lines_nonfree=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v 'non\-free ' || :)

wifi_interface=""
################################################################################################################################
# Function
################################################################################################################################
test_internet_(){
	tput sgr0
	echo -e '\E[1;32m'"Testing internet connection."
	tput sgr0	
	
	url_to_test=debian.org
	test_dns="1.1.1.1"
	if wget -O - "$url_to_test" &> /dev/null; then
		tput sgr0
		echo -e '\E[1;32m'"Internet connection test passed!"
		tput sgr0
		return 0
	else
		echo "Internet connection test failed!"
		_intface="$(ip route | awk '/default/ { print $5 }')"
		if [ -z "$_intface" ];then
			for intf in /sys/class/net/*; do
				intf_name="$(basename $intf)"
				if [ "$intf_name" != "lo" ];then
    				sudo ip link set dev $intf_name up
    			fi
			done
			_intface="$(ip route | awk '/default/ { print $5 }')"
			if [ -z "$_intface" ];then
				tput sgr0
            	echo -e '\E[1;33m'"Problem seems to be with your interface. not connected"
            	tput sgr0
            	exit 1
            fi
		fi
		_ip="$(ip address show dev $_intface | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/')"
		if [[ ! -z "$(echo $_ip | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]]
		then
			wifi_interface="$(ip link | awk -F: '$0 !~ "^[^0-9]"{print $2;getline}' | awk '/w/{ print $0 }')"
			if [ -z "$wifi_interface" ];then
  				tput sgr0
            	echo -e '\E[1;33m'"Problem seems to be with your router. $_ip"
            	tput sgr0
            	exit 1
            else
            	return 1
            fi
        else
        	tput sgr0
            echo -e '\E[1;33m'"Problem seems to be with your interface. $_intface ip is $_ip"
            tput sgr0
            exit 1
		fi
		
		gway=$(ip route | awk '/default/ { print $3 }')
		
		if ! ping -q -c 5 "$test_dns" >/dev/null 2>&1; then
            tput sgr0
            echo -e '\E[1;33m'"Problem seems to be with your gateway. $_ip"
            tput sgr0
            exit 1
        elif ! ping -q -c 5 "$gway" >/dev/null 2>&1; then
            tput sgr0
            echo -e '\E[1;33m'"Can not reach your gateway. $_ip"
            tput sgr0
            exit 1
    	fi

    	fix_time_
    	
    	if wget -O - "$url_to_test" &> /dev/null; then
			tput sgr0
			echo -e '\E[1;32m'"Internet connection test passed!"
			tput sgr0
			return 0
		elif ping -q -c 5 "$test_dns" >/dev/null 2>&1; then
            tput sgr0
            echo -e '\E[1;33m'"Problem seems to be with your DNS. $_ip"
            tput sgr0
            exit 1
        else
        	tput sgr0
            echo -e '\E[1;33m'"Somthing wrong with your network"
            tput sgr0
            exit 1
    	fi
    fi
}

prompt_to_ask_to_what_to_install(){
	if [ "$(do_you_want_2_run_this_yes_or_no 'Autorun installation?')" = "Y" ];then
		return
	fi
	
	if [ "$auto_run_script" != "true" ];then
	
		if [ "$deb_lines_contrib" != "" ];then
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want enable contrib repo?')" = "Y" ];then
				enable_contrib=true
			fi
		fi
		if [ "$deb_lines_nonfree_firmware" != "" ];then
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want enable nonfree_firmware repo?')" = "Y" ];then
				enable_nonfree_firmware=true
			fi
		fi
		if [ "$deb_lines_nonfree" != "" ];then
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want enable nonfree repo?')" = "Y" ];then
				enable_nonfree=true
			fi
		fi
		if [ "$(do_you_want_2_run_this_yes_or_no 'do you want to install GPU drivers?')" != "Y" ];then
			install_GPU_Drivers=""
		else
			if [ "${nvidia_gpu_exist}" = "true" ];then
				if [ "$(do_you_want_2_run_this_yes_or_no 'do you want to add Cuda Support?')" != "Y" ];then
					_cuda_=""
				else
					_cuda_="cuda"
				fi
				
				if [ "$(do_you_want_2_run_this_yes_or_no 'do you want to install opensource nvidia-kernel?')" != "Y" ];then
					_kernel_open_dkms_=""
				else
					_kernel_open_dkms_="nvidia-kernel-open-dkms"
				fi
			else
				_cuda_=""
				_kernel_open_dkms_=""
			fi
		fi
		
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
		
		if ! command -v xfce4-panel >/dev/null;then
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install xfce4-panel?')" != "Y" ];then
				install_xfce4_panel=""
			fi
		fi
		
		if ! command -v polybar >/dev/null;then
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install polybar?')" != "Y" ];then
				install_polybar=""
			fi
		fi
		
		if ! command -v qt5ct >/dev/null;then
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install qt5ct?')" != "Y" ];then
				install_qt5ct=""
			fi
		fi
		
		if ! command -v jgmenu >/dev/null;then
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install jgmenu?')" != "Y" ];then
				install_jgmenu=""
			fi
		fi
		
		if ! command -v bspwm >/dev/null && ! command -v sxhkd >/dev/null;then
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install bspwm?')" != "Y" ];then
				install_bspwm=""
			fi
		fi
			
		if [ "$(do_you_want_2_run_this_yes_or_no 'reboot?')" != "Y" ];then
			reboot_now=""
		fi
	fi
}

enable_repo_(){
	if [[ "$enable_contrib" = true ]];then
		for l in $deb_lines_contrib; do
			sudo sed -i "s\\^$l$\\$l contrib\\" /etc/apt/sources.list
		done
	fi
	if [[ "$enable_nonfree_firmware" = true ]];then
		for l in $deb_lines_nonfree_firmware; do
			sudo sed -i "s\\^$l$\\$l non-free-firmware\\" /etc/apt/sources.list
		done
	fi
	if [[ "$enable_nonfree" = true ]];then
		for l in $deb_lines_nonfree; do
			sudo sed -i "s\\^$l$\\$l non-free\\" /etc/apt/sources.list
		done
	fi
	aptupdate
}

fix_time_(){
	get_date_from_here=""
	list_to_test=(debian.com github.com 104.16.132.229)
	
	for test in "${list_to_test[@]}";do
		ping -c 1 $test &>/dev/null && get_date_from_here="$test" && break
	done
		
	if [[ -z "$get_date_from_here" ]];then 
		echo "failed to ping all of this: ${list_to_test[@]}" && exit 1
	else
		$_SUDO date -s "$(wget --method=HEAD -qSO- --max-redirect=0 $get_date_from_here 2>&1 | sed -n 's/^ *Date: *//p')" &>/dev/null
		#__timezone="$(curl -q https://ipinfo.io/ 2>/dev/null | grep timezone | awk -F: '{print $2}' | sed 's/"//g;s/,//g;s/ //g')"
		__timezone="Asia/Kuwait"
		$_SUDO timedatectl set-timezone $__timezone	
	fi
}

wifi_mode_installation(){
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
		if grep 'deb cdrom' /etc/apt/sources.list;then
			$_SUDO sed -i '/deb cdrom/d' /etc/apt/sources.list
		fi
		$_SUDO apt-get update || (fix_time_ && $_SUDO apt-get update )
		$_SUDO apt-get install -y -f 2>/dev/null
		$_SUDO apt-get install -y network-manager psmisc
		killall wpa_supplicant
		nmcli dev wifi connect "$ssid_var" password "$pass_var"	
		unset ssid_var
		unset pass_var
	fi
}

################################################################################################################################
################################################################################################################################
################################################################################################################################
test_internet_ || wifi_mode_installation
mkdir -p "${temp_path}"

# source my_stuff_lib
if [[ ! -z "${my_stuff_lib_location}" ]];then
	mv "${my_stuff_lib_location}" "${temp_path}"
	if ! source "${temp_path}"/${lib_file_name} 2> /dev/null; then
		echo "Error: Failed to source ${lib_file_name} from ${temp_path} but ${lib_file_name} exist in ${temp_path}" >&2
		exit 1
	fi
else
	echo "wget lib file"
	if wget -q https://raw.githubusercontent.com/dari862/my_stuff_installer/main/tempfornow/${lib_file_name} -O "${temp_path}"/${lib_file_name}; then
		if ! source "${temp_path}"/${lib_file_name} 2> /dev/null; then
			echo "Error: Failed to source ${lib_file_name} from ${temp_path}" >&2
			exit 1
		fi
	else
		echo "Error: Failed to download ${lib_file_name} ."
		exit 1
	fi
fi

prompt_to_ask_to_what_to_install

fix_time_

aptfixer

check_for_SUDO

keep_Sudo_refresed &

enable_repo_

must_install_apps

check_and_download_ "my_stuff_Installapps_list"

check_and_download_ "my_stuff_post_install_"

check_and_download_ "my_stuff_Drivers"

################################
# git clone

show_m "git clone distro files"
my_stuff_location="$(git_clone_and_set_var_to_path "my_stuff" | tail -1)"
Theme_Stuff_location="$(git_clone_and_set_var_to_path "Theme_Stuff" | tail -1)"

################################

clear

_unattended_upgrades_ stop
upgrade_now
full_upgrade_now

show_m "Install drivers from (my_stuff_Drivers)"
"${temp_path}"/my_stuff_Drivers ${install_GPU_Drivers} ${_cuda_} ${_kernel_open_dkms_}

show_m "Install apps from (my_stuff_Installapps_list)"
"${temp_path}"/my_stuff_Installapps_list $install_xfce4_panel $install_polybar $install_qt5ct $install_jgmenu $install_bspwm

################################
# no internet needed  part
################################
cd "${my_stuff_location}"

[ ! -d "${Custom_distro_dir_name}" ] && mv my_stuff "${Custom_distro_dir_name}"

[ -d "/usr/share/${Custom_distro_dir_name}" ] && sudo rm -rdf "/usr/share/${Custom_distro_dir_name}"

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

if [ ! -f "${Custom_distro_dir_name}/lib/xsessions/${Custom_distro_dir_name}_openbox.desktop" ];then
	mv "${Custom_distro_dir_name}"/lib/xsessions/*_openbox.desktop "${Custom_distro_dir_name}"/lib/xsessions/"${Custom_distro_dir_name}"_openbox.desktop
fi

if [ ! -f "${Custom_distro_dir_name}/lib/xsessions/${Custom_distro_dir_name}_bspwm.desktop" ];then
	mv "${Custom_distro_dir_name}"/lib/xsessions/*_bspwm.desktop "${Custom_distro_dir_name}"/lib/xsessions/"${Custom_distro_dir_name}"_bspwm.desktop
fi

if [ ! -f "${Custom_distro_dir_name}/lib/lightdm/lightdm.conf.d/50_${Custom_distro_dir_name}.conf" ];then
	mv "${Custom_distro_dir_name}"/lib/lightdm/lightdm.conf.d/50_*.conf "${Custom_distro_dir_name}"/lib/lightdm/lightdm.conf.d/50_"${Custom_distro_dir_name}".conf
fi

if [ ! -f "${Custom_distro_dir_name}/lib/lightdm/lightdm-gtk-greeter.conf.d/50_${Custom_distro_dir_name}.conf" ];then
	mv "${Custom_distro_dir_name}"/lib/lightdm/lightdm-gtk-greeter.conf.d/50_*.conf "${Custom_distro_dir_name}"/lib/lightdm/lightdm-gtk-greeter.conf.d/50_"${Custom_distro_dir_name}".conf
fi

if [ ! -f "${Custom_distro_dir_name}/lib/openbox_rc/${Custom_distro_dir_name}_rc.xml" ];then
	mv "${Custom_distro_dir_name}"/lib/openbox_rc/*_rc.xml "${Custom_distro_dir_name}"/lib/openbox_rc/"${Custom_distro_dir_name}"_rc.xml
fi

if [ ! -f "${Custom_distro_dir_name}/skel/.config/conky/scripts/${Custom_distro_dir_name}_weather.sh" ];then
	mv "${Custom_distro_dir_name}"/skel/.config/conky/scripts/DmDmDmdMdMdM_weather.sh "${Custom_distro_dir_name}"/skel/.config/conky/scripts/"${Custom_distro_dir_name}"_weather.sh
fi

if [ ! -f "${Custom_distro_dir_name}/bin/openbox/pipemenu/${Custom_distro_dir_name}-kb-pipemenu" ];then
	mv "${Custom_distro_dir_name}"/bin/openbox/pipemenu/DmDmDmdMdMdM-kb-pipemenu "${Custom_distro_dir_name}"/bin/openbox/pipemenu/"${Custom_distro_dir_name}"-kb-pipemenu
fi

mkdir -p "${Custom_distro_dir_name}"/bin/not_add_2_path/updater

if [[ "$(CHECK_IF_THIS_LAPTOP)"  = true ]];then 
	show_m "this is laptop"
	touch "${Custom_distro_dir_name}"/this_is_laptop
fi

if [[ -f "${temp_path}/envycontrol_updater_DmDmDmdMdMdM" ]];then
	mv "${temp_path}"/envycontrol_updater_DmDmDmdMdMdM "${Custom_distro_dir_name}"/bin/not_add_2_path/updater/envycontrol_updater
fi
 	
if [[ -f "$(ls ${temp_path}/GPU_Drivers_ready* 2>/dev/null)" ]];then 
	touch "${Custom_distro_dir_name}"/GPU_Drivers_ready
fi

find "${Custom_distro_dir_name}"/. -type f -exec sed -i "s/DmDmDmdMdMdM/${Custom_distro_dir_name}/g" {} +
find "${Custom_distro_dir_name}"/. -type f -exec sed -i "s/mDmDmDmDmDmDmD/${Custom_distro_name}/g" {} +

source "${Custom_distro_dir_name}/lib/common/openbox_folder_name"

if [[ ! -d "${Custom_distro_dir_name}/skel/.config/${OB_folder_name}" ]];then
	mv "${Custom_distro_dir_name}/skel/.config/openbox" "${Custom_distro_dir_name}/skel/.config/${OB_folder_name}"
	find "${Custom_distro_dir_name}"/. -type f -exec sed -i "s|.config/openbox|.config/${OB_folder_name}|g" {} +
fi

##################################################################################
#my_stuff.git

#run_fixes_
show_m "change ownership to root"
sudo chown -R root:root "${Custom_distro_dir_name}"

show_m "moving usr_share"
sudo mv "${Custom_distro_dir_name}" /usr/share/
sudo ln -sf /usr/share/"${Custom_distro_dir_name}"/lib/xsessions/*_openbox.desktop /usr/share/xsessions

for f in /usr/share/"${Custom_distro_dir_name}"/applications/* ; do
	sudo ln -sf "$f" /usr/share/applications
done

sudo mkdir -p "/usr/share/lightdm/lightdm.conf.d"
sudo mkdir -p "/usr/share/lightdm/lightdm-gtk-greeter.conf.d"
sudo ln -sf /usr/share/"${Custom_distro_dir_name}"/lib/lightdm/lightdm.conf.d/50_"${Custom_distro_dir_name}".conf /usr/share/lightdm/lightdm.conf.d
sudo ln -sf /usr/share/"${Custom_distro_dir_name}"/lib/lightdm/lightdm-gtk-greeter.conf.d/50_"${Custom_distro_dir_name}".conf /usr/share/lightdm/lightdm-gtk-greeter.conf.d

show_m "update alternatives apps"
sudo /usr/share/"${Custom_distro_dir_name}"/bin/bin/my-alternatives install
show_m "installing update-notification"
sudo /usr/share/"${Custom_distro_dir_name}"/bin/bin/update-notification -I
if [[ -f "/usr/share/${Custom_distro_dir_name}/bin/not_add_2_path/updater/envycontrol_updater" ]];then 
	show_m "runing envycontrol_updater"
	sudo /usr/share/"${Custom_distro_dir_name}"/bin/not_add_2_path/updater/envycontrol_updater
fi

if [[ -f "$(ls ${temp_path}/fingerprint_exist_XXXXXX* 2>/dev/null)" ]];then 
    ln -sf /usr/share/${Custom_distro_dir_name}/bin/not_add_2_path/fingerprint_gui /usr/share/${Custom_distro_dir_name}/bin/apps
fi
##################################################################################
#Theme_Stuff.git
show_m "chown of Theme_Stuff to root"
sudo chown -R root:root "${Theme_Stuff_location}"/Theme_Stuff

show_m "moving Theme_Stuff to /usr/share/${Custom_distro_dir_name}/Theme_Stuff"
sudo mv "${Theme_Stuff_location}"/Theme_Stuff /usr/share/"${Custom_distro_dir_name}"

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
	sudo systemctl --user mask tracker-store.service tracker-miner-fs.service tracker-miner-rss.service tracker-extract.service tracker-miner-apps.service tracker-writeback.service || show_m "fail to disable tracker services"
	#systemctl --user mask gvfs-udisks2-volume-monitor.service gvfs-metadata.service gvfs-daemon.service || show_m "fail to disable gvfs.service"
	
	if sudo systemctl status NetworkManager.service &>/dev/null; then
		#apt-get purge ifupdown; rm -rf /etc/network/*
		sudo systemctl networking disable || show_m "fail to disable networking"
	
		#apt-get purge network-dispacher
		sudo systemctl stop systemd-networkd.service || show_m "fail to stop systemd-networkd.service"
		sudo systemctl disable systemd-networkd.service || show_m "fail to disable systemd-networkd.service"
	fi
fi

show_m "clean_up_now"
show_m "removing not needed dotfiles"

mkdir -p "${temp_path}"/clean_up_now_trash_folder

move_this_Array=($(ls /usr/share/"${Custom_distro_dir_name}"/skel/.config/))

for movethis in "${move_this_Array[@]}"; do
	[ -e "${HOME}/.config/${movethis}" ] && mv "${HOME}/.config/${movethis}" "${temp_path}"/clean_up_now_trash_folder  &> /dev/null;
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

show_m "prepare some script"
sudo "${temp_path}"/my_stuff_post_install_ "${Custom_distro_dir_name}"

show_m "Done"

if [ "$reboot_now" = "Y" ];then
	sudo reboot
fi
