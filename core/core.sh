#!/bin/sh
set -e
if [ "$(id -u)" -ne 0 ]; then
  printf "This script must be run as root. Exiting."
  exit 1
fi

################################################################################################################################
# Var
################################################################################################################################
prompt_to_install_value_file="${1:-}"
__USER="${2:-}"
current_user_home="${3:-}"
machine_type_are="${4:-}"
__reinstall_distro="${5:-}"
__temp_distro_path_lib="${6:-}"

. "${prompt_to_install_value_file}"

__distro_title="$(echo "$__custom_distro_name" | tr '._-' ' ' | awk '{ for (i=1; i<=NF; i++) { $i = tolower($i); $i = toupper(substr($i,1,1)) substr($i,2) } print }')"

_SUPERUSER=""

switch_default_xsession=""

save_value_file="${all_temp_path}/save_value_file"

internet_status=""

list_of_apps_file_path="${all_temp_path}/list_of_apps"
list_of_installed_apps_file_path="${all_temp_path}/list_of_installed_apps"

dir_2_find_files_in=""

failed_2_install_ufw=false

Distro_installer_mode=true

usr_local_bin_path="/usr/local/bin"
List_of_installed_packages_=""

################################################################################################################################
# Function
################################################################################################################################

command_exist() {
	if command -v $1 > /dev/null 2>&1;then
		return
	else
		return 1
	fi
}

show_m(){
	message="${1-}"
	printf '%b' "\n==[ \\033[1;32m${message}\\033[0m ]==\n"
}

show_wm(){
	message="${1-}"
	printf '%b' "\\033[1;33m[!] \\033[0m${message}\n"
	printf '%s\n' "${message}" >> "$current_user_home/warnings_from_installer"
}

show_wm_only(){
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
	printf '%b' "\\033[1;36m[**] \\033[0m${message}\n"
}

failed_2_add_pakage(){
	message="${1-}"
	printf '%b' "\\033[1;36m[**] \\033[0m${message}\n"
	printf '%s\n' "${message}" >> "$current_user_home/failed_2_add_pakages"
}

pre_script(){
	show_m "Loading Script ....."
	if [ -f "${installer_phases}/Done" ] || [ -f "/tmp/distro_done_installing" ];then
		show_m "${__custom_distro_name} installed successfully ....."
		printf "reboot? (yes/no) [Yy]"
		stty -icanon -echo time 0 min 1
		answer="$(head -c1)"
		stty icanon echo
		echo
        
        [ -z "$answer" ] && answer="$default_value"
        
		case "$answer" in
			[Yy]) reboot_now="Y";;
			[Nn]) reboot_now="";;
			*) show_im "invalid response only y[yes] or n[No] are allowed.";;
		esac

		__Done
	fi
	
	if [ -d "$current_user_home/Desktop" ];then
		dir_2_find_files_in="$current_user_home/Desktop ${all_temp_path}"
	else
		dir_2_find_files_in="${all_temp_path}"
	fi
 	create_dir_and_source_stuff
}

create_dir_and_source_stuff(){
	show_m "pre-script: create dir and source files."
	show_im "create dir ${installer_phases}"

	mkdir -p "${installer_phases}"
	if [ -f "${save_value_file}" ];then
		. "${save_value_file}"
	fi
}

check_and_download_()
{
	check_this_file_="${1:-}"
	filename="$(basename "${check_this_file_}")"
	show_im "running check_and_download_ function on ($check_this_file_)"
	
	path_2_file="${__custom_distro_name}_installer/core/${check_this_file_}"
	
	if [ -f "$current_user_home/Desktop/${path_2_file}" ];then
		mv "$current_user_home/Desktop/${path_2_file}" "${all_temp_path}" || show_em "failed to move ($current_user_home/Desktop/${path_2_file}) to (${all_temp_path})"
		show_im "${filename} already exist."
	elif [ -f "${all_temp_path}/${filename}" ];then
		show_im "${filename} already exist."
	else
		show_im "Download $check_this_file_ file from www.github.com/dari862/${__custom_distro_name}_installer ."
		if download_file "https://raw.githubusercontent.com/dari862/${__custom_distro_name}_installer/main/core/${check_this_file_}" "${all_temp_path}/${filename}" ;then
			chmod +x "${all_temp_path}/${filename}"
		else
			show_em "Error: Failed to download ${filename} from https://raw.githubusercontent.com/dari862/${__custom_distro_name}_installer/main/core/${check_this_file_}"
		fi
	fi
}

