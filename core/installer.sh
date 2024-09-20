#!/bin/bash
set -e
echo "Loading Script ....."
################################################################################################################################
# Var
################################################################################################################################
lib_file_name="disto_lib"
auto_run_script="false" # true to enable
temp_path="/tmp/my_stuff"
grub_image_name="Networks.png"

mirror=""
mirror_security=""
deb_lines_contrib=""
deb_lines_nonfree_firmware=""
deb_lines_nonfree=""

export temp_path="${temp_path}"
prompt_to_install_value_file="${temp_path}/value_of_picked_option_from_prompt_to_install"
arg_="${1-}"
SUGROUP=""
internet_status=""
disto_lib_location=""
install_GPU_Drivers="install_GPU"
_cuda_="cuda"
_kernel_open_dkms_="nvidia-kernel-open-dkms"
run_purge_some_unnecessary_pakages="Y"
run_disable_some_unnecessary_services="Y"
disable_ipv6_stack="Y"
disable_ipv6="Y"
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
_SUPERUSER=""
__USER="$USER"

RC='\e[0m'
RED='\e[31m'
YELLOW='\e[33m'
GREEN='\e[32m'

doas_installed=false
switch_to_doas=false

sudo_installed=false

PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:$PATH

remove_aria2=false

switch_default_xsession_to="openbox"

################################################################################################################################
# Function
################################################################################################################################

show_m()
{
  echo -e $'\033[1;32m'"$*"$'\033[0m'
}

show_em()
{
	__massage="${1-}"
	echo "$__massage"
}

test_internet_(){
	local wifi_interface=""
	
	tput sgr0
	echo -e '\E[1;32m'"Testing internet connection."
	tput sgr0	
	
	url_to_test=debian.org
	test_dns="1.1.1.1"
	if curl -s "$url_to_test" &> /dev/null; then
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
    				$_SUPERUSER ip link set dev $intf_name up
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
    	
    	if curl -s "$url_to_test" &> /dev/null; then
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

do_you_want_2_run_this_yes_or_no(){
	massage_is_="${1}"
	yn=""
	read -r -p "${massage_is_} (yes/no) (default: yes)" yn
	yn="$(echo "$yn" | tr '[:upper:]' '[:lower:]')"
	[ "$yn" = "YES" ] && yn="Y"
	[ "$yn" = "" ] && yn="Y"
	echo "$yn"
}

prompt_to_ask_to_what_to_install(){
	mirror="http://deb.debian.org/debian/"
	mirror_security="http://security.debian.org/debian-security"
	deb_lines_contrib=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v contrib || :)
	deb_lines_nonfree_firmware=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v 'non-free-firmware' || :)
	deb_lines_nonfree=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v "non-free[[:blank:]]" || :)
	
	if [ -f "${prompt_to_install_value_file}" ];then
		show_m "file exist : ${prompt_to_install_value_file} form previce run."
		if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want source it?')" = "Y" ];then
			source "${prompt_to_install_value_file}"
			return
		fi
	
	fi
	
	number_of_gpus=0

	if [ "$(lspci | grep -i VMware | grep VGA -c)" != "0" ];then
		VMware_gpu_exist=true
		number_of_gpus=$((number_of_gpus++))
	else
		if [ "$(lspci | grep -i nvidia | grep VGA -c)" != "0" ];then
			nvidia_gpu_exist=true
			number_of_gpus=$((number_of_gpus++))
		fi
		
		if [ "$(lspci | grep -i intel | grep VGA -c)" != "0" ];then
			intel_gpu_exist=true
			number_of_gpus=$((number_of_gpus++))
		fi
		
		if [ "$(lspci | grep -i amd | grep VGA -c)" != "0" ];then
			amd_gpu_exist=true
			number_of_gpus=$((number_of_gpus++))
		fi
	fi
	
	if [ "$(do_you_want_2_run_this_yes_or_no 'Autorun installation?')" = "Y" ];then
		tee "${prompt_to_install_value_file}" <<- EOF >/dev/null 
			number_of_gpus="${number_of_gpus}"
			VMware_gpu_exist="${VMware_gpu_exist}"
			nvidia_gpu_exist="${nvidia_gpu_exist}"
			intel_gpu_exist="${intel_gpu_exist}"
			amd_gpu_exist="${amd_gpu_exist}"		
		EOF
		return
	fi
	
	if [ "$doas_installed" = false ] && [ "$sudo_installed" = true ];then
		if [ "$(do_you_want_2_run_this_yes_or_no 'Switch to doas?')" = "Y" ];then
			switch_to_doas=true
		fi
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
			
			if [ "$(do_you_want_2_run_this_yes_or_no 'disable ipv6 stack?')" != "Y" ];then
				if [ "$(do_you_want_2_run_this_yes_or_no 'disable ipv6 only?')" != "Y" ];then
					disable_ipv6="Y"
				fi
				if [ "$(do_you_want_2_run_this_yes_or_no 'update grub image?')" != "Y" ];then
					run_update_grub_image=""
				fi
				disable_ipv6_stack=""
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
					if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to switch to bspwm session?')" = "Y" ];then
						switch_default_xsession_to="bspwm"
					fi
				fi
			fi
		fi
		
		if [[ -z "$arg_" ]];then
			if [ "$(do_you_want_2_run_this_yes_or_no 'reboot?')" != "Y" ];then
				reboot_now=""
			fi
		fi
	fi
	tee "${prompt_to_install_value_file}" <<- EOF >/dev/null 
		deb_lines_contrib="${deb_lines_contrib}"
		deb_lines_nonfree_firmware="${deb_lines_nonfree_firmware}"
		deb_lines_nonfree="${deb_lines_nonfree}"
		number_of_gpus="${number_of_gpus}"
		VMware_gpu_exist="${VMware_gpu_exist}"
		nvidia_gpu_exist="${nvidia_gpu_exist}"
		intel_gpu_exist="${intel_gpu_exist}"
		amd_gpu_exist="${amd_gpu_exist}"
		switch_to_doas="${switch_to_doas}"
		enable_contrib="${enable_contrib}"
		enable_nonfree_firmware="${enable_nonfree_firmware}"
		enable_nonfree="${enable_nonfree}"
		install_GPU_Drivers="${install_GPU_Drivers}"
		_cuda_="${_cuda_}"
		_kernel_open_dkms_="${_kernel_open_dkms_}"
		run_purge_some_unnecessary_pakages="${run_purge_some_unnecessary_pakages}"
		run_disable_some_unnecessary_services="${run_disable_some_unnecessary_services}"
		disable_ipv6="${disable_ipv6}"
		run_update_grub_image="${run_update_grub_image}"
		disable_ipv6_stack="${disable_ipv6_stack}"
		autoclean_and_autoremove="${autoclean_and_autoremove}"
		install_zsh_now="${install_zsh_now}"
		install_xfce4_panel="${install_xfce4_panel}"
		install_polybar="${install_polybar}"
		install_qt5ct="${install_qt5ct}"
		install_jgmenu="${install_jgmenu}"
		install_bspwm="${install_bspwm}"
		switch_default_xsession_to="${switch_default_xsession_to}"
		reboot_now="${reboot_now}"		
	EOF
}

