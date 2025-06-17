#!/usr/bin/env sh

# Desc:   Get hardware temperature for tint2 panel.
# Author: Harry Kurn <alternate-se7en@pm.me>

# SPDX-License-Identifier: ISC

# TEMP_DEV              || Temperature device, see "/sys/devices/virtual/thermal". #
TEMP_DEV='thermal_zone0'

export LANG='POSIX'
exec 2>/dev/null

TEMPERATURE_DEVICE="/sys/devices/virtual/thermal/${TEMP_DEV}"

if [ -f "${TEMPERATURE_DEVICE}/temp" ]; then

    IFS= read -r TEMP <"${TEMPERATURE_DEVICE}/temp"

    echo "$((TEMP/1000))˚C"

else
    echo "Invalid ${TEMPERATURE_DEVICE} interface!"
fi

exit ${?}
