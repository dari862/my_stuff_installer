#!/bin/sh
install_mode="${1:-install}"
tmp_installer_dir="/tmp/installer_dir"
tmp_installer_file="$tmp_installer_dir/installer.sh"
machine_type_are=""

__USER="$(logname)"
current_user_home="$HOME"

install_drivers=true
install_apps=true

if [ "$install_mode" = "drivers" ];then
	install_drivers=true
	install_apps=false
	install_mode="install"
elif [ "$install_mode" = "apps" ];then
	install_drivers=false
	install_apps=true
	install_mode="install"
fi

if [ "$__USER" = "root" ];then
	non_root_users="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)"
	for u in ${non_root_users};do
		id "$u" | grep -E "sudo|wheel" && user_with_superuser_access="$user_with_superuser_access $u" || :
	done
	if [ -z "$user_with_superuser_access" ];then
		printf "you need user with superuser access." 
		exit 1
	fi
else
	if ! id "$__USER" | grep -Eq "sudo|wheel";then
		printf "you need user with superuser access." 
		exit 1
	fi
fi

current_script_dir="$(realpath $(dirname $0))"
__distro_name="my_stuff"
all_temp_path="/temp_distro_installer_dir"
installer_phases="${all_temp_path}/installer_phases"

__super_command=""

prompt_to_install_value_file="${all_temp_path}/value_of_picked_option_from_prompt_to_install"

auto_run_script="false" # true to enable
source_prompt_to_install_file=false
check_installer_file=""

if [ -d "$HOME/Desktop/$__distro_name" ];then
	distro_temp_path="$HOME/Desktop/$__distro_name"
else
	distro_temp_path="${all_temp_path}/$__distro_name"
fi

if [ -d "$HOME/Desktop/Theme_Stuff" ];then
	theme_temp_path="$HOME/Desktop/Theme_Stuff"
else
	theme_temp_path="${all_temp_path}/Theme_Stuff"
fi

if [ "$install_mode" = "install" ];then
	check_installer_file="${current_script_dir}/core.sh"
	download_url="https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/core.sh"
	if [ -f "$check_installer_file" ];then
		installation_file_path="$check_installer_file"
	else
		installation_file_path="$tmp_installer_file"
	fi
elif [ "$install_mode" = "dev" ];then
	check_installer_file="${current_script_dir}/../For_dev/pre_dev_env"
	download_url="https://raw.githubusercontent.com/dari862/my_stuff_installer/main/For_dev/pre_dev_env"
	if [ -f "$check_installer_file" ];then
		installation_file_path="$check_installer_file"
	else
		installation_file_path="$tmp_installer_file"
	fi
fi

install_sudo=false
user_with_superuser_accese=""
install_hwclock=false

if [ -f /etc/os-release ];then
	. /etc/os-release
	distro_name="$ID"
fi

case ${distro_name} in
	*arch*)
		distro_name="arch"
	;;

	*debian*)
		distro_name="debian"
	;;

	*fedora*)
		distro_name="fedora"
	;;
	
	*opensuse*)
		distro_name="opensuse"
	;;
	
	*ubuntu*)
		distro_name="ubuntu"
	;;
	*)
		printf "failed to detect your distro"
		exit 1
	;;
esac
	
PACKAGEMANAGER='apt-get dnf pacman zypper'
for pgm in ${PACKAGEMANAGER}; do
	if command -v ${pgm} >/dev/null 2>&1;then
		PACKAGER=${pgm}
		break
	fi
done

if [ -z "${PACKAGER}" ];then
	echo "Error: Can't find a supported package manager"
	exit 1
fi

command_exist() {
	if command -v $1 > /dev/null 2>&1;then
		return
	else
		return 1
	fi
}

