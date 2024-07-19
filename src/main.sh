# (TODO) f_view_{txt,img,dir} では GBOS_WST_NUM_{TXT,IMG,DIR}を使って
#        対象ビットのみを設定するようにする

if [ "${SRC_MAIN_SH+is_defined}" ]; then
	return
fi
SRC_MAIN_SH=true

. include/gb.sh
. include/vars.sh
. include/tiles.sh
. include/gbos.sh
. include/tdq.sh
. include/fs.sh
. include/con.sh
. include/timer.sh
. include/binbio.sh
. src/tiles.sh

# 使用する実験セットを読み込む
# TODO: この仕組みでは実行中に実験セットを変更できないので、
#       デイジーワールドの実験セットもv0.2.0までの動的に変更できる仕組みに入れ込むようにする
# 備考:
# - v0.2.0までは$var_binbio_expset_numによって切り替えられる様にしていたが、
#   v0.3.0でデイジーワールド実験の実装を急ぐ際に、実装の簡単さのため、このようにした
# - v0.2.0に入れ込む際、「実験セットの切り替えをスタート/セレクトボタンの他にどうするか」等は要検討
if [ "$BINBIO_EXPSET_NUM_INIT" = "$BINBIO_EXPSET_DAISYWORLD" ]; then
	. src/expset_daisyworld.sh
else
	. src/expset_hello.sh
fi

rm -f $MAP_FILE_NAME

debug_mode=false

GBOS_ROM_TILE_DATA_START=$GB_ROM_FREE_BASE
GBOS_ROM_CONST_DATA_START=0c00
GBOS_GFUNC_START=1000
GBOS_TILE_DATA_START=8000
GBOS_BG_TILEMAP_START=$GB_VRAM_BG_TILE_MAP_BASE
GBOS_WINDOW_TILEMAP_START=9c00
GBOS_FS_BASE_ROM=4000	# 16KB ROM Bank 01
GBOS_FS_BASE_RAM=a000	# 8KB External RAM
# GBOS_FS_BASE_DEF=$GBOS_FS_BASE_RAM
GBOS_FS_BASE_DEF=$GBOS_FS_BASE_ROM
GBOS_FS_BASE=$GBOS_FS_BASE_RAM
GBOS_FS_FILE_ATTR_SZ=07

# マウス座標
## TODO: ウィンドウを動かすようになったら
##       GBOS_WIN_DEF_{X,Y}_Tを使っている部分は直す
## ウィンドウのアイコン領域のベースアドレス
GBOS_ICON_BASE_X=$(
	calc16_2 "(${GBOS_WX_DEF}*${GB_TILE_WIDTH})+(${GB_TILE_WIDTH}*2)"
		)
GBOS_ICON_BASE_Y=$(
	calc16_2 "(${GBOS_WY_DEF}*${GB_TILE_HEIGHT})+(${GB_TILE_HEIGHT}*3)"
		)
CLICK_WIDTH=$(calc16_2 "${GB_TILE_WIDTH}*4")
CLICK_HEIGHT=$(calc16_2 "${GB_TILE_HEIGHT}*3")

# [LCD制御レジスタのベース設定値]
# - Bit 7: LCD Display Enable (0=Off, 1=On)
#   -> LCDはOn/Offは変わるためベースでは0
# - Bit 6: Window Tile Map Display Select (0=9800-9BFF, 1=9C00-9FFF)
#   -> ウィンドウタイルマップには9C00-9FFF(1)を設定
# - Bit 5: Window Display Enable (0=Off, 1=On)
#   -> ウィンドウはまずは使わないので0
# - Bit 4: BG & Window Tile Data Select (0=8800-97FF, 1=8000-8FFF)
#   -> タイルデータの配置領域は8000-8FFF(1)にする
# - Bit 3: BG Tile Map Display Select (0=9800-9BFF, 1=9C00-9FFF)
#   -> 背景用のタイルマップ領域に9800-9BFF(0)を使う
# - Bit 2: OBJ (Sprite) Size (0=8x8, 1=8x16)
#   -> スプライトサイズは8x16(1)
# - Bit 1: OBJ (Sprite) Display Enable (0=Off, 1=On)
#   -> スプライト使うので1
# - Bit 0: BG Display (0=Off, 1=On)
#   -> 背景は使うので1
GBOS_LCDC_BASE=57	# %0101 0111($57)

GBOS_OBJ_WIDTH=08
GBOS_OBJ_HEIGHT=10
GBOS_OBJ_DEF_ATTR=00	# %0000 0000($00)

# ウィンドウステータス用定数
GBOS_WST_BITNUM_DIR=0	# ディレクトリ表示中
GBOS_WST_BITNUM_EXE=1	# 実行ファイル実行中
GBOS_WST_BITNUM_TXT=2	# テキストファイル表示中
GBOS_WST_BITNUM_IMG=3	# 画像ファイル表示中
GBOS_WST_NUM_DIR=01	# ディレクトリ表示中
GBOS_WST_NUM_EXE=02	# 実行ファイル実行中
GBOS_WST_NUM_TXT=04	# テキストファイル表示中
GBOS_WST_NUM_IMG=08	# 画像ファイル表示中

# タイルミラー領域
# メモ：8近傍のオフセット
# | -0x21 | -0x20 | -0x1f |
# | -0x01 |     - | +0x01 |
# | +0x1f | +0x20 | +0x21 |
GBOS_TMRR_BASE=dc00	# タイルミラー領域ベースアドレス
GBOS_TMRR_BASE_BH=00	# タイルミラー領域ベースアドレス(下位8ビット)
GBOS_TMRR_BASE_TH=dc	# タイルミラー領域ベースアドレス(上位8ビット)
GBOS_TOFS_MASK_TH=03	# タイルアドレスオフセット部マスク(上位8ビット)
GBOS_TMRR_END_PLUS1_TH=e0	# タイルミラー領域最終アドレス+1(上位8ビット)

# 定数データを出力
const_data() {
	### 文字列データ ###

	# 定数名と変換元の文字列をTSVへリストアップ
	# ※ ここで付けた定数名を用いて、文字列データへ以下のシェル変数でアクセスできるようになる
	# 　 - アドレス: $a_const_<定数名>
	# 　 - サイズ  : $sz_const_<定数名>
	cat <<EOF >src/const_data.str.tsv
pref_hex	0X
surface_temp_str_title	ちひようおんと゛:
surface_temp_str_unit_and_btn	゜C▲▼
title_str_daisy	て゛いし゛-
title_str_world	わ-ると゛
title_str_demo	て゛も
ver_str_daisy	DAISY
ver_str_os	OS GB
ver_str_ver	V0.4.0
daisy_desc_str_white	🌼しろのて゛いし゛-:0.1゜Cほうねつ
daisy_desc_str_black	🌻くろのて゛いし゛-:0.1゜Cちくねつ
predator_desc_str	👄ほしよくしや:て゛いし゛-をたへ゛る
operation_str_title	そうさせつめい
operation_str_dir	+し゛き-:か-そるいと゛う
operation_str_a	Aほ゛たん:▲▼ほ゛たんそうさ
operation_str_b_1	Bほ゛たん:していしたせいふ゛つを
operation_str_b_2	まひ゛く(しようきよ)
cell_status_str_flags	ふらく゛:
cell_status_str_coord	さ゛ひよう:
cell_status_str_life_left_duration	よめい/し゛ゆみよう:
cell_status_str_fitness	てきおうと゛:
cell_status_str_bin_data_size	は゛いなり:(さいす゛:
cell_status_str_collected_flags	しゆとくふらく゛:
select_cell_eval	ひようかかんすうせんたく
cell_eval_daisyworld	て゛いし゛-わ-ると゛
cell_eval_fixedval	こていち
func_str	かんすう
conf_str	せつてい
cell_eval_conf	ひようかかんすうせつてい
fixedval_param_val	こていち:
EOF

	# 各文字列をタイル番号のバイナリデータへ変換しファイルと標準出力へ出力
	local num_lines=$(wc -l src/const_data.str.tsv | cut -d' ' -f1)
	local i
	local name
	local str
	for ((i = 1; i <= $num_lines; i++)); do
		name=$(sed -n ${i}p src/const_data.str.tsv | cut -f1)
		str=$(sed -n ${i}p src/const_data.str.tsv | cut -f2)
		put_str_tile_data "$str" >src/const_${name}.o
		cat src/const_${name}.o
	done

	# 一時マップファイルへ各文字列データのアドレスとサイズを出力
	# ※ この部分のみ、マップデータの読み込みを行うため、
	# 　 本体のマップファイルではなく別のファイルへ出力している
	local next_adr=$GBOS_ROM_CONST_DATA_START
	local str_name_list=$(cut -f1 src/const_data.str.tsv)
	local sz
	local sz_hex
	for name in $str_name_list; do
		echo "a_const_${name}=$next_adr"
		sz=$(stat -c '%s' src/const_${name}.o)
		echo "sz_const_${name}=$sz"
		sz_hex=$(to16 $sz)
		next_adr=$(four_digits $(calc16 "${next_adr}+${sz_hex}"))
	done >include/const_data.str_map.sh

	# マップデータ読み込み
	. include/const_data.str_map.sh

	# 本体のマップファイルへ追記
	cat include/const_data.str_map.sh >>$MAP_FILE_NAME
}
const_data >src/const_data.o

# 初期タイルデータをVRAMのタイルデータ領域へロード
# ※ regAF・regDE・regHLは破壊される
load_all_tiles() {
	local rel_sz
	local bc_radix='obase=16;ibase=16;'
	local bc_form="${GBOS_TILE_DATA_START}+${GBOS_NUM_ALL_TILE_BYTES}"
	local end_addr=$(echo "${bc_radix}${bc_form}" | bc)
	local end_addr_th=$(echo $end_addr | cut -c-2)
	local end_addr_bh=$(echo $end_addr | cut -c3-)
	lr35902_set_reg regDE $GBOS_ROM_TILE_DATA_START
	lr35902_set_reg regHL $GBOS_TILE_DATA_START
	(
		lr35902_copy_to_from regA ptrDE
		lr35902_copyinc_to_ptrHL_from_regA
		lr35902_copy_to_from regA regH
		lr35902_compare_regA_and $end_addr_th
		(
			lr35902_copy_to_from regA regL
			lr35902_compare_regA_and $end_addr_bh
			lr35902_rel_jump_with_cond Z 03
		) >src/load_all_tiles.1.o
		rel_sz=$(stat -c '%s' src/load_all_tiles.1.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $rel_sz)
		cat src/load_all_tiles.1.o
		lr35902_inc regDE
	) >src/load_all_tiles.2.o
	cat src/load_all_tiles.2.o
	rel_sz=$(stat -c '%s' src/load_all_tiles.2.o)
	lr35902_rel_jump $(two_comp_d $((rel_sz + 2)))
}

# 符号なしの2バイト値同士の比較
# in  : regHL - 引かれる値
#     : regDE - 引く値
# out : regA  - regHL < regDEの時、負の値
#               regHL == regDEの時、0
#               regHL > regDEの時、正の値
# ※ フラグレジスタは破壊される
a_compare_regHL_and_regDE=$GBOS_GFUNC_START
echo -e "a_compare_regHL_and_regDE=$a_compare_regHL_and_regDE" >>$MAP_FILE_NAME
f_compare_regHL_and_regDE() {
	# regHのMSBで分岐
	# ※ sub命令はMSBを符号ビットとして扱ってしまうので
	# 　 regHとregDでMSBが異なる場合の処理を先に行う
	#    (後のregLとregEも同様)
	lr35902_test_bitN_of_reg 7 regH
	(
		# regHのMSBが0の場合

		# regDのMSBは1か?
		lr35902_test_bitN_of_reg 7 regD
		(
			# regDのMSBが1の場合
			# → regHL < regDE

			# regAへ負の値を設定してreturn
			lr35902_set_reg regA ff
			lr35902_return
		) >src/f_compare_regHL_and_regDE.5.o
		local sz_5=$(stat -c '%s' src/f_compare_regHL_and_regDE.5.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_5)
		cat src/f_compare_regHL_and_regDE.5.o
	) >src/f_compare_regHL_and_regDE.3.o
	(
		# regHのMSBが1の場合

		# regDのMSBは0か?
		lr35902_test_bitN_of_reg 7 regD
		(
			# regDのMSBが0の場合
			# → regHL > regDE

			# regAへ正の値を設定してreturn
			lr35902_set_reg regA 01
			lr35902_return
		) >src/f_compare_regHL_and_regDE.6.o
		local sz_6=$(stat -c '%s' src/f_compare_regHL_and_regDE.6.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_6)
		cat src/f_compare_regHL_and_regDE.6.o

		# regHのMSBが0の場合の処理を飛ばす
		local sz_3=$(stat -c '%s' src/f_compare_regHL_and_regDE.3.o)
		lr35902_rel_jump $(two_digits_d $sz_3)
	) >src/f_compare_regHL_and_regDE.4.o
	local sz_4=$(stat -c '%s' src/f_compare_regHL_and_regDE.4.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_4)
	cat src/f_compare_regHL_and_regDE.4.o	# regHのMSBが1の場合
	cat src/f_compare_regHL_and_regDE.3.o	# regHのMSBが0の場合

	# regH - regD
	lr35902_copy_to_from regA regH
	lr35902_sub_to_regA regD	# regA - regD
	## Cがセットされるのは、regA < regD の時
	(
		# regA(regH) < regD の場合
		# → regHL < regDE

		# 結果のregAをreturn
		lr35902_return
	) >src/f_compare_regHL_and_regDE.1.o
	local sz_1=$(stat -c '%s' src/f_compare_regHL_and_regDE.1.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_1)
	cat src/f_compare_regHL_and_regDE.1.o

	# regH >= regD の場合

	# Zフラグで分岐
	(
		# regA(regH) == regD の場合

		# regLのMSBで分岐
		lr35902_test_bitN_of_reg 7 regL
		(
			# regLのMSBが0の場合

			# regEのMSBは1か?
			lr35902_test_bitN_of_reg 7 regE
			(
				# regEのMSBが1の場合
				# → regHL < regDE

				# regAへ負の値を設定してreturn
				lr35902_set_reg regA ff
				lr35902_return
			) >src/f_compare_regHL_and_regDE.9.o
			local sz_9=$(stat -c '%s' src/f_compare_regHL_and_regDE.9.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_9)
			cat src/f_compare_regHL_and_regDE.9.o
		) >src/f_compare_regHL_and_regDE.7.o
		(
			# regLのMSBが1の場合

			# regEのMSBは0か?
			lr35902_test_bitN_of_reg 7 regE
			(
				# regEのMSBが0の場合
				# → regHL > regDE

				# regAへ正の値を設定してreturn
				lr35902_set_reg regA 01
				lr35902_return
			) >src/f_compare_regHL_and_regDE.10.o
			local sz_10=$(stat -c '%s' src/f_compare_regHL_and_regDE.10.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_10)
			cat src/f_compare_regHL_and_regDE.10.o

			# regHのMSBが0の場合の処理を飛ばす
			local sz_7=$(stat -c '%s' src/f_compare_regHL_and_regDE.7.o)
			lr35902_rel_jump $(two_digits_d $sz_7)
		) >src/f_compare_regHL_and_regDE.8.o
		local sz_8=$(stat -c '%s' src/f_compare_regHL_and_regDE.8.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_8)
		cat src/f_compare_regHL_and_regDE.8.o	# regHのMSBが1の場合
		cat src/f_compare_regHL_and_regDE.7.o	# regLのMSBが0の場合

		# regL - regE
		lr35902_copy_to_from regA regL
		lr35902_sub_to_regA regE	# regA - regE

		# 結果のregAをreturn
		lr35902_return
	) >src/f_compare_regHL_and_regDE.2.o
	local sz_2=$(stat -c '%s' src/f_compare_regHL_and_regDE.2.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_2)
	cat src/f_compare_regHL_and_regDE.2.o

	# regH > regD の場合
	# → regHL > regDE

	# 結果のregAをreturn
	lr35902_return
}

# 符号なしの2バイト値同士の除算
# in  : regHL - 割られる値
#     : regDE - 割る値
# out : regHL - 商
#       regDE - 余り
f_compare_regHL_and_regDE >src/f_compare_regHL_and_regDE.o
fsz=$(to16 $(stat -c '%s' src/f_compare_regHL_and_regDE.o))
fadr=$(calc16 "${a_compare_regHL_and_regDE}+${fsz}")
a_div_regHL_by_regDE=$(four_digits $fadr)
echo -e "a_div_regHL_by_regDE=$a_div_regHL_by_regDE" >>$MAP_FILE_NAME
f_div_regHL_by_regDE() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC

	local obj

	# regBC = 0
	lr35902_clear_reg regBC

	# regHLからregDEを何回減算できるかをregBCでカウントする
	(
		# regHL < regDE ?
		## regHLとregDEを比較
		lr35902_call $a_compare_regHL_and_regDE
		## regAが負の値(MSBが1)か ?
		lr35902_test_bitN_of_reg 7 regA
		obj=src/f_div_regHL_by_regDE.break.o
		(
			# regAが負の値 の場合
			# (regHL < regDE の場合)

			# ループを脱出する
			local loop_bh_bytes=$((1 + 7 + 1 + 1 + 1))
			lr35902_rel_jump $(two_digits_d $((loop_bh_bytes + 2)))
		) >$obj
		local sz_break=$(stat -c '%s' $obj)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_break)
		cat $obj

		# regHL -= regDE
		## regDEをスタックへ退避
		lr35902_push_reg regDE	# 1
		## regDEを2の補数で上書きする
		get_comp_of regDE	# 7
		## regHL += regDE
		lr35902_add_to_regHL regDE	# 1
		## regDEをスタックから復帰
		lr35902_pop_reg regDE	# 1

		# regBC++
		lr35902_inc regBC	# 1
	) >src/f_div_regHL_by_regDE.loop.o
	cat src/f_div_regHL_by_regDE.loop.o
	local sz_loop=$(stat -c '%s' src/f_div_regHL_by_regDE.loop.o)
	lr35902_rel_jump $(two_comp_d $((sz_loop + 2)))	# 2

	# この時点でregBCに商、regHLに余りが設定されている

	# regDE = regHL
	lr35902_copy_to_from regE regL
	lr35902_copy_to_from regD regH

	# regHL = regBC
	lr35902_copy_to_from regL regC
	lr35902_copy_to_from regH regB

	# pop & return
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 現在のマウスカーソルが指すタイル座標を取得
# in : $var_mouse_{x,y}
# out: regD - タイル座標Y
#    : regE - タイル座標X
f_div_regHL_by_regDE >src/f_div_regHL_by_regDE.o
fsz=$(to16 $(stat -c '%s' src/f_div_regHL_by_regDE.o))
fadr=$(calc16 "${a_div_regHL_by_regDE}+${fsz}")
a_get_mouse_tcoord=$(four_digits $fadr)
echo -e "a_get_mouse_tcoord=$a_get_mouse_tcoord" >>$MAP_FILE_NAME
f_get_mouse_tcoord() {
	# push
	lr35902_push_reg regAF

	# タイル座標Yを算出
	## regAへ現在のマウスカーソルY座標を取得
	lr35902_copy_to_regA_from_addr $var_mouse_y
	## マウスカーソル座標(My)からピクセル座標(Py)へ変換
	## Py = My - 16(0x10)
	lr35902_sub_to_regA 10
	## ピクセル座標(Py)からタイル座標(Ty)へ変換
	## Ty = Py / 8 = Py >> 3
	lr35902_shift_right_logical regA
	lr35902_shift_right_logical regA
	lr35902_shift_right_logical regA
	## regDへ結果を設定
	lr35902_copy_to_from regD regA

	# タイル座標Xを算出
	## regAへ現在のマウスカーソルX座標を取得
	lr35902_copy_to_regA_from_addr $var_mouse_x
	## マウスカーソル座標(Mx)からピクセル座標(Px)へ変換
	## Px = Mx - 8
	lr35902_sub_to_regA 08
	## ピクセル座標(Px)からタイル座標(Tx)へ変換
	## Tx = Px / 8 = Px >> 3
	lr35902_shift_right_logical regA
	lr35902_shift_right_logical regA
	lr35902_shift_right_logical regA
	## regEへ結果を設定
	lr35902_copy_to_from regE regA

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# タイル座標をアドレスへ変換
# in : regD  - タイル座標Y
#      regE  - タイル座標X
# out: regHL - 9800h〜のアドレスを格納
f_get_mouse_tcoord >src/f_get_mouse_tcoord.o
fsz=$(to16 $(stat -c '%s' src/f_get_mouse_tcoord.o))
fadr=$(calc16 "${a_get_mouse_tcoord}+${fsz}")
a_tcoord_to_addr=$(four_digits $fadr)
echo -e "a_tcoord_to_addr=$a_tcoord_to_addr" >>$MAP_FILE_NAME
f_tcoord_to_addr() {
	local sz

	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE

	lr35902_set_reg regHL $GBOS_BG_TILEMAP_START
	lr35902_clear_reg regA
	lr35902_compare_regA_and regD
	(
		lr35902_set_reg regBC $(four_digits $GB_SC_WIDTH_T)
		(
			lr35902_add_to_regHL regBC
			lr35902_dec regD
		) >src/f_tcoord_to_addr.1.o
		cat src/f_tcoord_to_addr.1.o
		sz=$(stat -c '%s' src/f_tcoord_to_addr.1.o)
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz + 2)))
	) >src/f_tcoord_to_addr.2.o
	sz=$(stat -c '%s' src/f_tcoord_to_addr.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/f_tcoord_to_addr.2.o
	lr35902_add_to_regHL regDE

	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# ウィンドウタイル座標をタイル座標へ変換
# in : regD  - ウィンドウタイル座標Y
#      regE  - ウィンドウタイル座標X
# out: regD  - タイル座標Y
#      regE  - タイル座標X
f_tcoord_to_addr >src/f_tcoord_to_addr.o
fsz=$(to16 $(stat -c '%s' src/f_tcoord_to_addr.o))
a_wtcoord_to_tcoord=$(four_digits $(calc16 "${a_tcoord_to_addr}+${fsz}"))
echo -e "a_wtcoord_to_tcoord=$a_wtcoord_to_tcoord" >>$MAP_FILE_NAME
f_wtcoord_to_tcoord() {
	lr35902_push_reg regAF

	lr35902_copy_to_regA_from_addr $var_win_yt
	lr35902_add_to_regA regD
	lr35902_copy_to_from regD regA
	lr35902_copy_to_regA_from_addr $var_win_xt
	lr35902_add_to_regA regE
	lr35902_copy_to_from regE regA

	lr35902_pop_reg regAF
	lr35902_return
}

# タイル座標をミラーアドレスへ変換
# in : regD  - タイル座標Y
#      regE  - タイル座標X
# out: regHL - dc00h〜のアドレスを格納
f_wtcoord_to_tcoord >src/f_wtcoord_to_tcoord.o
fsz=$(to16 $(stat -c '%s' src/f_wtcoord_to_tcoord.o))
a_tcoord_to_mrraddr=$(four_digits $(calc16 "${a_wtcoord_to_tcoord}+${fsz}"))
echo -e "a_tcoord_to_mrraddr=$a_tcoord_to_mrraddr" >>$MAP_FILE_NAME
f_tcoord_to_mrraddr() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE

	local sz
	lr35902_set_reg regHL $GBOS_TMRR_BASE
	lr35902_clear_reg regA
	lr35902_compare_regA_and regD
	(
		lr35902_set_reg regBC $(four_digits $GB_SC_WIDTH_T)
		(
			lr35902_add_to_regHL regBC
			lr35902_dec regD
		) >src/f_tcoord_to_mrraddr.1.o
		cat src/f_tcoord_to_mrraddr.1.o
		sz=$(stat -c '%s' src/f_tcoord_to_mrraddr.1.o)
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz + 2)))
	) >src/f_tcoord_to_mrraddr.2.o
	sz=$(stat -c '%s' src/f_tcoord_to_mrraddr.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/f_tcoord_to_mrraddr.2.o
	lr35902_add_to_regHL regDE

	# pop & return
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# ミラーアドレスをタイル座標へ変換
# in : regHL - ミラーアドレス(dc00h〜)
# out: regD  - タイル座標Y
#      regE  - タイル座標X
f_tcoord_to_mrraddr >src/f_tcoord_to_mrraddr.o
fsz=$(to16 $(stat -c '%s' src/f_tcoord_to_mrraddr.o))
fadr=$(calc16 "${a_tcoord_to_mrraddr}+${fsz}")
a_mrraddr_to_tcoord=$(four_digits $fadr)
echo -e "a_mrraddr_to_tcoord=$a_mrraddr_to_tcoord" >>$MAP_FILE_NAME
f_mrraddr_to_tcoord() {
	# push
	lr35902_push_reg regHL

	# regHL -= 0xdc00 (2の補数:0x2400)
	lr35902_set_reg regDE 2400
	lr35902_add_to_regHL regDE

	# regHL / $GB_SC_WIDTH_T の商(regHL)と余り(regDE)のそれぞれ下位1バイトを
	# regD、regEへ設定
	# (ただし、余りの下位1バイトは元々regEなので設定不要)
	## regDE = $GB_SC_WIDTH_T
	lr35902_set_reg regDE $(four_digits $GB_SC_WIDTH_T)
	## regHL /= regBC
	lr35902_call $a_div_regHL_by_regDE
	## regD = regL
	lr35902_copy_to_from regD regL

	# pop & return
	lr35902_pop_reg regHL
	lr35902_return
}

# 背景タイルマップを白タイル(タイル番号0)で初期化
f_mrraddr_to_tcoord >src/f_mrraddr_to_tcoord.o
fsz=$(to16 $(stat -c '%s' src/f_mrraddr_to_tcoord.o))
fadr=$(calc16 "${a_mrraddr_to_tcoord}+${fsz}")
a_clear_bg=$(four_digits $fadr)
echo -e "a_clear_bg=$a_clear_bg" >>$MAP_FILE_NAME
f_clear_bg() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# 背景タイルマップを白タイル(タイル番号0)で初期化
	local sz
	lr35902_set_reg regHL $GBOS_BG_TILEMAP_START
	lr35902_set_reg regB $GB_SC_HEIGHT_T
	lr35902_clear_reg regA
	(
		lr35902_set_reg regC $GB_SC_WIDTH_T
		(
			lr35902_copyinc_to_ptrHL_from_regA
			lr35902_dec regC
		) >src/f_clear_bg.1.o
		cat src/f_clear_bg.1.o
		sz=$(stat -c '%s' src/f_clear_bg.1.o)
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz+2)))
		lr35902_dec regB
	) >src/f_clear_bg.2.o
	cat src/f_clear_bg.2.o
	sz=$(stat -c '%s' src/f_clear_bg.2.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz+2)))

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# タイルミラー領域を空白タイルで初期化
f_clear_bg >src/f_clear_bg.o
fsz=$(to16 $(stat -c '%s' src/f_clear_bg.o))
fadr=$(calc16 "${a_clear_bg}+${fsz}")
a_init_tmrr=$(four_digits $fadr)
echo -e "a_init_tmrr=$a_init_tmrr" >>$MAP_FILE_NAME
f_init_tmrr() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# regHLへタイルミラー領域のベースアドレスを設定
	lr35902_set_reg regL $GBOS_TMRR_BASE_BH
	lr35902_set_reg regH $GBOS_TMRR_BASE_TH

	# タイルミラー領域を空白タイルで初期化
	(
		lr35902_set_reg regA $GBOS_TILE_NUM_SPC
		lr35902_copyinc_to_ptrHL_from_regA

		lr35902_copy_to_from regA regH
		lr35902_compare_regA_and $GBOS_TMRR_END_PLUS1_TH
	) >src/f_init_tmrr.1.o
	cat src/f_init_tmrr.1.o
	local sz_1=$(stat -c '%s' src/f_init_tmrr.1.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_1 + 2)))

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
	lr35902_return
}

# タイル座標の位置へ指定されたタイルを配置する
# in : regA  - 配置するタイル番号
#      regD  - タイル座標Y
#      regE  - タイル座標X
f_init_tmrr >src/f_init_tmrr.o
fsz=$(to16 $(stat -c '%s' src/f_init_tmrr.o))
fadr=$(calc16 "${a_init_tmrr}+${fsz}")
a_lay_tile_at_tcoord=$(four_digits $fadr)
echo -e "a_lay_tile_at_tcoord=$a_lay_tile_at_tcoord" >>$MAP_FILE_NAME
f_lay_tile_at_tcoord() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	lr35902_call $a_tcoord_to_addr
	lr35902_copy_to_ptrHL_from regA

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
	lr35902_return
}

# ウィンドウタイル座標の位置へ指定されたタイルを配置する
# in : regA  - 配置するタイル番号
#      regD  - ウィンドウタイル座標Y
#      regE  - ウィンドウタイル座標X
f_lay_tile_at_tcoord >src/f_lay_tile_at_tcoord.o
fsz=$(to16 $(stat -c '%s' src/f_lay_tile_at_tcoord.o))
fadr=$(calc16 "${a_lay_tile_at_tcoord}+${fsz}")
a_lay_tile_at_wtcoord=$(four_digits $fadr)
echo -e "a_lay_tile_at_wtcoord=$a_lay_tile_at_wtcoord" >>$MAP_FILE_NAME
f_lay_tile_at_wtcoord() {
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	lr35902_call $a_wtcoord_to_tcoord
	lr35902_call $a_tcoord_to_addr
	lr35902_copy_to_ptrHL_from regA

	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_return
}

# タイル座標の位置から右へ指定されたタイルを並べる
# in : regA  - 並べるタイル番号
#      regC  - 並べる個数
#      regD  - タイル座標Y
#      regE  - タイル座標X
f_lay_tile_at_wtcoord >src/f_lay_tile_at_wtcoord.o
fsz=$(to16 $(stat -c '%s' src/f_lay_tile_at_wtcoord.o))
fadr=$(calc16 "${a_lay_tile_at_wtcoord}+${fsz}")
a_lay_tiles_at_tcoord_to_right=$(four_digits $fadr)
echo -e "a_lay_tiles_at_tcoord_to_right=$a_lay_tiles_at_tcoord_to_right" >>$MAP_FILE_NAME
f_lay_tiles_at_tcoord_to_right() {
	local sz

	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	lr35902_copy_to_from regB regC

	lr35902_call $a_tcoord_to_addr
	(
		lr35902_copyinc_to_ptrHL_from_regA
		lr35902_dec regC
	) >src/f_lay_tiles_at_tcoord_to_right.1.o
	cat src/f_lay_tiles_at_tcoord_to_right.1.o
	sz=$(stat -c '%s' src/f_lay_tiles_at_tcoord_to_right.1.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz + 2)))

	lr35902_copy_to_from regC regB

	lr35902_call $a_tcoord_to_mrraddr
	(
		lr35902_copyinc_to_ptrHL_from_regA
		lr35902_dec regC
	) >src/f_lay_tiles_at_tcoord_to_right.2.o
	cat src/f_lay_tiles_at_tcoord_to_right.2.o
	sz=$(stat -c '%s' src/f_lay_tiles_at_tcoord_to_right.2.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz + 2)))

	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_return
}

# ウィンドウタイル座標の位置から右へ指定されたタイルを並べる
# in : regA  - 並べるタイル番号
#      regC  - 並べる個数
#      regD  - ウィンドウタイル座標Y
#      regE  - ウィンドウタイル座標X
f_lay_tiles_at_tcoord_to_right >src/f_lay_tiles_at_tcoord_to_right.o
fsz=$(to16 $(stat -c '%s' src/f_lay_tiles_at_tcoord_to_right.o))
fadr=$(calc16 "${a_lay_tiles_at_tcoord_to_right}+${fsz}")
a_lay_tiles_at_wtcoord_to_right=$(four_digits $fadr)
echo -e "a_lay_tiles_at_wtcoord_to_right=$a_lay_tiles_at_wtcoord_to_right" >>$MAP_FILE_NAME
f_lay_tiles_at_wtcoord_to_right() {
	lr35902_push_reg regDE

	lr35902_call $a_wtcoord_to_tcoord
	lr35902_call $a_lay_tiles_at_tcoord_to_right

	lr35902_pop_reg regDE
	lr35902_return
}

# タイル座標の位置から下へ指定されたタイルを並べる
# in : regA  - 並べるタイル番号
#      regC  - 並べる個数
#      regD  - タイル座標Y
#      regE  - タイル座標X
f_lay_tiles_at_wtcoord_to_right >src/f_lay_tiles_at_wtcoord_to_right.o
fsz=$(to16 $(stat -c '%s' src/f_lay_tiles_at_wtcoord_to_right.o))
fadr=$(calc16 "${a_lay_tiles_at_wtcoord_to_right}+${fsz}")
a_lay_tiles_at_tcoord_to_low=$(four_digits $fadr)
echo -e "a_lay_tiles_at_tcoord_to_low=$a_lay_tiles_at_tcoord_to_low" >>$MAP_FILE_NAME
f_lay_tiles_at_tcoord_to_low() {
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	lr35902_call $a_tcoord_to_addr
	lr35902_set_reg regDE $(four_digits $GB_SC_WIDTH_T)
	(
		lr35902_copy_to_ptrHL_from regA
		lr35902_add_to_regHL regDE
		lr35902_dec regC
	) >src/f_lay_tiles_at_tcoord_to_low.1.o
	cat src/f_lay_tiles_at_tcoord_to_low.1.o
	local sz=$(stat -c '%s' src/f_lay_tiles_at_tcoord_to_low.1.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz + 2)))

	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_return
}

# ウィンドウタイル座標の位置から下へ指定されたタイルを並べる
# in : regA  - 並べるタイル番号
#      regC  - 並べる個数
#      regD  - ウィンドウタイル座標Y
#      regE  - ウィンドウタイル座標X
f_lay_tiles_at_tcoord_to_low >src/f_lay_tiles_at_tcoord_to_low.o
fsz=$(to16 $(stat -c '%s' src/f_lay_tiles_at_tcoord_to_low.o))
fadr=$(calc16 "${a_lay_tiles_at_tcoord_to_low}+${fsz}")
a_lay_tiles_at_wtcoord_to_low=$(four_digits $fadr)
echo -e "a_lay_tiles_at_wtcoord_to_low=$a_lay_tiles_at_wtcoord_to_low" >>$MAP_FILE_NAME
f_lay_tiles_at_wtcoord_to_low() {
	lr35902_push_reg regDE

	lr35902_call $a_wtcoord_to_tcoord
	lr35902_call $a_lay_tiles_at_tcoord_to_low

	lr35902_pop_reg regDE
	lr35902_return
}

# オブジェクト番号をOAMアドレスへ変換
# in : regC  - オブジェクト番号(00h〜27h)
# out: regHL - OAMアドレス(FE00h〜FE9Ch)
f_lay_tiles_at_wtcoord_to_low >src/f_lay_tiles_at_wtcoord_to_low.o
fsz=$(to16 $(stat -c '%s' src/f_lay_tiles_at_wtcoord_to_low.o))
fadr=$(calc16 "${a_lay_tiles_at_wtcoord_to_low}+${fsz}")
a_objnum_to_addr=$(four_digits $fadr)
echo -e "a_objnum_to_addr=$a_objnum_to_addr" >>$MAP_FILE_NAME
f_objnum_to_addr() {
	lr35902_push_reg regBC

	lr35902_clear_reg regB
	lr35902_shift_left_arithmetic regC
	lr35902_shift_left_arithmetic regC
	lr35902_set_reg regHL $GB_OAM_BASE
	lr35902_add_to_regHL regBC

	lr35902_pop_reg regBC
	lr35902_return
}

# オブジェクトの座標を設定
# in : regC - オブジェクト番号
#      regA - 座標Y
#      regB - 座標X
f_objnum_to_addr >src/f_objnum_to_addr.o
fsz=$(to16 $(stat -c '%s' src/f_objnum_to_addr.o))
fadr=$(calc16 "${a_objnum_to_addr}+${fsz}")
a_set_objpos=$(four_digits $fadr)
echo -e "a_set_objpos=$a_set_objpos" >>$MAP_FILE_NAME
f_set_objpos() {
	lr35902_push_reg regHL

	lr35902_call $a_objnum_to_addr
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_copy_to_ptrHL_from regB

	lr35902_pop_reg regHL
	lr35902_return
}

# アイコンをウィンドウ座標に配置
# in : regA - アイコン番号
#      regD - ウィンドウタイル座標Y
#      regE - ウィンドウタイル座標X
f_set_objpos >src/f_set_objpos.o
fsz=$(to16 $(stat -c '%s' src/f_set_objpos.o))
fadr=$(calc16 "${a_set_objpos}+${fsz}")
a_lay_icon=$(four_digits $fadr)
echo -e "a_lay_icon=$a_lay_icon" >>$MAP_FILE_NAME
f_lay_icon() {
	lr35902_push_reg regAF
	lr35902_push_reg regDE

	# アイコン番号を、アイコンのベースタイル番号へ変換
	# (1アイコン辺りのタイル数が4なので、アイコン番号を4倍する)
	lr35902_shift_left_arithmetic regA
	lr35902_shift_left_arithmetic regA

	# 配置するアイコンの1つ目のタイル番号を算出
	lr35902_add_to_regA $GBOS_TYPE_ICON_TILE_BASE

	# 左上
	lr35902_call $a_lay_tile_at_wtcoord
	lr35902_inc regA

	# 右上
	lr35902_inc regE
	lr35902_call $a_lay_tile_at_wtcoord
	lr35902_inc regA

	# 右下
	lr35902_inc regD
	lr35902_call $a_lay_tile_at_wtcoord
	lr35902_inc regA

	# 左下
	lr35902_dec regE
	lr35902_call $a_lay_tile_at_wtcoord

	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
	lr35902_return
}

# ウィンドウ内をクリア
f_lay_icon >src/f_lay_icon.o
fsz=$(to16 $(stat -c '%s' src/f_lay_icon.o))
fadr=$(calc16 "${a_lay_icon}+${fsz}")
a_clr_win=$(four_digits $fadr)
echo -e "a_clr_win=$a_clr_win" >>$MAP_FILE_NAME
f_clr_win() {
	lr35902_push_reg regAF

	# DA用変数設定
	lr35902_set_reg regA 03
	lr35902_copy_to_addr_from_regA $var_clr_win_nyt

	# DASにclr_winのビットをセット
	lr35902_copy_to_regA_from_addr $var_draw_act_stat
	lr35902_set_bitN_of_reg $GBOS_DA_BITNUM_CLR_WIN regA
	lr35902_copy_to_addr_from_regA $var_draw_act_stat

	# ウィンドウステータスのview系/run系ビットをクリア
	lr35902_copy_to_regA_from_addr $var_win_stat
	lr35902_res_bitN_of_reg $GBOS_WST_BITNUM_TXT regA
	lr35902_res_bitN_of_reg $GBOS_WST_BITNUM_IMG regA
	lr35902_res_bitN_of_reg $GBOS_WST_BITNUM_EXE regA
	lr35902_copy_to_addr_from_regA $var_win_stat

	lr35902_pop_reg regAF
	lr35902_return
}

# テキストファイルを表示
# in : regA  - ファイル番号
#      regHL - ファイルサイズ・データ先頭アドレス
f_clr_win >src/f_clr_win.o
fsz=$(to16 $(stat -c '%s' src/f_clr_win.o))
fadr=$(calc16 "${a_clr_win}+${fsz}")
a_view_txt=$(four_digits $fadr)
echo -e "a_view_txt=$a_view_txt" >>$MAP_FILE_NAME
f_view_txt() {
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	lr35902_call $a_clr_win

	# DA用変数設定

	# 残り文字数
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_addr_from_regA $var_da_var1
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_addr_from_regA $var_da_var2

	# 次に配置する文字のアドレス
	lr35902_copy_to_from regA regL
	lr35902_copy_to_addr_from_regA $var_da_var3
	lr35902_copy_to_from regA regH
	lr35902_copy_to_addr_from_regA $var_da_var4

	# 次に配置するウィンドウタイル座標
	lr35902_set_reg regA 03	# Y座標
	lr35902_copy_to_addr_from_regA $var_da_var5
	lr35902_set_reg regA 02	# X座標
	lr35902_copy_to_addr_from_regA $var_da_var6

	# DASにview_txtのフラグ設定
	lr35902_copy_to_regA_from_addr $var_draw_act_stat
	lr35902_set_bitN_of_reg $GBOS_DA_BITNUM_VIEW_TXT regA
	lr35902_copy_to_addr_from_regA $var_draw_act_stat

	# ウィンドウステータスに「テキストファイル表示中」を設定
	lr35902_copy_to_regA_from_addr $var_win_stat
	## 「ディレクトリ表示中」はクリア
	lr35902_res_bitN_of_reg $GBOS_WST_BITNUM_DIR regA
	## 「テキストファイル表示中」を設定
	lr35902_set_bitN_of_reg $GBOS_WST_BITNUM_TXT regA
	lr35902_copy_to_addr_from_regA $var_win_stat

	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
	lr35902_return
}

# view_txt用周期ハンドラ
# TODO 現状、文字数は255文字まで(1バイト以内)
f_view_txt >src/f_view_txt.o
fsz=$(to16 $(stat -c '%s' src/f_view_txt.o))
fadr=$(calc16 "${a_view_txt}+${fsz}")
a_view_txt_cyc=$(four_digits $fadr)
echo -e "a_view_txt_cyc=$a_view_txt_cyc" >>$MAP_FILE_NAME
f_view_txt_cyc() {
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 次に配置する文字をregBへ取得
	lr35902_copy_to_regA_from_addr $var_da_var3
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_da_var4
	lr35902_copy_to_from regH regA
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regB regA

	# 次に配置するウィンドウタイル座標を (X, Y) = (regE, regD) へ取得
	lr35902_copy_to_regA_from_addr $var_da_var5
	lr35902_copy_to_from regD regA
	lr35902_copy_to_regA_from_addr $var_da_var6
	lr35902_copy_to_from regE regA

	# regBが改行文字か否か
	lr35902_copy_to_from regA regB
	lr35902_compare_regA_and $GBOS_CTRL_CHR_NL
	(
		# 改行文字である場合

		# 次に配置するX座標を描画領域の開始座標にする
		lr35902_set_reg regA $GBOS_WIN_DRAWABLE_BASE_XT
		lr35902_copy_to_addr_from_regA $var_da_var6
		# 次に配置するY座標をインクリメントする
		lr35902_inc regD
		lr35902_copy_to_from regA regD
		lr35902_copy_to_addr_from_regA $var_da_var5
		## TODO 1画面を超える場合の対処は未実装
	) >src/f_view_txt_cyc.1.o
	(
		# 改行文字でない場合

		# 配置する文字をregAへ設定
		lr35902_copy_to_from regA regB

		# タイル配置の関数を呼び出す
		lr35902_call $a_lay_tile_at_wtcoord

		# 次に配置する座標更新
		## 現在のX座標は描画領域右端であるか
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and $GBOS_WIN_DRAWABLE_MAX_XT
		(
			# 右端である場合

			# 次に配置するX座標を描画領域の開始座標にする
			lr35902_set_reg regA $GBOS_WIN_DRAWABLE_BASE_XT
			lr35902_copy_to_addr_from_regA $var_da_var6
			# 次に配置するY座標をインクリメントする
			lr35902_inc regD
			lr35902_copy_to_from regA regD
			lr35902_copy_to_addr_from_regA $var_da_var5
			## TODO 1画面を超える場合の対処は未実装
		) >src/f_view_txt_cyc.3.o
		(
			# 右端でない場合

			# X座標をインクリメントして変数へ書き戻す
			lr35902_inc regA
			lr35902_copy_to_addr_from_regA $var_da_var6

			# 右端である場合の処理を飛ばす
			local sz_3=$(stat -c '%s' src/f_view_txt_cyc.3.o)
			lr35902_rel_jump $(two_digits_d $sz_3)
		) >src/f_view_txt_cyc.4.o
		local sz_4=$(stat -c '%s' src/f_view_txt_cyc.4.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_4)
		# 右端でない場合
		cat src/f_view_txt_cyc.4.o
		# 右端である場合
		cat src/f_view_txt_cyc.3.o

		# 改行文字である場合の処理を飛ばす
		local sz_1=$(stat -c '%s' src/f_view_txt_cyc.1.o)
		lr35902_rel_jump $(two_digits_d $sz_1)
	) >src/f_view_txt_cyc.2.o
	local sz_2=$(stat -c '%s' src/f_view_txt_cyc.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
	# 改行文字でない場合
	cat src/f_view_txt_cyc.2.o
	# 改行文字である場合
	cat src/f_view_txt_cyc.1.o

	# 残り文字数更新
	## TODO 上位8ビットの対処
	##      (そのため現状は255文字までしか対応していない)
	lr35902_copy_to_regA_from_addr $var_da_var1
	lr35902_dec regA
	(
		# 残り文字数が0になった場合

		# DASのview_txtのビットを下ろす
		lr35902_copy_to_regA_from_addr $var_draw_act_stat
		lr35902_res_bitN_of_reg $GBOS_DA_BITNUM_VIEW_TXT regA
		lr35902_copy_to_addr_from_regA $var_draw_act_stat
	) >src/f_view_txt_cyc.5.o
	(
		# 残り文字数が0にならなかった場合

		# 残り文字数を変数へ書き戻す
		lr35902_copy_to_addr_from_regA $var_da_var1

		# 次に配置する文字のアドレス更新
		lr35902_copy_to_from regA regL
		lr35902_copy_to_addr_from_regA $var_da_var3
		lr35902_copy_to_from regA regH
		lr35902_copy_to_addr_from_regA $var_da_var4

		# 残り文字数が0になった場合の処理を飛ばす
		local sz_5=$(stat -c '%s' src/f_view_txt_cyc.5.o)
		lr35902_rel_jump $(two_digits_d $sz_5)
	) >src/f_view_txt_cyc.6.o
	local sz_6=$(stat -c '%s' src/f_view_txt_cyc.6.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_6)
	# 残り文字数が0にならなかった場合
	cat src/f_view_txt_cyc.6.o
	# 残り文字数が0になった場合
	cat src/f_view_txt_cyc.5.o

	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# clr_win用周期ハンドラ
f_view_txt_cyc >src/f_view_txt_cyc.o
fsz=$(to16 $(stat -c '%s' src/f_view_txt_cyc.o))
fadr=$(calc16 "${a_view_txt_cyc}+${fsz}")
a_clr_win_cyc=$(four_digits $fadr)
echo -e "a_clr_win_cyc=$a_clr_win_cyc" >>$MAP_FILE_NAME
f_clr_win_cyc() {
	lr35902_push_reg regAF
	lr35902_push_reg regDE

	# 次にクリアするウィンドウタイルY行を取得
	lr35902_copy_to_regA_from_addr $var_clr_win_nyt
	lr35902_copy_to_from regD regA

	# クリア開始X座標を設定
	lr35902_set_reg regE 02

	# クリアに使う文字を設定
	lr35902_set_reg regA $GBOS_TILE_NUM_SPC

	# 並べる個数(描画幅)を設定
	lr35902_set_reg regC $GBOS_WIN_DRAWABLE_WIDTH_T

	# タイル配置の関数を呼び出す
	lr35902_call $a_lay_tiles_at_wtcoord_to_right

	# 終端判定
	lr35902_copy_to_from regA regD
	lr35902_compare_regA_and $(calc16_2 "2+${GBOS_WIN_DRAWABLE_HEIGHT_T}")
	(
		# Y座標が描画最終行と等しい

		# DASのclr_winのビットを下ろす
		lr35902_copy_to_regA_from_addr $var_draw_act_stat
		lr35902_res_bitN_of_reg $GBOS_DA_BITNUM_CLR_WIN regA
		lr35902_copy_to_addr_from_regA $var_draw_act_stat

		# pop & return
		lr35902_pop_reg regDE
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_clr_win_cyc.1.o
	local sz_1=$(stat -c '%s' src/f_clr_win_cyc.1.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_1)
	cat src/f_clr_win_cyc.1.o

	# 次にクリアする行更新
	lr35902_inc regD
	lr35902_copy_to_from regA regD
	lr35902_copy_to_addr_from_regA $var_clr_win_nyt

	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
	lr35902_return
}

# タイル番号をアドレスへ変換
# in : regA  - タイル番号
# out: regHL - 8000h〜のアドレスを格納
f_clr_win_cyc >src/f_clr_win_cyc.o
fsz=$(to16 $(stat -c '%s' src/f_clr_win_cyc.o))
fadr=$(calc16 "${a_clr_win_cyc}+${fsz}")
a_tn_to_addr=$(four_digits $fadr)
echo -e "a_tn_to_addr=$a_tn_to_addr" >>$MAP_FILE_NAME
f_tn_to_addr() {
	local sz

	# HLへ0x8000を設定
	lr35902_set_reg regHL $GBOS_TILE_DATA_START

	# A == 0x00 の場合、そのままreturn
	lr35902_compare_regA_and 00
	(
		lr35902_return
	) >src/f_tn_to_addr.1.o
	sz=$(stat -c '%s' src/f_tn_to_addr.1.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz)
	cat src/f_tn_to_addr.1.o

	# 関数内で変更する戻り値以外のレジスタをpush
	lr35902_push_reg regAF
	lr35902_push_reg regDE

	# DEへ1タイル当たりのバイト数(16)を設定
	lr35902_clear_reg regD
	lr35902_set_reg regE $GBOS_TILE_BYTES

	# タイル番号の数だけHLへDEを加算
	(
		lr35902_add_to_regHL regDE
		lr35902_dec regA
	) >src/f_tn_to_addr.2.o
	cat src/f_tn_to_addr.2.o
	sz=$(stat -c '%s' src/f_tn_to_addr.2.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz+2)))

	# 関数内で変更した戻り値以外のレジスタをpop
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF

	# return
	lr35902_return
}

# 画像ファイルを表示
# in : regA - 表示する画像を指定する値(画像指定値)
#             - 上位4ビット：バンク番号
#             - 下位4ビット：ファイル番号(0始まり)
# ※ VRAMのタイルパターンテーブル(0x8000〜)は破壊される
f_tn_to_addr >src/f_tn_to_addr.o
fsz=$(to16 $(stat -c '%s' src/f_tn_to_addr.o))
fadr=$(calc16 "${a_tn_to_addr}+${fsz}")
a_view_img=$(four_digits $fadr)
echo -e "a_view_img=$a_view_img" >>$MAP_FILE_NAME
f_view_img() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC

	# 画像指定値をregBへ退避
	lr35902_copy_to_from regB regA

	# tdq.statにemptyフラグはセットされているか?
	lr35902_copy_to_regA_from_addr $var_tdq_stat
	lr35902_test_bitN_of_reg $GBOS_TDQ_STAT_BITNUM_EMPTY regA
	(
		# tdq.statにemptyフラグがセットされていない場合

		# 変数view_img_stateにtdq消費待ちを設定
		lr35902_set_reg regA $GBOS_VIEW_IMG_STAT_WAIT_FOR_TDQEMP
		lr35902_copy_to_addr_from_regA $var_view_img_state

		# pop & return
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_view_img.tdq_not_emp.o
	local sz_tdq_not_emp=$(stat -c '%s' src/f_view_img.tdq_not_emp.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_tdq_not_emp)
	cat src/f_view_img.tdq_not_emp.o

	# push
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# regCへ画像指定値からバンク番号を抽出
	lr35902_copy_to_from regC regB
	lr35902_shift_right_logical regC
	lr35902_shift_right_logical regC
	lr35902_shift_right_logical regC
	lr35902_shift_right_logical regC

	# 指定されたバンク番号 == 現在のバンク番号 ?
	lr35902_copy_to_regA_from_addr $var_current_rom_bank_no
	lr35902_compare_regA_and regC
	(
		# 指定されたバンク番号 != 現在のバンク番号 の場合

		# 指定されたバンク番号をMBCへ設定
		lr35902_copy_to_from regA regC
		lr35902_copy_to_addr_from_regA $GB_MBC_ROM_BANK_ADDR

		# 現在のバンク番号変数を更新
		lr35902_copy_to_addr_from_regA $var_current_rom_bank_no
	) >src/f_view_img.set_mbc.o
	local sz_set_mbc=$(stat -c '%s' src/f_view_img.set_mbc.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_set_mbc)
	cat src/f_view_img.set_mbc.o

	# regHLへ描画する画像データアドレスを取得
	## 「ファイルシステムベースアドレス」から「最初のファイルの『ファイルデータへのオフセット』」へのオフセット
	local file_ofs_1st_ofs=0008
	## regHLへファイルシステム領域ベースアドレスを設定
	lr35902_copy_to_regA_from_addr $var_fs_base_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_fs_base_th
	lr35902_copy_to_from regH regA
	## regDEへ「最初のファイルの『ファイルデータへのオフセット』」へのオフセットを設定
	lr35902_set_reg regDE $file_ofs_1st_ofs
	## regHL += regDE し、regHLへ最初のファイルの『ファイルデータへのオフセット』のアドレスを設定
	lr35902_add_to_regHL regDE
	## regAへ指定されたファイル番号を設定
	lr35902_copy_to_from regA regB
	lr35902_and_to_regA 0f
	## regA == 0 ?
	lr35902_compare_regA_and 00
	(
		# regA != 0 の場合
		# (描画するファイル番号が0以外の場合)

		# regDEへファイル属性情報1つ分のサイズを設定
		lr35902_set_reg regDE $(four_digits $GBOS_FS_FILE_ATTR_SZ)

		# 目的のファイルの『ファイルデータへのオフセット』に到達するまで
		# regHLへregDEを加算し続ける
		(
			# regHL += regDE
			lr35902_add_to_regHL regDE

			# regA--
			lr35902_dec regA
		) >src/f_view_img.1.o
		cat src/f_view_img.1.o
		local sz_1=$(stat -c '%s' src/f_view_img.1.o)
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_1 + 2)))
	) >src/f_view_img.2.o
	local sz_2=$(stat -c '%s' src/f_view_img.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
	cat src/f_view_img.2.o
	## regDEへファイルデータへのオフセット取得
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regE regA
	lr35902_copy_to_from regA ptrHL
	lr35902_copy_to_from regD regA
	## FSベースアドレスと足してregHLへファイルデータ先頭アドレス取得
	lr35902_copy_to_regA_from_addr $var_fs_base_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_fs_base_th
	lr35902_copy_to_from regH regA
	lr35902_add_to_regHL regDE
	## ファイルサイズ(2バイト)を飛ばす
	lr35902_inc regHL
	lr35902_inc regHL

	# V-Blankの開始を待つ
	# ※ regAFは破壊される
	gb_wait_for_vblank_to_start

	# LCDを停止する
	# - 停止の間はVRAMとOAMに自由にアクセスできる(vblankとか関係なく)
	lr35902_set_reg regA ${GBOS_LCDC_BASE}
	lr35902_copy_to_ioport_from_regA $GB_IO_LCDC

	# タイル定義領域の内容をVRAMのタイルパターンテーブル(0x8000〜)へコピー
	## regBCへタイル定義領域サイズを取得
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regC regA
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regB regA
	## regDE = VRAMのタイルパターンテーブルベースアドレス
	lr35902_set_reg regDE $GBOS_TILE_DATA_START
	## regBCのサイズ分だけregHLからregDEへコピー
	(
		# regA = ptrHL, regHL++
		lr35902_copyinc_to_regA_from_ptrHL

		# ptrDE = regA, regDE++
		lr35902_copy_to_from ptrDE regA
		lr35902_inc regDE

		# regBC--
		lr35902_dec regBC

		# regBC == 0 ならループを脱出
		lr35902_clear_reg regA
		lr35902_or_to_regA regC
		lr35902_or_to_regA regB
		lr35902_compare_regA_and 00
		lr35902_rel_jump_with_cond Z 02
	) >src/f_view_img.cpy_de_hl.o
	cat src/f_view_img.cpy_de_hl.o
	local sz_cpy_de_hl=$(stat -c '%s' src/f_view_img.cpy_de_hl.o)
	lr35902_rel_jump $(two_comp_d $((sz_cpy_de_hl + 2)))	# 2

	# 画像定義領域の内容をVRAMの背景マップ領域へ1行ずつコピー
	## regDEへVRAMの背景マップ領域のベースアドレスを設定
	lr35902_set_reg regDE $GBOS_BG_TILEMAP_START
	## regBへ表示領域の縦方向のタイル数(行数)を設定
	lr35902_set_reg regB $GB_DISP_HEIGHT_T
	## regBが0になるまでregHLからregDEへ表示領域の縦方向のタイル数ずつコピー
	(
		# ジャンプサイズ計算のため予めファイル書き出し
		## regDEを表示領域外のタイル数分進める処理
		(
			# regCへ表示領域外のタイル数を設定
			lr35902_set_reg regC $(calc16_2 "${GB_SC_WIDTH_T}-${GB_DISP_WIDTH_T}")

			# regDE += regC
			## regHLをスタックへ退避
			lr35902_push_reg regHL
			## regHL = regDE
			lr35902_copy_to_from regL regE
			lr35902_copy_to_from regH regD
			## regBをregAへ退避
			lr35902_copy_to_from regA regB
			## regB = 0
			lr35902_clear_reg regB
			## regHL += regBC
			lr35902_add_to_regHL regBC
			## regDE = regHL
			lr35902_copy_to_from regE regL
			lr35902_copy_to_from regD regH
			## regBをregAから復帰
			lr35902_copy_to_from regB regA
			## regHLをスタックから復帰
			lr35902_pop_reg regHL
		) >src/f_view_img.fwd_de.o
		local sz_fwd_de=$(stat -c '%s' src/f_view_img.fwd_de.o)

		# regHLからregDEへ表示領域の縦方向のタイル数分コピー
		## regCへ表示領域の横方向のタイル数を設定
		lr35902_set_reg regC $GB_DISP_WIDTH_T
		## regCの数だけregHLからregDEへコピー
		(
			# regA = ptrHL, regHL++
			lr35902_copyinc_to_regA_from_ptrHL

			# ptrDE = regA, regDE++
			lr35902_copy_to_from ptrDE regA
			lr35902_inc regDE

			# regC--
			lr35902_dec regC

			# regC == 0 ならループを脱出
			lr35902_rel_jump_with_cond Z 02
		) >src/f_view_img.cpy_line.o
		cat src/f_view_img.cpy_line.o
		local sz_cpy_line=$(stat -c '%s' src/f_view_img.cpy_line.o)
		lr35902_rel_jump $(two_comp_d $((sz_cpy_line + 2)))	# 2

		# regB--
		lr35902_dec regB

		# regB == 0 ならループを脱出
		lr35902_rel_jump_with_cond Z $(two_digits_d $((sz_fwd_de + 2)))

		# regDEを表示領域外のタイル数分進める
		cat src/f_view_img.fwd_de.o
	) >src/f_view_img.cpy_bg.o
	cat src/f_view_img.cpy_bg.o
	local sz_cpy_bg=$(stat -c '%s' src/f_view_img.cpy_bg.o)
	lr35902_rel_jump $(two_comp_d $((sz_cpy_bg + 2)))	# 2

	# スプライトオフでLCD再開
	lr35902_set_reg regA $(calc16 "${GBOS_LCDC_BASE}+${GB_LCDC_BIT_DE}-${GB_LCDC_BIT_OBJE}")
	lr35902_copy_to_ioport_from_regA $GB_IO_LCDC

	# 変数mouse_enableにマウス無効化設定
	lr35902_clear_reg regA
	lr35902_copy_to_addr_from_regA $var_mouse_enable

	# 変数view_img_stateに画像表示中を設定
	lr35902_set_reg regA $GBOS_VIEW_IMG_STAT_DURING_IMG_DISP
	lr35902_copy_to_addr_from_regA $var_view_img_state

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 画像ファイルの表示を終了する
f_view_img >src/f_view_img.o
fsz=$(to16 $(stat -c '%s' src/f_view_img.o))
fadr=$(calc16 "${a_view_img}+${fsz}")
a_quit_img=$(four_digits $fadr)
echo -e "a_quit_img=$a_quit_img" >>$MAP_FILE_NAME
f_quit_img() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# V-Blankの開始を待つ
	# ※ regAFは破壊される
	gb_wait_for_vblank_to_start

	# LCDを停止する
	# - 停止の間はVRAMとOAMに自由にアクセスできる(vblankとか関係なく)
	lr35902_set_reg regA ${GBOS_LCDC_BASE}
	lr35902_copy_to_ioport_from_regA $GB_IO_LCDC

	# VRAMの背景マップ領域をタイルミラー領域からコピーする形で復帰
	# 表示領域のタイルを1行ずつタイルミラー領域から復帰する
	## regHLへタイルミラー領域ベースアドレス設定
	lr35902_set_reg regHL $GBOS_TMRR_BASE
	## regDEへ背景マップ領域ベースアドレス設定
	lr35902_set_reg regDE $GBOS_BG_TILEMAP_START
	## regBへ表示領域の縦方向のタイル数(行数)を設定
	lr35902_set_reg regB $GB_DISP_HEIGHT_T
	## regBが0になるまでregHLからregDEへ表示領域の縦方向のタイル数ずつコピー
	(
		# ジャンプサイズ計算のため予めファイル書き出し
		## regHLとregDEを表示領域外のタイル数分進める処理
		(
			# regCへ表示領域外のタイル数を設定
			lr35902_set_reg regC $(calc16_2 "${GB_SC_WIDTH_T}-${GB_DISP_WIDTH_T}")

			# regBをregAへ退避
			lr35902_copy_to_from regA regB

			# regB = 0
			lr35902_clear_reg regB

			# regHL += regBC
			lr35902_add_to_regHL regBC

			# regDE += regBC
			## regHLをスタックへ退避
			lr35902_push_reg regHL
			## regHL = regDE
			lr35902_copy_to_from regL regE
			lr35902_copy_to_from regH regD
			## regHL += regBC
			lr35902_add_to_regHL regBC
			## regDE = regHL
			lr35902_copy_to_from regE regL
			lr35902_copy_to_from regD regH
			## regHLをスタックから復帰
			lr35902_pop_reg regHL

			# regBをregAから復帰
			lr35902_copy_to_from regB regA
		) >src/f_quit_img.fwd_hl_de.o
		local sz_fwd_hl_de=$(stat -c '%s' src/f_quit_img.fwd_hl_de.o)

		# regHLからregDEへ表示領域の縦方向のタイル数分コピー
		## regCへ表示領域の横方向のタイル数を設定
		lr35902_set_reg regC $GB_DISP_WIDTH_T
		## regCの数だけregHLからregDEへコピー
		(
			# regA = ptrHL, regHL++
			lr35902_copyinc_to_regA_from_ptrHL

			# ptrDE = regA, regDE++
			lr35902_copy_to_from ptrDE regA
			lr35902_inc regDE

			# regC--
			lr35902_dec regC

			# regC == 0 ならループを脱出
			lr35902_rel_jump_with_cond Z 02
		) >src/f_quit_img.cpy_line.o
		cat src/f_quit_img.cpy_line.o
		local sz_cpy_line=$(stat -c '%s' src/f_quit_img.cpy_line.o)
		lr35902_rel_jump $(two_comp_d $((sz_cpy_line + 2)))	# 2

		# regB--
		lr35902_dec regB

		# regB == 0 ならループを脱出
		lr35902_rel_jump_with_cond Z $(two_digits_d $((sz_fwd_hl_de + 2)))

		# regHLとregDEを表示領域外のタイル数分進める
		cat src/f_quit_img.fwd_hl_de.o
	) >src/f_quit_img.restore_bg.o
	cat src/f_quit_img.restore_bg.o
	local sz_restore_bg=$(stat -c '%s' src/f_quit_img.restore_bg.o)
	lr35902_rel_jump $(two_comp_d $((sz_restore_bg + 2)))	# 2

	# VRAMのタイルパターンテーブルを初期化(元に戻す)
	# ※ regAF・regDE・regHLは破壊される
	load_all_tiles

	# スプライトオンでLCD再開
	lr35902_set_reg regA $(calc16 "${GBOS_LCDC_BASE}+${GB_LCDC_BIT_DE}")
	lr35902_copy_to_ioport_from_regA $GB_IO_LCDC

	# 変数mouse_enableにマウス有効化設定
	lr35902_set_reg regA 01
	lr35902_copy_to_addr_from_regA $var_mouse_enable

	# 変数view_img_stateに画像表示なしを設定
	lr35902_set_reg regA $GBOS_VIEW_IMG_STAT_NONE
	lr35902_copy_to_addr_from_regA $var_view_img_state

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# タイルデータを復帰する周期ハンドラを登録する関数
f_quit_img >src/f_quit_img.o
fsz=$(to16 $(stat -c '%s' src/f_quit_img.o))
fadr=$(calc16 "${a_quit_img}+${fsz}")
a_rstr_tiles=$(four_digits $fadr)
echo -e "a_rstr_tiles=$a_rstr_tiles" >>$MAP_FILE_NAME
f_rstr_tiles() {
	# push
	lr35902_push_reg regAF

	# TODO rstr_tiles_cycで使用する変数設定
	local ntadr=$(calc16 "${GBOS_TILE_DATA_START}+300")
	lr35902_set_reg regA $(echo $ntadr | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_view_img_ntadr_bh
	lr35902_set_reg regA $(echo $ntadr | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_view_img_ntadr_th

	# DASへタイルデータ復帰のビットをセット
	lr35902_copy_to_regA_from_addr $var_draw_act_stat
	lr35902_set_bitN_of_reg $GBOS_DA_BITNUM_RSTR_TILES regA
	lr35902_copy_to_addr_from_regA $var_draw_act_stat

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# タイルデータを復帰する周期関数
f_rstr_tiles >src/f_rstr_tiles.o
fsz=$(to16 $(stat -c '%s' src/f_rstr_tiles.o))
fadr=$(calc16 "${a_rstr_tiles}+${fsz}")
a_rstr_tiles_cyc=$(four_digits $fadr)
echo -e "a_rstr_tiles_cyc=$a_rstr_tiles_cyc" >>$MAP_FILE_NAME
f_rstr_tiles_cyc() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 復帰するタイルのアドレスをHLへ設定
	## var_view_img_ntadr変数を流用する
	lr35902_copy_to_regA_from_addr $var_view_img_ntadr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_view_img_ntadr_th
	lr35902_copy_to_from regH regA

	# 退避場所のメモリアドレスをDEへ設定
	## HL+5000hを設定する(D300h-)
	lr35902_push_reg regHL
	lr35902_set_reg regBC 5000
	lr35902_add_to_regHL regBC
	lr35902_copy_to_from regD regH
	lr35902_copy_to_from regE regL
	lr35902_pop_reg regHL

	# Cへ16を設定(ループ用カウンタ。16バイト)
	lr35902_set_reg regC 10

	# Cの数だけ1バイトずつ[DE]->[HL]へコピー
	(
		lr35902_copy_to_from regA ptrDE
		lr35902_copyinc_to_ptrHL_from_regA
		lr35902_inc regDE
		lr35902_dec regC
	) >src/f_rstr_tiles_cyc.1.o
	cat src/f_rstr_tiles_cyc.1.o
	local sz_1=$(stat -c '%s' src/f_rstr_tiles_cyc.1.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_1+2)))

	# この周期処理の終了判定
	local ntlast=$(calc16 "${GBOS_TILE_DATA_START}+${GBOS_NUM_ALL_TILE_BYTES}")
	local ntlast_th=$(echo $ntlast | cut -c1-2)
	local ntlast_bh=$(echo $ntlast | cut -c3-4)
	lr35902_copy_to_from regA regH
	lr35902_compare_regA_and $ntlast_th
	(
		# A != $ntlast_th の場合

		# HLを変数へ保存
		lr35902_copy_to_from regA regL
		lr35902_copy_to_addr_from_regA $var_view_img_ntadr_bh
		lr35902_copy_to_from regA regH
		lr35902_copy_to_addr_from_regA $var_view_img_ntadr_th
	) >src/f_rstr_tiles_cyc.2.o
	(
		# A == $ntlast_th の場合

		lr35902_copy_to_from regA regL
		lr35902_compare_regA_and $ntlast_bh
		(
			# A == $ntlast_bh の場合

			# DAのGBOS_DA_BITNUM_RSTR_TILESのビットを下ろす
			lr35902_copy_to_regA_from_addr $var_draw_act_stat
			lr35902_res_bitN_of_reg $GBOS_DA_BITNUM_RSTR_TILES regA
			lr35902_copy_to_addr_from_regA $var_draw_act_stat

			# 続く A != $ntlast_th の場合の処理を飛ばす
			local sz_2=$(stat -c '%s' src/f_rstr_tiles_cyc.2.o)
			lr35902_rel_jump $(two_digits_d $sz_2)
		) >src/f_rstr_tiles_cyc.3.o
		local sz_3=$(stat -c '%s' src/f_rstr_tiles_cyc.3.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
		## A == $ntlast_bh の場合
		cat src/f_rstr_tiles_cyc.3.o
	) >src/f_rstr_tiles_cyc.4.o
	local sz_4=$(stat -c '%s' src/f_rstr_tiles_cyc.4.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
	## A == $ntlast_th の場合
	cat src/f_rstr_tiles_cyc.4.o
	## A != $ntlast_th の場合
	cat src/f_rstr_tiles_cyc.2.o

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# ディレクトリを表示
## TODO 今の所ルートディレクトリ固定
f_rstr_tiles_cyc >src/f_rstr_tiles_cyc.o
fsz=$(to16 $(stat -c '%s' src/f_rstr_tiles_cyc.o))
fadr=$(calc16 "${a_rstr_tiles_cyc}+${fsz}")
a_view_dir=$(four_digits $fadr)
echo -e "a_view_dir=$a_view_dir" >>$MAP_FILE_NAME
f_view_dir() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# ファイルシステム上のファイル数が0でないか確認
	lr35902_copy_to_regA_from_addr $var_fs_base_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_fs_base_th
	lr35902_copy_to_from regH regA
	lr35902_copy_to_from regA ptrHL
	lr35902_or_to_regA regA
	(
		# ファイル数 != 0

		# 0番目のファイルから表示する
		lr35902_clear_reg regA
		lr35902_copy_to_addr_from_regA $var_view_dir_file_th

		# DASへディレクトリ表示のビットをセット
		lr35902_copy_to_regA_from_addr $var_draw_act_stat
		lr35902_set_bitN_of_reg $GBOS_DA_BITNUM_VIEW_DIR regA
		lr35902_copy_to_addr_from_regA $var_draw_act_stat
	) >src/f_view_dir.1.o
	local sz_1=$(stat -c '%s' src/f_view_dir.1.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_1)
	cat src/f_view_dir.1.o

	# ウィンドウステータスにディレクトリ表示中のビットをセット
	lr35902_copy_to_regA_from_addr $var_win_stat
	lr35902_set_bitN_of_reg $GBOS_WST_BITNUM_DIR regA
	lr35902_copy_to_addr_from_regA $var_win_stat

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
	lr35902_return
}

# ディレクトリを表示する周期関数
## TODO 今の所ルートディレクトリのみ
f_view_dir >src/f_view_dir.o
fsz=$(to16 $(stat -c '%s' src/f_view_dir.o))
fadr=$(calc16 "${a_view_dir}+${fsz}")
a_view_dir_cyc=$(four_digits $fadr)
echo -e "a_view_dir_cyc=$a_view_dir_cyc" >>$MAP_FILE_NAME
# アイコンを配置するウィンドウY座標を
# レジスタAに格納されたファイル番目で算出し
# レジスタDへ設定
set_icon_wy_to_regD_calc_from_regA() {
	# ファイル番目のビット3-2を抽出
	lr35902_and_to_regA 0c
	(
		# ファイル番目[3:2] == 01 or 10 or 11
		lr35902_compare_regA_and 04
		(
			# ファイル番目[3:2] == 10 or 11
			lr35902_compare_regA_and 08
			(
				# ファイル番目[3:2] == 11
				lr35902_set_reg regD 0c
			) >src/set_icon_wy_to_regD_calc_from_regA.6.o
			(
				# ファイル番目[3:2] == 10
				lr35902_set_reg regD 09

				# 「ファイル番目[3:2] == 11」の処理を飛ばす
				local sz_6=$(stat -c '%s' src/set_icon_wy_to_regD_calc_from_regA.6.o)
				lr35902_rel_jump $(two_digits_d $sz_6)
			) >src/set_icon_wy_to_regD_calc_from_regA.5.o
			local sz_5=$(stat -c '%s' src/set_icon_wy_to_regD_calc_from_regA.5.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_5)
			cat src/set_icon_wy_to_regD_calc_from_regA.5.o
			cat src/set_icon_wy_to_regD_calc_from_regA.6.o
		) >src/set_icon_wy_to_regD_calc_from_regA.4.o
		(
			# ファイル番目[3:2] == 01
			lr35902_set_reg regD 06

			# 「ファイル番目[3:2] == 10 or 11」の処理を飛ばす
			local sz_4=$(stat -c '%s' src/set_icon_wy_to_regD_calc_from_regA.4.o)
			lr35902_rel_jump $(two_digits_d $sz_4)
		) >src/set_icon_wy_to_regD_calc_from_regA.3.o
		local sz_3=$(stat -c '%s' src/set_icon_wy_to_regD_calc_from_regA.3.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
		cat src/set_icon_wy_to_regD_calc_from_regA.3.o
		cat src/set_icon_wy_to_regD_calc_from_regA.4.o
	) >src/set_icon_wy_to_regD_calc_from_regA.2.o
	(
		# ファイル番目[3:2] == 00
		lr35902_set_reg regD 03

		# 「ファイル番目[3:2] == 01 or 10 or 11」の処理を飛ばす
		local sz_2=$(stat -c '%s' src/set_icon_wy_to_regD_calc_from_regA.2.o)
		lr35902_rel_jump $(two_digits_d $sz_2)
	) >src/set_icon_wy_to_regD_calc_from_regA.1.o
	local sz_1=$(stat -c '%s' src/set_icon_wy_to_regD_calc_from_regA.1.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
	cat src/set_icon_wy_to_regD_calc_from_regA.1.o
	cat src/set_icon_wy_to_regD_calc_from_regA.2.o
}
# アイコンを配置するウィンドウX座標を
# レジスタAに格納されたファイル番目で算出し
# レジスタEへ設定
set_icon_wx_to_regE_calc_from_regA() {
	# ファイル番目のビット1-0を抽出
	lr35902_and_to_regA 03
	(
		# ファイル番目[1:0] == 01 or 10 or 11
		lr35902_compare_regA_and 01
		(
			# ファイル番目[1:0] == 10 or 11
			lr35902_compare_regA_and 02
			(
				# ファイル番目[1:0] == 11
				lr35902_set_reg regE 0f
			) >src/set_icon_wx_to_regE_calc_from_regA.6.o
			(
				# ファイル番目[1:0] == 10
				lr35902_set_reg regE 0b

				# 「ファイル番目[1:0] == 11」の処理を飛ばす
				local sz_6=$(stat -c '%s' src/set_icon_wx_to_regE_calc_from_regA.6.o)
				lr35902_rel_jump $(two_digits_d $sz_6)
			) >src/set_icon_wx_to_regE_calc_from_regA.5.o
			local sz_5=$(stat -c '%s' src/set_icon_wx_to_regE_calc_from_regA.5.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_5)
			cat src/set_icon_wx_to_regE_calc_from_regA.5.o
			cat src/set_icon_wx_to_regE_calc_from_regA.6.o
		) >src/set_icon_wx_to_regE_calc_from_regA.4.o
		(
			# ファイル番目[1:0] == 01
			lr35902_set_reg regE 07

			# 「ファイル番目[1:0] == 10 or 11」の処理を飛ばす
			local sz_4=$(stat -c '%s' src/set_icon_wx_to_regE_calc_from_regA.4.o)
			lr35902_rel_jump $(two_digits_d $sz_4)
		) >src/set_icon_wx_to_regE_calc_from_regA.3.o
		local sz_3=$(stat -c '%s' src/set_icon_wx_to_regE_calc_from_regA.3.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
		cat src/set_icon_wx_to_regE_calc_from_regA.3.o
		cat src/set_icon_wx_to_regE_calc_from_regA.4.o
	) >src/set_icon_wx_to_regE_calc_from_regA.2.o
	(
		# ファイル番目[1:0] == 00
		lr35902_set_reg regE 03

		# 「ファイル番目[1:0] == 01 or 10 or 11」の処理を飛ばす
		local sz_2=$(stat -c '%s' src/set_icon_wx_to_regE_calc_from_regA.2.o)
		lr35902_rel_jump $(two_digits_d $sz_2)
	) >src/set_icon_wx_to_regE_calc_from_regA.1.o
	local sz_1=$(stat -c '%s' src/set_icon_wx_to_regE_calc_from_regA.1.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
	cat src/set_icon_wx_to_regE_calc_from_regA.1.o
	cat src/set_icon_wx_to_regE_calc_from_regA.2.o
}
f_view_dir_cyc() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 表示するファイル番目を変数からBへ取得
	lr35902_copy_to_regA_from_addr $var_view_dir_file_th
	lr35902_copy_to_from regB regA

	# アイコンを置くウィンドウ座標(X,Y)を(E,D)へ設定
	set_icon_wy_to_regD_calc_from_regA
	lr35902_copy_to_from regA regB
	set_icon_wx_to_regE_calc_from_regA

	# アイコン番号をAへ設定
	## DEを使うのでpush
	lr35902_push_reg regDE
	## TODO ルートディレクトリ固定なので
	##      1つ目のファイルのファイルタイプへのオフセットは0x0007固定
	local file_type_ofs=0007
	## 1つ目のファイルタイプアドレスをHLへ格納
	lr35902_copy_to_regA_from_addr $var_fs_base_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_fs_base_th
	lr35902_copy_to_from regH regA
	lr35902_set_reg regDE $file_type_ofs
	lr35902_add_to_regHL regDE
	## 0番目のファイルであるか否か
	lr35902_copy_to_from regA regB
	lr35902_compare_regA_and 00
	(
		# 0番目のファイルの場合

		# ファイルタイプをAへ格納
		lr35902_copy_to_from regA ptrHL
	) >src/f_view_dir_cyc.1.o
	(
		# 1番目以降のファイルの場合

		# 次のファイルタイプアドレスへのオフセットをDEへ格納
		lr35902_set_reg regDE $(four_digits $GBOS_FS_FILE_ATTR_SZ)

		# 表示するファイル番目をCへコピー
		lr35902_copy_to_from regC regB

		# 現在のファイル番目のファイルタイプのアドレス取得
		(
			lr35902_add_to_regHL regDE
			lr35902_dec regC
		) >src/f_view_dir_cyc.3.o
		cat src/f_view_dir_cyc.3.o
		local sz_3=$(stat -c '%s' src/f_view_dir_cyc.3.o)
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_3 + 2)))

		# ファイルタイプをAへ格納
		lr35902_copy_to_from regA ptrHL

		# 0番目の場合の処理を飛ばす
		local sz_1=$(stat -c '%s' src/f_view_dir_cyc.1.o)
		lr35902_rel_jump $(two_digits_d $sz_1)
	) >src/f_view_dir_cyc.2.o
	local sz_2=$(stat -c '%s' src/f_view_dir_cyc.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
	## 1番目以降のファイルの場合
	cat src/f_view_dir_cyc.2.o
	## 0番目のファイルの場合
	cat src/f_view_dir_cyc.1.o
	## DEを元に戻す(pop)
	lr35902_pop_reg regDE

	# アイコンを描画
	lr35902_call $a_lay_icon

	# ファイル番目をインクリメント
	lr35902_inc regB

	# ディレクトリのファイル数取得
	## TODO ルートディレクトリ固定なのでオフセットは0x0000固定
	lr35902_copy_to_regA_from_addr $var_fs_base_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_fs_base_th
	lr35902_copy_to_from regH regA
	lr35902_copy_to_from regA ptrHL

	# 終了判定
	## ファイル数(A) == 次に表示するファイル番目(B) だったら終了
	lr35902_compare_regA_and regB
	(
		# ファイル数(A) == 次に表示するファイル番目(B) の場合

		# DAのGBOS_DA_BITNUM_VIEW_DIRのビットを下ろす
		lr35902_copy_to_regA_from_addr $var_draw_act_stat
		lr35902_res_bitN_of_reg $GBOS_DA_BITNUM_VIEW_DIR regA
		lr35902_copy_to_addr_from_regA $var_draw_act_stat
	) >src/f_view_dir_cyc.4.o
	(
		# ファイル数(A) != 次に表示するファイル番目(B) の場合

		# 表示するファイル番目の変数を更新
		lr35902_copy_to_from regA regB
		lr35902_copy_to_addr_from_regA $var_view_dir_file_th

		# ファイル数(A) == 次に表示するファイル番目(B) の場合の処理を飛ばす
		local sz_4=$(stat -c '%s' src/f_view_dir_cyc.4.o)
		lr35902_rel_jump $(two_digits_d $sz_4)
	) >src/f_view_dir_cyc.5.o
	local sz_5=$(stat -c '%s' src/f_view_dir_cyc.5.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_5)
	## ファイル数(A) != 次に表示するファイル番目(B) の場合
	cat src/f_view_dir_cyc.5.o
	## ファイル数(A) == 次に表示するファイル番目(B) の場合
	cat src/f_view_dir_cyc.4.o

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# アイコン領域のクリック確認(X軸)
# in : var_mouse_x変数
# out: regA - クリック位置のファイル番号の下位2ビットをbit[1:0]に設定
#             クリック位置がアイコン領域外の場合 $80 を設定
#             ※ bit[1:0]はビットセットのみ行うので、予めクリアしておくこと
# ※ OBJ座標系は右下原点なのでマウスX座標はカーソル先端(左上)から+8ピクセル
f_view_dir_cyc >src/f_view_dir_cyc.o
fsz=$(to16 $(stat -c '%s' src/f_view_dir_cyc.o))
fadr=$(calc16 "${a_view_dir_cyc}+${fsz}")
a_check_click_icon_area_x=$(four_digits $fadr)
echo -e "a_check_click_icon_area_x=$a_check_click_icon_area_x" >>$MAP_FILE_NAME
f_check_click_icon_area_x() {
	# push
	lr35902_push_reg regAF

	# マウス座標(X)を取得
	lr35902_copy_to_regA_from_addr $var_mouse_x

	# A >= 16 ?
	lr35902_compare_regA_and 18
	(
		# A >= 16 の場合

		# A < 48 ?
		lr35902_compare_regA_and 38
		(
			# A < 48 の場合

			# pop & return
			lr35902_pop_reg regAF
			## bit[1:0] = %00
			lr35902_return
		) >src/f_check_click_icon_area_x.1.o
		local sz_1=$(stat -c '%s' src/f_check_click_icon_area_x.1.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_1)
		cat src/f_check_click_icon_area_x.1.o
	) >src/f_check_click_icon_area_x.2.o
	local sz_2=$(stat -c '%s' src/f_check_click_icon_area_x.2.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_2)
	cat src/f_check_click_icon_area_x.2.o

	# A >= 48 ?
	lr35902_compare_regA_and 38
	(
		# A >= 48 の場合

		# A < 80 ?
		lr35902_compare_regA_and 58
		(
			# A < 80 の場合

			# pop & return
			lr35902_pop_reg regAF
			## bit[1:0] = %01
			lr35902_add_to_regA 01
			lr35902_return
		) >src/f_check_click_icon_area_x.3.o
		local sz_3=$(stat -c '%s' src/f_check_click_icon_area_x.3.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_3)
		cat src/f_check_click_icon_area_x.3.o
	) >src/f_check_click_icon_area_x.4.o
	local sz_4=$(stat -c '%s' src/f_check_click_icon_area_x.4.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_4)
	cat src/f_check_click_icon_area_x.4.o

	# A >= 80 ?
	lr35902_compare_regA_and 58
	(
		# A >= 80 の場合

		# A < 112 ?
		lr35902_compare_regA_and 78
		(
			# A < 112 の場合

			# pop & return
			lr35902_pop_reg regAF
			## bit[1:0] = %10
			lr35902_add_to_regA 02
			lr35902_return
		) >src/f_check_click_icon_area_x.5.o
		local sz_5=$(stat -c '%s' src/f_check_click_icon_area_x.5.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_5)
		cat src/f_check_click_icon_area_x.5.o
	) >src/f_check_click_icon_area_x.6.o
	local sz_6=$(stat -c '%s' src/f_check_click_icon_area_x.6.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_6)
	cat src/f_check_click_icon_area_x.6.o

	# A >= 112 ?
	lr35902_compare_regA_and 78
	(
		# A >= 112 の場合

		# A < 144 ?
		lr35902_compare_regA_and 98
		(
			# A < 144 の場合

			# pop & return
			lr35902_pop_reg regAF
			## bit[1:0] = %11
			lr35902_add_to_regA 03
			lr35902_return
		) >src/f_check_click_icon_area_x.7.o
		local sz_7=$(stat -c '%s' src/f_check_click_icon_area_x.7.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_7)
		cat src/f_check_click_icon_area_x.7.o
	) >src/f_check_click_icon_area_x.8.o
	local sz_8=$(stat -c '%s' src/f_check_click_icon_area_x.8.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_8)
	cat src/f_check_click_icon_area_x.8.o

	# pop & return
	lr35902_pop_reg regAF
	lr35902_set_reg regA 80	# アイコン領域外
	lr35902_return
}

# アイコン領域のクリック確認(Y軸)
# in : var_mouse_y変数
# out: regA - クリック位置のファイル番号のbit[3:2]をAレジスタのbit[3:2]に設定
#             クリック位置がアイコン領域外の場合 $80 を設定
#             ※ bit[3:2]はビットセットのみ行うので、予めクリアしておくこと
# ※ OBJ座標系は右下原点なのでマウスY座標はカーソル先端(左上)から+16ピクセル
f_check_click_icon_area_x >src/f_check_click_icon_area_x.o
fsz=$(to16 $(stat -c '%s' src/f_check_click_icon_area_x.o))
fadr=$(calc16 "${a_check_click_icon_area_x}+${fsz}")
a_check_click_icon_area_y=$(four_digits $fadr)
echo -e "a_check_click_icon_area_y=$a_check_click_icon_area_y" >>$MAP_FILE_NAME
f_check_click_icon_area_y() {
	# push
	lr35902_push_reg regAF

	# マウス座標(Y)を取得
	lr35902_copy_to_regA_from_addr $var_mouse_y

	# A >= 24 ?
	lr35902_compare_regA_and 28
	(
		# A >= 24 の場合

		# A < 48 ?
		lr35902_compare_regA_and 40
		(
			# A < 48 の場合

			# pop & return
			lr35902_pop_reg regAF
			## bit[3:2] = %00
			lr35902_return
		) >src/f_check_click_icon_area_y.1.o
		local sz_1=$(stat -c '%s' src/f_check_click_icon_area_y.1.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_1)
		cat src/f_check_click_icon_area_y.1.o
	) >src/f_check_click_icon_area_y.2.o
	local sz_2=$(stat -c '%s' src/f_check_click_icon_area_y.2.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_2)
	cat src/f_check_click_icon_area_y.2.o

	# A >= 48 ?
	lr35902_compare_regA_and 40
	(
		# A >= 48 の場合

		# A < 72 ?
		lr35902_compare_regA_and 58
		(
			# A < 72 の場合

			# pop & return
			lr35902_pop_reg regAF
			## bit[3:2] = %01
			lr35902_add_to_regA 04
			lr35902_return
		) >src/f_check_click_icon_area_y.3.o
		local sz_3=$(stat -c '%s' src/f_check_click_icon_area_y.3.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_3)
		cat src/f_check_click_icon_area_y.3.o
	) >src/f_check_click_icon_area_y.4.o
	local sz_4=$(stat -c '%s' src/f_check_click_icon_area_y.4.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_4)
	cat src/f_check_click_icon_area_y.4.o

	# A >= 72 ?
	lr35902_compare_regA_and 58
	(
		# A >= 72 の場合

		# A < 96 ?
		lr35902_compare_regA_and 70
		(
			# A < 96 の場合

			# pop & return
			lr35902_pop_reg regAF
			## bit[3:2] = %10
			lr35902_add_to_regA 08
			lr35902_return
		) >src/f_check_click_icon_area_y.5.o
		local sz_5=$(stat -c '%s' src/f_check_click_icon_area_y.5.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_5)
		cat src/f_check_click_icon_area_y.5.o
	) >src/f_check_click_icon_area_y.6.o
	local sz_6=$(stat -c '%s' src/f_check_click_icon_area_y.6.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_6)
	cat src/f_check_click_icon_area_y.6.o

	# A >= 96 ?
	lr35902_compare_regA_and 70
	(
		# A >= 96 の場合

		# A < 120 ?
		lr35902_compare_regA_and 88
		(
			# A < 120 の場合

			# pop & return
			lr35902_pop_reg regAF
			## bit[3:2] = %11
			lr35902_add_to_regA 0c
			lr35902_return
		) >src/f_check_click_icon_area_y.7.o
		local sz_7=$(stat -c '%s' src/f_check_click_icon_area_y.7.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_7)
		cat src/f_check_click_icon_area_y.7.o
	) >src/f_check_click_icon_area_y.8.o
	local sz_8=$(stat -c '%s' src/f_check_click_icon_area_y.8.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_8)
	cat src/f_check_click_icon_area_y.8.o

	# pop & return
	lr35902_pop_reg regAF
	lr35902_set_reg regA 80	# アイコン領域外
	lr35902_return
}

# コンソールを初期化する
f_check_click_icon_area_y >src/f_check_click_icon_area_y.o
fsz=$(to16 $(stat -c '%s' src/f_check_click_icon_area_y.o))
fadr=$(calc16 "${a_check_click_icon_area_y}+${fsz}")
a_init_con=$(four_digits $fadr)
echo -e "a_init_con=$a_init_con" >>$MAP_FILE_NAME
f_init_con() {
	# コンソールの初期化
	con_init

	# return
	lr35902_return
}

# 実行ファイル実行開始関数
# in : regHL - ファイルサイズ・データ先頭アドレス
f_init_con >src/f_init_con.o
fsz=$(to16 $(stat -c '%s' src/f_init_con.o))
fadr=$(calc16 "${a_init_con}+${fsz}")
a_run_exe=$(four_digits $fadr)
echo -e "a_run_exe=$a_run_exe" >>$MAP_FILE_NAME
f_run_exe() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 画面クリアをDAへ登録
	lr35902_call $a_clr_win

	# RAM(0xD000-)へロード
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regC regA
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regB regA
	lr35902_set_reg regDE $GBOS_APP_MEM_BASE
	lr35902_push_reg regHL
	lr35902_copy_to_from regL regE
	lr35902_copy_to_from regH regD
	lr35902_add_to_regHL regBC
	lr35902_copy_to_from regC regL
	lr35902_copy_to_from regB regH
	lr35902_pop_reg regHL
	(
		(
			lr35902_copyinc_to_regA_from_ptrHL
			lr35902_copy_to_from ptrDE regA
			lr35902_inc regDE

			# DE != BC の間ループする

			# D == B ?
			lr35902_copy_to_from regA regD
			lr35902_compare_regA_and regB
		) >src/f_run_exe.1.o
		cat src/f_run_exe.1.o
		local sz_1=$(stat -c '%s' src/f_run_exe.1.o)
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_1 + 2)))

		# E == C ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and regC
	) >src/f_run_exe.2.o
	cat src/f_run_exe.2.o
	local sz_2=$(stat -c '%s' src/f_run_exe.2.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_2 + 2)))

	# DASにrun_exeのビットをセット
	lr35902_copy_to_regA_from_addr $var_draw_act_stat
	lr35902_set_bitN_of_reg $GBOS_DA_BITNUM_RUN_EXE regA
	lr35902_copy_to_addr_from_regA $var_draw_act_stat

	# ウィンドウステータスに「実行ファイル実行中」のみを設定
	lr35902_set_reg regA $GBOS_WST_NUM_EXE
	lr35902_copy_to_addr_from_regA $var_win_stat

	# アプリ用ボタンリリースフラグをクリア
	lr35902_clear_reg regA
	lr35902_copy_to_addr_from_regA $var_app_release_btn

	# コンソールの初期化
	lr35902_call $a_init_con

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 実行ファイル周期実行関数
f_run_exe >src/f_run_exe.o
fsz=$(to16 $(stat -c '%s' src/f_run_exe.o))
fadr=$(calc16 "${a_run_exe}+${fsz}")
a_run_exe_cyc=$(four_digits $fadr)
echo -e "a_run_exe_cyc=$a_run_exe_cyc" >>$MAP_FILE_NAME
f_run_exe_cyc() {
	# push
	lr35902_push_reg regAF

	# $GBOS_APP_MEM_BASE をcall
	lr35902_call $GBOS_APP_MEM_BASE

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# tdqを初期化する
f_run_exe_cyc >src/f_run_exe_cyc.o
fsz=$(to16 $(stat -c '%s' src/f_run_exe_cyc.o))
fadr=$(calc16 "${a_run_exe_cyc}+${fsz}")
a_init_tdq=$(four_digits $fadr)
echo -e "a_init_tdq=$a_init_tdq" >>$MAP_FILE_NAME
f_init_tdq() {
	tdq_init

	# return
	lr35902_return
}

# tdqへエンキューする
# in : regB  - 配置するタイル番号
#      regD  - VRAMアドレス[15:8]
#      regE  - VRAMアドレス[7:0]
f_init_tdq >src/f_init_tdq.o
fsz=$(to16 $(stat -c '%s' src/f_init_tdq.o))
fadr=$(calc16 "${a_init_tdq}+${fsz}")
a_enq_tdq=$(four_digits $fadr)
echo -e "a_enq_tdq=$a_enq_tdq" >>$MAP_FILE_NAME
f_enq_tdq() {
	tdq_enq

	# return
	lr35902_return
}

# 指定された1バイトの下位4ビットを表す16進の文字に対応するタイル番号を返す
# in : regA - タイル番号へ変換する1バイト
# out: regB - タイル番号
f_enq_tdq >src/f_enq_tdq.o
fsz=$(to16 $(stat -c '%s' src/f_enq_tdq.o))
fadr=$(calc16 "${a_enq_tdq}+${fsz}")
a_byte_to_tile=$(four_digits $fadr)
echo -e "a_byte_to_tile=$a_byte_to_tile" >>$MAP_FILE_NAME
f_byte_to_tile() {
	# push
	lr35902_push_reg regAF

	# 下位4ビットを抽出
	lr35902_and_to_regA 0f

	# regA < 0x0A ?
	lr35902_compare_regA_and 0a
	(
		# regA < 0x0A (数字で表現) の場合

		lr35902_add_to_regA $GBOS_TILE_NUM_NUM_BASE
	) >src/f_byte_to_tile.2.o
	(
		# regA >= 0x0A (アルファベットで表現) の場合

		lr35902_sub_to_regA 0a
		lr35902_add_to_regA $GBOS_TILE_NUM_ALPHA_BASE

		# regA < 0x0A (数字で表現) の場合の処理を飛ばす
		local sz_2=$(stat -c '%s' src/f_byte_to_tile.2.o)
		lr35902_rel_jump $(two_digits_d $sz_2)
	) >src/f_byte_to_tile.1.o
	local sz_1=$(stat -c '%s' src/f_byte_to_tile.1.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_1)
	cat src/f_byte_to_tile.1.o	# regA >= 0x0A (アルファベットで表現)
	cat src/f_byte_to_tile.2.o	# regA < 0x0A (数字で表現)
	lr35902_copy_to_from regB regA

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# ファイルシステム先頭アドレスとファイル番号を指定すると
# ファイルサイズ・データ先頭アドレスとファイルタイプを返す
# in : regHL - ファイルシステム先頭アドレス
#    : regA  - ファイル番号
# out: regHL - ファイルサイズ・データ先頭アドレス
#              (そのままf_run_exe()へ渡せる)
#    : regA  - ファイルタイプ
f_byte_to_tile >src/f_byte_to_tile.o
fsz=$(to16 $(stat -c '%s' src/f_byte_to_tile.o))
fadr=$(calc16 "${a_byte_to_tile}+${fsz}")
a_get_file_addr_and_type=$(four_digits $fadr)
echo -e "a_get_file_addr_and_type=$a_get_file_addr_and_type" >>$MAP_FILE_NAME
f_get_file_addr_and_type() {
	# push
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regAF	# 戻り値のために最後にpush

	# regAは作業にも使うのでファイル番号はregBへコピー
	lr35902_copy_to_from regB regA

	# ファイルシステム先頭アドレスは後で使うのでpush
	lr35902_push_reg regHL

	# ファイルタイプ取得
	local file_type_1st_ofs=0007
	lr35902_set_reg regDE $file_type_1st_ofs
	## ファイル番号0のファイルのファイルタイプのアドレスをregHLへ設定
	lr35902_add_to_regHL regDE
	## 取得したいファイル番号の数だけregHLへファイル属性情報サイズを加算
	lr35902_compare_regA_and 00
	(
		# ファイル番号 != 0 の場合

		lr35902_set_reg regDE $(four_digits $GBOS_FS_FILE_ATTR_SZ)

		(
			lr35902_add_to_regHL regDE
			lr35902_dec regA
		) >src/f_get_file_addr_and_type.3.o
		cat src/f_get_file_addr_and_type.3.o
		local sz_3=$(stat -c '%s' src/f_get_file_addr_and_type.3.o)
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_3 + 2)))
	) >src/f_get_file_addr_and_type.4.o
	local sz_4=$(stat -c '%s' src/f_get_file_addr_and_type.4.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_4)
	cat src/f_get_file_addr_and_type.4.o
	## ファイルタイプをregAへ取得
	lr35902_copy_to_from regA ptrHL

	# regAは作業に使うのでファイルタイプをregCへコピー
	lr35902_copy_to_from regC regA

	# HLへファイルサイズ・データ先頭アドレスを設定
	## ファイルへのオフセットが格納されたアドレスを設定
	lr35902_inc regHL
	## ファイルへのオフセットをregDEへ取得
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regE regA
	lr35902_copy_to_from regA ptrHL
	lr35902_copy_to_from regD regA
	## ファイルシステム先頭アドレスをregHLへ復帰
	lr35902_pop_reg regHL
	## 取得したオフセットを足してファイルサイズ・データ先頭アドレス取得
	lr35902_add_to_regHL regDE

	# pop & return
	lr35902_pop_reg regAF
	## ファイルタイプをregAへ設定
	lr35902_copy_to_from regA regC
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_return
}

# ファイルを編集
# in : regA - ファイル番号
## TODO 関数化
# ※ regDを破壊しないこと
#    (event_driven内でキー入力状態の保持に使っている)
edit_file() {
	# regAをregBへバックアップ
	lr35902_copy_to_from regB regA

	# HLへファイルシステム先頭アドレスを設定
	lr35902_copy_to_regA_from_addr $var_fs_base_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_fs_base_th
	lr35902_copy_to_from regH regA

	# regAをregBから復元
	lr35902_copy_to_from regA regB

	# 編集対象ファイルのファイルサイズ・データ先頭アドレス
	# ・ファイルタイプ取得
	lr35902_call $a_get_file_addr_and_type

	# 取得したファイルタイプを実行ファイル用変数3へ設定
	lr35902_copy_to_addr_from_regA $var_exe_3

	# 取得したアドレスを実行ファイル用変数1・2へ設定
	## リトルエンディアン
	lr35902_copy_to_from regA regL
	lr35902_copy_to_addr_from_regA $var_exe_1
	lr35902_copy_to_from regA regH
	lr35902_copy_to_addr_from_regA $var_exe_2

	# バイナリエディタのファイルサイズ・データ先頭アドレス取得
	# TODO ROMのバンク番号を明示的に設定
	lr35902_set_reg regHL $GB_CARTROM_BANK1_BASE
	lr35902_set_reg regA $GBOS_SYSBANK_FNO_BEDIT
	lr35902_call $a_get_file_addr_and_type

	# バイナリエディタ実行
	lr35902_call $a_run_exe
}

# Aボタンリリース(右クリック)時の処理
# btn_release_handler()から呼ばれる専用の関数
# src/event_driven.2.oが128バイト以上になってしまったため関数化
# in : regA - リリースされたボタン(上位4ビット)
f_get_file_addr_and_type >src/f_get_file_addr_and_type.o
fsz=$(to16 $(stat -c '%s' src/f_get_file_addr_and_type.o))
fadr=$(calc16 "${a_get_file_addr_and_type}+${fsz}")
a_right_click_event=$(four_digits $fadr)
echo -e "a_right_click_event=$a_right_click_event" >>$MAP_FILE_NAME
f_right_click_event() {
	# 呼び出し元へ戻る際に復帰できるようにpush
	lr35902_push_reg regAF

	# ウィンドウステータスをAへ取得
	lr35902_copy_to_regA_from_addr $var_win_stat

	# ウィンドウステータスが「ディレクトリ表示中」であるか確認
	lr35902_test_bitN_of_reg $GBOS_WST_BITNUM_DIR regA
	(
		# 「ディレクトリ表示中」の場合

		# ファイルシステム内のファイル数をregBへ取得
		get_num_files_in_fs
		lr35902_copy_to_from regB regA

		# クリックした場所のファイル番号をregAへ取得
		lr35902_clear_reg regA
		lr35902_call $a_check_click_icon_area_x
		lr35902_call $a_check_click_icon_area_y

		# regA(ファイル番号) >= regB(ファイル数) ?
		lr35902_compare_regA_and regB
		(
			# regA(ファイル番号) < regB(ファイル数) の場合
			# クリックした場所のファイル番号のファイルが存在する
			edit_file
		) >src/right_click_event.3.o
		local sz_3=$(stat -c '%s' src/right_click_event.3.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_3)
		cat src/right_click_event.3.o

		# TODO 「regA(ファイル番号) >= regB(ファイル数)」の時
		#      edit_fileではなく、ファイル新規作成

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >src/right_click_event.2.o
	local sz_2=$(stat -c '%s' src/right_click_event.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
	cat src/right_click_event.2.o

	# 画像ファイル表示中か確認
	lr35902_test_bitN_of_reg $GBOS_WST_BITNUM_IMG regA
	(
		# 画像ファイル表示中の場合
		lr35902_call $a_rstr_tiles
	) >src/right_click_event.1.o
	local sz_1=$(stat -c '%s' src/right_click_event.1.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_1)
	## 画像ファイル表示中の場合
	cat src/right_click_event.1.o

	# clr_win設定
	lr35902_call $a_clr_win

	# view_dir設定
	lr35902_call $a_view_dir

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# ROM領域を表示
f_right_click_event >src/f_right_click_event.o
fsz=$(to16 $(stat -c '%s' src/f_right_click_event.o))
fadr=$(calc16 "${a_right_click_event}+${fsz}")
a_select_rom=$(four_digits $fadr)
echo -e "a_select_rom=$a_select_rom" >>$MAP_FILE_NAME
f_select_rom() {
	# push
	lr35902_push_reg regAF

	# ウィンドウステータスをAへ取得
	lr35902_copy_to_regA_from_addr $var_win_stat

	# ウィンドウステータスが「ディレクトリ表示中」であるか確認
	lr35902_test_bitN_of_reg $GBOS_WST_BITNUM_DIR regA
	(
		# 「ディレクトリ表示中」の場合

		# カートリッジRAM disable
		lr35902_clear_reg regA
		lr35902_copy_to_addr_from_regA $GB_MBC_RAM_EN_ADDR

		# ファイルシステム先頭アドレス変数へROMのアドレスを設定
		lr35902_set_reg regA $(echo $GBOS_FS_BASE_ROM | cut -c3-4)
		lr35902_copy_to_addr_from_regA $var_fs_base_bh
		lr35902_set_reg regA $(echo $GBOS_FS_BASE_ROM | cut -c1-2)
		lr35902_copy_to_addr_from_regA $var_fs_base_th

		# clr_win設定
		lr35902_call $a_clr_win

		# view_dir設定
		lr35902_call $a_view_dir
	) >src/select_rom.1.o
	local sz_1=$(stat -c '%s' src/select_rom.1.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_1)
	cat src/select_rom.1.o

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# RAM領域を表示
f_select_rom >src/f_select_rom.o
fsz=$(to16 $(stat -c '%s' src/f_select_rom.o))
fadr=$(calc16 "${a_select_rom}+${fsz}")
a_select_ram=$(four_digits $fadr)
echo -e "a_select_ram=$a_select_ram" >>$MAP_FILE_NAME
f_select_ram() {
	# push
	lr35902_push_reg regAF

	# ウィンドウステータスをAへ取得
	lr35902_copy_to_regA_from_addr $var_win_stat

	# ウィンドウステータスが「ディレクトリ表示中」であるか確認
	lr35902_test_bitN_of_reg $GBOS_WST_BITNUM_DIR regA
	(
		# 「ディレクトリ表示中」の場合

		# カートリッジRAM enable
		lr35902_set_reg regA $GB_MBC_RAM_EN_VAL
		lr35902_copy_to_addr_from_regA $GB_MBC_RAM_EN_ADDR

		# ファイルシステム先頭アドレス変数へRAMのアドレスを設定
		lr35902_set_reg regA $(echo $GBOS_FS_BASE_RAM | cut -c3-4)
		lr35902_copy_to_addr_from_regA $var_fs_base_bh
		lr35902_set_reg regA $(echo $GBOS_FS_BASE_RAM | cut -c1-2)
		lr35902_copy_to_addr_from_regA $var_fs_base_th

		# clr_win設定
		lr35902_call $a_clr_win

		# view_dir設定
		lr35902_call $a_view_dir
	) >src/select_ram.1.o
	local sz_1=$(stat -c '%s' src/select_ram.1.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_1)
	cat src/select_ram.1.o

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# run_exe_cycを終了させる
f_select_ram >src/f_select_ram.o
fsz=$(to16 $(stat -c '%s' src/f_select_ram.o))
fadr=$(calc16 "${a_select_ram}+${fsz}")
a_exit_exe=$(four_digits $fadr)
echo -e "a_exit_exe=$a_exit_exe" >>$MAP_FILE_NAME
f_exit_exe() {
	# push
	lr35902_push_reg regAF

	# DAS: run_exeをクリア
	lr35902_copy_to_regA_from_addr $var_draw_act_stat
	lr35902_res_bitN_of_reg $GBOS_DA_BITNUM_RUN_EXE regA
	lr35902_copy_to_addr_from_regA $var_draw_act_stat

	# clr_win設定
	lr35902_call $a_clr_win

	# view_dir設定
	lr35902_call $a_view_dir

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# 指定された1文字をtdqへ積む
# in : regB - 出力する文字のタイル番号あるいは改行文字
f_exit_exe >src/f_exit_exe.o
fsz=$(to16 $(stat -c '%s' src/f_exit_exe.o))
fadr=$(calc16 "${a_exit_exe}+${fsz}")
a_putch=$(four_digits $fadr)
echo -e "a_putch=$a_putch" >>$MAP_FILE_NAME
f_putch() {
	# コンソールのputchを呼び出す
	con_putch

	# return
	lr35902_return
}

# 指定したVRAMアドレスから指定した文字数を削除する
# (指定したVRAMアドレスから指定した文字数分のスペースを配置する)
# in : regA - 削除する文字数
#      regD  - VRAMアドレス[15:8]
#      regE  - VRAMアドレス[7:0]
# ※ regAは1以上の値であること
f_putch >src/f_putch.o
fsz=$(to16 $(stat -c '%s' src/f_putch.o))
fadr=$(calc16 "${a_putch}+${fsz}")
a_delch_tadr_num=$(four_digits $fadr)
echo -e "a_delch_tadr_num=$a_delch_tadr_num" >>$MAP_FILE_NAME
f_delch_tadr_num() {
	# コンソールのcon_delch_tadr_numを呼び出す
	con_delch_tadr_num

	# return
	lr35902_return
}

# コンソールの描画領域をクリアする
f_delch_tadr_num >src/f_delch_tadr_num.o
fsz=$(to16 $(stat -c '%s' src/f_delch_tadr_num.o))
fadr=$(calc16 "${a_delch_tadr_num}+${fsz}")
a_clr_con=$(four_digits $fadr)
echo -e "a_clr_con=$a_clr_con" >>$MAP_FILE_NAME
f_clr_con() {
	# コンソールのcon_clearを呼び出す
	con_clear

	# return
	lr35902_return
}

# 指定されたアドレスの文字列を出力する
# in : regHL - 文字列の先頭アドレス
f_clr_con >src/f_clr_con.o
fsz=$(to16 $(stat -c '%s' src/f_clr_con.o))
fadr=$(calc16 "${a_clr_con}+${fsz}")
a_print=$(four_digits $fadr)
echo -e "a_print=$a_print" >>$MAP_FILE_NAME
f_print() {
	# コンソールのcon_printを呼び出す
	con_print

	# return
	lr35902_return
}

# 指定されたアドレスの文字列を指定されたタイル座標へ出力する
# in : regHL - 文字列の先頭アドレス
#    : regD - タイル座標Y
#    : regE - タイル座標X
# ※ con_putxy()とは違い、コンソールのカーソル位置を変更する
f_print >src/f_print.o
fsz=$(to16 $(stat -c '%s' src/f_print.o))
fadr=$(calc16 "${a_print}+${fsz}")
a_print_xy=$(four_digits $fadr)
echo -e "a_print_xy=$a_print_xy" >>$MAP_FILE_NAME
f_print_xy() {
	# コンソールのcon_print_xyを呼び出す
	con_print_xy

	# return
	lr35902_return
}

# 指定されたコンソール座標に指定された文字を出力
# in : regB - 出力する文字のタイル番号
#    : regD - コンソールY座標
#    : regE - コンソールX座標
f_print_xy >src/f_print_xy.o
fsz=$(to16 $(stat -c '%s' src/f_print_xy.o))
fadr=$(calc16 "${a_print_xy}+${fsz}")
a_putxy=$(four_digits $fadr)
echo -e "a_putxy=$a_putxy" >>$MAP_FILE_NAME
f_putxy() {
	# コンソールのcon_putxyを呼び出す
	con_putxy

	# return
	lr35902_return
}

# 指定されたコンソール座標のタイル番号を取得
# in : regD - コンソールY座標
#    : regE - コンソールX座標
# out: regA - 取得したタイル番号
f_putxy >src/f_putxy.o
fsz=$(to16 $(stat -c '%s' src/f_putxy.o))
fadr=$(calc16 "${a_putxy}+${fsz}")
a_getxy=$(four_digits $fadr)
echo -e "a_getxy=$a_getxy" >>$MAP_FILE_NAME
f_getxy() {
	# コンソールのcon_getxyを呼び出す
	con_getxy

	# return
	lr35902_return
}

# ファイルを閲覧
# in : regA - ファイル番号
## TODO 関数化
## TODO regA == 80 の時、直ちにret
view_file() {
	# DEは呼び出し元で使っているので予め退避
	lr35902_push_reg regDE

	# Aは作業にも使うのでファイル番号はBへコピー
	lr35902_copy_to_from regB regA

	# ファイルタイプ取得
	local file_type_1st_ofs=0007
	lr35902_copy_to_regA_from_addr $var_fs_base_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_fs_base_th
	lr35902_copy_to_from regH regA
	lr35902_set_reg regDE $file_type_1st_ofs
	lr35902_add_to_regHL regDE
	lr35902_copy_to_from regA regB
	lr35902_compare_regA_and 00
	(
		# ファイル番号 != 0 の場合

		lr35902_set_reg regDE $(four_digits $GBOS_FS_FILE_ATTR_SZ)

		(
			lr35902_add_to_regHL regDE
			lr35902_dec regA
		) >src/view_file.3.o
		cat src/view_file.3.o
		local sz_3=$(stat -c '%s' src/view_file.3.o)
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_3 + 2)))
	) >src/view_file.4.o
	local sz_4=$(stat -c '%s' src/view_file.4.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_4)
	cat src/view_file.4.o
	## ファイルタイプをAへ取得
	lr35902_copy_to_from regA ptrHL

	# Aは作業に使うのでCへコピー
	lr35902_copy_to_from regC regA

	# HLへファイルサイズ・データ先頭アドレスを設定
	## ファイルサイズ・データへのオフセットが格納されたアドレスを設定
	lr35902_inc regHL
	## ファイルサイズ・データへのオフセット取得
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regE regA
	lr35902_copy_to_from regA ptrHL
	lr35902_copy_to_from regD regA
	## FSベースアドレスと足してファイルサイズ・データ先頭アドレス取得
	lr35902_copy_to_regA_from_addr $var_fs_base_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_fs_base_th
	lr35902_copy_to_from regH regA
	lr35902_add_to_regHL regDE

	# ファイルタイプをAへ復帰
	lr35902_copy_to_from regA regC

	# 対象が実行ファイルの場合、f_run_exe() で実行する
	lr35902_compare_regA_and $GBOS_ICON_NUM_EXE
	(
		# 実行ファイルの場合
		lr35902_copy_to_from regA regB
		lr35902_call $a_run_exe

		# Aがこの後何にもヒットしないようにする
		lr35902_clear_reg regA
	) >src/view_file.5.o
	local sz_5=$(stat -c '%s' src/view_file.5.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_5)
	cat src/view_file.5.o

	# 対象がテキストファイルの場合、f_view_txt() で閲覧
	lr35902_compare_regA_and $GBOS_ICON_NUM_TXT
	(
		# テキストファイルの場合
		lr35902_copy_to_from regA regB
		lr35902_call $a_view_txt

		# Aがこの後何にもヒットしないようにする
		lr35902_clear_reg regA
	) >src/view_file.1.o
	local sz_1=$(stat -c '%s' src/view_file.1.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
	cat src/view_file.1.o

	# 対象が画像ファイルの場合、f_view_img() で閲覧
	lr35902_compare_regA_and $GBOS_ICON_NUM_IMG
	(
		# 画像ファイルの場合
		lr35902_copy_to_from regA regB
		lr35902_call $a_view_img
	) >src/view_file.2.o
	local sz_2=$(stat -c '%s' src/view_file.2.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_2)
	cat src/view_file.2.o

	# DEを復帰
	lr35902_pop_reg regDE
}

# Bボタンリリース(左クリック)時の処理
# btn_release_handler()から呼ばれる専用の関数
# src/event_driven.3.oが128バイト以上になってしまったため関数化
# in : regA - リリースされたボタン(上位4ビット)
f_getxy >src/f_getxy.o
fsz=$(to16 $(stat -c '%s' src/f_getxy.o))
fadr=$(calc16 "${a_getxy}+${fsz}")
a_click_event=$(four_digits $fadr)
echo -e "a_click_event=$a_click_event" >>$MAP_FILE_NAME
f_click_event() {
	# push
	lr35902_push_reg regAF

	# ウィンドウステータスが「ディレクトリ表示中」であるか確認
	lr35902_copy_to_regA_from_addr $var_win_stat
	lr35902_test_bitN_of_reg $GBOS_WST_BITNUM_DIR regA
	(
		# 「ディレクトリ表示中」の場合

		# ファイルシステム内のファイル数をregBへ取得
		get_num_files_in_fs
		lr35902_copy_to_from regB regA

		# クリックした場所のファイル番号をregAへ取得
		lr35902_clear_reg regA
		lr35902_call $a_check_click_icon_area_x
		lr35902_call $a_check_click_icon_area_y

		# regA(ファイル番号) >= regB(ファイル数) ?
		lr35902_compare_regA_and regB
		(
			# regA(ファイル番号) < regB(ファイル数) の場合
			# クリックした場所のファイル番号のファイルが存在する
			view_file
		) >src/click_event.2.o
		local sz_2=$(stat -c '%s' src/click_event.2.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_2)
		cat src/click_event.2.o
	) >src/click_event.1.o
	local sz_1=$(stat -c '%s' src/click_event.1.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_1)
	cat src/click_event.1.o

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# regAをコンソールのカーソル位置にダンプ
# in : regA - ダンプする値
f_click_event >src/f_click_event.o
fsz=$(to16 $(stat -c '%s' src/f_click_event.o))
fadr=$(calc16 "${a_click_event}+${fsz}")
a_print_regA=$(four_digits $fadr)
echo -e "a_print_regA=$a_print_regA" >>$MAP_FILE_NAME
f_print_regA() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC

	# regAの上の桁と下の桁を入れ替え
	lr35902_swap_nibbles regA

	# 上の桁をダンプ
	lr35902_call $a_byte_to_tile
	lr35902_call $a_putch

	# regAの上の桁と下の桁を入れ替え
	lr35902_swap_nibbles regA

	# 下の桁をダンプ
	lr35902_call $a_byte_to_tile
	lr35902_call $a_putch

	# pop & return
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# regAをコンソールのカーソル位置に符号付き10進数でダンプ
# 備考:
# - regAを2の補数表現の値(-128〜127)として扱う
# - 正の値の場合に'+'は表示しない(スペースを表示する)
# - 上位の桁に0を表示する
# - 表示には常に4桁の幅を使用する
# 出力例:
# - 123  -> " 123"
# - 103  -> " 103"
# - 12   -> " 012"
# - -12  -> "-012"
# - -103 -> "-103"
# - -123 -> "-123"
# 引数:
# in : regA - ダンプする値
f_print_regA >src/f_print_regA.o
fsz=$(to16 $(stat -c '%s' src/f_print_regA.o))
fadr=$(calc16 "${a_print_regA}+${fsz}")
a_print_regA_signed_dec=$(four_digits $fadr)
echo -e "a_print_regA_signed_dec=$a_print_regA_signed_dec" >>$MAP_FILE_NAME
f_print_regA_signed_dec() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE

	# 符号('-')あるいはスペースを出力
	## regAのMSB == 0 ?
	lr35902_test_bitN_of_reg 7 regA
	(
		# regAのMSB == 0(regA >= 0) の場合

		# スペースを出力
		lr35902_set_reg regB $GBOS_TILE_NUM_SPC
		lr35902_call $a_putch
	) >src/f_print_regA_signed_dec.regA_positive.o
	(
		# regAのMSB == 1(regA < 0) の場合

		# 符号('-')を出力
		lr35902_set_reg regB $GBOS_TILE_NUM_DASH
		lr35902_call $a_putch

		# regAの絶対値をregAへ設定
		## regAの各ビットを反転
		lr35902_complement_regA
		## regAへ1を加算
		lr35902_inc regA

		# regAのMSB == 0 の場合の処理を飛ばす
		local sz_regA_positive=$(stat -c '%s' src/f_print_regA_signed_dec.regA_positive.o)
		lr35902_rel_jump $(two_digits_d $sz_regA_positive)
	) >src/f_print_regA_signed_dec.regA_negative.o
	local sz_regA_negative=$(stat -c '%s' src/f_print_regA_signed_dec.regA_negative.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_regA_negative)
	cat src/f_print_regA_signed_dec.regA_negative.o
	cat src/f_print_regA_signed_dec.regA_positive.o

	# 百の位を出力
	# regAが100以上なら'1'を、そうでなければ'0'を出力
	## regB = regA
	lr35902_copy_to_from regB regA
	## regA = 99(0x63)
	lr35902_set_reg regA 63
	## regA < regB ?
	lr35902_compare_regA_and regB
	(
		# regA < regB(regAが100以上) の場合

		# regA = regB
		lr35902_copy_to_from regA regB

		# '1'を出力
		lr35902_set_reg regB $(get_num_tile_num 1)
		lr35902_call $a_putch

		# regA -= 100(0x64)
		lr35902_sub_to_regA 64
	) >src/f_print_regA_signed_dec.regA_ge_100.o
	(
		# regA >= regB(regAが100未満) の場合

		# regA = regB
		lr35902_copy_to_from regA regB

		# '0'を出力
		lr35902_set_reg regB $(get_num_tile_num 0)
		lr35902_call $a_putch

		# regA < regB の場合の処理を飛ばす
		local sz_regA_ge_100=$(stat -c '%s' src/f_print_regA_signed_dec.regA_ge_100.o)
		lr35902_rel_jump $(two_digits_d $sz_regA_ge_100)
	) >src/f_print_regA_signed_dec.regA_lt_100.o
	local sz_regA_lt_100=$(stat -c '%s' src/f_print_regA_signed_dec.regA_lt_100.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_regA_lt_100)
	cat src/f_print_regA_signed_dec.regA_lt_100.o	# regA >= regB の場合
	cat src/f_print_regA_signed_dec.regA_ge_100.o	# regA < regB の場合

	# 十の位を出力
	## regB = 1
	lr35902_set_reg regB 01
	## regC = 10(0xa)
	lr35902_set_reg regC 0a
	## regA < 10 なら以下の処理を飛ばす
	lr35902_compare_regA_and regC
	(
		(
			# regAをregDへ退避
			lr35902_copy_to_from regD regA

			# regB += 1
			lr35902_inc regB

			# regC += 10(0xa)
			lr35902_copy_to_from regA regC
			lr35902_add_to_regA 0a
			lr35902_copy_to_from regC regA

			# regAをregDから復帰
			lr35902_copy_to_from regA regD

			# regA < regC ?
			lr35902_compare_regA_and regC
		) >src/f_print_regA_signed_dec.loop.o
		cat src/f_print_regA_signed_dec.loop.o

		# regA >= regC なら「regAをregDへ退避」に戻る
		# (regA < regC ならループを抜ける)
		local sz_loop=$(stat -c '%s' src/f_print_regA_signed_dec.loop.o)
		lr35902_rel_jump_with_cond NC $(two_comp_d $((sz_loop + 2)))

		# regA -= regC - 10(0xa)
		# (計算の簡単さから、regAに10を足した後、regCを引く)
		lr35902_add_to_regA 0a
		lr35902_sub_to_regA regC
	) >src/f_print_regA_signed_dec.count_tens.o
	local sz_count_tens=$(stat -c '%s' src/f_print_regA_signed_dec.count_tens.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_count_tens)
	cat src/f_print_regA_signed_dec.count_tens.o
	## regB -= 1
	lr35902_dec regB
	## regBを十の位の値として出力する
	lr35902_copy_to_from regD regA
	lr35902_copy_to_from regA regB
	lr35902_call $a_byte_to_tile
	lr35902_call $a_putch
	lr35902_copy_to_from regA regD

	# 一の位を出力
	## regAの値を出力
	lr35902_call $a_byte_to_tile
	lr35902_call $a_putch

	# pop & return
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 指定されたタイル番号に対応する16進の数値を返す
# in : regA - 数値へ変換するタイル番号
# out: regB - 数値
# ※ タイル番号は0x14〜0x1d('0'〜'9')・0x1e〜0x23('A'〜'F')の中で指定すること
f_print_regA_signed_dec >src/f_print_regA_signed_dec.o
fsz=$(to16 $(stat -c '%s' src/f_print_regA_signed_dec.o))
fadr=$(calc16 "${a_print_regA_signed_dec}+${fsz}")
a_tile_to_byte=$(four_digits $fadr)
echo -e "a_tile_to_byte=$a_tile_to_byte" >>$MAP_FILE_NAME
f_tile_to_byte() {
	# push
	lr35902_push_reg regAF

	# regA < 0x1E ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_ALPHA_BASE
	(
		# regA < 0x1E('0'〜'9')

		# '0'のタイル番号を引く
		lr35902_sub_to_regA $GBOS_TILE_NUM_NUM_BASE
	) >src/f_tile_to_byte.1.o
	(
		# regA >= 0x1E('A'〜'F')

		# 'A'のタイル番号を引く
		lr35902_sub_to_regA $GBOS_TILE_NUM_ALPHA_BASE

		# 0x0aを足す
		lr35902_add_to_regA 0a

		# regA < 0x1E('0'〜'9') の処理を飛ばす
		local sz_1=$(stat -c '%s' src/f_tile_to_byte.1.o)
		lr35902_rel_jump $(two_digits_d $sz_1)
	) >src/f_tile_to_byte.2.o
	local sz_2=$(stat -c '%s' src/f_tile_to_byte.2.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_2)
	cat src/f_tile_to_byte.2.o	# regA >= 0x1E('A'〜'F')
	cat src/f_tile_to_byte.1.o	# regA < 0x1E('0'〜'9')

	# 戻り値セット
	lr35902_copy_to_from regB regA

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# 乱数を返す
# 乱数生成には線形合同法を用いる
# 定数は、A=5・B=3・M=256なので、
# X_{n+1} = (5 * X_n + 3) % 256
# レジスタ幅8ビットより、256の剰余は計算しなくても同じなので
# X_{n+1} = 5 * X_n + 3
# X_{n+1} = (2^2 + 1) * X_n + 3
# X_{n+1} = (2^2 * X_n) + (1 * X_n) + 3
# X_{n+1} = (X_n << 2) + X_n + 3
# なお、初期値(X_0)はマウスカーソルが静止し始めた時のX座標とY座標の和
# そのため、変数領域に↓の変数を確保している(各1バイト)
# - var_lgcs_xn ← 線形合同法(LGCs)のX_n
# - var_lgcs_tile_sum ← 前回の乱数取得時のマウスカーソルのX座標とY座標の和
# out: regA - 乱数(0x00 - 0xff)
f_tile_to_byte >src/f_tile_to_byte.o
fsz=$(to16 $(stat -c '%s' src/f_tile_to_byte.o))
fadr=$(calc16 "${a_tile_to_byte}+${fsz}")
a_get_rnd=$(four_digits $fadr)
echo -e "a_get_rnd=$a_get_rnd" >>$MAP_FILE_NAME
f_get_rnd() {
	# push
	lr35902_push_reg regBC
	lr35902_push_reg regAF
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# regB = 現在のマウスカーソルX座標とY座標の和
	lr35902_copy_to_regA_from_addr $var_mouse_x
	lr35902_copy_to_from regB regA
	lr35902_copy_to_regA_from_addr $var_mouse_y
	lr35902_add_to_regA regB
	lr35902_copy_to_from regB regA

	# regA = var_lgcs_tile_sum
	lr35902_copy_to_regA_from_addr $var_lgcs_tile_sum

	# regA == regB ?
	lr35902_compare_regA_and regB
	(
		# regA == regB の場合

		# X_nとしてregBへvar_lgcs_xnを設定
		lr35902_copy_to_regA_from_addr $var_lgcs_xn
		lr35902_copy_to_from regB regA
	) >src/f_get_rnd.1.o
	(
		# regA != regB の場合

		# var_lgcs_tile_sum = regB
		lr35902_copy_to_from regA regB
		lr35902_copy_to_addr_from_regA $var_lgcs_tile_sum

		# regA == regB の場合の処理を飛ばす
		local sz_1=$(stat -c '%s' src/f_get_rnd.1.o)
		lr35902_rel_jump $(two_digits_d $sz_1)
	) >src/f_get_rnd.2.o
	local sz_2=$(stat -c '%s' src/f_get_rnd.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
	cat src/f_get_rnd.2.o	# regA != regB の場合
	cat src/f_get_rnd.1.o	# regA == regB の場合

	# この時点で、regBにはX_nとして使う値が設定されている
	# - 現在のマウスカーソルX座標とY座標の和 == var_lgcs_tile_sum
	#   → regB = var_lgcs_xn
	# - 現在のマウスカーソルX座標とY座標の和 != var_lgcs_tile_sum
	#   → regB = 現在のマウスカーソルX座標とY座標の和

	# regA = (regB << 2) + regB + 3
	# この時点で、regA == regB
	## regA <<= 2
	lr35902_shift_left_arithmetic regA
	lr35902_shift_left_arithmetic regA
	## regA += regB
	lr35902_add_to_regA regB
	## regA += 3
	lr35902_add_to_regA 03

	# var_lgcs_xn = regA
	lr35902_copy_to_addr_from_regA $var_lgcs_xn

	# regB = regA
	lr35902_copy_to_from regB regA

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
	lr35902_copy_to_from regA regB
	lr35902_pop_reg regBC
	lr35902_return
}

# tdqへエントリを追加する
# in : regB  - 配置するタイル番号
#      regD  - VRAMアドレス[15:8]
#      regE  - VRAMアドレス[7:0]
# ※ f_enq_tdq()の方が新しい(オーバーフローフラグ設定があったりする)
# 　 こちらの関数は古いので使わないこと
f_get_rnd >src/f_get_rnd.o
fsz=$(to16 $(stat -c '%s' src/f_get_rnd.o))
fadr=$(calc16 "${a_get_rnd}+${fsz}")
a_tdq_enq=$(four_digits $fadr)
echo -e "a_tdq_enq=$a_tdq_enq" >>$MAP_FILE_NAME
f_tdq_enq() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	lr35902_copy_to_regA_from_addr $var_tdq_stat
	lr35902_test_bitN_of_reg $GBOS_TDQ_STAT_BITNUM_FULL regA
	(
		# Aへロードしたtdq.statをCへコピー
		lr35902_copy_to_from regC regA

		# tdq.tailが指す位置に追加
		lr35902_copy_to_regA_from_addr $var_tdq_tail_bh
		lr35902_copy_to_from regL regA
		lr35902_copy_to_regA_from_addr $var_tdq_tail_th
		lr35902_copy_to_from regH regA

		lr35902_copy_to_from regA regE
		lr35902_copyinc_to_ptrHL_from_regA
		lr35902_copy_to_from regA regD
		lr35902_copyinc_to_ptrHL_from_regA
		lr35902_copy_to_from regA regB
		lr35902_copyinc_to_ptrHL_from_regA

		# HL == TDQ_END だったら HL = TDQ_FIRST
		# L == TDQ_END[7:0] ?
		lr35902_copy_to_from regA regL
		lr35902_compare_regA_and $(echo $GBOS_TDQ_END | cut -c3-4)
		(
			# L == TDQ_END[7:0]

			# H == TDQ_END[15:8] ?
			lr35902_copy_to_from regA regH
			lr35902_compare_regA_and $(echo $GBOS_TDQ_END | cut -c1-2)
			(
				# H == TDQ_END[15:8]

				# HL = TDQ_FIRST
				lr35902_set_reg regL $(echo $GBOS_TDQ_FIRST | cut -c3-4)
				lr35902_set_reg regH $(echo $GBOS_TDQ_FIRST | cut -c1-2)
			) >src/tdq_enqueue.1.o
			local sz_1=$(stat -c '%s' src/tdq_enqueue.1.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
			cat src/tdq_enqueue.1.o
		) >src/tdq_enqueue.2.o
		local sz_2=$(stat -c '%s' src/tdq_enqueue.2.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_2)
		cat src/tdq_enqueue.2.o

		lr35902_copy_to_from regA regL
		lr35902_copy_to_addr_from_regA $var_tdq_tail_bh
		lr35902_copy_to_from regA regH
		lr35902_copy_to_addr_from_regA $var_tdq_tail_th

		# HL == tdq.head だったら tdq.stat に is_full ビットをセット
		# tdq.head[7:0] == tdq.tail[7:0] ?
		lr35902_copy_to_regA_from_addr $var_tdq_head_bh
		lr35902_compare_regA_and regL
		(
			# tdq.head[7:0] == tdq.tail[7:0]

			# tdq.head[15:8] == tdq.tail[15:8] ?
			lr35902_copy_to_regA_from_addr $var_tdq_head_th
			lr35902_compare_regA_and regH
			(
				# tdq.head[15:8] == tdq.tail[15:8]

				# C に full ビットをセット
				lr35902_set_bitN_of_reg $GBOS_TDQ_STAT_BITNUM_FULL regC
			) >src/tdq_enqueue.3.o
			local sz_3=$(stat -c '%s' src/tdq_enqueue.3.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
			cat src/tdq_enqueue.3.o
		) >src/tdq_enqueue.4.o
		local sz_4=$(stat -c '%s' src/tdq_enqueue.4.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
		cat src/tdq_enqueue.4.o

		# C の empty フラグをクリア
		lr35902_res_bitN_of_reg $GBOS_TDQ_STAT_BITNUM_EMPTY regC

		# tdq.stat = C
		lr35902_copy_to_from regA regC
		lr35902_copy_to_addr_from_regA $var_tdq_stat
	) >src/tdq_enqueue.5.o
	local sz_5=$(stat -c '%s' src/tdq_enqueue.5.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_5)
	cat src/tdq_enqueue.5.o

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 指定されたタイルのタイル属性番号を返す
# in : regA  - タイル番号
# out: regA  - タイル属性番号
f_tdq_enq >src/f_tdq_enq.o
fsz=$(to16 $(stat -c '%s' src/f_tdq_enq.o))
fadr=$(calc16 "${a_tdq_enq}+${fsz}")
a_binbio_get_tile_family_num=$(four_digits $fadr)
echo -e "a_binbio_get_tile_family_num=$a_binbio_get_tile_family_num" >>$MAP_FILE_NAME
f_binbio_get_tile_family_num() {
	# push
	lr35902_push_reg regAF

	# タイル番号 == 細胞タイル ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_CELL
	(
		# タイル番号 == 細胞タイル の場合

		# pop
		lr35902_pop_reg regAF

		# regA(戻り値)へ「細胞」を設定
		lr35902_set_reg regA $BINBIO_TILE_FAMILY_NUM_CELL

		# return
		lr35902_return
	) >src/f_binbio_get_tile_family_num.9.o
	local sz_9=$(stat -c '%s' src/f_binbio_get_tile_family_num.9.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_9)
	cat src/f_binbio_get_tile_family_num.9.o

	# push
	lr35902_push_reg regBC

	# 渡されたタイル番号をregBへコピーしておく
	lr35902_copy_to_from regB regA

	# タイル番号 > 0x00 ?
	lr35902_xor_to_regA regA
	lr35902_compare_regA_and regB
	(
		# タイル番号 > 0x00 の場合

		# タイル番号 < 0x0e ?
		lr35902_copy_to_from regA regB
		lr35902_set_reg regC 0e
		lr35902_compare_regA_and regC
		(
			# タイル番号 < 0x0e の場合

			# pop
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF

			# regA(戻り値)へ「ウィンドウ」を設定
			lr35902_set_reg regA $BINBIO_TILE_FAMILY_NUM_WIN

			# return
			lr35902_return
		) >src/f_binbio_get_tile_family_num.1.o
		local sz_1=$(stat -c '%s' src/f_binbio_get_tile_family_num.1.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_1)
		cat src/f_binbio_get_tile_family_num.1.o
	) >src/f_binbio_get_tile_family_num.2.o
	local sz_2=$(stat -c '%s' src/f_binbio_get_tile_family_num.2.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_2)
	cat src/f_binbio_get_tile_family_num.2.o

	# タイル番号 > 0x11 ?
	lr35902_set_reg regA 11
	lr35902_compare_regA_and regB
	(
		# タイル番号 > 0x11 の場合

		# タイル番号 < 0x38 ?
		lr35902_copy_to_from regA regB
		lr35902_set_reg regC 38
		lr35902_compare_regA_and regC
		(
			# タイル番号 < 0x38 の場合

			# pop
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF

			# regA(戻り値)へ「文字」を設定
			lr35902_set_reg regA $BINBIO_TILE_FAMILY_NUM_CHAR

			# return
			lr35902_return
		) >src/f_binbio_get_tile_family_num.3.o
		local sz_3=$(stat -c '%s' src/f_binbio_get_tile_family_num.3.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_3)
		cat src/f_binbio_get_tile_family_num.3.o
	) >src/f_binbio_get_tile_family_num.4.o
	local sz_4=$(stat -c '%s' src/f_binbio_get_tile_family_num.4.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_4)
	cat src/f_binbio_get_tile_family_num.4.o

	# タイル番号 > 0x37 ?
	lr35902_set_reg regA 37
	lr35902_compare_regA_and regB
	(
		# タイル番号 > 0x37 の場合

		# タイル番号 < 0x48 ?
		lr35902_copy_to_from regA regB
		lr35902_set_reg regC 48
		lr35902_compare_regA_and regC
		(
			# タイル番号 < 0x48 の場合

			# pop
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF

			# regA(戻り値)へ「アイコン」を設定
			lr35902_set_reg regA $BINBIO_TILE_FAMILY_NUM_ICON

			# return
			lr35902_return
		) >src/f_binbio_get_tile_family_num.5.o
		local sz_5=$(stat -c '%s' src/f_binbio_get_tile_family_num.5.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_5)
		cat src/f_binbio_get_tile_family_num.5.o
	) >src/f_binbio_get_tile_family_num.6.o
	local sz_6=$(stat -c '%s' src/f_binbio_get_tile_family_num.6.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_6)
	cat src/f_binbio_get_tile_family_num.6.o

	# タイル番号 > 0x47 ?
	lr35902_set_reg regA 47
	lr35902_compare_regA_and regB
	(
		# タイル番号 > 0x47 の場合

		# タイル番号 < 0x8b ?
		lr35902_copy_to_from regA regB
		lr35902_set_reg regC 8b
		lr35902_compare_regA_and regC
		(
			# タイル番号 < 0x8b の場合

			# pop
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF

			# regA(戻り値)へ「文字」を設定
			lr35902_set_reg regA $BINBIO_TILE_FAMILY_NUM_CHAR

			# return
			lr35902_return
		) >src/f_binbio_get_tile_family_num.7.o
		local sz_7=$(stat -c '%s' src/f_binbio_get_tile_family_num.7.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_7)
		cat src/f_binbio_get_tile_family_num.7.o
	) >src/f_binbio_get_tile_family_num.8.o
	local sz_8=$(stat -c '%s' src/f_binbio_get_tile_family_num.8.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_8)
	cat src/f_binbio_get_tile_family_num.8.o

	# pop
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF

	# regA(戻り値)へ「属性なし」を設定
	lr35902_set_reg regA $BINBIO_TILE_FAMILY_NUM_NONE

	# return
	lr35902_return
}

# 繰り返し使用する処理をファイル書き出し
## マウスカーソルを表示する
## work: regA, regB, regDE
(
	# カーネル側でマウスカーソルの更新をするように専用の変数を設定
	lr35902_set_reg regA 01
	lr35902_copy_to_addr_from_regA $var_mouse_enable

	# オブジェクトを表示する
	lr35902_copy_to_regA_from_addr $var_mouse_y
	lr35902_copy_to_from regB regA
	lr35902_set_reg regDE $GBOS_OAM_BASE_CSL
	lr35902_call $a_enq_tdq
) >src/show_mouse_cursor.o
## マウスカーソルを非表示にする
## work: regA, regB, regDE
(
	# オブジェクトを非表示にする
	lr35902_clear_reg regB
	lr35902_set_reg regDE $GBOS_OAM_BASE_CSL
	lr35902_call $a_enq_tdq

	# カーネル側でマウスカーソルの更新をしないように専用の変数を設定
	lr35902_clear_reg regA
	lr35902_copy_to_addr_from_regA $var_mouse_enable
) >src/hide_mouse_cursor.o

# 指定されたタイル座標の細胞のアドレスを取得
# in : regD  - タイル座標Y
#      regE  - タイル座標X
# out: regHL - 細胞アドレス(指定された座標に細胞が存在しない場合はNULL)
f_binbio_get_tile_family_num >src/f_binbio_get_tile_family_num.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_get_tile_family_num.o))
fadr=$(calc16 "${a_binbio_get_tile_family_num}+${fsz}")
a_binbio_find_cell_data_by_tile_xy=$(four_digits $fadr)
echo -e "a_binbio_find_cell_data_by_tile_xy=$a_binbio_find_cell_data_by_tile_xy" >>$MAP_FILE_NAME
f_binbio_find_cell_data_by_tile_xy() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC

	# タイル座標に対応する細胞を細胞データ領域から探す
	## regHLへ細胞データ領域開始アドレスを設定
	lr35902_set_reg regHL $BINBIO_CELL_DATA_AREA_BEGIN
	## 指定されたタイル座標が細胞の(tile_x,tile_y)に見つかるまで繰り返す
	(
		# この細胞は生きているか?
		## flags.alive == 1 ?
		lr35902_test_bitN_of_reg 0 ptrHL
		(
			# flags.alive == 0 の場合

			# regHL += 細胞データ構造サイズ
			lr35902_set_reg regBC $(four_digits $BINBIO_CELL_DATA_SIZE)
			lr35902_add_to_regHL regBC
		) >src/f_binbio_find_cell_data_by_tile_xy.4.o
		(
			# flags.alive == 1 の場合

			# (tile_x,tile_y) == (regE,regD) ?
			## アドレスregHLをtile_xまで進める
			lr35902_inc regHL
			## regAへtile_xを取得
			lr35902_copy_to_from regA ptrHL
			## regC = regA XOR regE
			lr35902_xor_to_regA regE
			lr35902_copy_to_from regC regA
			## アドレスregHLをtile_yまで進める
			lr35902_inc regHL
			## regAへtile_yを取得
			lr35902_copy_to_from regA ptrHL
			## regB = regA XOR regD
			lr35902_xor_to_regA regD
			lr35902_copy_to_from regB regA
			## regA = regC | regB
			lr35902_copy_to_from regA regC
			lr35902_or_to_regA regB
			## regA == 0x00 ?
			lr35902_compare_regA_and 00
			(
				# regA == 0x00 の場合
				# (tile_x,tile_y) == (regE,regD)

				# 見つかった

				# アドレスregHLをこの細胞データの先頭まで戻す
				lr35902_dec regHL
				lr35902_dec regHL

				# pop & return
				lr35902_pop_reg regBC
				lr35902_pop_reg regAF
				lr35902_return
			) >src/f_binbio_find_cell_data_by_tile_xy.2.o
			local sz_2=$(stat -c '%s' src/f_binbio_find_cell_data_by_tile_xy.2.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_2)
			cat src/f_binbio_find_cell_data_by_tile_xy.2.o

			# regHL += 細胞データ構造サイズ - 2
			lr35902_set_reg regBC $(four_digits $(calc16 "${BINBIO_CELL_DATA_SIZE}-2"))
			lr35902_add_to_regHL regBC

			# flags.alive == 0 の場合の処理を飛ばす
			local sz_4=$(stat -c '%s' src/f_binbio_find_cell_data_by_tile_xy.4.o)
			lr35902_rel_jump $(two_digits_d $sz_4)
		) >src/f_binbio_find_cell_data_by_tile_xy.5.o
		local sz_5=$(stat -c '%s' src/f_binbio_find_cell_data_by_tile_xy.5.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_5)
		cat src/f_binbio_find_cell_data_by_tile_xy.5.o	# flags.alive == 1 の場合
		cat src/f_binbio_find_cell_data_by_tile_xy.4.o	# flags.alive == 0 の場合

		# regHL > 細胞データ領域最終アドレス ?
		## regDEをpush
		lr35902_push_reg regDE
		## regDEへ細胞データ領域最終アドレスを設定
		lr35902_set_reg regDE $BINBIO_CELL_DATA_AREA_END
		## regHLとregDEを比較
		lr35902_call $a_compare_regHL_and_regDE
		## regAに正の値が設定されている(regHL > regDE)か?
		## (regHL == regDEはありえないので、regA == 0は考えない)
		### regAのMSBを確認
		lr35902_test_bitN_of_reg 7 regA
		(
			# regAのMSB == 0

			# 見つからなかった

			# regHLへNULLを設定
			lr35902_set_reg regHL $GBOS_NULL

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF
			lr35902_return
		) >src/f_binbio_find_cell_data_by_tile_xy.3.o
		local sz_3=$(stat -c '%s' src/f_binbio_find_cell_data_by_tile_xy.3.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
		cat src/f_binbio_find_cell_data_by_tile_xy.3.o
		## regDEをpop
		lr35902_pop_reg regDE
	) >src/f_binbio_find_cell_data_by_tile_xy.1.o
	cat src/f_binbio_find_cell_data_by_tile_xy.1.o
	local sz_1=$(stat -c '%s' src/f_binbio_find_cell_data_by_tile_xy.1.o)
	lr35902_rel_jump $(two_comp_d $((sz_1 + 2)))
}

# 細胞データ領域を確保
# out: regHL - 確保した領域のアドレス(確保できなかった場合はNULL)
f_binbio_find_cell_data_by_tile_xy >src/f_binbio_find_cell_data_by_tile_xy.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_find_cell_data_by_tile_xy.o))
fadr=$(calc16 "${a_binbio_find_cell_data_by_tile_xy}+${fsz}")
a_binbio_cell_alloc=$(four_digits $fadr)
echo -e "a_binbio_cell_alloc=$a_binbio_cell_alloc" >>$MAP_FILE_NAME
f_binbio_cell_alloc() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regDE

	# CELL_DATA_AREA_BEGINからCELL_DATA_SIZEバイト毎に
	# flags.aliveが0の場所を探す
	## CELL_DATA_AREA_BEGINをregHLへ設定
	lr35902_set_reg regHL $BINBIO_CELL_DATA_AREA_BEGIN
	## flags.aliveが0の場所を探す
	(
		# flags.alive == 0 ?
		lr35902_test_bitN_of_reg 0 ptrHL
		(
			# flags.alive == 0 の場合

			# 現在のregHLを返す
			## pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regAF
			lr35902_return
		) >src/f_binbio_cell_alloc.1.o
		local sz_1=$(stat -c '%s' src/f_binbio_cell_alloc.1.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
		cat src/f_binbio_cell_alloc.1.o

		# regHL += 細胞データ構造サイズ
		lr35902_set_reg regDE $(four_digits $BINBIO_CELL_DATA_SIZE)
		lr35902_add_to_regHL regDE

		# regHL > 細胞データ領域最終アドレス ?
		## 細胞データ領域最終アドレスをregDEへ設定
		lr35902_set_reg regDE $BINBIO_CELL_DATA_AREA_END
		## regHLとregDEを比較
		lr35902_call $a_compare_regHL_and_regDE
		lr35902_test_bitN_of_reg 7 regA
		(
			# regHL >= regDE の場合

			# ループを脱出
			lr35902_rel_jump $(two_digits_d 2)
		) >src/f_binbio_cell_alloc.2.o
		local sz_2=$(stat -c '%s' src/f_binbio_cell_alloc.2.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_2)
		cat src/f_binbio_cell_alloc.2.o
	) >src/f_binbio_cell_alloc.3.o
	cat src/f_binbio_cell_alloc.3.o
	# (sz_3 + 2)のサイズ分、上方へ無条件ジャンプ
	local sz_3=$(stat -c '%s' src/f_binbio_cell_alloc.3.o)
	lr35902_rel_jump $(two_comp_d $((sz_3 + 2)))	# 2

	# regHLへNULLを設定
	lr35902_set_reg regHL $GBOS_NULL

	# pop & return
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
	lr35902_return
}

# 指定されたアドレスへ白/黒デイジーのデフォルト値を設定
f_binbio_cell_alloc >src/f_binbio_cell_alloc.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_alloc.o))
fadr=$(calc16 "${a_binbio_cell_alloc}+${fsz}")
a_binbio_cell_set_default_daisy=$(four_digits $fadr)
echo -e "a_binbio_cell_set_default_daisy=$a_binbio_cell_set_default_daisy" >>$MAP_FILE_NAME
## 定義はsrc/expset_daisyworld.shにある

# 指定されたアドレスへ捕食者のデフォルト値を設定
f_binbio_cell_set_default_daisy >src/f_binbio_cell_set_default_daisy.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_set_default_daisy.o))
fadr=$(calc16 "${a_binbio_cell_set_default_daisy}+${fsz}")
a_binbio_cell_set_default_predator=$(four_digits $fadr)
echo -e "a_binbio_cell_set_default_predator=$a_binbio_cell_set_default_predator" >>$MAP_FILE_NAME
## 定義はsrc/species_predator.shにある

# 現在の細胞に指定されたタイル番号を設定する
# in : regA  - タイル番号
f_binbio_cell_set_default_predator >src/f_binbio_cell_set_default_predator.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_set_default_predator.o))
fadr=$(calc16 "${a_binbio_cell_set_default_predator}+${fsz}")
a_binbio_cell_set_tile_num=$(four_digits $fadr)
echo -e "a_binbio_cell_set_tile_num=$a_binbio_cell_set_tile_num" >>$MAP_FILE_NAME
f_binbio_cell_set_tile_num() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 現在の細胞のtile_numへ指定されたタイル番号を設定
	## 指定されたタイル番号をregDへコピー
	lr35902_copy_to_from regD regA
	## 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA
	## アドレスregHLをtile_numまで進める
	lr35902_set_reg regBC 0006
	lr35902_add_to_regHL regBC
	## ptrHLへregDの値を設定
	lr35902_copy_to_from ptrHL regD

	# 設定されたタイルをマップへ描画
	## 指定されたタイル番号をregBへコピーしpushしておく
	lr35902_copy_to_from regB regD
	lr35902_push_reg regBC
	## 現在の細胞のtile_x,tile_yからVRAMアドレスを算出
	### アドレスregHLをtile_yまで戻す
	lr35902_set_reg regBC $(two_comp_4 4)
	lr35902_add_to_regHL regBC
	### tile_yをregDへ設定
	lr35902_copy_to_from regD ptrHL
	### アドレスregHLをtile_xまで戻す
	lr35902_set_reg regBC $(two_comp_4 1)
	lr35902_add_to_regHL regBC
	### tile_xをregEへ設定
	lr35902_copy_to_from regE ptrHL
	### タイル座標をアドレスへ変換
	lr35902_call $a_tcoord_to_addr
	## 算出したVRAMアドレスと細胞のタイル番号をtdqへエンキュー
	### タイル番号をregBへpopしてくる
	lr35902_pop_reg regBC
	### VRAMアドレスをregDEへ設定
	lr35902_copy_to_from regD regH
	lr35902_copy_to_from regE regL
	### tdqへエンキューする
	lr35902_call $a_enq_tdq

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 指定された生物種の細胞を指定されたタイル座標へ配置する
# 備考:
# - 各パラメータはその生物種のデフォルト値が設定される
# 引数:
# in : regB - 生物種のタイル番号
#      regD - タイル座標Y
#      regE - タイル座標X
f_binbio_cell_set_tile_num >src/f_binbio_cell_set_tile_num.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_set_tile_num.o))
fadr=$(calc16 "${a_binbio_cell_set_tile_num}+${fsz}")
a_binbio_place_cell=$(four_digits $fadr)
echo -e "a_binbio_place_cell=$a_binbio_place_cell" >>$MAP_FILE_NAME
f_binbio_place_cell() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	local obj

	# 1つ分の細胞データ領域を確保する
	lr35902_call $a_binbio_cell_alloc

	# 確保できた(regHL != NULL(0))か?
	lr35902_clear_reg regA
	lr35902_or_to_regA regL
	lr35902_or_to_regA regH
	lr35902_compare_regA_and 00
	obj=src/f_binbio_place_cell.alloc_failed.o
	(
		# 確保できなかった(regHL == NULL)場合

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regAF
		lr35902_return
	) >$obj
	local sz_alloc_failed=$(stat -c '%s' $obj)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_alloc_failed)
	cat $obj

	# 確保した細胞データ領域へ指定された生物種のデフォルト値を設定する
	lr35902_copy_to_from regA regB
	## 指定された生物種は白デイジーか?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_WHITE
	(
		# 白デイジーの場合
		lr35902_call $a_binbio_cell_set_default_daisy
	) | rel_jump_wrapper_binsz NZ forward
	## 指定された生物種は黒デイジーか?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_BLACK
	(
		# 黒デイジーの場合
		lr35902_call $a_binbio_cell_set_default_daisy
	) | rel_jump_wrapper_binsz NZ forward
	## 指定された生物種は捕食者か?
	lr35902_compare_regA_and $GBOS_TILE_NUM_PREDATOR
	(
		# 捕食者の場合
		lr35902_call $a_binbio_cell_set_default_predator
	) | rel_jump_wrapper_binsz NZ forward

	# 細胞をマップへ配置
	## タイル座標をVRAMアドレスへ変換
	lr35902_call $a_tcoord_to_addr
	## VRAMアドレスと細胞のタイル番号をtdqへエンキュー
	### regDEをスタックへ退避
	lr35902_push_reg regDE
	### VRAMアドレスをregDEへ設定
	lr35902_copy_to_from regD regH
	lr35902_copy_to_from regE regL
	### tdqへエンキューする
	lr35902_call $a_enq_tdq
	### regDEをスタックから復帰
	lr35902_pop_reg regDE

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
	lr35902_return
}

# 細胞の「死」の振る舞い
f_binbio_place_cell >src/f_binbio_place_cell.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_place_cell.o))
fadr=$(calc16 "${a_binbio_place_cell}+${fsz}")
a_binbio_cell_death=$(four_digits $fadr)
echo -e "a_binbio_cell_death=$a_binbio_cell_death" >>$MAP_FILE_NAME
f_binbio_cell_death() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# regHLへ現在の細胞のアドレスを設定する
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# 現在の細胞(のflags)のアドレスは後でも使うのでpushしておく
	lr35902_push_reg regHL

	# マップに描画されているタイルを消去
	## 現在の細胞のtile_x,tile_yからVRAMアドレスを算出
	### regE = tile_x
	lr35902_inc regHL
	lr35902_copy_to_from regE ptrHL
	### regD = tile_y
	lr35902_inc regHL
	lr35902_copy_to_from regD ptrHL
	### タイル座標をVRAMアドレスへ変換
	lr35902_call $a_tcoord_to_addr
	## 算出したVRAMアドレスと空白タイル(GBOS_TILE_NUM_SPC)をtdqへエンキュー
	### regDEへVRAMアドレス(regHL)を設定
	### ※ regDEの値(tile_y,tile_x)は後で使うのでregDEへの上書きではなく、
	### 　 regHLと入れ替える
	#### regEとregLを入れ替え
	lr35902_copy_to_from regA regE
	lr35902_copy_to_from regE regL
	lr35902_copy_to_from regL regA
	#### regDとregHを入れ替え
	lr35902_copy_to_from regA regD
	lr35902_copy_to_from regD regH
	lr35902_copy_to_from regH regA
	### regB = 空白タイル
	lr35902_set_reg regB $GBOS_TILE_NUM_SPC
	### エンキュー
	lr35902_call $a_enq_tdq
	## この時点でタイルミラー領域へも手動で反映
	### 現在の細胞のtile_x,tile_yからミラーアドレスを算出
	#### regDEへtile_y,tile_xを設定(regHLから復帰)
	lr35902_copy_to_from regE regL
	lr35902_copy_to_from regD regH
	#### タイル座標をミラーアドレスへ変換
	lr35902_call $a_tcoord_to_mrraddr
	### ミラー領域へタイル番号を書き込み
	lr35902_copy_to_from ptrHL regB

	# 現在の細胞のaliveフラグをクリアする
	## 現在の細胞のflagsのアドレスをregHLへpop
	lr35902_pop_reg regHL
	## aliveフラグをクリア
	lr35902_res_bitN_of_reg 0 ptrHL

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 評価の実装 - 8近傍の同じタイル属性のタイルの数を評価する
# out: regA - 評価結果の適応度(0x00〜0xff)
f_binbio_cell_death >src/f_binbio_cell_death.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_death.o))
fadr=$(calc16 "${a_binbio_cell_death}+${fsz}")
a_binbio_cell_eval_family=$(four_digits $fadr)
echo -e "a_binbio_cell_eval_family=$a_binbio_cell_eval_family" >>$MAP_FILE_NAME
f_binbio_cell_eval_family() {
	# push
	lr35902_push_reg regBC
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# アドレスregHLをtile_numまで進める
	lr35902_set_reg regBC 0006
	lr35902_add_to_regHL regBC

	# regAへ自身のタイル属性番号を取得
	## regAへtile_numを取得
	lr35902_copy_to_from regA ptrHL
	## regAへタイル属性番号を取得
	lr35902_call $a_binbio_get_tile_family_num

	# regA(タイル属性番号) == 属性なし ?
	lr35902_compare_regA_and $BINBIO_TILE_FAMILY_NUM_NONE
	(
		# regA == 属性なし の場合

		# pop
		lr35902_pop_reg regHL
		lr35902_pop_reg regAF
		lr35902_pop_reg regBC

		# regAへ適応度のベース値を設定
		lr35902_set_reg regA $BINBIO_CELL_EVAL_BASE_FITNESS

		# return
		lr35902_return
	) >src/f_binbio_cell_eval_family.1.o
	local sz_1=$(stat -c '%s' src/f_binbio_cell_eval_family.1.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
	cat src/f_binbio_cell_eval_family.1.o

	# push
	lr35902_push_reg regDE

	# regBへregA(現在の細胞のタイル属性番号)を設定し、
	# regCへ適応度のベース値を設定し、push
	lr35902_copy_to_from regB regA
	lr35902_set_reg regC $BINBIO_CELL_EVAL_BASE_FITNESS
	lr35902_push_reg regBC

	# (regE, regD)へ(tile_x, tile_y)を取得
	## アドレスregHLをtile_xまで戻す
	lr35902_set_reg regBC $(two_comp_4 5)
	lr35902_add_to_regHL regBC
	## regEへtile_xを取得
	lr35902_copy_to_from regE ptrHL
	## アドレスregHLをtile_yまで進める
	lr35902_inc regHL
	## regDへtile_yを取得
	lr35902_copy_to_from regD ptrHL

	# 現在の細胞の8近傍を左上から順に時計回りでチェック

	# 現在の細胞のタイルのタイルミラー領域上のアドレスをregHLへ設定
	lr35902_call $a_tcoord_to_mrraddr

	# 繰り返し使用する処理をファイル書き出し/マクロ定義
	## 対象の座標のタイル属性番号 == 現在の細胞のタイル属性番号 の場合の処理
	(
		# regC += 単位量
		lr35902_copy_to_from regA regC
		lr35902_add_to_regA $BINBIO_CELL_EVAL_FAMILY_ADD_UNIT
		lr35902_copy_to_from regC regA
	) >src/f_binbio_cell_eval_family.add.o
	local sz_add=$(stat -c '%s' src/f_binbio_cell_eval_family.add.o)
	## アドレスregHLのタイル属性が現在の細胞と等しければ適応度へ単位量を加算する処理
	(
		# regAへ対象座標のタイル属性番号を取得
		## regAへ対象座標のタイル番号を取得
		lr35902_copy_to_from regA ptrHL
		## タイル番号からタイル属性番号を取得
		lr35902_call $a_binbio_get_tile_family_num

		# 現在の細胞のタイル属性番号と適応度をpop
		lr35902_pop_reg regBC

		# regA(対象座標のタイル属性番号) == regB(現在の細胞のタイル属性番号) ?
		lr35902_compare_regA_and regB
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_add)
		cat src/f_binbio_cell_eval_family.add.o

		# 現在の細胞のタイル属性番号と適応度を再びpush
		lr35902_push_reg regBC
	) >src/f_binbio_cell_eval_family.chkadd.o

	# regD(tile_y) == 0 ?
	lr35902_copy_to_from regA regD
	lr35902_compare_regA_and 00
	(
		# tile_y != 0 の場合

		# regE(tile_x) == 0 ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and 00
		(
			# tile_x != 0 の場合

			# 左上座標をチェックし、
			# タイル属性が現在の細胞と等しければ適応度へ単位量を加算
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC $(two_comp_4 21)
			lr35902_add_to_regHL regBC
			## アドレスregHLのタイル属性が現在の細胞と等しければ適応度へ単位量を加算
			cat src/f_binbio_cell_eval_family.chkadd.o
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC 0021
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_eval_family.2.o
		local sz_2=$(stat -c '%s' src/f_binbio_cell_eval_family.2.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
		cat src/f_binbio_cell_eval_family.2.o

		# 上座標をチェックし、
		# タイル属性が現在の細胞と等しければ適応度へ単位量を加算
		## アドレスregHLを対象座標へ移動
		lr35902_set_reg regBC $(two_comp_4 20)
		lr35902_add_to_regHL regBC
		## アドレスregHLのタイル属性が現在の細胞と等しければ適応度へ単位量を加算
		cat src/f_binbio_cell_eval_family.chkadd.o
		## アドレスregHLを元に戻す
		lr35902_set_reg regBC 0020
		lr35902_add_to_regHL regBC

		# regE(tile_x) == 表示範囲の右端 ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
		(
			# tile_x != 表示範囲の右端 の場合

			# 右上座標をチェックし、
			# タイル属性が現在の細胞と等しければ適応度へ単位量を加算
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC $(two_comp_4 1f)
			lr35902_add_to_regHL regBC
			## アドレスregHLのタイル属性が現在の細胞と等しければ適応度へ単位量を加算
			cat src/f_binbio_cell_eval_family.chkadd.o
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC 001f
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_eval_family.3.o
		local sz_3=$(stat -c '%s' src/f_binbio_cell_eval_family.3.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_3)
		cat src/f_binbio_cell_eval_family.3.o
	) >src/f_binbio_cell_eval_family.4.o
	local sz_4=$(stat -c '%s' src/f_binbio_cell_eval_family.4.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_4)
	cat src/f_binbio_cell_eval_family.4.o

	# regE(tile_x) == 表示範囲の右端 ?
	lr35902_copy_to_from regA regE
	lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
	(
		# tile_x != 表示範囲の右端 の場合

		# 右座標をチェックし、
		# タイル属性が現在の細胞と等しければ適応度へ単位量を加算
		## アドレスregHLを対象座標へ移動
		lr35902_inc regHL
		## アドレスregHLのタイル属性が現在の細胞と等しければ適応度へ単位量を加算
		cat src/f_binbio_cell_eval_family.chkadd.o
		## アドレスregHLを元に戻す
		lr35902_dec regHL
	) >src/f_binbio_cell_eval_family.5.o
	local sz_5=$(stat -c '%s' src/f_binbio_cell_eval_family.5.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_5)
	cat src/f_binbio_cell_eval_family.5.o

	# regD(tile_y) == 表示範囲の下端 ?
	lr35902_copy_to_from regA regD
	lr35902_compare_regA_and $(calc16_2 "${GB_DISP_HEIGHT_T}-1")
	(
		# tile_y != 表示範囲の下端 の場合

		# regE(tile_x) == 表示範囲の右端 ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
		(
			# tile_x != 表示範囲の右端 の場合

			# 右下座標をチェックし、
			# タイル属性が現在の細胞と等しければ適応度へ単位量を加算
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC 0021
			lr35902_add_to_regHL regBC
			## アドレスregHLのタイル属性が現在の細胞と等しければ適応度へ単位量を加算
			cat src/f_binbio_cell_eval_family.chkadd.o
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC $(two_comp_4 21)
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_eval_family.6.o
		local sz_6=$(stat -c '%s' src/f_binbio_cell_eval_family.6.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_6)
		cat src/f_binbio_cell_eval_family.6.o

		# 下座標をチェックし、
		# タイル属性が現在の細胞と等しければ適応度へ単位量を加算
		## アドレスregHLを対象座標へ移動
		lr35902_set_reg regBC 0020
		lr35902_add_to_regHL regBC
		## アドレスregHLのタイル属性が現在の細胞と等しければ適応度へ単位量を加算
		cat src/f_binbio_cell_eval_family.chkadd.o
		## アドレスregHLを元に戻す
		lr35902_set_reg regBC $(two_comp_4 20)
		lr35902_add_to_regHL regBC

		# regE(tile_x) == 0 ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and 00
		(
			# tile_x != 0 の場合

			# 左下座標をチェックし、
			# タイル属性が現在の細胞と等しければ適応度へ単位量を加算
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC 001f
			lr35902_add_to_regHL regBC
			## アドレスregHLのタイル属性が現在の細胞と等しければ適応度へ単位量を加算
			cat src/f_binbio_cell_eval_family.chkadd.o
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC $(two_comp_4 1f)
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_eval_family.7.o
		local sz_7=$(stat -c '%s' src/f_binbio_cell_eval_family.7.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_7)
		cat src/f_binbio_cell_eval_family.7.o
	) >src/f_binbio_cell_eval_family.8.o
	local sz_8=$(stat -c '%s' src/f_binbio_cell_eval_family.8.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_8)
	cat src/f_binbio_cell_eval_family.8.o

	# regE(tile_x) == 0 ?
	lr35902_copy_to_from regA regE
	lr35902_compare_regA_and 00
	(
		# tile_x != 0 の場合

		# 左座標をチェックし、
		# タイル属性が現在の細胞と等しければ適応度へ単位量を加算
		## アドレスregHLを対象座標へ移動
		lr35902_dec regHL
		## アドレスregHLのタイル属性が現在の細胞と等しければ適応度へ単位量を加算
		cat src/f_binbio_cell_eval_family.chkadd.o
		## アドレスregHLを元に戻す
		lr35902_inc regHL
	) >src/f_binbio_cell_eval_family.9.o
	local sz_9=$(stat -c '%s' src/f_binbio_cell_eval_family.9.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_9)
	cat src/f_binbio_cell_eval_family.9.o

	# 現在の細胞のタイル属性番号と適応度をpop
	lr35902_pop_reg regBC

	# pop
	lr35902_pop_reg regDE
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF

	# regCへ反映していた適応度をregAへコピー
	lr35902_copy_to_from regA regC

	# pop & return
	lr35902_pop_reg regBC
	lr35902_return
}

# 評価の実装 - 「こんにちは、せかい！」という文字列の形成を目指す
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval_family >src/f_binbio_cell_eval_family.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_eval_family.o))
fadr=$(calc16 "${a_binbio_cell_eval_family}+${fsz}")
a_binbio_cell_eval_helloworld=$(four_digits $fadr)
echo -e "a_binbio_cell_eval_helloworld=$a_binbio_cell_eval_helloworld" >>$MAP_FILE_NAME
f_binbio_cell_eval_helloworld() {
	# push
	lr35902_push_reg regHL

	# 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# push
	lr35902_push_reg regBC

	# アドレスregHLをtile_numまで進める
	lr35902_set_reg regBC 0006
	lr35902_add_to_regHL regBC

	# regA = tile_num
	lr35902_copy_to_from regA ptrHL

	# 繰り返し使用する処理をファイルへ出力あるいはマクロ定義しておく
	## (regE,regD) = (tile_x,tile_y)
	(
		# アドレスregHLをtile_xまで戻す
		lr35902_set_reg regBC $(two_comp_4 5)
		lr35902_add_to_regHL regBC

		# regE = tile_x
		lr35902_copy_to_from regE ptrHL

		# アドレスregHLをtile_yまで進める
		lr35902_inc regHL

		# regD = tile_y
		lr35902_copy_to_from regD ptrHL
	) >src/f_binbio_cell_eval_helloworld.set_ed_xy.o
	## regBへ単位量(1/2)を加算
	(
		lr35902_set_reg regA $BINBIO_CELL_EVAL_HELLOWORLD_ADD_UNIT_H
		lr35902_add_to_regA regB
		lr35902_copy_to_from regB regA
	) >src/f_binbio_cell_eval_helloworld.addh.o
	local sz_addh=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.addh.o)
	## regBへ単位量(1/4)を加算
	(
		lr35902_set_reg regA $BINBIO_CELL_EVAL_HELLOWORLD_ADD_UNIT_Q
		lr35902_add_to_regA regB
		lr35902_copy_to_from regB regA
	) >src/f_binbio_cell_eval_helloworld.addq.o
	local sz_addq=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.addq.o)
	## regBをpopし、単位量(1/2)を加算後、再度push
	(
		# regBCをpop
		lr35902_pop_reg regBC

		# regBへ単位量を加算
		cat src/f_binbio_cell_eval_helloworld.addh.o

		# regBCをpush
		lr35902_push_reg regBC
	) >src/f_binbio_cell_eval_helloworld.pop_addh_push.o
	local sz_pop_addh_push=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.pop_addh_push.o)
	## regBをpopし、単位量(1/4)を加算後、再度push
	(
		# regBCをpop
		lr35902_pop_reg regBC

		# regBへ単位量を加算
		cat src/f_binbio_cell_eval_helloworld.addq.o

		# regBCをpush
		lr35902_push_reg regBC
	) >src/f_binbio_cell_eval_helloworld.pop_addq_push.o
	local sz_pop_addq_push=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.pop_addq_push.o)
	## 最初の文字の条件判定と処理
	_binbio_cell_eval_helloworld_char_first() {
		local target_tile_num=$1
		local next_tile_num=$2

		lr35902_compare_regA_and $target_tile_num
		(
			# regAが対象の文字の場合

			# push
			lr35902_push_reg regDE

			# (regE,regD) = (tile_x,tile_y)
			cat src/f_binbio_cell_eval_helloworld.set_ed_xy.o

			# regHLへ座標(tile_x,tile_y)に対応するタイルミラーアドレスを取得
			lr35902_call $a_tcoord_to_mrraddr

			# regB = 自分自身が所望のタイルである場合のベース値
			lr35902_set_reg regB $BINBIO_CELL_EVAL_HELLOWORLD_ADD_UNIT_OWN

			# regE(tile_x) == 表示範囲の右端 ?
			lr35902_copy_to_from regA regE
			lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
			(
				# tile_x != 表示範囲の右端 の場合

				# 右座標が次の文字の場合、regBへ単位量を加算
				## アドレスregHLを右座標へ移動
				lr35902_inc regHL
				## 右座標は次の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $next_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_addh)
				## regBへ単位量を加算
				cat src/f_binbio_cell_eval_helloworld.addh.o
				## アドレスregHLを戻す
				lr35902_dec regHL
			) >src/f_binbio_cell_eval_helloworld.char_first.1.o
			local sz_char_first_1=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_first.1.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_first_1)
			cat src/f_binbio_cell_eval_helloworld.char_first.1.o

			# regD(tile_y) == 表示範囲の下端 ?
			lr35902_copy_to_from regA regD
			lr35902_compare_regA_and $(calc16_2 "${GB_DISP_HEIGHT_T}-1")
			(
				# tile_y != 表示範囲の下端 の場合

				# 下座標が次の文字の場合、regBへ単位量を加算
				## regBCをpush
				lr35902_push_reg regBC
				## アドレスregHLを下座標へ移動
				lr35902_set_reg regBC 0020
				lr35902_add_to_regHL regBC
				## 下座標は次の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $next_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_pop_addh_push)
				### regBをpopし、単位量(1/2)を加算後、再度push
				cat src/f_binbio_cell_eval_helloworld.pop_addh_push.o
				## アドレスregHLを戻す
				lr35902_set_reg regBC $(two_comp_4 20)
				lr35902_add_to_regHL regBC
				## regBCをpop
				lr35902_pop_reg regBC
			) >src/f_binbio_cell_eval_helloworld.char_first.2.o
			local sz_char_first_2=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_first.2.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_first_2)
			cat src/f_binbio_cell_eval_helloworld.char_first.2.o

			# regAへ戻り値としてregB(適応度)を設定
			lr35902_copy_to_from regA regB

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_cell_eval_helloworld.char_first.3.o
		local sz_char_first_3=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_first.3.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_char_first_3)
		cat src/f_binbio_cell_eval_helloworld.char_first.3.o
	}
	## 中間の文字の条件判定と処理
	_binbio_cell_eval_helloworld_char_middle() {
		local target_tile_num=$1
		local prev_tile_num=$2
		local next_tile_num=$3

		lr35902_compare_regA_and $target_tile_num
		(
			# regAが対象の文字の場合

			# push
			lr35902_push_reg regDE

			# (regE,regD) = (tile_x,tile_y)
			cat src/f_binbio_cell_eval_helloworld.set_ed_xy.o

			# regHLへ座標(tile_x,tile_y)に対応するタイルミラーアドレスを取得
			lr35902_call $a_tcoord_to_mrraddr

			# regB = 自分自身が所望のタイルである場合のベース値
			lr35902_set_reg regB $BINBIO_CELL_EVAL_HELLOWORLD_ADD_UNIT_OWN

			# regD(tile_y) == 0 ?
			lr35902_copy_to_from regA regD
			lr35902_compare_regA_and 00
			(
				# tile_y != 0 の場合

				# 上座標が前の文字の場合、regBへ単位量を加算
				## regBCをpush
				lr35902_push_reg regBC
				## アドレスregHLを上座標へ移動
				lr35902_set_reg regBC $(two_comp_4 20)
				lr35902_add_to_regHL regBC
				## 上座標は前の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $prev_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_pop_addq_push)
				### regBをpopし、単位量(1/4)を加算後、再度push
				cat src/f_binbio_cell_eval_helloworld.pop_addq_push.o
				## アドレスregHLを戻す
				lr35902_set_reg regBC 0020
				lr35902_add_to_regHL regBC
				## regBCをpop
				lr35902_pop_reg regBC
			) >src/f_binbio_cell_eval_helloworld.char_middle.1.o
			local sz_char_middle_1=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_middle.1.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_middle_1)
			cat src/f_binbio_cell_eval_helloworld.char_middle.1.o

			# regE(tile_x) == 表示範囲の右端 ?
			lr35902_copy_to_from regA regE
			lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
			(
				# tile_x != 表示範囲の右端 の場合

				# 右座標が次の文字の場合、regBへ単位量を加算
				## アドレスregHLを右座標へ移動
				lr35902_inc regHL
				## 右座標は次の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $next_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_addq)
				### regBへ単位量を加算
				cat src/f_binbio_cell_eval_helloworld.addq.o
				## アドレスregHLを戻す
				lr35902_dec regHL
			) >src/f_binbio_cell_eval_helloworld.char_middle.2.o
			local sz_char_middle_2=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_middle.2.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_middle_2)
			cat src/f_binbio_cell_eval_helloworld.char_middle.2.o

			# regD(tile_y) == 表示範囲の下端 ?
			lr35902_copy_to_from regA regD
			lr35902_compare_regA_and $(calc16_2 "${GB_DISP_HEIGHT_T}-1")
			(
				# tile_y != 表示範囲の下端 の場合

				# 下座標が次の文字の場合、regBへ単位量を加算
				## regBCをpush
				lr35902_push_reg regBC
				## アドレスregHLを下座標へ移動
				lr35902_set_reg regBC 0020
				lr35902_add_to_regHL regBC
				## 下座標は次の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $next_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_pop_addq_push)
				### regBをpopし、単位量(1/4)を加算後、再度push
				cat src/f_binbio_cell_eval_helloworld.pop_addq_push.o
				## アドレスregHLを戻す
				lr35902_set_reg regBC $(two_comp_4 20)
				lr35902_add_to_regHL regBC
				## regBCをpop
				lr35902_pop_reg regBC
			) >src/f_binbio_cell_eval_helloworld.char_middle.3.o
			local sz_char_middle_3=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_middle.3.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_middle_3)
			cat src/f_binbio_cell_eval_helloworld.char_middle.3.o

			# regE(tile_x) == 0 ?
			lr35902_copy_to_from regA regE
			lr35902_compare_regA_and 00
			(
				# tile_x != 0 の場合

				# 左座標が前の文字の場合、regBへ単位量を加算
				## アドレスregHLを左座標へ移動
				lr35902_dec regHL
				## 左座標は前の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $prev_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_addq)
				## regBへ単位量を加算
				cat src/f_binbio_cell_eval_helloworld.addq.o
				## アドレスregHLを戻す
				lr35902_inc regHL
			) >src/f_binbio_cell_eval_helloworld.char_middle.4.o
			local sz_char_middle_4=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_middle.4.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_middle_4)
			cat src/f_binbio_cell_eval_helloworld.char_middle.4.o

			# regAへ戻り値としてregB(適応度)を設定
			lr35902_copy_to_from regA regB

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_cell_eval_helloworld.char_middle.5.o
		local sz_char_middle_5=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_middle.5.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_char_middle_5)
		cat src/f_binbio_cell_eval_helloworld.char_middle.5.o
	}
	## 最後の文字の条件判定と処理
	_binbio_cell_eval_helloworld_char_last() {
		local target_tile_num=$1
		local prev_tile_num=$2

		lr35902_compare_regA_and $target_tile_num
		(
			# regAが対象の文字の場合

			# push
			lr35902_push_reg regDE

			# (regE,regD) = (tile_x,tile_y)
			cat src/f_binbio_cell_eval_helloworld.set_ed_xy.o

			# regHLへ座標(tile_x,tile_y)に対応するタイルミラーアドレスを取得
			lr35902_call $a_tcoord_to_mrraddr

			# regB = 自分自身が所望のタイルである場合のベース値
			lr35902_set_reg regB $BINBIO_CELL_EVAL_HELLOWORLD_ADD_UNIT_OWN

			# regD(tile_y) == 0 ?
			lr35902_copy_to_from regA regD
			lr35902_compare_regA_and 00
			(
				# tile_y != 0 の場合

				# 上座標が前の文字の場合、regBへ単位量を加算
				## regBCをpush
				lr35902_push_reg regBC
				## アドレスregHLを上座標へ移動
				lr35902_set_reg regBC $(two_comp_4 20)
				lr35902_add_to_regHL regBC
				## 上座標は前の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $prev_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_pop_addh_push)
				### regBをpopし、単位量(1/2)を加算後、再度push
				cat src/f_binbio_cell_eval_helloworld.pop_addh_push.o
				## アドレスregHLを戻す
				lr35902_set_reg regBC 0020
				lr35902_add_to_regHL regBC
				## regBCをpop
				lr35902_pop_reg regBC
			) >src/f_binbio_cell_eval_helloworld.char_last.1.o
			local sz_char_last_1=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_last.1.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_last_1)
			cat src/f_binbio_cell_eval_helloworld.char_last.1.o

			# regE(tile_x) == 0 ?
			lr35902_copy_to_from regA regE
			lr35902_compare_regA_and 00
			(
				# tile_x != 0 の場合

				# 左座標が前の文字の場合、regBへ単位量を加算
				## アドレスregHLを左座標へ移動
				lr35902_dec regHL
				## 左座標は前の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $prev_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_addh)
				## regBへ単位量を加算
				cat src/f_binbio_cell_eval_helloworld.addh.o
				## アドレスregHLを戻す
				lr35902_inc regHL
			) >src/f_binbio_cell_eval_helloworld.char_last.2.o
			local sz_char_last_2=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_last.2.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_last_2)
			cat src/f_binbio_cell_eval_helloworld.char_last.2.o

			# regAへ戻り値としてregB(適応度)を設定
			lr35902_copy_to_from regA regB

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_cell_eval_helloworld.char_last.3.o
		local sz_char_last_3=$(stat -c '%s' src/f_binbio_cell_eval_helloworld.char_last.3.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_char_last_3)
		cat src/f_binbio_cell_eval_helloworld.char_last.3.o
	}

	# 文字別の条件判定と処理
	## 「こ」
	_binbio_cell_eval_helloworld_char_first $GBOS_TILE_NUM_HIRA_KO $GBOS_TILE_NUM_HIRA_N
	## 「ん」
	_binbio_cell_eval_helloworld_char_middle $GBOS_TILE_NUM_HIRA_N $GBOS_TILE_NUM_HIRA_KO $GBOS_TILE_NUM_HIRA_NI
	## 「に」
	_binbio_cell_eval_helloworld_char_middle $GBOS_TILE_NUM_HIRA_NI $GBOS_TILE_NUM_HIRA_N $GBOS_TILE_NUM_HIRA_CHI
	## 「ち」
	_binbio_cell_eval_helloworld_char_middle $GBOS_TILE_NUM_HIRA_CHI $GBOS_TILE_NUM_HIRA_NI $GBOS_TILE_NUM_HIRA_HA
	## 「は」
	_binbio_cell_eval_helloworld_char_middle $GBOS_TILE_NUM_HIRA_HA $GBOS_TILE_NUM_HIRA_CHI $GBOS_TILE_NUM_TOUTEN
	## 「、」
	_binbio_cell_eval_helloworld_char_middle $GBOS_TILE_NUM_TOUTEN $GBOS_TILE_NUM_HIRA_HA $GBOS_TILE_NUM_HIRA_SE
	## 「せ」
	_binbio_cell_eval_helloworld_char_middle $GBOS_TILE_NUM_HIRA_SE $GBOS_TILE_NUM_TOUTEN $GBOS_TILE_NUM_HIRA_KA
	## 「か」
	_binbio_cell_eval_helloworld_char_middle $GBOS_TILE_NUM_HIRA_KA $GBOS_TILE_NUM_HIRA_SE $GBOS_TILE_NUM_HIRA_I
	## 「い」
	_binbio_cell_eval_helloworld_char_middle $GBOS_TILE_NUM_HIRA_I $GBOS_TILE_NUM_HIRA_KA $GBOS_TILE_NUM_EXCLAMATION
	## 「!」
	_binbio_cell_eval_helloworld_char_last $GBOS_TILE_NUM_EXCLAMATION $GBOS_TILE_NUM_HIRA_I

	# regAへ戻り値として適応度のベース値を設定
	lr35902_set_reg regA $BINBIO_CELL_EVAL_BASE_FITNESS

	# pop & return
	lr35902_pop_reg regBC
	lr35902_pop_reg regHL
	lr35902_return
}

# 評価の実装 - 「DAISY」という文字列の形成を目指す
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval_helloworld >src/f_binbio_cell_eval_helloworld.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_eval_helloworld.o))
fadr=$(calc16 "${a_binbio_cell_eval_helloworld}+${fsz}")
a_binbio_cell_eval_daisy=$(four_digits $fadr)
echo -e "a_binbio_cell_eval_daisy=$a_binbio_cell_eval_daisy" >>$MAP_FILE_NAME
f_binbio_cell_eval_daisy() {
	# push
	lr35902_push_reg regHL

	# 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# push
	lr35902_push_reg regBC

	# アドレスregHLをtile_numまで進める
	lr35902_set_reg regBC 0006
	lr35902_add_to_regHL regBC

	# regA = tile_num
	lr35902_copy_to_from regA ptrHL

	# 繰り返し使用する処理をファイルへ出力あるいはマクロ定義しておく
	## (regE,regD) = (tile_x,tile_y)
	(
		# アドレスregHLをtile_xまで戻す
		lr35902_set_reg regBC $(two_comp_4 5)
		lr35902_add_to_regHL regBC

		# regE = tile_x
		lr35902_copy_to_from regE ptrHL

		# アドレスregHLをtile_yまで進める
		lr35902_inc regHL

		# regD = tile_y
		lr35902_copy_to_from regD ptrHL
	) >src/f_binbio_cell_eval_daisy.set_ed_xy.o
	## regBへ単位量を加算
	(
		lr35902_set_reg regA $BINBIO_CELL_EVAL_DAISY_ADD_UNIT
		lr35902_add_to_regA regB
		lr35902_copy_to_from regB regA
	) >src/f_binbio_cell_eval_daisy.add.o
	local sz_add=$(stat -c '%s' src/f_binbio_cell_eval_daisy.add.o)
	## regBへ単位量(1/2)を加算
	(
		lr35902_set_reg regA $BINBIO_CELL_EVAL_DAISY_ADD_UNIT_H
		lr35902_add_to_regA regB
		lr35902_copy_to_from regB regA
	) >src/f_binbio_cell_eval_daisy.addh.o
	local sz_addh=$(stat -c '%s' src/f_binbio_cell_eval_daisy.addh.o)
	## regBをpopし、単位量を加算後、再度push
	(
		# regBCをpop
		lr35902_pop_reg regBC

		# regBへ単位量を加算
		cat src/f_binbio_cell_eval_daisy.add.o

		# regBCをpush
		lr35902_push_reg regBC
	) >src/f_binbio_cell_eval_daisy.pop_add_push.o
	local sz_pop_add_push=$(stat -c '%s' src/f_binbio_cell_eval_daisy.pop_add_push.o)
	## regBをpopし、単位量(1/2)を加算後、再度push
	(
		# regBCをpop
		lr35902_pop_reg regBC

		# regBへ単位量を加算
		cat src/f_binbio_cell_eval_daisy.addh.o

		# regBCをpush
		lr35902_push_reg regBC
	) >src/f_binbio_cell_eval_daisy.pop_addh_push.o
	local sz_pop_addh_push=$(stat -c '%s' src/f_binbio_cell_eval_daisy.pop_addh_push.o)
	## 最初の文字の条件判定と処理
	_binbio_cell_eval_daisy_char_first() {
		local target_tile_num=$1
		local next_tile_num=$2

		lr35902_compare_regA_and $target_tile_num
		(
			# regAが対象の文字の場合

			# push
			lr35902_push_reg regDE

			# (regE,regD) = (tile_x,tile_y)
			cat src/f_binbio_cell_eval_daisy.set_ed_xy.o

			# regHLへ座標(tile_x,tile_y)に対応するタイルミラーアドレスを取得
			lr35902_call $a_tcoord_to_mrraddr

			# regB = 自分自身が所望のタイルである場合のベース値
			lr35902_set_reg regB $BINBIO_CELL_EVAL_DAISY_ADD_UNIT_OWN

			# regE(tile_x) == 表示範囲の右端 ?
			lr35902_copy_to_from regA regE
			lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
			(
				# tile_x != 表示範囲の右端 の場合

				# 右座標が次の文字の場合、regBへ単位量を加算
				## アドレスregHLを右座標へ移動
				lr35902_inc regHL
				## 右座標は次の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $next_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_add)
				## regBへ単位量を加算
				cat src/f_binbio_cell_eval_daisy.add.o
				## アドレスregHLを戻す
				lr35902_dec regHL
			) >src/f_binbio_cell_eval_daisy.char_first.1.o
			local sz_char_first_1=$(stat -c '%s' src/f_binbio_cell_eval_daisy.char_first.1.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_first_1)
			cat src/f_binbio_cell_eval_daisy.char_first.1.o

			# regAへ戻り値としてregB(適応度)を設定
			lr35902_copy_to_from regA regB

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_cell_eval_daisy.char_first.3.o
		local sz_char_first_3=$(stat -c '%s' src/f_binbio_cell_eval_daisy.char_first.3.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_char_first_3)
		cat src/f_binbio_cell_eval_daisy.char_first.3.o
	}
	## 中間の文字の条件判定と処理
	_binbio_cell_eval_daisy_char_middle() {
		local target_tile_num=$1
		local prev_tile_num=$2
		local next_tile_num=$3

		lr35902_compare_regA_and $target_tile_num
		(
			# regAが対象の文字の場合

			# push
			lr35902_push_reg regDE

			# (regE,regD) = (tile_x,tile_y)
			cat src/f_binbio_cell_eval_daisy.set_ed_xy.o

			# regHLへ座標(tile_x,tile_y)に対応するタイルミラーアドレスを取得
			lr35902_call $a_tcoord_to_mrraddr

			# regB = 自分自身が所望のタイルである場合のベース値
			lr35902_set_reg regB $BINBIO_CELL_EVAL_DAISY_ADD_UNIT_OWN

			# regE(tile_x) == 表示範囲の右端 ?
			lr35902_copy_to_from regA regE
			lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
			(
				# tile_x != 表示範囲の右端 の場合

				# 右座標が次の文字の場合、regBへ単位量を加算
				## アドレスregHLを右座標へ移動
				lr35902_inc regHL
				## 右座標は次の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $next_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_addh)
				### regBへ単位量を加算
				cat src/f_binbio_cell_eval_daisy.addh.o
				## アドレスregHLを戻す
				lr35902_dec regHL
			) >src/f_binbio_cell_eval_daisy.char_middle.2.o
			local sz_char_middle_2=$(stat -c '%s' src/f_binbio_cell_eval_daisy.char_middle.2.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_middle_2)
			cat src/f_binbio_cell_eval_daisy.char_middle.2.o

			# regE(tile_x) == 0 ?
			lr35902_copy_to_from regA regE
			lr35902_compare_regA_and 00
			(
				# tile_x != 0 の場合

				# 左座標が前の文字の場合、regBへ単位量を加算
				## アドレスregHLを左座標へ移動
				lr35902_dec regHL
				## 左座標は前の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $prev_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_addh)
				## regBへ単位量を加算
				cat src/f_binbio_cell_eval_daisy.addh.o
				## アドレスregHLを戻す
				lr35902_inc regHL
			) >src/f_binbio_cell_eval_daisy.char_middle.4.o
			local sz_char_middle_4=$(stat -c '%s' src/f_binbio_cell_eval_daisy.char_middle.4.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_middle_4)
			cat src/f_binbio_cell_eval_daisy.char_middle.4.o

			# regAへ戻り値としてregB(適応度)を設定
			lr35902_copy_to_from regA regB

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_cell_eval_daisy.char_middle.5.o
		local sz_char_middle_5=$(stat -c '%s' src/f_binbio_cell_eval_daisy.char_middle.5.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_char_middle_5)
		cat src/f_binbio_cell_eval_daisy.char_middle.5.o
	}
	## 最後の文字の条件判定と処理
	_binbio_cell_eval_daisy_char_last() {
		local target_tile_num=$1
		local prev_tile_num=$2

		lr35902_compare_regA_and $target_tile_num
		(
			# regAが対象の文字の場合

			# push
			lr35902_push_reg regDE

			# (regE,regD) = (tile_x,tile_y)
			cat src/f_binbio_cell_eval_daisy.set_ed_xy.o

			# regHLへ座標(tile_x,tile_y)に対応するタイルミラーアドレスを取得
			lr35902_call $a_tcoord_to_mrraddr

			# regB = 自分自身が所望のタイルである場合のベース値
			lr35902_set_reg regB $BINBIO_CELL_EVAL_DAISY_ADD_UNIT_OWN

			# regE(tile_x) == 0 ?
			lr35902_copy_to_from regA regE
			lr35902_compare_regA_and 00
			(
				# tile_x != 0 の場合

				# 左座標が前の文字の場合、regBへ単位量を加算
				## アドレスregHLを左座標へ移動
				lr35902_dec regHL
				## 左座標は前の文字か?
				lr35902_copy_to_from regA ptrHL
				lr35902_compare_regA_and $prev_tile_num
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_add)
				## regBへ単位量を加算
				cat src/f_binbio_cell_eval_daisy.add.o
				## アドレスregHLを戻す
				lr35902_inc regHL
			) >src/f_binbio_cell_eval_daisy.char_last.2.o
			local sz_char_last_2=$(stat -c '%s' src/f_binbio_cell_eval_daisy.char_last.2.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_char_last_2)
			cat src/f_binbio_cell_eval_daisy.char_last.2.o

			# regAへ戻り値としてregB(適応度)を設定
			lr35902_copy_to_from regA regB

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_cell_eval_daisy.char_last.3.o
		local sz_char_last_3=$(stat -c '%s' src/f_binbio_cell_eval_daisy.char_last.3.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_char_last_3)
		cat src/f_binbio_cell_eval_daisy.char_last.3.o
	}

	# 文字別の条件判定と処理
	## 使用する文字のタイル番号を変数へ取得しておく
	local tile_D=$(get_alpha_tile_num 'D')
	local tile_A=$(get_alpha_tile_num 'A')
	local tile_I=$(get_alpha_tile_num 'I')
	local tile_S=$(get_alpha_tile_num 'S')
	local tile_Y=$(get_alpha_tile_num 'Y')
	## 「D」
	_binbio_cell_eval_daisy_char_first $tile_D $tile_A
	## 「A」
	_binbio_cell_eval_daisy_char_middle $tile_A $tile_D $tile_I
	## 「I」
	_binbio_cell_eval_daisy_char_middle $tile_I $tile_A $tile_S
	## 「S」
	_binbio_cell_eval_daisy_char_middle $tile_S $tile_I $tile_Y
	## 「Y」
	_binbio_cell_eval_daisy_char_last $tile_Y $tile_S

	# regAへ戻り値として適応度のベース値を設定
	lr35902_set_reg regA $BINBIO_CELL_EVAL_BASE_FITNESS

	# pop & return
	lr35902_pop_reg regBC
	lr35902_pop_reg regHL
	lr35902_return
}

# 評価の実装 - 「HELLO」という文字列の形成を目指す
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval_daisy >src/f_binbio_cell_eval_daisy.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_eval_daisy.o))
fadr=$(calc16 "${a_binbio_cell_eval_daisy}+${fsz}")
a_binbio_cell_eval_hello=$(four_digits $fadr)
echo -e "a_binbio_cell_eval_hello=$a_binbio_cell_eval_hello" >>$MAP_FILE_NAME
f_binbio_cell_eval_hello() {
	# push
	lr35902_push_reg regHL

	# 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# flags.fix == 1 ?
	lr35902_test_bitN_of_reg $BINBIO_CELL_FLAGS_BIT_FIX ptrHL
	(
		# flags.fix == 1 の場合

		# 戻り値に適応度0xffを設定
		lr35902_set_reg regA ff

		# pop & return
		lr35902_pop_reg regHL
		lr35902_return
	) >src/f_binbio_cell_eval_hello.fix.o
	local sz_fix=$(stat -c '%s' src/f_binbio_cell_eval_hello.fix.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_fix)
	cat src/f_binbio_cell_eval_hello.fix.o

	# push
	lr35902_push_reg regBC
	lr35902_push_reg regDE

	# アドレスregHLをtile_xまで進める
	lr35902_inc regHL

	# regE = tile_x
	lr35902_copy_to_from regE ptrHL

	# アドレスregHLをtile_numまで進める
	lr35902_set_reg regBC 0005
	lr35902_add_to_regHL regBC

	# regA = tile_num
	lr35902_copy_to_from regA ptrHL

	# regA == 細胞タイル ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_CELL
	(
		# regA == 細胞タイル の場合

		# regA = 適応度のベース値
		lr35902_set_reg regA $BINBIO_CELL_EVAL_BASE_FITNESS

		# pop & return
		lr35902_pop_reg regDE
		lr35902_pop_reg regBC
		lr35902_pop_reg regHL
		lr35902_return
	) >src/f_binbio_cell_eval_hello.cell.o
	local sz_cell=$(stat -c '%s' src/f_binbio_cell_eval_hello.cell.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_cell)
	cat src/f_binbio_cell_eval_hello.cell.o

	# regD = regA(tile_num)
	lr35902_copy_to_from regD regA

	# regA = regE(tile_x)
	lr35902_copy_to_from regA regE

	# 繰り返し使用する処理をマクロ定義
	## 対象の文字との近さに応じた適応度を返す
	_binbio_cell_eval_hello_ret_distance() {
		# 引数を取得
		local target_char=$1

		# 対象のタイル番号をシェル変数へ設定
		local target_tile_num=$(get_alpha_tile_num $target_char)

		# regA = regD(tile_num)
		lr35902_copy_to_from regA regD

		# regA(tile_num) < 対象のタイル番号 ?
		lr35902_compare_regA_and $target_tile_num
		(
			# regA(tile_num) < 対象のタイル番号 の場合

			# regA = 最大距離 - (対象のタイル番号 - tile_num)
			## regA = 対象のタイル番号 - tile_num
			### regA = 対象のタイル番号
			lr35902_set_reg regA $target_tile_num
			### regA -= regD(tile_num)
			lr35902_sub_to_regA regD
			## regB = regA
			lr35902_copy_to_from regB regA
			## regA = 最大距離
			lr35902_set_reg regA $BINBIO_CELL_EVAL_HELLO_MAX_ALPHA_DIS
			## regA -= regB
			lr35902_sub_to_regA regB

			# regA *= 5
			## regB = regA
			lr35902_copy_to_from regB regA
			## regA <<= 2 (regA *= 4)
			lr35902_shift_left_arithmetic regA
			lr35902_shift_left_arithmetic regA
			## regA += regB
			lr35902_add_to_regA regB

			# regA += 適応度のベース値
			lr35902_add_to_regA $BINBIO_CELL_EVAL_BASE_FITNESS

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_cell_eval_hello.lt.o
		local sz_lt=$(stat -c '%s' src/f_binbio_cell_eval_hello.lt.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_lt)
		cat src/f_binbio_cell_eval_hello.lt.o

		# regA(tile_num) == 対象のタイル番号 ?
		(
			# regA(tile_num) == 対象のタイル番号 の場合

			# アドレスregHLをlife_durationまで戻す
			lr35902_set_reg regBC $(two_comp_4 3)
			lr35902_add_to_regHL regBC

			# regA = fixモード時の寿命(兼余命)
			lr35902_set_reg regA $BINBIO_CELL_EVAL_HELLO_LIFE_ON_FIX

			# life_duration = regA, regHL++
			lr35902_copyinc_to_ptrHL_from_regA

			# life_left = regA
			lr35902_copy_to_from ptrHL regA

			# regA = 適応度の最大値
			lr35902_set_reg regA $BINBIO_CELL_MAX_FITNESS

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_cell_eval_hello.eq.o
		local sz_eq=$(stat -c '%s' src/f_binbio_cell_eval_hello.eq.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_eq)
		cat src/f_binbio_cell_eval_hello.eq.o

		# regA(tile_num) > 対象のタイル番号 の場合

		# regA = 最大距離 - (tile_num - 対象のタイル番号)
		## regA(tile_num) -= 対象のタイル番号
		lr35902_sub_to_regA $target_tile_num
		## regB = regA
		lr35902_copy_to_from regB regA
		## regA = 最大距離
		lr35902_set_reg regA $BINBIO_CELL_EVAL_HELLO_MAX_ALPHA_DIS
		## regA -= regB
		lr35902_sub_to_regA regB

		# regA *= 5
		## regB = regA
		lr35902_copy_to_from regB regA
		## regA <<= 2 (regA *= 4)
		lr35902_shift_left_arithmetic regA
		lr35902_shift_left_arithmetic regA
		## regA += regB
		lr35902_add_to_regA regB

		# regA += 適応度のベース値
		lr35902_add_to_regA $BINBIO_CELL_EVAL_BASE_FITNESS

		# pop & return
		lr35902_pop_reg regDE
		lr35902_pop_reg regBC
		lr35902_pop_reg regHL
		lr35902_return
	}

	# regA < 4 ? (0 <= tile_x <= 3 は'H')
	lr35902_compare_regA_and 04
	(
		# regA < 4 の場合

		# タイル'H'との近さに応じた適応度を返す
		_binbio_cell_eval_hello_ret_distance 'H'
	) >src/f_binbio_cell_eval_hello.h.o
	local sz_h=$(stat -c '%s' src/f_binbio_cell_eval_hello.h.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_h)
	cat src/f_binbio_cell_eval_hello.h.o

	# regA < 8 ? (4 <= tile_x <= 7 は'E')
	lr35902_compare_regA_and 08
	(
		# regA < 8 の場合

		# タイル'E'との近さに応じた適応度を返す
		_binbio_cell_eval_hello_ret_distance 'E'
	) >src/f_binbio_cell_eval_hello.e.o
	local sz_e=$(stat -c '%s' src/f_binbio_cell_eval_hello.e.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_e)
	cat src/f_binbio_cell_eval_hello.e.o

	# regA < 16 ? (8 <= tile_x <= 15 は'L')
	lr35902_compare_regA_and 10
	(
		# regA < 16 の場合

		# タイル'L'との近さに応じた適応度を返す
		_binbio_cell_eval_hello_ret_distance 'L'
	) >src/f_binbio_cell_eval_hello.l.o
	local sz_l=$(stat -c '%s' src/f_binbio_cell_eval_hello.l.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_l)
	cat src/f_binbio_cell_eval_hello.l.o

	# regA >= 16 の場合 (16 <= tile_x <= 19 は'O')

	# タイル'O'との近さに応じた適応度を返す
	_binbio_cell_eval_hello_ret_distance 'O'
}

# 評価の実装 - デイジーワールド実験用
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval_hello >src/f_binbio_cell_eval_hello.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_eval_hello.o))
fadr=$(calc16 "${a_binbio_cell_eval_hello}+${fsz}")
a_binbio_cell_eval_daisyworld=$(four_digits $fadr)
echo -e "a_binbio_cell_eval_daisyworld=$a_binbio_cell_eval_daisyworld" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 評価の実装 - 固定値を返す
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval_daisyworld >src/f_binbio_cell_eval_daisyworld.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_eval_daisyworld.o))
fadr=$(calc16 "${a_binbio_cell_eval_daisyworld}+${fsz}")
a_binbio_cell_eval_fixedval=$(four_digits $fadr)
echo -e "a_binbio_cell_eval_fixedval=$a_binbio_cell_eval_fixedval" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 捕食者用評価関数
f_binbio_cell_eval_fixedval >src/f_binbio_cell_eval_fixedval.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_eval_fixedval.o))
fadr=$(calc16 "${a_binbio_cell_eval_fixedval}+${fsz}")
a_binbio_cell_eval_predator=$(four_digits $fadr)
echo -e "a_binbio_cell_eval_predator=$a_binbio_cell_eval_predator" >>$MAP_FILE_NAME
## 定義はsrc/species_predator.shにある

# 現在の細胞を評価する
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval_predator >src/f_binbio_cell_eval_predator.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_eval_predator.o))
fadr=$(calc16 "${a_binbio_cell_eval_predator}+${fsz}")
a_binbio_cell_eval=$(four_digits $fadr)
echo -e "a_binbio_cell_eval=$a_binbio_cell_eval" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 細胞の「代謝/運動」の振る舞い
f_binbio_cell_eval >src/f_binbio_cell_eval.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_eval.o))
fadr=$(calc16 "${a_binbio_cell_eval}+${fsz}")
a_binbio_cell_metabolism_and_motion=$(four_digits $fadr)
echo -e "a_binbio_cell_metabolism_and_motion=$a_binbio_cell_metabolism_and_motion" >>$MAP_FILE_NAME
f_binbio_cell_metabolism_and_motion() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 実行
	## 現在の細胞のbin_dataのbin_size分のバイナリをBIN_LOAD_ADDRへロード
	### 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA
	### アドレスregHLをbin_sizeまで進める
	lr35902_set_reg regBC 0007
	lr35902_add_to_regHL regBC
	### bin_sizeをregAへ取得し、アドレスregHLをbin_dataまで進める
	lr35902_copyinc_to_regA_from_ptrHL
	### regAをregDへコピー
	lr35902_copy_to_from regD regA
	### regBCへBIN_LOAD_ADDRを設定
	lr35902_set_reg regBC $BINBIO_BIN_LOAD_ADDR
	### bin_dataのバイナリをBIN_LOAD_ADDRへロード
	(
		# bin_dataから1バイト取得しつつアドレスを進める
		lr35902_copyinc_to_regA_from_ptrHL

		# 取得した1バイトをBIN_LOAD_ADDRへロードしアドレスを進める
		lr35902_copy_to_from ptrBC regA
		lr35902_inc regBC

		# regD(bin_size)をデクリメント
		lr35902_dec regD
	) >src/f_binbio_cell_metabolism_and_motion.1.o
	cat src/f_binbio_cell_metabolism_and_motion.1.o
	local sz_1=$(stat -c '%s' src/f_binbio_cell_metabolism_and_motion.1.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_1 + 2)))
	## ロードした最終アドレス+1の位置にreturn命令を配置
	lr35902_set_reg regA c9
	lr35902_copy_to_from ptrBC regA
	## BIN_LOAD_ADDRを関数呼び出し
	## ※ デイジーワールドの実験セットの細胞の命令列ではHLが破壊される
	lr35902_call $BINBIO_BIN_LOAD_ADDR

	# 評価
	## 評価関数(eval)を呼び出す
	lr35902_call $a_binbio_cell_eval
	## 得られた適応度を細胞へ設定
	### 得られた適応度をregDへコピーしておく
	lr35902_copy_to_from regD regA
	### 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA
	### アドレスregHLをfitnessまで進める
	lr35902_set_reg regBC 0005
	lr35902_add_to_regHL regBC
	### 現在の細胞のfitnessへ得られた適応度を設定
	lr35902_copy_to_from ptrHL regD

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# コード化合物取得の実装 - タイル番号は細胞として存在するどれかのタイルを返す
# 返して価値のある値は以下の通り
# A. タイル番号以外:
#    0x 3e cd a_binbio_cell_set_tile_num(下位8ビット) a_binbio_cell_set_tile_num(上位8ビット)
# B. タイル番号:
#    0x 01〜8b (139種)
# out: regA - 取得したコード化合物
# ※ フラグレジスタは破壊される
f_binbio_cell_metabolism_and_motion >src/f_binbio_cell_metabolism_and_motion.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_metabolism_and_motion.o))
fadr=$(calc16 "${a_binbio_cell_metabolism_and_motion}+${fsz}")
a_binbio_get_code_comp_all=$(four_digits $fadr)
echo -e "a_binbio_get_code_comp_all=$a_binbio_get_code_comp_all" >>$MAP_FILE_NAME
f_binbio_get_code_comp_all() {
	# push
	lr35902_push_reg regHL

	# 現在のカウンタ/アドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_get_code_comp_all_counter_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_get_code_comp_all_counter_addr_th
	lr35902_copy_to_from regH regA

	# regHLはカウンタか?アドレスか?
	# アドレス(タイルミラーアドレス)の場合、
	# 上位8ビットは0xdc(少なくとも0ではない)
	lr35902_copy_to_from regA regH
	lr35902_compare_regA_and 00
	(
		# カウンタの場合

		# regA = regL
		lr35902_copy_to_from regA regL

		# 繰り返し生成する処理をマクロ化
		# カウントに対応する値を返す
		_binbio_get_code_comp_all_macro() {
			local count=$1
			local val=$2

			# regA == count ?
			lr35902_compare_regA_and $count

			# 違うなら8バイト分飛ばす
			lr35902_rel_jump_with_cond NZ $(two_digits_d 8)

			# regA == count の場合の処理(計8バイト)
			## regA++
			lr35902_inc regA	# 1
			## カウンタ/アドレス変数(下位8ビット) = regA
			lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_bh	# 3
			## regA = val
			lr35902_set_reg regA $val	# 2
			## pop & return
			lr35902_pop_reg regHL	# 1
			lr35902_return	# 1
		}

		# マクロを使用して処理を生成
		_binbio_get_code_comp_all_macro 00 3e
		_binbio_get_code_comp_all_macro 01 cd
		_binbio_get_code_comp_all_macro 02 $(echo $a_binbio_cell_set_tile_num | cut -c3-4)

		# regA == 3 の場合は少し処理が異なる
		# (カウンタ/アドレス変数の更新値が異なる)
		# ※ カウンタであり前述のいずれの条件にも合致しなかった時点で
		# 　 regA == 3であると判断する
		## カウンタ/アドレス変数 = タイルミラー領域ベースアドレス
		lr35902_set_reg regA $GBOS_TMRR_BASE_BH
		lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_bh
		lr35902_set_reg regA $GBOS_TMRR_BASE_TH
		lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_th
		## regA = a_binbio_cell_set_tile_num(上位8ビット)
		lr35902_set_reg regA $(echo $a_binbio_cell_set_tile_num | cut -c1-2)
		## pop & return
		lr35902_pop_reg regHL
		lr35902_return
	) >src/f_binbio_get_code_comp_all.1.o
	local sz_1=$(stat -c '%s' src/f_binbio_get_code_comp_all.1.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
	cat src/f_binbio_get_code_comp_all.1.o

	# アドレスの場合

	# push
	lr35902_push_reg regBC

	# 変数が示すアドレスを起点にアドレスをインクリメントしながら
	# 0x00以外のタイル値を探す
	(
		# アドレスregHLの値 != 0x00 ?
		lr35902_copy_to_from regA ptrHL
		lr35902_compare_regA_and 00
		(
			# アドレスregHLの値 != 0x00 の場合

			# regBへregAを退避
			lr35902_copy_to_from regB regA

			# regHL++
			lr35902_inc regHL

			# regHL == タイルミラー領域最終アドレス+1 ?
			lr35902_copy_to_from regA regH
			lr35902_compare_regA_and $GBOS_TMRR_END_PLUS1_TH
			(
				# regHL == タイルミラー領域最終アドレス+1 の場合

				# カウンタ/アドレス変数 = 0x0000
				lr35902_xor_to_regA regA
				lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_bh
				lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_th
			) >src/f_binbio_get_code_comp_all.2.o
			(
				# regHL != タイルミラー領域最終アドレス+1 の場合

				# カウンタ/アドレス変数 = regHL
				lr35902_copy_to_from regA regL
				lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_bh
				lr35902_copy_to_from regA regH
				lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_th

				# regHL == タイルミラー領域最終アドレス+1 の場合の処理を飛ばす
				local sz_2=$(stat -c '%s' src/f_binbio_get_code_comp_all.2.o)
				lr35902_rel_jump $(two_digits_d $sz_2)
			) >src/f_binbio_get_code_comp_all.6.o
			local sz_6=$(stat -c '%s' src/f_binbio_get_code_comp_all.6.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_6)
			cat src/f_binbio_get_code_comp_all.6.o	# regHL != タイルミラー領域最終アドレス+1 の場合
			cat src/f_binbio_get_code_comp_all.2.o	# regHL == タイルミラー領域最終アドレス+1 の場合

			# regAをregBから復帰
			lr35902_copy_to_from regA regB

			# pop & return
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_get_code_comp_all.3.o
		local sz_3=$(stat -c '%s' src/f_binbio_get_code_comp_all.3.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_3)
		cat src/f_binbio_get_code_comp_all.3.o

		# アドレスregHLの値 == 0x00 の場合

		# regHL++
		lr35902_inc regHL

		# regHL == タイルミラー領域最終アドレス+1 ?
		lr35902_copy_to_from regA regH
		lr35902_compare_regA_and $GBOS_TMRR_END_PLUS1_TH
		(
			# regHL == タイルミラー領域最終アドレス+1 の場合

			# ループを脱出
			lr35902_rel_jump $(two_digits_d 2)
		) >src/f_binbio_get_code_comp_all.4.o
		local sz_4=$(stat -c '%s' src/f_binbio_get_code_comp_all.4.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
		cat src/f_binbio_get_code_comp_all.4.o
	) >src/f_binbio_get_code_comp_all.5.o
	cat src/f_binbio_get_code_comp_all.5.o
	local sz_5=$(stat -c '%s' src/f_binbio_get_code_comp_all.5.o)
	lr35902_rel_jump $(two_comp_d $((sz_5 + 2)))	# 2

	# 0x00以外のタイル番号が見つからないまま
	# regHL == タイルミラー領域最終アドレス+1 まで来てしまった場合

	# カウンタ/アドレス変数 = 0x0000
	lr35902_xor_to_regA regA
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_bh
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_th

	# regA = 細胞タイルのタイル値
	lr35902_set_reg regA $GBOS_TILE_NUM_CELL

	# pop & return
	lr35902_pop_reg regBC
	lr35902_pop_reg regHL
	lr35902_return
}

# コード化合物取得の実装 - "hello"の各文字の領域ではそれぞれの文字が取得しやすい
# out: regA - 取得したコード化合物
# ※ フラグレジスタは破壊される
f_binbio_get_code_comp_all >src/f_binbio_get_code_comp_all.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_get_code_comp_all.o))
fadr=$(calc16 "${a_binbio_get_code_comp_all}+${fsz}")
a_binbio_get_code_comp_hello=$(four_digits $fadr)
echo -e "a_binbio_get_code_comp_hello=$a_binbio_get_code_comp_hello" >>$MAP_FILE_NAME
f_binbio_get_code_comp_hello() {
	# regA = カウンタ変数
	lr35902_copy_to_regA_from_addr $var_binbio_get_code_comp_hello_counter

	# 繰り返し使用する処理をマクロ定義
	## regA < 第1引数 なら、カウンタ変数値をインクリメントし、第2引数を返す
	_binbio_get_code_comp_hello_if_regA_lt_inc_counter_ret_val() {
		local sz

		# regA < 第1引数 ?
		lr35902_compare_regA_and $1
		(
			# regA < 第1引数 の場合

			# カウンタ変数値をインクリメント
			lr35902_inc regA
			lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_counter

			# 第2引数を返す
			lr35902_set_reg regA $2
			lr35902_return
		) >src/f_binbio_get_code_comp_hello.iir.o
		sz=$(stat -c '%s' src/f_binbio_get_code_comp_hello.iir.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz)
		cat src/f_binbio_get_code_comp_hello.iir.o
	}

	# 0 <= regA <= 3 では、bin_dataを構成するコード化合物のタイル番号以外を返す
	# 即ち、カウンタの値に応じて
	# 0x 3e cd a_binbio_cell_set_tile_num(下位8ビット) a_binbio_cell_set_tile_num(上位8ビット)
	# のいずれかを返す
	## regA < 1 なら、カウンタ変数値をインクリメントし、0x3eを返す
	_binbio_get_code_comp_hello_if_regA_lt_inc_counter_ret_val 01 3e
	## regA < 2 なら、カウンタ変数値をインクリメントし、0xcdを返す
	_binbio_get_code_comp_hello_if_regA_lt_inc_counter_ret_val 02 cd
	## regA < 3 なら、カウンタ変数値をインクリメントし、a_binbio_cell_set_tile_num(下位8ビット)を返す
	_binbio_get_code_comp_hello_if_regA_lt_inc_counter_ret_val 03 $(echo $a_binbio_cell_set_tile_num | cut -c3-4)
	## regA < 4 なら、カウンタ変数値をインクリメントし、a_binbio_cell_set_tile_num(上位8ビット)を返す
	_binbio_get_code_comp_hello_if_regA_lt_inc_counter_ret_val 04 $(echo $a_binbio_cell_set_tile_num | cut -c1-2)

	# regA < 5 ?
	lr35902_compare_regA_and 05
	(
		# regA < 5 の場合
		# tile_xに応じて"hello"を構成する文字タイルのいずれかを返す

		# push
		lr35902_push_reg regHL

		# カウンタ変数をインクリメントした値で更新
		lr35902_inc regA
		lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_counter

		# 現在の細胞のアドレスをregHLへ取得
		lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
		lr35902_copy_to_from regL regA
		lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
		lr35902_copy_to_from regH regA

		# アドレスregHLをtile_xまで進める
		lr35902_inc regHL

		# regA = tile_x
		lr35902_copy_to_from regA ptrHL

		# regA < 4 ? (0 <= tile_x <= 3 は'H')
		lr35902_compare_regA_and 04
		(
			# regA < 4 の場合

			# regA = 'H'のタイル番号
			lr35902_set_reg regA $(get_alpha_tile_num 'H')

			# pop & return
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_get_code_comp_hello.h.o
		local sz_h=$(stat -c '%s' src/f_binbio_get_code_comp_hello.h.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_h)
		cat src/f_binbio_get_code_comp_hello.h.o

		# regA < 8 ? (4 <= tile_x <= 7 は'E')
		lr35902_compare_regA_and 08
		(
			# regA < 8 の場合

			# regA = 'E'のタイル番号
			lr35902_set_reg regA $(get_alpha_tile_num 'E')

			# pop & return
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_get_code_comp_hello.e.o
		local sz_e=$(stat -c '%s' src/f_binbio_get_code_comp_hello.e.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_e)
		cat src/f_binbio_get_code_comp_hello.e.o

		# regA < 16 ? (8 <= tile_x <= 15 は'L')
		lr35902_compare_regA_and 10
		(
			# regA < 16 の場合

			# regA = 'L'のタイル番号
			lr35902_set_reg regA $(get_alpha_tile_num 'L')

			# pop & return
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_get_code_comp_hello.l.o
		local sz_l=$(stat -c '%s' src/f_binbio_get_code_comp_hello.l.o)
		lr35902_rel_jump_with_cond NC $(two_digits_d $sz_l)
		cat src/f_binbio_get_code_comp_hello.l.o

		# regA >= 16 の場合 (16 <= tile_x <= 19 は'O')

		# regA = 'O'のタイル番号
		lr35902_set_reg regA $(get_alpha_tile_num 'O')

		# pop & return
		lr35902_pop_reg regHL
		lr35902_return
	) >src/f_binbio_get_code_comp_hello.hello.o
	local sz_hello=$(stat -c '%s' src/f_binbio_get_code_comp_hello.hello.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_hello)
	cat src/f_binbio_get_code_comp_hello.hello.o

	# 5 <= regA <= 8 では、bin_dataを構成するコード化合物のタイル番号以外を返す
	# 即ち、カウンタの値に応じて
	# 0x 3e cd a_binbio_cell_set_tile_num(下位8ビット) a_binbio_cell_set_tile_num(上位8ビット)
	# のいずれかを返す
	## regA < 6 なら、カウンタ変数値をインクリメントし、0x3eを返す
	_binbio_get_code_comp_hello_if_regA_lt_inc_counter_ret_val 06 3e
	## regA < 7 なら、カウンタ変数値をインクリメントし、0xcdを返す
	_binbio_get_code_comp_hello_if_regA_lt_inc_counter_ret_val 07 cd
	## regA < 8 なら、カウンタ変数値をインクリメントし、a_binbio_cell_set_tile_num(下位8ビット)を返す
	_binbio_get_code_comp_hello_if_regA_lt_inc_counter_ret_val 08 $(echo $a_binbio_cell_set_tile_num | cut -c3-4)
	## regA < 9 なら、カウンタ変数値をインクリメントし、a_binbio_cell_set_tile_num(上位8ビット)を返す
	_binbio_get_code_comp_hello_if_regA_lt_inc_counter_ret_val 09 $(echo $a_binbio_cell_set_tile_num | cut -c1-2)

	# regA >= 9 の場合

	# push
	lr35902_push_reg regHL

	# カウンタ変数を0で更新
	lr35902_clear_reg regA
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_counter

	# regHL = アドレス変数の値
	lr35902_copy_to_regA_from_addr $var_binbio_get_code_comp_hello_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_get_code_comp_hello_addr_th
	lr35902_copy_to_from regH regA

	# アドレスregHLを起点に0x00でない値を探す
	(
		# regA = ptrHL
		lr35902_copy_to_from regA ptrHL

		# regA != 0x00 ?
		lr35902_compare_regA_and 00
		(
			# regA != 0x00 の場合

			# push
			lr35902_push_reg regBC

			# regAをregBへ退避
			lr35902_copy_to_from regB regA

			# regHL++
			lr35902_inc regHL

			# アドレスregHLがタイルミラー領域を出たか?
			lr35902_copy_to_from regA regH
			lr35902_compare_regA_and $GBOS_TMRR_END_PLUS1_TH
			(
				# アドレスregHLがタイルミラー領域を出た場合

				# アドレス変数へタイルミラー領域ベースアドレスを設定
				lr35902_set_reg regA $GBOS_TMRR_BASE_BH
				lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_addr_bh
				lr35902_set_reg regA $GBOS_TMRR_BASE_TH
				lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_addr_th

				# regAをregBから復帰
				lr35902_copy_to_from regA regB

				# pop & return
				lr35902_pop_reg regBC
				lr35902_pop_reg regHL
				lr35902_return
			) >src/f_binbio_get_code_comp_hello.oom.o
			local sz_oom=$(stat -c '%s' src/f_binbio_get_code_comp_hello.oom.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_oom)
			cat src/f_binbio_get_code_comp_hello.oom.o

			# アドレス変数へregHLを設定
			lr35902_copy_to_from regA regL
			lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_addr_bh
			lr35902_copy_to_from regA regH
			lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_addr_th

			# regAをregBから復帰
			lr35902_copy_to_from regA regB

			# pop & return
			lr35902_pop_reg regBC
			lr35902_pop_reg regHL
			lr35902_return
		) >src/f_binbio_get_code_comp_hello.found.o
		local sz_found=$(stat -c '%s' src/f_binbio_get_code_comp_hello.found.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_found)
		cat src/f_binbio_get_code_comp_hello.found.o

		# regHL++
		lr35902_inc regHL

		# アドレスregHLがタイルミラー領域を出たか?
		lr35902_copy_to_from regA regH
		lr35902_compare_regA_and $GBOS_TMRR_END_PLUS1_TH
		(
			# アドレスregHLがタイルミラー領域を出た場合

			# regHLへタイルミラー領域ベースアドレスを設定
			lr35902_set_reg regHL $GBOS_TMRR_BASE
		) >src/f_binbio_get_code_comp_hello.oom2.o
		local sz_oom2=$(stat -c '%s' src/f_binbio_get_code_comp_hello.oom2.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_oom2)
		cat src/f_binbio_get_code_comp_hello.oom2.o
	) >src/f_binbio_get_code_comp_hello.loop.o
	cat src/f_binbio_get_code_comp_hello.loop.o
	local sz_loop=$(stat -c '%s' src/f_binbio_get_code_comp_hello.loop.o)
	lr35902_rel_jump $(two_comp_d $((sz_loop + 2)))
}

# コード化合物取得
# out: regA - 取得したコード化合物
# ※ フラグレジスタは破壊される
f_binbio_get_code_comp_hello >src/f_binbio_get_code_comp_hello.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_get_code_comp_hello.o))
fadr=$(calc16 "${a_binbio_get_code_comp_hello}+${fsz}")
a_binbio_get_code_comp=$(four_digits $fadr)
echo -e "a_binbio_get_code_comp=$a_binbio_get_code_comp" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 白/黒デイジー用の成長関数
# in  : regHL - 現在の細胞のfitnessのアドレス
f_binbio_get_code_comp >src/f_binbio_get_code_comp.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_get_code_comp.o))
fadr=$(calc16 "${a_binbio_get_code_comp}+${fsz}")
a_binbio_cell_growth_daisy=$(four_digits $fadr)
echo -e "a_binbio_cell_growth_daisy=$a_binbio_cell_growth_daisy" >>$MAP_FILE_NAME
## 定義はsrc/expset_daisyworld.shにある

# 捕食者用成長関数用の捕食処理
f_binbio_cell_growth_daisy >src/f_binbio_cell_growth_daisy.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_growth_daisy.o))
fadr=$(calc16 "${a_binbio_cell_growth_daisy}+${fsz}")
a_binbio_cell_growth_predator_prey=$(four_digits $fadr)
echo -e "a_binbio_cell_growth_predator_prey=$a_binbio_cell_growth_predator_prey" >>$MAP_FILE_NAME
## 定義はsrc/species_predator.shにある

# 捕食者用成長関数用の確認&捕食処理
f_binbio_cell_growth_predator_prey >src/f_binbio_cell_growth_predator_prey.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_growth_predator_prey.o))
fadr=$(calc16 "${a_binbio_cell_growth_predator_prey}+${fsz}")
a_binbio_cell_growth_predator_check_and_prey=$(four_digits $fadr)
echo -e "a_binbio_cell_growth_predator_check_and_prey=$a_binbio_cell_growth_predator_check_and_prey" >>$MAP_FILE_NAME
## 定義はsrc/species_predator.shにある

# 捕食者用成長関数
f_binbio_cell_growth_predator_check_and_prey >src/f_binbio_cell_growth_predator_check_and_prey.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_growth_predator_check_and_prey.o))
fadr=$(calc16 "${a_binbio_cell_growth_predator_check_and_prey}+${fsz}")
a_binbio_cell_growth_predator=$(four_digits $fadr)
echo -e "a_binbio_cell_growth_predator=$a_binbio_cell_growth_predator" >>$MAP_FILE_NAME
## 定義はsrc/species_predator.shにある

# 細胞の「成長」の振る舞い
f_binbio_cell_growth_predator >src/f_binbio_cell_growth_predator.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_growth_predator.o))
fadr=$(calc16 "${a_binbio_cell_growth_predator}+${fsz}")
a_binbio_cell_growth=$(four_digits $fadr)
echo -e "a_binbio_cell_growth=$a_binbio_cell_growth" >>$MAP_FILE_NAME
f_binbio_cell_growth() {
	# push
	lr35902_push_reg regAF

	# regAへ現在の細胞のtile_numを取得
	cat src/expset_daisyworld.get_current_cell_tile_num.o

	# 繰り返し使用する処理をファイル書き出し
	## pop & return
	(
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_growth.pop_and_return.o
	local sz_pop_and_return=$(stat -c '%s' src/f_binbio_cell_growth.pop_and_return.o)
	## デイジーワールドの成長関数を呼び出してreturn
	(
		# 成長関数呼び出し
		lr35902_call $a_binbio_cell_growth_daisy

		# pop & return
		cat src/f_binbio_cell_growth.pop_and_return.o
	) >src/f_binbio_cell_growth.daisy.o
	local sz_daisy=$(stat -c '%s' src/f_binbio_cell_growth.daisy.o)

	# regA == 白デイジー ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_WHITE
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisy)
	cat src/f_binbio_cell_growth.daisy.o

	# regA == 黒デイジー ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_BLACK
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisy)
	cat src/f_binbio_cell_growth.daisy.o

	# regA == 捕食者 ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_PREDATOR
	(
		# 成長関数呼び出し
		lr35902_call $a_binbio_cell_growth_predator

		# pop & return
		cat src/f_binbio_cell_growth.pop_and_return.o
	) >src/f_binbio_cell_growth.predator.o
	local sz_predator=$(stat -c '%s' src/f_binbio_cell_growth.predator.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_predator)
	cat src/f_binbio_cell_growth.predator.o

	# INSERT_f_binbio_cell_growth

	# regAがその他の値の場合(現状、このパスには来ないはず)
	# もしこのパスに来るようであれば無限ループで止める
	infinite_halt

	# pop & return
	cat src/f_binbio_cell_growth.pop_and_return.o
}

# 分裂可能か？
# out: regA - 分裂可能なら1、そうでないなら0
f_binbio_cell_growth >src/f_binbio_cell_growth.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_growth.o))
fadr=$(calc16 "${a_binbio_cell_growth}+${fsz}")
a_binbio_cell_is_dividable=$(four_digits $fadr)
echo -e "a_binbio_cell_is_dividable=$a_binbio_cell_is_dividable" >>$MAP_FILE_NAME
f_binbio_cell_is_dividable() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# regHLへ現在の細胞のアドレスを設定する
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# regHLのアドレスをcollected_flagsまで進める
	lr35902_set_reg regBC 000d
	lr35902_add_to_regHL regBC

	# collected_flagsをregDへ取得
	lr35902_copy_to_from regD ptrHL

	# regHLのアドレスをbin_sizeまで戻す
	lr35902_set_reg regBC $(two_comp_4 6)
	lr35902_add_to_regHL regBC

	# bin_sizeをregBへ取得
	lr35902_copy_to_from regB ptrHL

	# regAをゼロクリア
	lr35902_xor_to_regA regA

	# regBの数だけregAの下位からビットを立てていく
	(
		# regAを1ビット左ローテート
		lr35902_rot_regA_left_th_carry

		# regAをインクリメント(LSBをセットする)
		lr35902_inc regA

		# regBをデクリメント
		lr35902_dec regB
	) >src/f_binbio_cell_is_dividable.1.o
	cat src/f_binbio_cell_is_dividable.1.o
	local sz_1=$(stat -c '%s' src/f_binbio_cell_is_dividable.1.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_1 + 2)))

	# regD == regA ?
	lr35902_compare_regA_and regD
	(
		# regD != regA の場合

		# pop
		lr35902_pop_reg regHL
		lr35902_pop_reg regDE
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF

		# regAをゼロクリア
		# (フラグを変化させないためにXOR命令は使わない)
		lr35902_set_reg regA 00

		# return
		lr35902_return
	) >src/f_binbio_cell_is_dividable.2.o
	local sz_2=$(stat -c '%s' src/f_binbio_cell_is_dividable.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
	cat src/f_binbio_cell_is_dividable.2.o

	# regD == regA の場合

	# pop
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF

	# regAへ1を設定
	lr35902_set_reg regA 01

	# return
	lr35902_return
}

# 細胞データ領域をゼロクリア
f_binbio_cell_is_dividable >src/f_binbio_cell_is_dividable.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_is_dividable.o))
fadr=$(calc16 "${a_binbio_cell_is_dividable}+${fsz}")
a_binbio_clear_cell_data_area=$(four_digits $fadr)
echo -e "a_binbio_clear_cell_data_area=$a_binbio_clear_cell_data_area" >>$MAP_FILE_NAME
f_binbio_clear_cell_data_area() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# 細胞データ領域の最初のアドレスをregHLへ設定
	lr35902_set_reg regHL $BINBIO_CELL_DATA_AREA_BEGIN

	# 細胞データ領域のサイズをregBCへ設定
	lr35902_set_reg regBC $BINBIO_CELL_DATA_AREA_SIZE

	# 細胞データ領域を0x00で上書き
	(
		# regAへ0x00を設定
		lr35902_xor_to_regA regA

		# ptrHL = regA, regHL++
		lr35902_copyinc_to_ptrHL_from_regA

		# regBCをデクリメント
		lr35902_dec regBC

		# regBC == 0 ?
		## regA |= regB | regC
		lr35902_or_to_regA regB
		lr35902_or_to_regA regC
		## regA == 0 ?
		lr35902_compare_regA_and 00
	) >src/f_binbio_clear_cell_data_area.1.o
	cat src/f_binbio_clear_cell_data_area.1.o
	local sz_1=$(stat -c '%s' src/f_binbio_clear_cell_data_area.1.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_1 + 2)))

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# マウスカーソルが指す細胞のアドレスを返す
# out: regHL - 細胞アドレス(マウスカーソルが指す座標に細胞が存在しない場合はNULL)
f_binbio_clear_cell_data_area >src/f_binbio_clear_cell_data_area.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_clear_cell_data_area.o))
fadr=$(calc16 "${a_binbio_clear_cell_data_area}+${fsz}")
a_binbio_get_pointed_cell_addr=$(four_digits $fadr)
echo -e "a_binbio_get_pointed_cell_addr=$a_binbio_get_pointed_cell_addr" >>$MAP_FILE_NAME
f_binbio_get_pointed_cell_addr() {
	# push
	lr35902_push_reg regDE

	# 現在のマウスカーソルが指すタイル座標を取得
	lr35902_call $a_get_mouse_tcoord

	# TODO マウスカーソルが指すタイル座標が細胞表示領域内かのチェックを入れる

	# マウスカーソルが指すタイル座標の細胞のアドレスを取得
	lr35902_call $a_binbio_find_cell_data_by_tile_xy

	# pop & return
	lr35902_pop_reg regDE
	lr35902_return
}

# 近傍の空き座標を探す
# out: regD - 見つけたY座標(見つからなかった場合は0xff)
#      regE - 見つけたX座標(見つからなかった場合は0xff)
f_binbio_get_pointed_cell_addr >src/f_binbio_get_pointed_cell_addr.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_get_pointed_cell_addr.o))
fadr=$(calc16 "${a_binbio_get_pointed_cell_addr}+${fsz}")
a_binbio_cell_find_free_neighbor=$(four_digits $fadr)
echo -e "a_binbio_cell_find_free_neighbor=$a_binbio_cell_find_free_neighbor" >>$MAP_FILE_NAME
f_binbio_cell_find_free_neighbor() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# cur_cell_addrから現在の細胞データを参照しtile_x・tile_yを取得
	## 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA
	## tile_xをregEへ取得
	lr35902_inc regHL
	lr35902_copy_to_from regE ptrHL
	## tile_yをregDへ取得
	lr35902_inc regHL
	lr35902_copy_to_from regD ptrHL

	# 現在の細胞の8近傍を左上から順に時計回りでチェック

	# 現在の細胞のタイルのタイルミラー領域上のアドレスをregHLへ設定
	lr35902_call $a_tcoord_to_mrraddr

	# regD(tile_y) == $BINBIO_CELL_DISP_AREA_STY ?
	lr35902_copy_to_from regA regD
	lr35902_compare_regA_and $BINBIO_CELL_DISP_AREA_STY
	(
		# tile_y != $BINBIO_CELL_DISP_AREA_STY の場合

		# regE(tile_x) == $BINBIO_CELL_DISP_AREA_STX ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and $BINBIO_CELL_DISP_AREA_STX
		(
			# tile_x != $BINBIO_CELL_DISP_AREA_STX の場合

			# 左上座標は空か?
			## アドレスregHLへ左上座標のアドレスを設定
			lr35902_set_reg regBC $(two_comp_4 21)
			lr35902_add_to_regHL regBC
			## 空(0x00)か?
			lr35902_copy_to_from regA ptrHL
			lr35902_compare_regA_and $GBOS_TILE_NUM_SPC
			(
				# 空の場合

				# (regE, regD)へ左上座標を設定
				## regE--
				lr35902_dec regE
				## regD--
				lr35902_dec regD

				# pop & return
				lr35902_pop_reg regHL
				lr35902_pop_reg regBC
				lr35902_pop_reg regAF
				lr35902_return
			) >src/f_binbio_cell_find_free_neighbor.1.o
			local sz_1=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.1.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
			cat src/f_binbio_cell_find_free_neighbor.1.o
			## アドレスregHLへ現在の細胞のタイル座標アドレスを設定
			lr35902_set_reg regBC 0021
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_find_free_neighbor.2.o
		local sz_2=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.2.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
		cat src/f_binbio_cell_find_free_neighbor.2.o

		# 上座標は空か?
		## アドレスregHLへ上座標のアドレスを設定
		lr35902_set_reg regBC $(two_comp_4 20)
		lr35902_add_to_regHL regBC
		## 空(0x00)か?
		lr35902_copy_to_from regA ptrHL
		lr35902_compare_regA_and $GBOS_TILE_NUM_SPC
		(
			# 空の場合

			# (regE, regD)へ上座標を設定
			## regD--
			lr35902_dec regD

			# pop & return
			lr35902_pop_reg regHL
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF
			lr35902_return
		) >src/f_binbio_cell_find_free_neighbor.3.o
		local sz_3=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.3.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
		cat src/f_binbio_cell_find_free_neighbor.3.o
		## アドレスregHLへ現在の細胞のタイル座標アドレスを設定
		lr35902_set_reg regBC 0020
		lr35902_add_to_regHL regBC

		# regE(tile_x) == $BINBIO_CELL_DISP_AREA_ETX ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and $BINBIO_CELL_DISP_AREA_ETX
		(
			# tile_x != $BINBIO_CELL_DISP_AREA_ETX の場合

			# 右上座標は空か?
			## アドレスregHLへ右上座標のアドレスを設定
			lr35902_set_reg regBC $(two_comp_4 1f)
			lr35902_add_to_regHL regBC
			## 空(0x00)か?
			lr35902_copy_to_from regA ptrHL
			lr35902_compare_regA_and $GBOS_TILE_NUM_SPC
			(
				# 空の場合

				# (regE, regD)へ右上座標を設定
				## regE++
				lr35902_inc regE
				## regD--
				lr35902_dec regD

				# pop & return
				lr35902_pop_reg regHL
				lr35902_pop_reg regBC
				lr35902_pop_reg regAF
				lr35902_return
			) >src/f_binbio_cell_find_free_neighbor.4.o
			local sz_4=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.4.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
			cat src/f_binbio_cell_find_free_neighbor.4.o
			## アドレスregHLへ現在の細胞のタイル座標アドレスを設定
			lr35902_set_reg regBC 001f
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_find_free_neighbor.5.o
		local sz_5=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.5.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_5)
		cat src/f_binbio_cell_find_free_neighbor.5.o
	) >src/f_binbio_cell_find_free_neighbor.6.o
	local sz_6=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.6.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_6)
	cat src/f_binbio_cell_find_free_neighbor.6.o

	# regE(tile_x) == $BINBIO_CELL_DISP_AREA_ETX ?
	lr35902_copy_to_from regA regE
	lr35902_compare_regA_and $BINBIO_CELL_DISP_AREA_ETX
	(
		# tile_x != $BINBIO_CELL_DISP_AREA_ETX の場合

		# 右座標は空か?
		## アドレスregHLへ右座標のアドレスを設定
		lr35902_inc regHL
		## 空(0x00)か?
		lr35902_copy_to_from regA ptrHL
		lr35902_compare_regA_and $GBOS_TILE_NUM_SPC
		(
			# 空の場合

			# (regE, regD)へ右座標を設定
			## regE++
			lr35902_inc regE

			# pop & return
			lr35902_pop_reg regHL
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF
			lr35902_return
		) >src/f_binbio_cell_find_free_neighbor.7.o
		local sz_7=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.7.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_7)
		cat src/f_binbio_cell_find_free_neighbor.7.o
		## アドレスregHLへ現在の細胞のタイル座標アドレスを設定
		lr35902_dec regHL
	) >src/f_binbio_cell_find_free_neighbor.8.o
	local sz_8=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.8.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_8)
	cat src/f_binbio_cell_find_free_neighbor.8.o

	# regD(tile_y) == $BINBIO_CELL_DISP_AREA_ETY ?
	lr35902_copy_to_from regA regD
	lr35902_compare_regA_and $BINBIO_CELL_DISP_AREA_ETY
	(
		# tile_y != $BINBIO_CELL_DISP_AREA_ETY の場合

		# regE(tile_x) == $BINBIO_CELL_DISP_AREA_ETX ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and $BINBIO_CELL_DISP_AREA_ETX
		(
			# tile_x != $BINBIO_CELL_DISP_AREA_ETX の場合

			# 右下座標は空か?
			## アドレスregHLへ右下座標のアドレスを設定
			lr35902_set_reg regBC 0021
			lr35902_add_to_regHL regBC
			## 空(0x00)か?
			lr35902_copy_to_from regA ptrHL
			lr35902_compare_regA_and $GBOS_TILE_NUM_SPC
			(
				# 空の場合

				# (regE, regD)へ右下座標を設定
				## regE++
				lr35902_inc regE
				## regD++
				lr35902_inc regD

				# pop & return
				lr35902_pop_reg regHL
				lr35902_pop_reg regBC
				lr35902_pop_reg regAF
				lr35902_return
			) >src/f_binbio_cell_find_free_neighbor.9.o
			local sz_9=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.9.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_9)
			cat src/f_binbio_cell_find_free_neighbor.9.o
			## アドレスregHLへ現在の細胞のタイル座標アドレスを設定
			lr35902_set_reg regBC $(two_comp_4 21)
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_find_free_neighbor.10.o
		local sz_10=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.10.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_10)
		cat src/f_binbio_cell_find_free_neighbor.10.o

		# 下座標は空か?
		## アドレスregHLへ下座標のアドレスを設定
		lr35902_set_reg regBC 0020
		lr35902_add_to_regHL regBC
		## 空(0x00)か?
		lr35902_copy_to_from regA ptrHL
		lr35902_compare_regA_and $GBOS_TILE_NUM_SPC
		(
			# 空の場合

			# (regE, regD)へ下座標を設定
			## regD++
			lr35902_inc regD

			# pop & return
			lr35902_pop_reg regHL
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF
			lr35902_return
		) >src/f_binbio_cell_find_free_neighbor.11.o
		local sz_11=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.11.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_11)
		cat src/f_binbio_cell_find_free_neighbor.11.o
		## アドレスregHLへ現在の細胞のタイル座標アドレスを設定
		lr35902_set_reg regBC $(two_comp_4 20)
		lr35902_add_to_regHL regBC

		# regE(tile_x) == $BINBIO_CELL_DISP_AREA_STX ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and $BINBIO_CELL_DISP_AREA_STX
		(
			# tile_x != $BINBIO_CELL_DISP_AREA_STX の場合

			# 左下座標は空か?
			## アドレスregHLへ左下座標のアドレスを設定
			lr35902_set_reg regBC 001f
			lr35902_add_to_regHL regBC
			## 空(0x00)か?
			lr35902_copy_to_from regA ptrHL
			lr35902_compare_regA_and $GBOS_TILE_NUM_SPC
			(
				# 空の場合

				# (regE, regD)へ左下座標を設定
				## regE--
				lr35902_dec regE
				## regD++
				lr35902_inc regD

				# pop & return
				lr35902_pop_reg regHL
				lr35902_pop_reg regBC
				lr35902_pop_reg regAF
				lr35902_return
			) >src/f_binbio_cell_find_free_neighbor.12.o
			local sz_12=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.12.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_12)
			cat src/f_binbio_cell_find_free_neighbor.12.o
			## アドレスregHLへ現在の細胞のタイル座標アドレスを設定
			lr35902_set_reg regBC $(two_comp_4 1f)
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_find_free_neighbor.13.o
		local sz_13=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.13.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_13)
		cat src/f_binbio_cell_find_free_neighbor.13.o
	) >src/f_binbio_cell_find_free_neighbor.14.o
	local sz_14=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.14.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_14)
	cat src/f_binbio_cell_find_free_neighbor.14.o

	# regE(tile_x) == $BINBIO_CELL_DISP_AREA_STX ?
	lr35902_copy_to_from regA regE
	lr35902_compare_regA_and $BINBIO_CELL_DISP_AREA_STX
	(
		# tile_x != $BINBIO_CELL_DISP_AREA_STX の場合

		# 左座標は空か?
		## アドレスregHLへ左座標のアドレスを設定
		lr35902_dec regHL
		## 空(0x00)か?
		lr35902_copy_to_from regA ptrHL
		lr35902_compare_regA_and $GBOS_TILE_NUM_SPC
		(
			# 空の場合

			# (regE, regD)へ左座標を設定
			## regE--
			lr35902_dec regE

			# pop & return
			lr35902_pop_reg regHL
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF
			lr35902_return
		) >src/f_binbio_cell_find_free_neighbor.15.o
		local sz_15=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.15.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_15)
		cat src/f_binbio_cell_find_free_neighbor.15.o
		## アドレスregHLへ現在の細胞のタイル座標アドレスを設定
		lr35902_inc regHL
	) >src/f_binbio_cell_find_free_neighbor.16.o
	local sz_16=$(stat -c '%s' src/f_binbio_cell_find_free_neighbor.16.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_16)
	cat src/f_binbio_cell_find_free_neighbor.16.o

	# (regE, regD)へ共に0xffを設定
	lr35902_set_reg regE ff
	lr35902_set_reg regD ff

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 突然変異の実装 - 全タイルのどれかへ変異
# in : regHL - 対象の細胞のアドレス
f_binbio_cell_find_free_neighbor >src/f_binbio_cell_find_free_neighbor.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_find_free_neighbor.o))
fadr=$(calc16 "${a_binbio_cell_find_free_neighbor}+${fsz}")
a_binbio_cell_mutation_all=$(four_digits $fadr)
echo -e "a_binbio_cell_mutation_all=$a_binbio_cell_mutation_all" >>$MAP_FILE_NAME
f_binbio_cell_mutation_all() {
	# push
	lr35902_push_reg regAF

	# 0x01〜0x8b(使用可能な最後のタイル番号)の間で乱数を生成
	## 0x00〜0xffの乱数生成
	lr35902_call $a_get_rnd
	## regA(生成された乱数) < 0x8b ?
	## (細胞のタイル番号として使用する値は0x01〜0x8bの139種)
	lr35902_compare_regA_and 8b
	(
		# regA >= 0x8b の場合

		# 「突然変異しなかった」として、そのままpop&return
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_mutation.1.o
	local sz_1=$(stat -c '%s' src/f_binbio_cell_mutation.1.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_1)
	cat src/f_binbio_cell_mutation.1.o
	## regAを0x01〜0x8bの値にする
	lr35902_inc regA

	# push
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# アドレスregHLをbin_dataの2バイト目(タイル番号)まで進める
	lr35902_set_reg regBC 0009
	lr35902_add_to_regHL regBC

	# ptrHLへ生成した乱数を設定
	lr35902_copy_to_from ptrHL regA

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 突然変異の実装 - アルファベットタイルの中で突然変異
# 前提：
# - 環境に存在し得るタイルの種類：
#   - 細胞タイル：0x8b
#   - アルファベットタイル：0x1e('A') 〜 0x37('Z') (26種)
# 処理概要：
# - 現在の細胞が細胞タイルの場合：
#   - アルファベットタイル番号をランダムに選出
# - 現在の細胞がアルファベットの場合：
#   - 'A'の場合：
#     - インクリメント
#   - 'B'〜'Y'の場合：
#     - インクリメントあるいはデクリメント
#     - どちらにするかはランダムに決まる
#   - 'Z'の場合：
#     - デクリメント
# in : regHL - 対象の細胞のアドレス
f_binbio_cell_mutation_all >src/f_binbio_cell_mutation_all.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_mutation_all.o))
fadr=$(calc16 "${a_binbio_cell_mutation_all}+${fsz}")
a_binbio_cell_mutation_alphabet=$(four_digits $fadr)
echo -e "a_binbio_cell_mutation_alphabet=$a_binbio_cell_mutation_alphabet" >>$MAP_FILE_NAME
f_binbio_cell_mutation_alphabet() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# アドレスregHLをbin_dataの2バイト目(タイル番号)まで進める
	lr35902_set_reg regBC 0009
	lr35902_add_to_regHL regBC

	# regAへbin_data内のタイル番号を取得
	# ※ 突然変異はbin_dataに対して起こるので、
	# 　 突然変異直後はbin_data内のタイル番号がまだtile_numへ反映されていない。
	# 　 これはeval()時に反映される。
	# 　 突然変異で生まれた細胞が細胞分裂するまでの間に一度もeval()が
	# 　 呼ばれないことはあり得ないので、処理の削減のために現在のタイル番号として
	# 　 突然変異の対象でもあるbin_data内のタイル番号を参照している。
	lr35902_copy_to_from regA ptrHL

	# regA == 細胞タイル ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_CELL
	(
		# regA == 細胞タイル の場合

		# regAへ0x00〜0x19(25)の乱数を取得
		(
			# 0x00〜0xffの乱数生成
			lr35902_call $a_get_rnd

			# 下位5ビットを抽出
			lr35902_and_to_regA 1f

			# regA < 0x1a ?
			lr35902_compare_regA_and 1a
			(
				# regA < 0x1a の場合

				# ループを脱出
				lr35902_rel_jump $(two_digits_d 2)
			) >src/f_binbio_cell_mutation_alphabet.1.o
			local sz_1=$(stat -c '%s' src/f_binbio_cell_mutation_alphabet.1.o)
			lr35902_rel_jump_with_cond NC $(two_digits_d $sz_1)
			cat src/f_binbio_cell_mutation_alphabet.1.o
		) >src/f_binbio_cell_mutation_alphabet.2.o
		cat src/f_binbio_cell_mutation_alphabet.2.o
		local sz_2=$(stat -c '%s' src/f_binbio_cell_mutation_alphabet.2.o)
		lr35902_rel_jump $(two_comp_d $((sz_2 + 2)))	# 2

		# regA += 0x1e
		lr35902_add_to_regA 1e

		# ptrHL = regA
		lr35902_copy_to_from ptrHL regA

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_mutation_alphabet.3.o
	local sz_3=$(stat -c '%s' src/f_binbio_cell_mutation_alphabet.3.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
	cat src/f_binbio_cell_mutation_alphabet.3.o

	# regA != 細胞タイル の場合

	# regA == 'A' ?
	lr35902_compare_regA_and $(get_alpha_tile_num 'A')
	(
		# regA == 'A' の場合

		# regA++
		lr35902_inc regA

		# ptrHL = regA
		lr35902_copy_to_from ptrHL regA

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_mutation_alphabet.4.o
	local sz_4=$(stat -c '%s' src/f_binbio_cell_mutation_alphabet.4.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
	cat src/f_binbio_cell_mutation_alphabet.4.o

	# regA == 'Z' ?
	lr35902_compare_regA_and $(get_alpha_tile_num 'Z')
	(
		# regA == 'Z' の場合

		# regA--
		lr35902_dec regA

		# ptrHL = regA
		lr35902_copy_to_from ptrHL regA

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_mutation_alphabet.5.o
	local sz_5=$(stat -c '%s' src/f_binbio_cell_mutation_alphabet.5.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_5)
	cat src/f_binbio_cell_mutation_alphabet.5.o

	# regAが'B'〜'Y'のいずれかの場合

	# 現在のregAをregBへ退避
	lr35902_copy_to_from regB regA

	# regAへ0x00〜0xffの乱数を取得
	lr35902_call $a_get_rnd

	# regAのLSB == 0 ?
	lr35902_test_bitN_of_reg 0 regA
	(
		# regAのLSB == 0 の場合

		# regBからregAを復帰
		lr35902_copy_to_from regA regB

		# regA--
		lr35902_dec regA

		# ptrHL = regA
		lr35902_copy_to_from ptrHL regA

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_mutation_alphabet.6.o
	local sz_6=$(stat -c '%s' src/f_binbio_cell_mutation_alphabet.6.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_6)
	cat src/f_binbio_cell_mutation_alphabet.6.o

	# regAのLSB == 1 の場合

	# regBからregAを復帰
	lr35902_copy_to_from regA regB

	# regA++
	lr35902_inc regA

	# ptrHL = regA
	lr35902_copy_to_from ptrHL regA

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 白/黒デイジー用の突然変異関数
f_binbio_cell_mutation_alphabet >src/f_binbio_cell_mutation_alphabet.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_mutation_alphabet.o))
fadr=$(calc16 "${a_binbio_cell_mutation_alphabet}+${fsz}")
a_binbio_cell_mutation_daisy=$(four_digits $fadr)
echo -e "a_binbio_cell_mutation_daisy=$a_binbio_cell_mutation_daisy" >>$MAP_FILE_NAME
## 定義はsrc/expset_daisyworld.shにある

# 捕食者用突然変異関数
f_binbio_cell_mutation_daisy >src/f_binbio_cell_mutation_daisy.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_mutation_daisy.o))
fadr=$(calc16 "${a_binbio_cell_mutation_daisy}+${fsz}")
a_binbio_cell_mutation_predator=$(four_digits $fadr)
echo -e "a_binbio_cell_mutation_predator=$a_binbio_cell_mutation_predator" >>$MAP_FILE_NAME
## 定義はsrc/species_predator.shにある

# 突然変異
# in : regHL - 対象の細胞のアドレス
f_binbio_cell_mutation_predator >src/f_binbio_cell_mutation_predator.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_mutation_predator.o))
fadr=$(calc16 "${a_binbio_cell_mutation_predator}+${fsz}")
a_binbio_cell_mutation=$(four_digits $fadr)
echo -e "a_binbio_cell_mutation=$a_binbio_cell_mutation" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 細胞の「分裂」の振る舞い(通常時)
f_binbio_cell_mutation >src/f_binbio_cell_mutation.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_mutation.o))
fadr=$(calc16 "${a_binbio_cell_mutation}+${fsz}")
a_binbio_cell_division=$(four_digits $fadr)
echo -e "a_binbio_cell_division=$a_binbio_cell_division" >>$MAP_FILE_NAME
f_binbio_cell_division() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# 細胞データ領域を確保
	## 関数呼び出し
	lr35902_call $a_binbio_cell_alloc
	## 戻り値チェック
	lr35902_copy_to_from regA regH
	lr35902_or_to_regA regL
	lr35902_compare_regA_and 00
	(
		# regA == 0x00 の場合

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_division.1.o
	local sz_1=$(stat -c '%s' src/f_binbio_cell_division.1.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
	cat src/f_binbio_cell_division.1.o

	# push
	lr35902_push_reg regDE

	# 近傍の空き座標を探す
	## 関数呼び出し
	lr35902_call $a_binbio_cell_find_free_neighbor
	## 戻り値チェック
	lr35902_copy_to_from regA regD
	lr35902_and_to_regA regE
	lr35902_compare_regA_and ff
	(
		# regA == 0xff の場合

		# pop & return
		lr35902_pop_reg regDE
		lr35902_pop_reg regHL
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_division.2.o
	local sz_2=$(stat -c '%s' src/f_binbio_cell_division.2.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_2)
	cat src/f_binbio_cell_division.2.o

	# push
	lr35902_push_reg regBC

	# 現在の細胞のアドレスをregBCへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regC regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regB regA

	# 確保した領域へ細胞データを設定
	## flags = 0x01
	lr35902_set_reg regA 01
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_inc regBC
	## (tile_x, tile_y) = (regE, regD)
	lr35902_copy_to_from regA regE
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_inc regBC
	lr35902_copy_to_from regA regD
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_inc regBC
	## life_duration = 親のlife_duration
	lr35902_copy_to_from regA ptrBC
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_inc regBC
	## life_left = 親のlife_duration
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_inc regBC
	## fitness = 親のfitness
	lr35902_copy_to_from regA ptrBC
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_inc regBC
	if [ $BINBIO_FIX_MUTATION_PROBABILITY -eq 0 ]; then
		# 後のためにpush
		lr35902_push_reg regAF
	fi
	## tile_num = 親のtile_num
	lr35902_copy_to_from regA ptrBC
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_inc regBC
	## bin_size = 親のbin_size
	lr35902_copy_to_from regA ptrBC
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_inc regBC
	## bin_data = 親のbin_data
	for i in $(seq $BINBIO_CELL_BIN_DATA_AREA_SIZE); do
		lr35902_copy_to_from regA ptrBC
		lr35902_copyinc_to_ptrHL_from_regA
		lr35902_inc regBC
	done
	## collected_flags = 0x00
	lr35902_xor_to_regA regA
	lr35902_copy_to_from ptrHL regA

	# mutation_probabilityに応じて突然変異
	## regHLへ子細胞データの先頭アドレスを設定
	lr35902_set_reg regBC $(two_comp_4 $(calc16 "${BINBIO_CELL_DATA_SIZE}-1"))
	lr35902_add_to_regHL regBC
	## regBへ突然変異確率を設定
	if [ $BINBIO_FIX_MUTATION_PROBABILITY -eq 1 ]; then
		# 固定(var_binbio_mutation_probabilityを使う)
		## mutation_probabilityをregBへ取得
		lr35902_copy_to_regA_from_addr $var_binbio_mutation_probability
		lr35902_copy_to_from regB regA
	else
		# 自動(0xff - 適応度)
		## 突然変異確率(regB) = 0xff - fitness
		### 現在のregHLをpush
		lr35902_push_reg regHL
		### regHL = SP + 5(pushしていたfitnessのアドレス)
		lr35902_copy_to_regHL_from_SP_plus_n 03
		### regBへfitnessを取得
		lr35902_copy_to_from regB ptrHL
		### regA = 0xff - regB
		### ※ sub命令の計算結果はMSBを符号ビットとして扱った結果となるが
		### 　 0xffから減算する分にはそうであっても問題無い
		###    例えば、0xff - 0x7f = 0x80 となるし、0xff - 0x01 = 0xfe となる
		lr35902_set_reg regA ff
		lr35902_sub_to_regA regB
		### regB = regA
		lr35902_copy_to_from regB regA
		### regHLをpop
		lr35902_pop_reg regHL
		### pushしていた親のfitnessもpop
		lr35902_pop_reg regAF
	fi
	## 0x00〜0xffの間の乱数を生成
	lr35902_call $a_get_rnd
	## regA(生成した乱数) < mutation_probability ?
	lr35902_compare_regA_and regB
	(
		# regA < mutation_probability の場合

		# 突然変異
		lr35902_call $a_binbio_cell_mutation
	) >src/f_binbio_cell_division.3.o
	local sz_3=$(stat -c '%s' src/f_binbio_cell_division.3.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_3)
	cat src/f_binbio_cell_division.3.o

	# この時点でregHLには生まれた細胞の先頭アドレスが設定されている

	# この後、regHLが書き換えられるので、その前にスタックへpush
	lr35902_push_reg regHL

	# 生まれた細胞をマップへ描画
	## 生まれた細胞のタイル番号をregBへ取得
	### regHLのアドレスをtile_numまで進める
	lr35902_set_reg regBC 0006
	lr35902_add_to_regHL regBC
	### regBへ生まれた細胞のタイル番号を取得
	lr35902_copy_to_from regB ptrHL
	## 生まれた細胞のtile_x,tile_yからVRAMアドレスを算出
	lr35902_call $a_tcoord_to_addr
	## 算出/取得したVRAMアドレスと細胞のタイル番号をtdqへエンキュー
	### regDE = VRAMアドレス
	#### regDEを上書きする前に後のためにpush
	lr35902_push_reg regDE
	lr35902_copy_to_from regE regL
	lr35902_copy_to_from regD regH
	### 関数呼び出し
	lr35902_call $a_enq_tdq
	## この時点でタイルミラー領域へも手動で反映
	### pushしていたregDEをpop
	lr35902_pop_reg regDE
	### 生まれた細胞のtile_x,tile_yからタイルミラーアドレスを算出
	lr35902_call $a_tcoord_to_mrraddr
	### ミラー領域へタイル番号を書き込み
	lr35902_copy_to_from ptrHL regB

	# regDEへ生まれた細胞の先頭アドレスをスタックからpop
	lr35902_pop_reg regDE

	# BGマップへ書き込んだ旨のビットをセットするためのエントリをtdqへ追加
	## regBへwrote_to_bgとaliveをセットした状態のflagsを設定
	lr35902_set_reg regB 05
	## regDEへは生まれた細胞のflagsのアドレス(=細胞の先頭アドレス)が
	## 既に設定済
	## 関数呼び出し
	lr35902_call $a_enq_tdq

	# 親細胞のcollected_flagsを0x00にする
	## 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA
	## regHLのアドレスをcollected_flagsまで進める
	lr35902_set_reg regBC 000d
	lr35902_add_to_regHL regBC
	## ptrHL = 0x00
	lr35902_xor_to_regA regA
	lr35902_copy_to_from ptrHL regA

	# pop & return
	lr35902_pop_reg regBC
	lr35902_pop_reg regDE
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
	lr35902_return
}

# 細胞の「分裂」の振る舞い(fixモード時)
f_binbio_cell_division >src/f_binbio_cell_division.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_division.o))
fadr=$(calc16 "${a_binbio_cell_division}+${fsz}")
a_binbio_cell_division_fix=$(four_digits $fadr)
echo -e "a_binbio_cell_division_fix=$a_binbio_cell_division_fix" >>$MAP_FILE_NAME
f_binbio_cell_division_fix() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# regHLへcur_cell_addrを設定する
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# 細胞データの一部のフィールドの再設定
	## flags
	lr35902_set_reg regA 03
	lr35902_copyinc_to_ptrHL_from_regA
	## 後のために(tile_x,tile_y)を(regE,regD)へ取得
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regE regA
	lr35902_copyinc_to_regA_from_ptrHL
	lr35902_copy_to_from regD regA
	## life_left
	### life_durationを取得
	lr35902_copyinc_to_regA_from_ptrHL
	### 取得した値をlife_leftへ設定
	lr35902_copyinc_to_ptrHL_from_regA
	## 後のためにtile_numをpush
	lr35902_inc regHL
	lr35902_copy_to_from regB ptrHL
	lr35902_push_reg regBC
	## collected_flags
	lr35902_set_reg regBC 0007
	lr35902_add_to_regHL regBC
	lr35902_xor_to_regA regA
	lr35902_copy_to_from ptrHL regA

	# 細胞をマップへ描画
	## tile_x,tile_yからVRAMアドレスを算出
	lr35902_call $a_tcoord_to_addr
	## 算出したVRAMアドレスと細胞のタイル番号をtdqへエンキュー
	### regB = 配置するタイル番号
	#### pushしていたtile_numをpop
	lr35902_pop_reg regBC
	### regDE = VRAMアドレス
	#### regDEを上書きする前に後のためにpush
	lr35902_push_reg regDE
	lr35902_copy_to_from regE regL
	lr35902_copy_to_from regD regH
	### 関数呼び出し
	lr35902_call $a_enq_tdq
	## この時点でタイルミラー領域へも手動で反映
	### pushしていたregDEをpop
	lr35902_pop_reg regDE
	### 生まれた細胞のtile_x,tile_yからタイルミラーアドレスを算出
	lr35902_call $a_tcoord_to_mrraddr
	### ミラー領域へタイル番号を書き込み
	lr35902_copy_to_from ptrHL regB

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 次の細胞を選択
f_binbio_cell_division_fix >src/f_binbio_cell_division_fix.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_cell_division_fix.o))
fadr=$(calc16 "${a_binbio_cell_division_fix}+${fsz}")
a_binbio_select_next_cell=$(four_digits $fadr)
echo -e "a_binbio_select_next_cell=$a_binbio_select_next_cell" >>$MAP_FILE_NAME
f_binbio_select_next_cell() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# cur_cell_addr以降でflags.aliveがセットされている細胞を探す
	## regHLへcur_cell_addrを設定する
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA
	## 現在の細胞のアドレスは後にも使うのでpushしておく
	lr35902_push_reg regHL
	## flags.aliveがセットされている細胞を探す
	(
		# regHL += 細胞データ構造のサイズ
		lr35902_set_reg regBC $(four_digits $BINBIO_CELL_DATA_SIZE)
		lr35902_add_to_regHL regBC

		# regHL > 細胞データ領域最終アドレス ?
		## regDE = 細胞データ領域最終アドレス
		lr35902_set_reg regDE $BINBIO_CELL_DATA_AREA_END
		## regHLとregDEを比較
		lr35902_call $a_compare_regHL_and_regDE
		## 戻り値 > 0 ?
		### 戻り値は負の値か?
		lr35902_test_bitN_of_reg 7 regA
		(
			# 負の値でない場合

			# 戻り値は0と等しいか?
			lr35902_compare_regA_and 00
			(
				# 0と等しくない場合
				# (戻り値 > 0 であり、
				#  regHL > 細胞データ領域最終アドレス
				#  である場合)

				# regHLへ細胞データ領域の最初のアドレスを設定する
				lr35902_set_reg regHL $BINBIO_CELL_DATA_AREA_BEGIN
			) >src/f_binbio_select_next_cell.1.o
			local sz_1=$(stat -c '%s' src/f_binbio_select_next_cell.1.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_1)
			cat src/f_binbio_select_next_cell.1.o
		) >src/f_binbio_select_next_cell.4.o
		local sz_4=$(stat -c '%s' src/f_binbio_select_next_cell.4.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
		cat src/f_binbio_select_next_cell.4.o

		# flags.aliveはセットされているか?
		lr35902_test_bitN_of_reg 0 ptrHL
		(
			# flags.alive == 0 の場合

			# 現在の細胞のアドレスをregDEへpop
			lr35902_pop_reg regDE

			# regHL == regDE ?
			## regB = regH XOR regD
			## (regH == regD なら regB = 0)
			lr35902_copy_to_from regA regH
			lr35902_xor_to_regA regD
			lr35902_copy_to_from regB regA
			## regA = regL XOR regE
			## (regL == regE なら regA = 0)
			lr35902_copy_to_from regA regL
			lr35902_xor_to_regA regE
			## regA |= regB
			## (regHL == regDE なら regA = 0)
			lr35902_or_to_regA regB
			## regA == 0 ?
			lr35902_compare_regA_and 00
			(
				# regA == 0 (regHL == regDE) の場合

				# 変数errorへ1を設定
				lr35902_inc regA
				lr35902_copy_to_addr_from_regA $var_error

				# pop & return
				lr35902_pop_reg regHL
				lr35902_pop_reg regDE
				lr35902_pop_reg regBC
				lr35902_pop_reg regAF
				lr35902_return
			) >src/f_binbio_select_next_cell.6.o
			local sz_6=$(stat -c '%s' src/f_binbio_select_next_cell.6.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_6)
			cat src/f_binbio_select_next_cell.6.o

			# 現在の細胞のアドレスを再びpush
			lr35902_push_reg regDE
		) >src/f_binbio_select_next_cell.5.o
		(
			# flags.alive == 1 の場合

			# flags.alive == 0 の場合の処理を飛ばし、ループも脱出
			local sz_5=$(stat -c '%s' src/f_binbio_select_next_cell.5.o)
			lr35902_rel_jump $(two_digits_d $((sz_5 + 2)))
		) >src/f_binbio_select_next_cell.2.o
		local sz_2=$(stat -c '%s' src/f_binbio_select_next_cell.2.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
		cat src/f_binbio_select_next_cell.2.o	# flags.alive == 1 の場合
		cat src/f_binbio_select_next_cell.5.o	# flags.alive == 0 の場合
	) >src/f_binbio_select_next_cell.3.o
	cat src/f_binbio_select_next_cell.3.o
	local sz_3=$(stat -c '%s' src/f_binbio_select_next_cell.3.o)
	lr35902_rel_jump $(two_comp_d $((sz_3 + 2)))	# 2

	# 見つけた細胞のアドレスをcur_cell_addrへ設定
	lr35902_copy_to_from regA regL
	lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regA regH
	lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_th

	# 変数errorへ0を設定
	lr35902_xor_to_regA regA
	lr35902_copy_to_addr_from_regA $var_error

	# pop & return
	lr35902_pop_reg regHL	# pushしていた細胞アドレス
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# ソフト説明を画面へ配置
f_binbio_select_next_cell >src/f_binbio_select_next_cell.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_select_next_cell.o))
fadr=$(calc16 "${a_binbio_select_next_cell}+${fsz}")
a_binbio_place_soft_desc=$(four_digits $fadr)
echo -e "a_binbio_place_soft_desc=$a_binbio_place_soft_desc" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# ソフト説明をクリア
f_binbio_place_soft_desc >src/f_binbio_place_soft_desc.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_place_soft_desc.o))
fadr=$(calc16 "${a_binbio_place_soft_desc}+${fsz}")
a_binbio_clear_soft_desc=$(four_digits $fadr)
echo -e "a_binbio_clear_soft_desc=$a_binbio_clear_soft_desc" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# ステータス表示領域の更新
f_binbio_clear_soft_desc >src/f_binbio_clear_soft_desc.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_clear_soft_desc.o))
fadr=$(calc16 "${a_binbio_clear_soft_desc}+${fsz}")
a_binbio_update_status_disp=$(four_digits $fadr)
echo -e "a_binbio_update_status_disp=$a_binbio_update_status_disp" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 細胞ステータス情報のラベルを画面へ配置
f_binbio_update_status_disp >src/f_binbio_update_status_disp.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_update_status_disp.o))
fadr=$(calc16 "${a_binbio_update_status_disp}+${fsz}")
a_binbio_place_cell_info_labels=$(four_digits $fadr)
echo -e "a_binbio_place_cell_info_labels=$a_binbio_place_cell_info_labels" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 細胞ステータス情報の値を画面へ配置
# in : regHL - 対象の細胞のアドレス
f_binbio_place_cell_info_labels >src/f_binbio_place_cell_info_labels.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_place_cell_info_labels.o))
fadr=$(calc16 "${a_binbio_place_cell_info_labels}+${fsz}")
a_binbio_place_cell_info_val=$(four_digits $fadr)
echo -e "a_binbio_place_cell_info_val=$a_binbio_place_cell_info_val" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 細胞ステータス情報をクリア
f_binbio_place_cell_info_val >src/f_binbio_place_cell_info_val.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_place_cell_info_val.o))
fadr=$(calc16 "${a_binbio_place_cell_info_val}+${fsz}")
a_binbio_clear_cell_info=$(four_digits $fadr)
echo -e "a_binbio_clear_cell_info=$a_binbio_clear_cell_info" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 評価関数選択を画面へ配置
f_binbio_clear_cell_info >src/f_binbio_clear_cell_info.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_clear_cell_info.o))
fadr=$(calc16 "${a_binbio_clear_cell_info}+${fsz}")
a_binbio_place_cell_eval_sel=$(four_digits $fadr)
echo -e "a_binbio_place_cell_eval_sel=$a_binbio_place_cell_eval_sel" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 評価関数選択をクリア
f_binbio_place_cell_eval_sel >src/f_binbio_place_cell_eval_sel.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_place_cell_eval_sel.o))
fadr=$(calc16 "${a_binbio_place_cell_eval_sel}+${fsz}")
a_binbio_clear_cell_eval_sel=$(four_digits $fadr)
echo -e "a_binbio_clear_cell_eval_sel=$a_binbio_clear_cell_eval_sel" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# 現在の評価関数番号とパラメータ番号に対応する変数のアドレスを取得
f_binbio_clear_cell_eval_sel >src/f_binbio_clear_cell_eval_sel.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_clear_cell_eval_sel.o))
fadr=$(calc16 "${a_binbio_clear_cell_eval_sel}+${fsz}")
a_binbio_get_var_from_current_cell_eval_and_param=$(four_digits $fadr)
echo -e "a_binbio_get_var_from_current_cell_eval_and_param=$a_binbio_get_var_from_current_cell_eval_and_param" >>$MAP_FILE_NAME
## 定義はsrc/status_disp_cell_eval_conf.shにある

# 現在の評価関数番号のパラメータ番号を配置するタイルアドレスを取得
f_binbio_get_var_from_current_cell_eval_and_param >src/f_binbio_get_var_from_current_cell_eval_and_param.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_get_var_from_current_cell_eval_and_param.o))
fadr=$(calc16 "${a_binbio_get_var_from_current_cell_eval_and_param}+${fsz}")
a_binbio_get_tadr_from_current_cell_eval_and_param=$(four_digits $fadr)
echo -e "a_binbio_get_tadr_from_current_cell_eval_and_param=$a_binbio_get_tadr_from_current_cell_eval_and_param" >>$MAP_FILE_NAME
## 定義はsrc/status_disp_cell_eval_conf.shにある

# 固定値を返す評価関数のパラメータを画面へ配置
f_binbio_get_tadr_from_current_cell_eval_and_param >src/f_binbio_get_tadr_from_current_cell_eval_and_param.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_get_tadr_from_current_cell_eval_and_param.o))
fadr=$(calc16 "${a_binbio_get_tadr_from_current_cell_eval_and_param}+${fsz}")
a_binbio_place_fixedval_param=$(four_digits $fadr)
echo -e "a_binbio_place_fixedval_param=$a_binbio_place_fixedval_param" >>$MAP_FILE_NAME
## 定義はsrc/status_disp_cell_eval_conf.shにある

# 評価関数設定を画面へ配置
f_binbio_place_fixedval_param >src/f_binbio_place_fixedval_param.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_place_fixedval_param.o))
fadr=$(calc16 "${a_binbio_place_fixedval_param}+${fsz}")
a_binbio_place_cell_eval_conf=$(four_digits $fadr)
echo -e "a_binbio_place_cell_eval_conf=$a_binbio_place_cell_eval_conf" >>$MAP_FILE_NAME
## 定義はsrc/status_disp_cell_eval_conf.shにある

# 評価関数設定をクリア
f_binbio_place_cell_eval_conf >src/f_binbio_place_cell_eval_conf.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_place_cell_eval_conf.o))
fadr=$(calc16 "${a_binbio_place_cell_eval_conf}+${fsz}")
a_binbio_clear_cell_eval_conf=$(four_digits $fadr)
echo -e "a_binbio_clear_cell_eval_conf=$a_binbio_clear_cell_eval_conf" >>$MAP_FILE_NAME
## 定義はsrc/status_disp_cell_eval_conf.shにある

# バイナリ生物環境の初期化
# in : regA - 実験セット番号
f_binbio_clear_cell_eval_conf >src/f_binbio_clear_cell_eval_conf.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_clear_cell_eval_conf.o))
fadr=$(calc16 "${a_binbio_clear_cell_eval_conf}+${fsz}")
a_binbio_init=$(four_digits $fadr)
echo -e "a_binbio_init=$a_binbio_init" >>$MAP_FILE_NAME
## 定義は実験セットのスクリプト(src/expset_XXX.sh)内にある

# バイナリ生物環境のリセット
# in : regA - 実験セット番号
f_binbio_init >src/f_binbio_init.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_init.o))
fadr=$(calc16 "${a_binbio_init}+${fsz}")
a_binbio_reset=$(four_digits $fadr)
echo -e "a_binbio_reset=$a_binbio_reset" >>$MAP_FILE_NAME
f_binbio_reset() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC

	# regA(実験セット番号)をregBへ退避
	lr35902_copy_to_from regB regA

	# V-Blankの開始を待つ
	# ※ regAFは破壊される
	gb_wait_for_vblank_to_start

	# LCDを停止する
	# - 停止の間はVRAMとOAMに自由にアクセスできる(vblankとか関係なく)
	lr35902_set_reg regA ${GBOS_LCDC_BASE}
	lr35902_copy_to_ioport_from_regA $GB_IO_LCDC

	# 背景タイルマップを白タイル(タイル番号0)で初期化
	lr35902_call $a_clear_bg

	# tdq初期化
	# - tdq.head = tdq.tail = TDQ_FIRST
	lr35902_set_reg regA $(echo $GBOS_TDQ_FIRST | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_tdq_head_bh
	lr35902_copy_to_addr_from_regA $var_tdq_tail_bh
	lr35902_set_reg regA $(echo $GBOS_TDQ_FIRST | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_tdq_head_th
	lr35902_copy_to_addr_from_regA $var_tdq_tail_th
	# - tdq.stat = is_empty
	lr35902_set_reg regA 01
	lr35902_copy_to_addr_from_regA $var_tdq_stat

	# タイルミラー領域の初期化
	lr35902_call $a_init_tmrr

	# 初期化
	## regA(引数)をregBから復帰
	lr35902_copy_to_from regA regB
	## 関数呼び出し
	lr35902_call $a_binbio_init

	# LCD再開
	lr35902_set_reg regA $(calc16 "${GBOS_LCDC_BASE}+${GB_LCDC_BIT_DE}")
	lr35902_copy_to_ioport_from_regA $GB_IO_LCDC

	# pop & return
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 1周期分の周期動作を実施
f_binbio_reset >src/f_binbio_reset.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_reset.o))
fadr=$(calc16 "${a_binbio_reset}+${fsz}")
a_binbio_do_cycle=$(four_digits $fadr)
echo -e "a_binbio_do_cycle=$a_binbio_do_cycle" >>$MAP_FILE_NAME
f_binbio_do_cycle() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# 代謝/運動を実施
	lr35902_call $a_binbio_cell_metabolism_and_motion

	# 成長を実施
	lr35902_call $a_binbio_cell_growth

	# flags.fix == 0 ?
	lr35902_test_bitN_of_reg $BINBIO_CELL_FLAGS_BIT_FIX ptrHL
	(
		# flags.fix == 0 の場合

		# 分裂可能か?
		lr35902_call $a_binbio_cell_is_dividable
		lr35902_compare_regA_and 01
		(
			# 分裂可能な場合

			# 分裂を実施
			lr35902_call $a_binbio_cell_division
		) >src/f_binbio_do_cycle.1.o
		local sz_1=$(stat -c '%s' src/f_binbio_do_cycle.1.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
		cat src/f_binbio_do_cycle.1.o
	) >src/f_binbio_do_cycle.4.o
	local sz_4=$(stat -c '%s' src/f_binbio_do_cycle.4.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
	cat src/f_binbio_do_cycle.4.o

	# 細胞の余命をデクリメント
	## アドレスregHLをlife_leftまで進める
	lr35902_set_reg regBC 0004
	lr35902_add_to_regHL regBC
	## life_left--
	lr35902_dec ptrHL

	# 余命が0になったか?
	lr35902_copy_to_from regA ptrHL
	lr35902_compare_regA_and 00
	(
		# 余命 == 0 の場合

		# 死を実施
		lr35902_call $a_binbio_cell_death

		# flags.fix == 1 ?
		## アドレスregHLをflagsまで戻す
		lr35902_set_reg regBC $(two_comp_4 4)
		lr35902_add_to_regHL regBC
		## flagsのfixビットを確認
		lr35902_test_bitN_of_reg $BINBIO_CELL_FLAGS_BIT_FIX ptrHL
		(
			# flags.fix == 1 の場合

			# 分裂可能か?
			lr35902_call $a_binbio_cell_is_dividable
			lr35902_compare_regA_and 01
			(
				# 分裂可能な場合

				# 分裂を実施
				lr35902_call $a_binbio_cell_division_fix
			) >src/f_binbio_do_cycle.5.o
			local sz_5=$(stat -c '%s' src/f_binbio_do_cycle.5.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_5)
			cat src/f_binbio_do_cycle.5.o
		) >src/f_binbio_do_cycle.6.o
		local sz_6=$(stat -c '%s' src/f_binbio_do_cycle.6.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_6)
		cat src/f_binbio_do_cycle.6.o
	) >src/f_binbio_do_cycle.2.o
	local sz_2=$(stat -c '%s' src/f_binbio_do_cycle.2.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_2)
	cat src/f_binbio_do_cycle.2.o

	# 次の細胞を選択
	## 関数呼び出し
	lr35902_call $a_binbio_select_next_cell
	## エラーの有無を確認
	lr35902_copy_to_regA_from_addr $var_error
	lr35902_compare_regA_and 00
	(
		# regA != 0 の場合

		# 初期化を実施
		## regA(引数) = 現在の実験セット番号
		lr35902_copy_to_regA_from_addr $var_binbio_expset_num
		## 関数呼び出し
		lr35902_call $a_binbio_init
	) >src/f_binbio_do_cycle.3.o
	local sz_3=$(stat -c '%s' src/f_binbio_do_cycle.3.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_3)
	cat src/f_binbio_do_cycle.3.o

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# バイナリ生物環境用のAボタンリリースイベントハンドラ
f_binbio_do_cycle >src/f_binbio_do_cycle.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_do_cycle.o))
fadr=$(calc16 "${a_binbio_do_cycle}+${fsz}")
a_binbio_event_btn_a_release=$(four_digits $fadr)
echo -e "a_binbio_event_btn_a_release=$a_binbio_event_btn_a_release" >>$MAP_FILE_NAME
f_binbio_event_btn_a_release() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC

	# デイジーワールド: 地表温度の▲▼ボタンの処理
	## マウスカーソルY座標 <= ▲▼のY座標終端 ?
	lr35902_copy_to_regA_from_addr $var_mouse_y
	lr35902_copy_to_from regB regA
	lr35902_set_reg regA $SURFACE_TEMP_UP_DOWN_END_Y
	lr35902_compare_regA_and regB
	(
		# regB <= regA (マウスカーソルY座標 <= ▲▼のY座標終端) の場合

		# マウスカーソルY座標 >= ▲▼のY座標始端 ?
		lr35902_copy_to_from regA regB
		lr35902_set_reg regB $SURFACE_TEMP_UP_DOWN_BEGIN_Y
		lr35902_compare_regA_and regB
		(
			# regA >= regB (マウスカーソルY座標 >= ▲▼のY座標始端) の場合

			# マウスカーソルX座標 >= ▲のX座標始端 ?
			lr35902_set_reg regB $SURFACE_TEMP_UP_BEGIN_X
			lr35902_copy_to_regA_from_addr $var_mouse_x
			lr35902_compare_regA_and regB
			(
				# regA >= regB (マウスカーソルX座標 >= ▲のX座標始端) の場合

				# マウスカーソルX座標 <= ▲のX座標終端 ?
				lr35902_copy_to_from regB regA
				lr35902_set_reg regA $SURFACE_TEMP_UP_END_X
				lr35902_compare_regA_and regB
				(
					# regB > regA (マウスカーソルX座標 > ▲のX座標終端) の場合

					# マウスカーソルX座標 <= ▼のX座標終端 ?
					lr35902_set_reg regA $SURFACE_TEMP_DOWN_END_X
					lr35902_compare_regA_and regB
					(
						# regB <= regA (マウスカーソルX座標 <= ▼のX座標終端) の場合

						# 地表温度 != -128(0x80) ?
						lr35902_copy_to_regA_from_addr $var_binbio_surface_temp
						lr35902_compare_regA_and 80
						(
							# 地表温度 != -128の場合

							# 地表温度をデクリメント
							lr35902_dec regA
							lr35902_copy_to_addr_from_regA $var_binbio_surface_temp
						) >src/f_binbio_event_btn_a_release.st_ne_80.o
						local sz_st_ne_80=$(stat -c '%s' src/f_binbio_event_btn_a_release.st_ne_80.o)
						lr35902_rel_jump_with_cond Z $(two_digits_d $sz_st_ne_80)
						cat src/f_binbio_event_btn_a_release.st_ne_80.o
					) >src/f_binbio_event_btn_a_release.mx_le_dxe.o
					# regB > regA の場合処理を飛ばす
					local sz_mx_le_dxe=$(stat -c '%s' src/f_binbio_event_btn_a_release.mx_le_dxe.o)
					lr35902_rel_jump_with_cond C $(two_digits_d $sz_mx_le_dxe)
					cat src/f_binbio_event_btn_a_release.mx_le_dxe.o
				) >src/f_binbio_event_btn_a_release.mx_gt_uxe.o
				(
					# regB <= regA (マウスカーソルX座標 <= ▲のX座標終端) の場合

					# 地表温度 != 127(0x7f) ?
					lr35902_copy_to_regA_from_addr $var_binbio_surface_temp
					lr35902_compare_regA_and 7f
					(
						# 地表温度 != 127の場合

						# 地表温度をインクリメント
						lr35902_inc regA
						lr35902_copy_to_addr_from_regA $var_binbio_surface_temp
					) >src/f_binbio_event_btn_a_release.st_ne_7f.o
					local sz_st_ne_7f=$(stat -c '%s' src/f_binbio_event_btn_a_release.st_ne_7f.o)
					lr35902_rel_jump_with_cond Z $(two_digits_d $sz_st_ne_7f)
					cat src/f_binbio_event_btn_a_release.st_ne_7f.o

					# regB > regA の場合の処理を飛ばす
					local sz_mx_gt_uxe=$(stat -c '%s' src/f_binbio_event_btn_a_release.mx_gt_uxe.o)
					lr35902_rel_jump $(two_digits_d $sz_mx_gt_uxe)
				) >src/f_binbio_event_btn_a_release.mx_le_uxe.o
				local sz_mx_le_uxe=$(stat -c '%s' src/f_binbio_event_btn_a_release.mx_le_uxe.o)
				lr35902_rel_jump_with_cond C $(two_digits_d $sz_mx_le_uxe)
				cat src/f_binbio_event_btn_a_release.mx_le_uxe.o # regB <= regA の場合
				cat src/f_binbio_event_btn_a_release.mx_gt_uxe.o # regB > regA の場合
			) >src/f_binbio_event_btn_a_release.mx_ge_uxb.o
			# regA < regB の場合、処理を飛ばす
			local sz_mx_ge_uxb=$(stat -c '%s' src/f_binbio_event_btn_a_release.mx_ge_uxb.o)
			lr35902_rel_jump_with_cond C $(two_digits_d $sz_mx_ge_uxb)
			cat src/f_binbio_event_btn_a_release.mx_ge_uxb.o
		) >src/f_binbio_event_btn_a_release.my_ge_udyb.o
		# regA < regB の場合、処理を飛ばす
		local sz_my_ge_udyb=$(stat -c '%s' src/f_binbio_event_btn_a_release.my_ge_udyb.o)
		lr35902_rel_jump_with_cond C $(two_digits_d $sz_my_ge_udyb)
		cat src/f_binbio_event_btn_a_release.my_ge_udyb.o
	) >src/f_binbio_event_btn_a_release.my_le_udey.o
	## regB > regA の場合、処理を飛ばす
	local sz_my_le_udey=$(stat -c '%s' src/f_binbio_event_btn_a_release.my_le_udey.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_my_le_udey)
	cat src/f_binbio_event_btn_a_release.my_le_udey.o

	# pop & return
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# バイナリ生物環境用のBボタンリリースイベントハンドラ
f_binbio_event_btn_a_release >src/f_binbio_event_btn_a_release.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_event_btn_a_release.o))
fadr=$(calc16 "${a_binbio_event_btn_a_release}+${fsz}")
a_binbio_event_btn_b_release=$(four_digits $fadr)
echo -e "a_binbio_event_btn_b_release=$a_binbio_event_btn_b_release" >>$MAP_FILE_NAME
f_binbio_event_btn_b_release() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# regHLへマウスカーソルが指す細胞のアドレスを取得
	lr35902_call $a_binbio_get_pointed_cell_addr

	# 見つかった(regHL != NULL)か?
	lr35902_xor_to_regA regA
	lr35902_or_to_regA regL
	lr35902_or_to_regA regH
	lr35902_compare_regA_and 00
	(
		# 見つからなかった(regHL == NULL)場合

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regDE
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_event_btn_b_release.1.o
	local sz_1=$(stat -c '%s' src/f_binbio_event_btn_b_release.1.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
	cat src/f_binbio_event_btn_b_release.1.o

	# 現在のステータス表示領域の状態 == ソフト説明表示状態 ?
	## TODO
	## - 現在のステータス表示領域の状態 == ソフト説明表示状態 の場合
	##   - アドレスregHLの細胞に対して死を実施する
	## - 現在のステータス表示領域の状態 != ソフト説明表示状態 の場合
	##   - アドレスregHLの細胞のステータス情報の値を画面へ配置する

	# 現在のステータス表示領域の状態 == ソフト説明表示状態 ?
	lr35902_copy_to_regA_from_addr $var_binbio_status_disp_status
	lr35902_compare_regA_and $STATUS_DISP_SHOW_SOFT_DESC
	(
		# 現在のステータス表示領域の状態 == ソフト説明表示状態 の場合

		# アドレスregHLの細胞に対して死を実施する
		## 変数cur_cell_addrの値をregDEへ退避
		lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
		lr35902_copy_to_from regE regA
		lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
		lr35902_copy_to_from regD regA
		## アドレスregHLの細胞は現在対象とされている細胞か?
		## (regHL == regDE ?)
		lr35902_call $a_compare_regHL_and_regDE
		lr35902_compare_regA_and 00
		(
			# regA == 0 の場合
			# (regHL == regDE)

			# 死の振る舞いを実施
			lr35902_call $a_binbio_cell_death

			# 次の細胞を選択
			## 関数呼び出し
			lr35902_call $a_binbio_select_next_cell
			## エラーの有無を確認
			lr35902_copy_to_regA_from_addr $var_error
			lr35902_compare_regA_and 00
			(
				# regA != 0 の場合

				# 初期化を実施
				## regA(引数) = 現在の実験セット番号
				lr35902_copy_to_regA_from_addr $var_binbio_expset_num
				## 関数呼び出し
				lr35902_call $a_binbio_init
			) >src/f_binbio_event_btn_b_release.4.o
			local sz_4=$(stat -c '%s' src/f_binbio_event_btn_b_release.4.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_4)
			cat src/f_binbio_event_btn_b_release.4.o
		) >src/f_binbio_event_btn_b_release.2.o
		(
			# regA != 0 の場合
			# (regHL != regDE)

			# 変数cur_cell_addrへregHLを設定
			lr35902_copy_to_from regA regL
			lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_bh
			lr35902_copy_to_from regA regH
			lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_th

			# 死の振る舞いを実施
			lr35902_call $a_binbio_cell_death

			# regDEへ退避していた値を変数cur_cell_addrへ復帰
			lr35902_copy_to_from regA regE
			lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_bh
			lr35902_copy_to_from regA regD
			lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_th

			# regA == 0 の場合の処理を飛ばす
			local sz_2=$(stat -c '%s' src/f_binbio_event_btn_b_release.2.o)
			lr35902_rel_jump $(two_digits_d $sz_2)
		) >src/f_binbio_event_btn_b_release.3.o
		local sz_3=$(stat -c '%s' src/f_binbio_event_btn_b_release.3.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_3)
		cat src/f_binbio_event_btn_b_release.3.o	# regA != 0 の場合
		cat src/f_binbio_event_btn_b_release.2.o	# regA == 0 の場合

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regDE
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_event_btn_b_release.sds_eq_sd.o
	local sz_sds_eq_sd=$(stat -c '%s' src/f_binbio_event_btn_b_release.sds_eq_sd.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_sds_eq_sd)
	cat src/f_binbio_event_btn_b_release.sds_eq_sd.o

	# 現在のステータス表示領域の状態 != ソフト説明表示状態 の場合
	# (現状では「細胞ステータス情報表示状態」のみ)

	# アドレスregHLの細胞のステータス情報を配置
	lr35902_call $a_binbio_place_cell_info_val

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
	lr35902_return
}

# バイナリ生物環境用の↑ボタンリリースイベントハンドラ
f_binbio_event_btn_b_release >src/f_binbio_event_btn_b_release.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_event_btn_b_release.o))
fadr=$(calc16 "${a_binbio_event_btn_b_release}+${fsz}")
a_binbio_event_btn_up_release=$(four_digits $fadr)
echo -e "a_binbio_event_btn_up_release=$a_binbio_event_btn_up_release" >>$MAP_FILE_NAME
f_binbio_event_btn_up_release() {
	# 実験セットの初期値がデイジーワールド以外か否か
	if [ "$BINBIO_EXPSET_NUM_INIT" = "$BINBIO_EXPSET_DAISYWORLD" ]; then
		# デイジーワールドの場合

		# push
		lr35902_push_reg regAF
		lr35902_push_reg regBC
		lr35902_push_reg regDE

		# regAへ現在のステータス表示領域の状態を取得
		lr35902_copy_to_regA_from_addr $var_binbio_status_disp_status

		# regA == 評価関数選択表示状態 ?
		lr35902_compare_regA_and $STATUS_DISP_SHOW_CELL_EVAL_SEL
		(
			# 現在のステータス表示領域の状態 == 評価関数選択表示状態 の場合

			# regAへ現在の評価関数番号を取得
			lr35902_copy_to_regA_from_addr $var_binbio_expset_num

			# regA == 固定値を返す ?
			lr35902_compare_regA_and $CELL_EVAL_NUM_FIXEDVAL
			(
				# regA == 固定値を返す の場合

				# 評価関数設定で現在選択中のパラメータ番号変数をゼロクリア
				lr35902_clear_reg regA
				lr35902_copy_to_addr_from_regA $var_binbio_cell_eval_conf_paramno

				# 現在(「固定値を返す」関数の位置)の'→'をクリア
				con_putxy_macro $(calc16_2 "${CELL_EVAL_SEL_FIXEDVAL_TCOORD_X}-1") $CELL_EVAL_SEL_FIXEDVAL_TCOORD_Y ' '

				# 「デイジーワールド」関数の位置へ'→'を配置
				con_putxy_macro $(calc16_2 "${CELL_EVAL_SEL_DAISYWORLD_TCOORD_X}-1") $CELL_EVAL_SEL_DAISYWORLD_TCOORD_Y '→'

				# 評価関数番号を「デイジーワールド」関数の番号へ更新
				lr35902_set_reg regA $CELL_EVAL_NUM_DAISYWORLD
				lr35902_copy_to_addr_from_regA $var_binbio_expset_num
			) >src/f_binbio_event_btn_up_release.fixedval.o
			local sz_fixedval=$(stat -c '%s' src/f_binbio_event_btn_up_release.fixedval.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_fixedval)
			cat src/f_binbio_event_btn_up_release.fixedval.o
		) >src/f_binbio_event_btn_up_release.cell_eval_sel.o
		local sz_cell_eval_sel=$(stat -c '%s' src/f_binbio_event_btn_up_release.cell_eval_sel.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_cell_eval_sel)
		cat src/f_binbio_event_btn_up_release.cell_eval_sel.o

		# pop
		lr35902_pop_reg regDE
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
	fi

	# return
	lr35902_return
}

# バイナリ生物環境用の↓ボタンリリースイベントハンドラ
f_binbio_event_btn_up_release >src/f_binbio_event_btn_up_release.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_event_btn_up_release.o))
fadr=$(calc16 "${a_binbio_event_btn_up_release}+${fsz}")
a_binbio_event_btn_down_release=$(four_digits $fadr)
echo -e "a_binbio_event_btn_down_release=$a_binbio_event_btn_down_release" >>$MAP_FILE_NAME
f_binbio_event_btn_down_release() {
	# 実験セットの初期値がデイジーワールド以外か否か
	if [ "$BINBIO_EXPSET_NUM_INIT" = "$BINBIO_EXPSET_DAISYWORLD" ]; then
		# デイジーワールドの場合

		# push
		lr35902_push_reg regAF
		lr35902_push_reg regBC
		lr35902_push_reg regDE

		# regAへ現在のステータス表示領域の状態を取得
		lr35902_copy_to_regA_from_addr $var_binbio_status_disp_status

		# regA == 評価関数選択表示状態 ?
		lr35902_compare_regA_and $STATUS_DISP_SHOW_CELL_EVAL_SEL
		(
			# 現在のステータス表示領域の状態 == 評価関数選択表示状態 の場合

			# regAへ現在の評価関数番号を取得
			lr35902_copy_to_regA_from_addr $var_binbio_expset_num

			# regA == デイジーワールド ?
			lr35902_compare_regA_and $CELL_EVAL_NUM_DAISYWORLD
			(
				# regA == デイジーワールド の場合

				# 評価関数設定で現在選択中のパラメータ番号変数をゼロクリア
				lr35902_clear_reg regA
				lr35902_copy_to_addr_from_regA $var_binbio_cell_eval_conf_paramno

				# 現在(「デイジーワールド」関数の位置)の'→'をクリア
				con_putxy_macro $(calc16_2 "${CELL_EVAL_SEL_DAISYWORLD_TCOORD_X}-1") $CELL_EVAL_SEL_DAISYWORLD_TCOORD_Y ' '

				# 「固定値を返す」関数の位置へ'→'を配置
				con_putxy_macro $(calc16_2 "${CELL_EVAL_SEL_FIXEDVAL_TCOORD_X}-1") $CELL_EVAL_SEL_FIXEDVAL_TCOORD_Y '→'

				# 評価関数番号を「固定値を返す」関数の番号へ更新
				lr35902_set_reg regA $CELL_EVAL_NUM_FIXEDVAL
				lr35902_copy_to_addr_from_regA $var_binbio_expset_num
			) >src/f_binbio_event_btn_down_release.daisyworld.o
			local sz_daisyworld=$(stat -c '%s' src/f_binbio_event_btn_down_release.daisyworld.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisyworld)
			cat src/f_binbio_event_btn_down_release.daisyworld.o
		) >src/f_binbio_event_btn_down_release.cell_eval_sel.o
		local sz_cell_eval_sel=$(stat -c '%s' src/f_binbio_event_btn_down_release.cell_eval_sel.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_cell_eval_sel)
		cat src/f_binbio_event_btn_down_release.cell_eval_sel.o

		# pop
		lr35902_pop_reg regDE
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
	fi

	# return
	lr35902_return
}

# バイナリ生物環境用の→ボタンリリースイベントハンドラ
f_binbio_event_btn_down_release >src/f_binbio_event_btn_down_release.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_event_btn_down_release.o))
fadr=$(calc16 "${a_binbio_event_btn_down_release}+${fsz}")
a_binbio_event_btn_right_release=$(four_digits $fadr)
echo -e "a_binbio_event_btn_right_release=$a_binbio_event_btn_right_release" >>$MAP_FILE_NAME
f_binbio_event_btn_right_release() {
	# push
	lr35902_push_reg regAF

	# 画像処理中か?
	lr35902_copy_to_regA_from_addr $var_view_img_state
	lr35902_compare_regA_and $GBOS_VIEW_IMG_STAT_DURING_IMG_DISP
	(
		# 画像処理中でない場合

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_event_btn_right_release.nothing_return.o
	local sz_nothing_return=$(stat -c '%s' src/f_binbio_event_btn_right_release.nothing_return.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_nothing_return)
	cat src/f_binbio_event_btn_right_release.nothing_return.o

	# regAへ現在のスライドのバンク・ファイル番号を取得
	lr35902_copy_to_regA_from_addr $var_ss_current_bank_file_num

	# regA < 最後のスライドのバンク・ファイル番号 ?
	lr35902_compare_regA_and $SS_LAST_BANK_FILE_NUM
	(
		# regA < 最後のスライドのバンク・ファイル番号 の場合

		# push
		lr35902_push_reg regBC

		# regAをregBへ退避
		lr35902_copy_to_from regB regA

		# regCへ現在のバンクの最後のファイル番号(現在のバンクのファイル数 - 1)を取得
		lr35902_copy_to_regA_from_addr $GBOS_FS_BASE_ROM
		lr35902_sub_to_regA 01
		lr35902_copy_to_from regC regA

		# regAへ現在のスライドのファイル番号を取得
		lr35902_copy_to_from regA regB
		lr35902_and_to_regA 0f

		# regA(現在のスライドのファイル番号) < regC(現在のバンクの最後のファイル番号) ?
		lr35902_compare_regA_and regC
		(
			# regA < regC の場合

			# regAへ現在のスライドのバンク・ファイル番号をregBから復帰
			lr35902_copy_to_from regA regB

			# regA++
			# ※ 桁上がりはしない想定(regAの下位4ビットは16未満である想定)
			lr35902_inc regA
		) >src/f_binbio_event_btn_right_release.inc_filenum.o
		(
			# regA >= regC の場合

			# regAへ現在のスライドのバンク・ファイル番号をregBから復帰
			lr35902_copy_to_from regA regB

			# regAの上位・下位4ビットを入れ替える
			lr35902_swap_nibbles regA

			# regA++
			# (バンク番号をインクリメント)
			# ※ 桁上がりはしない想定(regAの下位4ビットは16未満である想定)
			lr35902_inc regA

			# regAの上位・下位4ビットを入れ替える
			lr35902_swap_nibbles regA

			# regAの下位4ビット(ファイル番号)を0にする
			lr35902_and_to_regA f0

			# regA < regC の場合の処理を飛ばす
			local sz_inc_filenum=$(stat -c '%s' src/f_binbio_event_btn_right_release.inc_filenum.o)
			lr35902_rel_jump $(two_digits_d $sz_inc_filenum)
		) >src/f_binbio_event_btn_right_release.next_bank.o
		local sz_next_bank=$(stat -c '%s' src/f_binbio_event_btn_right_release.next_bank.o)
		lr35902_rel_jump_with_cond C $(two_digits_d $sz_next_bank)
		cat src/f_binbio_event_btn_right_release.next_bank.o	# regA >= regC の場合
		cat src/f_binbio_event_btn_right_release.inc_filenum.o	# regA < regC の場合

		# 画像表示
		lr35902_call $a_view_img

		# 現在のスライドのバンク・ファイル番号変数を更新
		lr35902_copy_to_addr_from_regA $var_ss_current_bank_file_num

		# pop
		lr35902_pop_reg regBC
	) >src/f_binbio_event_btn_right_release.update_img.o
	local sz_update_img=$(stat -c '%s' src/f_binbio_event_btn_right_release.update_img.o)
	lr35902_rel_jump_with_cond NC $(two_digits_d $sz_update_img)
	cat src/f_binbio_event_btn_right_release.update_img.o

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# バイナリ生物環境用の←ボタンリリースイベントハンドラ
f_binbio_event_btn_right_release >src/f_binbio_event_btn_right_release.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_event_btn_right_release.o))
fadr=$(calc16 "${a_binbio_event_btn_right_release}+${fsz}")
a_binbio_event_btn_left_release=$(four_digits $fadr)
echo -e "a_binbio_event_btn_left_release=$a_binbio_event_btn_left_release" >>$MAP_FILE_NAME
f_binbio_event_btn_left_release() {
	# push
	lr35902_push_reg regAF

	# 画像処理中か?
	lr35902_copy_to_regA_from_addr $var_view_img_state
	lr35902_compare_regA_and $GBOS_VIEW_IMG_STAT_DURING_IMG_DISP
	(
		# 画像処理中でない場合

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_event_btn_left_release.nothing_return.o
	local sz_nothing_return=$(stat -c '%s' src/f_binbio_event_btn_left_release.nothing_return.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_nothing_return)
	cat src/f_binbio_event_btn_left_release.nothing_return.o

	# regAへ現在のスライドのバンク・ファイル番号を取得
	lr35902_copy_to_regA_from_addr $var_ss_current_bank_file_num

	# regA == 最初のスライドのバンク・ファイル番号 ?
	lr35902_compare_regA_and $SS_FIRST_BANK_FILE_NUM
	(
		# regA != 最初のスライドのバンク・ファイル番号 の場合

		# push
		lr35902_push_reg regBC

		# regBへregAを退避
		lr35902_copy_to_from regB regA

		# regAからファイル番号のみを抽出
		lr35902_and_to_regA 0f

		# regA == 0 ?
		(
			# regA == 0 の場合
			# (ファイル番号 == 0 の場合)

			# regAへ現在のスライドのバンク・ファイル番号を復帰
			lr35902_copy_to_from regA regB

			# バンク番号を下位4ビットへ持ってくる
			# (ファイル番号は0なので、この結果の上位4ビットは0)
			lr35902_swap_nibbles regA

			# regA--
			lr35902_dec regA

			# regAを新たなバンク番号としてMBCへ設定
			lr35902_copy_to_addr_from_regA $GB_MBC_ROM_BANK_ADDR

			# 現在のバンク番号変数を更新
			lr35902_copy_to_addr_from_regA $var_current_rom_bank_no

			# regA内でバンク番号を上位4ビットへ移動
			lr35902_swap_nibbles regA

			# regB = regA
			lr35902_copy_to_from regB regA

			# regAへ現在のバンクのファイル数を取得
			lr35902_copy_to_regA_from_addr $GBOS_FS_BASE_ROM

			# regA -= 1
			# (regAへ現在のバンクの最後のファイル番号を設定)
			lr35902_dec regA

			# regA |= regB
			# (regAの上位4ビットへ現在のバンク番号を設定)
			lr35902_or_to_regA regB
		) >src/f_binbio_event_btn_left_release.prev_bank.o
		(
			# regA != 0 の場合
			# (ファイル番号 != 0 の場合)

			# regAへ現在のスライドのバンク・ファイル番号を復帰
			lr35902_copy_to_from regA regB

			# regA--
			lr35902_dec regA

			# regA == 0 の場合の処理を飛ばす
			local sz_prev_bank=$(stat -c '%s' src/f_binbio_event_btn_left_release.prev_bank.o)
			lr35902_rel_jump $(two_digits_d $sz_prev_bank)
		) >src/f_binbio_event_btn_left_release.dec_filenum.o
		local sz_dec_filenum=$(stat -c '%s' src/f_binbio_event_btn_left_release.dec_filenum.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_dec_filenum)
		cat src/f_binbio_event_btn_left_release.dec_filenum.o	# regA != 0 の場合
		cat src/f_binbio_event_btn_left_release.prev_bank.o	# regA == 0 の場合

		# 画像表示
		lr35902_call $a_view_img

		# 現在のスライドのバンク・ファイル番号変数を更新
		lr35902_copy_to_addr_from_regA $var_ss_current_bank_file_num

		# pop
		lr35902_pop_reg regBC
	) >src/f_binbio_event_btn_left_release.update_img.o
	local sz_update_img=$(stat -c '%s' src/f_binbio_event_btn_left_release.update_img.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_update_img)
	cat src/f_binbio_event_btn_left_release.update_img.o

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# バイナリ生物環境用のスタートボタンリリースイベントハンドラ
f_binbio_event_btn_left_release >src/f_binbio_event_btn_left_release.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_event_btn_left_release.o))
fadr=$(calc16 "${a_binbio_event_btn_left_release}+${fsz}")
a_binbio_event_btn_start_release=$(four_digits $fadr)
echo -e "a_binbio_event_btn_start_release=$a_binbio_event_btn_start_release" >>$MAP_FILE_NAME
f_binbio_event_btn_start_release() {
	# push
	lr35902_push_reg regAF

	# スライドショー機能が無効な場合、以下の処理を出力しない
	if [ $SS_ENABLE -eq 1 ]; then
		# regAへ現在の画像表示状態を取得
		lr35902_copy_to_regA_from_addr $var_view_img_state

		# 現在、画像表示なしか?
		lr35902_compare_regA_and $GBOS_VIEW_IMG_STAT_NONE
		(
			# 画像表示なしの場合

			# 現在のスライドのバンク・ファイル番号を変数から取得
			lr35902_copy_to_regA_from_addr $var_ss_current_bank_file_num

			# 画像表示
			lr35902_call $a_view_img

			# pop & return
			lr35902_pop_reg regAF
			lr35902_return
		) | rel_jump_wrapper_binsz NZ forward

		# 現在、tdq消費待ちか?
		lr35902_compare_regA_and $GBOS_VIEW_IMG_STAT_WAIT_FOR_TDQEMP
		(
			# tdq消費待ちの場合

			# pop & return
			lr35902_pop_reg regAF
			lr35902_return
		) | rel_jump_wrapper_binsz NZ forward

		# 現在、画像表示中か?
		lr35902_compare_regA_and $GBOS_VIEW_IMG_STAT_DURING_IMG_DISP
		(
			# 画像表示中の場合

			# 画像表示終了関数を呼び出し
			lr35902_call $a_quit_img

			# pop & return
			lr35902_pop_reg regAF
			lr35902_return
		) | rel_jump_wrapper_binsz NZ forward

		# この関数の内容としてもここまでとする
		return
	fi

	# 実験セットの初期値がデイジーワールド以外か否か
	if [ "$BINBIO_EXPSET_NUM_INIT" != "$BINBIO_EXPSET_DAISYWORLD" ]; then
		# デイジーワールド以外の場合

		# リセットを実施
		## regA(引数)を設定
		lr35902_set_reg regA $BINBIO_EVENT_BTN_START_RELEASE_EXPSET
		## 関数呼び出し
		lr35902_call $a_binbio_reset

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	else
		# デイジーワールドの場合

		# regAへ現在のステータス表示領域の状態を取得
		lr35902_copy_to_regA_from_addr $var_binbio_status_disp_status

		# regA == ソフト説明表示状態 ?
		lr35902_compare_regA_and $STATUS_DISP_SHOW_SOFT_DESC
		(
			# regA == ソフト説明表示状態 の場合

			# pop & return
			lr35902_pop_reg regAF
			lr35902_return
		) >src/f_binbio_event_btn_start_release.showing_soft_desc.o
		local sz_showing_soft_desc=$(stat -c '%s' src/f_binbio_event_btn_start_release.showing_soft_desc.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_showing_soft_desc)
		cat src/f_binbio_event_btn_start_release.showing_soft_desc.o

		# regA == 細胞ステータス情報表示状態 ?
		lr35902_compare_regA_and $STATUS_DISP_SHOW_CELL_INFO
		(
			# regA == 細胞ステータス情報表示状態 の場合

			# 細胞ステータス情報をクリア
			lr35902_call $a_binbio_clear_cell_info
		) >src/f_binbio_event_btn_start_release.showing_cell_info.o
		local sz_showing_cell_info=$(stat -c '%s' src/f_binbio_event_btn_start_release.showing_cell_info.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_showing_cell_info)
		cat src/f_binbio_event_btn_start_release.showing_cell_info.o

		# regA == 評価関数選択表示状態 ?
		lr35902_compare_regA_and $STATUS_DISP_SHOW_CELL_EVAL_SEL
		(
			# regA == 細胞ステータス情報表示状態 の場合

			# 評価関数選択をクリア
			lr35902_call $a_binbio_clear_cell_eval_sel

			# マウスカーソルを表示する
			lr35902_push_reg regBC
			lr35902_push_reg regDE
			cat src/show_mouse_cursor.o
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
		) >src/f_binbio_event_btn_start_release.showing_cell_eval_sel.o
		local sz_showing_cell_eval_sel=$(stat -c '%s' src/f_binbio_event_btn_start_release.showing_cell_eval_sel.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_showing_cell_eval_sel)
		cat src/f_binbio_event_btn_start_release.showing_cell_eval_sel.o

		# regA == 評価関数設定表示状態 ?
		lr35902_compare_regA_and $STATUS_DISP_SHOW_CELL_EVAL_CONF
		(
			# regA == 評価関数設定表示状態 の場合

			# 評価関数設定をクリア
			lr35902_call $a_binbio_clear_cell_eval_conf

			# マウスカーソルを表示する
			lr35902_push_reg regBC
			lr35902_push_reg regDE
			cat src/show_mouse_cursor.o
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC

			# TODO
		) >src/f_binbio_event_btn_start_release.showing_cell_eval_conf.o
		local sz_showing_cell_eval_conf=$(stat -c '%s' src/f_binbio_event_btn_start_release.showing_cell_eval_conf.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_showing_cell_eval_conf)
		cat src/f_binbio_event_btn_start_release.showing_cell_eval_conf.o

		# ソフト説明を配置
		lr35902_call $a_binbio_place_soft_desc

		# 現在のステータス表示領域の状態 = ソフト説明表示状態
		lr35902_set_reg regA $STATUS_DISP_SHOW_SOFT_DESC
		lr35902_copy_to_addr_from_regA $var_binbio_status_disp_status

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	fi
}

# バイナリ生物環境用のセレクトボタンリリースイベントハンドラ
f_binbio_event_btn_start_release >src/f_binbio_event_btn_start_release.o
fsz=$(to16 $(stat -c '%s' src/f_binbio_event_btn_start_release.o))
fadr=$(calc16 "${a_binbio_event_btn_start_release}+${fsz}")
a_binbio_event_btn_select_release=$(four_digits $fadr)
echo -e "a_binbio_event_btn_select_release=$a_binbio_event_btn_select_release" >>$MAP_FILE_NAME
f_binbio_event_btn_select_release() {
	# push
	lr35902_push_reg regAF

	# 実験セットの初期値がデイジーワールド以外か否か
	if [ "$BINBIO_EXPSET_NUM_INIT" != "$BINBIO_EXPSET_DAISYWORLD" ]; then
		# デイジーワールド以外の場合

		# リセットを実施
		## regA(引数)を設定
		lr35902_set_reg regA $BINBIO_EVENT_BTN_SELECT_RELEASE_EXPSET
		## 関数呼び出し
		lr35902_call $a_binbio_reset
	else
		# デイジーワールドの場合
		# ※ 評価関数選択と評価関数設定の表示モードの処理は e0455ee のコミットで一時的に削除した

		# regAへ現在のステータス表示領域の状態を取得
		lr35902_copy_to_regA_from_addr $var_binbio_status_disp_status

		# regA == ソフト説明表示状態 ?
		lr35902_compare_regA_and $STATUS_DISP_SHOW_SOFT_DESC
		(
			# regA == ソフト説明表示状態 の場合

			# ソフト説明をクリア
			lr35902_call $a_binbio_clear_soft_desc

			# 細胞ステータス情報のラベルを画面へ配置
			lr35902_call $a_binbio_place_cell_info_labels

			# 現在のステータス表示領域の状態 = 細胞ステータス情報表示状態
			lr35902_set_reg regA $STATUS_DISP_SHOW_CELL_INFO
			lr35902_copy_to_addr_from_regA $var_binbio_status_disp_status

			# pop & return
			lr35902_pop_reg regAF
			lr35902_return
		) >src/f_binbio_event_btn_select_release.showing_soft_desc.o
		local sz_showing_soft_desc=$(stat -c '%s' src/f_binbio_event_btn_select_release.showing_soft_desc.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_showing_soft_desc)
		cat src/f_binbio_event_btn_select_release.showing_soft_desc.o

		# regA == 細胞ステータス情報表示状態 ?
		lr35902_compare_regA_and $STATUS_DISP_SHOW_CELL_INFO
		(
			# 現在のステータス表示領域の状態 == 細胞ステータス情報表示状態 の場合

			# push
			lr35902_push_reg regBC
			lr35902_push_reg regDE

			# 細胞ステータス情報をクリア
			lr35902_call $a_binbio_clear_cell_info

			# ソフト説明を画面へ配置
			lr35902_call $a_binbio_place_soft_desc

			# 現在のステータス表示領域の状態 = ソフト説明表示状態
			lr35902_set_reg regA $STATUS_DISP_SHOW_SOFT_DESC
			lr35902_copy_to_addr_from_regA $var_binbio_status_disp_status

			# pop & return
			lr35902_pop_reg regDE
			lr35902_pop_reg regBC
			lr35902_pop_reg regAF
			lr35902_return
		) >src/f_binbio_event_btn_select_release.showing_cell_info.o
		local sz_showing_cell_info=$(stat -c '%s' src/f_binbio_event_btn_select_release.showing_cell_info.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_showing_cell_info)
		cat src/f_binbio_event_btn_select_release.showing_cell_info.o

		# もしこのパスに来るようであれば無限ループで止める
		infinite_halt
	fi

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}
f_binbio_event_btn_select_release >src/f_binbio_event_btn_select_release.o

# V-Blankハンドラ
# f_vblank_hdlr() {
	# V-Blank/H-Blank時の処理は、
	# mainのHaltループ内でその他の処理と直列に実施する
	# ∵ 割り込み時にフラグレジスタをスタックへプッシュしない上に
	#    手動でプッシュする命令も無いため
	#    任意のタイミングで割り込みハンドラが実施される設計にするには
	#    割り込まれる可能性のある処理全てで
	#    「フラグレジスタへ影響を与える命令〜条件付きジャンプ」
	#    をdi〜eiで保護する必要が出てくる
	#    また、現状の分量であれば全てV-Blank期間に収まる

	# lr35902_ei_and_ret
# }

# 1000h〜の領域に配置される
global_functions() {
	cat src/f_compare_regHL_and_regDE.o
	cat src/f_div_regHL_by_regDE.o
	cat src/f_get_mouse_tcoord.o
	cat src/f_tcoord_to_addr.o
	cat src/f_wtcoord_to_tcoord.o
	cat src/f_tcoord_to_mrraddr.o
	cat src/f_mrraddr_to_tcoord.o
	cat src/f_clear_bg.o
	cat src/f_init_tmrr.o
	cat src/f_lay_tile_at_tcoord.o
	cat src/f_lay_tile_at_wtcoord.o
	cat src/f_lay_tiles_at_tcoord_to_right.o
	cat src/f_lay_tiles_at_wtcoord_to_right.o
	cat src/f_lay_tiles_at_tcoord_to_low.o
	cat src/f_lay_tiles_at_wtcoord_to_low.o
	cat src/f_objnum_to_addr.o
	cat src/f_set_objpos.o
	cat src/f_lay_icon.o
	cat src/f_clr_win.o
	cat src/f_view_txt.o
	cat src/f_view_txt_cyc.o
	cat src/f_clr_win_cyc.o
	cat src/f_tn_to_addr.o
	cat src/f_view_img.o
	cat src/f_quit_img.o
	cat src/f_rstr_tiles.o
	cat src/f_rstr_tiles_cyc.o
	cat src/f_view_dir.o
	cat src/f_view_dir_cyc.o
	cat src/f_check_click_icon_area_x.o
	cat src/f_check_click_icon_area_y.o
	cat src/f_init_con.o
	cat src/f_run_exe.o
	cat src/f_run_exe_cyc.o
	cat src/f_init_tdq.o
	cat src/f_enq_tdq.o
	cat src/f_byte_to_tile.o
	cat src/f_get_file_addr_and_type.o
	cat src/f_right_click_event.o
	cat src/f_select_rom.o
	cat src/f_select_ram.o
	cat src/f_exit_exe.o
	cat src/f_putch.o
	cat src/f_delch_tadr_num.o
	cat src/f_clr_con.o
	cat src/f_print.o
	cat src/f_print_xy.o
	cat src/f_putxy.o
	cat src/f_getxy.o
	cat src/f_click_event.o
	cat src/f_print_regA.o
	cat src/f_print_regA_signed_dec.o
	cat src/f_tile_to_byte.o
	cat src/f_get_rnd.o
	cat src/f_tdq_enq.o
	cat src/f_binbio_get_tile_family_num.o
	cat src/f_binbio_find_cell_data_by_tile_xy.o
	cat src/f_binbio_cell_alloc.o
	cat src/f_binbio_cell_set_default_daisy.o
	cat src/f_binbio_cell_set_default_predator.o
	cat src/f_binbio_cell_set_tile_num.o
	cat src/f_binbio_place_cell.o
	cat src/f_binbio_cell_death.o
	cat src/f_binbio_cell_eval_family.o
	cat src/f_binbio_cell_eval_helloworld.o
	cat src/f_binbio_cell_eval_daisy.o
	cat src/f_binbio_cell_eval_hello.o
	cat src/f_binbio_cell_eval_daisyworld.o
	cat src/f_binbio_cell_eval_fixedval.o
	cat src/f_binbio_cell_eval_predator.o
	cat src/f_binbio_cell_eval.o
	cat src/f_binbio_cell_metabolism_and_motion.o
	cat src/f_binbio_get_code_comp_all.o
	cat src/f_binbio_get_code_comp_hello.o
	cat src/f_binbio_get_code_comp.o
	cat src/f_binbio_cell_growth_daisy.o
	cat src/f_binbio_cell_growth_predator_prey.o
	cat src/f_binbio_cell_growth_predator_check_and_prey.o
	cat src/f_binbio_cell_growth_predator.o
	cat src/f_binbio_cell_growth.o
	cat src/f_binbio_cell_is_dividable.o
	cat src/f_binbio_clear_cell_data_area.o
	cat src/f_binbio_get_pointed_cell_addr.o
	cat src/f_binbio_cell_find_free_neighbor.o
	cat src/f_binbio_cell_mutation_all.o
	cat src/f_binbio_cell_mutation_alphabet.o
	cat src/f_binbio_cell_mutation_daisy.o
	cat src/f_binbio_cell_mutation_predator.o
	cat src/f_binbio_cell_mutation.o
	cat src/f_binbio_cell_division.o
	cat src/f_binbio_cell_division_fix.o
	cat src/f_binbio_select_next_cell.o
	cat src/f_binbio_place_soft_desc.o
	cat src/f_binbio_clear_soft_desc.o
	cat src/f_binbio_update_status_disp.o
	cat src/f_binbio_place_cell_info_labels.o
	cat src/f_binbio_place_cell_info_val.o
	cat src/f_binbio_clear_cell_info.o
	cat src/f_binbio_place_cell_eval_sel.o
	cat src/f_binbio_clear_cell_eval_sel.o
	cat src/f_binbio_get_var_from_current_cell_eval_and_param.o
	cat src/f_binbio_get_tadr_from_current_cell_eval_and_param.o
	cat src/f_binbio_place_fixedval_param.o
	cat src/f_binbio_place_cell_eval_conf.o
	cat src/f_binbio_clear_cell_eval_conf.o
	cat src/f_binbio_init.o
	cat src/f_binbio_reset.o
	cat src/f_binbio_do_cycle.o
	cat src/f_binbio_event_btn_a_release.o
	cat src/f_binbio_event_btn_b_release.o
	cat src/f_binbio_event_btn_up_release.o
	cat src/f_binbio_event_btn_down_release.o
	cat src/f_binbio_event_btn_right_release.o
	cat src/f_binbio_event_btn_left_release.o
	cat src/f_binbio_event_btn_start_release.o
	cat src/f_binbio_event_btn_select_release.o
}

gbos_vec() {
	dd if=/dev/zero bs=1 count=64 2>/dev/null

	# V-Blank (INT 40h)
	# lr35902_abs_jump $a_vblank_hdlr
	# dd if=/dev/zero bs=1 count=$((8 - 3)) 2>/dev/null
	lr35902_ei_and_ret
	dd if=/dev/zero bs=1 count=7 2>/dev/null

	# LCD STAT (INT 48h)
	lr35902_ei_and_ret
	dd if=/dev/zero bs=1 count=7 2>/dev/null

	# Timer (INT 50h)
	lr35902_push_reg regAF				     # 1
	lr35902_push_reg regHL				     # 1
	lr35902_set_reg regHL $var_timer_handler	     # 3
	lr35902_abs_jump ptrHL				     # 1
	dd if=/dev/zero bs=1 count=2 2>/dev/null	     # 2

	# Serial (INT 58h)
	lr35902_ei_and_ret
	dd if=/dev/zero bs=1 count=7 2>/dev/null

	# Joypad (INT 60h)
	lr35902_ei_and_ret
	dd if=/dev/zero bs=1 count=159 2>/dev/null
}

gbos_const() {
	# 文字タイルデータを配置
	char_tiles >src/char_tiles.o
	cat src/char_tiles.o

	# 文字タイルデータと定数データの間のパディングを配置
	local sz_char_tiles=$(stat -c '%s' src/char_tiles.o)
	local sz_tiledata_area=$(bc <<< "ibase=16;${GBOS_ROM_CONST_DATA_START^^} - ${GBOS_ROM_TILE_DATA_START^^}")
	local sz_padding=$((sz_tiledata_area - sz_char_tiles))
	if [ $sz_padding -lt 0 ]; then
		echo "Error: Padding size between char tiles and const data < 0 (sz_padding = $sz_padding)" 1>&2
		return 1
	fi
	dd if=/dev/zero bs=1 count=$sz_padding status=none

	# 定数データを配置
	cat src/const_data.o

	# 定数データとグローバル関数の間のパディングを配置
	local sz_const_data=$(stat -c '%s' src/const_data.o)
	local sz_const_data_area=$(bc <<< "ibase=16;${GBOS_GFUNC_START^^} - ${GBOS_ROM_CONST_DATA_START^^}")
	sz_padding=$((sz_const_data_area - sz_const_data))
	if [ $sz_padding -lt 0 ]; then
		echo "Error: Padding size between const data and global functions < 0 (sz_padding = $sz_padding)" 1>&2
		return 1
	fi
	dd if=/dev/zero bs=1 count=$sz_padding status=none

	# グローバル関数を配置
	global_functions
}

lay_tiles_in_grid() {
	lr35902_set_reg regHL 9800
	lr35902_set_reg regB 20
	lr35902_clear_reg regA
	# (
		lr35902_set_reg regC 20
		echo -en '\xee\x01'	# xor 1
		# (
			lr35902_copyinc_to_ptrHL_from_regA
			echo -en '\xee\x01'	# xor 1
			lr35902_dec regC
			lr35902_rel_jump_with_cond NZ $(two_comp 06)
		# )
		lr35902_dec regB
		lr35902_rel_jump_with_cond NZ $(two_comp 0d)
	# )
}

dump_all_tiles() {
	local rel_sz
	lr35902_set_reg regHL $GBOS_BG_TILEMAP_START
	lr35902_set_reg regB $GBOS_NUM_ALL_TILES
	lr35902_set_reg regDE $(four_digits $GB_NON_DISP_WIDTH_T)
	lr35902_clear_reg regC
	(
		lr35902_copy_to_from regA regC
		lr35902_copyinc_to_ptrHL_from_regA
		lr35902_copy_to_from regA regL
		lr35902_and_to_regA 1f
		lr35902_compare_regA_and $GB_DISP_WIDTH_T
		(
			lr35902_add_to_regHL regDE
		) >src/dump_all_tiles.1.o
		rel_sz=$(stat -c '%s' src/dump_all_tiles.1.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $rel_sz)
		cat src/dump_all_tiles.1.o
		lr35902_inc regC
		lr35902_dec regB
	) >src/dump_all_tiles.2.o
	cat src/dump_all_tiles.2.o
	rel_sz=$(stat -c '%s' src/dump_all_tiles.2.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((rel_sz + 2)))
}

hide_all_objs() {
	lr35902_clear_reg regA
	lr35902_set_reg regC $GB_NUM_ALL_OBJS
	(
		lr35902_dec regC
		lr35902_call $a_set_objpos
		lr35902_compare_regA_and regC
	) >src/hide_all_objs.1.o
	cat src/hide_all_objs.1.o
	local sz=$(stat -c '%s' src/hide_all_objs.1.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz+2)))
}

set_win_coord() {
	local xt=$1
	local yt=$2
	lr35902_set_reg regA $xt
	lr35902_copy_to_addr_from_regA $var_win_xt
	lr35902_set_reg regA $yt
	lr35902_copy_to_addr_from_regA $var_win_yt
}

draw_blank_window() {
	# local sz

	# タイトルバーを描画

	lr35902_set_reg regA 06	# _
	lr35902_set_reg regC $GBOS_WIN_WIDTH_T
	lr35902_set_reg regD 00
	lr35902_set_reg regE 01
	lr35902_call $a_lay_tiles_at_wtcoord_to_right

	lr35902_set_reg regD $GBOS_WIN_HEIGHT_T
	lr35902_call $a_lay_tiles_at_wtcoord_to_right

	lr35902_set_reg regA 02	# -(上付き)
	lr35902_set_reg regD 02
	lr35902_call $a_lay_tiles_at_wtcoord_to_right

	lr35902_set_reg regA $GBOS_TILE_NUM_LIGHT_GRAY
	lr35902_set_reg regC $(calc16 "${GBOS_WIN_WIDTH_T}-3")
	lr35902_set_reg regD 01
	lr35902_set_reg regE 02
	lr35902_call $a_lay_tiles_at_wtcoord_to_right

	lr35902_set_reg regA 04	# |(右付き)
	lr35902_set_reg regC $GBOS_WIN_HEIGHT_T
	lr35902_set_reg regD 01
	lr35902_set_reg regE 00
	lr35902_call $a_lay_tiles_at_wtcoord_to_low

	lr35902_set_reg regA 08	# |(左付き)
	lr35902_set_reg regE $(calc16 "${GBOS_WIN_WIDTH_T}+1")
	lr35902_call $a_lay_tiles_at_wtcoord_to_low

	lr35902_set_reg regA $GBOS_TILE_NUM_FUNC_BTN
	lr35902_set_reg regC 01
	lr35902_set_reg regE 01
	lr35902_call $a_lay_tiles_at_wtcoord_to_low

	lr35902_set_reg regA $GBOS_TILE_NUM_MINI_BTN
	lr35902_set_reg regC 01
	lr35902_set_reg regE $(calc16 "${GBOS_WIN_WIDTH_T}-1")
	lr35902_call $a_lay_tiles_at_wtcoord_to_low

	lr35902_set_reg regA $GBOS_TILE_NUM_MAXI_BTN
	lr35902_set_reg regC 01
	lr35902_set_reg regE ${GBOS_WIN_WIDTH_T}
	lr35902_call $a_lay_tiles_at_wtcoord_to_low
}

# TODO グローバル関数化
obj_init() {
	local oam_num=$1
	local y=$2
	local x=$3
	local tile_num=$4
	local attr=$5

	local oam_addr=$(calc16 "${GB_OAM_BASE}+(${oam_num}*${GB_OAM_SZ})")
	lr35902_set_reg regHL $oam_addr

	lr35902_set_reg regA $y
	lr35902_copyinc_to_ptrHL_from_regA

	lr35902_set_reg regA $x
	lr35902_copyinc_to_ptrHL_from_regA

	lr35902_set_reg regA $tile_num
	lr35902_copyinc_to_ptrHL_from_regA

	lr35902_set_reg regA $attr
	lr35902_copyinc_to_ptrHL_from_regA
}

# レジスタAをシェル引数で指定されたオブジェクト番号のY座標に設定
obj_set_y() {
	local oam_num=$1
	local oam_addr=$(calc16 "${GB_OAM_BASE}+(${oam_num}*${GB_OAM_SZ})")
	lr35902_set_reg regHL $oam_addr
	lr35902_copy_to_ptrHL_from regA
}

# シェル引数で指定されたオブジェクト番号のY座標をレジスタAに取得
obj_get_y() {
	local oam_num=$1
	local oam_addr=$(calc16 "${GB_OAM_BASE}+(${oam_num}*${GB_OAM_SZ})")
	lr35902_set_reg regHL $oam_addr
	lr35902_copy_to_from regA ptrHL
}

# 処理棒の初期化
proc_bar_init() {
	if [ "${debug_mode}" = "true" ]; then
		# 処理棒を描画
		obj_init $GBOS_OAM_NUM_PCB $GB_DISP_HEIGHT $GB_DISP_WIDTH \
			 $GBOS_TILE_NUM_UP_ARROW $GBOS_OBJ_DEF_ATTR

		# 関連する変数の初期化
		lr35902_clear_reg regA
		lr35902_copy_to_addr_from_regA $var_dbg_over_vblank
	fi
}

# 処理棒の開始時点設定
proc_bar_begin() {
	if [ "${debug_mode}" = "true" ]; then
		# 前回vblank期間を超えていたかチェック
		obj_get_y $GBOS_OAM_NUM_PCB
		lr35902_compare_regA_and $GBOS_OBJ_HEIGHT
		(
			lr35902_set_reg regA 01
			lr35902_copy_to_addr_from_regA $var_dbg_over_vblank
		) >src/proc_bar_begin.1.o
		local sz_1=$(stat -c '%s' src/proc_bar_begin.1.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
		cat src/proc_bar_begin.1.o

		# 処理棒をMAX設定
		# 一番高い位置に処理棒OBJのY座標を設定する
		# ループ処理末尾でその時のLYに応じて設定し直すが
		# 末尾に至るまでの間にVブランクを終えた場合、
		# 処理棒は一番高い位置で残ることになる
		# (それにより、Vブランク期間内にループ処理を終えられなかった事がわかる)
		lr35902_set_reg regA $GBOS_OBJ_HEIGHT
		obj_set_y $GBOS_OAM_NUM_PCB
	fi
}

# 処理棒の終了時点設定
proc_bar_end() {
	if [ "${debug_mode}" = "true" ]; then
		# [処理棒をLYに応じて設定]
		lr35902_copy_to_regA_from_ioport $GB_IO_LY
		lr35902_sub_to_regA $GB_DISP_HEIGHT
		lr35902_compare_regA_and 00
		(
			# A == 0 の場合
			lr35902_set_reg regA $GB_DISP_HEIGHT
		) >src/proc_bar_end.3.o
		(
			# A != 0 の場合
			lr35902_copy_to_from regC regA
			lr35902_set_reg regA $GB_DISP_HEIGHT
			(
				lr35902_sub_to_regA 0e
				lr35902_dec regC
			) >src/proc_bar_end.1.o
			cat src/proc_bar_end.1.o
			local sz_1=$(stat -c '%s' src/proc_bar_end.1.o)
			lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_1 + 2)))

			# A == 0の場合の処理を飛ばす
			local sz_3=$(stat -c '%s' src/proc_bar_end.3.o)
			lr35902_rel_jump $(two_digits_d $sz_3)
		) >src/proc_bar_end.2.o
		local sz_2=$(stat -c '%s' src/proc_bar_end.2.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
		cat src/proc_bar_end.2.o
		cat src/proc_bar_end.3.o

		obj_set_y $GBOS_OAM_NUM_PCB
	fi
}

init() {
	local i

	# 割り込みは一旦無効にする
	lr35902_disable_interrupts

	# SPをFFFE(HMEMの末尾)に設定
	lr35902_set_regHL_and_SP fffe

	# MBCへ初期値のROMバンク番号を設定
	lr35902_set_reg regA $GBOS_ROM_BANK_NO_INIT
	lr35902_copy_to_addr_from_regA $GB_MBC_ROM_BANK_ADDR

	# 現在のROMバンク番号を変数へ反映
	lr35902_copy_to_addr_from_regA $var_current_rom_bank_no

	# # カートリッジ搭載RAMの有効化
	# lr35902_set_reg regA $GB_MBC_RAM_EN_VAL
	# lr35902_copy_to_addr_from_regA $GB_MBC_RAM_EN_ADDR

	# スクロールレジスタクリア
	gb_reset_scroll_pos

	# ウィンドウ座標レジスタへ初期値設定
	gb_set_window_pos $GBOS_WX_DEF $GBOS_WY_DEF

	# V-Blankの開始を待つ
	gb_wait_for_vblank_to_start

	# LCDを停止する
	# - 停止の間はVRAMとOAMに自由にアクセスできる(vblankとか関係なく)
	lr35902_set_reg regA ${GBOS_LCDC_BASE}
	lr35902_copy_to_ioport_from_regA $GB_IO_LCDC

	# パレット初期化
	gb_set_palette_to_default

	# タイルデータをVRAMのタイルデータ領域へロード
	load_all_tiles

	# 背景タイルマップを白タイル(タイル番号0)で初期化
	lr35902_call $a_clear_bg

	# OAMを初期化(全て非表示にする)
	hide_all_objs

	# ウィンドウ座標(タイル番目)の変数へデフォルト値設定
	set_win_coord $GBOS_WX_DEF $GBOS_WY_DEF

	# ファイルシステム先頭アドレス変数をデフォルト値で初期化
	lr35902_set_reg regA $(echo $GBOS_FS_BASE_DEF | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_fs_base_bh
	lr35902_set_reg regA $(echo $GBOS_FS_BASE_DEF | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_fs_base_th

	# マウスカーソルを描画
	obj_init $GBOS_OAM_NUM_CSL $GBOS_OBJ_HEIGHT $GBOS_OBJ_WIDTH \
		 $GBOS_TILE_NUM_CSL $GBOS_OBJ_DEF_ATTR

	# コンソールの初期化
	lr35902_call $a_init_con

	# 処理棒の初期化
	proc_bar_init

	# V-Blank(b0)の割り込みのみ有効化
	lr35902_set_reg regA 01
	lr35902_copy_to_ioport_from_regA $GB_IO_IE

	# 変数初期化
	# - マウスカーソルX,Y座標を画面左上で初期化
	lr35902_set_reg regA $GBOS_OBJ_WIDTH
	lr35902_copy_to_addr_from_regA $var_mouse_x
	lr35902_set_reg regA $GBOS_OBJ_HEIGHT
	lr35902_copy_to_addr_from_regA $var_mouse_y
	# - 入力状態を示す変数をゼロクリア
	lr35902_clear_reg regA
	lr35902_copy_to_addr_from_regA $var_btn_stat
	lr35902_copy_to_addr_from_regA $var_prv_btn
	# - アプリ用ボタンリリースフラグをゼロクリア
	lr35902_copy_to_addr_from_regA $var_app_release_btn
	# - 関数実行のエラー状態をゼロクリア
	lr35902_copy_to_addr_from_regA $var_error
	# - 実行ファイル用変数をゼロクリア
	lr35902_copy_to_addr_from_regA $var_exe_1
	lr35902_copy_to_addr_from_regA $var_exe_2
	lr35902_copy_to_addr_from_regA $var_exe_3
	# - 乱数用変数をゼロクリア
	lr35902_copy_to_addr_from_regA $var_lgcs_xn
	lr35902_copy_to_addr_from_regA $var_lgcs_tile_sum
	# - ウィンドウステータスをディレクトリ表示中で初期化
	lr35902_set_bitN_of_reg $GBOS_WST_BITNUM_DIR regA
	lr35902_copy_to_addr_from_regA $var_win_stat
	# - tdq.head = tdq.tail = TDQ_FIRST
	lr35902_set_reg regA $(echo $GBOS_TDQ_FIRST | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_tdq_head_bh
	lr35902_copy_to_addr_from_regA $var_tdq_tail_bh
	lr35902_set_reg regA $(echo $GBOS_TDQ_FIRST | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_tdq_head_th
	lr35902_copy_to_addr_from_regA $var_tdq_tail_th
	# - tdq.stat = is_empty
	lr35902_set_reg regA 01
	lr35902_copy_to_addr_from_regA $var_tdq_stat
	# - マウス有効化
	lr35902_copy_to_addr_from_regA $var_mouse_enable
	# - 画像表示ステータスを画像表示なしで初期化
	lr35902_set_reg regA $GBOS_VIEW_IMG_STAT_NONE
	lr35902_copy_to_addr_from_regA $var_view_img_state
	# - slide show: 現在のスライドのファイル番号の初期値
	lr35902_set_reg regA $SS_CURRENT_BANK_FILE_NUM_INIT
	lr35902_copy_to_addr_from_regA $var_ss_current_bank_file_num
	# - タイマーハンドラ初期化
	timer_init_handler

	# タイルミラー領域の初期化
	lr35902_call $a_init_tmrr

	# バイナリ生物環境の初期化
	## regA(引数)を設定
	lr35902_set_reg regA $BINBIO_EXPSET_NUM_INIT
	## 関数呼び出し
	lr35902_call $a_binbio_init

	# 現状、タイマーは使っていないので明示的に止めておく
	lr35902_copy_to_regA_from_ioport $GB_IO_TAC
	lr35902_and_to_regA $GB_TAC_MASK_START
	lr35902_copy_to_ioport_from_regA $GB_IO_TAC

	# # タイマー設定&開始
	# lr35902_copy_to_regA_from_ioport $GB_IO_TAC
	# lr35902_or_to_regA $(calc16_2 "$GB_TAC_BIT_START+$GB_TAC_BIT_HZ_262144")
	# lr35902_copy_to_ioport_from_regA $GB_IO_TAC

	# サウンドの初期化
	# - サウンド無効化(使う時にONにする)
	lr35902_copy_to_regA_from_ioport $GB_IO_NR52
	lr35902_res_bitN_of_reg $GB_NR52_BITNUM_ALL_ONOFF regA
	lr35902_copy_to_ioport_from_regA $GB_IO_NR52

	# LCD再開
	lr35902_set_reg regA $(calc16 "${GBOS_LCDC_BASE}+${GB_LCDC_BIT_DE}")
	lr35902_copy_to_ioport_from_regA $GB_IO_LCDC

	# 割り込み有効化
	lr35902_enable_interrupts

	# 安定待ち
	# この待ちが無い状態だと、エミュレータによっては(binjgbで確認)、
	# tdqの最初の方のタイルがいくつか表示されない状態に陥る。
	# ひとまず以下のようにVブランク10回分の待ちを入れた所、表示されるようになった。
	# もっと短くても良いのかもしれないが、どれくらい短くても大丈夫かは未確認。
	for i in $(seq 10); do
		lr35902_halt
	done
}

# マウスカーソル座標更新
# in : regD - 現在のキーの状態
update_mouse_cursor() {
	local sz

	# マウスカーソル座標を変数から取得
	## regB ← X座標
	lr35902_copy_to_regA_from_addr $var_mouse_x
	lr35902_copy_to_from regB regA
	## regC ← Y座標
	lr35902_copy_to_regA_from_addr $var_mouse_y
	lr35902_copy_to_from regC regA

	# ↓の押下状態確認
	lr35902_copy_to_from regA regD
	lr35902_and_to_regA $GBOS_DOWN_KEY_MASK
	(
		lr35902_inc regC
	) >src/update_mouse_cursor.1.o
	sz=$(stat -c '%s' src/update_mouse_cursor.1.o)
	lr35902_rel_jump_with_cond Z $(two_digits $sz)
	cat src/update_mouse_cursor.1.o

	# ↑の押下状態確認
	lr35902_copy_to_from regA regD
	lr35902_and_to_regA $GBOS_UP_KEY_MASK
	(
		lr35902_dec regC
	) >src/update_mouse_cursor.2.o
	sz=$(stat -c '%s' src/update_mouse_cursor.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits $sz)
	cat src/update_mouse_cursor.2.o

	# ←の押下状態確認
	lr35902_copy_to_from regA regD
	lr35902_and_to_regA $GBOS_LEFT_KEY_MASK
	(
		lr35902_dec regB
	) >src/update_mouse_cursor.3.o
	sz=$(stat -c '%s' src/update_mouse_cursor.3.o)
	lr35902_rel_jump_with_cond Z $(two_digits $sz)
	cat src/update_mouse_cursor.3.o

	# →の押下状態確認
	lr35902_copy_to_from regA regD
	lr35902_and_to_regA $GBOS_RIGHT_KEY_MASK
	(
		lr35902_inc regB
	) >src/update_mouse_cursor.4.o
	sz=$(stat -c '%s' src/update_mouse_cursor.4.o)
	lr35902_rel_jump_with_cond Z $(two_digits $sz)
	cat src/update_mouse_cursor.4.o

	# OAM更新
	lr35902_copy_to_from regA regC
	lr35902_set_reg regC $GBOS_OAM_NUM_CSL
	lr35902_call $a_set_objpos

	# 変数へ反映
	lr35902_copy_to_addr_from_regA $var_mouse_y
	lr35902_copy_to_from regA regB
	lr35902_copy_to_addr_from_regA $var_mouse_x
}

# ボタンリリースに応じた処理
# in : regA - リリースされたボタン
btn_release_handler() {
	local sz

	# Bボタンの確認
	lr35902_test_bitN_of_reg $GBOS_B_KEY_BITNUM regA
	(
		lr35902_call $a_binbio_event_btn_b_release
	) >src/btn_release_handler.1.o
	sz=$(stat -c '%s' src/btn_release_handler.1.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/btn_release_handler.1.o

	# Aボタンの確認
	lr35902_test_bitN_of_reg $GBOS_A_KEY_BITNUM regA
	(
		lr35902_call $a_binbio_event_btn_a_release
	) >src/btn_release_handler.2.o
	sz=$(stat -c '%s' src/btn_release_handler.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/btn_release_handler.2.o

	# ↑ボタンの確認
	lr35902_test_bitN_of_reg $GBOS_UP_KEY_BITNUM regA
	(
		lr35902_call $a_binbio_event_btn_up_release
	) >src/btn_release_handler.up.o
	sz=$(stat -c '%s' src/btn_release_handler.up.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/btn_release_handler.up.o

	# ↓ボタンの確認
	lr35902_test_bitN_of_reg $GBOS_DOWN_KEY_BITNUM regA
	(
		lr35902_call $a_binbio_event_btn_down_release
	) >src/btn_release_handler.down.o
	sz=$(stat -c '%s' src/btn_release_handler.down.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/btn_release_handler.down.o

	# →ボタンの確認
	lr35902_test_bitN_of_reg $GBOS_RIGHT_KEY_BITNUM regA
	(
		lr35902_call $a_binbio_event_btn_right_release
	) >src/btn_release_handler.right.o
	sz=$(stat -c '%s' src/btn_release_handler.right.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/btn_release_handler.right.o

	# ←ボタンの確認
	lr35902_test_bitN_of_reg $GBOS_LEFT_KEY_BITNUM regA
	(
		lr35902_call $a_binbio_event_btn_left_release
	) >src/btn_release_handler.left.o
	sz=$(stat -c '%s' src/btn_release_handler.left.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/btn_release_handler.left.o

	# セレクトボタンの確認
	lr35902_test_bitN_of_reg $GBOS_SELECT_KEY_BITNUM regA
	(
		lr35902_call $a_binbio_event_btn_select_release
	) >src/btn_release_handler.3.o
	sz=$(stat -c '%s' src/btn_release_handler.3.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/btn_release_handler.3.o

	# スタートボタンの確認
	lr35902_test_bitN_of_reg $GBOS_START_KEY_BITNUM regA
	(
		lr35902_call $a_binbio_event_btn_start_release
	) >src/btn_release_handler.4.o
	sz=$(stat -c '%s' src/btn_release_handler.4.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/btn_release_handler.4.o
}

# タイル描画キュー処理
# 書き換え不可レジスタ: regD
# (変更する場合はpush/popすること)
tdq_handler() {
	lr35902_copy_to_regA_from_addr $var_tdq_stat
	lr35902_test_bitN_of_reg $GBOS_TDQ_STAT_BITNUM_EMPTY regA
	(
		# tdq is not empty

		# push
		lr35902_push_reg regDE

		# HL = tdq.head
		lr35902_copy_to_regA_from_addr $var_tdq_head_bh
		lr35902_copy_to_from regL regA
		lr35902_copy_to_regA_from_addr $var_tdq_head_th
		lr35902_copy_to_from regH regA

		# 1周期の最大描画タイル数をCへ設定
		lr35902_set_reg regC $GBOS_TDQ_MAX_DRAW_TILES

		(
			# E = (HL++)
			lr35902_copyinc_to_regA_from_ptrHL
			lr35902_copy_to_from regE regA
			# D = (HL++)
			lr35902_copyinc_to_regA_from_ptrHL
			lr35902_copy_to_from regD regA
			# A = (HL++)
			lr35902_copyinc_to_regA_from_ptrHL

			# (DE) = A
			lr35902_copy_to_from ptrDE regA

			# この時、regDEにはキューに積まれたアドレス
			# (tdqで書き込むアドレス)が書かれている

			# regAを作業に使うため、regBへ退避
			lr35902_copy_to_from regB regA

			# regDEは背景マップ領域のアドレスか?
			# ※ ここでは単に上位8ビットを0xfcとandを取った結果が
			# 　 0x98と等しいか否かで判断している。
			lr35902_copy_to_from regA regD
			lr35902_and_to_regA fc
			lr35902_compare_regA_and 98
			(
				# タイルミラー領域(0xDC00-)更新
				lr35902_copy_to_from regA regD
				lr35902_and_to_regA $GBOS_TOFS_MASK_TH
				lr35902_add_to_regA $GBOS_TMRR_BASE_TH
				lr35902_copy_to_from regD regA
				lr35902_copy_to_from regA regB
				lr35902_copy_to_from ptrDE regA
			) | rel_jump_wrapper_binsz NZ forward

			# L == TDQ_END[7:0] ?
			lr35902_copy_to_from regA regL
			lr35902_compare_regA_and $(echo $GBOS_TDQ_END | cut -c3-4)
			(
				# L == TDQ_END[7:0]

				# H == TDQ_END[15:8] ?
				lr35902_copy_to_from regA regH
				lr35902_compare_regA_and $(echo $GBOS_TDQ_END | cut -c1-2)
				(
					# H == TDQ_END[15:8]

					# HL = TDQ_FIRST
					lr35902_set_reg regL $(echo $GBOS_TDQ_FIRST | cut -c3-4)
					lr35902_set_reg regH $(echo $GBOS_TDQ_FIRST | cut -c1-2)
				) >src/tdq_handler.5.o
				local sz_5=$(stat -c '%s' src/tdq_handler.5.o)
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_5)
				cat src/tdq_handler.5.o
			) >src/tdq_handler.4.o
			local sz_4=$(stat -c '%s' src/tdq_handler.4.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
			cat src/tdq_handler.4.o

			# tdq.head = HL
			lr35902_copy_to_from regA regL
			lr35902_copy_to_addr_from_regA $var_tdq_head_bh
			lr35902_copy_to_from regA regH
			lr35902_copy_to_addr_from_regA $var_tdq_head_th

			# tdq.head[7:0] == tdq.tail[7:0] ?
			lr35902_copy_to_regA_from_addr $var_tdq_tail_bh
			lr35902_compare_regA_and regL
			(
				# tdq.head[7:0] == tdq.tail[7:0]

				# tdq.head[15:8] == tdq.tail[15:8] ?
				lr35902_copy_to_regA_from_addr $var_tdq_tail_th
				lr35902_compare_regA_and regH
				(
					# tdq.head[15:8] == tdq.tail[15:8]

					# tdq.stat = empty
					lr35902_set_reg regA 01
					lr35902_copy_to_addr_from_regA $var_tdq_stat

					# popまでジャンプ
					# デクリメント命令サイズ(1)+相対ジャンプ命令サイズ(2)
					# +レジスタAクリアサイズ(1)+tdq.stat設定サイズ(3)=7
					lr35902_rel_jump 07
				) >src/tdq_handler.3.o
				local sz_3=$(stat -c '%s' src/tdq_handler.3.o)
				lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
				cat src/tdq_handler.3.o
			) >src/tdq_handler.2.o
			local sz_2=$(stat -c '%s' src/tdq_handler.2.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_2)
			cat src/tdq_handler.2.o
		) >src/tdq_handler.6.o
		cat src/tdq_handler.6.o
		local sz_6=$(stat -c '%s' src/tdq_handler.6.o)

		# Cをデクリメント
		lr35902_dec regC

		# C != 0 なら繰り返す
		# tdq_handler.6.oのサイズに
		# デクリメント命令サイズと相対ジャンプ命令サイズを足す
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_6+3)))

		# tdq.stat = 0
		lr35902_clear_reg regA
		lr35902_copy_to_addr_from_regA $var_tdq_stat

		# pop
		lr35902_pop_reg regDE
	) >src/tdq_handler.1.o
	local sz_1=$(stat -c '%s' src/tdq_handler.1.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_1)
	cat src/tdq_handler.1.o
}

event_driven() {
	local sz

	# [割り込み待ち]
	lr35902_halt



	# [マウスカーソル更新]

	# 現在の入力状態を変数から取得
	lr35902_copy_to_regA_from_addr $var_btn_stat
	lr35902_copy_to_from regD regA

	# 十字キー入力の有無確認
	lr35902_and_to_regA $GBOS_DIR_KEY_MASK
	(
		# 十字キー入力有

		# マウス有効/無効確認
		lr35902_copy_to_regA_from_addr $var_mouse_enable
		lr35902_or_to_regA regA
		(
			# マウス有効

			# マウスカーソル座標更新
			update_mouse_cursor
		) >src/event_driven.7.o
		local sz_7=$(stat -c '%s' src/event_driven.7.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_7)
		cat src/event_driven.7.o
	) >src/event_driven.1.o
	sz=$(stat -c '%s' src/event_driven.1.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/event_driven.1.o


	# [タイル描画キュー処理]
	tdq_handler


	# [ボタンリリースフラグ更新]

	# 前回の入力状態を変数から取得
	lr35902_copy_to_regA_from_addr $var_prv_btn
	lr35902_copy_to_from regE regA

	# リリースのみ抽出(1->0の変化があったビットのみregAへ格納)
	# 1. 現在と前回でxor
	lr35902_xor_to_regA regD
	# 2. 1.と前回でand
	lr35902_and_to_regA regE

	# リリースされたボタンをBへコピー
	lr35902_copy_to_from regB regA

	# ウィンドウステータスがディレクトリ表示中であるか否か
	lr35902_copy_to_regA_from_addr $var_win_stat
	lr35902_test_bitN_of_reg $GBOS_WST_BITNUM_DIR regA
	(
		# ディレクトリ表示中以外の場合

		# アプリ用ボタンリリースフラグ更新
		lr35902_copy_to_regA_from_addr $var_app_release_btn
		lr35902_or_to_regA regB
		lr35902_copy_to_addr_from_regA $var_app_release_btn
	) >src/event_driven.5.o
	(
		# ディレクトリ表示中の場合

		# 処理なし

		# ディレクトリ表示中以外の場合の処理を飛ばす
		local sz5=$(stat -c '%s' src/event_driven.5.o)
		lr35902_rel_jump $(two_digits_d $sz5)
	) >src/event_driven.6.o
	local sz6=$(stat -c '%s' src/event_driven.6.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz6)
	cat src/event_driven.6.o
	cat src/event_driven.5.o


	# [ボタンリリース処理]

	# ボタンのリリースがあった場合それに応じた処理を実施
	lr35902_copy_to_from regA regB
	(
		# ボタンリリースがあれば応じた処理を実施
		btn_release_handler
	) >src/event_driven.2.o
	sz=$(stat -c '%s' src/event_driven.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz)
	cat src/event_driven.2.o

	# 前回の入力状態更新
	lr35902_copy_to_from regA regD
	lr35902_copy_to_addr_from_regA $var_prv_btn



	# [画像表示処理]

	# 現在、何らかの画像表示処理中か?
	lr35902_copy_to_regA_from_addr $var_view_img_state
	lr35902_compare_regA_and $GBOS_VIEW_IMG_STAT_NONE
	(
		# 画像表示処理中でない場合

		# [バイナリ生物周期処理]
		lr35902_call $a_binbio_do_cycle

		if [ "$BINBIO_EXPSET_NUM_INIT" = "$BINBIO_EXPSET_DAISYWORLD" ]; then
			# [ステータス表示領域の更新]
			lr35902_copy_to_regA_from_addr $var_binbio_status_disp_counter
			lr35902_compare_regA_and $BINBIO_CELL_DISP_AREA_UPDATE_CYC
			(
				# regA < regC(更新周期)の場合

				# カウンタをインクリメント
				lr35902_inc regA
				lr35902_copy_to_addr_from_regA $var_binbio_status_disp_counter
			) >src/event_driven.no_img_proc.regA_lt_update_cyc.o
			(
				# regA >= regC(更新周期)の場合

				# ステータス表示領域更新関数を呼び出す
				lr35902_call $a_binbio_update_status_disp

				# カウンタをゼロクリア
				lr35902_xor_to_regA regA
				lr35902_copy_to_addr_from_regA $var_binbio_status_disp_counter

				# regA < regCの場合の処理を飛ばす
				local sz_no_img_proc_regA_lt_update_cyc=$(stat -c '%s' src/event_driven.no_img_proc.regA_lt_update_cyc.o)
				lr35902_rel_jump $(two_digits_d $sz_no_img_proc_regA_lt_update_cyc)
			) >src/event_driven.no_img_proc.regA_ge_update_cyc.o
			local sz_no_img_proc_regA_ge_update_cyc=$(stat -c '%s' src/event_driven.no_img_proc.regA_ge_update_cyc.o)
			lr35902_rel_jump_with_cond C $sz_no_img_proc_regA_ge_update_cyc
			cat src/event_driven.no_img_proc.regA_ge_update_cyc.o	# regA >= regCの場合
			cat src/event_driven.no_img_proc.regA_lt_update_cyc.o	# regA < regCの場合
		fi
	) >src/event_driven.no_img_proc.o
	(
		# 何らかの画像表示処理中である場合

		# tdq消費待ちか?
		lr35902_compare_regA_and $GBOS_VIEW_IMG_STAT_WAIT_FOR_TDQEMP
		(
			# tdq消費待ちである場合

			# 現在のスライドのバンク・ファイル番号を変数から取得
			lr35902_copy_to_regA_from_addr $var_ss_current_bank_file_num

			# 画像表示
			lr35902_call $a_view_img
		) >src/event_driven.during_wait_tdqemp.o
		local sz_during_wait_tdqemp=$(stat -c '%s' src/event_driven.during_wait_tdqemp.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_during_wait_tdqemp)
		cat src/event_driven.during_wait_tdqemp.o

		# 画像表示処理中でない場合の処理を飛ばす
		local sz_no_img_proc=$(stat -c '%s' src/event_driven.no_img_proc.o)
		lr35902_rel_jump $(two_digits_d $sz_no_img_proc)
	) >src/event_driven.during_img_proc.o
	local sz_during_img_proc=$(stat -c '%s' src/event_driven.during_img_proc.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_during_img_proc)
	cat src/event_driven.during_img_proc.o	# 何らかの画像表示処理中である場合
	cat src/event_driven.no_img_proc.o	# 画像表示処理中でない場合



	# [キー入力処理]
	# チャタリング(あるのか？)等のノイズ除去は未実装

	# * ボタンキーの入力チェック *
	# ボタンキー側の入力を取得するように設定
	lr35902_copy_to_regA_from_ioport $GB_IO_JOYP	# 2
	echo -en '\xcb\xaf'	# res 5,a		# 2
	echo -en '\xcb\xe7'	# set 4,a		# 2
	lr35902_copy_to_ioport_from_regA $GB_IO_JOYP	# 2

	# 改めて入力取得
	lr35902_copy_to_regA_from_ioport $GB_IO_JOYP	# 2
	# ノイズ除去のため2回読む
	lr35902_copy_to_regA_from_ioport $GB_IO_JOYP	# 2
	lr35902_copy_to_from regB regA			# 1

	# スタートキーは押下中か？
	echo -en '\xcb\x58'	# bit 3,b		# 2
	lr35902_rel_jump_with_cond NZ 04		# 2
	# >>キー押下中の処理
	echo -en '\xcb\xf9'	# set 7,c		# 2
	lr35902_rel_jump 02				# 2
	# <<キー押下中の処理
	# >>キー押下が無かった場合の処理
	echo -en '\xcb\xb9'	# res 7,c		# 2
	# <<キー押下が無かった場合の処理

	# セレクトキーは押下中か？
	echo -en '\xcb\x50'	# bit 2,b		# 2
	lr35902_rel_jump_with_cond NZ 04		# 2
	# >>キー押下中の処理
	echo -en '\xcb\xf1'	# set 6,c		# 2
	lr35902_rel_jump 02				# 2
	# <<キー押下中の処理
	# >>キー押下が無かった場合の処理
	echo -en '\xcb\xb1'	# res 6,c		# 2
	# <<キー押下が無かった場合の処理

	# Bキーは押下中か？
	echo -en '\xcb\x48'	# bit 1,b		# 2
	lr35902_rel_jump_with_cond NZ 04		# 2
	# >>キー押下中の処理
	echo -en '\xcb\xe9'	# set 5,c		# 2
	lr35902_rel_jump 02				# 2
	# <<キー押下中の処理
	# >>キー押下が無かった場合の処理
	echo -en '\xcb\xa9'	# res 5,c		# 2
	# <<キー押下が無かった場合の処理

	# Aキーは押下中か？
	echo -en '\xcb\x40'	# bit 0,b		# 2
	lr35902_rel_jump_with_cond NZ 04		# 2
	# >>キー押下中の処理
	echo -en '\xcb\xe1'	# set 4,c		# 2
	lr35902_rel_jump 02				# 2
	# <<キー押下中の処理
	# >>キー押下が無かった場合の処理
	echo -en '\xcb\xa1'	# res 4,c		# 2
	# <<キー押下が無かった場合の処理

	# * 方向キーの入力チェック *
	# 方向キー側の入力を取得するように設定
	lr35902_copy_to_regA_from_ioport $GB_IO_JOYP	# 2
	echo -en '\xcb\xef'	# set 5,a		# 2
	echo -en '\xcb\xa7'	# res 4,a		# 2
	lr35902_copy_to_ioport_from_regA $GB_IO_JOYP	# 2

	# 改めて入力取得
	lr35902_copy_to_regA_from_ioport $GB_IO_JOYP	# 2
	# ノイズ除去のため2回読む
	lr35902_copy_to_regA_from_ioport $GB_IO_JOYP	# 2
	lr35902_copy_to_from regB regA			# 1

	# ↓キーは押下中か？
	echo -en '\xcb\x58'	# bit 3,b		# 2
	lr35902_rel_jump_with_cond NZ 04		# 2
	# >>キー押下中の処理
	echo -en '\xcb\xd9'	# set 3,c		# 2
	lr35902_rel_jump 02				# 2
	# <<キー押下中の処理
	# >>キー押下が無かった場合の処理
	echo -en '\xcb\x99'	# res 3,c		# 2
	# <<キー押下が無かった場合の処理

	# ↑キーは押下中か？
	echo -en '\xcb\x50'	# bit 2,b		# 2
	lr35902_rel_jump_with_cond NZ 04		# 2
	# >>キー押下中の処理
	echo -en '\xcb\xd1'	# set 2,c		# 2
	lr35902_rel_jump 02				# 2
	# <<キー押下中の処理
	# >>キー押下が無かった場合の処理
	echo -en '\xcb\x91'	# res 2,c		# 2
	# <<キー押下が無かった場合の処理

	# ←キーは押下中か？
	echo -en '\xcb\x48'	# bit 1,b		# 2
	lr35902_rel_jump_with_cond NZ 04		# 2
	# >>キー押下中の処理
	echo -en '\xcb\xc9'	# set 1,c		# 2
	lr35902_rel_jump 02				# 2
	# <<キー押下中の処理
	# >>キー押下が無かった場合の処理
	echo -en '\xcb\x89'	# res 1,c		# 2
	# <<キー押下が無かった場合の処理

	# →キーは押下中か？
	echo -en '\xcb\x40'	# bit 0,b		# 2
	lr35902_rel_jump_with_cond NZ 04		# 2
	# >>キー押下中の処理
	echo -en '\xcb\xc1'	# set 0,c		# 2
	lr35902_rel_jump 02				# 2
	# <<キー押下中の処理
	# >>キー押下が無かった場合の処理
	echo -en '\xcb\x81'	# res 0,c		# 2
	# <<キー押下が無かった場合の処理

	# 現在の入力状態をメモリ上の変数へ保存
	lr35902_copy_to_from regA regC			# 1
	lr35902_copy_to_addr_from_regA $var_btn_stat	# 3



	# [割り込み待ち(halt)へ戻る]
	gbos_const >src/gbos_const.o
	local const_bytes=$(stat -c '%s' src/gbos_const.o)
	local init_bytes=$(stat -c '%s' src/init.o)
	local bc_form="obase=16;${const_bytes}+${init_bytes}"
	local const_init=$(echo $bc_form | bc)
	bc_form="obase=16;ibase=16;${GB_ROM_FREE_BASE}+${const_init}"
	local halt_addr=$(echo $bc_form | bc)
	lr35902_abs_jump $(four_digits $halt_addr)
}

gbos_main() {
	init >src/init.o
	cat src/init.o

	# 以降、割り込み駆動の処理部
	event_driven
}
