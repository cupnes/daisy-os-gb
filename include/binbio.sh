if [ "${INCLUDE_BINBIO_SH+is_defined}" ]; then
	return
fi

. include/common.sh

INCLUDE_BINBIO_SH=true

# 細胞データ構造のサイズ[バイト]
BINBIO_CELL_DATA_SIZE=0e

# 細胞の機械語バイナリのロード先アドレス
BINBIO_BIN_LOAD_ADDR=c007

# 細胞データ領域
BINBIO_CELL_DATA_AREA_BEGIN=c090	# 最初のアドレス
BINBIO_CELL_DATA_AREA_END=c2f7	# 最後のアドレス
## ※ 「(最後のアドレス + 1) - 最初のアドレス」が
## 　 細胞データ構造のサイズの倍数であること
BINBIO_CELL_DATA_AREA_SIZE=$(four_digits $(calc16 "${BINBIO_CELL_DATA_AREA_END}-${BINBIO_CELL_DATA_AREA_BEGIN}+1"))

# 細胞の「死」の振る舞い
# 現在の細胞の`alive`フラグをクリアする
binbio_cell_death() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# regHLへ現在の細胞のアドレスを設定する
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# regHLのアドレスをフラグの位置まで進める
	lr35902_set_reg regBC 0002
	lr35902_add_to_regHL regBC

	# aliveフラグをクリア
	lr35902_res_bitN_of_reg 0 ptrHL

	# pop
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
}
