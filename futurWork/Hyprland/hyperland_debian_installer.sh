#!/bin/bash
clear

install_log_dir="$HOME/Desktop/Install-Logs"
hyperland_debian_installer_temp_dir="/tmp/hyperland_debian_installer_temp_dir"

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/01-Hyprland-Install-Scripts-$(date +%d-%H%M%S).log"

# Set some colors for output messages
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
MAGENTA="$(tput setaf 5)"
ORANGE="$(tput setaf 214)"
WARNING="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
    echo "${ERROR}  This script should ${WARNING}NOT${RESET} be executed as root!! Exiting......." | tee -a "$LOG"
    printf "\n%.0s" {1..2} 
    exit 1
fi

# Create Directory for Install Logs
if [ ! -d ${install_log_dir} ]; then
    mkdir -p ${install_log_dir}
fi

mkdir -p "${hyperland_debian_installer_temp_dir}"
cd "${hyperland_debian_installer_temp_dir}"

keep_superuser_refresed(){
	while true;do
		sudo true
		sleep 30
	done
}

# Show progress function
show_progress() {
    local pid=$1
    local package_name=$2
    local spin_chars=("●○○○○○○○○○" "○●○○○○○○○○" "○○●○○○○○○○" "○○○●○○○○○○" "○○○○●○○○○" \
                      "○○○○○●○○○○" "○○○○○○●○○○" "○○○○○○○●○○" "○○○○○○○○●○" "○○○○○○○○○●") 
    local i=0

    tput civis 
    printf "\r${INFO} Installing ${YELLOW}%s${RESET} ..." "$package_name"

    while ps -p $pid &> /dev/null; do
        printf "\r${INFO} Installing ${YELLOW}%s${RESET} %s" "$package_name" "${spin_chars[i]}"
        i=$(( (i + 1) % 10 ))  
        sleep 0.3  
    done

    printf "\r${INFO} Installing ${YELLOW}%s${RESET} ... Done!%-20s \n\n" "$package_name" ""
    tput cnorm  
}


# Function for installing packages with a progress bar
install_package() { 
  if dpkg -l | grep -q -w "$1" ; then
    echo -e "${INFO} ${MAGENTA}$1${RESET} is already installed. Skipping..."
  else 
    (
      stdbuf -oL sudo apt install -y "$1" 2>&1
    ) >> "$LOG" 2>&1 &
    PID=$!
    show_progress $PID "$1" 
    
    # Double check if the package successfully installed
    if dpkg -l | grep -q -w "$1"; then
        echo -e "\e[1A\e[K${OK} Package ${YELLOW}$1${RESET} has been successfully installed!"
    else
        echo -e "\e[1A\e[K${ERROR} ${YELLOW}$1${RESET} failed to install. Please check the install.log. You may need to install it manually. Sorry, I have tried :("
    fi
  fi
}

# Function for build depencies with a progress bar
build_dep() { 
  echo -e "${INFO} building dependencies for ${MAGENTA}$1${RESET} "
    (
      stdbuf -oL sudo apt build-dep -y "$1" 2>&1
    ) >> "$LOG" 2>&1 &
    PID=$!
    show_progress $PID "$1" 
}

# Function for cargo install with a progress bar
cargo_install() { 
  echo -e "${INFO} installing ${MAGENTA}$1${RESET} using cargo..."
    (
      stdbuf -oL cargo install "$1" 2>&1
    ) >> "$LOG" 2>&1 &
    PID=$!
    show_progress $PID "$1" 
}

# Function for re-installing packages with a progress bar
re_install_package() {
    (
        stdbuf -oL sudo apt install --reinstall -y "$1" 2>&1
    ) >> "$LOG" 2>&1 &
    
    PID=$!
    show_progress $PID "$1" 
    
    if dpkg -l | grep -q -w "$1"; then
        echo -e "\e[1A\e[K${OK} Package ${YELLOW}$1${RESET} has been successfully re-installed!"
    else
        # Package not found, reinstallation failed
        echo -e "${ERROR} ${YELLOW}$1${RESET} failed to re-install. Please check the install.log. You may need to install it manually. Sorry, I have tried :("
    fi
}

# Function for removing packages
uninstall_package() {
  local pkg="$1"

  # Checking if package is installed
  if sudo dpkg -l | grep -q -w "^ii  $1" ; then
    echo -e "${NOTE} removing $pkg ..."
    sudo apt autoremove -y "$1" >> "$LOG" 2>&1 | grep -v "error: target not found"
    
    if ! dpkg -l | grep -q -w "^ii  $1" ; then
      echo -e "\e[1A\e[K${OK} ${MAGENTA}$1${RESET} removed."
    else
      echo -e "\e[1A\e[K${ERROR} $pkg Removal failed. No actions required."
      return 1
    fi
  else
    echo -e "${INFO} Package $pkg not installed, skipping."
  fi
  return 0
}

# Function to check if the system is Ubuntu
is_ubuntu() {
    # Check for 'Ubuntu' in /etc/os-release
    if grep -q 'Ubuntu' /etc/os-release; then
        return 0
    fi
    return 1
}

install_and_switching_to_sddm(){
	sudo apt-get -y update
	sudo apt-get -yq upgrade
	
	sleep 1
	########################################################################
	echo "${INFO} Installing and configuring ${SKY_BLUE}SDDM...${RESET}" | tee -a "$LOG"
	# SDDM with optional SDDM theme #
	
	# installing with NO-recommends
	sddm1=(
  	sddm
	)
	
	sddm2=(
  	qt6-5compat-dev
  	qml6-module-qt5compat-graphicaleffects
  	qt6-declarative-dev
  	qt6-svg-dev
	)
	
	# login managers to attempt to disable
	login=(
  	lightdm 
  	gdm3 
  	gdm 
  	lxdm 
  	lxdm-gtk3
	)
	
	# Set the name of the log file to include the current date and time
	LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_sddm.log"
	
	
	# Install SDDM (no-recommends)
	printf "\n%s - Installing ${SKY_BLUE}SDDM and dependencies${RESET} .... \n" "${NOTE}"
	for PKG1 in "${sddm1[@]}" ; do
  		sudo dpkg-divert --add --rename /usr/sbin/update-alternatives
		sudo ln -s /bin/true /usr/sbin/update-alternatives
		echo "sddm shared/default-x-display-manager select sddm" | sudo debconf-set-selections
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$PKG1" | tee -a "$LOG"
	done
	
	# Installation of additional sddm stuff
	for PKG2 in "${sddm2[@]}"; do
  		install_package "$PKG2"  "$LOG"
	done
	
	# Check if other login managers are installed and disable their service before enabling SDDM
	for login_manager in "${login[@]}"; do
  	if dpkg -l | grep -q "^ii  $login_manager"; then
    	echo "Disabling $login_manager..."
    	sudo systemctl disable "$login_manager.service" >> "$LOG" 2>&1 || echo "Failed to disable $login_manager" >> "$LOG"
    	echo "$login_manager disabled."
  	fi
	done
	
	# Double check with systemctl
	for manager in "${login[@]}"; do
  	if systemctl is-active --quiet "$manager.service" > /dev/null 2>&1; then
    	echo "$manager.service is active, disabling it..." >> "$LOG" 2>&1
    	sudo systemctl disable "$manager.service" >> "$LOG" 2>&1 || echo "Failed to disable $manager.service" >> "$LOG"
  	else
    	echo "$manager.service is not active" >> "$LOG" 2>&1
  	fi
	done
	
	printf "\n%.0s" {1..1}
	printf "${INFO} Activating sddm service........\n"
	sudo systemctl set-default graphical.target 2>&1 | tee -a "$LOG"
	sudo systemctl enable sddm.service 2>&1 | tee -a "$LOG"
	printf "\n%.0s" {1..2}
	reboot_system
}

reboot_system(){
	printf "\n${NOTE} it is ${YELLOW}highly recommended to reboot${RESET} your system.\n\n"

    while true; do
        echo -n "${CAT} Would you like to reboot now? (y/n): "
        read REBOOTNOW
        REBOOTNOW=$(echo "$REBOOTNOW" | tr '[:upper:]' '[:lower:]')
		case "${REBOOTNOW}" in
			y*|'')
				echo "${INFO} Rebooting now..."
            	systemctl reboot 
            	break
			;;
			n*)
				echo "👌 ${OK} You chose NOT to reboot"
            	printf "\n%.0s" {1..1}
            	break
			;;
			*)
				echo "${WARN} Invalid response. Please answer with 'y' or 'n'."
			;;
		esac
    done
}

# Check if the system is Ubuntu
if is_ubuntu; then
    echo "${WARN}This script is ${WARNING}NOT intended for Ubuntu / Ubuntu Based${RESET}. Refer to ${YELLOW}README for the correct link for Ubuntu-Hyprland project${RESET}" | tee -a "$LOG"
    exit 1
