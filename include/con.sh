if [ "${INCLUDE_CON_SH+is_defined}" ]; then
	return
fi
INCLUDE_CON_SH=true

. include/gb.sh
. include/vars.sh
. include/tiles.sh

### 定数 ###

# コンソールの開始タイルアドレス
CON_TADR_BASE=9805

# 最終行最終文字のアドレス
CON_TADR_EOP=9a33

# 行末判定定数
# TODO 以下を MASK=1f, VAL=11 から変える際は、
#      con_clear()・con_update_tadr()・con_update_tadr_for_nl()の
#      ↓の箇所も併せて変える必要があるのでは?
#      > # 次の行の行頭のアドレスをregDEへ設定
#      > # (現在のアドレスに0x11を足す)
#      (↑の0x11も定数化あるいはシェル芸で算出したい所)
CON_EOL_MASK=1f
CON_EOL_VAL=13

# 最終行判定
# TODO この定数では最終行判定できないのでは?
#      改ページは動いてほしくないのでひとまずこのままにしておく
CON_LAST_LINE_MASK=e0
CON_LAST_LINE_VAL=e0

### マクロとして使用する関数 ###

# タイル座標をタイルアドレスへ変換
# in : 第1引数 - タイル座標X
#    : 第2引数 - タイル座標Y
con_tcoord_to_tadr() {
	local tcoord_x=$1
	local tcoord_y=$2
	local form="${GB_VRAM_BG_TILE_MAP_BASE}+(${GB_SC_WIDTH_T}*${tcoord_y})+${tcoord_x}"
	echo $(four_digits $(calc16 $form))
}

