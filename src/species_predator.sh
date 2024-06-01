# 生物種「捕食者」用のスクリプト

# [定数]

## 白/黒デイジーの細胞データのデフォルト値
CELL_DEFAULT_FLAGS_PREDATOR=01
CELL_DEFAULT_LIFE_DURATION_PREDATOR=60
CELL_DEFAULT_LIFE_LEFT_PREDATOR=$CELL_DEFAULT_LIFE_DURATION_PREDATOR
CELL_DEFAULT_FITNESS_PREDATOR=80
CELL_DEFAULT_BIN_SIZE_PREDATOR=05
CELL_DEFAULT_BIN_DATA_0_PREDATOR=00
CELL_DEFAULT_BIN_DATA_1_PREDATOR=00
CELL_DEFAULT_BIN_DATA_2_PREDATOR=00
CELL_DEFAULT_BIN_DATA_3_PREDATOR=00
CELL_DEFAULT_BIN_DATA_4_PREDATOR=00
CELL_DEFAULT_COLLECTED_FLAGS_PREDATOR=00

# 適応度
SPECIES_PREDATOR_FITNESS=$CELL_DEFAULT_FITNESS_PREDATOR

# 捕食サイクル
SPECIES_PREDATOR_PREY_CYCLE=03

# collected_flags更新方式
# - 'bit': 1ビットずつセット
# - 'inc': インクリメント
SPECIES_PREDATOR_COLLECTED_FLAGS_UPDATE_MODE='bit'



# [関数]

# 指定されたアドレスへ捕食者のデフォルト値を設定
# in : regD  - 捕食者のタイル座標Y
#      regE  - 捕食者のタイル座標X
#      regHL - デフォルト値を設定する領域の先頭アドレス
f_binbio_cell_set_default_predator() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# flags
	lr35902_set_reg regA $CELL_DEFAULT_FLAGS_PREDATOR
	lr35902_copyinc_to_ptrHL_from_regA

	# tile_x
	lr35902_copy_to_from regA regE
	lr35902_copyinc_to_ptrHL_from_regA

	# tile_y
	lr35902_copy_to_from regA regD
	lr35902_copyinc_to_ptrHL_from_regA

	# life_duration
	lr35902_set_reg regA $CELL_DEFAULT_LIFE_DURATION_PREDATOR
	lr35902_copyinc_to_ptrHL_from_regA

	# life_left
	lr35902_set_reg regA $CELL_DEFAULT_LIFE_LEFT_PREDATOR
	lr35902_copyinc_to_ptrHL_from_regA

	# fitness
	lr35902_set_reg regA $CELL_DEFAULT_FITNESS_PREDATOR
	lr35902_copyinc_to_ptrHL_from_regA

	# tile_num
	lr35902_set_reg regA $GBOS_TILE_NUM_PREDATOR
	lr35902_copyinc_to_ptrHL_from_regA

	# bin_size
	lr35902_set_reg regA $CELL_DEFAULT_BIN_SIZE_PREDATOR
	lr35902_copyinc_to_ptrHL_from_regA

	# bin_data
	local byte_in_inst
	for byte_in_inst in $CELL_DEFAULT_BIN_DATA_0_PREDATOR \
				    $CELL_DEFAULT_BIN_DATA_1_PREDATOR \
				    $CELL_DEFAULT_BIN_DATA_2_PREDATOR \
				    $CELL_DEFAULT_BIN_DATA_3_PREDATOR \
				    $CELL_DEFAULT_BIN_DATA_4_PREDATOR; do
		lr35902_set_reg regA $byte_in_inst
		lr35902_copyinc_to_ptrHL_from_regA
	done

	# collected_flags
	lr35902_set_reg regA $CELL_DEFAULT_COLLECTED_FLAGS_PREDATOR
	lr35902_copy_to_from ptrHL regA

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
	lr35902_return
}

# 捕食者用評価関数
# 定義された固定値を適応度として返す
# out: regA - 評価結果の適応度(0x00〜0xff)
f_binbio_cell_eval_predator() {
	# 戻り値としてregAへ固定値を設定
	lr35902_set_reg regA $SPECIES_PREDATOR_FITNESS

	# return
	lr35902_return
}

