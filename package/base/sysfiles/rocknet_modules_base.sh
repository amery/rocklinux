
if="none"
declare -a auto_if=()
auto_if[0]="*"

public_auto() {
	auto_if=()
	for x in "$@"; do
		a="${x%(*}"; b="${x#*(}"
		b="${b#)}"; b="${b//,/ }"
		if [ "$a" = "$b" ]; then
			auto_if[${#auto_if[*]}]="$a"
		else
			for x in $b; do
				[ "$x" = "$profile" ] && \
					auto_if[${#auto_if[*]}]="$a"
			done
		fi
	done
}

public_interface() {
	ignore=1 if="${1%(*}"
	local prof="${1#*(}"
	prof="${prof/)}"; prof="${prof//,/ }"

	if [ "$if" = "$prof" ]; then
		ignore=0
	else
		for x in $prof; do
			[ "$x" = "$profile" ] && ignore=0
		done
	fi

	if [ "$ignore" = 0 ]; then
		if [ "$if" = "auto" ]; then
			ignore=1
			for x in "${auto_if[@]}"; do
				[[ "$if" == $x ]] && ignore=0
			done
		else
			[ "$if" = "$interface" ] || ignore=1
		fi
	fi
}

