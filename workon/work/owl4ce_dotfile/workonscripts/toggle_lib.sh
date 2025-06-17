#!/usr/bin/env sh

joyd_tray_programs()
{
	. "${Distro_config_file}"
    [ -n "${1}" ] || return ${?}

    grep -Fv '#' "$OB_TRAY" | while IFS= read -r TRAY; do
        [ -x "$(command -v "${TRAY%%\ *}")" ] || continue
        case "${1}" in
            exec) pidof -s "${TRAY%%\ *}" -q \
                  || eval "\${TRAY}   >/dev/null  2>&1 &"
            ;;
            kill) pidof -s "${TRAY%%\ *}" -q \
                  && eval "killall -9 \${TRAY%%\ *} -q &"
            ;;
        esac
    done
}

joyd_run_theme()
{
    cat "${DUNST_DIR}/global" "${DUNST_DIR}/${CHK_THEME}.${CHK_MODE}.dunstrc" > "${DUNST_DIR}/dunstrc"
	LANG="$SYSTEM_LANG" dunst -config "${DUNST_DIR}/dunstrc" &
		
	[ "${1-}" = "without_wallpaper" ] || nitrogen --force-setter=xwindows --set-zoom-fill --save "${CHK_WALLPAPER_DIR}/${CHK_WALLPAPER}"  &

	case "$CHK_MODE" in
		art*) LANG="$SYSTEM_LANG" tint2 -c "${TINT2_DIR}/${CHK_THEME}-${CHK_PANEL_ORT}.artistic.tint2rc" & ;;
		int*) LANG="$SYSTEM_LANG" tint2 -c "${TINT2_DIR}/${CHK_THEME}-top.interactive.tint2rc" & ;;
	esac
}

joyd_user_interface_set()
{
	. "${Distro_config_file}"
	openbox --reconfigure &
	owl4ce_scripts terminal &    
    joyd_run_theme "${1-}"
}
