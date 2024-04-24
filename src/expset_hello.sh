# expset_daisyworld.shに追随したこのファイルの更新は停止した。
# いつの時点から停止しているかはこの行が含まれるコミットを参照。

if [ "${SRC_EXPSET_HELLO_SH+is_defined}" ]; then
	return
fi
SRC_EXPSET_HELLO_SH=true

# main.shの中で一通りのシェルスクリプトの読み込みが終わった後でこのファイルが読み込まれる想定
# なので、このファイル内で個別のシェルスクリプトの読み込みは行っていない。

# 定数
## 画面上のタイル座標/アドレス
### 細胞表示
CELL_DISP_AREA_FRAME_UPPER_LEFT_TCOORD_Y=00
CELL_DISP_AREA_FRAME_UPPER_LEFT_TCOORD_X=00
CELL_DISP_AREA_FRAME_LOWER_RIGHT_TCOORD_Y=11
CELL_DISP_AREA_FRAME_LOWER_RIGHT_TCOORD_X=13

# 評価の実装 - デイジーワールド実験用
f_binbio_cell_eval_daisyworld() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# 評価の実装 - 固定値を返す
f_binbio_cell_eval_fixedval() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# 現在の細胞を評価する
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval() {
	# regAへexpset_numを取得
	lr35902_copy_to_regA_from_addr $var_binbio_expset_num

	# 繰り返し使用する処理をファイル書き出し
	## regA(評価結果の適応度)に応じてfixフラグをセット/クリアする
	(
		# push
		lr35902_push_reg regBC
		lr35902_push_reg regHL

		# regBへregAを退避
		lr35902_copy_to_from regB regA

		# 現在の細胞のアドレスをregHL(のflags)へ取得
		lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
		lr35902_copy_to_from regL regA
		lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
		lr35902_copy_to_from regH regA

		# regBからregAを復帰
		lr35902_copy_to_from regA regB

		# regA == CELL_MAX_FITNESS ?
		lr35902_compare_regA_and $BINBIO_CELL_MAX_FITNESS
		(
			# regA == CELL_MAX_FITNESS の場合

			# fixフラグをセットする
			lr35902_set_bitN_of_reg $BINBIO_CELL_FLAGS_BIT_FIX ptrHL
		) >src/f_binbio_cell_eval.max_fitness.o
		(
			# regA != CELL_MAX_FITNESS の場合

			# fixフラグをクリアする
			lr35902_res_bitN_of_reg $BINBIO_CELL_FLAGS_BIT_FIX ptrHL

			# regA == CELL_MAX_FITNESS の場合の処理を飛ばす
			local sz_max_fitness=$(stat -c '%s' src/f_binbio_cell_eval.max_fitness.o)
			lr35902_rel_jump $(two_digits_d $sz_max_fitness)
		) >src/f_binbio_cell_eval.not_max_fitness.o
		local sz_not_max_fitness=$(stat -c '%s' src/f_binbio_cell_eval.not_max_fitness.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_not_max_fitness)
		cat src/f_binbio_cell_eval.not_max_fitness.o	# regA != CELL_MAX_FITNESS の場合
		cat src/f_binbio_cell_eval.max_fitness.o	# regA == CELL_MAX_FITNESS の場合

		# pop
		lr35902_pop_reg regHL
		lr35902_pop_reg regBC
	) >src/f_binbio_cell_eval.update_fix_flag.o

	# regA == HELLO ?
	lr35902_compare_regA_and $BINBIO_EXPSET_HELLO
	(
		# regA == HELLO の場合

		# 実装関数呼び出し
		lr35902_call $a_binbio_cell_eval_hello

		# 評価結果に応じてfixフラグをセット/クリアする
		cat src/f_binbio_cell_eval.update_fix_flag.o

		# return
		lr35902_return
	) >src/f_binbio_cell_eval.hello.o
	local sz_hello=$(stat -c '%s' src/f_binbio_cell_eval.hello.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_hello)
	cat src/f_binbio_cell_eval.hello.o

	# regA == DAISY ?
	lr35902_compare_regA_and $BINBIO_EXPSET_DAISY
	(
		# regA == DAISY の場合

		# 実装関数呼び出し
		lr35902_call $a_binbio_cell_eval_daisy

		# 評価結果に応じてfixフラグをセット/クリアする
		cat src/f_binbio_cell_eval.update_fix_flag.o

		# return
		lr35902_return
	) >src/f_binbio_cell_eval.daisy.o
	local sz_daisy=$(stat -c '%s' src/f_binbio_cell_eval.daisy.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisy)
	cat src/f_binbio_cell_eval.daisy.o

	# regA == HELLOWORLD ?
	lr35902_compare_regA_and $BINBIO_EXPSET_HELLOWORLD
	(
		# regA == HELLOWORLD の場合

		# 実装関数呼び出し
		lr35902_call $a_binbio_cell_eval_helloworld

		# 評価結果に応じてfixフラグをセット/クリアする
		cat src/f_binbio_cell_eval.update_fix_flag.o

		# return
		lr35902_return
	) >src/f_binbio_cell_eval.helloworld.o
	local sz_helloworld=$(stat -c '%s' src/f_binbio_cell_eval.helloworld.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_helloworld)
	cat src/f_binbio_cell_eval.helloworld.o

	# return
	lr35902_return
}

