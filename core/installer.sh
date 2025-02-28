#!/bin/sh
set -e
################################################################################################################################
# Var
################################################################################################################################
__distro_path="/usr/share/my_stuff"
lib_file_name="disto_lib"
auto_run_script="false" # true to enable
temp_path="/tmp/temp_distro_installer_dir"
installer_phases="${temp_path}/installer_phases"
switch_default_xsession_to="openbox"
switch_to_doas=false
NETWORK_TEST="network-test.debian.org"
url_to_test=debian.org
test_dns="1.1.1.1"

mirror=""
mirror_security=""
deb_lines_contrib=""
deb_lines_nonfree_firmware=""
deb_lines_nonfree=""

export temp_path="${temp_path}"
prompt_to_install_value_file="${temp_path}/value_of_picked_option_from_prompt_to_install"
save_value_file="${temp_path}/save_value_file"
install_drivers=true
install_apps=true
arg_="${1-}"
if [ "$arg_" = "drivers" ];then
	install_drivers=true
	install_apps=false
elif [ "$arg_" = "apps" ];then
	install_drivers=false
	install_apps=true
fi
SUGROUP=""
internet_status=""
disto_lib_location=""

install_GPU_Drivers="install_GPU"
_cuda_=""
_kernel_open_dkms_=""
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
install_xfce4_panel=""
install_files_manager=true
thunar_files_manager=false
pcmanfm_files_manager=false
install_polybar=polybar
install_bspwm=bspwm
reboot_now="Y"

enable_contrib=false
enable_nonfree_firmware=false
enable_nonfree=false
_SUPERUSER=""
__USER="$USER"
source_prompt_to_install_file=""

getthis_location=""
my_stuff_temp_path=""
theme_temp_path=""
Distro_Specific_temp_path=""

doas_installed=false
sudo_installed=false

PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:$PATH

var_for_distro_uninstaller="${__distro_path}/system_files/var_for_distro_uninstaller"

list_of_apps_file_path="${temp_path}/list_of_apps"

# distro
if [ -f /etc/os-release ];then
	# freedesktop.org and systemd
	. /etc/os-release
	version_="$(echo "${VERSION_ID}" | sed 's/.//g')"
	distro_name_="$ID"
	distro_name_and_ver_=$ID$version_
fi

PACKAGEMANAGER='apt-get dnf pacman zypper'
for pgm in ${PACKAGEMANAGER}; do
	if command -v ${pgm} >/dev/null;then
		PACKAGER=${pgm}
		break
	fi
done		
if [ -z "${PACKAGER}" ];then
	echo "Error: Can't find a supported package manager"
fi
		
mirror="http://deb.debian.org/debian/"
mirror_security="http://security.debian.org/debian-security"
only_doas_installed=false

if [ -d "$HOME/Desktop" ];then
	dir_2_find_files_in="$HOME/Desktop ${temp_path}"
else
	dir_2_find_files_in="${temp_path}"
fi

GPU_Drivers_ready=false
this_is_laptop=false
fingerprint_exist=true
################################################################################################################################
# Function
################################################################################################################################

show_m(){
	message="${1-}"
	printf '%b' "\n==[ \\033[1;32m${message}\\033[0m ]==\n"
}

show_wm(){
	message="${1-}"
	printf '%b' "\\033[1;33m[!] \\033[0m${message}\n"
}

show_em(){
	message="${1-}"
	printf '%b' "\\033[1;31m[-] ${message}\\033[0m\n"
	exit 1
}

show_im(){
	message="${1-}"
	printf '%b' "\\033[1;34m[*] \\033[0m${message}\n"
}

show_sm(){
	message="${1-}"
	printf '%b' "\\033[1;34m  ==> \\033[0m${message}\n"
}

