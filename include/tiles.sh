if [ "${INCLUDE_TILES_SH+is_defined}" ]; then
	return
fi
INCLUDE_TILES_SH=true

GBOS_TILE_BYTES=10	# 一つのタイルは16バイト(0x10)

GBOS_CTRL_CHR_NL=0a
GBOS_CTRL_CHR_NULL=ff

GBOS_TILE_NUM_SPC=00
GBOS_TILE_NUM_UPPER_LEFT_BAR=01
GBOS_TILE_NUM_UPPER_BAR=02
GBOS_TILE_NUM_UPPER_RIGHT_BAR=03
GBOS_TILE_NUM_RIGHT_BAR=04
GBOS_TILE_NUM_LOWER_RIGHT_BAR=05
GBOS_TILE_NUM_LOWER_BAR=06
GBOS_TILE_NUM_LOWER_LEFT_BAR=07
GBOS_TILE_NUM_LEFT_BAR=08
GBOS_TILE_NUM_BLACK=09
GBOS_TILE_NUM_LIGHT_GRAY=0a
GBOS_TILE_NUM_FUNC_BTN=0b
GBOS_TILE_NUM_MINI_BTN=0c
GBOS_TILE_NUM_MAXI_BTN=0d
GBOS_TILE_NUM_CSL=0e
GBOS_TILE_NUM_UP_ARROW=12
GBOS_TILE_NUM_DOWN_ARROW=13
GBOS_TILE_NUM_NUM_BASE=14
GBOS_TILE_NUM_ALPHA_BASE=1E	# 大文字指定
GBOS_TILE_NUM_OPEN_BRACKET=48
GBOS_TILE_NUM_CLOSE_BRACKET=49
GBOS_TILE_NUM_ATMARK=4a
GBOS_TILE_NUM_DAKUTEN=4b
GBOS_TILE_NUM_HIRA_BASE=4C
GBOS_TILE_NUM_HIRA_A=4c
GBOS_TILE_NUM_HIRA_I=4d
GBOS_TILE_NUM_HIRA_U=4e
GBOS_TILE_NUM_HIRA_O=50
GBOS_TILE_NUM_HIRA_KA=51
GBOS_TILE_NUM_HIRA_KI=52
GBOS_TILE_NUM_HIRA_KU=53
GBOS_TILE_NUM_HIRA_KE=54
GBOS_TILE_NUM_HIRA_KO=55
GBOS_TILE_NUM_HIRA_SA=56
GBOS_TILE_NUM_HIRA_SHI=57
GBOS_TILE_NUM_HIRA_SU=58
GBOS_TILE_NUM_HIRA_SE=59
GBOS_TILE_NUM_HIRA_TA=5b
GBOS_TILE_NUM_HIRA_CHI=5c
GBOS_TILE_NUM_HIRA_TSU=5d
GBOS_TILE_NUM_HIRA_TE=5e
GBOS_TILE_NUM_HIRA_TO=5f
GBOS_TILE_NUM_HIRA_NA=60
GBOS_TILE_NUM_HIRA_NI=61
GBOS_TILE_NUM_HIRA_NO=64
GBOS_TILE_NUM_HIRA_FU=67
GBOS_TILE_NUM_HIRA_HA=65
GBOS_TILE_NUM_HIRA_HI=66
GBOS_TILE_NUM_HIRA_HE=68
GBOS_TILE_NUM_HIRA_HO=69
GBOS_TILE_NUM_HIRA_MA=6a
GBOS_TILE_NUM_HIRA_MI=6b
GBOS_TILE_NUM_HIRA_MU=6c
GBOS_TILE_NUM_HIRA_MO=6e
GBOS_TILE_NUM_HIRA_YA=6f
GBOS_TILE_NUM_HIRA_YU=70
GBOS_TILE_NUM_HIRA_YO=71
GBOS_TILE_NUM_HIRA_RA=72
GBOS_TILE_NUM_HIRA_RI=73
GBOS_TILE_NUM_HIRA_RU=74
GBOS_TILE_NUM_HIRA_RE=75
GBOS_TILE_NUM_HIRA_WA=77
GBOS_TILE_NUM_HIRA_WO=78
GBOS_TILE_NUM_HIRA_N=79
GBOS_TILE_NUM_HANDAKUTEN=7a
GBOS_TILE_NUM_TOUTEN=7b
GBOS_TILE_NUM_KUTEN=7c
GBOS_TILE_NUM_EXCLAMATION=7d
GBOS_TILE_NUM_QUESTION=7e
GBOS_TILE_NUM_DASH=7f
GBOS_TILE_NUM_PERIOD=80
GBOS_TILE_NUM_SLASH=81
GBOS_TILE_NUM_COLON=82
GBOS_TILE_NUM_UNDERBAR=83
GBOS_TILE_NUM_RIGHT_ARROW=84
GBOS_TILE_NUM_LEFT_ARROW=85
GBOS_TILE_NUM_PLUS=87
GBOS_TILE_NUM_EQUAL=88
GBOS_TILE_NUM_OPEN_BRACKET_JA=89
GBOS_TILE_NUM_CLOSE_BRACKET_JA=8a
GBOS_TILE_NUM_CELL=8b
GBOS_TILE_NUM_DAISY_WHITE=8c
GBOS_TILE_NUM_DAISY_BLACK=8d
GBOS_TILE_NUM_PREDATOR=8e
# INSERT_GBOS_TILE_NUM

