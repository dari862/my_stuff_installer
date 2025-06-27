#!/bin/bash	
set -e

patches_dir_name="dwm_patches"
dwm_source_dir_name="dwm_source"
dwm_builder_dir_name="dwm_builder"
dwm_building_dir_name="dwm"

patches_dir="/tmp/${patches_dir_name}"
dwm_source_dir="/tmp/${dwm_source_dir_name}"
dwm_builder_dir="${dwm_builder_dir_name}"
dwm_building_dir="${dwm_building_dir_name}"

declare -a patches=()
declare -a patches_name=()

patches_name_file="${dwm_builder_dir}/dwm-patches-name.txt"


if command -v curl >/dev/null;then
	getURL(){
		mode="${1-}"
		curl -fSLo "${3-}" "${2-}" --progress-bar || return 1
	}
	
elif command -v wget >/dev/null;then
	getURL(){
		mode="${1-}"
		wget -q --show-progress -O "${3-}" "${2-}" || return 1
	}
fi	

downloading_dwm_source(){
	echo "[+] Cloning dwm 6.5..."
	(git clone https://git.suckless.org/dwm "${dwm_source_dir}" && cd "${dwm_source_dir}" && git checkout 6.5)
}

downloading_dwm_patches(){
		echo "[+] Creating patch directory..."
		mkdir -p "${patches_dir}"

		# Ordered patch list
		patches=(
			"https://dwm.suckless.org/patches/xrdb/dwm-xrdb-6.4.diff"
			"https://dwm.suckless.org/patches/colorbar/dwm-colorbar-6.3.diff"
			"https://dwm.suckless.org/patches/hide_vacant_tags/dwm-hide_vacant_tags-6.4.diff"
			"https://dwm.suckless.org/patches/bartoggle/dwm-bartoggle-keybinds-6.4.diff"
			"https://dwm.suckless.org/patches/statuscmd/dwm-statuscmd-20210405-67d76bd.diff"
			"https://dwm.suckless.org/patches/sticky/dwm-sticky-6.5.diff"
			"https://dwm.suckless.org/patches/spawntag/dwm-spawntag-6.2.diff"
			"https://dwm.suckless.org/patches/stacker/dwm-stacker-6.2.diff"
			"https://dwm.suckless.org/patches/vanitygaps/dwm-vanitygaps-6.2.diff"
			"https://dwm.suckless.org/patches/focusfullscreen/dwm-focusfullscreen-20211121-95e7342.diff"
			"https://dwm.suckless.org/patches/focusmonmouse/dwm-focusmonmouse-6.2.diff"
			"https://dwm.suckless.org/patches/focusmaster/dwm-focusmaster-return-6.2.diff"
			"https://dwm.suckless.org/patches/preventfocusshift/dwm-preventfocusshift-20240831-6.5.diff"
			"https://dwm.suckless.org/patches/fixmultimon/dwm-fixmultimon-6.4.diff"
			"https://dwm.suckless.org/patches/restartsig/dwm-restartsig-20180523-6.2.diff"
			"https://dwm.suckless.org/patches/swallow/dwm-swallow-6.3.diff"
			"https://dwm.suckless.org/patches/bulkill/dwm-bulkill-20231029-9f88553.diff"
		)

		echo "[+] Downloading patches..."
		for url in "${patches[@]}"; do
			patch_name="$(basename "$url")"
			patches_name+=("$patch_name")
			echo "[+] Downloading patche ($patch_name)..."
			getURL 'download2' "$url" "${patches_dir}/$patch_name"
		done
}

create_dwm_builder_dir(){
	[ ! -d "${dwm_builder_dir}" ] && mkdir -p "${dwm_builder_dir}"
	
	if [ ! -d "${dwm_builder_dir}/${patches_dir_name}" ];then
		cp -r "${patches_dir}" "${dwm_builder_dir}"
	fi
	
	if [ ! -d "${dwm_builder_dir}/${dwm_source_dir_name}" ];then
		cp -r "${dwm_source_dir}" "${dwm_builder_dir}"
	fi
}

create_dwm_patches_file(){	
	echo "[+] Creating patches name and order file..."
	echo "${patches_name[@]}" > "$patches_name_file"
}

applying_dwm_patches(){
	patchs_list="$(cat "$patches_name_file")"
	cd "${dwm_builder_dir}"
	[ -d "${dwm_building_dir_name}" ] && rm -rdf "${dwm_building_dir_name}"
	cp -r "${dwm_source_dir_name}" "${dwm_building_dir_name}"
	echo "[+] Applying patches in order..."
	cd "${dwm_building_dir_name}"
	for patch_name in $patchs_list; do
		echo "Applying $patch_name..."
		patch -p1 < "../${patches_dir_name}/${patch_name}"
	done
}

building_dwm(){
	echo "[+] Building dwm..."
	sudo make clean install

	echo "[✓] Done! DWM patched, themed, and installed."
}

##############################################################################################

if [ ! -d "${dwm_builder_dir}/${dwm_source_dir_name}" ];then
	downloading_dwm_source
fi

if [ ! -d "${dwm_builder_dir}/${patches_dir_name}" ];then
	downloading_dwm_patches
fi

if [ ! -d "${dwm_builder_dir}/${dwm_source_dir_name}" ];then
	create_dwm_builder_dir
fi

if [ ! -f "${patches_name_file}" ];then
	create_dwm_patches_file
fi

applying_dwm_patches
#building_dwm
