#!/bin/bash
set -e
echo "Loading Script ....."
################################################################################################################################
# Var
################################################################################################################################
lib_file_name="my_stuff_lib"
auto_run_script="false" # true to enable
# global_temp_path if changed all temp_path will be equal to this value because of next if statment  in all of other files [[ -z "${temp_path}" ]] && temp_path="/tmp/my_stuff"
global_temp_path="/tmp/my_stuff"
mirror="http://deb.debian.org/debian/"
mirror_security="http://security.debian.org/debian-security"
deb_lines_contrib=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v contrib || :)
deb_lines_nonfree_firmware=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v 'non-free-firmware' || :)
deb_lines_nonfree=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v "non-free[[:blank:]]" || :)

arg_="${1-}"
SUGROUP=""
temp_path=""
internet_status=""
my_stuff_lib_location="$(find $HOME -type f -name ${lib_file_name} | head -1 || :)"
install_GPU_Drivers="install_GPU"
_cuda_="cuda"
_kernel_open_dkms_="nvidia-kernel-open-dkms"
run_purge_some_unnecessary_pakages="Y"
run_disable_some_unnecessary_services="Y"
run_update_grub_image="Y"
autoclean_and_autoremove="Y"
install_zsh_now=""
install_xfce4_panel=xfce4_panel 
install_polybar=polybar 
install_qt5ct=qt5ct 
install_jgmenu=jgmenu 
install_bspwm=bspwm
reboot_now="Y"
enable_contrib=false
enable_nonfree_firmware=false
enable_nonfree=false
_SUDO=""

RC='\e[0m'
RED='\e[31m'
YELLOW='\e[33m'
GREEN='\e[32m'
################################################################################################################################
# Function
################################################################################################################################

test_internet_(){
	local wifi_interface=""
	
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
				if [[ "$intf_name" != "lo" ]] || [[ "$intf_name" != "w"* ]];then
    				$_SUDO ip link set dev $intf_name up
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
			if ls /sys/class/net/w* 2>/dev/null;then
				wifi_interface="$(ip link | awk -F: '$0 !~ "^[^0-9]"{print $2;getline}' | awk '/w/{ print $0 }')"
				if [ -z "$wifi_interface" ];then
  					tput sgr0
            		echo -e '\E[1;33m'"Problem seems to be with your router. $_ip"
            		tput sgr0
            		exit 1
            	else
            		wifi_mode_installation "$wifi_interface"
            	fi
            else
            	echo -e '\E[1;33m'"Problem seems to be with your router. $_ip"
            fi
        else
        	tput sgr0
            echo -e '\E[1;33m'"Problem seems to be with your interface or there is no DHCP server. $_intface ip is $_ip"
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
		if [[ -z "$arg_" ]];then
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
		fi
		
		if [[ -z "$arg_" ]] || [[ "$arg_" = "drivers" ]];then
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
		fi
		
		if [[ -z "$arg_" ]];then
			if [ "$(do_you_want_2_run_this_yes_or_no 'do you want to purge some unnecessary pakages?')" != "Y" ];then
				run_purge_some_unnecessary_pakages=""
			fi
			
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to disable some unnecessary services?')" != "Y" ];then
				run_disable_some_unnecessary_services=""
			fi
			
			if [ "$(do_you_want_2_run_this_yes_or_no 'update grub image?')" != "Y" ];then
				run_update_grub_image=""
			fi
			
			if [ "$(do_you_want_2_run_this_yes_or_no 'run autoclean and autoremove?')" != "Y" ];then
				autoclean_and_autoremove=""
			fi
		fi
		
		if [[ -z "$arg_" ]] || [[ "$arg_" = "apps" ]];then
			if ! command -v zsh >/dev/null;then
				if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install zsh?')" = "Y" ];then
					if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to set zsh as default shell?')" = "Y" ];then
						install_zsh_now=zsh_default
					else
						install_zsh_now=zsh
					fi
				fi
			else
				if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to set zsh as default shell?')" = "Y" ];then
					install_zsh_now=zsh_default
				else
					install_zsh_now=zsh
				fi
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
		fi
		
		if [[ -z "$arg_" ]];then
			if [ "$(do_you_want_2_run_this_yes_or_no 'reboot?')" != "Y" ];then
				reboot_now=""
			fi
		fi
	fi
}

