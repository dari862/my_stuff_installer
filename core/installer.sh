#!/bin/sh
set -e
################################################################################################################################
# Var
################################################################################################################################
install_wayland=false
install_X11=true
__distro_path="/usr/share/my_stuff"
auto_run_script="false" # true to enable
temp_path="/tmp/temp_distro_installer_dir"
installer_phases="${temp_path}/installer_phases"
switch_default_xsession=""
switch_default_xsession_to="openbox"
switch_to_doas=false
NETWORK_TEST="http://network-test.debian.org/nm"
url_to_test=debian.org
test_dns="1.1.1.1"

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

ask_2_install_dwm=false

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

doas_installed=false
sudo_installed=false

PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:$PATH
never_remove_dir_path="${__distro_path}/never_remove"
var_for_distro_uninstaller="${never_remove_dir_path}/var_for_distro_uninstaller"

list_of_apps_file_path="${temp_path}/list_of_apps"
list_of_installed_apps_file_path="${temp_path}/list_of_installed_apps"

# distro
if [ -f /etc/os-release ];then
	# freedesktop.org and systemd
	. /etc/os-release
	version_="$(echo "${VERSION_ID}" | tr -d '.')"
	distro_name="$ID"
	distro_desc="$PRETTY_NAME"
	distro_name_and_ver_="$ID$version_"
	distro_name_and_ver_2="${ID}_${version_}"
	version_codename="${VERSION_CODENAME}"
	VERSION_ID="$VERSION_ID"
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
fi
		
only_doas_installed=false

if [ -d "$HOME/Desktop" ];then
	dir_2_find_files_in="$HOME/Desktop ${temp_path}"
else
	dir_2_find_files_in="${temp_path}"
fi

failed_2_install_ufw=false

machine_type_are=""
################################################################################################################################
# Function
################################################################################################################################

command_exist() {
  command -v $1 > /dev/null 2>&1
}

show_m(){
	message="${1-}"
	printf '%b' "\n==[ \\033[1;32m${message}\\033[0m ]==\n"
}

show_wm(){
	message="${1-}"
	printf '%b' "\\033[1;33m[!] \\033[0m${message}\n"
	printf '%s\n' "${message}" >> $HOME/warnings_from_installer
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
	printf '%b' "\\033[1;36m[**] \\033[0m${message}\n"
}

show_filed_2_add_pakage_m(){
	message="${1-}"
	printf '%b' "\\033[1;36m[**] \\033[0m${message}\n"
	printf '%s\n' "${message}" >> $HOME/filed_2_add_pakages
}

do_you_want_2_run_this_yes_or_no()
{
	massage_is_="${1:-}"
	default_value="${2:-}"
	default_value_massage=""
	
	case "$default_value" in
		[Yy]) default_value_massage="(default: yes) ";;
		[Nn]) default_value_massage="(default: no) " ;;
	esac
	
	while true; do
		printf "${massage_is_} (yes/no) $default_value_massage"
		stty -icanon -echo time 0 min 1
		answer="$(head -c1)"
		stty icanon echo
		echo
        
        [ -z "$answer" ] && answer="$default_value"
        
		case "$answer" in
			[Yy]) return 0;;
			[Nn]) return 1 ;;
			*) show_im "invalid response only y[yes] or n[No] are allowed.";;
		esac
	done
}

pre_script(){
	show_m "Loading Script ....."
	
	if [ -f "${installer_phases}/Done" ];then
		show_m "my_stuff installed successfully ....."
		if do_you_want_2_run_this_yes_or_no 'reboot?' 'Y';then
			reboot_now="Y"
		else
			reboot_now=""
		fi
		__Done
	fi
	create_dir_and_source_stuff
	check_if_user_has_root_access
}