kill_package_(){
	ps aux | grep "${1}" | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1 || :
}

pick_file_downloader_and_url_checker(){
	show_im "picked url command: $url_package "
	
	if [ "$url_package" = "curl" ];then
		get_url_content(){
			curl -fsSL "${1-}"
		}
		download_file(){
			curl -SsL --progress-bar "${1-}" -o "${2-}" 2>/dev/null
		}
		get_url_content(){
			curl -s "${1-}" 2>/dev/null
		}
	elif [ "$url_package" = "wget" ];then
		get_url_content(){
			wget -O- "${1-}"
		}
		download_file(){
			wget -q --no-check-certificate --progress=bar "${1-}" -O "${2-}" 2>/dev/null
		}
		get_url_content(){
			wget -q -O- "${1-}" 2>/dev/null
		}
	fi
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
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	[ -f "${installer_phases}/disable_ipv6_now" ] && return
	if [ "$disable_ipv6_stack" = "Y" ];then
		tweek_as_dependency disable_ipv6_stack_kernal_level
	fi
	
	if [ "$disable_ipv6" = "Y" ];then
		tweek_as_dependency disable_ipv6
	fi
	touch "${installer_phases}/disable_ipv6_now"
}

update_grub(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	[ -f "${installer_phases}/update_grub" ] && return
	if [ "$need_to_update_grub" = "true" ];then
		show_im "update grub"
		sync
		if command_exist update-grub; then
			update-grub
		elif command_exist grub-mkconfig; then
			grub-mkconfig -o /boot/grub/grub.cfg
		elif command_exist zypper || command_exist transactional-update; then
			grub2-mkconfig -o /boot/grub2/grub.cfg
		elif command_exist dnf || command_exist rpm-ostree; then
			if [ -f "/boot/grub2/grub.cfg" ]; then
				grub2-mkconfig -o /boot/grub2/grub.cfg
			elif [ -f "/boot/efi/EFI/fedora/grub.cfg" ]; then
				grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
			fi
		fi
	fi
	touch "${installer_phases}/update_grub"
}

update_grub_image(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	[ -f "${installer_phases}/update_grub_image" ] && return
	if [ "$run_update_grub_image" = "Y" ];then
		show_im "update image."
		"${__distro_path_root}"/bin/not_add_2_path/grub2_themes/install.sh
	fi
	touch "${installer_phases}/update_grub_image"
}

source_this_script(){
	file_to_source_and_check="${1-}"
	message_to_show="${2-}"
	[ ! -f "${all_temp_path}"/"${file_to_source_and_check}" ] && show_em "can not source this file ( ${all_temp_path}/${file_to_source_and_check} ). does not exist."
	show_im "${message_to_show}"
	. "${all_temp_path}"/"${file_to_source_and_check}"
}

install_doas_tools()
{
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	[ -f "${installer_phases}/install_doas_tools" ] && return
	if [ "$switch_to_doas" = true ] && [ "$only_doas_installed" = "false" ];then
		show_m "install superuser tools."
		if ! grep "sudo" /etc/group;then
			groupadd sudo
		fi
		show_im "Installing doas"
		install_this_packages_for_doas="doas expect"
		install_packages "$install_this_packages_for_doas"
		adduser "$__USER" sudo || :
		tee -a /etc/bash.bashrc <<- EOF >/dev/null 2>&1
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
		if [ ! -f "${all_temp_path}/PACKAGE_MANAGER" ];then
			check_and_download_ "Files_4_Distros/${PACKAGER}"
			mv "${all_temp_path}/${PACKAGER}" "${all_temp_path}/PACKAGE_MANAGER"
		fi
		if ! . "${all_temp_path}/PACKAGE_MANAGER";then
			show_em "Error: Failed to source PACKAGE_MANAGER from ${all_temp_path}"
		fi
		
		upgrade_now
		
		create_packages_installed_list
		
		if package_installed systemd ;then
			init_system_are="systemd"
		elif package_installed openrc;then
			init_system_are="openrc"
		else
			show_em "Error: variable init_system_are are empty"
		fi
		
		echo "init_system_are=\"${init_system_are}\"" >> "${save_value_file}"
		
		check_and_download_ "disto_init_manager"
		if ! . "${all_temp_path}/disto_init_manager";then
			show_em "Error: Failed to source disto_init_manager from ${all_temp_path}"
		fi
		
		show_im "running pre_package_manager_"
		pre_package_manager_
		
		touch "${installer_phases}/set_package_manager"
	else
		if ! . "${all_temp_path}/PACKAGE_MANAGER";then
			show_em "Error: Failed to source PACKAGE_MANAGER from ${all_temp_path}"
		fi
		if ! . "${all_temp_path}/disto_init_manager";then
			show_em "Error: Failed to source disto_init_manager from ${all_temp_path}"
		fi
	fi
}

