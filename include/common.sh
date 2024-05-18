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

# 指定されたレジスタの2の補数を求める
# in : 第1引数
#      - 2の補数を求める値が入っているレジスタ
#      - 結果で上書きされる
# work: regA
get_comp_of() {
	local reg=$1

	_flip_byte() {
		local reg=$1
		lr35902_copy_to_from regA $reg
		lr35902_complement_regA
		lr35902_copy_to_from $reg regA
	}

	case $reg in
	regA)
		lr35902_complement_regA
		;;
	regB|regC|regD|regE|regH|regL)
		_flip_byte $reg
		;;
	regBC|regDE|regHL)
		local reg_th="$(echo $reg | cut -c1-4)"
		local reg_bh="reg$(echo $reg | cut -c5)"
		local r
		for r in $reg_th $reg_bh; do
			_flip_byte $r
		done
		;;
	*)
		echo -n 'Error: invalid argument: ' 1>&2
		echo "get_comp_of $reg" 1>&2
		return 1
	esac
	lr35902_inc $reg
}

# 指定されたバイナリサイズ分の相対ジャンプの処理を1行で書くためのラッパー
# in : 第1引数
#      - NZ|Z|NC|C: 条件付きジャンプ
#      - 指定なし : 無条件ジャンプ
#      第1 or 2引数
#      - f|for|forward  : アドレスが大きくなる方向へジャンプ
#      - b|back|backward: アドレスが小さくなる方向へジャンプ
#      第2 or 3引数
#      - ジャンプする命令列が書かれたバイナリファイル(パイプ渡しも可)
#        - ここで指定したファイルに書かれている命令列が
#          第1引数が"f"の場合、相対ジャンプ命令の直後に、
#          第1引数が"b"の場合、相対ジャンプ命令の直前に出力される
rel_jump_wrapper_binsz() {
	local condition
	case $1 in
	NZ|Z|NC|C)
		condition=$1
		shift
		;;
	*)
		condition=''
		;;
	esac

	local direction=$1
	case $direction in
	f|'for'|forward)
		direction=forward
		;;
	b|back|backward)
		direction=backward
		;;
	*)
		echo "Error: Invalid direction argument: $direction" 1>&2
		return 1
	esac

	local bin_file
	if [ -p /dev/stdin ]; then
		bin_file=src/rel_jump_wrapper_binsz.tmp.o
		cat - >$bin_file
		trap "rm $bin_file" EXIT
	else
		bin_file=$2
	fi

	local sz_bin_file=$(stat -c '%s' $bin_file)

	local jump_ofs
	if [ "$direction" = 'forward' ]; then
		jump_ofs=$(two_digits_d $sz_bin_file)
		if [ -z "$condition" ]; then
			lr35902_rel_jump $jump_ofs
		else
			lr35902_rel_jump_with_cond $condition $jump_ofs
		fi
		cat $bin_file
	else
		cat $bin_file
		jump_ofs=$(two_comp_d $((sz_bin_file + 2)))
		if [ -z "$condition" ]; then
			lr35902_rel_jump $jump_ofs
		else
			lr35902_rel_jump_with_cond $condition $jump_ofs
		fi
	fi
}