fix_time_(){
	echo "runing fix_time_ function"
	get_date_from_here=""
	list_to_test=(debian.com ipinfo.io 104.16.132.229)
	
	for test in "${list_to_test[@]}";do
		ping -c 1 $test &>/dev/null && get_date_from_here="$test" && break
	done
		
	if [[ -z "$get_date_from_here" ]];then 
		echo "failed to ping all of this: ${list_to_test[@]}" && exit 1
	else
		$_SUPERUSER date -s "$(curl --head -sL --max-redirs 0 $get_date_from_here 2>&1 | sed -n 's/^ *Date: *//p')" &>/dev/null
		#__timezone="$(curl -s https://ipinfo.io/ 2>/dev/null | grep timezone | awk -F: '{print $2}' | sed 's/"//g;s/,//g;s/ //g')"
		__timezone="Asia/Kuwait"
		if command -v timedatectl >/dev/null 2>&1;then
			$_SUPERUSER timedatectl set-timezone $__timezone
		else
			$_SUPERUSER ln -sf /usr/share/zoneinfo/$__timezone /etc/localtime
			$_SUPERUSER hwclock --systohc
		fi
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
			$_SUPERUSER iwlist "$wifi_interface" scan | grep ESSID | sed 's/ESSID://g;s/"//g;s/^                    //g'
			read -p -r "ssid:" ssid_var
			if iw "$wifi_interface" scan | grep 'SSID' | grep "$ssid_var" >/dev/null;then
				read -p -r "pass:" pass_var
			fi
		done
		wpa_passphrase "$ssid_var" "$pass_var" | tee "$tmpfile" > /dev/null 2>&1
		$_SUPERUSER wpa_supplicant -B -c "$tmpfile" -i "$wifi_interface" &
		unset ssid_var
		unset pass_var
		echo "you will wait for few sec"
		sleep 10 
		$_SUPERUSER dhclient "$wifi_interface"
		ping -c4 google.com || (echo "no internet connection" ; exit 1)
		[ -f "$tmpfile" ] && rm "$tmpfile"
		test_internet_
	fi
}

