#!/bin/sh
####################################################################################
#	Var
####################################################################################
install_mode="${1:-install}"
tmp_installer_dir="/tmp/installer_dir"
tmp_installer_file="$tmp_installer_dir/installer.sh"
machine_type_are=""

__USER="$(logname)"
current_user_home="/home/$__USER"

install_drivers=true
install_apps=true

current_script_dir="$(realpath $(dirname $0))"
__distro_name="my_stuff"
__distro_path_root="/usr/share/${__distro_name}"
__distro_path_lib="${__distro_path_root}/lib/common/Distro_path"

all_temp_path="/temp_distro_installer_dir"

if [ "$install_mode" != "dev" ];then
	installer_phases="${all_temp_path}/installer_phases"
else
	installer_phases="${tmp_installer_dir}/installer_phases"
fi

__super_command=""

prompt_to_install_value_file="${all_temp_path}/value_of_picked_option_from_prompt_to_install"

auto_run_script="false" # true to enable
source_prompt_to_install_file=false
check_installer_file=""

install_sudo=false
user_with_superuser_accese=""
install_hwclock=false

PACKAGEMANAGER='apt-get dnf pacman zypper'

####################################################################################
#	functions
####################################################################################
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

test_internet_() {
	[ -f "${installer_phases}/no_internet_needed" ] && return

	NETWORK_TEST="http://network-test.debian.org/nm"
	TEST_DNS="1.1.1.1"
	URL_TO_TEST="http://debian.org"
	install_hwclock=false
	
	_intf=""
	_ip=""
	gateway=""
	
	if [ "$url_package" = "curl" ]; then
		check_url() {
				curl -SsL "$1" >/dev/null 2>&1
		}
		get_full_header() {
				curl -fSi "$1" 2>&1
		}
	elif [ "$url_package" = "wget" ]; then
		check_url() {
				wget -q -O- "$1" >/dev/null 2>&1
		}
		get_full_header() {
				wget -S -O- -q --no-check-certificate "$1" 2>&1
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

	test_internet_via_url() {
		__test_internet_massage_="${1:-}"
		if check_url "$URL_TO_TEST"; then
			print_m "$__test_internet_massage_"
			return 0
		fi
	}
	
	fix_time_() {
		[ -f "${installer_phases}/fix_time_" ] && return

		print_m "Setting date, time, and timezone..."
		header="$(get_full_header 'https://ipinfo.io/')"
		current_date=$(printf "%s\n" "$header" | sed -n 's/^ *[Dd]ate: *//p')

		if [ -n "$current_date" ]; then
			$__super_command date -s "$current_date" >/dev/null 2>&1
		fi

		__timezone=$(printf "%s\n" "$header" | grep -i timezone | awk -F: '{print $2}' | sed 's/[",]//g; s/^[[:space:]]*//;s/[[:space:]]*$//')

		if [ -n "$__timezone" ]; then
			print_m "applying time and timezone."
			if ! $__super_command timedatectl set-timezone "$__timezone" >/dev/null 2>&1; then
				$__super_command ln -sf "/usr/share/zoneinfo/$__timezone" /etc/localtime
				if ! $__super_command hwclock --systohc >/dev/null 2>&1; then
					print_m "Failed to set hardware clock!" "YELLOW"
					install_hwclock=true
				fi
			fi
		fi

		print_m "Time sync complete."
		$__super_command touch "${installer_phases}/fix_time_"
	}

	wifi_mode_installation() {
		wifi_if="${1}"
		ip link set "$wifi_if" up

		if command_exist nmcli; then
			nmcli radio wifi on
			while :; do
				print_m "Scanning for WiFi..."
				networks=$(nmcli -t -f SSID dev wifi list | sed 's/^$//g' | awk '!seen[$0]++' | head -n 10)

				if [ -z "$networks" ]; then
					print_m "No WiFi networks found." "YELLOW"
				else
					printf "%b\n" "Top 10 Networks found:"
					printf '%b\n' "$networks" | awk -F: '{printf("%d. SSID: %-25s \n", NR, $1)}'
				fi

				nmcli --ask dev wifi connect && break
			done
		elif command_exist wpa_supplicant; then
			tmpfile=$(mktemp)
			while :; do
				print_m "Available WiFi:"
				iwlist "$wifi_if" scan | grep ESSID | sed 's/ESSID://g;s/"//g;s/^ *//'

				printf "SSID: "
				read ssid_var
				iw "$wifi_if" scan | grep 'SSID' | grep "$ssid_var" >/dev/null || continue
				printf "Password: "
				read pass_var

				wpa_passphrase "$ssid_var" "$pass_var" > "$tmpfile"
				wpa_supplicant -B -c "$tmpfile" -i "$wifi_if"
				print_m "you will wait for few sec"
				sleep 10
				dhclient "$wifi_if"

				rm -f "$tmpfile"
				break
			done
		fi
	}

	check_ip_and_route() {
		_intf=$(ip route | awk '/default/ {print $5}' | head -n1)
		[ -n "$_intf" ] || _intf=""

		if [ -z "$_intf" ]; then
			for intf in /sys/class/net/*; do
				name=$(basename "$intf")
				[ "$name" != "lo" ] && ip link set "$name" up
			done
			_intf=$(ip route | awk '/default/ {print $5}' | head -n1)
		fi

		if [ -z "$_intf" ]; then
			print_m "No active interface found." "RED"
		fi

		_ip=$(ip -o -f inet addr show "$_intf" | awk '{print $4}' | cut -d/ -f1)
		gateway=$(ip route | awk '/default/ {print $3}' | head -n1)
	}
	
	print_m "Testing internet connection..."

	if internet_tester; then
		return 0
	fi

	if test_internet_via_url "Internet available via fallback check."; then
		return 0
	fi

	print_m "Internet check failed." "YELLOW"
	check_ip_and_route
	if [ -z "$_ip" ]; then
		print_m "No IP address assigned. Checking for WiFi interfaces..."
		wifi_if=$(ip -o link show | awk -F': ' '/state/ && $2 ~ /^w/ {print $2; exit}')
		[ -n "$wifi_if" ] && wifi_mode_installation
	fi

	# Second chance test
	if test_internet_via_url "Internet connection restored."; then
		return 0
	fi

	if ping -q -c 2 "$TEST_DNS" >/dev/null 2>&1; then
		print_m "DNS seems to be the issue. IP: $_ip" "RED"
	elif ! ping -q -c 2 "$gateway" >/dev/null 2>&1; then
		print_m "Cannot reach gateway ($gateway). IP: $_ip" "RED"
	else
		print_m "General network error. IP: $_ip" "RED"
	fi

	fix_time_

	if test_internet_via_url "Internet available after fixing time."; then
		return 0
	fi

	print_m "Still no internet connection." "RED"
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
		__timezone="$__timezone"
		install_hwclock="${install_hwclock}"
		__distro_path_root="$__distro_path_root"
		export __distro_path_lib="$__distro_path_lib"
		installer_phases="${installer_phases}"
		install_drivers="${install_drivers}"
		install_apps="${install_apps}"
		PACKAGER="${PACKAGER}"
		distro_name="${distro_name}"
		__distro_name="$__distro_name"
		all_temp_path="${all_temp_path}"
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
		install_jgmenu="${install_jgmenu}"
		install_bspwm=${install_bspwm}
		install_dwm=${install_dwm}
		switch_default_xsession_to="${switch_default_xsession_to}"
		repo_commnad="${repo_commnad}"
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
	print_m "Neither curl nor wget is availabl, please install curl or wget.." 'RED'
fi

####################################################################################
#	main
####################################################################################

if [ "$__USER" = "root" ];then
	non_root_users="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)"
	for u in ${non_root_users};do
		id "$u" | grep -E "sudo|wheel" && user_with_superuser_access="$user_with_superuser_access $u" || :
	done
	if [ -z "$user_with_superuser_access" ];then
		print_m "you need user with superuser access." 'RED'
	fi
else
	if ! id "$__USER" | grep -Eq "sudo|wheel";then
		print_m "you need user with superuser access." 'RED'
	fi
fi

if [ "$install_mode" = "drivers" ];then
	install_drivers=true
	install_apps=false
	install_mode="install"
elif [ "$install_mode" = "apps" ];then
	install_drivers=false
	install_apps=true
	install_mode="install"
fi

if [ -d "$__distro_path_root" ] && [ ! -d "$installer_phases" ];then
	__reinstall_distro=true
elif [ -f "${installer_phases}/__distro_path_root_removed" ];then
	__reinstall_distro=true
else
	__reinstall_distro=false
fi

if [ -d "$HOME/Desktop/$__distro_name" ];then
	distro_temp_path="$HOME/Desktop/$__distro_name"
else
	distro_temp_path="${all_temp_path}/$__distro_name"
fi

if [ -d "$__distro_path_root" ];then
	__temp_distro_path_lib="${__distro_path_lib}"
else
	__temp_distro_path_lib="${distro_temp_path}/lib/common/Distro_path"
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
else
	print_m "Error: picked incorrect install_mode=$install_mode, you should choose either install or dev" 'RED'
fi

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
		print_m "failed to detect your distro" 'RED'
	;;
esac

for pgm in ${PACKAGEMANAGER}; do
	if command_exist ${pgm};then
		PACKAGER=${pgm}
		break
	fi
done

if [ -z "${PACKAGER}" ];then
	print_m "Error: Can't find a supported package manager" 'RED'
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

print_m "pick clone repo commnad"
if command_exist git;then
	print_m "clone repo commnad: git"
	repo_commnad="git clone --depth=1"
elif command_exist svn;then
	print_m "clone repo commnad: svn"
	repo_commnad="svn clone --depth=1"
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
	chmod 700 "$tmp_installer_dir"

	download_file "$download_url" "$tmp_installer_file"
fi

chmod +x "$installation_file_path"

if [ "$install_mode" = "install" ];then
	if $__super_command "$installation_file_path" "$prompt_to_install_value_file" "$__USER" "$current_user_home" "$machine_type_are" "$__reinstall_distro" "$__temp_distro_path_lib";then
		if [ -f "$tmp_installer_file" ];then
			rm -rdf "$tmp_installer_dir"
		fi
	fi
elif [ "$install_mode" = "dev" ];then
	__packagemanager_file="$tmp_installer_dir/PACKAGEMANAGER"
	if [ ! -f "$__packagemanager_file" ];then
		download_file "https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/Files_4_Distros/${PACKAGER}" "$__packagemanager_file"
	fi
	$__super_command "$installation_file_path" "$__USER" "$__packagemanager_file"
fi
