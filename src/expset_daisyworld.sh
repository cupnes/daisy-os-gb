if [ "${SRC_EXPSET_DAISYWORLD_SH+is_defined}" ]; then
	return
fi
SRC_EXPSET_DAISYWORLD_SH=true

# main.shの中で一通りのシェルスクリプトの読み込みが終わった後でこのファイルが読み込まれる想定
# なので、このファイル内で個別のシェルスクリプトの読み込みは行っていない。

# 定数
DAISY_GROWING_TEMP=14		# デイジーの生育適温(20℃)

# 変数
var_binbio_surface_temp=c035	# 地表温度(-128〜127)のアドレス

# 繰り返し使用する処理をファイル書き出し
## 現在の細胞が白デイジーか否か
## out : regA - 現在の細胞が白デイジーなら1、それ以外は0
## work: regBC, regHL
{
	# 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# アドレスregHLをtile_numまで進める
	lr35902_set_reg regBC 0006
	lr35902_add_to_regHL regBC

	# regAへ現在の細胞のtile_numを取得
	lr35902_copy_to_from regA ptrHL

	# regA == 白デイジータイル?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_WHITE
	(
		# regA == 白デイジーの場合

		# regAへ1を設定
		lr35902_set_reg regA 01
	) >src/expset_daisyworld.is_daisy_white.isw.o
	(
		# regA != 白デイジーの場合

		# regAへ0を設定
		lr35902_xor_to_regA regA

		# regA == 白デイジーの場合の処理を飛ばす
		sz_is_daisy_white_isw=$(stat -c '%s' src/expset_daisyworld.is_daisy_white.isw.o)
		lr35902_rel_jump $(two_digits_d $sz_is_daisy_white_isw)
	) >src/expset_daisyworld.is_daisy_white.isnw.o
	sz_is_daisy_white_isnw=$(stat -c '%s' src/expset_daisyworld.is_daisy_white.isnw.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_is_daisy_white_isnw)
	cat src/expset_daisyworld.is_daisy_white.isnw.o	# regA != 白デイジーの場合
	cat src/expset_daisyworld.is_daisy_white.isw.o	# regA == 白デイジーの場合
} >src/expset_daisyworld.is_daisy_white.o

