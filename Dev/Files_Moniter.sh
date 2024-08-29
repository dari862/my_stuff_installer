#!/bin/bash
#set -e
_opt="$1"
version=1.0
script_url="https://raw.githubusercontent.com/dari862/my_linux/main/Dev/Files_Moniter.sh"

#===================================================================================
# Files Monitor
# FILE: Files_Monitor.sh
#===================================================================================

# Variables
script_name="$(basename "$0")"
install_file="/usr/bin/${script_name}"

processed_file_list_d="$HOME/.local/share/Files_Monitor"
processed_file_list="$processed_file_list_d/processed_file_list.txt"

config_file_d="$HOME/.config/My_Monitor"
telegram_config_file="$config_file_d/Telegram.conf"
forums_config_file="$config_file_d/Forums.conf"
telegrambot_config_file="$config_file_d/TelegramBot.conf"

autostart_path="$HOME/.config/autostart"

telegram_desktop_url="https://telegram.org/dl/desktop/linux"

#=== FUNCTIONS ==================================================================

# Function to display messages in plain color
plain() {
	#no color
	(( QUIET )) && return
	local mesg=$1; shift
	printf "\e[1;1m    ${mesg}\e[1;0m\n" "$@" >&1
}

# Function to display messages in green color
msg() {
    ((QUIET)) && return
    local mesg=$1
    shift
    printf "\e[1;1m\e[1;32m==>\e[1;0m\e[1;1m %s\e[1;0m\n" "$mesg" "$@" >&1
}

# Function to display warnings in yellow color
warning() {
    local mesg=$1
    shift
    printf "\e[1;1m\e[1;33m==> WARNING:\e[1;0m\e[1;1m %s\e[1;0m\n" "$mesg" "$@" >&2
}

# Function to display errors in red color
error() {
    local mesg=$1
    shift
    printf "\e[1;1m\e[1;31m==> ERROR:\e[1;0m\e[1;1m %s\e[1;0m\n" "$mesg" "$@" >&2
}

# Function to update script
update_script() {
	local script_current_path url_script_name download_path download_commnad  online_version
    script_current_path=$(realpath "$0")
    url_script_name="${script_url##*/}"
    download_path="/tmp/$url_script_name"  # Replace with your desired path
    download_commnad=""
    online_version=""
    [ -f "${download_path}" ] && rm "${download_path}"
	if command -v wget >/dev/null 2>&1; then
		download_commnad="wget -q -O $download_path $script_url"
	elif command -v curl >/dev/null 2>&1; then
		download_commnad="curl -s -o $download_path $script_url"
	else
        error "Neither wget nor curl found. Please install either of them."
        return 1
    fi
    
    if [ -f "$download_path" ]; then
    	rm "$download_path"
    fi
    
    msg "Downloading $download_path from $script_url ."
    $download_commnad
    
    if [ ! -f "$download_path" ]; then
    	error "$download_commnad        failed"
    	return 1
    fi
    
    online_version="$(sed -n "s/^version=\(.*\)/\1/p" "$download_path")"
    
  	if [ "$version" = "$online_version" ]; then
   		msg "Script is already up to date (version $version)."
   		return 0
   	elif (( $(echo "$version > $online_version" | bc -l) )); then
   		msg "Running script (version $version) is newer than online version (version $online_version)."
   		return 0
   	elif (( $(echo "$version < $online_version" | bc -l) )); then
   		msg "downloading new version (version $online_version)."
   		sudo chown root:root "$download_path"
    	sudo chmod +x "$download_path"
    	sudo rm "${install_file}"
    	sudo mv "$download_path" "${install_file}"
    	msg "Script updated successfully to version $online_version at $download_path!"
   	else
   		error "somthing is wrong"
   		return 0
	fi
}