create_dir_and_source_stuff(){
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
		if do_you_want_2_run_this_yes_or_no 'Do you want source it?' 'Y';then
			. "${prompt_to_install_value_file}"
			source_prompt_to_install_file=true
		fi
	fi
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
    	
    	if command_exist doas;then
    		_SUPERUSER="doas"
    		doas_installed=true
    		echo "_SUPERUSER=\"$_SUPERUSER\"" >> "${save_value_file}"
    		echo "doas_installed=\"$doas_installed\"" >> "${save_value_file}"
		fi
		
		if command_exist sudo;then
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
    	if command_exist doas;then
    		show_im "doas command exist."
    		doas_installed=true
    		echo "doas_installed=\"$doas_installed\"" >> "${save_value_file}"
		fi
		
		if command_exist sudo;then
    		sudo_installed=true
    		echo "sudo_installed=\"$sudo_installed\"" >> "${save_value_file}"
		fi
		_SUPERUSER=""
		echo "_SUPERUSER=\"$_SUPERUSER\"" >> "${save_value_file}"
    	show_im "value of _SUPERUSER are $_SUPERUSER"
    fi
    touch "${installer_phases}/check_if_user_has_root_access"
}

test_internet_(){
	[ -f "${installer_phases}/no_internet_needed" ] && return
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

prompt_to_ask_to_what_to_install(){
	if [ "${source_prompt_to_install_file}" = "true" ];then
		return
	fi

	show_m "prompt for what do you want to install."
	
	if [ "$auto_run_script" != "true" ];then
		if do_you_want_2_run_this_yes_or_no 'Autorun installation?' 'Y';then
			return
		fi
		
		if do_you_want_2_run_this_yes_or_no 'Do you want to install wayland packages?' 'Y';then
			install_wayland=true
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
}

create_prompt_to_install_value_file(){
	show_im "creating: ${prompt_to_install_value_file}"
	tee "${prompt_to_install_value_file}" <<- EOF >/dev/null
		install_wayland="${install_wayland}"
		install_X11="${install_X11}"
		switch_to_doas="${switch_to_doas}"
		enable_contrib="${enable_contrib}"
		enable_nonfree_firmware="${enable_nonfree_firmware}"
		enable_nonfree="${enable_nonfree}"
		run_purge_some_unnecessary_pakages="${run_purge_some_unnecessary_pakages}"
		run_disable_some_unnecessary_services="${run_disable_some_unnecessary_services}"
		disable_ipv6="${disable_ipv6}"
		run_update_grub_image="${run_update_grub_image}"
		disable_ipv6_stack="${disable_ipv6_stack}"
		autoclean_and_autoremove="${autoclean_and_autoremove}"
		install_zsh_now="${install_zsh_now}"
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

check_and_download_()
{
	check_this_file_="${1:-}"
	filename="$(basename "${check_this_file_}")"
	show_im "running check_and_download_ function on ($check_this_file_)"
	
	path_2_file="my_stuff_installer/core/${check_this_file_}"
	
	if [ -f "$HOME/Desktop/${path_2_file}" ];then
		mv "$HOME/Desktop/${path_2_file}" "${temp_path}" || show_em "failed to move ($HOME/Desktop/${path_2_file}) to (${temp_path})"
		show_im "${filename} already exist."
	elif [ -f "${temp_path}/${filename}" ];then
		show_im "${filename} already exist."
	else
		show_im "Download $check_this_file_ file from www.github.com/dari862/my_stuff_installer ."
		if download_file "" "https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/${check_this_file_}" "${temp_path}/${filename}" ;then
			chmod +x "${temp_path}/${filename}"
		else
			show_em "Error: Failed to download ${filename} from https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/${check_this_file_}"
		fi
	fi
}

kill_package_(){
	$_SUPERUSER ps aux | grep "${1}" | awk '{print $2}' | xargs $_SUPERUSER kill -9 >/dev/null 2>&1 || :
}

detect_file_downloader_and_url_checker(){
	[ -f "${installer_phases}/pick_file_downloader_and_url_checker" ] && return
	show_m "picking url command"
	if command_exist curl;then
		url_package="curl"
	elif command_exist wget;then
		url_package="wget"
	else
		show_em "Neither curl nor wget is availabl, please install curl or wget.."
	fi
	echo "url_package=\"$url_package\"" >> "${save_value_file}"
	touch "${installer_phases}/pick_file_downloader_and_url_checker"
}

pick_file_downloader_and_url_checker(){
	show_im "picked url command: $url_package "
	
	if [ "$url_package" = "curl" ];then
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
		get_full_header(){
			curl -fSi "${1-}" 2>&1
		}
	elif [ "$url_package" = "wget" ];then
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
		get_full_header(){
			wget -S -O- -q --no-check-certificate "${1-}" 2>&1
		}
	fi
}

internet_tester() {
	show_im "Checking internet."
    if check_url "${NETWORK_TEST}" | grep -q "NetworkManager is online";then
    	show_im "There is an internet connection..."
    	return 0
    else
    	return 1
    fi
}

fix_time_(){
	[ -f "${installer_phases}/fix_time_" ] && return
	show_m "Setting date ,time ,and timezone."
	ipinfo_full_head="$(get_full_header "https://ipinfo.io/")"
	current_date="$(echo "$ipinfo_full_head" | sed -n 's/^ *date: *//p')"
	$_SUPERUSER date -s "$current_date" >/dev/null 2>&1
	__timezone="$(echo "$ipinfo_full_head" | grep timezone | awk -F: '{print $2}' | sed 's/"//g;s/,//g;s/^[ \t]*//;s/[ \t]*$//')"
	show_im "applying time and timezone."
	if ! $_SUPERUSER timedatectl set-timezone $__timezone >/dev/null 2>&1;then
		$_SUPERUSER ln -sf /usr/share/zoneinfo/$__timezone /etc/localtime
		if ! $_SUPERUSER hwclock --systohc >/dev/null 2>&1;then
			show_em "failed to set time zone !"
		fi
	fi
	echo "__timezone=\"$__timezone\"" >> "${save_value_file}"
	show_im "fix time done."
	touch "${installer_phases}/fix_time_"
}

wifi_mode_installation(){
	wifi_interface="${1-}"
	
	ip link set "$wifi_interface" up
		
	if command_exist nmcli;then
		nmcli radio wifi on
		while :
		do
			show_im "Scanning for WiFi networks..."
    		networks=$(nmcli -t -f SSID,BSSID,SIGNAL dev wifi list | awk -F: '!seen[$1]++' | head -n 10)
    		if [ -z "$networks" ]; then
        		show_wm "No networks found."
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
	install_packages "git"
	touch "${installer_phases}/must_install_apps"
}

clean_up_now(){
	[ -f "${installer_phases}/clean_up_now" ] && return
	show_m "clean_up_now"
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
				$_SUPERUSER sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="ipv6.disable=1"/' /etc/default/grub
				need_to_update_grub=true
			else
				$_SUPERUSER sed -i 's/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 ipv6.disable=1\"/' /etc/default/grub
				need_to_update_grub=true
			fi
		fi
		if ! grep 'GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | grep -q 'ipv6.disable=1';then
			if grep -q 'GRUB_CMDLINE_LINUX_DEFAULT=""' /etc/default/grub;then
				$_SUPERUSER sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1"/' /etc/default/grub
				need_to_update_grub=true
			else
				$_SUPERUSER sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ipv6.disable=1\"/' /etc/default/grub
				need_to_update_grub=true
			fi
		fi
	fi
	
	if [ "$disable_ipv6" = "Y" ];then
		disable_ipv6_conf="/etc/sysctl.d/90-disable_ipv6.conf"
		if [ ! -f "${disable_ipv6_conf}" ];then
			show_im "Disabling IPv6."
			$_SUPERUSER tee "${disable_ipv6_conf}" <<- EOF >/dev/null
			net.ipv6.conf.all.disable_ipv6 = 1
			net.ipv6.conf.default.disable_ipv6 = 1
			net.ipv6.conf.lo.disable_ipv6 = 1
			EOF
			$_SUPERUSER sysctl -p "${disable_ipv6_conf}"
		fi
	fi
	touch "${installer_phases}/disable_ipv6_now"
}

update_grub(){
	[ -f "${installer_phases}/update_grub" ] && return
	if [ "$need_to_update_grub" = "true" ];then
		show_im "update grub"
		$_SUPERUSER sync
		if command_exist update-grub; then
			$_SUPERUSER update-grub
		elif command_exist grub-mkconfig; then
			$_SUPERUSER grub-mkconfig -o /boot/grub/grub.cfg
		elif command_exist zypper || command_exist transactional-update; then
			$_SUPERUSER grub2-mkconfig -o /boot/grub2/grub.cfg
		elif command_exist dnf || command_exist rpm-ostree; then
			if [ -f "/boot/grub2/grub.cfg" ]; then
				$_SUPERUSER grub2-mkconfig -o /boot/grub2/grub.cfg
			elif [ -f "/boot/efi/EFI/fedora/grub.cfg" ]; then
				$_SUPERUSER grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
			fi
		fi
	fi
	touch "${installer_phases}/update_grub"
}

update_grub_image(){
	[ -f "${installer_phases}/update_grub_image" ] && return
	if [ "$run_update_grub_image" = "Y" ];then
		show_im "update image."
		$_SUPERUSER "${__distro_path}/bin/not_add_2_path/grub2_themes/install.sh"
	fi
	touch "${installer_phases}/update_grub_image"
}

source_this_script(){
	file_to_source_and_check="${1-}"
	message_to_show="${2-}"
	run_check="${3-}"
	[ ! -f "${temp_path}"/"${file_to_source_and_check}" ] && show_em "can not source this file ( ${temp_path}/${file_to_source_and_check} ). does not exist."
	[ "$run_check" = "run_check" ] && [ -f "${installer_phases}/${file_to_source_and_check}" ] && return
	show_im "${message_to_show}"
	. "${temp_path}"/"${file_to_source_and_check}"
}

keep_superuser_refresed(){
	[ "$sudo_installed" = "false" ] && return
	show_im "running keep_superuser_refresed"
	while true;do
		sudo true
		sleep 30
	done
}

install_doas_tools()
{
	[ -f "${installer_phases}/install_doas_tools" ] && return
	if [ "$switch_to_doas" = true ] && [ "$only_doas_installed" = "false" ];then
		show_m "install superuser tools."
		if ! grep "sudo" /etc/group;then
			$_SUPERUSER groupadd sudo
		fi
		show_im "Installing doas"
		install_this_packages_for_doas="doas expect"
		install_packages "$install_this_packages_for_doas"
		$_SUPERUSER adduser "$USER" sudo || :
		$_SUPERUSER tee -a /etc/bash.bashrc <<- EOF >/dev/null 2>&1
		if [ -x /usr/bin/doas ];then
			complete -F _command doas
		fi
		EOF
	fi
	touch "${installer_phases}/install_doas_tools"
}

set_package_manager(){
	show_m "running set_package_manager function"
	show_im "Using ${PACKAGER}"
	if [ ! -f "${installer_phases}/set_package_manager" ];then
		if [ ! -f "${temp_path}/PACKAGE_MANAGER" ];then
			check_and_download_ "installer_repo/${PACKAGER}"
			mv "${temp_path}/${PACKAGER}" "${temp_path}/PACKAGE_MANAGER"
		fi
		if ! . "${temp_path}/PACKAGE_MANAGER";then
			show_em "Error: Failed to source PACKAGE_MANAGER from ${temp_path}"
		fi
		
		create_package_list
		
		if package_installed systemd ;then
			init_system_are="systemd"
		elif package_installed openrc;then
			init_system_are="openrc"
		else
			show_em "Error: variable init_system_are are empty"
		fi
		
		check_and_download_ "disto_init_manager"
		if ! . "${temp_path}/disto_init_manager";then
			show_em "Error: Failed to source disto_init_manager from ${temp_path}"
		fi
		
		show_im "running pre_package_manager_"
		pre_package_manager_
		echo "PACKAGER=\"${PACKAGER}\"" >> "${save_value_file}"
		echo "init_system_are=\"${init_system_are}\"" >> "${save_value_file}"
		touch "${installer_phases}/set_package_manager"
	else
		if ! . "${temp_path}/PACKAGE_MANAGER";then
			show_em "Error: Failed to source PACKAGE_MANAGER from ${temp_path}"
		fi
		if ! . "${temp_path}/disto_init_manager";then
			show_em "Error: Failed to source disto_init_manager from ${temp_path}"
		fi
	fi
}

switch_default_xsession(){
	[ -f "${installer_phases}/switch_default_xsession" ] && return
	show_m "switching default xsession to my stuff $switch_default_xsession_to."
	if command_exist update-alternatives;then
		$_SUPERUSER update-alternatives --install /usr/bin/x-session-manager x-session-manager ${__distro_path}/system_files/bin/xsessions/${switch_default_xsession_to} 60
		switch_default_xsession="$(realpath /etc/alternatives/x-session-manager)"
	else
		$_SUPERUSER ln -sf ${__distro_path}/system_files/bin/xsessions/${switch_default_xsession_to} /usr/bin/x-session-manager
	fi
	touch "${installer_phases}/switch_default_xsession"
}

create_uninstaller_file(){
	[ -f "${var_for_distro_uninstaller}" ] && return
	show_m "Creating uninstaller file."
	List_of_installed_packages_="${List_of_apt_2_install_}"
	$_SUPERUSER mkdir -p "${never_remove_dir_path}"
	$_SUPERUSER tee "${var_for_distro_uninstaller}" <<- EOF >/dev/null
	grub_image_name=\"${grub_image_name}\"
	List_of_pakages_installed_=\"${List_of_installed_packages_}\"
	switch_default_xsession=\"$switch_default_xsession\"
	EOF
}

pick_clone_rep_commnad(){
	[ -f "${installer_phases}/pick_clone_rep_commnad" ] && return
	show_m "pick clone repo commnad"
	if command_exist git;then
		show_im "clone repo commnad: git"
		repo_commnad="git clone --depth=1"
	elif command_exist svn;then
		show_im "clone repo commnad: svn"
		repo_commnad="svn clone --depth=1"
	fi
	echo "repo_commnad=\"${repo_commnad}\"" >> "${save_value_file}"
	touch "${installer_phases}/pick_clone_rep_commnad"
}

print_getthis_location(){
	check_this_location="${1-}"
	if [ -d "$HOME/Desktop/${check_this_location}" ];then
		printf '%s' "$HOME/Desktop"
	else
		printf '%s' "${temp_path}"
	fi
}

clone_rep_(){
	getthis="${1-}"
	getthis_location="$(print_getthis_location "${getthis}")"

	if [ ! -f "${installer_phases}/${getthis}" ];then
		show_im "clone distro files repo ( ${getthis} )."
		if [ ! -d "${getthis_location}/${getthis}" ];then 
			$repo_commnad "https://github.com/dari862/${getthis}.git" "${getthis_location}/${getthis}"
		else
			show_im "${getthis} Folder does exsist"
		fi
		touch "${installer_phases}/${getthis}"	
	fi
}

check_and_download_core_script(){
	show_m "check if exsit and download core script."
	
	if [ "$install_drivers" = "true" ];then
		check_and_download_ "installer_repo/${distro_name}/disto_Drivers_list" 
		check_and_download_ "disto_Drivers_installer"
		check_and_download_ "installer_repo/${distro_name}/disto_specific_Drivers_installer"
	fi
	
	if [ "$install_apps" = "true" ];then
		check_and_download_ "installer_repo/${distro_name}/disto_apps_list"
		check_and_download_ "disto_apps_installer"
		check_and_download_ "installer_repo/${distro_name}/disto_specific_apps_installer"
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
		################################
	fi
	check_and_download_ "installer_repo/${distro_name}/disto_specific_extra"
}

source_and_set_machine_type(){
	[ -f "${installer_phases}/check_machine_type" ] && return
	
	if [ -f "${__distro_path}/lib/common/machine_type" ];then
		. "${__distro_path}/lib/common/machine_type"
	elif [ -f "${my_stuff_temp_path}/my_stuff/lib/common/machine_type" ];then
		. "${my_stuff_temp_path}/my_stuff/lib/common/machine_type"
	else
		show_em "failed to source machine_type"
	fi
	
	show_m "check machine type"
	
	machine_type_are="$(check_machine_type)"
	
	if [ "${machine_type_are}" = "laptop" ];then
		show_im "this is laptop"
	elif [ -n "${machine_type_are}" ];then
		show_im "this is not laptop"
	else
		show_em "failed to set machine_type var"
	fi
	has_bluetooth=false
	
	if $_SUPERUSER dmesg | grep -qi bluetooth || $_SUPERUSER lsusb 2>/dev/null | grep -qi bluetooth || [ -d "/sys/class/bluetooth" ];then
		show_im "has bluetooth"
		has_bluetooth=true
	fi
	
	echo "machine_type_are=$machine_type_are" >> "${save_value_file}"
	echo "has_bluetooth=$has_bluetooth" >> "${save_value_file}"
	touch "${installer_phases}/check_machine_type"
}

create_new_os_release_file(){
	[ -f "${__distro_path}/os-release" ] && return
	$_SUPERUSER tee "${__distro_path}/os-release" <<- EOF > /dev/null 2>&1
	version_="$version_"
	distro_name="$distro_name"
	distro_desc="$distro_desc"
	distro_name_and_ver_="$distro_name_and_ver_"
	distro_name_and_ver_2="$distro_name_and_ver_2"
	version_codename="${version_codename}"
	VERSION_ID="$VERSION_ID"
	EOF
}

run_my_alternatives(){
	[ -f "${installer_phases}/my_alternatives" ] && return
	show_m "update alternatives apps"
	${__distro_path}/bin/bin/my-alternatives --install
	touch "${installer_phases}/my_alternatives"
}

switch_to_doas_now(){
	[ -f "${installer_phases}/switch_to_doas_now" ] && return
	if [ "$switch_to_doas" = true ];then
		if command_exist sudo;then
			show_m "pre Purge sudo."
			export SUDO_FORCE_REMOVE=yes
			
			show_im "changing root password"	
			PASSWORD=$(tr -dc 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' < /dev/urandom | head -c 30 | base64)
			echo "root:${PASSWORD}" | $_SUPERUSER chpasswd || show_em "failed to change root password"
			
			if [ -z "${_SUPERUSER}" ];then
				show_im "Purging sudo."
				remove_packages "sudo" || show_em "failed to purge sudo"
				show_im "install fake sudo package and disable root user."
				dpkg -i "${__distro_path}/lib/fake_empty_apps/sudo.deb" || show_em "failed to install fake sudo."
				passwd -l root || show_em "failed to disable root user."
			else
				show_im "Purging sudo and install fake sudo package and disable root user."
				echo "${PASSWORD}"
				sudo su -s /bin/sh -c "
					show_em(){
						massage='${1:-}'
						printf '%b' \"\\033[1;31m[-] ${massage}\\033[0m\n\"
					}
					$__remove_package sudo || show_em 'failed to purge sudo'
					dpkg -i ${__distro_path}/lib/fake_empty_apps/sudo.deb || show_em 'failed to install fake sudo.'
					passwd -l root || show_em 'failed to disable root user.'
				"
			fi
			unset PASSWORD
			PASSWORD="1234"
		fi
	fi
	touch "${installer_phases}/switch_to_doas_now"
}

__Done(){
	show_m "Done"
	if [ "$failed_2_install_ufw" = true ];then
		echo "Press any key to reboot."
		stty -icanon -echo time 0 min 1
		head -c1 >/dev/null
		stty icanon echo
	fi
	
	if [ "$reboot_now" = "Y" ];then
		${__distro_path}/system_files/bin/my_session_manager_cli reboot
	fi
	
	touch "${installer_phases}/Done"
	exit
}

post_switch_to_network_manager(){
	show_m "runing post_switch_to_network_manager."
 	show_im "disable not needed network service."
    init_manager stop networking
	init_manager disable networking
 	init_manager stop systemd-networkd.service
  	init_manager disable systemd-networkd.service
	
 	show_im "disable wifi powersaving (application level)."
 	$_SUPERUSER tee /etc/NetworkManager/conf.d/wifi-powersave.conf <<- 'EOF' >/dev/null
	[connection]
	wifi.powersave = 2
	EOF
 	
  	show_im "disable wifi powersaving (kernel)."
	$_SUPERUSER tee /etc/modprobe.d/iwlwifi.conf <<- 'EOF' >/dev/null
	options iwlwifi power_save=0
 	EOF
 	if command -v update-initramfs >/dev/null 2>&1;then
		sudo update-initramfs -u
 	elif command -v mkinitcpio >/dev/null 2>&1;then
		sudo mkinitcpio -P
 	fi
}
################################################################################################################################
################################################################################################################################
################################################################################################################################
# main
################################################################################################################################
################################################################################################################################
################################################################################################################################

pre_script

prompt_to_ask_to_what_to_install
create_prompt_to_install_value_file

if [ -n "$_SUPERUSER" ];then
	show_m "creating $_SUPERUSER command "
	$_SUPERUSER true
	
	keep_superuser_refresed &
	sleep 0.5
fi

detect_file_downloader_and_url_checker
pick_file_downloader_and_url_checker

test_internet_

fix_time_

set_package_manager

install_doas_tools

must_install_apps

pick_clone_rep_commnad

check_and_download_core_script

source_and_set_machine_type

clear

_unattended_upgrades_ stop

if [ "$install_drivers" = "true" ] && [ "$install_apps" = "true" ];then
	show_m "Sourcing drivers and apps files."
elif [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
	show_m "Sourcing $arg_ files."
fi
	
if [ "$install_drivers" = "true" ];then
	source_this_script "disto_Drivers_installer" "Source Install drivers functions from (disto_Drivers_installer)"
	source_this_script "disto_specific_Drivers_installer" "Source Install drivers functions from (disto_specific_Drivers_installer)"
fi
	
if [ "$install_apps" = "true" ];then
	source_this_script "disto_apps_installer" "Source Install apps functions from (disto_apps_installer)"
	source_this_script "disto_specific_apps_installer" "Source Install apps functions from (disto_specific_apps_installer)"
fi
	
if [ ! -f "${installer_phases}/create_List_of_apt_2_install_" ];then
	List_of_apt_2_install_=""
	if [ "$install_drivers" = "true" ];then
		source_this_script "disto_Drivers_list" "Add drivers list from (disto_Drivers_list)"
	fi
		
	if [ "$install_apps" = "true" ];then
		source_this_script "disto_apps_list" "Add apps list from (disto_apps_list)"
	fi
	if [ "$install_drivers" = "true" ] && [ "$install_apps" = "true" ];then
		show_m "Sourcing drivers and apps files."
	elif [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
		show_m "Sourcing $arg_ files."
	fi
	
	if [ "$install_drivers" = "true" ];then
		pre_disto_Drivers_installer || show_em "failed to run pre_disto_Drivers_installer"
	fi
	
	if [ "$install_apps" = "true" ];then
		must_purge_first || show_em "failed to run must_purge_first"
		pre_disto_apps_installer || show_em "failed to run pre_disto_apps_installer"
	fi
	
	if [ "$install_dwm" = true ];then
		show_m "Download dwm..."
		dwm_script_location="$(print_getthis_location "my_stuff")"
		$_SUPERUSER "${dwm_script_location}"/my_stuff/bin/my_installer/apps_center/Windows_Manager/dwm_Extra/build.sh download-only "$__USER" || show_em "failed to download dwm."
	fi
	
	install_lightdm_now
	
	install_network_manager
	
	if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
		echo "List_of_apt_2_install_=\"$List_of_apt_2_install_\"" >> "${save_value_file}"
		echo "packages_to_install_pacman=\"$packages_to_install_pacman\"" >> "${save_value_file}"
		echo "packages_to_install_AUR=\"$packages_to_install_AUR\"" >> "${save_value_file}"
	fi
	touch "${installer_phases}/create_List_of_apt_2_install_"
fi

if [ ! -f "${installer_phases}/install_List_of_apt_2_install_" ];then
	if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
		show_m "Install list of apps."
		install_packages || show_em "failed to run install_packages"
		touch "${installer_phases}/install_List_of_apt_2_install_"
	fi
fi

touch "${installer_phases}/no_internet_needed" 
##################################################################################
##################################################################################
# no internet needed  part
##################################################################################
##################################################################################

if [ "$install_drivers" = "true" ];then
	if [ ! -f "${installer_phases}/disto_Drivers_installer" ];then
		post_disto_Drivers_installer || show_em "failed to run post_disto_Drivers_installer"
		disto_specific_Drivers_installer || show_em "failed to run disto_specific_Drivers_installer"
	fi
fi

if [ "$install_apps" = "true" ];then
	post_disto_apps_installer || show_em "failed to run post_disto_apps_installer"
	disto_specific_apps_installer || show_em "failed to run disto_specific_apps_installer"
	install_ads_block_for_firefox || show_em "failed to run install_ads_block_for_firefox"
fi

switch_lightdm_now

switch_to_network_manager

post_switch_to_network_manager

_unattended_upgrades_ start

if [ "$install_drivers" = "false" ] && [ "$install_apps" = "true" ];then
	__Done
elif [ "$install_drivers" = "true" ] && [ "$install_apps" = "false" ];then
	__Done
fi

##################################################################################

show_m "Sourceing disto_configer."
source_this_script "disto_configer" "Configering My Stuff." "run_check"

if [ "$install_dwm" = true ];then
	show_m "Building dwm."
	$_SUPERUSER /usr/share/my_stuff/bin/my_installer/apps_center/Windows_Manager/dwm_Extra/build.sh build "$__USER"
fi

source_this_script "disto_specific_extra" "Source purge_some_unnecessary_pakages and  disable_some_unnecessary_services from (disto_specific_extra)"

purge_some_unnecessary_pakages

disable_some_unnecessary_services

clean_up_now

show_m "running Grub scripts."
disable_ipv6_now
update_grub
update_grub_image

show_m "Sourceing disto_post_install."
source_this_script "disto_post_install" "prepare some script"

pre_post_install

if [ ! -f "${installer_phases}/create_blob_system_files" ];then
	$_SUPERUSER ${__distro_path}/distro_manager/system_files_creater "${machine_type_are}"
	$_SUPERUSER touch "${installer_phases}/create_blob_system_files"
fi

end_of_post_install

create_uninstaller_file

switch_default_xsession

create_new_os_release_file

run_my_alternatives

switch_to_doas_now

if [ "$failed_2_install_ufw" = true ];then
	show_wm "failed to install ${install_ufw_apps}."
	show_wm "sleep 10."
	sleep 10
fi

__Done