fix_time_(){
	echo "runing fix_time_ function"
	get_date_from_here=""
	list_to_test=(debian.com github.com 104.16.132.229)
	
	for test in "${list_to_test[@]}";do
		ping -c 1 $test &>/dev/null && get_date_from_here="$test" && break
	done
		
	if [[ -z "$get_date_from_here" ]];then 
		echo "failed to ping all of this: ${list_to_test[@]}" && exit 1
	else
		$_SUDO date -s "$(wget --method=HEAD -qSO- --max-redirect=0 $get_date_from_here 2>&1 | sed -n 's/^ *Date: *//p')" &>/dev/null
		#__timezone="$(wget -O- https://ipinfo.io/ 2>/dev/null | grep timezone | awk -F: '{print $2}' | sed 's/"//g;s/,//g;s/ //g')"
		__timezone="Asia/Kuwait"
		$_SUDO timedatectl set-timezone $__timezone	
	fi
}

wifi_mode_installation(){
	local wifi_interface="${1-}"
	
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
		while :
		do
			echo -e "\n These hotspots are available \n"
			$_SUDO iwlist "$wifi_interface" scan | grep ESSID | sed 's/ESSID://g;s/"//g;s/^                    //g'
			read -p -r "ssid:" ssid_var
			if iw "$wifi_interface" scan | grep 'SSID' | grep "$ssid_var" >/dev/null;then
				read -p -r "pass:" pass_var
			fi
		done
		wpa_passphrase "$ssid_var" "$pass_var" | tee "$tmpfile"
		$_SUDO wpa_supplicant -B -c "$tmpfile" -i "$wifi_interface" &
		unset ssid_var
		unset pass_var
		echo "you will wait for few sec"
		sleep 10 
		$_SUDO dhclient "$wifi_interface"
		ping -c4 google.com || (echo "no internet connection" ; exit 1)
		[ -f "$tmpfile" ] && rm "$tmpfile"
		test_internet_
	fi
}

switch_to_network_manager(){
	network_manager_name="network-manager"
	$__install ${network_manager_name}
cat << 'EOF' > "${temp_path}"/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).
	
source /etc/network/interfaces.d/*
	
# The loopback network interface
auto lo
iface lo inet loopback
EOF
	chmod 644 "${temp_path}"/interfaces
	sudo chown root:root "${temp_path}"/interfaces
	sudo mv /etc/network/interfaces /etc/network/interfaces.old
	sudo mv "${temp_path}"/interfaces /etc/network/interfaces
	sudo sed -i 's/managed=.*/managed=true/g' /etc/NetworkManager/NetworkManager.conf
	install_extra_Network_tools=(rfkill)
	add_packages_2_install_list "${install_extra_Network_tools[@]}"
	install_packages
}

purge_some_unnecessary_pakages(){
# fonts-linuxlibertine break polybar 
# fonts-linuxlibertine installed from libreoffice
	if [ "$run_purge_some_unnecessary_pakages" = "Y" ];then
		declare -a to_be_purged=( aisleriot anthy kasumi aspell debian-reference-common fcitx fcitx-bin fcitx-frontend-gtk2 fcitx-frontend-gtk3 fcitx-mozc five-or-more four-in-a-row gnome-chess gnome-klotski gnome-mahjongg gnome-mines gnome-music gnome-nibbles gnome-robots gnome-sudoku gnome-taquin gnome-tetravex gnote goldendict hamster-applet hdate-applet hexchat hitori iagno khmerconverter lightsoff mate-themes malcontent mlterm mlterm-tiny mozc-utils-gui quadrapassel reportbug rhythmbox scim simple-scan sound-juicer swell-foop tali uim xboard xiterm+thai xterm im-config xfce4-notifyd xfce4-power-manager* )
		
		show_m "adding fonts-linuxlibertine to purging list (fonts-linuxlibertine break polybar) "
		to_be_purged+=("linuxlibertine")
		show_m "purging apps"
		apt_purge_with_error2info "${to_be_purged[@]}"
	fi
}

disable_some_unnecessary_services(){
	if [ "$run_disable_some_unnecessary_services" = "Y" ];then
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
}
clean_up_now(){
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
	if [ "$autoclean_and_autoremove" = "Y" ];then
		show_m "autoremove unwanted pakages"
		sudo apt-get autoremove -y
		sudo apt-get autoclean -y
	fi
}

update_grub_image(){
	if [ "$run_update_grub_image" = "Y" ];then
		show_m "update grub"
		sudo ln -sf /usr/share/"${Custom_distro_dir_name}"/images/wallpapers/default/Networks.png /boot/grub/
		# this package added some grub config
		sudo sync
		sudo update-grub
	fi
	# install Themes
	sudo gtk-update-icon-cache
}

