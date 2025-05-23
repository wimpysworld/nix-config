#!/usr/bin/env bash
# A tool to pick colors from the screen using hyprpicker and fuzzel

set +u  # Disable nounset
APP_NAME="fuzzel-hyprpicker"
NOTIFY="notify-desktop --app-name=$APP_NAME --icon=org.gnome.design.Palette"

# Set up the storage directory and file
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APP_NAME"
HISTORY_FILE="$CONFIG_DIR/colors.txt"
HISTORY_NUM=10
ICONS_DIR="$CONFIG_DIR/icons"

# Create directories and history if they don't exist
mkdir -p "$ICONS_DIR"
touch "$HISTORY_FILE"

function create_eye_dropper_svg() {
  local color="#C8D1EE"
  local icon_path="$ICONS_DIR/eyedropper.svg"

  # Create an SVG for the eyedropper icon if it doesn't exist
  if [ ! -f "$icon_path" ]; then
    cat > "$icon_path" <<EOF
<svg fill="$color" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <g id="eyedropper">
    <path
      d="M223.99658,67.50391a35.73557,35.73557,0,0,0-11.26172-25.66114c-14.01806-13.2705-36.71875-12.771-50.60254,1.11328L140.18408,64.90479a24.02939,24.02939,0,0,0-33.15429.75195L100,72.68652a16.01779,16.01779,0,0,0,0,22.627l2.05908,2.05908L51.71533,147.71582a40.15638,40.15638,0,0,0-11.01074,35.771l-9.78271,22.40869a13.66329,13.66329,0,0,0,2.87744,15.21728,15.915,15.915,0,0,0,11.27929,4.70313,16.077,16.077,0,0,0,6.43555-1.353l20.999-9.16748a40.15391,40.15391,0,0,0,35.771-11.01123l50.34326-50.34326L160.68652,156a16.01779,16.01779,0,0,0,22.627,0l7.02978-7.02979a24.02843,24.02843,0,0,0,.752-33.15429l22.36036-22.36035A35.71726,35.71726,0,0,0,223.99658,67.50391ZM96.9707,192.9707a24.09567,24.09567,0,0,1-23.1914,6.21436,8.0052,8.0052,0,0,0-5.26416.39746L47.044,208.95605l9.37353-21.47119a8.00234,8.00234,0,0,0,.39746-5.26416,24.0986,24.0986,0,0,1,6.21436-23.1914L113.37256,108.686l33.9414,33.9414Z">
      id="eyedropper_path" />
  </g>
</svg>
EOF
  fi
}

function create_trash_svg() {
  local color="#C8D1EE"
  local icon_path="$ICONS_DIR/trash.svg"

  # Create an SVG for the eyedropper icon if it doesn't exist
  if [ ! -f "$icon_path" ]; then
    cat > "$icon_path" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<svg fill="$color" width="800px" height="800px" viewBox="0 0 256 256" id="Flat" xmlns="http://www.w3.org/2000/svg">
  <path d="M215.99609,48H176V40a24.02718,24.02718,0,0,0-24-24H104A24.02718,24.02718,0,0,0,80,40v8H39.99609a8,8,0,0,0,0,16h8V208a16.01833,16.01833,0,0,0,16,16h128a16.01833,16.01833,0,0,0,16-16V64h8a8,8,0,0,0,0-16ZM112,168a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Zm48,0a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Zm0-120H96V40a8.00917,8.00917,0,0,1,8-8h48a8.00917,8.00917,0,0,1,8,8Z"/>
</svg>
EOF
  fi
}

# Function to add a color to history
function add_color_to_history() {
  local color="$1"

  # Don't add duplicates
  if ! grep -q "^$color$" "$HISTORY_FILE"; then
    # Add to beginning of file
    echo "$color" > "$HISTORY_FILE.new"
    cat "$HISTORY_FILE" >> "$HISTORY_FILE.new"
    # Limit history to HISTORY_NUM entries
    head -n $HISTORY_NUM "$HISTORY_FILE.new" > "$HISTORY_FILE" && rm "$HISTORY_FILE.new"  
  fi
  HISTORY_LEN=$(wc -l < "$HISTORY_FILE")
}

# Function to generate color square .svg icon
function generate_svg_icon() {
  local color="$1"
  local icon_path="$ICONS_DIR/$color.svg"

  # Create an SVG for the color if it doesn't exist
  if [ ! -f "$icon_path" ]; then
    cat > "$icon_path" <<EOF
<svg width="128" height="128" xmlns="http://www.w3.org/2000/svg">
  <rect width="128" height="128" fill="#$color" />
</svg>
EOF
  fi
}

# Function to pick a color from screen
function pick_color() {
  sleep 0.5
  color=$(hyprpicker --format=hex --no-fancy --autocopy | tail -n 1)
  if [ -n "$color" ]; then
    $NOTIFY "Color Picker" "Color <span color=\"$color\">󰝤 $color</span> copied to clipboard."
    # Remove leading # if present
    color="${color#\#}"
    generate_svg_icon "$color"
    add_color_to_history "$color"
  fi
}

# Build menu options
function build_menu() {
  echo -e "Pick a color\0icon\x1f$ICONS_DIR/eyedropper.svg"
  # Add history items if they exist
  if [ -s "$HISTORY_FILE" ]; then
    while read -r color; do
      # If the preview icon doesn't exist, generate it
      if [ ! -e "$ICONS_DIR/$color.svg" ]; then
        generate_svg_icon "$color"
      fi
      # Display the color with a preview
      echo -e "#$color\0icon\x1f$ICONS_DIR/$color.svg"
    done < "$HISTORY_FILE"
  fi
  if [ "$HISTORY_LEN" -gt 0 ]; then
    echo -e "Clear history\0icon\x1f$ICONS_DIR/trash.svg"
  fi
}

create_eye_dropper_svg
create_trash_svg
HISTORY_LEN=$(wc -l < "$HISTORY_FILE")
selection=$(build_menu | fuzzel --dmenu --prompt="󰏘 " --lines=$((HISTORY_LEN + 2)) --width=24)
[[ -z "$selection" ]] && exit 0

if [[ "$selection" == "Pick a color"* ]]; then
  pick_color
elif [[ "$selection" == "Clear history"* ]]; then
  rm -f "$HISTORY_FILE"
  rm -f "$ICONS_DIR"/*.svg
  create_eye_dropper_svg
  create_trash_svg
  $NOTIFY "Color Picker" "History cleared."
else
  echo "$selection" | wl-copy --trim-newline
  $NOTIFY "Color Picker" "Color <span color=\"$selection\">󰝤 $selection</span> copied to clipboard."
fi
