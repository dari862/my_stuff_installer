#!/bin/sh

## Copyright (C) 2020-2021 Aditya Shakya <adi1090x@gmail.com>
## Everyone is permitted to copy and distribute copies of this file under GNU-GPL3

export FIFO_UEBERZUG="/tmp/$USER/mpd-ueberzug-${PPID}"

cleanup() {
    rm "$FIFO_UEBERZUG" 2>/dev/null
    rm /tmp/$USER/mpd_cover.jpg 2>/dev/null
    pkill -P $$ 2>/dev/null
    pkill album-art
}

pkill -P $$ 2>/dev/null
rm "$FIFO_UEBERZUG" 2>/dev/null
mkfifo "$FIFO_UEBERZUG" >/dev/null
trap cleanup EXIT 2>/dev/null
tail --follow "$FIFO_UEBERZUG" | ueberzug layer --silent --parser simple >/dev/null 2>&1 &

ncmpcpp -c ~/.config/ncmpcpp/config-art
cleanup
