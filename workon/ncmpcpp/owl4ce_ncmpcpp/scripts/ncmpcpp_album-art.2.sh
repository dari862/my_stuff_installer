#!/usr/bin/env sh

# Desc:   Ncmpcpp album-art executor.
# Author: Harry Kurn <alternate-se7en@pm.me>
# URL:    https://github.com/owl4ce/dotfiles/tree/ng/.config/ncmpcpp/scripts/album-art.sh

# SPDX-License-Identifier: ISC

# shellcheck disable=SC2166,SC2086
. "/usr/share/my_stuff/lib/common/WM"
. "${Distro_config_file}"

export LANG='POSIX'
CHK_MPD_MUSIC_DIR="$(awk -F'"' '/music_directory/ {print $2}' "$HOME/.config/mpd/mpd.conf")"
CHK_MPD_PORT="$(awk -F'"' '/port/ {print $2}' "$HOME/.config/mpd/mpd.conf")"

#-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~--~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-#
# Ncmpcpp album-art options                                          ~ Auto-load ~ #
#-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~--~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-#
# NCMPCPP_AA_BACKEND    || Details about supported image backend described below.  #
#                       || *) Only supports 'w3m' and 'pixbuf' TE image backends.  #
#                       || *) Both backends on `rxvt-unicode` works like a charm.  #
#                       || *) 'pixbuf' backend is not portable, so may not works.  #
#                       ||---------------------------------------------------------#
# NCMPCPP_AA_NICENESS   || 0-19 or leave it blank, it reduces CPU% of 'w3m' loop.  #
#                       ||---------------------------------------------------------#
# NCMPCPP_{,S}AA_LAUNC* || Override ncmpcpp and single album-art geometry pixels.  #
#-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~--~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-#

TMP_DIR='/tmp'

NCMPCPP_AA_IMG="${TMP_DIR}/ncmpcpp.album-art.png"
NCMPCPP_AA_PID="${NCMPCPP_AA_IMG%.*}.pid"
NCMPCPP_AA_BACKEND='w3m'
NCMPCPP_AA_NICENESS='19'
NCMPCPP_AA_LAUNCHER_GEOMETRY='84x13'
NCMPCPP_SAA_LAUNCHER_GEOMETRY='47x18'
LIBS_PATH=" \
/usr/lib \
/usr/lib64 \
/usr/libexec \
/usr/libexec64 \
/usr/local/lib \
/usr/local/lib64 \
/usr/local/libexec \
/usr/local/libexec64 \
${HOME}/.nix-profile/lib \
${HOME}/.nix-profile/lib64 \
${HOME}/.nix-profile/libexec \
${HOME}/.nix-profile/libexec64 "

[ -x "$(command -v mpd)" -a -x "$(command -v mpc)" -a -x "$(command -v convert)" ] || exit ${?}

[ -z "$NCMPCPP_AA_NICENESS" ] || renice -n "$NCMPCPP_AA_NICENESS" "${$}" >&2

w3m()
{
    [ -x "$(command -v xdotool)" ] || exec printf '\033c%s' 'error: xdotool is not installed!'

    WINDOWID="${WINDOWID:-$(xdotool getactivewindow)}"

    echo "${$}" >"$NCMPCPP_AA_PID"

    read -r W3M_IMG_DISPLAY <<- EOF
		$(find ${LIBS_PATH} -type f -path '*/w3m/*' -name 'w3mimg*')
	EOF

    while IFS= read -r P <"$NCMPCPP_AA_PID" && [ "${P:-0}" -eq "${$}" ]; do

        eval "$(xdotool getwindowgeometry --shell "$WINDOWID")"

        if [ -n "$WIDTH" ]; then

            WIDTH="$(printf '%.f\n' "$((${WIDTH}000000/EFLOAT))e-3")"

            "${W3M_IMG_DISPLAY:-break}" >&2 <<- IMG
				0;1;0;0;${WIDTH};${WIDTH};;;;;${NCMPCPP_AA_IMG}
				3;
			IMG

            WIDTH=

        else
            sleep .022s
            printf '\033c%s' 'error: invalid window geometry. Relaunch!'
        fi

    done
}

pixbuf()
{
    printf '\033]20;%s;%s:op=keep-aspect\007' "$NCMPCPP_AA_IMG" "${GPX}x${GPX}+${OFF}+${OFF}"
}

{
    case "${1}" in
        '') exit ${?}
        ;;
        a*) EFLOAT='3521' GPX='67' OFF='00'
        ;;
        s*) EFLOAT='1166' GPX='86' OFF='04'
        ;;
    esac

    FILE="$(mpc -p "$CHK_MPD_PORT" -f '%file% ########## %album%' current)"

    [ -n "${FILE%/*\ #####\ *}" ] || exit ${?}

    [ -n "${CHK_MPD_MUSIC_DIR%%~*}" ] || CHK_MPD_MUSIC_DIR="${HOME}/${CHK_MPD_MUSIC_DIR#~*/}"

    read -r ALBUM_COVER <<- EOF
		$(find "${CHK_MPD_MUSIC_DIR}/${FILE%/*\ #####\ *}/" -maxdepth 1 \
															-type f \
															-iregex \
		".*/.*\(${FILE##*\ #####\ }\|cover\|folder\|artwork\|front\).*[.]\(jpe?g\|png\|gif\|bmp\)")
	EOF

    if [ -f "$ALBUM_COVER" ]; then

        convert "$ALBUM_COVER" \
               -strip \
               -interlace Plane \
               -scale 500x500\! \
               -depth 8 \
           '(' -clone 0 \
               -alpha extract \
               -draw 'fill black polygon 0,0 0,6 6,0 fill white circle 6,6 6,0' \
           '(' -clone 0 \
               -flip \
           ')' -compose Multiply \
               -composite \
           '(' -clone 0 \
               -flop \
           ')' -compose Multiply \
               -composite \
           ')' -alpha off \
               -compose CopyOpacity \
               -composite \
               -quality 9 \
        "$NCMPCPP_AA_IMG" \
        || convert -depth 8 canvas:transparent "PNG8:${NCMPCPP_AA_IMG}"

    else
        convert -depth 8 canvas:transparent "PNG8:${NCMPCPP_AA_IMG}"
    fi

    [ ! -f "$NCMPCPP_AA_IMG" ] || "$NCMPCPP_AA_BACKEND"
} &

exit ${?}