test_internet_(){
	show_m "Testing internet connection."
	
	if ! internet_tester ;then
		wifi_interface=""
		if check_url "$url_to_test";then
			show_im "Internet connection test passed!"
			return 0
		else
			show_wm "Internet connection test failed!"
			_intface="$(ip route | awk '/default/ { print $5 }')"
			if [ -z "$_intface" ];then
				for intf in /sys/class/net/*; do
					intf_name="$(basename $intf)"
					if [ "$intf_name" != "lo" ] || echo "$intf_name" | grep "^w" ;then
    					$_SUPERUSER ip link set dev $intf_name up
    				fi
				done
				_intface="$(ip route | awk '/default/ { print $5 }')"
				if [ -z "$_intface" ];then
            		show_em "Problem seems to be with your interface. not connected"
            	fi
			fi
			_ip="$(ip address show dev $_intface | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/')"
			if echo $_ip | grep -qE '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)';then
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
			
			if ! ping -q -c 5 "$test_dns" >/dev/null 2>&1;then
            	show_em "Problem seems to be with your gateway. $_ip"
        	elif ! ping -q -c 5 "$gway" >/dev/null 2>&1;then
            	show_em "Can not reach your gateway. $_ip"s
    		fi
	
    		fix_time_
    		
    		if check_url "$url_to_test";then
				show_im "Internet connection test passed!"
				return 0
			elif ping -q -c 5 "$test_dns" >/dev/null 2>&1;then
            	show_em "Problem seems to be with your DNS. $_ip"
        	else
            	show_em "Somthing wrong with your network"
    		fi
    	fi  
	fi
}

do_you_want_2_run_this_yes_or_no()
{
	massage_is_="${1}"
	while true; do
		printf "${massage_is_} (yes/no) (default: yes) "
		stty -icanon -echo time 0 min 1
		answer="$(head -c1)"
		stty icanon echo
		echo
        	
		case "$answer" in
			[Yy]) return 0;;
			[Nn]) return 1 ;;
			*) show_im "invalid response only y[yes] or n[No] are allowed.";;
		esac
	done
}

prompt_to_ask_to_what_to_install(){
	if [ "${source_prompt_to_install_file}" = "true" ];then
		return
	fi
	
	if [ "$distro_name_" = "debian" ];then
		mirror="http://deb.debian.org/debian/"
		mirror_security="http://security.debian.org/debian-security"
		deb_lines_nonfree_firmware=$(grep -E "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v 'non-free-firmware' || :)
		deb_lines_contrib=$(grep -E "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v contrib || :)
		deb_lines_nonfree=$(grep -E "^(deb|deb-src) (${mirror}|${mirror_security})" /etc/apt/sources.list | grep -v "non-free[[:blank:]]" || :)
	fi
	show_m "prompt for what do you want to install."
	
	if [ "$auto_run_script" != "true" ];then
		if do_you_want_2_run_this_yes_or_no 'Autorun installation?';then
			return
		fi
			
		if [ "$switch_to_doas" = false ] && [ "$only_doas_installed" = "false" ];then
			if do_you_want_2_run_this_yes_or_no 'Switch to doas?';then
				switch_to_doas=true
			fi
		fi
		
		if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
			if [ "$distro_name_" = "debian" ];then
				if [ -n "$deb_lines_contrib" ];then
					if do_you_want_2_run_this_yes_or_no 'Do you want enable contrib repo?';then
						enable_contrib=true
					else
						enable_contrib=false
					fi
				fi
				if [ -n "$deb_lines_nonfree_firmware" ];then
					if do_you_want_2_run_this_yes_or_no 'Do you want enable nonfree_firmware repo?';then
						enable_nonfree_firmware=true
					else
						enable_nonfree_firmware=false
					fi
				fi
				if [ -n "$deb_lines_nonfree" ];then
					if do_you_want_2_run_this_yes_or_no 'Do you want enable nonfree repo?';then
						enable_nonfree=true
					else
						enable_nonfree=false
					fi
				fi
			fi
		fi
		
		if [ "$install_drivers" = "true" ];then
			if do_you_want_2_run_this_yes_or_no 'do you want to install GPU drivers?';then
				install_GPU_Drivers="Y"
				if lspci | grep -i nvidia | grep VGA -q;then
					enable_nvidia_repo="true"
					if do_you_want_2_run_this_yes_or_no 'do you want to add Cuda Support?';then
						_cuda_="Y"
					else
						_cuda_=""
					fi
					
					if do_you_want_2_run_this_yes_or_no 'do you want to install opensource nvidia-kernel?';then
						_kernel_open_dkms_="Y"
					else
						_kernel_open_dkms_=""
					fi
				else
					_cuda_=""
					_kernel_open_dkms_=""
				fi
			else
				install_GPU_Drivers=""
			fi
		fi
		
		if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
			if do_you_want_2_run_this_yes_or_no 'do you want to purge some unnecessary pakages?';then
				run_purge_some_unnecessary_pakages="Y"
			else
				run_purge_some_unnecessary_pakages=""
			fi
			
			if do_you_want_2_run_this_yes_or_no 'Do you want to disable some unnecessary services?';then
				run_disable_some_unnecessary_services="Y"
			else
				run_disable_some_unnecessary_services=""
			fi
			
			if do_you_want_2_run_this_yes_or_no 'update grub image?';then
				run_update_grub_image="Y"
			else
				run_update_grub_image=""
			fi
			
			if do_you_want_2_run_this_yes_or_no 'disable ipv6 stack?';then
				disable_ipv6_stack="Y"
			else
				if do_you_want_2_run_this_yes_or_no 'disable ipv6 only?';then
					disable_ipv6="Y"
				else
					disable_ipv6=""
				fi
				disable_ipv6_stack=""
			fi
			
			if do_you_want_2_run_this_yes_or_no 'run autoclean and autoremove?';then
				autoclean_and_autoremove="Y"
			else
				autoclean_and_autoremove=""
			fi
		fi
		
		if [ "$install_apps" = "true" ];then
			if ! command -v zsh >/dev/null;then
				if do_you_want_2_run_this_yes_or_no 'Do you want to install zsh?';then
					if do_you_want_2_run_this_yes_or_no 'Do you want to set zsh as default shell?';then
						install_zsh_now=zsh_default
					else
						install_zsh_now=zsh
					fi
				else
					install_zsh_now=""
				fi
			else
				if do_you_want_2_run_this_yes_or_no 'Do you want to set zsh as default shell?';then
					install_zsh_now=zsh_default
				else
					install_zsh_now=zsh
				fi
			fi
			
			if ! command -v xfce4-panel >/dev/null;then
				if do_you_want_2_run_this_yes_or_no 'Do you want to install xfce4-panel?';then
					install_xfce4_panel=xfce4_panel
				else
					install_xfce4_panel=""
				fi
			fi
			
			if [ "$install_files_manager" = false ];then
				if do_you_want_2_run_this_yes_or_no 'Do you want to File Manager?';then
					install_files_manager=true
				fi
				
				if [ "$thunar_files_manager" = false ] && [ "$install_files_manager" = true ] ;then
					if ! command -v thunar >/dev/null;then
						if do_you_want_2_run_this_yes_or_no 'Do you want to switch from pcmanfm to thunar?';then
							thunar_files_manager=true
						else
							pcmanfm_files_manager=true
						fi
					else
						thunar_files_manager=true
					fi
				fi
			fi
			if ! command -v polybar >/dev/null;then
				if do_you_want_2_run_this_yes_or_no 'Do you want to install polybar?';then
					install_polybar=polybar
				else
					install_polybar=""
				fi
			fi
			
			if ! command -v qt5ct >/dev/null;then
				if do_you_want_2_run_this_yes_or_no 'Do you want to install qt5ct?';then
					install_qt5ct=qt5ct
				else
					install_qt5ct=""
				fi
			fi
			
			if ! command -v jgmenu >/dev/null;then
				if do_you_want_2_run_this_yes_or_no 'Do you want to install jgmenu?';then
					install_jgmenu=jgmenu
				else
					install_jgmenu=""
				fi
			fi
			
			if ! command -v bspwm >/dev/null;then
				if do_you_want_2_run_this_yes_or_no 'Do you want to install bspwm?';then
					install_bspwm=bspwm
					if do_you_want_2_run_this_yes_or_no 'Do you want to switch to bspwm session?';then
						switch_default_xsession_to="bspwm"
					fi
				else
					install_bspwm=""
				fi
			fi
			if do_you_want_2_run_this_yes_or_no 'Do you want to install extra apps?';then
				install_extra_now=extra
			else
				install_extra_now=""
			fi
		fi
		
		if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
			if do_you_want_2_run_this_yes_or_no 'reboot?';then
				reboot_now="Y"
			else
				reboot_now=""
			fi
		fi
	fi
}

create_prompt_to_install_value_file(){
	show_im "creating: ${prompt_to_install_value_file}"
	tee "${prompt_to_install_value_file}" <<- EOF >/dev/null
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
	show_m "picking url command"
	if command -v curl >/dev/null 2>&1;then
		url_package="curl"
		check_url(){
			curl -SsL "${1-}" 2>/dev/null
		}
		get_url_content(){
			curl -fsSL "${1-}"
		}
		download_file(){
			${1-} curl -SsL --progress-bar "${2-}" -o "${3-}" 2>/dev/null
		}
		get_url_content(){
			curl -s "${1-}" 2>/dev/null
		}
		get_current_date(){
			curl --head -fSs --max-redirs 0 "${1-}" 2>&1 | sed -n 's/^ *Date: *//p'
		}
	elif command -v wget >/dev/null 2>&1;then
		url_package="wget"
		check_url(){
			wget -q -O- "${1-}" >/dev/null 2>&1
		}
		get_url_content(){
			wget -O- "${1-}"
		}
		download_file(){
			${1-} wget -q --no-check-certificate --progress=bar "${2-}" -O "${3-}" 2>/dev/null
		}
		get_url_content(){
			wget -q -O- "${1-}" 2>/dev/null
		}
		get_current_date(){
			wget -S -O- -q --no-check-certificate --max-redirect=0 "${1-}" 2>&1 | sed -n 's/^ *Date: *//p'
		}
	else
		show_em "Neither curl nor wget is availabl, please install curl or wget.."
	fi
	show_im "picked url command: $url_package "
}

