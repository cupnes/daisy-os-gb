if [ "${INCLUDE_COMMON_SH+is_defined}" ]; then
	return
fi
INCLUDE_COMMON_SH=true

. include/lr35902.sh

MAP_FILE_NAME=include/map.sh

echo_2bytes() {
	local val=$1
	local top_half=$(echo $val | cut -c-2)
	local bottom_half=$(echo $val | cut -c3-4)
	echo -en "\x${bottom_half}\x${top_half}"
}

two_digits() {
	local val=$1
	local current_digits=$(echo -n $val | wc -m)
	case $current_digits in
	1)
		echo "0$val"
		;;
	2)
		echo $val
		;;
	*)
		echo "Error: Invalid digits: $val" 1>&2
		return 1
	esac
}

two_digits_d() {
	local opt
	local val_d
	if [ $# -lt 2 ]; then
		opt=''
		val_d=$1
	else
		opt=$1
		val_d=$2
	fi
	if [ $val_d -ge 128 ]; then
		if [ "$opt" != '--allow-ge-128' ]; then
			echo "Error: $val_d >= 128" 1>&2
			return 1
		fi
	fi
	local val=$(echo "obase=16;$val_d" | bc)
	two_digits $val
}

four_digits() {
	local val=$1
	local current_digits=$(echo -n $val | wc -m)
	case $current_digits in
	1)
		echo "000$val"
		;;
	2)
		echo "00$val"
		;;
	3)
		echo "0$val"
		;;
	4)
		echo $val
		;;
	*)
		echo "Error: Invalid digits: $val" 1>&2
		return 1
	esac
}

two_comp() {
	local val=$1
	local current_digits=$(echo -n $val | wc -m)
	if [ $current_digits -gt 2 ]; then
		echo "Error: Invalid digits: $val" 1>&2
		return 1
	fi
	local val_up=$(echo $val | tr [:lower:] [:upper:])
	echo "obase=16;ibase=16;100-${val_up}" | bc
}

two_comp_d() {
	local val=$1
	echo "obase=16;256-${val}" | bc
}

two_comp_4() {
	local val=$1
	local val_up=$(echo $val | tr [:lower:] [:upper:])
	echo "obase=16;ibase=16;10000-${val_up}" | bc
}

calc16() {
	local bc_form=$1
	local form_up=$(echo $bc_form | tr [:lower:] [:upper:])
	echo "obase=16;ibase=16;$form_up" | bc
}

calc16_2() {
	local bc_form=$1
	two_digits $(calc16 $bc_form)
}

# 負の値の場合は計算結果を2の補数で出力する
calc16_2_two_comp() {
	local bc_form=$1
	local val=$(calc16 $bc_form)
	if [ "${val:0:1}" = '-' ]; then
		two_comp $(echo $val | cut -c2-)
	else
		two_digits $val
	fi
}

to16() {
	local val=$1
	echo "obase=16;$val" | bc
}

busy_loop() {
	lr35902_rel_jump $(two_comp 02)
}

infinite_halt() {
	lr35902_halt
	lr35902_rel_jump $(two_comp 04)
}