# カーソル位置を設定
# in  : 第1引数 - カーソル位置のタイルアドレス
# work: regA
con_set_cursor() {
	local tadr=$1

	lr35902_set_reg regA $(echo $tadr | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_con_tadr_bh
	lr35902_set_reg regA $(echo $tadr | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_con_tadr_th
}

# 指定されたコンソール座標に指定された文字を配置
# in : 第1引数 - コンソール座標X
#      第2引数 - コンソール座標Y
#      第3引数 - 文字
# work: regB, regDE
con_putxy_macro() {
	local con_coord_x=$1
	local con_coord_y=$2
	local ch="$3"

	# 文字をタイル番号へ変換
	local tile_num=$(get_tile_num "$ch")

	# レジスタを設定し関数呼び出し
	lr35902_set_reg regB $tile_num
	lr35902_set_reg regD $con_coord_y
	lr35902_set_reg regE $con_coord_x
	lr35902_call $a_putxy
}

# カーソル位置を設定し文字列を配置
# in : 第1引数 - カーソル位置のタイル座標X
#      第2引数 - カーソル位置のタイル座標Y
#      第3引数 - 文字列のアドレス
# work: regDE, regHL
con_print_xy_macro() {
	local cursor_tcoord_x=$1
	local cursor_tcoord_y=$2
	local str_adr=$3

	lr35902_set_reg regHL $str_adr
	lr35902_set_reg regD $cursor_tcoord_y
	lr35902_set_reg regE $cursor_tcoord_x
	lr35902_call $a_print_xy
}

# 指定したタイル座標から指定した文字数を削除
# in : 第1引数 - タイル座標X
#      第2引数 - タイル座標Y
#      第3引数 - 文字数(10進数)
# work: regA, regDE
con_delch_tadr_num_macro() {
	local tcoord_x=$1
	local tcoord_y=$2
	local num_dec=$3
	local num_hex=$(two_digits $(to16 $num_dec))

	lr35902_set_reg regA $num_hex
	lr35902_set_reg regDE $(con_tcoord_to_tadr $tcoord_x $tcoord_y)
	lr35902_call $a_delch_tadr_num
}

# 指定されたタイル座標へ指定されたサイズの矩形を罫線で描く
# in  : 第1引数 - タイル座標X
#       第2引数 - タイル座標Y
#       第3引数 - 幅[タイル数]
#       第4引数 - 高さ[タイル数]
# work: regA, regB
# ※ 幅と高さはそれぞれ2以上であること
con_draw_rect_macro() {
	local tcoord_x=$1
	local tcoord_y=$2
	local width=$3
	local height=$4

	local i

	# カーソル位置を指定されたタイル座標へ設定
	local upper_left_tadr=$(con_tcoord_to_tadr $tcoord_x $tcoord_y)
	con_set_cursor $upper_left_tadr

	# "┌"を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_UPPER_LEFT_BAR
	lr35902_call $a_putch

	# 上側と下側の"─"を配置する数を算出
	local num_horizontal_bars=$(bc <<< "ibase=16;$width - 2")

	# "─"(上側)を$num_horizontal_bars個分配置
	lr35902_set_reg regB $GBOS_TILE_NUM_UPPER_BAR
	for i in $(seq $num_horizontal_bars); do
		# "─"(上側)を配置
		lr35902_call $a_putch
	done

	# "┐"を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_UPPER_RIGHT_BAR
	lr35902_call $a_putch

	# 右側と左側の"│"を配置する数を算出
	local num_vertical_bars=$(bc <<< "ibase=16;$height - 2")

	# "│"(右側)を$num_vertical_bars個分配置
	local right_bar_start_tx=$(calc16 "${tcoord_x}+${width}-1")
	local right_bar_start_ty_ofs
	local right_bar_start_ty
	local right_bar_start_tadr
	lr35902_set_reg regB $GBOS_TILE_NUM_RIGHT_BAR
	for i in $(seq $num_vertical_bars); do
		# カーソル位置を設定
		right_bar_start_ty_ofs=$(to16 $i)
		right_bar_start_ty=$(calc16 "${tcoord_y}+${right_bar_start_ty_ofs}")
		right_bar_start_tadr=$(con_tcoord_to_tadr $right_bar_start_tx $right_bar_start_ty)
		con_set_cursor $right_bar_start_tadr

		# "│"(右側)を配置
		lr35902_call $a_putch
	done

	# カーソル位置を"┘"の位置へ設定
	local lower_right_tx=$right_bar_start_tx
	local lower_right_ty=$(calc16 "${right_bar_start_ty}+1")
	local lower_right_tadr=$(con_tcoord_to_tadr $lower_right_tx $lower_right_ty)
	con_set_cursor $lower_right_tadr

	# "┘"を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_LOWER_RIGHT_BAR
	lr35902_call $a_putch

	# "│"(左側)を$num_vertical_bars個分配置
	local left_bar_start_tx=$tcoord_x
	local left_bar_start_ty_ofs
	local left_bar_start_ty
	local left_bar_start_tadr
	lr35902_set_reg regB $GBOS_TILE_NUM_LEFT_BAR
	for i in $(seq $num_vertical_bars); do
		# カーソル位置を設定
		left_bar_start_ty_ofs=$(to16 $i)
		left_bar_start_ty=$(calc16 "${tcoord_y}+${left_bar_start_ty_ofs}")
		left_bar_start_tadr=$(con_tcoord_to_tadr $left_bar_start_tx $left_bar_start_ty)
		con_set_cursor $left_bar_start_tadr

		# "│"(左側)を配置
		lr35902_call $a_putch
	done

	# カーソル位置を"└"の位置へ設定
	local lower_left_tx=$left_bar_start_tx
	local lower_left_ty=$(calc16 "${left_bar_start_ty}+1")
	local lower_left_tadr=$(con_tcoord_to_tadr $lower_left_tx $lower_left_ty)
	con_set_cursor $lower_left_tadr

	# "└"を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_LOWER_LEFT_BAR
	lr35902_call $a_putch

	# "─"(下側)を$num_horizontal_bars個分配置
	lr35902_set_reg regB $GBOS_TILE_NUM_LOWER_BAR
	for i in $(seq $num_horizontal_bars); do
		# "─"(上側)を配置
		lr35902_call $a_putch
	done
}

# 指定されたタイル座標の指定されたサイズの矩形を中身ごとクリアする
# in  : 第1引数 - タイル座標X
#       第2引数 - タイル座標Y
#       第3引数 - 幅[タイル数]
#       第4引数 - 高さ[タイル数]
# work: regA, regDE
con_clear_rect_macro() {
	local tcoord_x=$1
	local tcoord_y=$2
	local width=$3
	local height=$4

	local ty=$tcoord_y
	local width_dec=$(bc <<< "ibase=16;${width^^}")
	local height_dec=$(bc <<< "ibase=16;${height^^}")
	local i

	for ((i = 0; i < $height_dec; i++)); do
		con_delch_tadr_num_macro $tcoord_x $ty $width_dec
		ty=$(calc16_2 "${ty}+1")
	done
}

### OSの関数として使用する関数 ###

# コンソールの初期化
con_init() {
	# push
	lr35902_push_reg regAF

	# 次に描画するタイルアドレスを
	# コンソール開始アドレスで初期化
	lr35902_set_reg regA $(echo $CON_TADR_BASE | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_con_tadr_bh
	lr35902_set_reg regA $(echo $CON_TADR_BASE | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_con_tadr_th

	# pop
	lr35902_pop_reg regAF
}

# 指定したVRAMアドレスから指定した文字数を削除する
# (指定したVRAMアドレスから指定した文字数分のスペースを配置する)
# in : regA - 削除する文字数
#      regD  - VRAMアドレス[15:8]
#      regE  - VRAMアドレス[7:0]
# ※ regAは1以上の値であること
con_delch_tadr_num() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE

	# regBへ' '(スペース)のタイル番号を設定
	lr35902_set_reg regB $GBOS_TILE_NUM_SPC

	# regAの数だけregDEのアドレスへスペースを配置する
	(
		# regDEのアドレスへregBのタイルを配置するエンキュー
		lr35902_call $a_enq_tdq

		# regDEを1バイト進める
		lr35902_inc regDE

		# regAをデクリメント
		lr35902_dec regA

		# regAと0を比較
		lr35902_compare_regA_and 00
	) >src/con_del_tadr_num.put_spcs.o
	cat src/con_del_tadr_num.put_spcs.o
	local sz_put_spcs=$(stat -c '%s' src/con_del_tadr_num.put_spcs.o)
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_put_spcs + 2)))	# 2

	# pop
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
}