internet_tester() {
    test_with_nc() {
        printf "GET /nm HTTP/1.1\r\nHost: ${NETWORK_TEST}\r\n\r\n" | nc -w1 "$NETWORK_TEST" 80 | grep -q "NetworkManager is online" >/dev/null 2>&1
    }
    test_with_http() {
        if command -v curl >/dev/null 2>&1;then
            curl -s -X GET "$url_to_test" >/dev/null 2>&1
        elif command -v wget >/dev/null 2>&1;then
            wget -qS -O- "$url_to_test" >/dev/null 2>&1
        fi
    }
    if command -v nc >/dev/null 2>&1;then
        if ! test_with_nc;then
            show_im "Failed to check internet using nc (netcat), switching to ${url_package}..."
            test_with_http
        fi
    else
        show_im "nc (Netcat) not found. Attempting to test internet connectivity..."
        test_with_http
    fi
    show_im "There is an internet connection..."
}

fix_time_(){
	[ -f "${installer_phases}/fix_time_" ] && return
	show_m "Setting date ,time ,and timezone."
	get_date_from_here=""
	list_to_test="${NETWORK_TEST} ipinfo.io 104.16.132.229"
	
	for test in ${list_to_test};do
		show_im "testing time domain if they are up."
		ping -c 1 $test >/dev/null 2>&1 && get_date_from_here="$test" && break
	done
		
	if [ -z "$get_date_from_here" ];then 
		show_em "failed to ping all of this: ${list_to_test}"
	else
		show_im "Getting time and timezone."
		current_date="$(get_current_date "$get_date_from_here")"
		$_SUPERUSER date -s "$current_date" >/dev/null 2>&1
		__timezone="$(get_url_content "https://ipinfo.io/" | grep timezone | awk -F: '{print $2}' | sed 's/"//g;s/,//g;s/^[ \t]*//;s/[ \t]*$//')"
		show_im "applying time and timezone."
		if ! $_SUPERUSER timedatectl set-timezone $__timezone >/dev/null 2>&1;then
			$_SUPERUSER ln -sf /usr/share/zoneinfo/$__timezone /etc/localtime
			if ! $_SUPERUSER hwclock --systohc >/dev/null 2>&1;then
				show_em "failed to set time zone !"
			fi
		fi
	fi
	echo "__timezone=\"$__timezone\"" >> "${save_value_file}"
	show_im "fix time done."
	touch "${installer_phases}/fix_time_"
}

