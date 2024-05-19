# 生物種「捕食者」用のスクリプト

# [定数]

# 適応度
SPECIES_PREDATOR_FITNESS=7f



# [関数]

# 捕食者用評価関数
# 定義された固定値を適応度として返す
# out: regA - 評価結果の適応度(0x00〜0xff)
f_binbio_cell_eval_predator() {
	# 戻り値としてregAへ固定値を設定
	lr35902_set_reg regA $SPECIES_PREDATOR_FITNESS

	# return
	lr35902_return
}

# 捕食者用成長関数
# 8近傍を見て、デイジーが居れば補食し、その座標へ移動する
f_binbio_cell_growth_predator() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	local obj

	# [8近傍をチェック]
	# 現在の細胞の8近傍を左上から順に時計回りでチェック

	# 現在の細胞のタイル座標(X, Y)を(regE, regD)へ取得
	## 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA
	## アドレスregHLをtile_xまで進める
	lr35902_inc regHL
	## regEへ現在の細胞のtile_xを取得
	lr35902_copy_to_from regE ptrHL
	## アドレスregHLをtile_yまで進める
	lr35902_inc regHL
	## regDへ現在の細胞のtile_yを取得
	lr35902_copy_to_from regD ptrHL

	# 現在の細胞のタイルのタイルミラー領域上のアドレスをregHLへ設定
	lr35902_call $a_tcoord_to_mrraddr

	# 繰り返し使用する処理をファイル書き出し/マクロ定義
	## 捕食処理
	obj=src/f_binbio_cell_growth_predator.prey.o
	(
		# 対象の生物を消去
		## 対象の生物のタイルミラー領域上のアドレス(regHL)から
		## 対象の生物のアドレスを算出
		### タイルミラー領域上のアドレスからタイル座標を算出
		#### TODO
		### タイル座標から細胞のアドレスを取得
		lr35902_call $a_binbio_find_cell_data_by_tile_xy
		## regBCへ現在の細胞のアドレス変数の値を退避
		### TODO
		## 対象の生物のアドレスを現在の細胞のアドレス変数へ設定
		### TODO
		## 死の振る舞いを実施
		lr35902_call $a_binbio_cell_death
		## regBCから現在の細胞のアドレス変数の値を復帰
		### TODO

		# 自身のステータス更新
		## TODO

		# BGマップの表示を更新
		## TODO
	) >$obj
	local sz_prey=$(stat -c '%s' $obj)
	## アドレスregHLのタイル番号が白/黒デイジーであれば捕食処理を実施
	obj=src/f_binbio_cell_growth_predator.check_and_prey.o
	(
		# TODO
		:
	) >$obj
	local sz_check_and_prey=$(stat -c '%s' $obj)

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
			# タイル番号が白/黒デイジーであれば捕食処理を実施
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC $(two_comp_4 21)
			lr35902_add_to_regHL regBC
			## アドレスregHLのタイル番号が白/黒デイジーであれば捕食処理を実施
			cat src/f_binbio_cell_growth_predator.check_and_prey.o
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC 0021
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_growth_predator.2.o
		local sz_2=$(stat -c '%s' src/f_binbio_cell_growth_predator.2.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
		cat src/f_binbio_cell_growth_predator.2.o

		# 上座標をチェックし、
		# タイル番号が白/黒デイジーであれば捕食処理を実施
		## アドレスregHLを対象座標へ移動
		lr35902_set_reg regBC $(two_comp_4 20)
		lr35902_add_to_regHL regBC
		## アドレスregHLのタイル番号が白/黒デイジーであれば捕食処理を実施
		cat src/f_binbio_cell_growth_predator.check_and_prey.o
		## アドレスregHLを元に戻す
		lr35902_set_reg regBC 0020
		lr35902_add_to_regHL regBC

		# regE(tile_x) == 表示範囲の右端 ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
		(
			# tile_x != 表示範囲の右端 の場合

			# 右上座標をチェックし、
			# タイル番号が白/黒デイジーであれば捕食処理を実施
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC $(two_comp_4 1f)
			lr35902_add_to_regHL regBC
			## アドレスregHLのタイル番号が白/黒デイジーであれば捕食処理を実施
			cat src/f_binbio_cell_growth_predator.check_and_prey.o
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC 001f
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_growth_predator.3.o
		local sz_3=$(stat -c '%s' src/f_binbio_cell_growth_predator.3.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_3)
		cat src/f_binbio_cell_growth_predator.3.o
	) >src/f_binbio_cell_growth_predator.4.o
	local sz_4=$(stat -c '%s' src/f_binbio_cell_growth_predator.4.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_4)
	cat src/f_binbio_cell_growth_predator.4.o

	# regE(tile_x) == 表示範囲の右端 ?
	lr35902_copy_to_from regA regE
	lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
	(
		# tile_x != 表示範囲の右端 の場合

		# 右座標をチェックし、
		# タイル番号が白/黒デイジーであれば捕食処理を実施
		## アドレスregHLを対象座標へ移動
		lr35902_inc regHL
		## アドレスregHLのタイル番号が白/黒デイジーであれば捕食処理を実施
		cat src/f_binbio_cell_growth_predator.check_and_prey.o
		## アドレスregHLを元に戻す
		lr35902_dec regHL
	) >src/f_binbio_cell_growth_predator.5.o
	local sz_5=$(stat -c '%s' src/f_binbio_cell_growth_predator.5.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_5)
	cat src/f_binbio_cell_growth_predator.5.o

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
			# タイル番号が白/黒デイジーであれば捕食処理を実施
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC 0021
			lr35902_add_to_regHL regBC
			## アドレスregHLのタイル番号が白/黒デイジーであれば捕食処理を実施
			cat src/f_binbio_cell_growth_predator.check_and_prey.o
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC $(two_comp_4 21)
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_growth_predator.6.o
		local sz_6=$(stat -c '%s' src/f_binbio_cell_growth_predator.6.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_6)
		cat src/f_binbio_cell_growth_predator.6.o

		# 下座標をチェックし、
		# タイル番号が白/黒デイジーであれば捕食処理を実施
		## アドレスregHLを対象座標へ移動
		lr35902_set_reg regBC 0020
		lr35902_add_to_regHL regBC
		## アドレスregHLのタイル番号が白/黒デイジーであれば捕食処理を実施
		cat src/f_binbio_cell_growth_predator.check_and_prey.o
		## アドレスregHLを元に戻す
		lr35902_set_reg regBC $(two_comp_4 20)
		lr35902_add_to_regHL regBC

		# regE(tile_x) == 0 ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and 00
		(
			# tile_x != 0 の場合

			# 左下座標をチェックし、
			# タイル番号が白/黒デイジーであれば捕食処理を実施
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC 001f
			lr35902_add_to_regHL regBC
			## アドレスregHLのタイル番号が白/黒デイジーであれば捕食処理を実施
			cat src/f_binbio_cell_growth_predator.check_and_prey.o
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC $(two_comp_4 1f)
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_growth_predator.7.o
		local sz_7=$(stat -c '%s' src/f_binbio_cell_growth_predator.7.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_7)
		cat src/f_binbio_cell_growth_predator.7.o
	) >src/f_binbio_cell_growth_predator.8.o
	local sz_8=$(stat -c '%s' src/f_binbio_cell_growth_predator.8.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_8)
	cat src/f_binbio_cell_growth_predator.8.o

	# regE(tile_x) == 0 ?
	lr35902_copy_to_from regA regE
	lr35902_compare_regA_and 00
	(
		# tile_x != 0 の場合

		# 左座標をチェックし、
		# タイル番号が白/黒デイジーであれば捕食処理を実施
		## アドレスregHLを対象座標へ移動
		lr35902_dec regHL
		## アドレスregHLのタイル番号が白/黒デイジーであれば捕食処理を実施
		cat src/f_binbio_cell_growth_predator.check_and_prey.o
		## アドレスregHLを元に戻す
		lr35902_inc regHL
	) >src/f_binbio_cell_growth_predator.9.o
	local sz_9=$(stat -c '%s' src/f_binbio_cell_growth_predator.9.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_9)
	cat src/f_binbio_cell_growth_predator.9.o

	# TODO

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 捕食者用突然変異関数
f_binbio_cell_mutation_predator() {
	# push
	## TODO

	# TODO

	# pop & return
	## TODO
	lr35902_return
}
