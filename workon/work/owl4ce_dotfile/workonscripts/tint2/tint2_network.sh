#!/usr/bin/env sh

# Desc:   Get network status for tint2 panel.
# Author: Harry Kurn <alternate-se7en@pm.me>

# SPDX-License-Identifier: ISC

# shellcheck disable=SC2166,SC2016

#-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~--~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-#
# Tint2 panel executor options for Interactive Mode                  ~ Auto-load ~ #
#-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~--~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-#
# IFACE_ET              || Ethernet interface, run `ifconfig` or `ip link` to see. #
# IFACE_WL              || Wireless interface, run `ifconfig` or `ip link` to see. #
#                       ||---------------------------------------------------------#
#-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~--~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-#

IFACE_ET='enp4s0'
IFACE_WL='wlan0'

export LANG='POSIX'
exec 2>/dev/null

[ -x "$(command -v iwgetid)" -o -x "$(command -v ip)" ] || exec echo 'Install `wireless-tools` and/or `iproute2`!'

if GET_WL="$(iwgetid "$IFACE_WL")" && [ -n "$GET_WL" ]; then

    ESSID="${GET_WL##*:\"}" ESSID="${ESSID%\"}"

    if [ -n "$ESSID" ]; then

        IP_WL="$(ip addr show "$IFACE_WL")"

        if [ -z "${IP_WL%%*inet*\ *}" ]; then
            ICON=''
            STAT="${ESSID} @ ${IFACE_WL}"
        else
            ICON=''
            STAT="No IP Address @ ${IFACE_WL}"
        fi

    else
        ICON=''
        STAT="Disconnected @ ${IFACE_WL}"
    fi

elif GET_ET="$(ip addr show "$IFACE_ET")" && [ -n "$GET_ET" ]; then

    IP_ET="${GET_ET##*inet\ }" IP_ET="${IP_ET%%\ brd*}"

    case "$IP_ET" in
        *'
'*       ) ICON=''
           STAT="No IP Address @ ${IFACE_ET}"
        ;;
        *) ICON=''
           STAT="${IP_ET} @ ${IFACE_ET}"
        ;;
    esac

else
    ICON=''
    STAT="Invalid \"${IFACE_WL}\" and \"${IFACE_ET}\" network interfaces"
fi

case "${1}" in
    icon) echo "$ICON"
    ;;
    sta*) echo "$STAT"
    ;;
esac

exit ${?}