wifi_mode_installation(){
	wifi_interface="${1-}"
	
	ip link set "$wifi_interface" up
		
	if command -v nmcli >/dev/null 2>&1
	then
		nmcli radio wifi on
		while :
		do
			nmcli --ask dev wifi connect && break
		done
	elif command -v wpa_supplicant >/dev/null 2>&1
	then
		tmpfile="$(mktemp)"
		while :
		do
			printf "\n These hotspots are available \n"
			$_SUPERUSER iwlist "$wifi_interface" scan | grep ESSID | sed 's/ESSID://g;s/"//g;s/^                    //g'
			echo "ssid: "
			read -r ssid_var
			if iw "$wifi_interface" scan | grep 'SSID' | grep "$ssid_var" >/dev/null;then
				echo "pass: "
				read -r pass_var
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
	install_packages
	touch "${installer_phases}/must_install_apps"
}

purge_some_unnecessary_pakages(){
	[ -f "${installer_phases}/purge_some_unnecessary_pakages" ] && return
	show_m "purge some unnecessary pakages"
	# fonts-linuxlibertine break polybar 
	# fonts-linuxlibertine installed from libreoffice
	if [ "$run_purge_some_unnecessary_pakages" = "Y" ];then
		to_be_purged=" aisleriot anthy kasumi aspell debian-reference-common fcitx fcitx-bin fcitx-frontend-gtk2 fcitx-frontend-gtk3 fcitx-mozc five-or-more four-in-a-row gnome-chess gnome-klotski gnome-mahjongg gnome-mines gnome-music gnome-nibbles gnome-robots gnome-sudoku gnome-taquin gnome-tetravex gnote goldendict hamster-applet hdate-applet hexchat hitori iagno khmerconverter lightsoff mate-themes malcontent mlterm mlterm-tiny mozc-utils-gui quadrapassel reportbug rhythmbox scim simple-scan sound-juicer swell-foop tali uim xboard xiterm+thai xterm im-config xfce4-notifyd xfce4-power-manager* "
		
		show_im "adding fonts-linuxlibertine to purging list (fonts-linuxlibertine break polybar) "
		to_be_purged="${to_be_purged} linuxlibertine"
		to_be_purged="${to_be_purged} ${install_autoinstall_firmware}"
		show_im "purging apps"
		remove_package_with_error2info "${to_be_purged}"
	fi
	touch "${installer_phases}/purge_some_unnecessary_pakages"
}

disable_some_unnecessary_services(){
	[ -f "${installer_phases}/disable_some_unnecessary_services" ] && return
	
	if [ "$init_system_are" = "systemd" ];then
		if [ "$run_disable_some_unnecessary_services" = "Y" ];then
			show_m "Disable some unnecessary services"
			
			# INFO: Some boot services included in Debian are unnecesary for most usres (like NetworkManager-wait-online.service, ModemManager.service or pppd-dns.service)
			for service in NetworkManager-wait-online.service ModemManager.service pppd-dns.service;do
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
			
			if init_manager status NetworkManager.service >/dev/null 2>&1;then
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
	
	show_im "removing not needed dotfiles"

	remove_this_Array="
	.xsession-error
	.xsession-error.old
	"
	for removethis in ${remove_this_Array}; do
		[ -f "${HOME}/${removethis}" ] && rm -f "${HOME}/${removethis}" >/dev/null 2>&1;
	done
	
	[ "$autoclean_and_autoremove" = "Y" ] && run_package_manager_autoclean
	touch "${installer_phases}/clean_up_now"
}

