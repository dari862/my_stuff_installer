#!/bin/bash
set -e
################################################################################################################################
# Var
################################################################################################################################
lib_file_name="disto_lib"
auto_run_script="false" # true to enable
temp_path="/tmp/my_stuff"
installer_phases="/tmp/my_stuff/installer_phases"
grub_image_name="Networks.png"
switch_default_xsession_to="openbox"
switch_to_doas=false
url_to_test=debian.org
test_dns="1.1.1.1"
NETWORK_TEST="network-test.debian.org"

mirror=""
mirror_security=""
deb_lines_contrib=""
deb_lines_nonfree_firmware=""
deb_lines_nonfree=""

export temp_path="${temp_path}"
prompt_to_install_value_file="${temp_path}/value_of_picked_option_from_prompt_to_install"
save_value_file="${temp_path}/save_value_file"
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
install_extra_now=""
install_qt5ct="" 
install_jgmenu="" 
install_xfce4_panel=xfce4_panel 
install_polybar=polybar 
install_bspwm=bspwm
reboot_now="Y"
enable_contrib=false
enable_nonfree_firmware=false
enable_nonfree=false
_SUPERUSER=""
__USER="$USER"
source_prompt_to_install_file=""

RC='\e[0m'
RED='\e[31m'
YELLOW='\e[33m'
GREEN='\e[32m'

getthis_location=""
my_stuff_temp_path=""
theme_temp_path=""

doas_installed=false
sudo_installed=false

PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:$PATH

var_for_distro_uninstaller="/usr/share/my_stuff/system_files/var_for_distro_uninstaller"

################################################################################################################################
# Function
################################################################################################################################

show_m(){
	message="${1-}"
	printf '%b' "\n==[ \\033[1;32m${message}\\033[0m ]==\n"
}

show_wm(){
	message="${1-}"
	printf '%b' "\\033[1;33m[!]\\033[0m${message}\n"
}

show_em(){
	message="${1-}"
	printf '%b' "\\033[1;31m[-]${message}\\033[0m\n"
	exit 1 # show_em
}