switch_to_network_manager(){
	network_manager_name="network-manager"
	add_packages_2_install_list "${network_manager_name}"
	install_packages
	my-superuser tee "${temp_path}"/interfaces <<- 'EOF' > /dev/null
	# This file describes the network interfaces available on your system
	# and how to activate them. For more information, see interfaces(5).
		
	source /etc/network/interfaces.d/*
		
	# The loopback network interface
	auto lo
	iface lo inet loopback
	EOF
	my-superuser chmod 644 "${temp_path}"/interfaces
	my-superuser mv /etc/network/interfaces /etc/network/interfaces.old
	my-superuser mv "${temp_path}"/interfaces /etc/network/interfaces
	my-superuser sed -i 's/managed=.*/managed=true/g' /etc/NetworkManager/NetworkManager.conf
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
		to_be_purged+=("${install_autoinstall_firmware[@]}")
		show_m "purging apps"
		remove_package_with_error2info "${to_be_purged[@]}"
	fi
}

disable_some_unnecessary_services(){
	if [ "$run_disable_some_unnecessary_services" = "Y" ];then
		show_m "Disable some unnecessary services"
		
		# INFO: Some boot services included in Debian are unnecesary for most usres (like NetworkManager-wait-online.service, ModemManager.service or pppd-dns.service)
		for service in NetworkManager-wait-online.service wpa_supplicant ModemManager.service pppd-dns.service;do
			init_manager stop $service || show_m "fail to stop $service"
			init_manager mask $service || show_m "fail to mask $service"
		done

		# Disable tracker (Data indexing for GNOME mostly)
		for service in tracker-store.service tracker-miner-fs.service tracker-miner-rss.service tracker-extract.service tracker-miner-apps.service tracker-writeback.service;do
			init_manager mask $service  || show_m "fail to disable $service"
		done
		#init_manager mask gvfs-udisks2-volume-monitor.service || show_m "fail to disable gvfs.service"
		#init_manager mask gvfs-daemon.service || show_m "fail to disable gvfs.service"
		#init_manager mask gvfs-metadata.service || show_m "fail to disable gvfs.service"
		
		if init_manager status NetworkManager.service &>/dev/null; then
			init_manager disable networking || show_m "fail to disable networking"
			init_manager stop systemd-networkd.service || show_m "fail to stop systemd-networkd.service"
			init_manager disable systemd-networkd.service || show_m "fail to disable systemd-networkd.service"
		fi
	fi
}

clean_up_now(){
	show_m "clean_up_now"
	
	remove_unnecessary_package_manager_stuff
	
	show_m "removing not needed dotfiles"
	
	mkdir -p "${temp_path}"/clean_up_now_trash_folder
	
	move_this_Array=($(ls /usr/share/"my_stuff"/skel/.config/))
	
	for movethis in "${move_this_Array[@]}"; do
		[ -e "${HOME}/.config/${movethis}" ] && mv "${HOME}/.config/${movethis}" "${temp_path}"/clean_up_now_trash_folder  &> /dev/null;
	done
	
	remove_this_Array=(
	.xsession-error*
	)
	for removethis in "${remove_this_Array[@]}"; do
		[ -f "${HOME}/${removethis}" ] && rm -f "${HOME}/${removethis}" &> /dev/null;
	done
	
	[ "$autoclean_and_autoremove" = "Y" ] && run_package_manager_autoclean
}