disable_ipv6_now(){
	[ -f "${installer_phases}/disable_ipv6_now" ] && return
	if [ "$disable_ipv6_stack" = "Y" ];then
		show_im "disabling IPv6 stack (kernal level)."
		if ! grep 'GRUB_CMDLINE_LINUX=' /etc/default/grub | grep -q 'ipv6.disable=1';then
			if grep -q 'GRUB_CMDLINE_LINUX=""' /etc/default/grub;then
				my-superuser sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="ipv6.disable=1"/' /etc/default/grub
				need_to_update_grub=true
			else
				my-superuser sed -i 's/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 ipv6.disable=1\"/' /etc/default/grub
				need_to_update_grub=true
			fi
		fi
		if ! grep 'GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | grep -q 'ipv6.disable=1';then
			if grep -q 'GRUB_CMDLINE_LINUX_DEFAULT=""' /etc/default/grub;then
				my-superuser sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1"/' /etc/default/grub
				need_to_update_grub=true
			else
				my-superuser sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ipv6.disable=1\"/' /etc/default/grub
				need_to_update_grub=true
			fi
		fi
	fi
	
	if [ "$disable_ipv6" = "Y" ];then
		disable_ipv6_conf="/etc/sysctl.d/90-disable_ipv6.conf"
		if [ ! -f "${disable_ipv6_conf}" ];then
			show_im "Disabling IPv6."
			my-superuser tee "${disable_ipv6_conf}" <<- EOF >/dev/null
			net.ipv6.conf.all.disable_ipv6 = 1
			net.ipv6.conf.default.disable_ipv6 = 1
			net.ipv6.conf.lo.disable_ipv6 = 1
			EOF
			my-superuser sysctl -p "${disable_ipv6_conf}"
		fi
	fi
	touch "${installer_phases}/disable_ipv6_now"
}

run_my_alternatives(){
	[ -f "${installer_phases}/my_alternatives" ] && return
	show_m "update alternatives apps"
	${__distro_path}/bin/bin/my-alternatives --install
	touch "${installer_phases}/my_alternatives"
}

update_grub(){
	[ -f "${installer_phases}/update_grub" ] && return
	if [ "$need_to_update_grub" = "true" ];then
		show_im "update grub"
		my-superuser sync
		my-superuser grub-mkconfig -o /boot/grub/grub.cfg
	fi
	touch "${installer_phases}/update_grub"
}

update_grub_image(){
	[ -f "${installer_phases}/update_grub_image" ] && return
	if [ "$run_update_grub_image" = "Y" ];then
		show_im "update image."
		my-superuser "${__distro_path}/bin/not_add_2_path/grub2_themes/install.sh"
	fi
	touch "${installer_phases}/update_grub_image"
}

check_if_user_has_root_access(){
	[ -f "${installer_phases}/check_if_user_has_root_access" ] && return
	show_im "check if user has root access."
	if [ "$(id -u)" -ne 0 ];then
		show_im "you are using normal user."
    	## Check SuperUser Group
    	SUPERUSERGROUP='wheel sudo root'
    	for sug in ${SUPERUSERGROUP}; do
        	if groups | grep ${sug} >/dev/null;then
            	SUGROUP=${sug}
            	show_im "Super user group are ${SUGROUP}"
        	fi
    	done
    	
    	## Check if member of the SuperUser Group.
    	if ! groups | grep ${SUGROUP} >/dev/null;then
        	show_em "You need to be a member of the SuperUser Group to run me!"
    	fi
    	
    	echo "SUGROUP=\"$SUGROUP\"" >> "${save_value_file}"
    	
    	if command -v doas >/dev/null;then
    		_SUPERUSER="doas"
    		doas_installed=true
    		echo "_SUPERUSER=\"$_SUPERUSER\"" >> "${save_value_file}"
    		echo "doas_installed=\"$doas_installed\"" >> "${save_value_file}"
		fi
		
		if command -v sudo >/dev/null;then
    		_SUPERUSER="sudo"
    		sudo_installed=true
    		echo "_SUPERUSER=\"$_SUPERUSER\"" >> "${save_value_file}"
    		echo "sudo_installed=\"$sudo_installed\"" >> "${save_value_file}"
		fi

		if [ "$sudo_installed" = "false" ] && [ "$doas_installed" = "true" ];then
			only_doas_installed="true"
			echo "only_doas_installed=\"$only_doas_installed\"" >> "${save_value_file}"
		fi
		show_im "value of _SUPERUSER are $_SUPERUSER"
    else
    	show_im "you are elevated user."
    	if command -v doas >/dev/null;then
    		show_im "doas command exist."
    		doas_installed=true
    		echo "doas_installed=\"$doas_installed\"" >> "${save_value_file}"
		fi
		
		if command -v sudo >/dev/null;then
    		sudo_installed=true
    		echo "sudo_installed=\"$sudo_installed\"" >> "${save_value_file}"
		fi
		_SUPERUSER=""
		echo "_SUPERUSER=\"$_SUPERUSER\"" >> "${save_value_file}"
    	show_im "value of _SUPERUSER are $_SUPERUSER"
    fi
    touch "${installer_phases}/check_if_user_has_root_access"
}