install_lightdm_now(){
	install_lightdm_=(lightdm lightdm-gtk-greeter-settings)
	if [ -f "/etc/X11/default-display-manager" ]; then
		d_d_m="$(basename "$(cat /etc/X11/default-display-manager)")"
		[ "$d_d_m" != "lightdm"  ] && lightdm_does_not_exist=true
	else
		lightdm_does_not_exist=true
	fi
	
	if [ "$lightdm_does_not_exist" = true  ];then
		($__noninteractive_install ${install_lightdm_[@]} && kill_PACKAGE_MANAGER) || ($__noninteractive_install ${install_lightdm_[@]} && kill_PACKAGE_MANAGER) || $__noninteractive_install ${install_lightdm_[@]}
		echo "/usr/sbin/lightdm" | $_SUDO tee /etc/X11/default-display-manager
		$_SUDO $__noninteractive dpkg-reconfigure lightdm
	fi
}

check_if_user_has_root_access(){
	echo "check if user has root access."
    ## Check SuperUser Group
    SUPERUSERGROUP='wheel sudo root'
    for sug in ${SUPERUSERGROUP}; do
        if groups | grep ${sug} >/dev/null; then
            SUGROUP=${sug}
            echo -e "Super user group ${SUGROUP}"
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep ${SUGROUP} >/dev/null; then
        echo -e "\e[31m You need to be a member of the sudo group to run me!"
        exit 1
    fi
    
    if command -v sudo >/dev/null;then
    	_SUDO="sudo"
		sudo -v
	fi
}

source_my_lib_file(){
	export temp_path="${global_temp_path}"
	# source my_stuff_lib
	if [[ ! -z "${my_stuff_lib_location}" ]];then
		mv "${my_stuff_lib_location}" "${temp_path}"
	elif [[ ! -f "${temp_path}/${lib_file_name}" ]];then 
		echo "wget lib file"
		if ! wget -q https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/${lib_file_name} -O "${temp_path}"/${lib_file_name}; then
			echo "Error: Failed to download ${lib_file_name} ."
			exit 1
		fi
	fi
		
	set -a
	if ! source "${temp_path}"/${lib_file_name} 2> /dev/null; then
		echo "Error: Failed to source ${lib_file_name} from ${temp_path}" >&2
		exit 1
	fi
	set +a
}
################################################################################################################################
# main
################################################################################################################################

export temp_path="${global_temp_path}"

check_if_user_has_root_access

test_internet_

mkdir -p "${temp_path}"

fix_time_

source_my_lib_file

prompt_to_ask_to_what_to_install

must_install_apps

if [[ "$arg_" = "drivers" ]] || [[ -z "$arg_" ]];then
	check_and_download_ "my_stuff_Drivers"
fi

if [[ "$arg_" = "apps" ]] || [[ -z "$arg_" ]];then
	check_and_download_ "my_stuff_Installapps_list"
fi

if [[ -z "$arg_" ]];then
	check_and_download_ "my_stuff_configer"
	
	check_and_download_ "my_stuff_post_install_"
################################
# git clone
	show_m "git clone distro files"
	my_stuff_location="$(git_clone_and_set_var_to_path "my_stuff" | tail -1)"
	Theme_Stuff_location="$(git_clone_and_set_var_to_path "Theme_Stuff" | tail -1)"
################################
fi
clear

_unattended_upgrades_ stop
upgrade_now

if [[ "$arg_" = "drivers" ]] || [[ -z "$arg_" ]];then
	show_m "Install drivers from (my_stuff_Drivers)"
	"${temp_path}"/my_stuff_Drivers ${install_GPU_Drivers} ${_cuda_} ${_kernel_open_dkms_}
fi

if [[ "$arg_" = "apps" ]] || [[ -z "$arg_" ]];then
	show_m "Install apps from (my_stuff_Installapps_list)"
	"${temp_path}"/my_stuff_Installapps_list $install_xfce4_panel $install_polybar $install_qt5ct $install_jgmenu $install_bspwm $install_zsh_now
fi

install_lightdm_now

switch_to_network_manager

_unattended_upgrades_ start

if [[ ! -z "$arg_" ]];then
	show_m "Done"
	exit
fi

##################################################################################
##################################################################################
# no internet needed  part
##################################################################################
##################################################################################

show_m "Configering ${Custom_distro_name}."
"${temp_path}"/my_stuff_configer "${my_stuff_location}" "${Theme_Stuff_location}"

purge_some_unnecessary_pakages

disable_some_unnecessary_services

clean_up_now

update_grub_image

show_m "prepare some script"
sudo "${temp_path}"/my_stuff_post_install_ "${Custom_distro_dir_name}"

show_m "Done"
if [ "$reboot_now" = "Y" ];then
	sudo reboot
fi