switch_default_xsession(){

	[ -f "${installer_phases}/switch_default_xsession" ] && return
	show_m "switching default xsession to $__distro_title $switch_default_xsession_to."
	if command_exist update-alternatives;then
		update-alternatives --install /usr/bin/x-session-manager x-session-manager "${__distro_path_root}/system_files/bin/xsessions/${switch_default_xsession_to}" 60
		switch_default_xsession="$(realpath /etc/alternatives/x-session-manager)"
	else
		ln -sf "${__distro_path_root}/system_files/bin/xsessions/${switch_default_xsession_to}" /usr/bin/x-session-manager
	fi
	touch "${installer_phases}/switch_default_xsession"
}

create_uninstaller_file(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	[ -f "${__distro_path_uninstaller_var}" ] && return
	show_m "Creating uninstaller file."
	tee "${__distro_path_uninstaller_var}" <<- EOF >/dev/null
	grub_image_name="${grub_image_name}"
	List_of_pakages_installed_="${List_of_installed_packages_}"
	switch_default_xsession="${switch_default_xsession}"
	EOF
}

clone_rep_(){
	getthis="${1-}"
	getthis_location="${2-}"
	if [ -d "${getthis_location}" ];then
		show_im "Update distro files repo ( ${getthis} )."
		su - "$__USER" -c "(cd "${getthis_location}" && $repo_commnad pull)"
		touch "${installer_phases}/${getthis}"
	else
		show_im "Clone distro files repo ( ${getthis} )."
		if ! $repo_commnad clone --depth=1 "https://github.com/dari862/${getthis}.git" "${getthis_location}";then
			rm -rdf "${getthis_location}"
			show_em "failed to clone ${getthis}."
		fi
		touch "${installer_phases}/${getthis}"
	fi
	git config --system --add safe.directory "${getthis_location}"
}

check_and_download_core_script(){
	show_m "check if exsit and download core script."
	
	if [ "$install_drivers" = "true" ];then
		check_and_download_ "Files_4_Distros/disto_Drivers_list_common" 
		check_and_download_ "Files_4_Distros/${root_distro_name}/disto_Drivers_list" 
		check_and_download_ "disto_Drivers_installer"
		check_and_download_ "Files_4_Distros/${root_distro_name}/disto_specific_Drivers_installer"
	fi
	
	if [ "$install_apps" = "true" ];then
		check_and_download_ "Files_4_Distros/disto_apps_list_common"
		check_and_download_ "Files_4_Distros/${root_distro_name}/disto_apps_list"
		check_and_download_ "disto_apps_installer"
		check_and_download_ "Files_4_Distros/${root_distro_name}/disto_specific_apps_installer"
	fi
	
	check_and_download_ "Files_4_Distros/${root_distro_name}/disto_specific_extra"
}

clone_all_distro_repo(){
	if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
		check_and_download_ "disto_configer"
		
		################################
		# repo clone
		if [ "$__reinstall_distro" = true ] || [ ! -d "$__distro_path_root" ];then
			show_m "clone distro files repo."
			clone_rep_ "${__custom_distro_name}" "${distro_temp_path}"
			clone_rep_ "Theme_Stuff" "${theme_temp_path}"
		fi
		################################
	fi
}