source_my_lib_file(){
	if [ ! -f "${installer_phases}/source_my_lib_file" ];then
		show_m "sourcing ${lib_file_name} file."
		disto_lib_location="$(find ${dir_2_find_files_in} -type f -name ${lib_file_name} | head -1 || :)"
		# source disto_lib
		if [ -n "${disto_lib_location}" ] && [ "${disto_lib_location}" != "${temp_path}/${lib_file_name}" ];then
			mv "${disto_lib_location}" "${temp_path}"
		elif [ ! -f "${temp_path}/${lib_file_name}" ];then 
			show_im "download lib file"
			if ! download_file "" "https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/${lib_file_name}" "${temp_path}/${lib_file_name}";then
				show_em "Error: Failed to download ${lib_file_name} ."
			fi
		fi
		touch "${installer_phases}/source_my_lib_file"
	fi	
	set -a
	show_im "sourcing ${lib_file_name} from ${temp_path}"
	if ! . "${temp_path}"/${lib_file_name};then
		show_em "Error: Failed to source ${lib_file_name} from ${temp_path}"
	fi
	set +a
}

source_this_script(){
	file_to_source_and_check="${1-}"
	message_to_show="${2-}"
	[ ! -f "${temp_path}"/"${file_to_source_and_check}" ] && show_em "can not source this file ( ${temp_path}/${file_to_source_and_check} ). does not exist."
	[ -f "${installer_phases}/${file_to_source_and_check}" ] && return
	show_im "${message_to_show}"
	. "${temp_path}"/"${file_to_source_and_check}"
}