show_im(){
	message="${1-}"
	printf '%b' "\\033[1;34m[*]\\033[0m${message}\n"
}
test_internet_(){
	show_m "Testing internet connection."	
	NETWORK=$(printf "GET /nm HTTP/1.1\\r\\nHost: network-test.debian.org\\r\\n\\r\\n" | nc -w1 $NETWORK_TEST 80 | grep -c "NetworkManager is online")
	if test "$NETWORK" -ne 1 ; then
		local wifi_interface=""
		if check_url "$url_to_test"; then
			show_im "Internet connection test passed!"
			return 0
		else
			show_wm "Internet connection test failed!"
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
            		show_em "Problem seems to be with your interface. not connected"
            	fi
			fi
			_ip="$(ip address show dev $_intface | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/')"
			if [[ ! -z "$(echo $_ip | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]]
			then
				if ls /sys/class/net/w* 2>/dev/null;then
					wifi_interface="$(ip link | awk -F: '$0 !~ "^[^0-9]"{print $2;getline}' | awk '/w/{ print $0 }')"
					if [ -z "$wifi_interface" ];then
            			show_em "Problem seems to be with your router. $_ip"
            		else
            			wifi_mode_installation "$wifi_interface"
            		fi
            	else
            		show_wm "Problem seems to be with your router. $_ip"
            	fi
        	else
            	show_em "Problem seems to be with your interface or there is no DHCP server. $_intface ip is $_ip"
			fi
			
			gway=$(ip route | awk '/default/ { print $3 }')
			
			if ! ping -q -c 5 "$test_dns" >/dev/null 2>&1; then
            	show_em "Problem seems to be with your gateway. $_ip"
        	elif ! ping -q -c 5 "$gway" >/dev/null 2>&1; then
            	show_em "Can not reach your gateway. $_ip"s
    		fi
	
    		fix_time_
    		
    		if check_url "$url_to_test"; then
				show_im "Internet connection test passed!"
				return 0
			elif ping -q -c 5 "$test_dns" >/dev/null 2>&1; then
            	show_em "Problem seems to be with your DNS. $_ip"
        	else
            	show_em "Somthing wrong with your network"
    		fi
    	fi  
	fi
}

do_you_want_2_run_this_yes_or_no(){
	massage_is_="${1}"
	yn=""
	read -r -p "${massage_is_} (yes/no) (default: yes)" yn
	yn="$(echo "$yn" | cut -c 1 | tr '[:lower:]' '[:upper:]')"
	[ "$yn" = "" ] && yn="Y"
	echo "$yn"
}

prompt_to_ask_to_what_to_install(){
	mirror="http://deb.debian.org/debian/"
	mirror_security="http://security.debian.org/debian-security"
	deb_lines_contrib=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v contrib || :)
	deb_lines_nonfree_firmware=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v 'non-free-firmware' || :)
	deb_lines_nonfree=$(egrep "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v "non-free[[:blank:]]" || :)
	
	if [ "${source_prompt_to_install_file}" = "true" ];then
		return
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
	
	show_m "prompt for what do you want to install."
	
	if [ "$auto_run_script" != "true" ];then
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
			
		if [ "$switch_to_doas" = false ];then
			if [ "$(do_you_want_2_run_this_yes_or_no 'Switch to doas?')" = "Y" ];then
				switch_to_doas=true
			fi
		fi
		
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
				if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install qt5ct?')" = "Y" ];then
					install_qt5ct=qt5ct
				fi
			fi
			
			if ! command -v jgmenu >/dev/null;then
				if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install jgmenu?')" = "Y" ];then
					install_jgmenu=jgmenu
				fi
			fi
			
			if ! command -v bspwm >/dev/null && ! command -v sxhkd >/dev/null;then
				if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install bspwm?')" = "Y" ];then
					install_bspwm=bspwm
					if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to switch to bspwm session?')" = "Y" ];then
						switch_default_xsession_to="bspwm"
					fi
				else
					install_bspwm=""
				fi
			fi
			if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want to install extra apps?')" = "Y" ];then
				install_extra_now=extra
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
		install_extra_now="${install_extra_now}"
		install_xfce4_panel="${install_xfce4_panel}"
		install_polybar="${install_polybar}"
		install_qt5ct="${install_qt5ct}"
		install_jgmenu="${install_jgmenu}"
		install_bspwm="${install_bspwm}"
		switch_default_xsession_to="${switch_default_xsession_to}"
		reboot_now="${reboot_now}"		
	EOF
}

pick_file_downloader_and_url_checker(){
	show_im "picking url command"
	if command -v curl >/dev/null 2>&1;then
		show_im "picked url command: curl "
		check_url(){
			curl -s "${1-}" 2>/dev/null
		}
		download_file(){
			${1-} curl -SsL --progress-bar "${2-}" -o "${3-}" 2>/dev/null
		}
		get_url_content(){
			curl -s "${1-}" 2>/dev/null
		}
	elif command -v wget >/dev/null 2>&1;then
		show_im "picked url command: wget "
		check_url(){
			wget -q -O- "${1-}" >/dev/null 2>&1
		}
		download_file(){
			${1-} wget -q --no-check-certificate --progress=bar "${2-}" -O "${3-}" 2>/dev/null
		}
		get_url_content(){
			wget -q -O- "${1-}" 2>/dev/null
		}
	else
		show_em "please install curl or wget."
	fi
}

fix_time_(){
	[ -f "${installer_phases}/fix_time_" ] && return
	show_m "Setting date ,time ,and timezone."
	get_date_from_here=""
	list_to_test=(network-test.debian.org ipinfo.io 104.16.132.229)
	
	for test in "${list_to_test[@]}";do
		ping -c 1 $test &>/dev/null && get_date_from_here="$test" && break
	done
		
	if [[ -z "$get_date_from_here" ]];then 
		show_em "failed to ping all of this: ${list_to_test[@]}"
	else
		if command -v curl >/dev/null 2>&1;then
			$_SUPERUSER date -s "$(curl --head -sL --max-redirs 0 "$get_date_from_here" 2>&1 | sed -n 's/^ *Date: *//p')" >/dev/null 2>&1
		elif command -v wget >/dev/null 2>&1;then
			$_SUPERUSER date -s "$(wget -S -O- -q --no-check-certificate --max-redirect=0 "$get_date_from_here" 2>&1 | sed -n 's/^ *Date: *//p')" >/dev/null 2>&1
		fi
		#__timezone="$(get_url_content "https://ipinfo.io/" | grep timezone | awk -F: '{print $2}' | sed 's/"//g;s/,//g;s/ //g')"
		__timezone="Asia/Kuwait"
		if command -v timedatectl >/dev/null 2>&1;then
			$_SUPERUSER timedatectl set-timezone $__timezone
		else
			$_SUPERUSER ln -sf /usr/share/zoneinfo/$__timezone /etc/localtime
			$_SUPERUSER hwclock --systohc
		fi
	fi
	touch "${installer_phases}/fix_time_"
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
		wpa_passphrase "$ssid_var" "$pass_var" | tee "$tmpfile" > /dev/null
		$_SUPERUSER wpa_supplicant -B -c "$tmpfile" -i "$wifi_interface" &
		unset ssid_var
		unset pass_var
		show_im "you will wait for few sec"
		sleep 10 
		$_SUPERUSER dhclient "$wifi_interface"
		ping -c4 google.com || show_em "no internet connection"
		[ -f "$tmpfile" ] && rm "$tmpfile"
		test_internet_
	fi
}

must_install_apps()
{
	[ -f "${installer_phases}/must_install_apps" ] && return
	show_m "installing req apps"
	add_packages_2_install_list "mlocate"
	add_packages_2_install_list "git"
	add_packages_2_install_list "curl"
	install_packages
	touch "${installer_phases}/must_install_apps"
}

switch_to_network_manager(){
	[ -f "${installer_phases}/switch_to_network_manager" ] && return
	network_manager_name="network-manager"
	show_m "switching to ${network_manager_name}"
	add_packages_2_install_list "${network_manager_name}"
	install_packages
	my-superuser tee "${temp_path}"/interfaces <<- 'EOF' >/dev/null
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
	touch "${installer_phases}/switch_to_network_manager"
}

purge_some_unnecessary_pakages(){
	[ -f "${installer_phases}/purge_some_unnecessary_pakages" ] && return
	# fonts-linuxlibertine break polybar 
	# fonts-linuxlibertine installed from libreoffice
	if [ "$run_purge_some_unnecessary_pakages" = "Y" ];then
		declare -a to_be_purged=( aisleriot anthy kasumi aspell debian-reference-common fcitx fcitx-bin fcitx-frontend-gtk2 fcitx-frontend-gtk3 fcitx-mozc five-or-more four-in-a-row gnome-chess gnome-klotski gnome-mahjongg gnome-mines gnome-music gnome-nibbles gnome-robots gnome-sudoku gnome-taquin gnome-tetravex gnote goldendict hamster-applet hdate-applet hexchat hitori iagno khmerconverter lightsoff mate-themes malcontent mlterm mlterm-tiny mozc-utils-gui quadrapassel reportbug rhythmbox scim simple-scan sound-juicer swell-foop tali uim xboard xiterm+thai xterm im-config xfce4-notifyd xfce4-power-manager* )
		
		show_im "adding fonts-linuxlibertine to purging list (fonts-linuxlibertine break polybar) "
		to_be_purged+=("linuxlibertine")
		to_be_purged+=("${install_autoinstall_firmware[@]}")
		show_m "purging apps"
		remove_package_with_error2info "${to_be_purged[@]}"
	fi
	touch "${installer_phases}/purge_some_unnecessary_pakages"
}

disable_some_unnecessary_services(){
	[ -f "${installer_phases}/disable_some_unnecessary_services" ] && return
	
	if [ "$init_system_are" = "systemd" ];then
		if [ "$run_disable_some_unnecessary_services" = "Y" ];then
			show_m "Disable some unnecessary services"
			
			# INFO: Some boot services included in Debian are unnecesary for most usres (like NetworkManager-wait-online.service, ModemManager.service or pppd-dns.service)
			for service in NetworkManager-wait-online.service wpa_supplicant ModemManager.service pppd-dns.service;do
				init_manager stop $service || show_wm "fail to stop $service"
				init_manager mask $service || show_wm "fail to mask $service"
			done
	
			# Disable tracker (Data indexing for GNOME mostly)
			for service in tracker-store.service tracker-miner-fs.service tracker-miner-rss.service tracker-extract.service tracker-miner-apps.service tracker-writeback.service;do
				init_manager mask $service  || show_wm "fail to disable $service"
			done
			#init_manager mask gvfs-udisks2-volume-monitor.service || show_im "fail to disable gvfs.service"
			#init_manager mask gvfs-daemon.service || show_wm "fail to disable gvfs.service"
			#init_manager mask gvfs-metadata.service || show_wm "fail to disable gvfs.service"
			
			if init_manager status NetworkManager.service &>/dev/null; then
				init_manager disable networking || show_wm "fail to disable networking"
				init_manager stop systemd-networkd.service || show_wm "fail to stop systemd-networkd.service"
				init_manager disable systemd-networkd.service || show_wm "fail to disable systemd-networkd.service"
			fi
		fi
	fi
	touch "${installer_phases}/disable_some_unnecessary_services"
}

clean_up_now(){
	[ -f "${installer_phases}/clean_up_now" ] && return
	show_m "clean_up_now"
	
	remove_unnecessary_package_manager_stuff
	
	show_m "removing not needed dotfiles"

	remove_this_Array=(
	.xsession-error
	.xsession-error.old
	)
	for removethis in "${remove_this_Array[@]}"; do
		[ -f "${HOME}/${removethis}" ] && rm -f "${HOME}/${removethis}" &> /dev/null;
	done
	
	[ "$autoclean_and_autoremove" = "Y" ] && run_package_manager_autoclean
	touch "${installer_phases}/clean_up_now"
}

disable_ipv6_now(){
	[ -f "${installer_phases}/disable_ipv6_now" ] && return
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
		
		my-superuser tee "${disable_ipv6_conf}" <<- EOF >/dev/null
		net.ipv6.conf.all.disable_ipv6 = 1
		net.ipv6.conf.default.disable_ipv6 = 1
		net.ipv6.conf.lo.disable_ipv6 = 1
		EOF
		my-superuser sysctl -p "${disable_ipv6_conf}"
	fi
	touch "${installer_phases}/disable_ipv6_now"
}

run_my_alternatives(){
	if [ ! -f "${installer_phases}/my_alternatives" ];then
		show_m "update alternatives apps"
		/usr/share/my_stuff/bin/bin/my-alternatives --install
		touch "${installer_phases}/my_alternatives"
	fi
}

update_grub_image(){
	[ -f "${installer_phases}/update_grub_image" ] && return
	if [ "$run_update_grub_image" = "Y" ];then
		show_m "update grub"
		my-superuser ln -sf /usr/share/my_stuff/images/wallpapers/default/${grub_image_name} /boot/grub/
		# this package added some grub config
		my-superuser sync
		my-superuser grub-mkconfig -o /boot/grub/grub.cfg
	fi
	# install Themes
	my-superuser gtk-update-icon-cache
	touch "${installer_phases}/update_grub_image"
}

check_if_user_has_root_access(){
	show_m "check if user has root access."
	if [[ "$EUID" -ne 0 ]];then
    	## Check SuperUser Group
    	SUPERUSERGROUP='wheel sudo root'
    	for sug in ${SUPERUSERGROUP}; do
        	if groups | grep ${sug} >/dev/null; then
            	SUGROUP=${sug}
            	show_im "Super user group are ${SUGROUP}"
        	fi
    	done
    	
    	## Check if member of the SuperUser Group.
    	if ! groups | grep ${SUGROUP} >/dev/null; then
        	show_em "You need to be a member of the SuperUser Group to run me!"
    	fi
    	
    	if command -v doas >/dev/null;then
    		_SUPERUSER="doas"
    		doas_installed=true
		fi
		
		if command -v sudo >/dev/null;then
    		_SUPERUSER="sudo"
    		sudo_installed=true
		fi
		
		if [ "$sudo_installed" = "true" ] || [ "$doas_installed" = "true" ];then
			$_SUPERUSER true
			[ "$sudo_installed" = "true" ] && keep_superuser_refresed &
		fi
		
		$_SUPERUSER ln -sf $(which $_SUPERUSER) /usr/bin/my-superuser
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
	[ -f "${installer_phases}/source_my_lib_file" ] && return
	show_m "sourcing ${lib_file_name} file."
	disto_lib_location="$(find $HOME -type f -name ${lib_file_name} | head -1 || :)"
	# source disto_lib
	if [[ ! -z "${disto_lib_location}" ]];then
		mv "${disto_lib_location}" "${temp_path}"
	elif [[ ! -f "${temp_path}/${lib_file_name}" ]];then 
		show_im "download lib file"
		if ! download_file "" "https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/${lib_file_name}" "${temp_path}/${lib_file_name}"; then
			show_em "Error: Failed to download ${lib_file_name} ."
		fi
	fi
		
	set -a
	if ! source "${temp_path}"/${lib_file_name} 2> /dev/null; then
		show_em "Error: Failed to source ${lib_file_name} from ${temp_path}" >&2
	fi
	set +a
	touch "${installer_phases}/fix_time_"
}

source_this_script(){
	file_to_source_and_check="${1-}"
	message_to_show="${2-}"
	[ ! -f "${temp_path}"/"${file_to_source_and_check}" ] && show_em "can not source this file ( ${temp_path}/${file_to_source_and_check} ). does not exist."
	[ -f "${installer_phases}/${file_to_source_and_check}" ] && return
	show_m "${message_to_show}"
	source "${temp_path}"/"${file_to_source_and_check}"
}

pre_script_create_dir_and_source_stuff(){
	show_m "pre-script: create dir and source files."
	show_im "create dir ${installer_phases}"
	mkdir -p "${installer_phases}"
	
	if [ -f "${save_value_file}" ];then
		source "${save_value_file}"
	fi
	
	if [ -f "${prompt_to_install_value_file}" ];then
		show_im "file exist : ${prompt_to_install_value_file} form previce run."
		if [ "$(do_you_want_2_run_this_yes_or_no 'Do you want source it?')" = "Y" ];then
			source "${prompt_to_install_value_file}"
			source_prompt_to_install_file=true
		fi
	fi
}

purge_sudo(){
	[ -f "${installer_phases}/purge_sudo" ] && return
	if command -v sudo >/dev/null;then
		export SUDO_FORCE_REMOVE=yes
		PASSWORD=$(tr -dc 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' < /dev/urandom | head -c 30 | base64)	
		echo "root:${PASSWORD}" | $_SUPERUSER chpasswd
		remove_package_with_error2info "sudo" 
		echo "$PASSWORD" | su -c "dpkg -i /usr/share/my_stuff/lib/fake_empty_apps/sudo.deb" root
		echo "$PASSWORD" | su -c "ln -sf $(which doas) /usr/bin/sudo" root
		echo "$PASSWORD" | su -c "passwd -l root" root
		PASSWORD=""
		unset PASSWORD
	fi
	touch "${installer_phases}/purge_sudo"
}

keep_superuser_refresed(){
	while true;do
		sudo true
		sleep 10m
	done
}

install_doas(){
	if ! command -v doas >/dev/null;then
		if ! cat /etc/group | grep sudo;then
			$_SUPERUSER groupadd sudo
		fi
		show_im "Installing doas"
		add_packages_2_install_list "doas"
		add_packages_2_install_list "expect"
		kill_package_ ${PACKAGER} && install_packages || (kill_package_ ${PACKAGER}  && install_packages) || (show_em "failed to install doas")
		$_SUPERUSER adduser "$USER" sudo || :
		$_SUPERUSER tee -a /etc/bash.bashrc <<- EOF >/dev/null 2>&1
		if [ -x /usr/bin/doas ]; then
			complete -F _command doas
		fi
		EOF
	fi
}

install_superuser_tools()
{
	show_m "install superuser tools."
	[ -f "${installer_phases}/install_superuser_tools" ] && return
	if [ "$switch_to_doas" = true ];then
		install_doas
	fi
	
	if [ -z "$_SUPERUSER" ] && [ "$doas_installed" = false ] ;then
	   	install_doas
    	$_SUPERUSER tee /etc/doas.conf <<- EOF >/dev/null 
		permit nopass $USER as root			
		EOF
		if ! doas -C /etc/doas.conf;then
			show_em "config error"
		fi
		chmod -c 0400 /etc/doas.conf
		ln -sf $(which doas) /usr/bin/my-superuser
	fi
	touch "${installer_phases}/install_superuser_tools"
}

set_package_manager(){
	if [ -z "${PACKAGER}" ];then
		show_m "checking which type of package manager is being used."
		## Check Package Handeler
		PACKAGEMANAGER='apt-get yum dnf pacman zypper'
		for pgm in ${PACKAGEMANAGER}; do
			if command -v ${pgm} >/dev/null; then
				PACKAGER=${pgm}
				show_im "Using ${pgm}"
				break
			fi
		done
		
		if [ -z "${PACKAGER}" ]; then
			show_em "${RED}Can't find a supported package manager"
		fi
		
		check_and_download_ "disto_package_manager_${PACKAGER}"
		echo "PACKAGER=\"${PACKAGER}\"" | tee "${save_value_file}" >/dev/null 2>&1
	fi
	
	if ! source "${temp_path}/disto_package_manager_${PACKAGER}" 2> /dev/null; then
		show_em "Error: Failed to source disto_package_manager_${PACKAGER} from ${temp_path}" >&2
	fi
	
	pre_package_manager_
	
	kill_package_ ${PACKAGER} 	
}

switch_default_xsession(){
	if [ -f "${installer_phases}/switch_default_xsession" ];then
		return	
	fi
	show_m "switching default xsession to my stuff $switch_default_xsession_to."
	my-superuser update-alternatives --install /usr/bin/x-session-manager x-session-manager /usr/share/my_stuff/system_files/bin/xsessions/${switch_default_xsession_to} 60
	touch "${installer_phases}/switch_default_xsession"
}

create_uninstaller_file(){
	[ -f "${var_for_distro_uninstaller}" ] && return
	show_m "Creating uninstaller file."
	List_of_installed_packages_="${List_of_apt_2_install_[@]}"
	my-superuser tee "${var_for_distro_uninstaller}" <<- EOF >/dev/null
	grub_image_name=\"${grub_image_name}\"
	List_of_pakages_installed_=\"${List_of_installed_packages_}\"
	switch_default_xsession=\"$(realpath /etc/alternatives/x-session-manager)\"
	EOF
}

switch_to_doas_now(){
	if [ "$switch_to_doas" = true ];then
		show_m "Purging sudo."
		if [ -n "$_SUPERUSER" ];then
			sudo ln -sf $(which doas) /usr/bin/my-superuser
		else
			ln -sf $(which doas) /usr/bin/my-superuser
		fi
		purge_sudo
	fi
}

pick_clone_rep_commnad(){
	show_m "pick clone repo commnad"
	if command -v git >/dev/null 2>&1;then
		show_im "clone repo commnad: git"
		clone_rep_(){
			getthis="${1-}"
			if [ ! -f "${installer_phases}/${getthis}" ];then
				show_im "clone distro files repo ( ${getthis} )."
				getthis_location="$(find $HOME -type d -name ${getthis} | head -1)"
				
				if [ -z "${getthis_location}" ];then
					getthis_location="${temp_path}"
				else
					getthis_location="$(cd "${getthis_location}" && cd .. && pwd)"
				fi
				
				if [ ! -d "${getthis_location}/${getthis}" ]; then 
					git clone --depth=1 "https://github.com/dari862/${getthis}.git" "${getthis_location}/${getthis}"
				else
					show_im "${getthis} Folder does exsist"
				fi
			fi
			touch "${installer_phases}/${getthis}"
		}
	elif command -v svn >/dev/null 2>&1;then
		show_im "clone repo commnad: svn"
		clone_rep_(){
			getthis="${1-}"
			if [ ! -f "${installer_phases}/${getthis}" ];then
				show_im "clone distro files repo ( ${getthis} )."
				getthis_location="$(find $HOME -type d -name ${getthis} | head -1)"
				
				if [ -z "${getthis_location}" ];then
					getthis_location="${temp_path}"
				else
					getthis_location="$(cd "${getthis_location}" && cd .. && pwd)"
				fi
				
				if [ ! -d "${getthis_location}/${getthis}" ]; then 
					svn clone --depth=1 "https://github.com/dari862/${getthis}.git" "${getthis_location}/${getthis}"
				else
					show_im "${getthis} Folder does exsist"
				fi
			fi
			touch "${installer_phases}/${getthis}"
		}
	fi
}

check_and_download_core_script(){
	show_m "check if exsit and download core script."
	
	if [[ "$arg_" = "drivers" ]] || [[ -z "$arg_" ]];then
		check_and_download_ "disto_Drivers_list"
		check_and_download_ "disto_Drivers_installer"
	fi
	
	if [[ "$arg_" = "apps" ]] || [[ -z "$arg_" ]];then
		check_and_download_ "disto_apps_list"
		check_and_download_ "disto_apps_installer"
	fi
	
	if [[ -z "$arg_" ]];then
		check_and_download_ "disto_configer"
		
		check_and_download_ "disto_post_install"
		
		################################
		# repo clone
		show_m "clone distro files repo."
		clone_rep_ "my_stuff"
		my_stuff_temp_path="${getthis_location}"
		clone_rep_ "Theme_Stuff"
		theme_temp_path="${getthis_location}"
		################################
	fi
}
################################################################################################################################
################################################################################################################################
################################################################################################################################
# main
################################################################################################################################
################################################################################################################################
################################################################################################################################
show_m "Loading Script ....."

pre_script_create_dir_and_source_stuff

check_if_user_has_root_access

prompt_to_ask_to_what_to_install

pick_file_downloader_and_url_checker

test_internet_

fix_time_

source_my_lib_file

CHECK_IF_THIS_LAPTOP

set_package_manager

install_superuser_tools

must_install_apps

pick_clone_rep_commnad

check_and_download_core_script

clear

_unattended_upgrades_ stop

if [[ "$arg_" = "drivers" ]] || [[ -z "$arg_" ]];then
	source_this_script "disto_Drivers_list" "Install drivers from (disto_Drivers)"
	source_this_script "disto_Drivers_installer" "Install drivers from (disto_Drivers)"
fi

if [[ "$arg_" = "apps" ]] || [[ -z "$arg_" ]];then
	source_this_script "disto_apps_list" "Install drivers from (disto_Drivers)"
	source_this_script "disto_apps_installer" "Install apps from (disto_Installapps_list)"
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
source_this_script "disto_configer" "Configering My Stuff."

purge_some_unnecessary_pakages

disable_some_unnecessary_services

clean_up_now

disable_ipv6_now

update_grub_image

run_my_alternatives

source_this_script "disto_post_install" "prepare some script"

create_uninstaller_file

switch_default_xsession

switch_to_doas_now

show_m "Done"

if [ "$reboot_now" = "Y" ];then
	/usr/share/my_stuff/system_files/bin/my_session_manager reboot
fi