source_and_set_machine_type(){
	[ -f "${installer_phases}/check_machine_type" ] && return
	
	if [ -z "${machine_type_are}" ];then
		if [ -f "${__distro_path_root}/lib/common/machine_type" ];then
			. "${__distro_path_root}/lib/common/machine_type"
		elif [ -f "${distro_temp_path}/lib/common/machine_type" ];then
			. "${distro_temp_path}/lib/common/machine_type"
		else
			show_em "failed to source machine_type"
		fi
		
		show_m "check machine type"
		
		machine_type_are="$(check_machine_type)"
	fi
	
	if [ "${machine_type_are}" = "laptop" ];then
		show_im "this is laptop"
	elif [ -n "${machine_type_are}" ];then
		show_im "this is not laptop"
	else
		show_em "failed to set machine_type var"
	fi
	has_bluetooth=false
	
	if dmesg | grep -qi bluetooth || lsusb 2>/dev/null | grep -qi bluetooth || [ -d "/sys/class/bluetooth" ];then
		show_im "has bluetooth"
		has_bluetooth=true
	fi
	
	echo "machine_type_are=$machine_type_are" >> "${save_value_file}"
	echo "has_bluetooth=$has_bluetooth" >> "${save_value_file}"
	touch "${installer_phases}/check_machine_type"
}

