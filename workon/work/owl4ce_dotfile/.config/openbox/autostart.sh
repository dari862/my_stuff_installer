#!/usr/bin/env sh
#
# These things are run when an Openbox X Session is started.
# You may place a similar script in "${HOME}/.config/openbox/autostart" to run user-specific things.
#
# https://github.com/owl4ce/dotfiles
#
# shellcheck disable=SC3044,SC2091,SC2086
# ---

exec >/dev/null 2>&1
. "${Distro_config_file}"
. "${HOME}/workonscripts/toggle_lib.sh"

#{ pidof -s pulseaudio -q || pulseaudio --start --log-target=syslog; } &
killall tint2 dunst -q &

joyd_user_interface_set

joyd_tray_programs exec

/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1

# Any additions should be added below.