disable_ipv6_now(){
	if [ "$disable_ipv6_stack" = "Y" ];then
		show_m "disabling IPv6 stack (kernal level)."
		if ! grep 'GRUB_CMDLINE_LINUX=' /etc/default/grub | grep -q 'ipv6.disable=1';then
			if grep -q 'GRUB_CMDLINE_LINUX=""' /etc/default/grub;then
				my-superuser sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="ipv6.disable=1"/' /etc/default/grub
			else
				my-superuser sed -i 's/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 ipv6.disable=1\"/' /etc/default/grub
			fi
		fi
		if ! grep 'GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | grep -q 'ipv6.disable=1';then
			if grep -q 'GRUB_CMDLINE_LINUX_DEFAULT=""' /etc/default/grub;then
				my-superuser sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1"/' /etc/default/grub
			else
				my-superuser sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ipv6.disable=1\"/' /etc/default/grub
			fi
		fi
	fi
	
	if [ "$disable_ipv6" = "Y" ];then
		disable_ipv6_conf="/etc/sysctl.d/90-disable_ipv6.conf"
		show_m "Disabling IPv6."
		echo "net.ipv6.conf.all.disable_ipv6 = 1" | my-superuser tee "${disable_ipv6_conf}" >/dev/null 2>&1
		echo "net.ipv6.conf.default.disable_ipv6 = 1" | my-superuser tee -a "${disable_ipv6_conf}" >/dev/null 2>&1
		echo "net.ipv6.conf.lo.disable_ipv6 = 1" | my-superuser tee -a "${disable_ipv6_conf}" >/dev/null 2>&1
		
		my-superuser sysctl -p "${disable_ipv6_conf}"
	fi
}

update_grub_image(){
	if [ "$run_update_grub_image" = "Y" ];then
		show_m "update grub"
		my-superuser ln -sf /usr/share/my_stuff/images/wallpapers/default/${grub_image_name} /boot/grub/
		# this package added some grub config
		my-superuser sync
		my-superuser grub-mkconfig -o /boot/grub/grub.cfg
	fi
	# install Themes
	my-superuser gtk-update-icon-cache
}

check_if_user_has_root_access(){
	if [[ "$EUID" -ne 0 ]];then
		echo "check if user has root access."
    	## Check SuperUser Group
    	SUPERUSERGROUP='wheel sudo root'
    	for sug in ${SUPERUSERGROUP}; do
        	if groups | grep ${sug} >/dev/null; then
            	SUGROUP=${sug}
            	echo -e "Super user group are ${SUGROUP}"
        	fi
    	done
	
    	## Check if member of the SuperUser Group.
    	if ! groups | grep ${SUGROUP} >/dev/null; then
        	echo -e "\e[31m You need to be a member of the SuperUser Group to run me!"
        	exit 1
    	fi
    	
    	if command -v doas >/dev/null;then
    		_SUPERUSER="doas"
    		doas_installed=true
		fi
		if command -v sudo >/dev/null;then
    		_SUPERUSER="sudo"
    		sudo_installed=true
		fi
		
		$_SUPERUSER true
    else
    	if command -v doas >/dev/null;then
    		doas_installed=true
		fi
		
		if command -v sudo >/dev/null;then
    		sudo_installed=true
		fi
		
		_SUPERUSER=""
    fi
}