# 捕食者用成長関数用の捕食処理
# ※ 捕食者用成長関数で呼ばれることを想定し、特にpush・popは行っていない
f_binbio_cell_growth_predator_prey() {
	local obj_pref

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
	lr35902_copy_to_from regD ptrHL
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
	## collected_flags更新方式別に分岐
	case $SPECIES_PREDATOR_COLLECTED_FLAGS_UPDATE_MODE in
	'bit')
		# 1ビットずつセットする方式の場合

		# regAへcollected_flagsを取得
		lr35902_copy_to_from regA ptrHL

		# collected_flags(regA)は0か?
		lr35902_compare_regA_and 00
		obj_pref=src/f_binbio_cell_growth_predator_prey.regA_is_0
		(
			# regAが0の場合

			# regAの最下位ビットに1を設定する
			lr35902_inc regA
		) >$obj_pref.true.o
		(
			# regAが0でない場合

			# regAを1ビット左シフト
			lr35902_shift_left_arithmetic regA

			# collected_flagsの最下位ビットに1を設定する
			lr35902_inc regA

			# regAが0の場合の処理を飛ばす
			local sz_regA_is_0_true=$(stat -c '%s' $obj_pref.true.o)
			lr35902_rel_jump $(two_digits_d $sz_regA_is_0_true)
		) >$obj_pref.false.o
		local sz_regA_is_0_false=$(stat -c '%s' $obj_pref.false.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_regA_is_0_false)
		cat $obj_pref.false.o
		cat $obj_pref.true.o
		## 更新後のregAをcollected_flagsへ設定
		lr35902_copy_to_from ptrHL regA
		;;
	'inc')
		# インクリメント方式の場合

		# 自身のcollected_flagsをインクリメント
		lr35902_inc ptrHL
		;;
	*)
		echo -n 'Error: invalid collected_flags update mode: ' 1>&2
		echo "$SPECIES_PREDATOR_COLLECTED_FLAGS_UPDATE_MODE" 1>&2
		return 1
	esac

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

	# return
	lr35902_return
}