fi

printf "\n%.0s" {1..2}  
echo -e "\e[35m
	╦╔═┌─┐┌─┐╦    ╦ ╦┬ ┬┌─┐┬─┐┬  ┌─┐┌┐┌┌┬┐
	╠╩╗│ ││ │║    ╠═╣└┬┘├─┘├┬┘│  ├─┤│││ ││ 2025
	╩ ╩└─┘└─┘╩═╝  ╩ ╩ ┴ ┴  ┴└─┴─┘┴ ┴┘└┘─┴┘ Debian Trixie / SiD
\e[0m"
printf "\n%.0s" {1..1} 
if [ "$(cat /sys/devices/virtual/dmi/id/chassis_type)" = "1" ];then # this is vm
	 echo "${INFO} Were are on VM...${RESET}" | tee -a "$LOG"
	 echo "${INFO} Checking if 3D acceleration are enabled...${RESET}" | tee -a "$LOG"
	 if command -v glxinfo >/dev/null 2>&1;then
	 	outputOfglxinfo="$(glxinfo | grep -iE 'direct rendering|renderer string')"
	 	if echo "$outputOfglxinfo" | grep -q ": Yes" && ! echo "$outputOfglxinfo" | grep -q "llvmpipe";then
	 		echo "👌 ${OK} 🇵🇭 hardware acceleration are ${MAGENTA}enabled..${RESET} ${SKY_BLUE}lets continue with the installation...${RESET}" | tee -a "$LOG"
	 	else
	 		echo "${INFO} ❌ hardware acceleration are ${YELLOW}Disabled${RESET} enable it to proceed. ${YELLOW}Exiting...${RESET}" | tee -a "$LOG"
	 		exit
	 	fi
	 else
	 	printf "\n${NOTE} glxinfo command not found to check if 3D acceleration are enabled \n Are you sure 3D acceleration are enabled?(YES/no)"
	 	read 3DaccelerationEnabled
		3DaccelerationEnabled=$(echo "$3DaccelerationEnabled" | tr '[:upper:]' '[:lower:]')
		if [[ "$3DaccelerationEnabled" == "n"* ]]; then
    		echo -e "\n"
    		echo "❌ ${INFO} You 🫵 chose ${YELLOW}NOT${RESET} to proceed. ${YELLOW}Exiting...${RESET}" | tee -a "$LOG"
    		echo -e "\n"
    		exit 1
    	fi
	 fi
fi

switch2Trixie=false

if [[ -f "/etc/apt/sources.list.d/debian.sources" ]];then
	printf "\n${NOTE} Your in Trixie Debian do you want to proceed with installation of hyperland?(YES/no)"
elif grep -q "trixie" /etc/apt/sources.list && ! grep "trixie" /etc/apt/sources.list | grep "deb-src" | grep -q "#" && [ ! -f "/tmp/need_full_update_upgrade_and_reboot_trixie" ];then
	printf "\n${NOTE} Your in Trixie Debian do you want to proceed with installation of hyperland?(YES/no)"
elif ! grep -qE "trixie|bookworm" /etc/apt/sources.list;then
	echo -e "\n"
    echo "${INFO} You Need ${YELLOW}bookworm debian or trixie ${RESET} to proceed. ${YELLOW}Exiting...${RESET}" | tee -a "$LOG"
    echo -e "\n"
    exit 1
else	
	printf "\n${NOTE} Your in bookworm Debian do you want to switch to trixie to proceed with installation of hyperland?(YES/no)"
	switch2Trixie=true
fi

read ProceedInstallation
ProceedInstallation=$(echo "$ProceedInstallation" | tr '[:upper:]' '[:lower:]')
if [[ "$ProceedInstallation" == "n"* ]]; then
    echo -e "\n"
    echo "❌ ${INFO} You 🫵 chose ${YELLOW}NOT${RESET} to proceed. ${YELLOW}Exiting...${RESET}" | tee -a "$LOG"
    echo -e "\n"
    exit 1
else
	echo "👌 ${OK} 🇵🇭 ${MAGENTA}KooL..${RESET} ${SKY_BLUE}lets continue with the installation...${RESET}" | tee -a "$LOG"
fi

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# List of services to check for active login managers
services=("gdm.service" "gdm3.service" "lightdm.service" "lxdm.service")

# Function to check if any login services are active
check_services_running() {
    active_services=()  # Array to store active services
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            active_services+=("$svc")  
        fi
    done

    if [ ${#active_services[@]} -gt 0 ]; then
        return 0  
    else
        return 1  
    fi
}

#####################################################################################
install_nvidia_driver(){
	echo "${INFO} Configuring ${SKY_BLUE}nvidia stuff${RESET}" | tee -a "$LOG"
	# Nvidia - Check Readme for more details for the drivers #
	# UBUNTU USERS, FOLLOW README!
	
	nvidia_pkg=(
  	nvidia-driver
  	firmware-misc-nonfree
  	nvidia-kernel-dkms
  	linux-headers-$(uname -r)
  	libnvidia-egl-wayland1
  	libva-wayland2
  	libnvidia-egl-wayland1
  	nvidia-vaapi-driver
	)

	# Set the name of the log file to include the current date and time
	LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_nvidia.log"
	MLOG="${install_log_dir}/install-$(date +%d-%H%M%S)_nvidia2.log"
	
	## adding the deb source for nvidia driver
	# Create a backup of the sources.list file
	sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup 2>&1 | tee -a "$LOG"
	
	## UBUNTU - NVIDIA (comment this two by adding # you dont need this!)
	# Add the comment and repository entry to sources.list
	echo "## for nvidia" | sudo tee -a /etc/apt/sources.list 2>&1 | tee -a "$LOG"
	echo "deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware" | sudo tee -a /etc/apt/sources.list 2>&1 | tee -a "$LOG"
	
	# Update the package list
	sudo apt update
	
	# Function to add a value to a configuration file if not present
	add_to_file() {
    	local config_file="$1"
    	local value="$2"
    	
    	if ! sudo grep -q "$value" "$config_file"; then
        	echo "Adding $value to $config_file"
        	sudo sh -c "echo '$value' >> '$config_file'"
    	else
        	echo "$value is already present in $config_file."
    	fi
	}
	
	# Install additional Nvidia packages
	printf "${YELLOW} Installing ${SKY_BLUE}Nvidia packages${RESET} ...\n"
  	for NVIDIA in "${nvidia_pkg[@]}"; do
    	install_package "$NVIDIA" "$LOG"
  	done
	
	# adding additional nvidia-stuff
	printf "${YELLOW} adding ${SKY_BLUE}nvidia-stuff${RESET} to /etc/default/grub..."
	
  	# Additional options to add to GRUB_CMDLINE_LINUX
  	additional_options="rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia-drm.modeset=1 rcutree.rcu_idle_gp_delay=1"
	
  	# Check if additional options are already present in GRUB_CMDLINE_LINUX
  	if grep -q "GRUB_CMDLINE_LINUX.*$additional_options" /etc/default/grub; then
    	echo "GRUB_CMDLINE_LINUX already contains the additional options"
  	else
    	# Append the additional options to GRUB_CMDLINE_LINUX
    	sudo sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"$additional_options /" /etc/default/grub
    	echo "Added the additional options to GRUB_CMDLINE_LINUX"
  	fi
	
  	# Update GRUB configuration
  	sudo update-grub 2>&1 | tee -a "$LOG"
    	
  	# Define the configuration file and the line to add
    	config_file="/etc/modprobe.d/nvidia.conf"
    	line_to_add="""
    	options nvidia-drm modeset=1 fbdev=1
    	options nvidia NVreg_PreserveVideoMemoryAllocations=1
    	"""
	
    	# Check if the config file exists
    	if [ ! -e "$config_file" ]; then
        	echo "Creating $config_file"
        	sudo touch "$config_file" 2>&1 | tee -a "$LOG"
    	fi
	
    	add_to_file "$config_file" "$line_to_add"
	
   	# Add NVIDIA modules to initramfs configuration
   	modules_to_add="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
   	modules_file="/etc/initramfs-tools/modules"
	
   	if [ -e "$modules_file" ]; then
    	add_to_file "$modules_file" "$modules_to_add" 2>&1 | tee -a "$LOG"
    	sudo update-initramfs -u 2>&1 | tee -a "$LOG"
   	else
    	echo "Modules file ($modules_file) not found." 2>&1 | tee -a "$LOG"
   	fi
	
	printf "\n%.0s" {1..2}
}

switching_to_sddm=false
if check_services_running; then
	switching_to_sddm=true
    active_list=$(printf "%s\n" "${active_services[@]}")
	printf "\n${NOTE} Active non-SDDM login manager(s) detected. \n The following login manager(s) are active:\n\n$active_list\n\n\nShall we proceed??(YES/no)"
	read non_SDDM_switch
	non_SDDM_switch=$(echo "$non_SDDM_switch" | tr '[:upper:]' '[:lower:]')
	if [[ "$non_SDDM_switch" == "n"* ]]; then
    	switching_to_sddm=false
    fi
fi

keep_superuser_refresed &

if [[ "$switching_to_sddm" == true ]];then
	install_and_switching_to_sddm
fi
	
if [[ "$switch2Trixie" == "true" ]];then
	echo "❌ ${INFO} Switching to Trixie-sid...${RESET}" | tee -a "$LOG"
	sudo sed -i 's/#deb-src/deb-src/g' /etc/apt/sources.list
	sudo sed -i 's/# deb-src/deb-src/g' /etc/apt/sources.list
	sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
fi

echo "${INFO} Running a ${SKY_BLUE}full system update...${RESET}" | tee -a "$LOG"
sudo apt-get -y update
sudo apt-get -yq upgrade

if [[ "$switch2Trixie" == "true" ]];then
	sudo apt-get -yq dist-upgrade
	sudo apt-get -yq full-upgrade
	sudo apt modernize-sources -y
	touch "/tmp/need_full_update_upgrade_and_reboot_trixie"
	reboot_system
	exit
fi

sleep 1
printf "\n%.0s" {1..1}

# install pciutils if detected not installed. Necessary for detecting GPU
if ! dpkg -l | grep -w pciutils > /dev/null; then
    echo "pciutils is not installed. Installing..." | tee -a "$LOG"
    sudo apt install -y pciutils
    printf "\n%.0s" {1..1}
fi

# Path to the install-scripts directory
script_directory=install-scripts

rm -rdf "Debian-Hyprland"
git clone https://github.com/JaKooLit/Debian-Hyprland.git Debian-Hyprland

# Check if NVIDIA GPU is detected
if lspci | grep -i "nvidia" &> /dev/null; then
    install_nvidia_driver(){ echo ""; }
fi

printf "\n%.0s" {1..1}

sleep 1
########################################################################
# execute pre clean up
########################################################################
# This script is cleaning up previous manual installation files / directories

# 22 Aug 2024
# Files to be removed from /usr/local/bin

TARGET_DIR="/usr/local/bin"

# Define packages to manually remove (was manually installed previously)
PACKAGES=(
  hyprctl
  hyprpm
  hyprland
  Hyprland
  cliphist
  pypr
  swappy
  waybar
  magick
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_pre-clean-up.log"

# Loop through the list of packages
for PKG_NAME in "${PACKAGES[@]}"; do
  # Construct the full path to the file
  FILE_PATH="$TARGET_DIR/$PKG_NAME"

  # Check if the file exists
  if [[ -f "$FILE_PATH" ]]; then
    # Delete the file
    sudo rm "$FILE_PATH"
    echo "Deleted: $FILE_PATH" 2>&1 | tee -a "$LOG"
  else
    echo "File not found: $FILE_PATH" 2>&1 | tee -a "$LOG"
  fi
done

clear
########################################################################
echo "${INFO} Installing ${SKY_BLUE}necessary dependencies...${RESET}" | tee -a "$LOG"
########################################################################
sleep 1

# packages neeeded
dependencies=(
    build-essential
    cmake
    cmake-extras
    curl
    findutils
    gawk
    gettext
    git
    glslang-tools
    gobject-introspection
    golang
    hwdata
    jq
    libegl-dev
    libegl1-mesa-dev
    meson
    ninja-build
    openssl
    psmisc
    python3-mako
    python3-markdown
    python3-markupsafe
    python3-yaml
    python3-pyquery
    qt6-base-dev
    spirv-tools
    unzip
    vulkan-validationlayers
    vulkan-utility-libraries-dev
    wayland-protocols
    xdg-desktop-portal
    xwayland
)

# hyprland dependencies
hyprland_dep=(
    bc
    binutils
    libc6
    libcairo2
    libdisplay-info2
    libdrm2
    libhyprcursor-dev
    libhyprlang-dev
    libhyprutils-dev
    libpam0g-dev
    hyprcursor-util
)

build_dep=(
  wlroots
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_dependencies.log"

# Installation of main dependencies
printf "\n%s - Installing ${SKY_BLUE}main dependencies....${RESET} \n" "${NOTE}"

for PKG1 in "${dependencies[@]}" "${hyprland_dep[@]}"; do
  install_package "$PKG1" "$LOG"
done

printf "\n%.0s" {1..1}

for PKG1 in "${build_dep[@]}"; do
  build_dep "$PKG1" "$LOG"
done

printf "\n%.0s" {1..2}

########################################################################
echo "${INFO} Installing ${SKY_BLUE}necessary fonts...${RESET}" | tee -a "$LOG"
########################################################################
sleep 1
# Fonts Required #

fonts=(
  fonts-firacode
  fonts-font-awesome
  fonts-noto
  fonts-noto-cjk
  fonts-noto-color-emoji
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_fonts.log"


# Installation of main components
printf "\n%s - Installing necessary ${SKY_BLUE}fonts${RESET}.... \n" "${NOTE}"

for PKG1 in "${fonts[@]}"; do
  install_package "$PKG1" "$LOG"
done

printf "\n%.0s" {1..2}

# jetbrains nerd font. Necessary for waybar
DOWNLOAD_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
# Maximum number of download attempts
MAX_ATTEMPTS=2
for ((ATTEMPT = 1; ATTEMPT <= MAX_ATTEMPTS; ATTEMPT++)); do
    curl -OL "$DOWNLOAD_URL" 2>&1 | tee -a "$LOG" && break
    echo "Download ${YELLOW}DOWNLOAD_URL${RESET} attempt $ATTEMPT failed. Retrying in 2 seconds..." 2>&1 | tee -a "$LOG"
    sleep 2
done

# Check if the JetBrainsMono directory exists and delete it if it does
if [ -d ~/.local/share/fonts/JetBrainsMonoNerd ]; then
    rm -rf ~/.local/share/fonts/JetBrainsMonoNerd 2>&1 | tee -a "$LOG"
fi

mkdir -p ~/.local/share/fonts/JetBrainsMonoNerd 2>&1 | tee -a "$LOG"
# Extract the new files into the JetBrainsMono directory and log the output
tar -xJkf JetBrainsMono.tar.xz -C ~/.local/share/fonts/JetBrainsMonoNerd 2>&1 | tee -a "$LOG"

# Fantasque Mono Nerd Font
if wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FantasqueSansMono.zip; then
    mkdir -p "$HOME/.local/share/fonts/FantasqueSansMonoNerd" && unzip -o -q "FantasqueSansMono.zip" -d "$HOME/.local/share/fonts/FantasqueSansMono" && echo "FantasqueSansMono installed successfully" | tee -a "$LOG"
else
    echo -e "\n${ERROR} Failed to download ${YELLOW}Fantasque Sans Mono Nerd Font${RESET} Please check your connection\n" | tee -a "$LOG"
fi

# Victor Mono-Font
if wget -q https://rubjo.github.io/victor-mono/VictorMonoAll.zip; then
    mkdir -p "$HOME/.local/share/fonts/VictorMono" && unzip -o -q "VictorMonoAll.zip" -d "$HOME/.local/share/fonts/VictorMono" && echo "Victor Font installed successfully" | tee -a "$LOG"
else
    echo -e "\n${ERROR} Failed to download ${YELLOW}Victor Mono Font${RESET} Please check your connection\n" | tee -a "$LOG"
fi

# Update font cache and log the output
fc-cache -v 2>&1 | tee -a "$LOG"

# clean up 
if [ -d "JetBrainsMono.tar.xz" ]; then
	rm -r JetBrainsMono.tar.xz 2>&1 | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}

########################################################################
echo "${INFO} Installing ${SKY_BLUE}KooL Hyprland packages...${RESET}" | tee -a "$LOG"
########################################################################
sleep 1
########################################################################
# "01-hypr-pkgs.sh"
########################################################################
# Hyprland-Dots Packages #
# edit your packages desired here. 
# WARNING! If you remove packages here, dotfiles may not work properly.
# and also, ensure that packages are present in Debian Official Repo

# add packages wanted here
Extra=(

)

# packages needed
hypr_package=(
    cliphist
    grim
    gvfs
    gvfs-backends
    inxi
    imagemagick
    kitty
    nano
    pavucontrol
    playerctl
    polkit-kde-agent-1
    python3-requests
    python3-pip
    qt5ct
    qt5-style-kvantum
    qt5-style-kvantum-themes
    qt6ct
    slurp
    swappy
    sway-notification-center
    unzip
    waybar
    wget
    wl-clipboard
    wlogout
    xdg-user-dirs
    xdg-utils
    yad
)

# the following packages can be deleted. however, dotfiles may not work properly
hypr_package_2=(
    brightnessctl
    btop
    cava
    fastfetch
    loupe
    gnome-system-monitor
    mousepad
    mpv
    mpv-mpris
    nwg-look
    nwg-displays
    nvtop
    pamixer
    qalculate-gtk
)

# packages to force reinstall 
force=(
  imagemagick
  wayland-protocols
)

# List of packages to uninstall as it conflicts with swaync or causing swaync to not function properly
uninstall=(
    dunst
    mako
    rofi
    cargo
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_hypr-pkgs.log"

# conflicting packages removal
overall_failed=0
printf "\n%s - ${SKY_BLUE}Removing some packages${RESET} as it conflicts with KooL's Hyprland Dots \n" "${NOTE}"
for PKG in "${uninstall[@]}"; do
  uninstall_package "$PKG" 2>&1 | tee -a "$LOG"
  if [ $? -ne 0 ]; then
    overall_failed=1
  fi
done

if [ $overall_failed -ne 0 ]; then
  echo -e "${ERROR} Some packages failed to uninstall. Please check the log."
fi

printf "\n%.0s" {1..1}

# Installation of main components
printf "\n%s - Installing ${SKY_BLUE}KooL's hyprland necessary packages${RESET} .... \n" "${NOTE}"

for PKG1 in "${hypr_package[@]}" "${hypr_package_2[@]}" "${Extra[@]}"; do
  install_package "$PKG1" "$LOG"
done

printf "\n%.0s" {1..1}

for PKG2 in "${force[@]}"; do
  re_install_package "$PKG2" "$LOG"
done

printf "\n%.0s" {1..1}
# install YAD from assets. NOTE This is downloaded from SID repo and sometimes
# Trixie is removing YAD for some strange reasons
# Check if yad is installed
if ! command -v yad &> /dev/null; then
  echo "${INFO} Installing ${YELLOW}YAD from assets${RESET} ..."
  sudo dpkg -i assets/yad_0.40.0-1+b2_amd64.deb
  sudo apt install -f -y
  echo "${INFO} ${YELLOW}YAD from assets${RESET} succesfully installed ..."
fi

printf "\n%.0s" {1..2}

# Install up-to-date Rust
echo "${INFO} Installing most ${YELLOW}up to date Rust compiler${RESET} ..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1 | tee -a "$LOG"
source "$HOME/.cargo/env"

## making brightnessctl work
sudo chmod +s $(which brightnessctl) 2>&1 | tee -a "$LOG" || true

printf "\n%.0s" {1..2}

sleep 1
########################################################################
# "hyprland.sh"
########################################################################
sleep 1
# Main Hyprland Package #

hypr=(
  hyprland-protocols
  hyprwayland-scanner
)

# forcing to reinstall. Had experience it says hyprland is already installed
f_hypr=(
  hyprland
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_hyprland.log"


# Hyprland
printf "${NOTE} Installing ${SKY_BLUE}Hyprland packages${RESET} .......\n"
 for HYPR in "${hypr[@]}"; do
   install_package "$HYPR" "$LOG"
done

# force
printf "${NOTE} Reinstalling ${SKY_BLUE}Hyprland packages${RESET}  .......\n"
 for HYPR1 in "${f_hypr[@]}"; do
   re_install_package "$HYPR1" "$LOG"
done

printf "\n%.0s" {1..2} 
########################################################################
# "wallust.sh"
########################################################################
sleep 1
# wallust - pywal colors replacement #

wallust=(
  wallust
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_wallust.log"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG")"

# Install up-to-date Rust
echo "${INFO} Installing most ${YELLOW}up to date Rust compiler${RESET} ..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1 | tee -a "$LOG"
source "$HOME/.cargo/env"

printf "\n%.0s" {1..2} 

# Remove any existing Wallust binary
if [[ -f "/usr/local/bin/wallust" ]]; then
    echo "Removing existing Wallust binary..." 2>&1 | tee -a "$LOG"
    sudo rm "/usr/local/bin/wallust" 
fi

printf "\n%.0s" {1..2} 

cargo_install "$WALL" "$LOG" 
if [ $? -eq 0 ]; then  
	echo "${OK} ${MAGENTA}Wallust${RESET} installed successfully." | tee -a "$LOG"
	printf "\n%.0s" {1..1} 
	# Move the newly compiled binary to /usr/local/bin
	echo "Moving Wallust binary to /usr/local/bin..." | tee -a "$LOG"
	if sudo mv "$HOME/.cargo/bin/wallust" /usr/local/bin 2>&1 | tee -a "$LOG"; then
    	echo "${OK} Wallust binary moved successfully to /usr/local/bin." | tee -a "$LOG"
	else
    	echo "${ERROR} Failed to move Wallust binary. Check the log file $LOG for details." | tee -a "$LOG"
	fi
else
    echo "${ERROR} Installation of ${MAGENTA}$WALL${RESET} failed. Check the log file $LOG for details." | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}
########################################################################
# "swww.sh"
########################################################################
# SWWW - Wallpaper Utility #

# Check if 'swww' is installed
if ! command -v swww &>/dev/null || [[ "$(swww -V | awk '{print $NF}')" != "0.9.5" ]]; then
	echo -e "${NOTE} ${MAGENTA}swww${RESET} is not installed. Proceeding with installation."
	swww=(
    	liblz4-dev
	)
	
	# specific branch or release
	swww_tag="v0.9.5"

	# Set the name of the log file to include the current date and time
	LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_swww.log"
	MLOG="${install_log_dir}/install-$(date +%d-%H%M%S)_swww2.log"
	
	# Installation of swww compilation needed
	printf "\n%s - Installing ${SKY_BLUE}swww $swww_tag and dependencies${RESET} .... \n" "${NOTE}"
	
	for PKG1 in "${swww[@]}"; do
    	install_package "$PKG1" "$LOG"
	done
	
	printf "\n%.0s" {1..2}
	build_it="false"
	# Check if swww directory exists
	if [ -d "swww" ]; then
    	cd swww
    	git pull origin main 2>&1 | tee -a "$MLOG"
    	build_it="true"
	else
    	if git clone --recursive -b $swww_tag https://github.com/LGFae/swww.git swww; then
        	cd swww
        	build_it="true"
    	else
        	echo -e "${ERROR} Download failed for ${YELLOW}swww $swww_tag${RESET}" 2>&1 | tee -a "$LOG"
    	fi
	fi
	
	if [[ "$build_it" == "true" ]];then
		# Proceed with the rest of the installation steps
		source "$HOME/.cargo/env" || true
		
		cargo build --release 2>&1 | tee -a "$MLOG"
		
		# Checking if swww is previously installed and delete before copying
		file1="/usr/bin/swww"
		file2="/usr/bin/swww-daemon"
		
		# Check if file1 exists and delete if so
		if [ -f "$file1" ]; then
    		sudo rm -r "$file1"
		fi
		
		# Check if file2 exists and delete if so
		if [ -f "$file2" ]; then
    		sudo rm -r "$file2"
		fi
		
		# Copy binaries to /usr/bin/
		sudo cp -r target/release/swww /usr/bin/ 2>&1 | tee -a "$MLOG" 
		sudo cp -r target/release/swww-daemon /usr/bin/ 2>&1 | tee -a "$MLOG" 
		
		# Copy bash completions
		sudo mkdir -p /usr/share/bash-completion/completions 2>&1 | tee -a "$MLOG" 
		sudo cp -r completions/swww.bash /usr/share/bash-completion/completions/swww 2>&1 | tee -a "$MLOG" 
		
		# Copy zsh completions
		sudo mkdir -p /usr/share/zsh/site-functions 2>&1 | tee -a "$MLOG" 
		sudo cp -r completions/_swww /usr/share/zsh/site-functions/_swww 2>&1 | tee -a "$MLOG" 
		
		printf "\n%.0s" {1..2}
		
		sleep 1
		cd ..
	fi
	build_it="false"
fi
########################################################################
# "rofi-wayland.sh"
########################################################################
sleep 1
# Rofi-Wayland) #

rofi=(
  bison
  flex
  pandoc
  doxygen
  cppcheck
  imagemagick
  libmpdclient-dev
  libnl-3-dev
  libasound2-dev
  libstartup-notification0-dev
  libwayland-client++1
  libwayland-dev
  libcairo-5c-dev
  libcairo2-dev
  libpango1.0-dev
  libgdk-pixbuf-2.0-dev
  libxcb-keysyms1-dev
  libwayland-client0
  libxcb-ewmh-dev
  libxcb-cursor-dev
  libxcb-icccm4-dev
  libxcb-randr0-dev
  libxcb-render-util0-dev
  libxcb-util-dev
  libxcb-xkb-dev
  libxcb-xinerama0-dev
  libxkbcommon-dev
  libxkbcommon-x11-dev
  ohcount
  wget
)

rofi_tag="1.7.8+wayland1"

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_rofi_wayland.log"
MLOG="${install_log_dir}/install-$(date +%d-%H%M%S)_rofi_wayland2.log"

# Installation of main components
printf "\n%s - Re-installing ${SKY_BLUE}rofi-wayland dependencies${RESET}.... \n" "${INFO}"

 for FORCE in "${rofi[@]}"; do
   re_install_package "$FORCE" "$LOG"
  done

printf "\n%.0s" {1..2}
# Clone and build rofi - wayland
printf "${NOTE} Installing ${SKY_BLUE}rofi-wayland${RESET}...\n"

# Check if rofi directory exists
if [ -d "rofi-$rofi_tag" ]; then
  rm -rf "rofi-$rofi_tag"
fi

# cloning rofi-wayland
printf "${NOTE} Downloading ${YELLOW}rofi-wayland $rofi_tag${RESET} from releases...\n"
wget https://github.com/lbonn/rofi/releases/download/1.7.8%2Bwayland1/rofi-1.7.8+wayland1.tar.gz

if [ -f "rofi-$rofi_tag.tar.gz" ]; then
  printf "${OK} ${YELLOW}rofi-wayland $rofi_tag${RESET} downloaded successfully.\n" 2>&1 | tee -a "$LOG"
  tar xf rofi-$rofi_tag.tar.gz
fi

cd rofi-$rofi_tag

# Proceed with the installation steps
if meson setup build && ninja -C build ; then
  if sudo ninja -C build install 2>&1 | tee -a "$MLOG"; then
    printf "${OK} rofi-wayland installed successfully.\n" 2>&1 | tee -a "$MLOG"
  else
    echo -e "${ERROR} Installation failed for ${YELLOW}rofi-wayland $rofi_tag${RESET}" 2>&1 | tee -a "$MLOG"
  fi
else
  echo -e "${ERROR} Meson setup or ninja build failed for ${YELLOW}rofi-wayland $rofi_tag${RESET}" 2>&1 | tee -a "$MLOG"
fi

# clean up
rm -rf rofi-$rofi_tag.tar.gz

printf "\n%.0s" {1..2}

########################################################################
# "hyprlock.sh"
########################################################################
sleep 1
# hyprlock #

lock=(
	libpam0g-dev
	libgbm-dev
	libdrm-dev
    libmagic-dev
    libhyprlang-dev
    libhyprutils-dev
)

#specific branch or release
lock_tag="v0.4.0"

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_hyprlock.log"
MLOG="${install_log_dir}/install-$(date +%d-%H%M%S)_hyprlock2.log"

# Installation of dependencies
printf "\n%s - Installing ${YELLOW}hyprlock dependencies${RESET} .... \n" "${INFO}"

for PKG1 in "${lock[@]}"; do
  re_install_package "$PKG1" "$LOG"
done

# Check if hyprlock directory exists and remove it
if [ -d "hyprlock" ]; then
    rm -rf "hyprlock"
fi

# Clone and build hyprlock
printf "${INFO} Installing ${YELLOW}hyprlock $lock_tag${RESET} ...\n"
if git clone --recursive -b $lock_tag https://github.com/hyprwm/hyprlock.git; then
    cd hyprlock
	cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
	cmake --build ./build --config Release --target hyprlock -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
    if sudo cmake --install build 2>&1 | tee -a "$MLOG" ; then
        printf "${OK} ${YELLOW}hyprlock $lock_tag${RESET} installed successfully.\n" 2>&1 | tee -a "$MLOG"
    else
        echo -e "${ERROR} Installation failed for ${YELLOW}hyprlock $lock_tag${RESET}" 2>&1 | tee -a "$MLOG"
    fi
    cd ..
else
    echo -e "${ERROR} Download failed for ${YELLOW}hyprlock $lock_tag${RESET}" 2>&1 | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}

########################################################################
# "hyprlang.sh"
########################################################################
sleep 1
# hyplang #


#specific branch or release
lang_tag="v0.5.2"

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_hyprlang.log"
MLOG="${install_log_dir}/install-$(date +%d-%H%M%S)_hyprlang2.log"

# Installation of dependencies
printf "\n%s - Installing ${YELLOW}hyprlang dependencies${RESET} .... \n" "${INFO}"

# Check if hyprlang directory exists and remove it
if [ -d "hyprlang" ]; then
    rm -rf "hyprlang"
fi

# Clone and build 
printf "${INFO} Installing ${YELLOW}hyprlang $lang_tag${RESET} ...\n"
if git clone --recursive -b $lang_tag https://github.com/hyprwm/hyprlang.git; then
    cd hyprlang
	cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
    cmake --build ./build --config Release --target hyprlang -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
    if sudo cmake --install ./build 2>&1 | tee -a "$MLOG" ; then
        printf "${OK} ${MAGENTA}hyprlang $lang_tag${RESET} installed successfully.\n" 2>&1 | tee -a "$MLOG"
    else
        echo -e "${ERROR} Installation failed for ${YELLOW}hyprlang $lang_tag${RESET}" 2>&1 | tee -a "$MLOG"
    fi
    #moving the addional logs to ${install_log_dir} directory
    mv $MLOG ../${install_log_dir}/ || true 
    cd ..
else
    echo -e "${ERROR} Download failed for ${YELLOW}hyprlang $lang_tag${RESET}" 2>&1 | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}
########################################################################
# "hypridle.sh"
########################################################################
# hypidle #

idle=(
    libsdbus-c++-dev
)

#specific branch or release
idle_tag="v0.1.2"

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_hypridle.log"
MLOG="${install_log_dir}/install-$(date +%d-%H%M%S)_hypridle2.log"

# Installation of dependencies
printf "\n%s - Installing ${YELLOW}hypridle dependencies${RESET} .... \n" "${INFO}"

for PKG1 in "${idle[@]}"; do
  re_install_package "$PKG1" 2>&1 | tee -a "$LOG"
  if [ $? -ne 0 ]; then
    echo -e "\e[1A\e[K${ERROR} - ${YELLOW}$PKG1${RESET} Package installation failed, Please check the installation logs"
  fi
done

# Check if hypridle directory exists and remove it
if [ -d "hypridle" ]; then
    rm -rf "hypridle"
fi

# Clone and build 
printf "${INFO} Installing ${YELLOW}hypridle $idle_tag${RESET} ...\n"
if git clone --recursive -b $idle_tag https://github.com/hyprwm/hypridle.git; then
    cd hypridle
	cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
	cmake --build ./build --config Release --target hypridle -j`nproc 2>/dev/null || getconf NPROCESSORS_CONF`
    if sudo cmake --install ./build 2>&1 | tee -a "$MLOG" ; then
        printf "${OK} ${MAGENTA}hypridle $idle_tag${RESET} installed successfully.\n" 2>&1 | tee -a "$MLOG"
    else
        echo -e "${ERROR} Installation failed for ${YELLOW}hypridle $idle_tag${RESET}" 2>&1 | tee -a "$MLOG"
    fi
    #moving the addional logs to ${install_log_dir} directory
    mv $MLOG ../${install_log_dir}/ || true 
    cd ..
else
    echo -e "${ERROR} Download failed for ${YELLOW}hypridle $idle_tag${RESET}" 2>&1 | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}

########################################################################
########################################################################
########################################################################
########################################################################
########################################################################
if [[ "$switching_to_sddm" == true ]];then
	########################################################################
	wayland_sessions_dir=/usr/share/wayland-sessions
	[ ! -d "$wayland_sessions_dir" ] && { printf "$CAT - $wayland_sessions_dir not found, creating...\n"; sudo mkdir -p "$wayland_sessions_dir" 2>&1 | tee -a "$LOG"; }
	sudo tee "$wayland_sessions_dir/hyprland.desktop" <<- 'EOF' >/dev/null 2>&1
		[Desktop Entry]
		Name=Hyprland
		Comment=An intelligent dynamic tiling Wayland compositor
		Exec=Hyprland
		Type=Application
	EOF
	
	echo "${INFO} Downloading & Installing ${SKY_BLUE}Additional SDDM theme...${RESET}" | tee -a "$LOG"
	# SDDM themes #
	
	source_theme="https://codeberg.org/JaKooLit/sddm-sequoia"
	theme_name="sequoia_2"
	
	# Set the name of the log file to include the current date and time
	LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_sddm_theme.log"
    	
	# SDDM-themes
	printf "${INFO} Installing ${SKY_BLUE}Additional SDDM Theme${RESET}\n"
	
	# Check if /usr/share/sddm/themes/$theme_name exists and remove if it does
	if [ -d "/usr/share/sddm/themes/$theme_name" ]; then
  	sudo rm -rf "/usr/share/sddm/themes/$theme_name"
  	echo -e "\e[1A\e[K${OK} - Removed existing $theme_name directory." 2>&1 | tee -a "$LOG"
	fi
	
	# Check if $theme_name directory exists in the current directory and remove if it does
	if [ -d "$theme_name" ]; then
  	rm -rf "$theme_name"
  	echo -e "\e[1A\e[K${OK} - Removed existing $theme_name directory from the current location." 2>&1 | tee -a "$LOG"
	fi
	
	# Clone the repository
	if git clone --depth=1 "$source_theme" "$theme_name"; then
  	if [ ! -d "$theme_name" ]; then
    	echo "${ERROR} Failed to clone the repository." | tee -a "$LOG"
  	fi
	
  	# Create themes directory if it doesn't exist
  	if [ ! -d "/usr/share/sddm/themes" ]; then
    	sudo mkdir -p /usr/share/sddm/themes
    	echo "${OK} - Directory '/usr/share/sddm/themes' created." | tee -a "$LOG"
  	fi
	
  	# Move cloned theme to the themes directory
  	sudo mv "$theme_name" "/usr/share/sddm/themes/$theme_name" 2>&1 | tee -a "$LOG"
	
  	# setting up SDDM theme
  	sddm_conf_dir="/etc/sddm.conf.d"
  	BACKUP_SUFFIX=".bak"
  	
  	echo -e "${NOTE} Setting up the login screen." | tee -a "$LOG"
	
  	if [ -d "$sddm_conf_dir" ]; then
    	echo "Backing up files in $sddm_conf_dir" | tee -a "$LOG"
    	for file in "$sddm_conf_dir"/*; do
      	if [ -f "$file" ]; then
        	if [[ "$file" == *$BACKUP_SUFFIX ]]; then
          	echo "Skipping backup file: $file" | tee -a "$LOG"
          	continue
        	fi
        	# Backup each original file
        	sudo cp "$file" "$file$BACKUP_SUFFIX" 2>&1 | tee -a "$LOG"
        	echo "Backup created for $file" | tee -a "$LOG"
        	
        	# Edit existing "Current=" 
        	if grep -q '^[[:space:]]*Current=' "$file"; then
          	sudo sed -i "s/^[[:space:]]*Current=.*/Current=$theme_name/" "$file" 2>&1 | tee -a "$LOG"
          	echo "Updated theme in $file" | tee -a "$LOG"
        	fi
      	fi
    	done
  	else
    	echo "$CAT - $sddm_conf_dir not found, creating..." | tee -a "$LOG"
    	sudo mkdir -p "$sddm_conf_dir" 2>&1 | tee -a "$LOG"
  	fi
	
  	if [ ! -f "$sddm_conf_dir/theme.conf.user" ]; then
    	echo -e "[Theme]\nCurrent = $theme_name" | sudo tee "$sddm_conf_dir/theme.conf.user" > /dev/null
    	
    	if [ -f "$sddm_conf_dir/theme.conf.user" ]; then
      	echo "Created and configured $sddm_conf_dir/theme.conf.user with theme $theme_name" | tee -a "$LOG"
    	else
      	echo "Failed to create $sddm_conf_dir/theme.conf.user" | tee -a "$LOG"
    	fi
  	else
    	echo "$sddm_conf_dir/theme.conf.user already exists, skipping creation." | tee -a "$LOG"
  	fi
	
  	# Replace current background from assets
  	sudo cp -r assets/sddm.png "/usr/share/sddm/themes/$theme_name/backgrounds/default" 2>&1 | tee -a "$LOG"
  	sudo sed -i 's|^wallpaper=".*"|wallpaper="backgrounds/default"|' "/usr/share/sddm/themes/$theme_name/theme.conf" 2>&1 | tee -a "$LOG"
	
  	printf "\n%.0s" {1..1}
  	printf "${NOTE} copying ${YELLOW}JetBrains Mono Nerd Font${RESET} to ${YELLOW}/usr/local/share/fonts${RESET} .......\n"
  	printf "${NOTE} necessary for the new SDDM theme to work properly........\n"
	
  	sudo mkdir -p /usr/local/share/fonts/JetBrainsMonoNerd && \
  	sudo cp -r "$HOME/.local/share/fonts/JetBrainsMonoNerd" /usr/local/share/fonts/JetBrainsMonoNerd
	
  	if [ $? -eq 0 ]; then
    	echo "Fonts copied successfully."
  	else
    	echo "Failed to copy fonts."
  	fi
	
  	fc-cache -fv 2>&1 | tee -a "$LOG"
	
  	printf "\n%.0s" {1..1}
  	
  	echo "${OK} - ${MAGENTA}Additional SDDM Theme${RESET} successfully installed." | tee -a "$LOG"
	
	else
	
  	echo "${ERROR} - Failed to clone the sddm theme repository. Please check your internet connection." | tee -a "$LOG" >&2
	fi
	
	
	printf "\n%.0s" {1..2}
fi
########################################################################
install_nvidia_driver
########################################################################
echo "${INFO} Installing ${SKY_BLUE}GTK themes...${RESET}" | tee -a "$LOG"
# GTK Themes & ICONS and  Sourcing from a different Repo #

engine=(
    unzip
    gtk2-engines-murrine
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_themes.log"


# installing engine needed for gtk themes
for PKG1 in "${engine[@]}"; do
    install_package "$PKG1" "$LOG"
done

# Check if the directory exists and delete it if present
if [ -d "GTK-themes-icons" ]; then
    echo "$NOTE GTK themes and Icons directory exist..deleting..." 2>&1 | tee -a "$LOG"
    rm -rf "GTK-themes-icons" 2>&1 | tee -a "$LOG"
fi

echo "$NOTE Cloning ${SKY_BLUE}GTK themes and Icons${RESET} repository..." 2>&1 | tee -a "$LOG"
if git clone --depth=1 https://github.com/JaKooLit/GTK-themes-icons.git ; then
    cd GTK-themes-icons
    chmod +x auto-extract.sh
    ./auto-extract.sh
    cd ..
    echo "$OK Extracted GTK Themes & Icons to ~/.icons & ~/.themes directories" 2>&1 | tee -a "$LOG"
else
    echo "$ERROR Download failed for GTK themes and Icons.." 2>&1 | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}
########################################################################
echo "${INFO} Adding user into ${SKY_BLUE}input group...${RESET}" | tee -a "$LOG"
# Adding users into input group #

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_input.log"

# Check if the 'input' group exists
if grep -q '^input:' /etc/group; then
    echo "${OK} ${MAGENTA}input${RESET} group exists."
else
    echo "${NOTE} ${MAGENTA}input${RESET} group doesn't exist. Creating ${MAGENTA}input${RESET} group..."
    sudo groupadd input
    echo "${MAGENTA}input${RESET} group created" >> "$LOG"
fi

# Add the user to the 'input' group
sudo usermod -aG input "$(whoami)"
echo "${OK} ${YELLOW}user${RESET} added to the ${MAGENTA}input${RESET} group. Changes will take effect after you log out and log back in." >> "$LOG"

printf "\n%.0s" {1..2}
########################################################################
echo "${INFO} Installing ${SKY_BLUE}AGS v1 for Desktop Overview...${RESET}" | tee -a "$LOG"
# Aylur's GTK Shell #

ags=(
    node-typescript 
    npm 
    meson 
    libgjs-dev 
    gjs 
    libgtk-layer-shell-dev 
    libgtk-3-dev
    libpam0g-dev 
    libpulse-dev 
    libdbusmenu-gtk3-dev 
    libsoup-3.0-dev
)

f_ags=(
    npm
)

build_dep=(
    pam
)

# specific tags to download
ags_tag="v1.9.0"

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_ags.log"
MLOG="${install_log_dir}/install-$(date +%d-%H%M%S)_ags2.log"

# Check if AGS is installed
if command -v ags &>/dev/null; then
    AGS_VERSION=$(ags -v | awk '{print $NF}') 
    if [[ "$AGS_VERSION" == "1.9.0" ]]; then
        printf "${INFO} ${MAGENTA}Aylur's GTK Shell v1.9.0${RESET} is already installed. Skipping installation."
        printf "\n%.0s" {1..2}
    fi
else
	# Installation of main components
	printf "\n%s - Installing ${SKY_BLUE}Aylur's GTK shell $ags_tag${RESET} Dependencies \n" "${INFO}"
	
	# Installing ags Dependencies
	for PKG1 in "${ags[@]}"; do
  	install_package "$PKG1" "$LOG"
	done
	
	for force_ags in "${f_ags[@]}"; do
   	re_install_package "$force_ags" 2>&1 | tee -a "$LOG"
  	done
	
	printf "\n%.0s" {1..1}
	
	for PKG1 in "${build_dep[@]}"; do
  	build_dep "$PKG1" "$LOG"
	done
	
	#install typescript by npm
	sudo npm install --global typescript 2>&1 | tee -a "$LOG"
	
	# ags v1
	printf "${NOTE} Install and Compiling ${SKY_BLUE}Aylur's GTK shell $ags_tag${RESET}..\n"
	
	# Check if directory exists and remove it
	if [ -d "ags" ]; then
    	printf "${NOTE} Removing existing ags directory...\n"
    	rm -rf "ags"
	fi
	
	printf "\n%.0s" {1..1}
	printf "${INFO} Kindly Standby...cloning and compiling ${SKY_BLUE}Aylur's GTK shell $ags_tag${RESET}...\n"
	printf "\n%.0s" {1..1}
	# Clone repository with the specified tag and capture git output into MLOG
	if git clone --depth=1 https://github.com/JaKooLit/ags_v1.9.0.git; then
    	cd ags_v1.9.0
    	npm install
    	meson setup build
   		if sudo meson install -C build 2>&1 | tee -a "$MLOG"; then
    		printf "\n${OK} ${YELLOW}Aylur's GTK shell $ags_tag${RESET} installed successfully.\n" 2>&1 | tee -a "$MLOG"
  		else
    		echo -e "\n${ERROR} ${YELLOW}Aylur's GTK shell $ags_tag${RESET} Installation failed\n " 2>&1 | tee -a "$MLOG"
   		fi
   		cd ..
	else
    	echo -e "\n${ERROR} Failed to download ${YELLOW}Aylur's GTK shell $ags_tag${RESET} Please check your connection\n" 2>&1 | tee -a "$LOG"
	fi
	
	printf "\n%.0s" {1..2}
fi
########################################################################
echo "${INFO} Installing ${SKY_BLUE}xdg-desktop-portal-hyprland...${RESET}" | tee -a "$LOG"
# XDG-Desktop-Portals for hyprland #

xdg=(
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
)

LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_xdph.log"

# Check if the file exists and remove it
[[ -f "/usr/lib/xdg-desktop-portal-hyprland" ]] && sudo rm "/usr/lib/xdg-desktop-portal-hyprland"

# XDG-DESKTOP-PORTAL-HYPRLAND
printf "${NOTE} Installing ${SKY_BLUE}xdg-desktop-portal-hyprland${RESET}\n\n" 
for xdgs in "${xdg[@]}"; do
  install_package "$xdgs" "$LOG"
done
    
printf "\n%.0s" {1..2}

########################################################################
echo "${INFO} Configuring ${SKY_BLUE}Bluetooth...${RESET}" | tee -a "$LOG"
# Bluetooth #

blue=(
  bluez
  blueman
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_bluetooth.log"

# Bluetooth
printf "${NOTE} Installing ${SKY_BLUE}Bluetooth${RESET} Packages...\n"
 for BLUE in "${blue[@]}"; do
   install_package "$BLUE" "$LOG"
  done

printf " Activating ${YELLOW}Bluetooth${RESET} Services...\n"
sudo systemctl enable --now bluetooth.service 2>&1 | tee -a "$LOG"

printf "\n%.0s" {1..2}

########################################################################
echo "${INFO} Installing ${SKY_BLUE}Thunar file manager...${RESET}" | tee -a "$LOG"
# Thunar #

thunar=(
  ffmpegthumbnailer
  thunar 
  thunar-volman 
  tumbler 
  thunar-archive-plugin
  xarchiver
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_thunar.log"

# Thunar
printf "${NOTE} Installing ${SKY_BLUE}Thunar${RESET} Packages...\n\n"  
  for THUNAR in "${thunar[@]}"; do
    install_package "$THUNAR" "$LOG"
  done

printf "\n%.0s" {1..1}
mkdir -p "/tmp/temptemp"

for DIR1 in gtk-3.0 Thunar xfce4; do
  DIRPATH=~/.config/$DIR1
  mv "$DIRPATH" /tmp/temptemp
  cp -r assets/$DIR1 ~/.config/ && echo "${OK} Copy $DIR1 completed!" || echo "${ERROR} Failed to copy $DIR1 config files." 2>&1 | tee -a "$LOG"
done

printf "\n%.0s" {1..2}

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_thunar-default.log"

printf "${INFO} Setting ${SKY_BLUE}Thunar${RESET} as default file manager...\n"  
 
xdg-mime default thunar.desktop inode/directory
xdg-mime default thunar.desktop application/x-wayland-gnome-saved-search
echo "${OK} ${MAGENTA}Thunar${RESET} is now set as the default file manager." | tee -a "$LOG"

printf "\n%.0s" {1..2}

########################################################################
echo "${INFO} Installing ${SKY_BLUE}zsh with Oh-My-Zsh...${RESET}" | tee -a "$LOG"
# Zsh and Oh my Zsh + Optional Pokemon ColorScripts#

zsh=(
  lsd
  zsh
  mercurial
  zplug
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_zsh.log"

# Check if the log file already exists, if yes, append a counter to make it unique
COUNTER=1
while [ -f "$LOG" ]; do
  LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_${COUNTER}_zsh.log"
  ((COUNTER++))
done

# Installing zsh packages
printf "${NOTE} Installing core zsh packages...${RESET}\n"
for ZSHP in "${zsh[@]}"; do
  install_package "$ZSHP"
done

printf "\n%.0s" {1..1}

# Install Oh My Zsh, plugins, and set zsh as default shell
if command -v zsh >/dev/null; then

  # Check if the current shell is zsh
  current_shell=$(basename "$SHELL")
  if [ "$current_shell" != "zsh" ]; then
    printf "${NOTE} Changing default shell to ${MAGENTA}zsh${RESET}..."
    printf "\n%.0s" {1..2}
    sudo chsh -s $(command -v zsh) $USER
    printf "${INFO} Shell changed successfully to ${MAGENTA}zsh${RESET}" 2>&1 | tee -a "$LOG"
  else
    echo "${NOTE} Your shell is already set to ${MAGENTA}zsh${RESET}."
  fi
  
  printf "${NOTE} Installing ${SKY_BLUE}Oh My Zsh and plugins${RESET} ...\n"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then  
    sh -c "$(curl -fsSL https://install.ohmyz.sh)" "" --unattended  	       
  else
    echo "${INFO} Directory .oh-my-zsh already exists. Skipping re-installation." 2>&1 | tee -a "$LOG"
  fi
  
  # Check if the directories exist before cloning the repositories
  if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
      git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 
  else
      echo "${INFO} Directory zsh-autosuggestions already exists. Cloning Skipped." 2>&1 | tee -a "$LOG"
  fi

  if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
      git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 
  else
      echo "${INFO} Directory zsh-syntax-highlighting already exists. Cloning Skipped." 2>&1 | tee -a "$LOG"
  fi
  
  # Check if ~/.zshrc and .zprofile exists, create a backup, and copy the new configuration
  if [ -f "$HOME/.zshrc" ]; then
      cp -b "$HOME/.zshrc" "$HOME/.zshrc-backup" || true
  fi

  if [ -f "$HOME/.zprofile" ]; then
      cp -b "$HOME/.zprofile" "$HOME/.zprofile-backup" || true
  fi
  
  # Copying the preconfigured zsh themes and profile
  sudo tee "$HOME/.zshrc" <<- 'EOF' >/dev/null 2>&1
		# If you come from bash you might have to change your $PATH.
		# export PATH=$HOME/bin:/usr/local/bin:$PATH
		
		export ZSH="$HOME/.oh-my-zsh"
		
		ZSH_THEME="agnosterzak"
		
		plugins=( 
    		git
    		zsh-autosuggestions
    		zsh-syntax-highlighting
		)
		
		source $ZSH/oh-my-zsh.sh
		
		
		# Display Pokemon-colorscripts
		# Project page: https://gitlab.com/phoneybadger/pokemon-colorscripts#on-other-distros-and-macos
		#pokemon-colorscripts --no-title -s -r #without fastfetch
		#pokemon-colorscripts --no-title -s -r | fastfetch -c $HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
		
		# fastfetch. Will be disabled if above colorscript was chosen to install
		fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc
		
		# Set-up icons for files/directories in terminal using lsd
		alias ls='lsd'
		alias l='ls -l'
		alias la='ls -a'
		alias lla='ls -la'
		alias lt='ls --tree'
	EOF
  sudo tee "$HOME/.zprofile" <<- 'EOF' >/dev/null 2>&1
	[ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ] &&  Hyprland 
	EOF
fi

# copy additional oh-my-zsh themes from assets
if [ -d "$HOME/.oh-my-zsh/themes" ]; then
    cp -r assets/add_zsh_theme/* ~/.oh-my-zsh/themes >> "$LOG" 2>&1
fi

printf "\n%.0s" {1..2}

########################################################################
echo "${INFO} Adding ${SKY_BLUE}Pokemon color scripts to terminal...${RESET}" | tee -a "$LOG"
# pokemon-color-scripts#
# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_zsh_pokemon.log"

printf "${INFO} Installing ${SKY_BLUE}Pokemon color scripts${RESET} ..."

if [ -d "pokemon-colorscripts" ]; then
    cd pokemon-colorscripts && git pull && sudo ./install.sh && cd ..
    else
    git clone --depth=1 https://gitlab.com/phoneybadger/pokemon-colorscripts.git &&
    cd pokemon-colorscripts && sudo ./install.sh && cd ..
fi

# Check if ~/.zshrc exists
if [ -f "$HOME/.zshrc" ]; then
	sed -i 's|^#pokemon-colorscripts --no-title -s -r \| fastfetch -c \$HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -|pokemon-colorscripts --no-title -s -r \| fastfetch -c \$HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -|' "$HOME/.zshrc" >> "$LOG" 2>&1
	sed -i "s|^fastfetch -c \$HOME/.config/fastfetch/config-compact.jsonc|#fastfetch -c \$HOME/.config/fastfetch/config-compact.jsonc|" "$HOME/.zshrc" >> "$LOG" 2>&1
else
    echo "$HOME/.zshrc not found. Cant enable ${YELLOW}Pokemon color scripts${RESET}" >> "$LOG" 2>&1
fi
  
printf "\n%.0s" {1..2}

########################################################################
echo "${INFO} Installing ${SKY_BLUE}ROG laptop packages...${RESET}" | tee -a "$LOG"
# ASUS ROG ) #

asus=(
  power-profiles-daemon
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/install-$(date +%d-%H%M%S)_rog.log"

# Installing enhancemet
for PKG1 in "${asus[@]}"; do
  install_package "$PKG1" 2>&1 | tee -a "$LOG"
  if [ $? -ne 0 ]; then
    echo -e "\033[1A\033[K${ERROR} - $PKG1 Package installation failed, Please check the installation logs"
  fi
done

printf " enabling power-profiles-daemon...\n"
sudo systemctl enable power-profiles-daemon 2>&1 | tee -a "$LOG"

# Function to handle the installation and log messages
install_and_log() {
  local project_name="$1"
  local git_url="$2"
  
  printf "${NOTE} Installing $project_name\n"

  if git clone "$git_url" "$project_name"; then
    cd "$project_name"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh 2>&1 | tee -a "$LOG"
    source "$HOME/.cargo/env"
    make

    if sudo make install 2>&1 | tee -a "$LOG"; then
      printf "${OK} $project_name installed successfully.\n"
      if [ "$project_name" == "supergfxctl" ]; then
        # Enable supergfxctl
        sudo systemctl enable --now supergfxd 2>&1 | tee -a "$LOG"
      fi
    else
      echo -e "${ERROR} Installation failed for $project_name."
    fi
    cd ..
  else
    echo -e "${ERROR} Cloning $project_name from $git_url failed."
  fi
}

# Download and build asusctl
install_and_log "asusctl" "https://gitlab.com/asus-linux/asusctl.git"

# Download and build supergfxctl
install_and_log "supergfxctl" "https://gitlab.com/asus-linux/supergfxctl.git"

printf "\n%.0s" {1..2}
########################################################################
echo "${INFO} Installing pre-configured ${SKY_BLUE}KooL Hyprland dotfiles...${RESET}" | tee -a "$LOG"
# Hyprland-Dots to download from main #

#specific branch or release
dots_tag="Deb-Untu-Dots"

# Check if Hyprland-Dots exists
printf "${NOTE} Cloning and Installing ${SKY_BLUE}KooL's Hyprland Dots for Debian${RESET}....\n"

# Check if Hyprland-Dots exists
if [ -d Hyprland-Dots-Debian ]; then
  cd Hyprland-Dots-Debian
  git stash && git pull
  chmod +x copy.sh
  ./copy.sh 
else
  if git clone --depth=1 -b $dots_tag https://github.com/JaKooLit/Hyprland-Dots Hyprland-Dots-Debian; then
    cd Hyprland-Dots-Debian
    chmod +x copy.sh
    ./copy.sh 
    cd ..
  else
    echo -e "$ERROR Can't download ${YELLOW}KooL's Hyprland-Dots-Debian${RESET}"
  fi
fi

printf "\n%.0s" {1..2}

########################################################################

# copy fastfetch config if debian is not present
if [ ! -f "$HOME/.config/fastfetch/debian.png" ]; then
    cp -r assets/fastfetch "$HOME/.config/"
fi

printf "\n%.0s" {1..2}
#######################################################################################
# final check essential packages if it is installed
# "03-Final-Check.sh"
#######################################################################################
# Final checking if packages are installed
# NOTE: These package checks are only the essentials

# Final checking if packages are installed
# NOTE: These package checks are only the essentials

packages=(
  imagemagick
  sway-notification-center
  waybar
  wl-clipboard
  cliphist
  wlogout
  kitty
  hyprland
)

# Local packages that should be in /usr/local/bin/
local_pkgs_installed=(
  rofi
  hypridle
  hyprlock
  wallust 
)

local_pkgs_installed_2=(
  swww
)

# Set the name of the log file to include the current date and time
LOG="${install_log_dir}/00_CHECK-$(date +%d-%H%M%S)_installed.log"

printf "\n%s - Final Check if Essential packages were installed \n" "${NOTE}"
# Initialize an empty array to hold missing packages
missing=()
local_missing=()
local_missing_2=()

# Function to check if a package is installed using dpkg
is_installed_dpkg() {
    dpkg -l | grep -q "^ii  $1 "
}

# Loop through each package
for pkg in "${packages[@]}"; do
    # Check if the package is installed via dpkg
    if ! is_installed_dpkg "$pkg"; then
        missing+=("$pkg")
    fi
done

# Check for local packages
for pkg1 in "${local_pkgs_installed[@]}"; do
    if ! [ -f "/usr/local/bin/$pkg1" ]; then
        local_missing+=("$pkg1")
    fi
done

# Check for local packages in /usr/bin
for pkg2 in "${local_pkgs_installed_2[@]}"; do
    if ! [ -f "/usr/bin/$pkg2" ]; then
        local_missing_2+=("$pkg2")
    fi
done

# Log missing packages
if [ ${#missing[@]} -eq 0 ] && [ ${#local_missing[@]} -eq 0 ] && [ ${#local_missing_2[@]} -eq 0 ]; then
    echo "${OK} GREAT! All ${YELLOW}essential packages${RESET} have been successfully installed." | tee -a "$LOG"
else
    if [ ${#missing[@]} -ne 0 ]; then
        echo "${WARN} The following packages are not installed and will be logged:"
        for pkg in "${missing[@]}"; do
            echo "$pkg"
            echo "$pkg" >> "$LOG" # Log the missing package to the file
        done
    fi

    if [ ${#local_missing[@]} -ne 0 ]; then
        echo "${WARN} The following local packages are missing from /usr/local/bin/ and will be logged:"
        for pkg1 in "${local_missing[@]}"; do
            echo "$pkg1 is not installed. can't find it in /usr/local/bin/"
            echo "$pkg1" >> "$LOG" # Log the missing local package to the file
        done
    fi

    if [ ${#local_missing_2[@]} -ne 0 ]; then
        echo "${WARN} The following local packages are missing from /usr/bin/ and will be logged:"
        for pkg2 in "${local_missing_2[@]}"; do
            echo "$pkg2 is not installed. can't find it in /usr/bin/"
            echo "$pkg2" >> "$LOG" # Log the missing local package to the file
        done
    fi

    # Add a timestamp when the missing packages were logged
    echo "${NOTE} Missing packages logged at $(date)" >> "$LOG"
fi

##############################################################################
sudo apt install -y network-manager-gnome

printf "\n%.0s" {1..1}

# Check if either hyprland or hyprland-git is installed
if dpkg -l | grep -qw hyprland; then
    printf "\n ${OK} 👌 Hyprland is installed. However, some essential packages may not be installed. Please see above!"
    printf "\n${CAT} Ignore this message if it states ${YELLOW}All essential packages${RESET} are installed as per above\n"
    sleep 2
    printf "\n%.0s" {1..2}

    printf "${SKY_BLUE}Thank you${RESET} 🫰 for using 🇵🇭 ${MAGENTA}KooL's Hyprland Dots${RESET}. ${YELLOW}Enjoy and Have a good day!${RESET}"
    printf "\n%.0s" {1..2}

    printf "\n${NOTE} You can start Hyprland by typing ${SKY_BLUE}Hyprland${RESET} (IF SDDM is not installed) (note the capital H!).\n"
	
	reboot_system
    
    # Check if NVIDIA GPU is present
    if lspci | grep -i "nvidia" &> /dev/null; then
    	echo "${INFO} HOWEVER ${YELLOW}NVIDIA GPU${RESET} detected. Reminder that you must REBOOT your SYSTEM..."
    	printf "\n%.0s" {1..1}
    fi
else
    # Print error message if neither package is installed
    printf "\n${WARN} Hyprland is NOT installed. Please check 00_CHECK-time_installed.log and other files in the ${install_log_dir}/ directory..."
    printf "\n%.0s" {1..3}
fi

printf "\n%.0s" {1..2}