# コード化合物取得
# out: regA - 取得したコード化合物
# ※ フラグレジスタは破壊される
f_binbio_get_code_comp() {
	# regAへexpset_numを取得
	lr35902_copy_to_regA_from_addr $var_binbio_expset_num

	# regA == HELLO ?
	lr35902_compare_regA_and $BINBIO_EXPSET_HELLO
	(
		# regA == HELLO の場合

		# 実装関数呼び出し
		lr35902_call $a_binbio_get_code_comp_hello

		# return
		lr35902_return
	) >src/f_binbio_get_code_comp.hello.o
	local sz_hello=$(stat -c '%s' src/f_binbio_get_code_comp.hello.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_hello)
	cat src/f_binbio_get_code_comp.hello.o

	# regA == DAISY ?
	lr35902_compare_regA_and $BINBIO_EXPSET_DAISY
	(
		# regA == DAISY の場合

		# 実装関数呼び出し
		lr35902_call $a_binbio_get_code_comp_all

		# return
		lr35902_return
	) >src/f_binbio_get_code_comp.daisy.o
	local sz_daisy=$(stat -c '%s' src/f_binbio_get_code_comp.daisy.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisy)
	cat src/f_binbio_get_code_comp.daisy.o

	# regA == HELLOWORLD ?
	lr35902_compare_regA_and $BINBIO_EXPSET_HELLOWORLD
	(
		# regA == HELLOWORLD の場合

		# 実装関数呼び出し
		lr35902_call $a_binbio_get_code_comp_all

		# return
		lr35902_return
	) >src/f_binbio_get_code_comp.helloworld.o
	local sz_helloworld=$(stat -c '%s' src/f_binbio_get_code_comp.helloworld.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_helloworld)
	cat src/f_binbio_get_code_comp.helloworld.o

	# return
	lr35902_return
}

