#!/usr/bin/env bash

# The Nix wrapper sets these variables before this text:
#   wleave       the wleave executable.
#   config_home  an empty directory for XDG_CONFIG_HOME.
#   layout, css  the wleave layout and CSS files.
#
# wleave has no button size option, and its default margins are 20% of the
# output. Margins that centre a fixed band of logical pixels on the focused
# output give the six buttons one size on every output. The band is the
# Skrye layout: 1536x960, which gives 239x760 buttons with the CSS button
# margins. When the query fails, wleave keeps its default margins.

band_width=1536
band_height=960

margins=()
if focused=$(compositor-query focused-output) &&
	read -r _ width height _ <<<"$focused" &&
	[[ $width =~ ^[0-9]+$ && $height =~ ^[0-9]+$ ]]; then
	horizontal=$((width > band_width ? width - band_width : 0))
	vertical=$((height > band_height ? height - band_height : 0))
	margins=(
		--margin-left "$((horizontal / 2))"
		--margin-right "$((horizontal - horizontal / 2))"
		--margin-top "$((vertical / 2))"
		--margin-bottom "$((vertical - vertical / 2))"
	)
fi

exec env XDG_CONFIG_HOME="$config_home" "$wleave" \
	--no-version-info \
	--buttons-per-row 6 \
	"${margins[@]}" \
	--layout "$layout" \
	--css "$css" "$@"
