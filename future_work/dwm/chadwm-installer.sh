#!/bin/sh
set -e

show_m(){
	message="${1-}"
	printf '%b' "\n==[ \\033[1;32m${message}\\033[0m ]==\n"
}

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

for repo in chadwm st;do
	[ ! -d "$repo" ] && show_m "git clone $repo" && git clone https://github.com/siduck/$repo.git
	show_m "moving $repo"
	mv "$repo" "/tmp/suckless"
done

cd /tmp/suckless
for d in st chadwm/chadwm;do
	show_m "build $d"
	cd $d
	sudo make install
	cd ..
done

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
	$HOME/.config/chadwm/scripts/./run.sh 
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

show_m "Done"