# 突然変異
# in : regHL - 対象の細胞のアドレス
f_binbio_cell_mutation() {
	# push
	lr35902_push_reg regAF

	# regAへexpset_numを取得
	lr35902_copy_to_regA_from_addr $var_binbio_expset_num

	# regA == HELLO ?
	lr35902_compare_regA_and $BINBIO_EXPSET_HELLO
	(
		# regA == HELLO の場合

		# 実装関数呼び出し
		lr35902_call $a_binbio_cell_mutation_alphabet

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_mutation.hello.o
	local sz_hello=$(stat -c '%s' src/f_binbio_cell_mutation.hello.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_hello)
	cat src/f_binbio_cell_mutation.hello.o

	# regA == DAISY ?
	lr35902_compare_regA_and $BINBIO_EXPSET_DAISY
	(
		# regA == DAISY の場合

		# 実装関数呼び出し
		lr35902_call $a_binbio_cell_mutation_alphabet

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_mutation.daisy.o
	local sz_daisy=$(stat -c '%s' src/f_binbio_cell_mutation.daisy.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisy)
	cat src/f_binbio_cell_mutation.daisy.o

	# regA == HELLOWORLD ?
	lr35902_compare_regA_and $BINBIO_EXPSET_HELLOWORLD
	(
		# regA == HELLOWORLD の場合

		# 実装関数呼び出し
		lr35902_call $a_binbio_cell_mutation_all

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_mutation.helloworld.o
	local sz_helloworld=$(stat -c '%s' src/f_binbio_cell_mutation.helloworld.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_helloworld)
	cat src/f_binbio_cell_mutation.helloworld.o

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# ソフト説明を画面へ配置
f_binbio_place_soft_desc() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# ソフト説明をクリア
f_binbio_clear_soft_desc() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# ステータス表示領域の更新
f_binbio_update_status_disp() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# 細胞ステータス情報を画面へ配置
f_binbio_place_cell_info_labels() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# 細胞ステータス情報を画面へ配置
f_binbio_place_cell_info_val() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# 細胞ステータス情報をクリア
f_binbio_clear_cell_info() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# 評価関数選択を画面へ配置
f_binbio_place_cell_eval_sel() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# 評価関数選択をクリア
f_binbio_clear_cell_eval_sel() {
	# HELLO系の実験セットでは呼ばれないため、何もしない
	:
}

# バイナリ生物環境の初期化
# in : regA - 実験セット番号
f_binbio_init() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 実験セット番号変数を初期化
	lr35902_copy_to_addr_from_regA $var_binbio_expset_num

	# 細胞データ領域をゼロクリア
	lr35902_call $a_binbio_clear_cell_data_area

	# 初期細胞を生成
	## 細胞データ領域の最初のアドレスをregHLへ設定
	lr35902_set_reg regHL $BINBIO_CELL_DATA_AREA_BEGIN
	## flags = 0x01
	lr35902_set_reg regA 01
	lr35902_copyinc_to_ptrHL_from_regA
	## tile_x = 10
	lr35902_set_reg regA 0a
	lr35902_copyinc_to_ptrHL_from_regA
	### 後のためにregEにも設定
	lr35902_copy_to_from regE regA
	## tile_y = 9
	lr35902_set_reg regA 09
	lr35902_copyinc_to_ptrHL_from_regA
	### 後のためにregDにも設定
	lr35902_copy_to_from regD regA
	## life_duration
	lr35902_set_reg regA $BINBIO_CELL_LIFE_DURATION_INIT
	lr35902_copyinc_to_ptrHL_from_regA
	## life_left
	lr35902_copyinc_to_ptrHL_from_regA
	## fitness
	lr35902_set_reg regA $BINBIO_CELL_FITNESS_INIT
	lr35902_copyinc_to_ptrHL_from_regA
	## tile_num = $GBOS_TILE_NUM_CELL
	lr35902_set_reg regA $GBOS_TILE_NUM_CELL
	lr35902_copyinc_to_ptrHL_from_regA
	### 後のためにregBにも設定
	lr35902_copy_to_from regB regA
	## bin_size = 5
	lr35902_set_reg regA 05
	lr35902_copyinc_to_ptrHL_from_regA
	## bin_data = (現在の細胞のtile_numへ細胞タイルを設定する命令列)
	### ld a,$GBOS_TILE_NUM_CELL => 3e $GBOS_TILE_NUM_CELL
	lr35902_set_reg regA 3e
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_set_reg regA $GBOS_TILE_NUM_CELL
	lr35902_copyinc_to_ptrHL_from_regA
	### call $a_binbio_cell_set_tile_num => cd a_binbio_cell_set_tile_num
	lr35902_set_reg regA cd
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_set_reg regA $(echo $a_binbio_cell_set_tile_num | cut -c3-4)
	lr35902_copyinc_to_ptrHL_from_regA
	lr35902_set_reg regA $(echo $a_binbio_cell_set_tile_num | cut -c1-2)
	lr35902_copyinc_to_ptrHL_from_regA
	## collected_flags = 0x00
	lr35902_xor_to_regA regA
	lr35902_copy_to_from ptrHL regA

	# その他のシステム変数へ初期値を設定
	## cur_cell_addr = $BINBIO_CELL_DATA_AREA_BEGIN
	lr35902_set_reg regA $(echo $BINBIO_CELL_DATA_AREA_BEGIN | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_bh
	lr35902_set_reg regA $(echo $BINBIO_CELL_DATA_AREA_BEGIN | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_th
	## mutation_probability
	lr35902_set_reg regA $BINBIO_MUTATION_PROBABILITY_INIT
	lr35902_copy_to_addr_from_regA $var_binbio_mutation_probability
	## get_code_comp_counter_addr = 0x0000
	lr35902_xor_to_regA regA
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_bh
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_th
	## get_code_comp_hello_counter = 0
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_counter
	## binbio_get_code_comp_hello_addr = タイルミラー領域ベースアドレス
	lr35902_set_reg regA $GBOS_TMRR_BASE_BH
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_addr_bh
	lr35902_set_reg regA $GBOS_TMRR_BASE_TH
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_hello_addr_th

	# 初期細胞をマップへ配置
	## タイル座標をVRAMアドレスへ変換
	lr35902_call $a_tcoord_to_addr
	## VRAMアドレスと細胞のタイル番号をtdqへエンキュー
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