# コンソールの描画領域をクリアする
# - コンソール描画領域は、ウィンドウ内のdrawableエリア
con_clear() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# regBへクリア文字(スペース)を設定
	lr35902_set_reg regB $GBOS_TILE_NUM_SPC

	# regDEへ描画領域の開始アドレスを設定
	lr35902_set_reg regDE $CON_TADR_BASE

	# 1タイルずつクリアするエントリをtdqへ積むループ
	(
		# tdqへ追加
		lr35902_call $a_enq_tdq

		# regDEが最終行最終文字か?
		lr35902_set_reg regA $(echo $CON_TADR_EOP | cut -c3-4)
		lr35902_xor_to_regA regE
		lr35902_copy_to_from regH regA
		lr35902_set_reg regA $(echo $CON_TADR_EOP | cut -c1-2)
		lr35902_xor_to_regA regD
		lr35902_or_to_regA regH
		(
			# 最終行最終文字

			# ループを脱出
			lr35902_rel_jump $(two_digits_d 2)
		) >src/con_clear.2.o
		(
			# 最終行最終文字ではない

			# 行末か?
			lr35902_copy_to_from regA regE
			lr35902_and_to_regA $CON_EOL_MASK
			lr35902_compare_regA_and $CON_EOL_VAL
			(
				# 行末

				# 次の行の行頭のアドレスをregDEへ設定
				# (現在のアドレスに0x11を足す)
				lr35902_set_reg regHL 0011
				lr35902_add_to_regHL regDE
				lr35902_copy_to_from regE regL
				lr35902_copy_to_from regD regH
			) >src/con_clear.4.o
			(
				# 行末ではない

				# regDEをインクリメント
				lr35902_inc regDE

				# 行末の処理を飛ばす
				local sz_4=$(stat -c '%s' src/con_clear.4.o)
				lr35902_rel_jump $(two_digits_d $sz_4)
			) >src/con_clear.5.o
			local sz_5=$(stat -c '%s' src/con_clear.5.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_5)
			cat src/con_clear.5.o	# 行末ではない
			cat src/con_clear.4.o	# 行末

			# 最終行最終文字の処理を飛ばす
			local sz_2=$(stat -c '%s' src/con_clear.2.o)
			lr35902_rel_jump $(two_digits_d $sz_2)
		) >src/con_clear.3.o
		local sz_3=$(stat -c '%s' src/con_clear.3.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_3)
		cat src/con_clear.3.o	# 最終行最終文字ではない
		cat src/con_clear.2.o	# 最終行最終文字
	) >src/con_clear.1.o
	cat src/con_clear.1.o
	local sz_1=$(stat -c '%s' src/con_clear.1.o)
	lr35902_rel_jump $(two_comp_d $((sz_1 + 2)))	# 2

	# pop
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
}

