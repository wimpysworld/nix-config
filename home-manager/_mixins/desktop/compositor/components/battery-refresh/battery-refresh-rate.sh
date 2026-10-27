#!/usr/bin/env bash

on_battery() {
	local ac_online=0 has_battery=0 supply supply_type online
	for supply in /sys/class/power_supply/*; do
		[ -r "$supply/type" ] || continue
		read -r supply_type < "$supply/type"
		case "$supply_type" in
		Battery)
			has_battery=1
			;;
		Mains | USB)
			if [ -r "$supply/online" ]; then
				read -r online < "$supply/online"
				if [ "$online" = "1" ]; then
					ac_online=1
				fi
			fi
			;;
		esac
	done
	[ "$has_battery" = "1" ] && [ "$ac_online" = "0" ]
}

apply() {
	local battery=false outputs name mode
	if on_battery; then
		battery=true
	fi

	outputs=$(wlr-randr --json 2> /dev/null) || return 0
	while IFS=$'\t' read -r name mode; do
		[ -n "$name" ] && [ -n "$mode" ] || continue
		wlr-randr --output "$name" --mode "$mode" || true
	done < <(
		jq -r --argjson battery "$battery" '
			.[]
			| select(.enabled and (.name | test("^eDP")))
			| .name as $name
			| (.modes | map(select(.current))[0]) as $cur
			| select($cur != null)
			| (.modes | map(select(.width == $cur.width and .height == $cur.height))) as $same
			| (if $battery then
				if $cur.refresh > 65 then
					($same | map(select(.refresh >= 59 and .refresh <= 61)) | sort_by((.refresh - 60) | fabs)[0])
				else
					null
				end
			else
				if $cur.refresh <= 65 then
					($same | map(select(.refresh > 65)) | max_by(.refresh))
				else
					null
				end
			end) as $target
			| select($target != null)
			| "\($name)\t\($target.width)x\($target.height)@\($target.refresh * 1000 | round / 1000)Hz"
		' <<< "$outputs"
	)
}

apply
while read -r line; do
	case "$line" in
	UDEV*)
		while read -r -t 1 _; do :; done
		apply
		;;
	esac
done < <(udevadm monitor --udev --subsystem-match=power_supply)

exit 1
