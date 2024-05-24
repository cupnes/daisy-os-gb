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
	local obj_base

	# [8近傍をチェック]
	# 自身の細胞の8近傍を左上から順に時計回りでチェック

	# 自身の細胞のタイル座標(X, Y)を(regE, regD)へ取得
	## 自身の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA
	## アドレスregHLをtile_xまで進める
	lr35902_inc regHL
	## regEへ自身の細胞のtile_xを取得
	lr35902_copy_to_from regE ptrHL
	## アドレスregHLをtile_yまで進める
	lr35902_inc regHL
	## regDへ自身の細胞のtile_yを取得
	lr35902_copy_to_from regD ptrHL

	# 自身の細胞のタイルのタイルミラー領域上のアドレスをregHLへ設定
	lr35902_call $a_tcoord_to_mrraddr

	# 繰り返し使用する処理をファイル書き出し/マクロ定義
	## 捕食処理を実施しreturn
	obj=src/f_binbio_cell_growth_predator.prey_return.o
	(
		# 対象の細胞を消去
		## 対象の細胞のタイルミラー領域上のアドレス(regHL)から
		## 対象の細胞のアドレスを算出
		### タイルミラー領域上のアドレスからタイル座標を算出
		lr35902_call $a_mrraddr_to_tcoord
		### タイル座標から細胞のアドレスを取得
		lr35902_call $a_binbio_find_cell_data_by_tile_xy
		## regBCへ自身の細胞のアドレス変数の値を退避
		lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
		lr35902_copy_to_from regC regA
		lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
		lr35902_copy_to_from regB regA
		## 対象の細胞のアドレスを自身の細胞のアドレス変数へ設定
		lr35902_copy_to_from regA regL
		lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_bh
		lr35902_copy_to_from regA regH
		lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_th
		## 死の振る舞いを実施
		lr35902_call $a_binbio_cell_death
		## regBCから自身の細胞のアドレス変数の値を復帰
		lr35902_copy_to_from regA regC
		lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_bh
		lr35902_copy_to_from regA regB
		lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_th

		# この時、regBCに自身の細胞のアドレスが、
		# regHLに対象の細胞のアドレスが設定されている

		# 自身のtile_{x,y}を対象の細胞のtile_{x,y}で更新
		## regHLの対象の細胞のアドレスをtile_xまで進める
		lr35902_inc regHL
		## regEへ対象の細胞のtile_xを取得
		lr35902_copy_to_from regE ptrHL
		## regHLをtile_yまで進める
		lr35902_inc regHL
		## regDへ対象の細胞のtile_yを取得
		lr35902_copy_to_from regE ptrHL
		## regHLへ自身のアドレスを設定
		lr35902_copy_to_from regL regC
		lr35902_copy_to_from regH regB
		## regHLをtile_xまで進める
		lr35902_inc regHL
		## 後のためにregCへ自身のtile_xを退避
		lr35902_copy_to_from regC ptrHL
		## 自身のtile_xへregEを設定
		lr35902_copy_to_from ptrHL regE
		## regHLをtile_yまで進める
		lr35902_inc regHL
		## 後のためにregBへ自身のtile_yを退避
		lr35902_copy_to_from regB ptrHL
		## 自身のtile_yへregDを設定
		lr35902_copy_to_from ptrHL regD

		# この時、(regC, regB)に自身のtile{x,y}が、
		# (regE, regD)に対象の細胞のtile_{x,y}が、
		# regHLには自身のtile_yのアドレスが設定されている

		# 自身のcollected_flagsを更新
		# 現状はインクリメントするようにしている
		# bin_sizeが5なので、collected_flagsのbin_size分のビットが
		# 全て立つまで31(0x1f)サイクルかかる形
		# TODO チューニング項目
		## regBC(自身のtile{x,y})をスタックへ退避
		lr35902_push_reg regBC
		## regHLをcollected_flagsまで進める
		lr35902_set_reg regBC 000b
		lr35902_add_to_regHL regBC
		## 自身のcollected_flagsをインクリメント
		lr35902_inc ptrHL

		# 背景タイルマップ上で自身の表示を更新
		## 対象の細胞の座標へ捕食者タイルを配置
		### 対象の細胞のタイル座標(regE, regD)を
		### VRAMアドレス(regHL)へ変換
		lr35902_call $a_tcoord_to_addr
		### VRAMアドレスへ捕食者タイルを配置するエントリを
		### tdqへエンキュー
		lr35902_set_reg regB $GBOS_TILE_NUM_PREDATOR
		lr35902_copy_to_from regE regL
		lr35902_copy_to_from regD regH
		lr35902_call $a_enq_tdq
		## 自身の表示を消す(空白タイルを配置)
		### regBC(自身のtile{x,y})をスタックから復帰
		lr35902_pop_reg regBC
		### 自身のタイル座標をVRAMアドレス(regHL)へ変換
		lr35902_copy_to_from regE regC
		lr35902_copy_to_from regD regB
		lr35902_call $a_tcoord_to_addr
		### VRAMアドレスへ空白タイルを配置するエントリをtdqへエンキュー
		lr35902_set_reg regB $GBOS_TILE_NUM_SPC
		lr35902_copy_to_from regE regL
		lr35902_copy_to_from regD regH
		lr35902_call $a_enq_tdq

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regDE
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >$obj
	local sz_prey_return=$(stat -c '%s' $obj)
	## アドレスregHLのタイル番号が白/黒デイジーであれば
	## 捕食処理を実施しreturn
	## ※ regDE・regHLを変更しないこと
	obj_base=src/f_binbio_cell_growth_predator.check_and_prey_return
	(
		# regAへアドレスregHLのタイル番号を取得
		lr35902_copy_to_from regA ptrHL

		# regAが白/黒デイジーであればregBへ1を設定
		# (そうでなければ0を設定)
		## regBをゼロクリア
		lr35902_clear_reg regB
		## フラグセット処理をファイルへ出力
		(
			# regBへ1を設定
			lr35902_set_reg regB 01
		) >${obj_base}.set_flag.o
		local sz_check_and_prey_return_set_flag=$(stat -c '%s' ${obj_base}.set_flag.o)
		## regA == 白デイジー ?
		lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_WHITE
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_check_and_prey_return_set_flag)
		### そうならregBへ1を設定
		cat ${obj_base}.set_flag.o
		## regA == 黒デイジー ?
		lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_BLACK
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_check_and_prey_return_set_flag)
		### そうならregBへ1を設定
		cat ${obj_base}.set_flag.o
		## regB == 1 ?
		lr35902_set_reg regA 01
		lr35902_compare_regA_and regB
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_prey_return)
		### そうなら捕食処理を実施しreturn
		cat src/f_binbio_cell_growth_predator.prey_return.o
	) >${obj_base}.o
	local sz_check_and_prey_return=$(stat -c '%s' ${obj_base}.o)

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
			## アドレスregHLのタイル番号が白/黒デイジーであれば
			## 捕食処理を実施しreturn
			cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
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
		## アドレスregHLのタイル番号が白/黒デイジーであれば
		## 捕食処理を実施しreturn
		cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
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
			## アドレスregHLのタイル番号が白/黒デイジーであれば
			## 捕食処理を実施しreturn
			cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
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
		## アドレスregHLのタイル番号が白/黒デイジーであれば
		## 捕食処理を実施しreturn
		cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
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
			## アドレスregHLのタイル番号が白/黒デイジーであれば
			## 捕食処理を実施しreturn
			cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
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
		## アドレスregHLのタイル番号が白/黒デイジーであれば
		## 捕食処理を実施しreturn
		cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
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
			## アドレスregHLのタイル番号が白/黒デイジーであれば
			## 捕食処理を実施しreturn
			cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
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
		## アドレスregHLのタイル番号が白/黒デイジーであれば
		## 捕食処理を実施しreturn
		cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
		## アドレスregHLを元に戻す
		lr35902_inc regHL
	) >src/f_binbio_cell_growth_predator.9.o
	local sz_9=$(stat -c '%s' src/f_binbio_cell_growth_predator.9.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_9)
	cat src/f_binbio_cell_growth_predator.9.o

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