# 現在の細胞を評価する
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval() {
	# push
	lr35902_push_reg regBC
	lr35902_push_reg regHL
	## TODO

	# 現在の細胞の機械語バイナリ実行結果の後処理
	## 地表温度がオーバーフローしてしまっている場合、元に戻す
	## TODO: これらの処理は細胞の機械語バイナリの側にあるべきとも考えられるが
	##       細胞の機械語バイナリサイズを5から変更した場合の影響を鑑みて
	##       v0.3.0時点ではこのように実装している
	### regAへ地表温度を設定
	lr35902_set_reg regHL $var_binbio_surface_temp
	lr35902_copy_to_from regA ptrHL
	### regA == 0x80?
	lr35902_compare_regA_and 80
	(
		# regA(地表温度) == 0x80 の場合

		# 現在の細胞が黒デイジーなら正のオーバーフローを起こして0x80(-128)になってしまっているので
		# 地表温度を0x7f(127)に戻す

		# 現在の細胞 == 黒デイジー?
		cat src/expset_daisyworld.is_daisy_white.o
		lr35902_compare_regA_and 00
		(
			# 現在の細胞 == 黒デイジーの場合

			# 地表温度を0x7fに戻す
			lr35902_set_reg regA 7f
			lr35902_copy_to_from ptrHL regA
		) >src/expset_daisyworld.f_binbio_cell_eval.st_eq_0.b.o
		local sz_st_eq_0_b=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_eq_0.b.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_st_eq_0_b)
		cat src/expset_daisyworld.f_binbio_cell_eval.st_eq_0.b.o
	) >src/expset_daisyworld.f_binbio_cell_eval.st_eq_0.o
	local sz_st_eq_0=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_eq_0.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_st_eq_0)
	cat src/expset_daisyworld.f_binbio_cell_eval.st_eq_0.o
	### regA == 0x7f?
	lr35902_compare_regA_and 7f
	(
		# regA(地表温度) == 0x7f の場合

		# 現在の細胞が白デイジーなら負のオーバーフローを起こして0x7f(127)になってしまっているので
		# 地表温度を0x80(-128)に戻す

		# 現在の細胞 == 白デイジー?
		cat src/expset_daisyworld.is_daisy_white.o
		lr35902_compare_regA_and 01
		(
			# 現在の細胞 == 白デイジーの場合

			# 地表温度を0x80に戻す
			lr35902_set_reg regA 80
			lr35902_copy_to_from ptrHL regA
		) >src/expset_daisyworld.f_binbio_cell_eval.st_eq_ff.w.o
		local sz_st_eq_ff_w=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_eq_ff.w.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_st_eq_ff_w)
		cat src/expset_daisyworld.f_binbio_cell_eval.st_eq_ff.w.o
	) >src/expset_daisyworld.f_binbio_cell_eval.st_eq_ff.o
	local sz_st_eq_ff=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_eq_ff.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_st_eq_ff)
	cat src/expset_daisyworld.f_binbio_cell_eval.st_eq_ff.o

	# 誤差を算出
	# (誤差 = 地表温度 - 生育適温)
	## regAへ地表温度を設定
	lr35902_set_reg regHL $var_binbio_surface_temp
	lr35902_copy_to_from regA ptrHL
	## regA < -127 + $DAISY_GROWING_TEMP なら以降の処理を飛ばす
	## (-127の時点で負の方向の誤差の最大であるため)
	### TODO
	## regBへ生育適温を設定
	lr35902_set_reg regB $DAISY_GROWING_TEMP
	## regA = regA - regB
	lr35902_sub_to_regA regB

	# 誤差 >= 0?
	## regAのMSBが0か?
	lr35902_test_bitN_of_reg 7 regA
	(
		# 誤差 >= 0(regAのMSBが0)の場合

		# ⽣育適温より⾼いため、⽩デイジーへ⾼い適応度を設定

		# 現在の細胞 == 白デイジー?
		cat src/expset_daisyworld.is_daisy_white.o
		lr35902_compare_regA_and 01
		(
			# 現在の細胞 == 白デイジーの場合

			# 適応度 = 128 + 誤差
			## TODO
		) >src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.w.o
		(
			# 現在の細胞 == 黒デイジーの場合

			# 適応度 = 128 - 誤差
			## TODO

			# 現在の細胞 == 白デイジーの場合の処理を飛ばす
			local sz_st_ge_gt_w=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.w.o)
			lr35902_rel_jump $(two_digits_d $sz_st_ge_gt_w)
		) >src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.b.o
		local sz_st_ge_gt_b=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.b.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_st_ge_gt_b)
		cat src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.b.o	# 現在の細胞 == 黒デイジーの場合
		cat src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.w.o	# 現在の細胞 == 白デイジーの場合
	) >src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.o
	(
		# 誤差 < 0(regAのMSBが1)の場合

		# ⽣育適温より低いため、黒デイジーへ⾼い適応度を設定

		# 現在の細胞 == 白デイジー?
		cat src/expset_daisyworld.is_daisy_white.o
		lr35902_compare_regA_and 01
		(
			# 現在の細胞 == 白デイジーの場合

			# 適応度 = 128 - 誤差の絶対値
			## TODO
		) >src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.w.o
		(
			# 現在の細胞 == 黒デイジーの場合

			# 適応度 = 128 + 誤差の絶対値
			## TODO

			# 現在の細胞 == 白デイジーの場合の処理を飛ばす
			local sz_st_lt_gt_w=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.w.o)
			lr35902_rel_jump $(two_digits_d $sz_st_lt_gt_w)
		) >src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.b.o
		local sz_st_lt_gt_b=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.b.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_st_lt_gt_b)
		cat src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.b.o	# 現在の細胞 == 黒デイジーの場合
		cat src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.w.o	# 現在の細胞 == 白デイジーの場合

		# 誤差 >= 0の場合の処理を飛ばす
		local sz_st_ge_gt=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.o)
		lr35902_rel_jump $(two_digits_d $sz_st_ge_gt)
	) >src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.o
	local sz_st_lt_gt=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_st_lt_gt)
	cat src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.o	# 誤差 < 0の場合
	cat src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.o	# 誤差 >= 0の場合

	# pop & return
	## TODO
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_return
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
	## tile_num = $GBOS_TILE_NUM_DAISY_BLACK
	lr35902_set_reg regA $GBOS_TILE_NUM_DAISY_BLACK
	lr35902_copyinc_to_ptrHL_from_regA
	### 後のためにregBにも設定
	lr35902_copy_to_from regB regA
	## bin_size = 5
	lr35902_set_reg regA 05
	lr35902_copyinc_to_ptrHL_from_regA
	## bin_data = (黒デイジーの命令列)
	## 命令列についてはdocs/daisyworld.mdを参照
	local byte_in_inst
	for byte_in_inst in 21 $(echo $var_binbio_surface_temp | cut -c3-4) $(echo $var_binbio_surface_temp | cut -c1-2) 35 00; do
		lr35902_set_reg regA $byte_in_inst
		lr35902_copyinc_to_ptrHL_from_regA
	done
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
