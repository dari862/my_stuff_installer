#!/usr/bin/env sh

# Desc:   Ncmpcpp triplet launcher.
# Author: Harry Kurn <alternate-se7en@pm.me>
# URL:    https://github.com/owl4ce/dotfiles/tree/ng/.config/ncmpcpp/scripts/launcher.sh

# SPDX-License-Identifier: ISC

# shellcheck disable=SC3044

SYSTEM_LANG="$LANG"
export LANG='POSIX'
NCMPCPP_DIR="${HOME}/.config/ncmpcpp"

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

# https://gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html#:~:text=expand_aliases
[ -z "$BASH" ] || shopt -s expand_aliases

MUSIC_PLAYER="$(cat "${music_player_path}")"

if [ "$MUSIC_PLAYER" = 'mpd' ]; then

    case "${1}" in
        '') LANG="$SYSTEM_LANG" my-terminal-emulator -e ncmpcpp -q
        ;;
        a*) LANG="$SYSTEM_LANG" my-terminal-emulator -g "${NCMPCPP_AA_LAUNCHER_GEOMETRY:-84x13}" \
                                                          -e ncmpcpp -c "${NCMPCPP_DIR}/album-art.config" \
                                                                     -q
        ;;
        s*) LANG="$SYSTEM_LANG" my-terminal-emulator -g "${NCMPCPP_SAA_LAUNCHER_GEOMETRY:-47x18}" \
                                                          -e ncmpcpp -c "${NCMPCPP_DIR}/single.album-art.config" \
                                                                     -q
        ;;
    esac

else

    dunstify 'Music Player' "Currently <u>${MUSIC_PLAYER}</u>!" -h string:synchronous:music-player \
                                                                -a joyful_desktop \
                                                                -i "$MUSIC_ICON" \
                                                                -u low

fi

exit ${?}
