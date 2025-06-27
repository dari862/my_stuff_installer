#!/bin/sh
set -eu

DWM_DIR="dwm"
PATCH_DIR="chadwm-patches"
CONFIG="$DWM_DIR/config.h"
CONFIG_def="$DWM_DIR/config.def.h"

show_m(){
	message="${1-}"
	printf '%b' "\n==[ \\033[1;32m${message}\\033[0m ]==\n"
}

pre_req(){
	for_building="gcc make pkg-config"
	for_dwm="libx11-dev libxinerama-dev libxrandr-dev libharfbuzz-dev libxft-dev libx11-xcb-dev libxcb-res0-dev libimlib2-dev"
	for_st="libgd-dev"
	for_X11="xclip xcompmgr xorg xwallpaper x11-utils xinit x11-xserver-utils"
	for_chadwm="acpi"
	extra_2_install="feh maim git lightdm arandr dosfstools libnotify4 dunst ffmpeg nsxiv gnome-keyring mpd mpc mpv ncmpcpp fzf zsh zsh* "
	
	to_install="${for_building} ${for_dwm} ${for_st} ${extra_2_install} ${for_X11} ${for_chadwm}"
	
	show_m "update system"
	sudo apt-get update
	
	show_m "Installing dependancy"
	sudo apt-get install -y ${to_install}
	
	rm -rdf "$HOME/.config/chadwm/"
	mkdir -p "$HOME/.config/chadwm/"
	
	rm -rdf /tmp/suckless
	mkdir -p /tmp/suckless
	
	mkdir -p "$HOME/Pictures/wall"
	cp -r "$HOME/Desktop/my_stuff/my_wallpapers/nord_wall-02.png" "$HOME/Pictures/wall/gruv.png"
}
download_dwm(){
	cd /tmp
	mkdir -p "$DWM_DIR"
	echo "📥 Downloading DWM ..."
	wget https://dl.suckless.org/dwm/dwm-6.4.tar.gz -P /tmp
	(cd /tmp && tar -xvzf dwm-6.4.tar.gz)
	mv /tmp/dwm-6.4/* "$DWM_DIR"
}

download_patches() {
    mkdir -p "$PATCH_DIR"

    echo "📥 Downloading ChadWM patch set..."
    #status2d/dwm-status2d-systray-6.4.diff
    #cfacts/dwm-cfacts-6.2.diff
    #horizgrid/dwm-horizgrid-6.1.diff
    #movestack/dwm-movestack-20211115-a786211.diff
    #vanitygaps/dwm-cfacts-vanitygaps-6.4_combo.diff
    #notitle/dwm-notitle-6.2.diff
    
	patches="
	barpadding/dwm-barpadding-20211020-a786211.diff
	fibonacci/dwm-fibonacci-20200418-c82db69.diff
    gaplessgrid/dwm-gaplessgrid-20160731-56a31dc.diff
    bottomstack/dwm-bottomstack-6.1.diff	
    dragmfact/dwm-dragmfact-6.2.diff	
    rainbowtags/dwm-rainbowtags-6.2.diff
    underlinetags/dwm-underlinetags-6.2.diff	
    winicon/dwm-winicon-6.3-v2.1.diff
    preserveonrestart/dwm-preserveonrestart-6.3.diff
    shift-tools/shift-tools.c"
	
	base_url="https://dwm.suckless.org/patches"
	for patch in $patches; do
		wget -nc "${base_url}/$patch" -P "$PATCH_DIR" || echo "$patch"
	done

    wget -nc "https://raw.githubusercontent.com/bakkeby/patches/master/dwm/dwm-cfacts-dragcfact-6.2.diff" -P "$PATCH_DIR"
    
    echo "✅ All patches downloaded into: $PATCH_DIR"
}

apply_patches() {
    if [ ! -d "$DWM_DIR" ]; then
        echo "❌ Error: '$DWM_DIR' directory not found. Please place your dwm source there."
        exit 1
    fi

    echo "🩹 Applying patches to: $DWM_DIR"
    for patch in "$PATCH_DIR"/*.diff; do
        echo "→ Applying: $(basename "$patch")"
        patch -d "$DWM_DIR" -Np1 < "$patch" || {
            echo "⚠️ Patch failed: $patch"
            exit 1
        }
    done
	if [ ! -f "$CONFIG" ]; then
		if [ -f "$CONFIG_def" ]; then
			mv "$CONFIG_def" "$CONFIG"
		else
			echo "❌ $CONFIG not found."
			exit 1
		fi
	fi

	# Insert include if missing
	if ! grep -q 'shift-tools.c' "$CONFIG"; then
		sed -i '1i#include "shift-tools.c"' "$CONFIG"
		echo "✅ Added '#include \"shift-tools.c\"' to top of config.h"
	else
		echo "ℹ️  shift-tools.c already included"
	fi

	# Append keybindings if not already present
	if ! grep -q 'shiftview' "$CONFIG"; then
    cat <<'EOF' >> "$CONFIG"

    /* shift-tools keybindings */
    { MODKEY,             XK_Right,  shiftview,  { .i = +1 } },
    { MODKEY,             XK_Left,   shiftview,  { .i = -1 } },
    { MODKEY|ShiftMask,   XK_Right,  shifttag,   { .i = +1 } },
    { MODKEY|ShiftMask,   XK_Left,   shifttag,   { .i = -1 } },
    { MODKEY|ControlMask, XK_Right,  shiftboth,  { .i = +1 } },
    { MODKEY|ControlMask, XK_Left,   shiftboth,  { .i = -1 } },
EOF
		echo "✅ Appended shiftview/shifttag/shiftboth keybindings"
	else
		echo "ℹ️  shift-tools keybindings already exist"
	fi

    echo "✅ All patches applied successfully to '$DWM_DIR'"
    sudo make install
}

