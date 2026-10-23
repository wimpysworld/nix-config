#!/usr/bin/env bash
# Pick one Mango layout for every tag on every monitor.
#
# The Nix wrapper sets these variables before this text:
#   layouts_file    the override file that Mango reads with source_optional.
#   default_layout  the Mango layout that applies without an override.
#
# A choice writes one tag_rule line to the override file, and Mango reloads
# its configuration when the file changes. The "Default" row removes the file.
# Each choice also sets the layout of the focused tag at once.

# Mango layout name, Mango layout symbol, and the menu label.
layouts="\
tile|T| Leftside
right_tile|RT| Rightside
center_tile|CT|󰜨 Centre Tile
vertical_tile|VT|󱢈 Vertical Tile
scroller|S|󰕬 Side Scroller
vertical_scroller|VS|󰕯 Vertical Scroller
grid|G|󰕰 Grid Top
vertical_grid|VG|󰕳 Grid Left
monocle|M|󰖯 Monocle
deck|K| Deck Right
vertical_deck|VK| Deck Bottom
dwindle|DW|󰕮 Dwindle
fair|F|󰕶 Fair Left
vertical_fair|VF|󰕵 Fair Top"

names=()
symbols=()
labels=()
while IFS="|" read -r name symbol label; do
	names+=("$name")
	symbols+=("$symbol")
	labels+=("$label")
done <<<"$layouts"

current=$(mmsg get all-monitors | jq -r '.monitors[] | select(.active) | .layout_symbol' | head -n 1 || true)

menu=""
selected=0
for i in "${!names[@]}"; do
	row="${labels[$i]}"
	if [ "${symbols[$i]}" = "$current" ]; then
		row="$row 󰄬"
		selected=$i
	fi
	menu="$menu$row\n"
done
default_index=${#names[@]}
menu="${menu}󰦛 Default"

choice=$(echo -e "$menu" |
	fuzzel --dmenu --index --prompt "󰹫 " --select-index="$selected" --lines=$((default_index + 1)) --width=24) || exit 0

layouts_dir=$(dirname "$layouts_file")

if [ "$choice" = "$default_index" ]; then
	rm -f "$layouts_file"
	mmsg dispatch "setlayout,$default_layout"
elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -lt "$default_index" ]; then
	name="${names[$choice]}"
	# Mango watches the directory of each included file only if that
	# directory exists when it loads the configuration, so a new directory
	# needs an explicit reload.
	reload=false
	if [ ! -d "$layouts_dir" ]; then
		mkdir -p "$layouts_dir"
		reload=true
	fi
	temporary=$(mktemp "$layouts_dir/.layouts.conf.XXXXXX")
	echo "tag_rule=id:*,layout_name:$name" >"$temporary"
	mv -f "$temporary" "$layouts_file"
	if [ "$reload" = true ]; then
		mmsg dispatch reload_config
	fi
	mmsg dispatch "setlayout,$name"
fi