# 指定されたコンソール座標に指定された文字を出力
# in : regB - 出力する文字のタイル番号
#    : regD - コンソールY座標
#    : regE - コンソールX座標
# ※ コンソール座標 - ウィンドウ内のdrawable領域の座標
con_putxy() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# drawable領域へのオフセットを足す
	lr35902_copy_to_from regA regD
	lr35902_add_to_regA $GBOS_WIN_DRAWABLE_OFS_YT
	lr35902_copy_to_from regD regA
	lr35902_copy_to_from regA regE
	lr35902_add_to_regA $GBOS_WIN_DRAWABLE_OFS_XT
	lr35902_copy_to_from regE regA

	# タイル座標をアドレスへ変換しregDEへ設定
	lr35902_call $a_tcoord_to_addr
	lr35902_copy_to_from regE regL
	lr35902_copy_to_from regD regH

	# tdqへ積む
	lr35902_call $a_enq_tdq

	# pop
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
}

# 指定されたコンソール座標のタイル番号を取得
# in : regD - コンソールY座標
#    : regE - コンソールX座標
# out: regA - 取得したタイル番号
con_getxy() {
	# push
	lr35902_push_reg regDE
	lr35902_push_reg regHL
	lr35902_push_reg regAF

	# drawable領域へのオフセットを足す
	lr35902_copy_to_from regA regD
	lr35902_add_to_regA $GBOS_WIN_DRAWABLE_OFS_YT
	lr35902_copy_to_from regD regA
	lr35902_copy_to_from regA regE
	lr35902_add_to_regA $GBOS_WIN_DRAWABLE_OFS_XT
	lr35902_copy_to_from regE regA

	# タイル座標をアドレスへ変換
	lr35902_call $a_tcoord_to_addr

	# アドレスの値をregHへ取得
	lr35902_copy_to_from regH ptrHL

	# pop
	lr35902_pop_reg regAF
	## regAへ戻り値設定
	lr35902_copy_to_from regA regH
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
}

