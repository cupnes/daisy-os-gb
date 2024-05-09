# 定数
## モード名を配置するタイル座標
CELL_EVAL_CONF_LABEL_TCOORD_X=00
CELL_EVAL_CONF_LABEL_TCOORD_Y=0A
## 枠線を配置するタイル座標
CELL_EVAL_CONF_FRAME_TCOORD_X=00
CELL_EVAL_CONF_FRAME_TCOORD_Y=0B
CELL_EVAL_CONF_FRAME_WIDTH=14
CELL_EVAL_CONF_FRAME_HEIGHT=07
## パラメータ文字列配置座標
CELL_EVAL_CONF_PARAM_LABEL_BASE_TCOORD_Y=0C
CELL_EVAL_CONF_PARAM_LABEL_TCOORD_X=02
## パラメータ番号
CELL_EVAL_CONF_PARAMNO_FIXEDVAL_VAL=00

# 評価関数設定を画面へ配置
f_binbio_place_cell_eval_conf() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL
	## TODO

	# ラベルを配置
	con_print_xy_macro $CELL_EVAL_CONF_LABEL_TCOORD_X $CELL_EVAL_CONF_LABEL_TCOORD_Y $a_const_cell_eval_conf

	# 枠線を配置
	con_draw_rect_macro $CELL_EVAL_CONF_FRAME_TCOORD_X $CELL_EVAL_CONF_FRAME_TCOORD_Y $CELL_EVAL_CONF_FRAME_WIDTH $CELL_EVAL_CONF_FRAME_HEIGHT

	# 現在の評価関数 == 固定値を返す評価関数?
	lr35902_copy_to_regA_from_addr $var_binbio_expset_num
	lr35902_compare_regA_and $CELL_EVAL_NUM_FIXEDVAL
	(
		# 現在の評価関数 == 固定値を返す評価関数 の場合

		# 固定値を返す評価関数のパラメータ配置関数を呼び出す
		lr35902_call $a_binbio_place_fixedval_param
	) >src/status_disp_cell_eval_conf.f_binbio_place_cell_eval_conf.fixedval.o
	local sz_fixedval=$(stat -c '%s' src/status_disp_cell_eval_conf.f_binbio_place_cell_eval_conf.fixedval.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_fixedval)
	cat src/status_disp_cell_eval_conf.f_binbio_place_cell_eval_conf.fixedval.o

	# TODO

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	## TODO
	lr35902_return
}

# 評価関数設定をクリア
f_binbio_clear_cell_eval_conf() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regDE
	## TODO

	# ラベルをクリア
	con_delch_tadr_num_macro $CELL_EVAL_CONF_LABEL_TCOORD_X $CELL_EVAL_CONF_LABEL_TCOORD_Y $((sz_const_cell_eval_conf - 1))

	# 枠線と中身をクリア
	con_clear_rect_macro $CELL_EVAL_CONF_FRAME_TCOORD_X $CELL_EVAL_CONF_FRAME_TCOORD_Y $CELL_EVAL_CONF_FRAME_WIDTH $CELL_EVAL_CONF_FRAME_HEIGHT

	# TODO

	# pop & return
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
	## TODO
	lr35902_return
}

# 現在の評価関数番号とパラメータ番号に対応する変数のアドレスを取得
# out: regHL - 対象の変数のアドレス
f_binbio_get_var_from_current_cell_eval_and_param() {
	# push
	lr35902_push_reg regAF

	# regAへ現在の評価関数番号を取得
	lr35902_copy_to_regA_from_addr $var_binbio_expset_num

	local obj

	# regA == デイジーワールド ?
	lr35902_compare_regA_and $CELL_EVAL_NUM_DAISYWORLD
	obj=src/status_disp_cell_eval_conf.f_binbio_get_var_from_current_cell_eval_and_param.daisyworld.o
	(
		# regA == デイジーワールド の場合

		# 戻り値へNULLを設定
		lr35902_set_reg regHL $GBOS_NULL

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >$obj
	local sz_daisyworld=$(stat -c '%s' $obj)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisyworld)
	cat $obj

	# regA == 固定値 ?
	lr35902_compare_regA_and $CELL_EVAL_NUM_FIXEDVAL
	obj=src/status_disp_cell_eval_conf.f_binbio_get_var_from_current_cell_eval_and_param.fixedval.o
	(
		# regA == 固定値 の場合

		# 戻り値へNULLを設定
		lr35902_set_reg regHL $GBOS_NULL

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >$obj
	local sz_fixedval=$(stat -c '%s' $obj)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_fixedval)
	cat $obj

	# regAがその他の値の場合(現状、このパスには来ないはず)
	# もしこのパスに来るようであれば無限ループで止める
	infinite_halt

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# 現在の評価関数番号のパラメータ番号を配置するタイルアドレスを取得
# out: regHL - タイルアドレス
f_binbio_get_tadr_from_current_cell_eval_and_param() {
	# push
	lr35902_push_reg regAF

	# regAへ現在の評価関数番号を取得
	lr35902_copy_to_regA_from_addr $var_binbio_expset_num

	local obj

	# regA == デイジーワールド ?
	lr35902_compare_regA_and $CELL_EVAL_NUM_DAISYWORLD
	obj=src/status_disp_cell_eval_conf.f_binbio_get_tadr_from_current_cell_eval_and_param.daisyworld.o
	(
		# regA == デイジーワールド の場合

		# 戻り値へNULLを設定
		lr35902_set_reg regHL $GBOS_NULL

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >$obj
	local sz_daisyworld=$(stat -c '%s' $obj)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisyworld)
	cat $obj

	# regA == 固定値 ?
	lr35902_compare_regA_and $CELL_EVAL_NUM_FIXEDVAL
	obj=src/status_disp_cell_eval_conf.f_binbio_get_tadr_from_current_cell_eval_and_param.fixedval.o
	(
		# regA == 固定値 の場合

		# 戻り値へNULLを設定
		lr35902_set_reg regHL $GBOS_NULL

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >$obj
	local sz_fixedval=$(stat -c '%s' $obj)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_fixedval)
	cat $obj

	# regAがその他の値の場合(現状、このパスには来ないはず)
	# もしこのパスに来るようであれば無限ループで止める
	infinite_halt

	# pop & return
	lr35902_pop_reg regAF
	lr35902_return
}

# 固定値を返す評価関数のパラメータを画面へ配置
f_binbio_place_fixedval_param() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL
	## TODO

	# ラベルを配置
	con_print_xy_macro $CELL_EVAL_CONF_PARAM_LABEL_TCOORD_X $CELL_EVAL_CONF_PARAM_LABEL_BASE_TCOORD_Y $a_const_fixedval_param_val

	# 16進数の接頭時を配置
	con_print_xy_macro $(calc16_2 "${CELL_EVAL_CONF_PARAM_LABEL_TCOORD_X}+${sz_const_fixedval_param_val}-1") $CELL_EVAL_CONF_PARAM_LABEL_BASE_TCOORD_Y $a_const_pref_hex

	# 値を配置
	## regAへ現在の固定値を取得
	lr35902_copy_to_regA_from_addr $var_binbio_cell_eval_fixedval_val
	## regAの値を16進数で配置
	lr35902_call $a_print_regA

	# 現在選択しているパラメータの左に「→」を配置
	con_putxy_macro $(calc16_2 "${CELL_EVAL_CONF_PARAM_LABEL_TCOORD_X}-1") $CELL_EVAL_CONF_PARAM_LABEL_BASE_TCOORD_Y '→'

	# TODO

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	## TODO
	lr35902_return
}
