if [ "${INCLUDE_EXPSET_HELLO_SH+is_defined}" ]; then
	return
fi
INCLUDE_EXPSET_HELLO_SH=true

# main.shの中で一通りのシェルスクリプトの読み込みが終わった後でこのファイルが読み込まれる想定
# なので、このファイル内で個別のシェルスクリプトの読み込みは行っていない。

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