# 次に描画するアドレスを更新する
# ※ con_putch()内でインライン展開されることを想定
# ※ con_putch()でpush/popしているregAF・regDEはpush/popしていない
# in : regDE - 現在のアドレス
con_update_tadr() {
	# 行末か否か?
	lr35902_copy_to_from regA regE
	lr35902_and_to_regA $CON_EOL_MASK
	lr35902_compare_regA_and $CON_EOL_VAL
	(
		# 行末

		# push
		lr35902_push_reg regHL

		# 最終行最終文字か否か?
		lr35902_set_reg regA $(echo $CON_TADR_EOP | cut -c3-4)
		lr35902_xor_to_regA regE
		lr35902_copy_to_from regH regA
		lr35902_set_reg regA $(echo $CON_TADR_EOP | cut -c1-2)
		lr35902_xor_to_regA regD
		lr35902_or_to_regA regH
		(
			# 最終行最終文字

			# 次の文字を出力する際は改ページが必要であることを
			# 示すために、var_con_tadr_thに0x00を設定する
			lr35902_clear_reg regA
			lr35902_copy_to_addr_from_regA $var_con_tadr_th
		) >src/con_update_tadr.3.o
		(
			# 最終行最終文字ではない

			# 次の行の行頭のアドレスを取得
			# (現在のアドレスに0x11を足す)
			lr35902_set_reg regHL 0011
			lr35902_add_to_regHL regDE

			# var_con_tadr_{th,bh}を更新
			lr35902_copy_to_from regA regL
			lr35902_copy_to_addr_from_regA $var_con_tadr_bh
			lr35902_copy_to_from regA regH
			lr35902_copy_to_addr_from_regA $var_con_tadr_th

			# 最終行最終文字の処理を飛ばす
			local sz_3=$(stat -c '%s' src/con_update_tadr.3.o)
			lr35902_rel_jump $(two_digits_d $sz_3)
		) >src/con_update_tadr.4.o
		local sz_4=$(stat -c '%s' src/con_update_tadr.4.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_4)
		cat src/con_update_tadr.4.o	# 最終行最終文字ではない
		cat src/con_update_tadr.3.o	# 最終行最終文字

		# pop
		lr35902_pop_reg regHL
	) >src/con_update_tadr.1.o
	(
		# 行末ではない

		# アドレスをインクリメント
		lr35902_inc regDE

		# var_con_tadr_{th,bh}を更新
		lr35902_copy_to_from regA regE
		lr35902_copy_to_addr_from_regA $var_con_tadr_bh
		lr35902_copy_to_from regA regD
		lr35902_copy_to_addr_from_regA $var_con_tadr_th

		# 行末の処理を飛ばす
		local sz_1=$(stat -c '%s' src/con_update_tadr.1.o)
		lr35902_rel_jump $(two_digits_d $sz_1)
	) >src/con_update_tadr.2.o
	local sz_2=$(stat -c '%s' src/con_update_tadr.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
	cat src/con_update_tadr.2.o	# 行末ではない
	cat src/con_update_tadr.1.o	# 行末
}

# 次に描画するアドレスを更新する(改行文字用)
# ※ con_putch()内でインライン展開されることを想定
# ※ con_putch()でpush/popしているregAF・regDEはpush/popしていない
# in : regDE - 現在のアドレス
con_update_tadr_for_nl() {
	# 最終行か否か?
	lr35902_copy_to_from regA regD
	lr35902_and_to_regA $CON_LAST_LINE_MASK
	lr35902_compare_regA_and $CON_LAST_LINE_VAL
	(
		# 最終行

		# 次の文字を出力する際は改ページが必要であることを
		# 示すために、var_con_tadr_thに0x00を設定する
		lr35902_clear_reg regA
		lr35902_copy_to_addr_from_regA $var_con_tadr_th
	) >src/con_update_tadr_for_nl.1.o
	(
		# 最終行ではない

		# push
		lr35902_push_reg regHL

		# 次の行の行頭のアドレスを取得
		# (現在のアドレスに0x11を足す)
		lr35902_set_reg regHL 0011
		lr35902_add_to_regHL regDE

		# var_con_tadr_{th,bh}を更新
		lr35902_copy_to_from regA regL
		lr35902_copy_to_addr_from_regA $var_con_tadr_bh
		lr35902_copy_to_from regA regH
		lr35902_copy_to_addr_from_regA $var_con_tadr_th

		# pop
		lr35902_pop_reg regHL

		# 最終行の処理を飛ばす
		local sz_1=$(stat -c '%s' src/con_update_tadr_for_nl.1.o)
		lr35902_rel_jump $(two_digits_d $sz_1)
	) >src/con_update_tadr_for_nl.2.o
	local sz_2=$(stat -c '%s' src/con_update_tadr_for_nl.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
	cat src/con_update_tadr_for_nl.2.o	# 最終行ではない
	cat src/con_update_tadr_for_nl.1.o	# 最終行
}

# 指定された1文字をtdqへ積む
# in : regB - 出力する文字のタイル番号あるいは改行文字
con_putch() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regDE

	# 改ページが必要か?
	lr35902_copy_to_regA_from_addr $var_con_tadr_th
	lr35902_or_to_regA regA
	(
		# 改ページ必要

		# コンソール領域クリアのエントリをtdqへ積む
		con_clear

		# regDEへ描画領域開始アドレスを設定
		lr35902_set_reg regDE $CON_TADR_BASE
	) >src/con_putch.3.o
	(
		# 改ページ不要

		# 次に描画するアドレスをregDEへ設定
		lr35902_copy_to_regA_from_addr $var_con_tadr_th
		lr35902_copy_to_from regD regA
		lr35902_copy_to_regA_from_addr $var_con_tadr_bh
		lr35902_copy_to_from regE regA

		# 改ページ必要の処理を飛ばす
		local sz_3=$(stat -c '%s' src/con_putch.3.o)
		lr35902_rel_jump $(two_digits_d $sz_3)
	) >src/con_putch.4.o
	local sz_4=$(stat -c '%s' src/con_putch.4.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_4)
	cat src/con_putch.4.o	# 改ページ不要
	cat src/con_putch.3.o	# 改ページ必要

	# 指定された文字が改行文字か否か
	lr35902_copy_to_from regA regB
	lr35902_compare_regA_and $GBOS_CTRL_CHR_NL
	(
		# 改行文字

		# 改行文字用のアドレス更新
		con_update_tadr_for_nl
	) >src/con_putch.1.o
	(
		# 改行文字でない

		# tdqへエンキュー
		lr35902_call $a_enq_tdq

		# アドレスを更新
		con_update_tadr

		# 改行文字の処理を飛ばす
		local sz_1=$(stat -c '%s' src/con_putch.1.o)
		lr35902_rel_jump $(two_digits_d $sz_1)
	) >src/con_putch.2.o
	local sz_2=$(stat -c '%s' src/con_putch.2.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
	cat src/con_putch.2.o	# 改行文字でない
	cat src/con_putch.1.o	# 改行文字

	# pop
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
}

# 指定されたアドレスの文字列を出力する
# in : regHL - 文字列の先頭アドレス
con_print() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# ヌル文字に到達するまで繰り返す
	(
		# regHLの指す先からregAへ1文字取得し、regHLをインクリメント
		lr35902_copyinc_to_regA_from_ptrHL

		# regAがヌル文字か否か?
		lr35902_compare_regA_and $GBOS_CTRL_CHR_NULL
		(
			# regA == ヌル文字

			# ループを脱出
			lr35902_rel_jump $(two_digits_d 2)
		) >src/con_print.1.o
		(
			# regA != ヌル文字

			# push
			lr35902_push_reg regBC

			# regAを出力
			lr35902_copy_to_from regB regA
			lr35902_call $a_putch

			# pop
			lr35902_pop_reg regBC

			# regA == ヌル文字の処理を飛ばす
			local sz_1=$(stat -c '%s' src/con_print.1.o)
			lr35902_rel_jump $(two_digits_d $sz_1)
		) >src/con_print.2.o
		local sz_2=$(stat -c '%s' src/con_print.2.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
		cat src/con_print.2.o	# regA != ヌル文字
		cat src/con_print.1.o	# regA == ヌル文字
	) >src/con_print.3.o
	cat src/con_print.3.o
	local sz_3=$(stat -c '%s' src/con_print.3.o)
	lr35902_rel_jump $(two_comp_d $((sz_3 + 2)))	# 2

	# pop
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
}

# 指定されたアドレスの文字列を指定されたタイル座標へ出力する
# in : regHL - 文字列の先頭アドレス
#    : regD - タイル座標Y
#    : regE - タイル座標X
# ※ con_putxy()とは違い、コンソールのカーソル位置を変更する
con_print_xy() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# タイル座標をアドレスへ変換しregHLへ設定
	lr35902_call $a_tcoord_to_addr

	# 変換して得られたアドレスを$var_con_tadr_{th,bh}へ設定
	lr35902_copy_to_from regA regL
	lr35902_copy_to_addr_from_regA $var_con_tadr_bh
	lr35902_copy_to_from regA regH
	lr35902_copy_to_addr_from_regA $var_con_tadr_th

	# regHLだけ先にpop
	lr35902_pop_reg regHL

	# f_print()を呼び出して、指定された文字列を出力
	lr35902_call $a_print

	# pop
	lr35902_pop_reg regAF
}
