#!/bin/sh
install_mode="${1:-installer}"
tmp_installer_dir="/tmp/installer_dir"
tmp_installer_file="$tmp_installer_dir/installer.sh"

__distro_name="my_stuff"
all_temp_path="/temp_distro_installer_dir"

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
elif [ "$install_mode" = "dev" ];then
	download_url="https://raw.githubusercontent.com/dari862/my_stuff_installer/main/For_dev/pre_dev_env"
fi

mkdir -p "$tmp_installer_dir"
chmod 700 "$tmp_installer_dir"

if [ -f "$tmp_installer_file" ];then
	rm -f "$tmp_installer_file"
fi

if command -v curl >/dev/null 2>&1;then
	download_file(){
		curl -SsL --progress-bar "${1-}" -o "${2-}" 2>/dev/null
	}
elif command -v wget >/dev/null 2>&1;then
	download_file(){
		wget -q --no-check-certificate --progress=bar "${1-}" -O "${2-}" 2>/dev/null
	}
fi

download_file "$download_url" "$tmp_installer_file"

chmod 700 installer.sh
chmod +x installer.sh

if sudo "$tmp_installer_file" "$__distro_name" "${all_temp_path}" "$distro_temp_path" "$theme_temp_path";then
	rm -rdf "$tmp_installer_dir"
fi
