# 定数
## モード名を配置するタイル座標
CELL_EVAL_CONF_LABEL_TCOORD_X=00
CELL_EVAL_CONF_LABEL_TCOORD_Y=0A
## 枠線を配置するタイル座標
CELL_EVAL_CONF_FRAME_TCOORD_X=00
CELL_EVAL_CONF_FRAME_TCOORD_Y=0B
CELL_EVAL_CONF_FRAME_WIDTH=0E
CELL_EVAL_CONF_FRAME_HEIGHT=07

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