# 捕食者用成長関数
# 8近傍を見て、デイジーが居れば補食し、その座標へ移動する
f_binbio_cell_growth_predator() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	local obj
	local obj_pref=src/f_binbio_cell_growth_predator
	local obj_base

	# [捕食サイクルチェック]
	# 自身の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# regAへflagsを取得
	lr35902_copy_to_from regA ptrHL

	# 捕食サイクルカウンタ部分をインクリメント
	lr35902_add_to_regA 04

	# regBへインクリメント後のflagsを退避
	lr35902_copy_to_from regB regA

	# regAへ捕食サイクルカウンタ部分のみを取り出す
	# (2ビット右シフトする)
	lr35902_shift_right_logical regA
	lr35902_shift_right_logical regA

	# 捕食サイクルカウンタが捕食サイクルに達したか?
	lr35902_compare_regA_and $SPECIES_PREDATOR_PREY_CYCLE
	(
		# 捕食サイクルカウンタが捕食サイクルに達していない場合
		# (捕食中。まだ捕食が完了していない)

		# インクリメント後のflagsを変数へ書き戻す
		lr35902_copy_to_from ptrHL regB

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) | rel_jump_wrapper_binsz NC forward

	# 捕食サイクルカウンタが捕食サイクルに達した場合
	## regAへインクリメント後のflagsを復帰
	lr35902_copy_to_from regA regB
	## 捕食サイクルカウンタ部分をゼロクリア
	lr35902_and_to_regA f3
	## 変数へ書き戻す
	lr35902_copy_to_from ptrHL regA



	# push
	lr35902_push_reg regDE

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
	## pop & return
	(
		# pop & return
		lr35902_pop_reg regDE
		lr35902_pop_reg regHL
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >$obj_pref.pop_and_return.o
	## アドレスregHLのタイル番号が白/黒デイジーであれば
	## 捕食処理を実施しreturn
	## in  : regHL - 対象のミラー領域上のアドレス
	##       regD  - 対象のタイル座標Y
	##       regE  - 対象のタイル座標X
	## work: regAF, regBC
	## ※ regDE・regHLを変更しないこと
	obj_base=$obj_pref.check_and_prey_return
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
		obj=src/f_binbio_cell_growth_predator.prey_return.o
		(
			# regB == 1 の場合

			# push
			lr35902_push_reg regHL

			# regBへ自身の細胞の適応度を取得
			## regHLへ自身の細胞のアドレスを取得
			lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
			lr35902_copy_to_from regL regA
			lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
			lr35902_copy_to_from regH regA
			## アドレスregHLをfitnessまで進める
			lr35902_set_reg regBC 0005
			lr35902_add_to_regHL regBC
			## regBへ適応度を取得
			lr35902_copy_to_from regB ptrHL

			# regBをregC含めてスタックへ退避
			lr35902_push_reg regBC

			# regAへ対象の細胞の適応度を取得
			## regHLへタイル座標(regE, regD)の細胞のアドレスを取得
			lr35902_call $a_binbio_find_cell_data_by_tile_xy
			## アドレスregHLをfitnessまで進める
			lr35902_set_reg regBC 0005
			lr35902_add_to_regHL regBC
			## regAへ適応度を取得
			lr35902_copy_to_from regA ptrHL

			# regBをregC含めてスタックから復帰
			lr35902_pop_reg regBC

			# pop
			lr35902_pop_reg regHL

			# regA(対象の適応度) < regB(自身の適応度) ?
			lr35902_compare_regA_and regB
			(
				# regA(対象の適応度) < regB(自身の適応度) の場合

				# 捕食処理
				lr35902_call $a_binbio_cell_growth_predator_prey

				# pop & return
				cat $obj_pref.pop_and_return.o
			) | rel_jump_wrapper_binsz NC forward
		) >$obj
		local sz_prey_return=$(stat -c '%s' $obj)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_prey_return)
		cat $obj
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

			# 左上座標を確認し、条件に合えば捕食処理を実施しreturn
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC $(two_comp_4 21)
			lr35902_add_to_regHL regBC
			## (regE, regD)を対象座標へ移動
			lr35902_dec regE
			lr35902_dec regD
			## 条件に合えば捕食処理を実施しreturn
			cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
			## (regE, regD)を元に戻す
			lr35902_inc regE
			lr35902_inc regD
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC 0021
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_growth_predator.2.o
		local sz_2=$(stat -c '%s' src/f_binbio_cell_growth_predator.2.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
		cat src/f_binbio_cell_growth_predator.2.o

		# 上座標を確認し、条件に合えば捕食処理を実施しreturn
		## アドレスregHLを対象座標へ移動
		lr35902_set_reg regBC $(two_comp_4 20)
		lr35902_add_to_regHL regBC
		## (regE, regD)を対象座標へ移動
		lr35902_dec regD
		## 条件に合えば捕食処理を実施しreturn
		cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
		## (regE, regD)を元に戻す
		lr35902_inc regD
		## アドレスregHLを元に戻す
		lr35902_set_reg regBC 0020
		lr35902_add_to_regHL regBC

		# regE(tile_x) == 表示範囲の右端 ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and $(calc16_2 "${GB_DISP_WIDTH_T}-1")
		(
			# tile_x != 表示範囲の右端 の場合

			# 右上座標を確認し、条件に合えば捕食処理を実施しreturn
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC $(two_comp_4 1f)
			lr35902_add_to_regHL regBC
			## (regE, regD)を対象座標へ移動
			lr35902_inc regE
			lr35902_dec regD
			## 条件に合えば捕食処理を実施しreturn
			cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
			## (regE, regD)を元に戻す
			lr35902_dec regE
			lr35902_inc regD
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

		# 右座標を確認し、条件に合えば捕食処理を実施しreturn
		## アドレスregHLを対象座標へ移動
		lr35902_inc regHL
		## (regE, regD)を対象座標へ移動
		lr35902_inc regE
		## 条件に合えば捕食処理を実施しreturn
		cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
		## (regE, regD)を元に戻す
		lr35902_dec regE
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

			# 右下座標を確認し、条件に合えば捕食処理を実施しreturn
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC 0021
			lr35902_add_to_regHL regBC
			## (regE, regD)を対象座標へ移動
			lr35902_inc regE
			lr35902_inc regD
			## 条件に合えば捕食処理を実施しreturn
			cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
			## (regE, regD)を元に戻す
			lr35902_dec regE
			lr35902_dec regD
			## アドレスregHLを元に戻す
			lr35902_set_reg regBC $(two_comp_4 21)
			lr35902_add_to_regHL regBC
		) >src/f_binbio_cell_growth_predator.6.o
		local sz_6=$(stat -c '%s' src/f_binbio_cell_growth_predator.6.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_6)
		cat src/f_binbio_cell_growth_predator.6.o

		# 下座標を確認し、条件に合えば捕食処理を実施しreturn
		## アドレスregHLを対象座標へ移動
		lr35902_set_reg regBC 0020
		lr35902_add_to_regHL regBC
		## (regE, regD)を対象座標へ移動
		lr35902_inc regD
		## 条件に合えば捕食処理を実施しreturn
		cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
		## (regE, regD)を元に戻す
		lr35902_dec regD
		## アドレスregHLを元に戻す
		lr35902_set_reg regBC $(two_comp_4 20)
		lr35902_add_to_regHL regBC

		# regE(tile_x) == 0 ?
		lr35902_copy_to_from regA regE
		lr35902_compare_regA_and 00
		(
			# tile_x != 0 の場合

			# 左下座標を確認し、条件に合えば捕食処理を実施しreturn
			## アドレスregHLを対象座標へ移動
			lr35902_set_reg regBC 001f
			lr35902_add_to_regHL regBC
			## (regE, regD)を対象座標へ移動
			lr35902_dec regE
			lr35902_inc regD
			## 条件に合えば捕食処理を実施しreturn
			cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
			## (regE, regD)を元に戻す
			lr35902_inc regE
			lr35902_dec regD
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

		# 左座標を確認し、条件に合えば捕食処理を実施しreturn
		## アドレスregHLを対象座標へ移動
		lr35902_dec regHL
		## (regE, regD)を対象座標へ移動
		lr35902_dec regE
		## 条件に合えば捕食処理を実施しreturn
		cat src/f_binbio_cell_growth_predator.check_and_prey_return.o
		## (regE, regD)を元に戻す
		lr35902_inc regE
		## アドレスregHLを元に戻す
		lr35902_inc regHL
	) >src/f_binbio_cell_growth_predator.9.o
	local sz_9=$(stat -c '%s' src/f_binbio_cell_growth_predator.9.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_9)
	cat src/f_binbio_cell_growth_predator.9.o

	# pop & return
	cat $obj_pref.pop_and_return.o
}

# 捕食者用突然変異関数
# 何もしない
f_binbio_cell_mutation_predator() {
	# return
	lr35902_return
}

# 捕食者用成長関数用の確認&捕食処理
f_binbio_cell_growth_predator_check_and_prey() {
	# push
	## TODO

	# TODO

	# pop & return
	## TODO
	lr35902_return
}