# Function to check if another instance of the script is already running and kill it
check_and_kill_previous_instance() {
    local script_pid process_id_to_kill
	script_pid=$$
	process_id_to_kill=($(pgrep -f "$(basename "$0")" | grep -v "$script_pid"))
    if [[ ${#process_id_to_kill[@]} -gt 1 ]]; then
        warning "Another instance of the script is already running. Killing it..."
        for pid in "${process_id_to_kill[@]}"; do
            if ps -p "$pid" >/dev/null; then
                msg "Killing process with ID $pid..."
                kill "$pid"
            else
                warning "Process with ID $pid does not exist."
            fi
        done
        sleep 1
    fi
}


check_and_install_script() {
if [[ ! -f "$install_file" ]]; then
    warning "Script is not installed. Do you want to install it? (y/n)"
    read -r install_choice
    if [[ $install_choice == "y" ]]; then
	    if [[ $install_file != "$(readlink -f "$0")" ]]; then
        msg "Moving $(basename "$0") to $install_file"
        sudo mv "$0" "$install_file"
        sudo chmod +x "$install_file"
        sudo chown root:root "$install_file"
    	fi
    	  	
		# Check if the autostart dir exists
		if [[ ! -d "$autostart_path" ]]; then
			warning "$autostart_path does not exist. Creating a new one..."
			mkdir -p "$autostart_path"
		fi
		
    	if [[ "$_Telegram_" == true ]]; then
    		msg "Creating desktop in $autostart_path with Arg=T  to be autoruned on startup."
        	# Check if the dir $HOME/.config/autostart exists
			cat <<EOF > "$autostart_path/Telegram_Monitor.desktop"
[Desktop Entry]
Type=Application
Exec=x-terminal-emulator -e ${install_file} T
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Telegram_Monitor
Name=Telegram_Monitor
Comment[en_US]=Run Telegram_Monitor at startup
Comment=Run Telegram_Monitor to monitor telegram at startup
EOF
			chmod +x "$autostart_path/Telegram_Monitor.desktop"
		fi
		
		if [[ "$_forums_" == true ]]; then
			msg "Creating desktop in $autostart_path with Arg=F  to be autoruned on startup."
        	# Check if the dir $HOME/.config/autostart exists
			cat <<EOF > "$autostart_path/Forums_Monitor.desktop"
[Desktop Entry]
Type=Application
Exec=x-terminal-emulator -e ${install_file} F
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Forums_Monitor
Name=Forums_Monitor
Comment[en_US]=Run Forums_Monitor at startup
Comment=Run Forums_Monitor to monitor forums at startup
EOF
			chmod +x "$autostart_path/Forums_Monitor.desktop"
    		msg "Installation complete!"
    	fi
    else
        error "Script is not installed. Exiting..."
        exit 1
    fi
fi	
}

create_telegram_monitor_config_file(){
	warning "Config file does not exist. Creating a new one..."
	# create the config file
    while true; do
       	read -p -r "Enter the directory to monitor: " monitor_directory
       	if [[ -n $monitor_directory ]]; then
           	break
       	else
           	error "Monitor directory cannot be blank. Please try again."
       	fi
    done
	
    while true; do
       	read -p -r "Enter the directory to store processed files: " processed_telegram_file_directory
       	if [[ -n $processed_telegram_file_directory ]]; then
           	break
       	else
           	error "Processed Telegram file directory cannot be blank. Please try again."
       	fi
    done
	
    while true; do
       	read -p -r "Enter the interval_for_telegram_monitor in minutes: " interval_for_telegram_monitor
       	if [[ -n $interval_for_telegram_monitor ]]; then
           	break
       	else
           	error "interval for telegram monitor cannot be blank. Please try again."
       	fi
    done
    interval_for_telegram_monitor=$((interval_for_telegram_monitor * 60))
    # Prompt the user to enter true or false for sending as document
	while true; do
    	read -p -r "Send as document (true/false): " send_as_document
    	send_as_document=${send_as_document,,}  # Convert input to lowercase
		
   		if [[ "$send_as_document" == "true" || "$send_as_document" == "false" ]]; then
       		break  # Valid input, exit the loop
   		else
       		warning "Invalid input. Please enter either true or false."
   		fi
	done
		
	# Keep orignal containt or not
	while true; do
   		read -p -r "Keep orignal containt or not? (keep/delete): " keep_or_delete
   		keep_or_delete=${keep_or_delete,,}  # Convert input to lowercase
	
   		if [[ "$keep_or_delete" == "keep" || "$keep_or_delete" == "delete" ]]; then
       		break  # Valid input, exit the loop
   		else
       		warning "Invalid input. Please enter either true or false."
   		fi
	done
    # Create config file dir
   	mkdir -p "${config_file_d}"
				
   	echo "monitor_directory=$monitor_directory" >"$telegram_config_file"
   	echo "processed_telegram_file_directory=$processed_telegram_file_directory" >>"$telegram_config_file"
   	echo "interval_for_telegram_monitor=$interval_for_telegram_monitor" >>"$telegram_config_file"
   	echo "send_as_document=$send_as_document" >>"$telegram_config_file"
   	echo "keep_or_delete=$keep_or_delete" >>"$telegram_config_file"
}

source_and_check_create_telegram_monitor_folder() {
	msg "Sourcing config file."
	# Load config file
	source "$telegram_config_file"
	# Check if the monitor directory exists
	if [[ ! -d "$monitor_directory" ]]; then
		warning "Monitor directory does not exist: $monitor_directory"
		msg "Creating Monitor directory at: $monitor_directory"
		mkdir -p "$monitor_directory"
	fi

	# Check if the processed file directory exists
	if [[ ! -d "$processed_telegram_file_directory" ]]; then
		warning "Processed telegram file directory does not exist: $processed_telegram_file_directory"
		msg "Creating Processed file directory at: $processed_telegram_file_directory"
		mkdir -p "$processed_telegram_file_directory"
	fi

	# Check if the processed file list file exists
	if [[ ! -f "$processed_file_list" ]]; then
		warning "Processed file list file does not exist. Creating a new one..."			
		# Create processed file dir
		mkdir -p "${processed_file_list_d}"
		touch "$processed_file_list"
	fi
}

create_forums_monitor_config_file(){
	# Create config file dir
   	mkdir -p "${config_file_d}"
   	echo " " >"$forums_config_file"
}

source_and_check_create_forums_monitor_folder() {
	msg "Sourcing config file."
	# Load config file
	source "$forums_config_file"
}

create_and_source_telegrambot_config_file() {
	if [[ ! -f "$telegrambot_config_file" ]]; then
		warning "telegrambot config file file does not exist. Creating a new one..."
		# Telegram Bot API token
   		local API_TOKEN=""
		while true; do
       		read -p -r "Enter the API TOKEN: " API_TOKEN
       		if [[ -n $API_TOKEN ]]; then
           		break
       		else
           		error "Processed file directory cannot be blank. Please try again."
       		fi
   		done
			
		# Chat ID where you want to send the message
   		local CHAT_ID=""
		while true; do
       		read -p -r "Enter the CHAT ID: " CHAT_ID
       		if [[ -n $CHAT_ID ]]; then
           		break
       		else
           		error "Processed file directory cannot be blank. Please try again."
       		fi
   		done
	
   		echo "API_TOKEN=$API_TOKEN" >"$telegrambot_config_file"
   		echo "CHAT_ID=$CHAT_ID" >>"$telegrambot_config_file"
   		source "$telegrambot_config_file"
   	else
   		source "$telegrambot_config_file"
   	fi
}

check_and_create_files_and_folders() {
	# Check if the config file exists
	if [[ ! -f "$telegram_config_file"  && "$_Telegram_"  == true ]]; then
		create_telegram_monitor_config_file
	fi
	if [[ "$_Telegram_" == true ]]; then
		source_and_check_create_telegram_monitor_folder
	fi
	
	# Check if the config file exists
	if [[ ! -f "$forums_config_file"  && "$_forums_" == true ]]; then
		create_forums_monitor_config_file
	fi
	if [[ "$_forums_" == true ]]; then
		source_and_check_create_forums_monitor_folder
	fi
	
   	create_and_source_telegrambot_config_file
   	   	
   	msg "Config file created. Please edit it with appropriate values."	
}

# Function to send variable value to Telegram Bot API
send_file_to_telegram() {
	# Variable value to send
    local file_path
    file_path="$1"
    # Send the variable value to the Telegram Bot API
    curl -s -X POST "https://api.telegram.org/bot$API_TOKEN/sendDocument" -F "chat_id=$CHAT_ID" -F "document=@$file_path" &> /dev/null
    msg "Sending $file_path to Telegram group."
}

send_contain_to_telegram() {
	# Variable value to send
    local file_path
    file_path="$1"
    # Send the file contents value to the Telegram Bot API
    local file_contents
    file_contents=$(cat "$file_path")
    
    curl "https://api.telegram.org/bot$API_TOKEN/sendMessage" -d "chat_id=$CHAT_ID" -d "text=$file_contents" &> /dev/null
	msg "Sending contain of $file_path file to Telegram group."
}

# Function to install the script
check_and_install_telegram() {
	# Check if Telegram Desktop is already installed
	if [[ -f "/opt/Telegram/Telegram" ]]; then
		msg "Telegram Desktop is already installed."
	else
		# Determine the package manager
		if ! command -v apt-get &> /dev/null; then
			error "Package manager not found. Please install Telegram Desktop manually."
			exit 1
		fi

		# Install Telegram Desktop using the appropriate package manager
		if command -v wget &> /dev/null; then
			msg "Installing Telegram Desktop using wget..."
			wget -O telegram.tar.xz "$telegram_desktop_url"
		elif command -v curl &> /dev/null; then
			msg "Installing Telegram Desktop using curl..."
			sudo curl -L -o telegram.tar.xz "$telegram_desktop_url"
		else
			error "Neither wget nor curl found. Please install either wget or curl."
			exit 1
		fi
		tar -xf telegram.tar.xz
		rm telegram.tar.xz
		sudo mv Telegram /opt/
		if [[ ! -f "/usr/bin/telegram-desktop" ]]; then
			sudo ln -sf /opt/Telegram/Telegram /usr/bin/telegram-desktop
		fi
		if [[ ! -f "$autostart_path/autostart-telegram-desktop.desktop" ]]; then
			cat <<EOF > "$autostart_path/autostart-telegram-desktop.desktop"
[Desktop Entry]
Type=Application
Exec=/usr/bin/telegram-desktop
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=telegram-desktop
Name=telegram-desktop
Comment[en_US]=Run telegram-desktop at startup
Comment=Run telegram-desktop at startup
EOF
		fi
		msg "Telegram Desktop installed successfully."
	fi
}

monitor_telegram_groups_now() {		
	# Check if telegram installed
	check_and_install_telegram
	clear
	msg "Monitoring ( $monitor_directory ) started"
	# Main loop
	while true; do
    	# Check for new files in the monitor directory
    	new_files=()
    	while IFS= read -r -d '' file; do
    		file_name="$(basename "$file")"
    		if [ "$(find "$processed_telegram_file_directory" -type f -name "${file_name}")" ];then
    			echo "$file" >> "$processed_file_list"
    		else
        		if ! grep -qxF "$file" "$processed_file_list"; then
            		new_files+=("$file")
        		fi
        	fi
    	done < <(find "$monitor_directory" -type f -name "*.txt" -print0)
	
    	# Process new files
    	if [[ ${#new_files[@]} -gt 0 ]]; then
        	for file in "${new_files[@]}"; do
            	# Process the file (replace this with your own logic)
            	plain "Processing file: $file"
				date_now=$(date +"%H%M%S_%d%m%Y")
				grep_kw_result=$(grep -rE "\.kw:|\.kw/|\.kw\\" "$file")
            	if [[ -n $grep_kw_result ]]; then
            		grep_result_d="${processed_telegram_file_directory}/$date_now"
            		mkdir -p "$grep_result_d"
            		KW_file="${grep_result_d}/KW_${date_now}.txt"
            		GOV_file="${grep_result_d}/GOV_${date_now}.txt"
            		EDU_file="${grep_result_d}/EDU_${date_now}.txt"
            		tmp_file="${grep_result_d}/tmp"
                	echo "$grep_kw_result" >> "${KW_file}"
					grep_gov_result=$(grep -r '\.gov\.kw' "${KW_file}")
					if [[ -n $grep_gov_result ]]; then
						echo "$grep_gov_result" >> "${GOV_file}"
						# Remove lines from file 'KW_$date_now' that are present in file 'GOV_$date_now'
						grep -vFf "${GOV_file}" "${KW_file}" > "${tmp_file}" 
						rm "${KW_file}" 
						mv "${tmp_file}"  "${KW_file}"
						if [ "$send_as_document" == "true" ]; then
        					# Send the file as a document
        					send_file_to_telegram "${GOV_file}"
    					else
        					# Send the file contents as text
        					send_contain_to_telegram "${GOV_file}"
    					fi
					fi
	
					grep_edu_result=$(grep -r '\.edu\.kw' "${KW_file}")
					if [[ -n $grep_edu_result ]]; then
						echo "$grep_edu_result" >> "${EDU_file}"
						# Remove lines from file 'KW_$date_now' that are present in file 'EDU_$date_now'
						grep -vFf "${EDU_file}" "${KW_file}" > "${tmp_file}" 
						rm "${KW_file}" 
						mv "${tmp_file}"  "${KW_file}"
						if [ "$send_as_document" == "true" ]; then
        					# Send the file as a document
        					send_file_to_telegram "${EDU_file}"
    					else
        					# Send the file contents as text
        					send_contain_to_telegram "${GOV_file}"
    					fi
					fi	
					
            	fi
				# Add the processed file to the list
				echo "$file" >> "$processed_file_list"
				
				if [[ "$keep_or_delete" == "delete" ]]; then
        			rm "$file"
    			fi
        	done
    	fi
	
    	# Sleep for the specified interval_for_telegram_monitor
    	sleep "$interval_for_telegram_monitor"
	done
}

# Uninstall every thing
monitor_forums_now() {
	msg "monitor_forums_now"
}

# Uninstall every thing
Uninstall_every_thing() {
	warning "ARE YOU SURE YOU WANT TO DELETE EVERYTHING?"
	read -p -r "ARE YOU SURE YOU WANT TO DELETE EVERYTHING? (yes/no): " delete_every_thing
   	delete_every_thing="${delete_every_thing,,}"  # Convert input to lowercase
   	if [[ "$delete_every_thing" == "yes" ]]; then
		[ -f "$install_file" ] && sudo rm "$install_file"
		[ -f "$autostart_path/${script_name}.desktop" ] && rm "$autostart_path/${script_name}.desktop"
		[ -d "${config_file_d}" ] && rm -rdf "${config_file_d}"
		[ -d "${processed_file_list_d}" ] && rm -rdf "${processed_file_list_d}"
		[ -f "$autostart_path/autostart-telegram-desktop.desktop" ] && rm "$autostart_path/autostart-telegram-desktop.desktop"
		[ -d "/opt/Telegram" ] && sudo rm -rdf /opt/Telegram 
		[ -f "/usr/bin/telegram-desktop" ] && rm /usr/bin/telegram-desktop
	fi
}
# Show command help

function help() {
	echo -e 'monitoring Telegram and Forums for leaked password
Usage: '"$(basename "$0")"' [HTFBRU]
   \e[1mH\e[0m\tShow command help
   \e[1mT\e[0m\tInstall the script and create autostart for monitoring Telegram, then start it.
   \e[1mF\e[0m\tInstall the script and create autostart for monitoring Forums, then start it.
   \e[1mB\e[0m\tInstall the script and create autostart for monitoring Telegram and Forums, WITHOUT STARTING IT.
   \e[1mR\e[0m\tUninstall the script.
   \e[1mU\e[0m\tUpdate script.
	'
	exit 0
}

#=== MAIN =======================================================================

case $_opt in
	H) 	
		help
		;;
	
	T) 	
		_Telegram_=true 
		;;
	F) 
		_forums_=true
		;;
	B) 
		_Telegram_=true
		_forums_=true
		_Both_=true
		;;
	R) 
		_Uninstall_=true
		;;
	U) 
		_Update_=true
		;;
	*) 
		error "Invaled arguments."
		help
		;;
esac

# Check if the script is already running and kill previous instances
#check_and_kill_previous_instance

if [[ "$_Uninstall_" == true ]]; then
	# Uninstall every thing
	Uninstall_every_thing
fi

if [[ "$_Update_" == true ]]; then
	# Uninstall every thing
	update_script
fi

if [[ "$_Telegram_" == true || "$_forums_" == true ]]; then
	# Check if the script is already installed
	check_and_install_script
	
	# check_and_create_files_and_folders
	check_and_create_files_and_folders
fi

if [[ "$_Both_" == true ]]; then
	msg "Telegram and Forums Monitor Created."
	msg "Telegram and Forums Monitor Created."
	exit 0
fi

if [[ "$_Telegram_" == true ]]; then
	# monitor_telegram_now
	monitor_telegram_groups_now
fi

if [[ "$_forums_" == true ]]; then
	# monitor_forums_now
	monitor_forums_now
fi