print_m(){
	massage_is_="${1:-}"
	__COLOR="${2:-32}"
	if [ "$__COLOR" = "RED" ];then
		__COLOR="31"
	elif [ "$__COLOR" = "YELLOW" ];then
		__COLOR="33"
	fi
	printf '%b' "\\033[1;${__COLOR}m${massage_is_}\\033[0m\n"
	if [ "$__COLOR" = "RED" ];then
		exit 1
	fi
}

do_you_want_2_run_this_yes_or_no(){
	massage_is_="${1:-}"
	default_value="${2:-}"
	default_value_massage=""
	
	case "$default_value" in
		[Yy]) default_value_massage="(default: yes) ";;
		[Nn]) default_value_massage="(default: no) " ;;
	esac
	
	while true; do
		print_m "${massage_is_} (yes/no) $default_value_massage"
		stty -icanon -echo time 0 min 1
		answer="$(head -c1)"
		stty icanon echo
		echo
        
        [ -z "$answer" ] && answer="$default_value"
        
		case "$answer" in
			[Yy]) return 0;;
			[Nn]) return 1 ;;
			*) print_m "invalid response only y[yes] or n[No] are allowed.";;
		esac
	done
}

test_internet_(){
	[ -f "${installer_phases}/no_internet_needed" ] && return
	NETWORK_TEST="http://network-test.debian.org/nm"
	url_to_test=debian.org
	test_dns="1.1.1.1"
	install_hwclock=false
	if [ "$url_package" = "curl" ];then
		check_url(){
			curl -SsL "${1-}" 2>/dev/null
		}
		get_full_header(){
			curl -fSi "${1-}" 2>&1
		}
	elif [ "$url_package" = "wget" ];then
		check_url(){
			wget -q -O- "${1-}" >/dev/null 2>&1
		}
		get_full_header(){
			wget -S -O- -q --no-check-certificate "${1-}" 2>&1
		}
	fi
	internet_tester() {
		print_m "Checking internet."
    	if check_url "${NETWORK_TEST}" | grep -q "NetworkManager is online";then
    		print_m "There is an internet connection..."
    		return 0
    	else
    		return 1
    	fi
	}
	
	fix_time_(){
		[ -f "${installer_phases}/fix_time_" ] && return
		print_m "Setting date ,time ,and timezone."
		ipinfo_full_head="$(get_full_header "https://ipinfo.io/")"
		current_date="$(echo "$ipinfo_full_head" | sed -n 's/^ *date: *//p')"
		$__super_command date -s "$current_date" >/dev/null 2>&1
		__timezone="$(echo "$ipinfo_full_head" | grep timezone | awk -F: '{print $2}' | sed 's/"//g;s/,//g;s/^[ \t]*//;s/[ \t]*$//')"
		print_m "applying time and timezone."
		if ! $__super_command timedatectl set-timezone $__timezone >/dev/null 2>&1;then
			$__super_command ln -sf /usr/share/zoneinfo/$__timezone /etc/localtime
			if ! $__super_command hwclock --systohc >/dev/null 2>&1;then
				print_m "failed hwclock to set time zone !" "YELLOW"
				print_m "installing hwclock later !"
				install_hwclock=true
			fi
		fi
		
		print_m "fix time done."
		$__super_command touch "${installer_phases}/fix_time_"
	}	
	wifi_mode_installation(){
		wifi_interface="${1-}"
		
		ip link set "$wifi_interface" up
			
		if command_exist nmcli;then
			nmcli radio wifi on
			while :
			do
				print_m "Scanning for WiFi networks..."
    			networks=$(nmcli -t -f SSID,BSSID,SIGNAL dev wifi list | awk -F: '!seen[$1]++' | head -n 10)
    			if [ -z "$networks" ]; then
        			print_m "No networks found." "YELLOW"
    			else
        			printf "%b\n" "Top 10 Networks found:"
        			echo "$networks" | awk -F: '{printf("%d. SSID: %-25s \n", NR, $1)}'
    			fi
				nmcli --ask dev wifi connect && break
			done
		elif command_exist wpa_supplicant;then
			tmpfile="$(mktemp)"
			while :
			do
				printf "\n These hotspots are available \n"
				iwlist "$wifi_interface" scan | grep ESSID | sed 's/ESSID://g;s/"//g;s/^                    //g'
				echo "ssid: "
				read -r ssid_var
				if iw "$wifi_interface" scan | grep 'SSID' | grep "$ssid_var" >/dev/null;then
					echo "pass: "
					read -r pass_var
				fi
			done
			wpa_passphrase "$ssid_var" "$pass_var" | tee "$tmpfile" > /dev/null
			wpa_supplicant -B -c "$tmpfile" -i "$wifi_interface" &
			unset ssid_var
			unset pass_var
			print_m "you will wait for few sec"
			sleep 10 
			dhclient "$wifi_interface"
			[ -f "$tmpfile" ] && rm "$tmpfile"
			gway=$(ip route | awk '/default/ { print $3 }')
			if check_url "$url_to_test";then
				print_m "Internet connection test passed!"
				return 0
			elif ping -q -c 5 "$test_dns" >/dev/null 2>&1;then
            	print_m "Problem seems to be with your DNS. $_ip" "RED"
            elif ! ping -q -c 5 "$gway" >/dev/null 2>&1;then
            	print_m "Can not reach your gateway. $_ip" "RED"
        	else
            	print_m "Somthing wrong with your network" "RED"
    		fi
			fix_time_
		fi
	}
	print_m "Testing internet connection."
	
	if ! internet_tester ;then
		wifi_interface=""
		if check_url "$url_to_test";then
			print_m "Internet connection test passed!"
			return 0
		else
			print_m "Internet connection test failed!" "YELLOW"
			_intface="$(ip route | awk '/default/ { print $5 }')"
			if [ -z "$_intface" ];then
				for intf in /sys/class/net/*; do
					intf_name="$(basename $intf)"
					if [ "$intf_name" != "lo" ] || echo "$intf_name" | grep "^w" ;then
    					ip link set dev $intf_name up
    				fi
				done
				_intface="$(ip route | awk '/default/ { print $5 }')"
				if [ -z "$_intface" ];then
            		print_m "Problem seems to be with your interface. not connected" "RED"
            	fi
			fi
			_ip="$(ip address show dev $_intface | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/')"
			if echo $_ip | grep -qE '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)';then
				if ls /sys/class/net/w* 2>/dev/null;then
					wifi_interface="$(ip link | awk -F: '$0 !~ "^[^0-9]"{print $2;getline}' | awk '/w/{ print $0 }')"
					if [ -z "$wifi_interface" ];then
            			print_m "Problem seems to be with your router. $_ip" "RED"
            		else
            			wifi_mode_installation "$wifi_interface"
            		fi
            	else
            		print_m "Problem seems to be with your router. $_ip" "YELLOW"
            	fi
        	else
            	print_m "Problem seems to be with your interface or there is no DHCP server. $_intface ip is $_ip" "RED"
			fi
			
			gway=$(ip route | awk '/default/ { print $3 }')
			
			if ! ping -q -c 5 "$test_dns" >/dev/null 2>&1;then
            	print_m "Problem seems to be with your gateway. $_ip" "RED"
        	elif ! ping -q -c 5 "$gway" >/dev/null 2>&1;then
            	print_m "Can not reach your gateway. $_ip" "RED"
    		fi
	
    		fix_time_
    		
    		if check_url "$url_to_test";then
				print_m "Internet connection test passed!"
				return 0
			elif ping -q -c 5 "$test_dns" >/dev/null 2>&1;then
            	print_m "Problem seems to be with your DNS. $_ip" "RED"
        	else
            	print_m "Somthing wrong with your network" "RED"
    		fi
    	fi  
	fi
	fix_time_
}

prompt_to_ask_to_what_to_install(){
	install_wayland=false
	install_X11=true
	switch_default_xsession_to="openbox"
	switch_to_doas=false
	run_purge_some_unnecessary_pakages="Y"
	run_disable_some_unnecessary_services="Y"
	disable_ipv6_stack="Y"
	disable_ipv6="Y"
	run_update_grub_image="Y"
	autoclean_and_autoremove="Y"
	install_zsh_now=""
	install_extra_now=""
	install_qt5ct=""
	install_files_manager=true
	thunar_files_manager=false
	pcmanfm_files_manager=false
	
	if [ "$install_X11" = true ];then
		install_jgmenu=""
		install_polybar=polybar
		install_bspwm=true
		install_dwm=false
	else
		install_jgmenu=""
		install_polybar=""
		install_bspwm=false
		install_dwm=false
	fi
	
	enable_GPU_installer=true
	reboot_now="Y"
	if [ "${source_prompt_to_install_file}" = "true" ];then
		return
	fi

	print_m "what do you want to install."
	
	if [ "$auto_run_script" != "true" ];then
		if do_you_want_2_run_this_yes_or_no 'Autorun installation?' 'Y';then
			return
		fi
		
		if do_you_want_2_run_this_yes_or_no 'install GPU Drivers?' 'Y';then
			enable_GPU_installer=true
			install_cuda_=false
			install_kernel_open_dkms_=false
			install_akmod_nvidia=false
			if do_you_want_2_run_this_yes_or_no 'do you want to add Cuda Support?' 'Y';then
				install_cuda_=true
			elif do_you_want_2_run_this_yes_or_no 'do you want to install opensource nvidia-kernel?' 'Y';then
				install_kernel_open_dkms_=true
			elif do_you_want_2_run_this_yes_or_no 'do you want to add akmod Support?' 'Y';then
				install_akmod_nvidia=true
			fi
		else
			enable_GPU_installer=false
		fi
		
		if do_you_want_2_run_this_yes_or_no 'Do you want to install wayland packages?' 'Y';then
			install_wayland=true
			enable_GPU_installer=true
			if do_you_want_2_run_this_yes_or_no 'Do you want to install X11 packages?' 'Y';then
				install_X11=true
			else
				install_X11=false
			fi
		else
			install_wayland=false
		fi

		if [ "$switch_to_doas" = false ] && [ "$only_doas_installed" = "false" ];then
			if do_you_want_2_run_this_yes_or_no 'Switch to doas?' 'Y';then
				switch_to_doas=true
			fi
		fi

		if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
			if do_you_want_2_run_this_yes_or_no 'do you want to purge some unnecessary pakages?' 'Y';then
				run_purge_some_unnecessary_pakages="Y"
			else
				run_purge_some_unnecessary_pakages=""
			fi
			
			if do_you_want_2_run_this_yes_or_no 'Do you want to disable some unnecessary services?' 'Y';then
				run_disable_some_unnecessary_services="Y"
			else
				run_disable_some_unnecessary_services=""
			fi
			
			if do_you_want_2_run_this_yes_or_no 'update grub image?' 'Y';then
				run_update_grub_image="Y"
			else
				run_update_grub_image=""
			fi
			
			if do_you_want_2_run_this_yes_or_no 'disable ipv6 stack?' 'Y';then
				disable_ipv6_stack="Y"
			else
				if do_you_want_2_run_this_yes_or_no 'disable ipv6 only?' 'Y';then
					disable_ipv6="Y"
				else
					disable_ipv6=""
				fi
				disable_ipv6_stack=""
			fi
			
			if do_you_want_2_run_this_yes_or_no 'run autoclean and autoremove?' 'Y';then
				autoclean_and_autoremove="Y"
			else
				autoclean_and_autoremove=""
			fi
		fi
		
		if [ "$install_apps" = "true" ];then
			if ! command_exist zsh;then
				if do_you_want_2_run_this_yes_or_no 'Do you want to install zsh?' 'Y';then
					if do_you_want_2_run_this_yes_or_no 'Do you want to set zsh as default shell?' 'Y';then
						install_zsh_now=zsh_default
					else
						install_zsh_now=zsh
					fi
				else
					install_zsh_now=""
				fi
			else
				if do_you_want_2_run_this_yes_or_no 'Do you want to set zsh as default shell?' 'Y';then
					install_zsh_now=zsh_default
				else
					install_zsh_now=zsh
				fi
			fi
			
			if [ "$install_files_manager" = false ];then
				if do_you_want_2_run_this_yes_or_no 'Do you want to File Manager?' 'Y';then
					install_files_manager=true
				fi
				
				if [ "$thunar_files_manager" = false ] && [ "$install_files_manager" = true ] ;then
					if ! command_exist thunar;then
						if do_you_want_2_run_this_yes_or_no 'Do you want to switch from pcmanfm to thunar?' 'Y';then
							thunar_files_manager=true
						else
							pcmanfm_files_manager=true
						fi
					else
						thunar_files_manager=true
					fi
				fi
			fi
		
			if ! command_exist qt5ct;then
				if do_you_want_2_run_this_yes_or_no 'Do you want to install qt5ct?' 'Y';then
					install_qt5ct=qt5ct
				else
					install_qt5ct=""
				fi
			fi
			
			if [ "$install_X11" = "true" ];then
				if ! command_exist jgmenu;then
					if do_you_want_2_run_this_yes_or_no 'Do you want to install jgmenu?' 'Y';then
						install_jgmenu=jgmenu
					else
						install_jgmenu=""
					fi
				fi
				
				if ! command_exist polybar;then
					if do_you_want_2_run_this_yes_or_no 'Do you want to install polybar?' 'Y';then
						install_polybar=polybar
					else
						install_polybar=""
					fi
				fi
							
				if ! command_exist bspwm;then
					if do_you_want_2_run_this_yes_or_no 'Do you want to install bspwm?' 'Y';then
						install_bspwm=true
						if do_you_want_2_run_this_yes_or_no 'Do you want to switch to bspwm session?' 'Y';then
							switch_default_xsession_to="bspwm"
						fi
					else
						install_bspwm=false
					fi
				fi
				if ! command_exist dwm && [ "$ask_2_install_dwm" = true ];then
					if do_you_want_2_run_this_yes_or_no 'Do you want to install dwm?' 'Y';then
						install_dwm=true
						if do_you_want_2_run_this_yes_or_no 'Do you want to switch to dwm session?' 'Y';then
							switch_default_xsession_to="dwm"
						fi
					else
						install_dwm=false
					fi
				fi
			fi
			
			if do_you_want_2_run_this_yes_or_no 'Do you want to install extra apps?' 'Y';then
				install_extra_now=extra
			else
				install_extra_now=""
			fi
		fi
		
		if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
			if do_you_want_2_run_this_yes_or_no 'reboot?' 'Y';then
				reboot_now="Y"
			else
				reboot_now=""
			fi
		fi
	fi
	
	if [ "$switch_to_doas" = false ] && [ "$doas_installed" = false ] && [ "$sudo_installed" = false ];then
		switch_to_doas=true
	fi
	
	if [ "$doas_installed" = true ] && [ "$sudo_installed" = false ];then
		only_doas_installed=true
	else
		only_doas_installed=false
	fi
}

create_prompt_to_install_value_file(){
	print_m "creating: ${prompt_to_install_value_file}"
	$__super_command mkdir -p "${all_temp_path}"
	$__super_command chmod 755 "${all_temp_path}"
	$__super_command tee "${prompt_to_install_value_file}" <<- EOF >/dev/null
		machine_type_are="$machine_type_are"
		__timezone="$__timezone"
		install_hwclock="${install_hwclock}"
		installer_phases="${installer_phases}"
		install_drivers="${install_drivers}"
		install_apps="${install_apps}"
		PACKAGER="${PACKAGER}"
		distro_name="${distro_name}"
		__distro_name="$__distro_name"
		export all_temp_path="${all_temp_path}"
		distro_temp_path="$distro_temp_path"
		theme_temp_path="$theme_temp_path"
		url_package="$url_package"
		doas_installed="$doas_installed"
		sudo_installed="$sudo_installed"
		only_doas_installed="$only_doas_installed"
		enable_GPU_installer=${enable_GPU_installer}
		install_cuda_=${install_cuda_}
		install_kernel_open_dkms_=${install_kernel_open_dkms_}
		install_akmod_nvidia=${install_akmod_nvidia}
		install_wayland="${install_wayland}"
		install_X11="${install_X11}"
		switch_to_doas="${switch_to_doas}"
		run_purge_some_unnecessary_pakages="${run_purge_some_unnecessary_pakages}"
		run_disable_some_unnecessary_services="${run_disable_some_unnecessary_services}"
		disable_ipv6="${disable_ipv6}"
		run_update_grub_image="${run_update_grub_image}"
		disable_ipv6_stack="${disable_ipv6_stack}"
		autoclean_and_autoremove="${autoclean_and_autoremove}"
		install_zsh_now="${install_zsh_now}"
		install_files_manager="$install_files_manager"
		thunar_files_manager="$thunar_files_manager"
		pcmanfm_files_manager="$pcmanfm_files_manager"
		install_extra_now="${install_extra_now}"
		install_polybar="${install_polybar}"
		install_qt5ct="${install_qt5ct}"
		install_jgmenu="${install_jgmenu}"
		install_bspwm=${install_bspwm}
		install_dwm=${install_dwm}
		switch_default_xsession_to="${switch_default_xsession_to}"
		reboot_now="${reboot_now}"
	EOF
}

if command_exist curl;then
	url_package="curl"
	download_file(){
		print_m "downloading ${1-} to ${2-} using ${url_package} ."
		curl -SsL --progress-bar "${1-}" -o "${2-}" 2>/dev/null
	}
elif command_exist wget;then
	url_package="wget"
	download_file(){
		print_m "downloading ${1-} to ${2-} using ${url_package} ."
		wget -q --no-check-certificate --progress=bar "${1-}" -O "${2-}" 2>/dev/null
	}
else
	print_m "Neither curl nor wget is availabl, please install curl or wget.."
	exit 1
fi

if command_exist doas;then
	doas_installed=true
	__super_command="doas"
else
	doas_installed=false
fi
	
if command_exist sudo;then
	sudo_installed=true
	__super_command="sudo"
else
	sudo_installed=false
fi

if [ "$install_mode" = "install" ];then
	if [ -f "${prompt_to_install_value_file}" ];then
		print_m "file exist : ${prompt_to_install_value_file} form previce run."
		if do_you_want_2_run_this_yes_or_no 'Do you want source it?' 'Y';then
			source_prompt_to_install_file=true
		fi
	else
		prompt_to_ask_to_what_to_install
		create_prompt_to_install_value_file
	fi
fi

$__super_command mkdir -p "${installer_phases}"

test_internet_

if [ ! -f "$installation_file_path" ];then
	mkdir -p "$tmp_installer_dir"
	chmod 750 "$tmp_installer_dir"

	download_file "$download_url" "$tmp_installer_file"
fi

chmod +x "$installation_file_path"

if [ "$install_mode" = "install" ];then
	if $__super_command "$installation_file_path" "$prompt_to_install_value_file" "$__USER" "$current_user_home";then
		if [ -f "$tmp_installer_file" ];then
			rm -rdf "$tmp_installer_dir"
		fi
	fi
elif [ "$install_mode" = "dev" ];then
	$__super_command "$installation_file_path"
fi
