#!/bin/sh
set -e
sudo apt-get update
sudo apt-get install -y feh maim xclip xcompmgr gcc make pkg-config git lightdm libx11-dev xorg xwallpaper x11-utils xinit x11-xserver-utils arandr dosfstools libnotify4 dunst ffmpeg nsxiv gnome-keyring mpd mpc mpv ncmpcpp fzf libxinerama-dev libxrandr-dev libharfbuzz-dev libxft-dev libx11-xcb-dev libxcb-res0-dev zsh zsh*

mkdir -p /tmp/suckless
cd /tmp/suckless

for repo in dwm dmenu st voidrice dwmblocks;do
	git clone https://github.com/LukeSmithxyz/$repo.git
done
curl "https://raw.githubusercontent.com/wis/mpvSockets/master/mpvSockets.lua" --create-dirs -o "voidrice/.config/mpv/scripts/mpvSockets.lua"

for repo in slock ;do
	git clone https://git.suckless.org/$repo
done

for d in dwm dmenu st dwmblocks slock;do
	cd $d
	sudo make install
	cd ..
done

cd voidrice
rm -rdf README.md LICENSE FUNDING.yml .gitmodules .git
cp -r . $HOME

sudo tee /usr/bin/dwm_autorun <<- 'EOF' > /dev/null
	#!/bin/sh
	source $HOME/.config/x11/xinitrc
	exec /usr/local/bin/dwm
	EOF
sudo chmod +x /usr/bin/dwm_autorun

sudo tee /usr/share/xsessions/dwm.desktop <<- 'EOF' > /dev/null
	[Desktop Entry]
	Name=My Stuff dwm
	Comment=Log in to a My Stuff dwm session
	Exec=/usr/bin/dwm_autorun
	TryExec=/usr/bin/dwm_autorun
	Icon=openbox
	Type=Xsession
	EOF