switch_to_doas_now(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	[ -f "${installer_phases}/switch_to_doas_now" ] && return
	if [ "$switch_to_doas" = true ];then
		if command_exist sudo;then
			show_m "pre Purge sudo."
			export SUDO_FORCE_REMOVE=yes
			
			show_im "changing root password"	
			PASSWORD=$(tr -dc 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' < /dev/urandom | head -c 30 | base64)
			echo "root:${PASSWORD}" | chpasswd || show_em "failed to change root password"
			
			show_im "Purging sudo."
			remove_packages "sudo" || show_em "failed to purge sudo"
			show_im "install fake sudo package and disable root user."
			dpkg -i "${__distro_path_root}/lib/fake_empty_apps/sudo.deb" || show_em "failed to install fake sudo."
			passwd -l root || show_em "failed to disable root user."
			
			unset PASSWORD
			PASSWORD="1234"
		fi
	fi
	touch "${installer_phases}/switch_to_doas_now"
}

tweek_as_dependency(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	grub_updater_function(){   need_to_update_grub=true; }
	if [ -d "$distro_temp_path" ];then
		tweek_location="$(find "${distro_temp_path}/bin/my_installer/tweeks_center/" "${distro_temp_path}/All_Distro_Specific/${root_distro_name}/tweeks_center/" -type f -name "${1:-}" )"
	elif [ -d "$__distro_path_root" ];then
		tweek_location="$(find "${__distro_path_root}/bin/my_installer/tweeks_center/" "${__distro_path_root}/All_Distro_Specific/${root_distro_name}/tweeks_center/" -type f -name "${1:-}" )"
	fi
	. "${tweek_location}" "${2:-}"
}

install_GPU_Drivers_now(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	grub_updater_function(){   need_to_update_grub=true; }
	create_GPU_Drivers_ready=false
	need_2_run_upgrade_now=false
	[ "${enable_GPU_installer}" != true ] && return
	[ -f "${installer_phases}/install_GPU_Drivers_now" ] && return
	failed_to_run(){   show_wm "$@"; }
	failed_but_continue(){   show_em "$@"; }
	alias continue="show_wm"
	say(){   show_im "$@"; }
	create_system_ready_file(){   :; }
	update_pipemenu(){   :; }
	Package_installer_(){   install_packages $@; }
	Package_update_(){   upgrade_now; }
	
	show_im "Installing GPU Drivers"
	. "${distro_temp_path}/All_Distro_Specific/${root_distro_name}/apps_center/Drivers_Pakages/GPU"
	
	create_GPU_Drivers_ready=true
	echo "create_GPU_Drivers_ready=$create_GPU_Drivers_ready" >> "${save_value_file}"
	
	unset failed_to_run
	unset failed_but_continue
	unalias continue
	unset say
	unset create_system_ready_file
	unset update_pipemenu
	unset Package_installer_
	unset need_2_run_upgrade_now
	touch "${installer_phases}/install_GPU_Drivers_now"
}

__Done(){
	show_m "Done"
	if [ "$failed_2_install_ufw" = true ];then
		echo "Press any key to reboot."
		stty -icanon -echo time 0 min 1
		head -c1 >/dev/null
		stty icanon echo
	fi
	
	touch "/tmp/distro_done_installing"
	
	if [ "$reboot_now" = "Y" ];then
		show_m "Removing ${all_temp_path}"
		[ -d "${all_temp_path}" ] && rm -rdf "${all_temp_path}"
		${__distro_path_root}/system_files/bin/my_session_manager_cli reboot
	else
		show_m "Removing ${all_temp_path}"
		[ -d "${all_temp_path}" ] && rm -rdf "${all_temp_path}"
	fi
	exit
}

install_network_manager(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	[ -f "${installer_phases}/install_network_manager" ] && return
	show_m "installing networkmanager"
	install_packages "$network_manager_app_from_Files_4_Distros"
	touch "${installer_phases}/install_network_manager"
}

switch_to_network_manager(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	[ -f "${installer_phases}/switch_to_network_manager" ] && return
	if [ ! -f "/etc/network/interfaces.old" ] && [ -d "/etc/network" ];then
		show_m "running switch_to_network_manager."
		show_im "create to interfaces file"
		tee "${all_temp_path}"/interfaces <<- 'EOF' >/dev/null
		# This file describes the network interfaces available on your system
		# and how to activate them. For more information, see interfaces(5).
			
		source /etc/network/interfaces.d/*
			
		# The loopback network interface
		auto lo
		iface lo inet loopback
		EOF
		chmod 644 "${all_temp_path}"/interfaces
		show_im "create backup of interfaces file"
		mv /etc/network/interfaces /etc/network/interfaces.old
		mv "${all_temp_path}"/interfaces /etc/network/interfaces
 		if ip route | awk '/default/ { print $5 }' | grep -q "^w";then
			__SSID4switch=$(awk '/wpa-ssid/ {gsub(/"/, "", $2); print $2}' /etc/network/interfaces.old)
			__PASS4switch=$(awk '/wpa-psk/ {gsub(/"/, "", $2); print $2}' /etc/network/interfaces.old)
		fi
  		sed -i 's/managed=.*/managed=false/g' /etc/NetworkManager/NetworkManager.conf
 	fi
	if ! service_manager is-enabled NetworkManager;then
		service_manager enable-only NetworkManager
		if [ -n "$__SSID4switch" ];then
			nmcli device wifi connect "$SSID" password "$PASS"
	 	fi
	fi
	show_im "disable not needed network service."
	for servicename in systemd-networkd.service systemd-networkd.socket systemd-resolved.service iwd netctl;do
		if service_manager is-enabled "${servicename}" >/dev/null 2>&1;then
			service_manager disable "${servicename}" || show_wm_only "failed to disable ${servicename}"
		fi
	done
	touch "${installer_phases}/switch_to_network_manager"
}

disable_network_manager_powersaving(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
 	if ls /sys/class/net | grep -q "^w";then
 		if [ -f "/etc/NetworkManager/conf.d/wifi-powersave.conf" ] && [ -f "/etc/modprobe.d/iwlwifi.conf" ];then
  			grep -q "wifi.powersave = 2" "/etc/NetworkManager/conf.d/wifi-powersave.conf" && \
  			grep -q "options iwlwifi power_save=0" "/etc/modprobe.d/iwlwifi.conf" && \
  			return
  		fi
	 	show_im "disable wifi powersaving (application level)."
	 	tee /etc/NetworkManager/conf.d/wifi-powersave.conf <<- 'EOF' >/dev/null
		[connection]
		wifi.powersave = 2
		EOF
	 	
	  	show_im "disable wifi powersaving (kernel)."
		tee /etc/modprobe.d/iwlwifi.conf <<- 'EOF' >/dev/null
		options iwlwifi power_save=0
		EOF
	 	if command -v update-initramfs >/dev/null 2>&1;then
			update-initramfs -u
	 	elif command -v mkinitcpio >/dev/null 2>&1;then
			mkinitcpio -P
	 	fi
	fi
}

install_yt_dlb(){
	if [ "${__reinstall_distro}" = true ];then
		return
	fi
	[ -f "${installer_phases}/install_yt_dlb" ] && return
	if command -v yt-dlp >/dev/null 2>&1;then
		if ! remove_packages "yt-dlp";then
			yt_dlp_path="$(which yt-dlp)"
			rm -rdf $yt_dlp_path
		fi
	fi
	mkdir -p "$usr_local_bin_path"
	download_file "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" "${usr_local_bin_path}/yt-dlp"
	chmod +x "${usr_local_bin_path}/yt-dlp"
	touch "${installer_phases}/install_yt_dlb"
}

################################################################################################################################
################################################################################################################################
################################################################################################################################
# main
################################################################################################################################
################################################################################################################################
################################################################################################################################

PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:$PATH"

pre_script

pick_file_downloader_and_url_checker

set_package_manager

install_network_manager
switch_to_network_manager
disable_network_manager_powersaving

install_doas_tools

must_install_apps
 
check_and_download_core_script

clone_all_distro_repo

. "${__temp_distro_path_lib}"

source_and_set_machine_type

clear

_unattended_upgrades_ stop

if [ "$install_drivers" = "true" ] && [ "$install_apps" = "true" ];then
	show_m "Sourcing drivers and apps files."
elif [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
	show_m "Sourcing $install_mode files."
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
	Packages_2_install=""
	if [ "$install_drivers" = "true" ];then
		source_this_script "disto_Drivers_list_common" "Add drivers list from (disto_Drivers_list_common)"
		source_this_script "disto_Drivers_list" "Add drivers list from (disto_Drivers_list)"
	fi
		
	if [ "$install_apps" = "true" ];then
		source_this_script "disto_apps_list" "Add apps list from (disto_apps_list)"
		source_this_script "disto_apps_list_common" "Add apps list from (disto_apps_list_common)"
	fi
	if [ "$install_drivers" = "true" ] && [ "$install_apps" = "true" ];then
		show_m "Sourcing drivers and apps files."
	elif [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
		show_m "Sourcing $install_mode files."
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
		"${distro_temp_path}"/bin/my_installer/apps_center/Windows_Manager/dwm_Extra/build.sh download-only "$__USER" || show_em "failed to download dwm."
	fi
	
	install_lightdm_now
	
	if [ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ];then
		echo "all_Packages_to_install=\"$all_Packages_to_install\"" >> "${save_value_file}"
	fi
	touch "${installer_phases}/create_List_of_apt_2_install_"
fi

if [ ! -f "${installer_phases}/install_the_list_of_packages_" ] && ([ "$install_drivers" = "true" ] || [ "$install_apps" = "true" ]);then
	show_m "Install list of apps."
	install_packages || show_em "failed to run install_packages"
	touch "${installer_phases}/install_the_list_of_packages_"
fi

install_aur_and_all_needed_packages || show_em "failed to run install_aur_and_all_needed_packages"

install_GPU_Drivers_now

install_yt_dlb

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

_unattended_upgrades_ start

if [ "$install_drivers" = "false" ] && [ "$install_apps" = "true" ];then
	__Done
elif [ "$install_drivers" = "true" ] && [ "$install_apps" = "false" ];then
	__Done
fi

##################################################################################

if [ ! -L "${__distro_path_root}/Distro_Specific" ] || [ "${__reinstall_distro}" = true ];then
	show_m "Sourceing disto_configer."
	source_this_script "disto_configer" "Configering $__distro_title."
fi

. "${__distro_path_root}/lib/common/common"

if [ "$install_dwm" = true ];then
	show_m "Building dwm."
	"${__distro_path_root}"/bin/my_installer/apps_center/Windows_Manager/dwm_Extra/build.sh build "$__USER"
fi

source_this_script "disto_specific_extra" "Source purge_some_unnecessary_pakages and  disable_some_unnecessary_services from (disto_specific_extra)"

purge_some_unnecessary_pakages

disable_some_unnecessary_services

clean_up_now

if [ "${__reinstall_distro}" = false ];then
	show_m "running Grub scripts."
	disable_ipv6_now
	update_grub
	update_grub_image
fi

if [ ! -f "${installer_phases}/system_files_creater" ];then
	show_m "Running system_files_creater."
	unset service_manager
	export PATH="${PATH}:${__distro_path_bin}"
	"${__distro_path_root}"/distro_manager/system_files_creater
	
	touch "${installer_phases}/system_files_creater"
fi

create_uninstaller_file

switch_default_xsession

switch_to_doas_now

if [ "${create_GPU_Drivers_ready}" = true ];then
	touch "${__distro_path_system_ready}/GPU_Drivers_ready"
fi

if [ "$failed_2_install_ufw" = true ];then
	show_wm "failed to install ${install_ufw_apps}."
	show_im "sleep 10."
	sleep 10
fi

__Done