GBOS_TYPE_ICON_TILE_BASE=38
GBOS_NUM_ICON_TILES=04

GBOS_ICON_NUM_EXE=01
GBOS_ICON_NUM_TXT=02
GBOS_ICON_NUM_IMG=03

get_num_tile_num() {
	local n=$1
	echo "obase=16;ibase=16;$GBOS_TILE_NUM_NUM_BASE + $n" | bc
}

ASCII_A_HEX=41
get_alpha_tile_num() {
	local ch=$1
	ch=${ch^^}	# 大文字化
	local ascii_num_hex=$(echo -n $ch | hexdump -e '1/1 "%02X"')
	local ascii_ofs_hex=$(echo "obase=16;ibase=16;$ascii_num_hex - $ASCII_A_HEX" | bc)
	echo "obase=16;ibase=16;$GBOS_TILE_NUM_ALPHA_BASE + $ascii_ofs_hex" | bc
}

UTF8_HIRA_A_HEX=E38182
UTF8_HIRA_KA_HEX=E3818B
UTF8_HIRA_TSU_HEX=E381A4
UTF8_HIRA_NI_HEX=E381AB
UTF8_HIRA_HI_HEX=E381B2
UTF8_HIRA_MU_HEX=E38280
UTF8_HIRA_YA_HEX=E38284
UTF8_HIRA_RA_HEX=E38289
get_hira_tile_num() {
	local ch=$1
	local utf8_num_hex=$(echo -n $ch | hexdump -v -e '1/1 "%X"')
	local ofs_hex
	case "$utf8_num_hex" in
	# あいうえお
	E3818[2468A])
		ofs_hex=$(bc <<< "obase=16;ibase=16;($utf8_num_hex - $UTF8_HIRA_A_HEX) / 2")
		bc <<< "obase=16;ibase=16;${GBOS_TILE_NUM_HIRA_A^^} + $ofs_hex"
		;;
	# かきくけこさしすせそたち
	E3818[BDF] | E3819[13579BDF] | E381A1)
		ofs_hex=$(bc <<< "obase=16;ibase=16;($utf8_num_hex - $UTF8_HIRA_KA_HEX) / 2")
		bc <<< "obase=16;ibase=16;${GBOS_TILE_NUM_HIRA_KA^^} + $ofs_hex"
		;;
	# つてとな
	E381A[468A])
		ofs_hex=$(bc <<< "obase=16;ibase=16;($utf8_num_hex - $UTF8_HIRA_TSU_HEX) / 2")
		bc <<< "obase=16;ibase=16;${GBOS_TILE_NUM_HIRA_TSU^^} + $ofs_hex"
		;;
	# にぬねのは
	E381A[BCDEF])
		ofs_hex=$(bc <<< "obase=16;ibase=16;$utf8_num_hex - $UTF8_HIRA_NI_HEX")
		bc <<< "obase=16;ibase=16;${GBOS_TILE_NUM_HIRA_NI^^} + $ofs_hex"
		;;
	# ひふへほま
	E381B[258BE])
		ofs_hex=$(bc <<< "obase=16;ibase=16;($utf8_num_hex - $UTF8_HIRA_HI_HEX) / 3")
		bc <<< "obase=16;ibase=16;${GBOS_TILE_NUM_HIRA_HI^^} + $ofs_hex"
		;;
	# み
	E381BF)
		echo ${GBOS_TILE_NUM_HIRA_MI^^}
		;;
	# むめも
	E3828[012])
		ofs_hex=$(bc <<< "obase=16;ibase=16;$utf8_num_hex - $UTF8_HIRA_MU_HEX")
		bc <<< "obase=16;ibase=16;${GBOS_TILE_NUM_HIRA_MU^^} + $ofs_hex"
		;;
	# やゆよ
	E3828[468])
		ofs_hex=$(bc <<< "obase=16;ibase=16;($utf8_num_hex - $UTF8_HIRA_YA_HEX) / 2")
		bc <<< "obase=16;ibase=16;${GBOS_TILE_NUM_HIRA_YA^^} + $ofs_hex"
		;;
	# らりるれろ
	E3828[9ABCD])
		ofs_hex=$(bc <<< "obase=16;ibase=16;$utf8_num_hex - $UTF8_HIRA_RA_HEX")
		bc <<< "obase=16;ibase=16;${GBOS_TILE_NUM_HIRA_RA^^} + $ofs_hex"
		;;
	# わ
	E3828F)
		echo ${GBOS_TILE_NUM_HIRA_WA^^}
		;;
	# を
	E38292)
		echo ${GBOS_TILE_NUM_HIRA_WO^^}
		;;
	# ん
	E38293)
		echo ${GBOS_TILE_NUM_HIRA_N^^}
		;;
	*)
		echo "Error: invalid character $ch" 1>&2
		return 1
		;;
	esac
}