pre_script_create_dir_and_source_stuff(){
	show_m "pre-script: create dir and source files."
	show_im "create dir ${installer_phases}"
	
	mkdir -p "${temp_path}"
	chmod 700 "${temp_path}"
	
	mkdir -p "${installer_phases}"
		
	if [ -f "${save_value_file}" ];then
		. "${save_value_file}"
	fi
	
	if [ -f "${prompt_to_install_value_file}" ];then
		show_im "file exist : ${prompt_to_install_value_file} form previce run."
		if do_you_want_2_run_this_yes_or_no 'Do you want source it?';then
			. "${prompt_to_install_value_file}"
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
		echo "$PASSWORD" | su -c "dpkg -i ${__distro_path}/lib/fake_empty_apps/sudo.deb" root
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

install_superuser_tools()
{
	[ -f "${installer_phases}/install_superuser_tools" ] && return
	if [ "$switch_to_doas" = true ] && [ "$only_doas_installed" = "false" ];then
		show_m "install superuser tools."
		if ! grep "sudo" /etc/group;then
			$_SUPERUSER groupadd sudo
		fi
		show_im "Installing doas"
		add_packages_2_install_list "doas"
		add_packages_2_install_list "expect"
		kill_package_ ${PACKAGER} && install_packages || (kill_package_ ${PACKAGER}  && install_packages) || (show_em "failed to install doas")
		$_SUPERUSER adduser "$USER" sudo || :
		$_SUPERUSER tee -a /etc/bash.bashrc <<- EOF >/dev/null 2>&1
		if [ -x /usr/bin/doas ];then
			complete -F _command doas
		fi
		EOF
		
    	$_SUPERUSER tee /etc/doas.conf <<- EOF >/dev/null 
		permit nopass $USER as root			
		EOF
		if ! $_SUPERUSER doas -C /etc/doas.conf;then
			show_em "config error"
		fi
		$_SUPERUSER chmod -c 0400 /etc/doas.conf
		doas_path="$(which doas)"
		$_SUPERUSER ln -sf "$doas_path" "/usr/bin/my-superuser"
	fi
	touch "${installer_phases}/install_superuser_tools"
}

set_package_manager(){
	show_m "running set_package_manager function"
	show_im "Using ${PACKAGER}"
	if [ ! -f "${installer_phases}/set_package_manager" ];then
		check_and_download_ "${PACKAGER}" "installer_repo"
		echo "PACKAGER=\"${PACKAGER}\"" >> "${save_value_file}"
		
		if ! . "${temp_path}/${PACKAGER}";then
			show_em "Error: Failed to source ${PACKAGER} from ${temp_path}"
		fi
		
		if check_if_package_exist_in_repo --no-list-of-apps-file systemd >/dev/null 2>&1;then
			init_system_are="systemd"
			echo "init_system_are=\"${init_system_are}\"" >> "${save_value_file}"
		else
			show_em "Error: variable init_system_are are empty"
		fi
		
		check_and_download_ "disto_init_manager"
		if ! . "${temp_path}/disto_init_manager";then
			show_em "Error: Failed to source disto_init_manager from ${temp_path}"
		fi
		
		show_im "running pre_package_manager_"
		pre_package_manager_
		touch "${installer_phases}/set_package_manager"
	else
		if ! . "${temp_path}/${PACKAGER}";then
			show_em "Error: Failed to source ${PACKAGER} from ${temp_path}"
		fi
		if ! . "${temp_path}/disto_init_manager";then
			show_em "Error: Failed to source disto_init_manager from ${temp_path}"
		fi
	fi
}

switch_default_xsession(){
	[ -f "${installer_phases}/switch_default_xsession" ] && return
	show_m "switching default xsession to my stuff $switch_default_xsession_to."
	if command -v update-alternatives >/dev/null 2>&1;then
		my-superuser update-alternatives --install /usr/bin/x-session-manager x-session-manager ${__distro_path}/system_files/bin/xsessions/${switch_default_xsession_to} 60
	else
		my-superuser ln -sf ${__distro_path}/system_files/bin/xsessions/${switch_default_xsession_to} /usr/bin/x-session-manager
	fi
	touch "${installer_phases}/switch_default_xsession"
}

create_uninstaller_file(){
	[ -f "${var_for_distro_uninstaller}" ] && return
	show_m "Creating uninstaller file."
	List_of_installed_packages_="${List_of_apt_2_install_}"
	my-superuser tee "${var_for_distro_uninstaller}" <<- EOF >/dev/null
	grub_image_name=\"${grub_image_name}\"
	List_of_pakages_installed_=\"${List_of_installed_packages_}\"
	switch_default_xsession=\"$(realpath /etc/alternatives/x-session-manager)\"
	EOF
}

switch_to_doas_now(){
	[ -f "${installer_phases}/switch_to_doas_now" ] && return
	if [ "$switch_to_doas" = true ];then
		show_m "switch to doas."
		show_im "Creating new my-superuser symoblic link."
		if [ -n "$_SUPERUSER" ];then
			sudo ln -sf $(which doas) /usr/bin/my-superuser
		else
			ln -sf $(which doas) /usr/bin/my-superuser
		fi
		show_im "Purging sudo."
		purge_sudo
	fi
	touch "${installer_phases}/switch_to_doas_now"
}

pick_clone_rep_commnad(){
	show_m "pick clone repo commnad"
	if command -v git >/dev/null 2>&1;then
		show_im "clone repo commnad: git"
		clone_rep_(){
			getthis="${1-}"
			if [ ! -f "${installer_phases}/${getthis}" ];then
				show_im "clone distro files repo ( ${getthis} )."
				getthis_location="$(find ${dir_2_find_files_in} -type d -name ${getthis} | head -1)"
				
				if [ -z "${getthis_location}" ];then
					getthis_location="${temp_path}"
				else
					getthis_location="$(cd "${getthis_location}" && cd .. && pwd)"
				fi
				
				if [ ! -d "${getthis_location}/${getthis}" ];then 
					git clone --depth=1 "https://github.com/dari862/${getthis}.git" "${getthis_location}/${getthis}"
				else
					show_im "${getthis} Folder does exsist"
				fi
				touch "${installer_phases}/${getthis}"
			else
				getthis_location="$(find ${dir_2_find_files_in} -type d -name ${getthis} | head -1)"
				
				if [ -z "${getthis_location}" ];then
					getthis_location="${temp_path}"
				else
					getthis_location="$(cd "${getthis_location}" && cd .. && pwd)"
				fi
			fi
		}
	elif command -v svn >/dev/null 2>&1;then
		show_im "clone repo commnad: svn"
		clone_rep_(){
			getthis="${1-}"
			if [ ! -f "${installer_phases}/${getthis}" ];then
				show_im "clone distro files repo ( ${getthis} )."
				getthis_location="$(find ${dir_2_find_files_in} -type d -name ${getthis} | head -1)"
				
				if [ -z "${getthis_location}" ];then
					getthis_location="${temp_path}"
				else
					getthis_location="$(cd "${getthis_location}" && cd .. && pwd)"
				fi
				
				if [ ! -d "${getthis_location}/${getthis}" ];then 
					svn clone --depth=1 "https://github.com/dari862/${getthis}.git" "${getthis_location}/${getthis}"
				else
					show_im "${getthis} Folder does exsist"
				fi
				touch "${installer_phases}/${getthis}"
			else
				getthis_location="$(find ${dir_2_find_files_in} -type d -name ${getthis} | head -1)"
				
				if [ -z "${getthis_location}" ];then
					getthis_location="${temp_path}"
				else
					getthis_location="$(cd "${getthis_location}" && cd .. && pwd)"
				fi
			fi
		}
	fi
}

check_and_download_core_script(){
	show_m "check if exsit and download core script."
	
	if [ "$install_drivers" = "true" ];then
		check_and_download_ "disto_Drivers_list" "installer_repo/${distro_name_}" 
		check_and_download_ "disto_Drivers_installer"
		check_and_download_ "disto_specific_Drivers_installer" "installer_repo/${distro_name_}"
	fi
	
	if [ "$install_apps" = "true" ];then
		check_and_download_ "disto_apps_list" "installer_repo/${distro_name_}"
		check_and_download_ "disto_apps_installer"
		check_and_download_ "disto_specific_apps_installer" "installer_repo/${distro_name_}"
	fi
	
	if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
		check_and_download_ "disto_configer"
		
		check_and_download_ "disto_post_install"
		
		################################
		# repo clone
		show_m "clone distro files repo."
		clone_rep_ "my_stuff"
		my_stuff_temp_path="${getthis_location}"
		clone_rep_ "Theme_Stuff"
		theme_temp_path="${getthis_location}"
		clone_rep_ "Distro_Specific"
		Distro_Specific_temp_path="${getthis_location}"
		################################
	fi
}

mv_Distro_Specific(){
	[ -f "${installer_phases}/mv_Distro_Specific" ] && return
	show_im "moving Distro Specific files."
	"${Distro_Specific_temp_path}"/Distro_Specific/installer "${distro_name_}" "${PACKAGER}"
	touch "${installer_phases}/mv_Distro_Specific"
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
create_prompt_to_install_value_file

if [ -n "$_SUPERUSER" ];then
	show_m "creating my-superuser command "
	$_SUPERUSER ln -sf $(which $_SUPERUSER) /usr/bin/my-superuser
	$_SUPERUSER true
	
	[ "$sudo_installed" = "true" ] && show_im "running keep_superuser_refresed" && keep_superuser_refresed &
fi

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

List_of_apt_2_install_=""

if [ "$install_drivers" = "true" ] && [ "$install_apps" = "true" ];then
	show_m "Sourcing drivers and apps files."
elif [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
	show_m "Sourcing $arg_ files."
fi

if [ "$install_drivers" = "true" ];then
	source_this_script "disto_Drivers_list" "Add drivers list from (disto_Drivers_list)"
	source_this_script "disto_Drivers_installer" "Source Install drivers functions from (disto_Drivers_installer)"
	source_this_script "disto_specific_Drivers_installer" "Source Install drivers functions from (disto_specific_Drivers_installer)"
	pre_disto_Drivers_installer || show_em "failed to run pre_disto_Drivers_installer"
fi

if [ "$install_apps" = "true" ];then
	source_this_script "disto_apps_list" "Add apps list from (disto_apps_list)"
	source_this_script "disto_apps_installer" "Source Install apps functions from (disto_apps_installer)"
	source_this_script "disto_specific_apps_installer" "Source Install apps functions from (disto_specific_apps_installer)"
	pre_disto_apps_installer || show_em "failed to run pre_disto_apps_installer"
fi

if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
	show_m "Install list of apps."
	install_packages || show_em "failed to run install_packages"
fi

if [ "$install_drivers" = "true" ];then
	post_disto_Drivers_installer || show_em "failed to run post_disto_Drivers_installer"
	disto_specific_Drivers_installer || show_em "failed to run disto_specific_Drivers_installer"
fi

if [ "$install_apps" = "true" ];then
	post_disto_apps_installer || show_em "failed to run post_disto_apps_installer"
	disto_specific_apps_installer || show_em "failed to run disto_specific_apps_installer"
fi

install_lightdm_now

switch_to_network_manager

_unattended_upgrades_ start

if [ "$install_drivers" = "false" ] && [ "$install_apps" = "true" ];then
	show_m "Done"
	exit
elif [ "$install_drivers" = "true" ] && [ "$install_apps" = "false" ];then
	show_m "Done"
	exit
fi

##################################################################################
##################################################################################
# no internet needed  part
##################################################################################
##################################################################################
show_m "Sourceing disto_configer."
source_this_script "disto_configer" "Configering My Stuff."
mv_Distro_Specific

purge_some_unnecessary_pakages

disable_some_unnecessary_services

clean_up_now

show_m "running Grub scripts."
disable_ipv6_now
update_grub
update_grub_image

run_my_alternatives

show_m "Sourceing disto_post_install."
source_this_script "disto_post_install" "prepare some script"

pre_post_install
${__distro_path}/distro_manager/system_files_creater
create_blob_system_files
end_of_post_install

create_uninstaller_file

switch_default_xsession

switch_to_doas_now

show_m "Done"

if [ "$reboot_now" = "Y" ];then
	${__distro_path}/system_files/bin/my_session_manager --no-confirm reboot
fi
