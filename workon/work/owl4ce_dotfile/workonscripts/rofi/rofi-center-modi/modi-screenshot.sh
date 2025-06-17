#!/usr/bin/env sh

# Desc:   Custom screenshot modi for rofi.
# Author: Harry Kurn <alternate-se7en@pm.me>
# URL:    https://github.com/owl4ce/dotfiles/tree/ng/.config/rofi/scripts/custom-modi/modi-screenshot.sh

# SPDX-License-Identifier: ISC

# shellcheck disable=SC3044

export LANG='POSIX'
exec 2>/dev/null

ROW_ICON_FONT='feather 12'
MSG_ICON_FONT='feather 48'

A_='' A="<span font_desc='${ROW_ICON_FONT}' weight='bold'>${A_}</span>   Screen"
B_='' B="<span font_desc='${ROW_ICON_FONT}' weight='bold'>${B_}</span>   Select or Draw"
C_='' C="<span font_desc='${ROW_ICON_FONT}' weight='bold'>${C_}</span>   Countdown 5s"

case "${@}" in
    "$A") my-shots
    ;;
    "$B") my-shots --area
          return ${?}
    ;;
    "$C") my-shots --delay 5
    ;;
esac

MESSAGE="<span font_desc='${MSG_ICON_FONT}' weight='bold'></span>"

printf '%b\n' '\0use-hot-keys\037true' '\0markup-rows\037true' "\0message\037${MESSAGE}" \
              "$A" "$B" "$C"

exit ${?}
