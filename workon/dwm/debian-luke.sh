#!/bin/sh
set -e

show_m(){
	message="${1-}"
	printf '%b' "\n==[ \\033[1;32m${message}\\033[0m ]==\n"
}

sudo apt-get update
for_building="gcc make pkg-config"
for_dwm="libx11-dev libxinerama-dev libxrandr-dev libharfbuzz-dev libxft-dev libx11-xcb-dev libxcb-res0-dev"
for_X11="xclip xcompmgr xorg xwallpaper x11-utils xinit x11-xserver-utils"
extra_2_install="feh maim git lightdm arandr dosfstools libnotify4 dunst ffmpeg nsxiv gnome-keyring mpd mpc mpv ncmpcpp fzf zsh zsh* "

to_install="${for_building} ${for_dwm} ${for_X11} ${extra_2_install}"

show_m "update system"
sudo apt-get update

show_m "Installing dependancy"
sudo apt-get install -y ${to_install}

mkdir -p /tmp/suckless
cd /tmp/suckless

for repo in dwm dmenu st voidrice dwmblocks;do
	show_m "git clone $repo"
	git clone https://github.com/LukeSmithxyz/$repo.git
done
curl "https://raw.githubusercontent.com/wis/mpvSockets/master/mpvSockets.lua" --create-dirs -o "voidrice/.config/mpv/scripts/mpvSockets.lua"

for repo in slock ;do
	show_m "git clone $repo"
	git clone https://git.suckless.org/$repo
done

for d in dwm dmenu st dwmblocks slock;do
	show_m "build $d"
	cd $d
	sudo make install
	cd ..
done

show_m "copy and move files to correct location."

cd voidrice

sudo mv .local/bin/statusbar/* /usr/local/bin
rm -rdf .local/bin/cron .local/bin/statusbar
sudo mv .local/bin/* /usr/local/bin

sudo chown root:root -R /usr/local/bin

rm -rdf README.md LICENSE FUNDING.yml .gitmodules .git
cp -r . $HOME

show_m "create wm luncher."

sudo tee /usr/bin/luke_dwm_autorun <<- 'EOF' > /dev/null
	#!/bin/sh
	. $HOME/.config/x11/xinitrc
	exec /usr/local/bin/dwm
	EOF
sudo chmod +x /usr/bin/luke_dwm_autorun

show_m "create wm desktop file."
sudo tee /usr/share/xsessions/luke-dwm.desktop <<- 'EOF' > /dev/null
	[Desktop Entry]
	Name=My Stuff dwm
	Comment=Log in to a My Stuff dwm session
	Exec=/usr/bin/luke_dwm_autorun
	TryExec=/usr/bin/luke_dwm_autorun
	Icon=openbox
	Type=Xsession
	EOF

show_m "Done"
