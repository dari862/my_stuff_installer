#!/bin/sh
install_mode="${1:-install}"
tmp_installer_dir="/tmp/installer_dir"
tmp_installer_file="$tmp_installer_dir/installer.sh"

check_installer_file="$HOME/Desktop/my_stuff_installer/core/core.sh"

__distro_name="my_stuff"
all_temp_path="/temp_distro_installer_dir"
__super_command=""

prompt_to_install_value_file="${all_temp_path}/value_of_picked_option_from_prompt_to_install"

auto_run_script="false" # true to enable
source_prompt_to_install_file=false

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
	download_url="https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/core.sh"
	if [ -f "$check_installer_file" ];then
		tmp_installer_file="$check_installer_file"
	fi
elif [ "$install_mode" = "dev" ];then
	download_url="https://raw.githubusercontent.com/dari862/my_stuff_installer/main/For_dev/pre_dev_env"
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
	printf '%b' "\\033[1;32m${massage_is_}\\033[0m\n"
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
	
	if [ "$doas_installed" = true ] && [ "$sudo_installed" = false ];then
		only_doas_installed=true
	else
		only_doas_installed=false
	fi
}

create_prompt_to_install_value_file(){
	print_m "creating: ${prompt_to_install_value_file}"
	$__super_command mkdir -p "${all_temp_path}"
	$__super_command tee "${prompt_to_install_value_file}" <<- EOF >/dev/null
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
		printf "downloading %s to %s using %s ." "${1-}" "${2-}" "${url_package}"
		curl -SsL --progress-bar "${1-}" -o "${2-}" 2>/dev/null
	}
elif command_exist wget;then
	url_package="wget"
	download_file(){
		printf "downloading %s to %s using %s ." "${1-}" "${2-}" "${url_package}"
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

if [ ! -f "$tmp_installer_file" ];then
	mkdir -p "$tmp_installer_dir"
	chmod 700 "$tmp_installer_dir"

	download_file "$download_url" "$tmp_installer_file"
fi

chmod +x "$tmp_installer_file"

if [ -f "${prompt_to_install_value_file}" ];then
	print_m "file exist : ${prompt_to_install_value_file} form previce run."
	if do_you_want_2_run_this_yes_or_no 'Do you want source it?' 'Y';then
		source_prompt_to_install_file=true
	fi
fi

prompt_to_ask_to_what_to_install
create_prompt_to_install_value_file

if $__super_command "$tmp_installer_file" "$prompt_to_install_value_file";then
	if [ "$tmp_installer_file" != "$check_installer_file" ];then
		rm -rdf "$tmp_installer_dir"
	fi
fi
