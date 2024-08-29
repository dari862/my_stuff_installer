#!/usr/bin/env zsh

set -o errexit -o nounset
setopt BRACE_CCL

if [[ $(uname -s) == "Darwin" ]]; then
    rm -f ~/.config/waybar/style.css
    exit 0
fi

if type "sass" >/dev/null; then
    command="sass"
elif type "sassc" >/dev/null; then
    command="sassc"
else
    echo "Install SASS or SASSC to compile the Waybar SCSS style file."
    exit 1
fi

"$command" ~/.config/waybar/style.{scss,css}