post_req(){
	for repo in chadwm st;do
		[ ! -d "$repo" ] && show_m "git clone $repo" && git clone https://github.com/siduck/$repo.git
		show_m "moving $repo"
		mv "$repo" "/tmp/suckless"
	done
	
	cd /tmp/suckless/st
	sudo make install
	
	show_m "copy and move files to correct location."
	cd /tmp/suckless/chadwm
	mv rofi "$HOME/.config/chadwm/"
	mv scripts "$HOME/.config/chadwm/"
	mv eww "$HOME/.config"
	cp -r .Xresources "$HOME/"
	cd "$HOME/.config/chadwm/scripts"
	find . -type f -exec sed -i 's|#!/bin/dash|#!/bin/sh|g' {} +
	sed -i 's/dash/sh/g' run.sh
	
	show_m "create wm luncher."
	
	sudo tee /usr/bin/chadwm_autorun <<- 'EOF' > /dev/null
		#!/bin/sh
		xrdb merge ~/.Xresources 
		xbacklight -set 10 &
		feh --bg-fill ~/Pictures/wall/gruv.png &
		xset r rate 200 50 &
		picom &
		
		sh ~/.config/chadwm/scripts/bar.sh &
		while type dwm >/dev/null; do dwm && continue || break; done
		EOF
	sudo chmod +x /usr/bin/chadwm_autorun
	
	show_m "create wm desktop file."
	
	sudo tee /usr/share/xsessions/chadwm-dwm.desktop <<- 'EOF' > /dev/null
		[Desktop Entry]
		Name=My Stuff dwm
		Comment=Log in to a My Stuff dwm session
		Exec=/usr/bin/chadwm_autorun
		TryExec=/usr/bin/chadwm_autorun
		Icon=openbox
		Type=Xsession
		EOF
	
	show_m "install JetBrainsMono Nerd Font"
	cd /tmp/suckless
	wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.tar.xz
	mkdir -p /tmp/suckless/JetBrainsMono
	tar -xf JetBrainsMono.tar.xz -C /tmp/suckless/JetBrainsMono
	sudo cp -r JetBrainsMono/* /usr/share/fonts/
	sudo fc-cache -fv
}

pre_req
download_dwm
download_patches
apply_patches
post_req

show_m "Done"