source_my_lib_file(){
	disto_lib_location="$(find $HOME -type f -name ${lib_file_name} | head -1 || :)"
	# source disto_lib
	if [[ ! -z "${disto_lib_location}" ]];then
		mv "${disto_lib_location}" "${temp_path}"
	elif [[ ! -f "${temp_path}/${lib_file_name}" ]];then 
		echo "download lib file"
		if ! curl -s https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/${lib_file_name} -o "${temp_path}"/${lib_file_name}; then
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

must_create_temp_dir(){
	mkdir -p "${temp_path}"
}

purge_sudo(){
	if ! command -v sudo >/dev/null;then
		export SUDO_FORCE_REMOVE=yes
		PASSWORD=$(tr -dc 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' < /dev/urandom | head -c 30 | base64)	
		echo "root:${PASSWORD}" | $_SUPERUSER chpasswd
		remove_package_with_error2info "sudo" 
		$_SUPERUSER passwd -l root
		PASSWORD=""
	fi
}

install_doas(){
	if ! command -v doas >/dev/null;then
		if ! cat /etc/group | grep sudo;then
			$_SUPERUSER groupadd sudo
		fi
		show_m "Installing doas and add user 1000 to sudo group"
		add_packages_2_install_list "doas"
		kill_package_ ${PACKAGER} && install_packages || (kill_package_ ${PACKAGER}  && install_packages) || (show_em "failed to install sudo" && exit 1)
		$_SUPERUSER tee /etc/doas.conf <<- EOF >/dev/null 
		permit nopass $USER as root			
		EOF
		_SUPERUSER="doas"
		$_SUPERUSER adduser "$USER" sudo || :
		$_SUPERUSER tee -a /etc/bash.bashrc <<- EOF >/dev/null 

		if [ -x /usr/bin/doas ]; then
			complete -F _command doas
		fi
		EOF
		purge_sudo
	fi
}

install_superuser_tools()
{
	if [ "$switch_to_doas" = true ];then
		install_doas
	else
		if command -v doas >/dev/null;then
    		_SUPERUSER="doas"
		elif command -v sudo >/dev/null;then
			_SUPERUSER="sudo"
			keep_superuser_refresed(){
				while true
				do
						sudo true
						sleep 10m
				done
			}
			keep_superuser_refresed &
    	else
    		install_doas
    		_SUPERUSER=""
		fi
	fi
	
	$_SUPERUSER ln -sf /usr/bin/$_SUPERUSER /usr/bin/my-superuser
}

set_package_manager(){
	## Check Package Handeler
	PACKAGEMANAGER='apt-get yum dnf pacman zypper'
	for pgm in ${PACKAGEMANAGER}; do
		if command -v ${pgm} >/dev/null; then
			PACKAGER=${pgm}
			echo -e "Using ${pgm}"
			break
		fi
	done
	
	if [ -z "${PACKAGER}" ]; then
		echo -e "${RED}Can't find a supported package manager"
		exit 1
	fi
	
	check_and_download_ "disto_package_manager_${pgm}"

	if ! source "${temp_path}/disto_package_manager_${pgm}" 2> /dev/null; then
		echo "Error: Failed to source disto_package_manager_${pgm} from ${temp_path}" >&2
		exit 1
	fi

	kill_package_ ${PACKAGER} 	
}

switch_default_xsession(){
	my-superuser update-alternatives --install /usr/bin/x-session-manager x-session-manager /usr/share/my_stuff/system_files/bin/xsessions/${switch_default_xsession_to} 60
}

################################################################################################################################
################################################################################################################################
################################################################################################################################
# main
################################################################################################################################
################################################################################################################################
################################################################################################################################

check_if_user_has_root_access

must_create_temp_dir

prompt_to_ask_to_what_to_install

test_internet_

fix_time_

source_my_lib_file

CHECK_IF_THIS_LAPTOP

set_package_manager

install_superuser_tools

must_install_apps

if [[ "$arg_" = "drivers" ]] || [[ -z "$arg_" ]];then
	check_and_download_ "disto_Drivers"
fi

if [[ "$arg_" = "apps" ]] || [[ -z "$arg_" ]];then
	check_and_download_ "disto_Installapps_list"
fi

if [[ -z "$arg_" ]];then
	check_and_download_ "disto_configer"
	
	check_and_download_ "disto_post_install"
################################
# repo clone
	show_m "clone distro files repo."
	my_stuff_location="$(clone_and_set_var_to_path "my_stuff" | tail -1)"
	Theme_Stuff_location="$(clone_and_set_var_to_path "Theme_Stuff" | tail -1)"
################################
fi
clear

if [ "$init_system_are" = "systemd" ];then
	_unattended_upgrades_ stop
fi

if [[ "$arg_" = "drivers" ]] || [[ -z "$arg_" ]];then
	show_m "Install drivers from (disto_Drivers)"
	source "${temp_path}"/disto_Drivers
fi

if [[ "$arg_" = "apps" ]] || [[ -z "$arg_" ]];then
	show_m "Install apps from (disto_Installapps_list)"
	source "${temp_path}"/disto_Installapps_list
fi

install_lightdm_now

switch_to_network_manager

if [ "$init_system_are" = "systemd" ];then
	_unattended_upgrades_ start
fi

if [[ ! -z "$arg_" ]];then
	show_m "Done"
	exit
fi

##################################################################################
##################################################################################
# no internet needed  part
##################################################################################
##################################################################################

show_m "Configering My Stuff."
source "${temp_path}"/disto_configer

purge_some_unnecessary_pakages

if [ "$init_system_are" = "systemd" ];then
	disable_some_unnecessary_services
fi

clean_up_now

disable_ipv6_now

update_grub_image

show_m "update alternatives apps"
/usr/share/my_stuff/bin/bin/my-alternatives --install

show_m "prepare some script"
cd "${temp_path}"
my-superuser "${temp_path}"/disto_post_install "${PACKAGER}"

show_m "switching default xsession to my stuff $switch_default_xsession_to."
switch_default_xsession

show_m "Done"
if [ "$reboot_now" = "Y" ];then
	/usr/share/my_stuff/system_files/bin/my_session_manager reboot
fi