# 指定された文字のタイル番号を取得
# in : 第1引数  - 文字
#                 ※ 対応するタイルが存在すること
#                 ※ 罫線には未対応
#                    ∵ 上下左右の線に対応する文字が無いのと、
#                       罫線を描くなら「矩形を描画する関数」とかの方が良いため
# out: 標準出力 - タイル番号
get_tile_num() {
	local ch="$1"
	case "$ch" in
	' ')
		echo $GBOS_TILE_NUM_SPC
		;;
	# 黒で8x8を塗りつぶす(他の文字の様な字間無し)
	'■')
		echo $GBOS_TILE_NUM_BLACK
		;;
	# 明るい灰色で8x8を塗りつぶす(他の文字の様な字間無し)
	'□')
		echo $GBOS_TILE_NUM_LIGHT_GRAY
		;;
	'▼')
		echo $GBOS_TILE_NUM_MINI_BTN
		;;
	'▲')
		echo $GBOS_TILE_NUM_MAXI_BTN
		;;
	'↑')
		echo $GBOS_TILE_NUM_UP_ARROW
		;;
	'↓')
		echo $GBOS_TILE_NUM_DOWN_ARROW
		;;
	[0-9])
		get_num_tile_num $ch
		;;
	[a-zA-Z])
		get_alpha_tile_num $ch
		;;
	'(')
		echo $GBOS_TILE_NUM_OPEN_BRACKET
		;;
	')')
		echo $GBOS_TILE_NUM_CLOSE_BRACKET
		;;
	'@')
		echo $GBOS_TILE_NUM_ATMARK
		;;
	'゛')
		echo $GBOS_TILE_NUM_DAKUTEN
		;;
	# ゛と゜を除くひらがな
	[あ-おかきくけこさしすせそたちつてとな-のはひふへほま-もやゆよら-ろわをん])
		get_hira_tile_num $ch
		;;
	'゜')
		echo $GBOS_TILE_NUM_HANDAKUTEN
		;;
	'、')
		echo $GBOS_TILE_NUM_TOUTEN
		;;
	'。')
		echo $GBOS_TILE_NUM_KUTEN
		;;
	'!')
		echo $GBOS_TILE_NUM_EXCLAMATION
		;;
	'?')
		echo $GBOS_TILE_NUM_QUESTION
		;;
	'-')
		echo $GBOS_TILE_NUM_DASH
		;;
	'.')
		echo $GBOS_TILE_NUM_PERIOD
		;;
	'/')
		echo $GBOS_TILE_NUM_SLASH
		;;
	':')
		echo $GBOS_TILE_NUM_COLON
		;;
	'_')
		echo $GBOS_TILE_NUM_UNDERBAR
		;;
	'→')
		echo $GBOS_TILE_NUM_RIGHT_ARROW
		;;
	'←')
		echo $GBOS_TILE_NUM_LEFT_ARROW
		;;
	'+')
		echo $GBOS_TILE_NUM_PLUS
		;;
	'=')
		echo $GBOS_TILE_NUM_EQUAL
		;;
	'「')
		echo $GBOS_TILE_NUM_OPEN_BRACKET_JA
		;;
	'」')
		echo $GBOS_TILE_NUM_CLOSE_BRACKET_JA
		;;
	# 「微生物」の絵文字を細胞の代わりに使用
	'🦠')
		echo $GBOS_TILE_NUM_CELL
		;;
	# 「開花」の絵文字を白デイジーの代わりに使用
	'🌼')
		echo $GBOS_TILE_NUM_DAISY_WHITE
		;;
	# 「ひまわり」の絵文字を黒デイジーの代わりに使用
	'🌻')
		echo $GBOS_TILE_NUM_DAISY_BLACK
		;;
	# 「口」の絵文字を捕食者の代わりに使用
	'👄')
		echo $GBOS_TILE_NUM_PREDATOR
		;;
	*)
		echo "Error: invalid character $ch" 1>&2
		return 1
		;;
	esac
}

# 指定された文字のタイル番号のバイナリデータを標準出力へ出力
# in : 第1引数  - 文字
#                 ※ 対応するタイルが存在すること
#                 ※ 罫線には未対応
#                    ∵ 上下左右の線に対応する文字が無いのと、
#                       罫線を描くなら「矩形を描画する関数」とかの方が良いため
# out: 標準出力 - タイル番号のバイナリデータ
put_char_tile_data() {
	local ch="$1"
	local tile_num=$(get_tile_num "$ch")
	echo -en "\x$tile_num"
}

# 指定された文字列のタイル番号の並びのバイナリデータを標準出力へ出力
# (NULL文字で終端する)
# in : 第1引数  - 文字列
#                 ※ 対応するタイルが存在する文字のみであること
# out: 標準出力 - タイル番号が並んだバイナリデータ
#                 ※ NULL文字(0xff)で終端されている
put_str_tile_data() {
	local str=$1
	local len=${#str}
	local i
	local ch
	for ((i = 0; i < $len; i++)); do
		ch="${str:$i:1}"
		put_char_tile_data "$ch"
	done
	echo -en "\x$GBOS_CTRL_CHR_NULL"
}
