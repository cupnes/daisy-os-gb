if [ "${INCLUDE_BINBIO_SH+is_defined}" ]; then
	return
fi
INCLUDE_BINBIO_SH=true

# 細胞データ構造のサイズ[バイト]
BINBIO_CELL_DATA_SIZE=0e

# 細胞の機械語バイナリのロード先アドレス
BINBIO_BIN_LOAD_ADDR=c007

# 細胞データ領域
BINBIO_CELL_DATA_AREA_BEGIN=c090	# 最初のアドレス
BINBIO_CELL_DATA_AREA_END=c2ff	# 最後のアドレス

# 細胞の「成長」の振る舞い
# 現在の細胞の機械語バイナリの中に取得したコード化合物と同じものが存在したら、
# 対応するcollected_flagsのビットをセットする
# in : regA  - 取得したコード化合物
# TODO コード化合物は引数で受け取るのではなく、この関数内で取得するようにする
binbio_cell_growth() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 取得したコード化合物をregDへコピー
	lr35902_copy_to_from regD regA

	# regHLへ現在の細胞のアドレスを設定する
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# TODO 細胞データ構造が変わったのでオフセットを使用した箇所を修正する

	# regHLのアドレスを機械語バイナリサイズの位置まで進める
	lr35902_set_reg regBC 0009
	lr35902_add_to_regHL regBC

	# 機械語バイナリサイズをregBへコピー
	lr35902_copy_to_from regB ptrHL

	# regBCをスタックへpush
	lr35902_push_reg regBC

	# regHLのアドレスを機械語バイナリの各バイトの取得フラグの位置まで進める
	lr35902_set_reg regBC 0006
	lr35902_add_to_regHL regBC

	# 取得フラグをregEへコピー
	lr35902_copy_to_from regE ptrHL

	# regHLのアドレスを機械語バイナリの位置まで戻す
	lr35902_set_reg regBC $(two_comp_4 5)
	lr35902_add_to_regHL regBC

	# regBCをスタックからpop
	lr35902_pop_reg regBC

	# regCをゼロクリア(処理したバイト数のカウンタにする)
	lr35902_set_reg regC 00

	# 機械語バイナリを1バイトずつチェック
	## regE(取得フラグ)を1ビットずつ右ローテートさせながらチェックする
	(
		# ptrHL == regD ?
		lr35902_copy_to_from regA regD
		lr35902_compare_regA_and ptrHL
		(
			# ptrHL == regD の場合

			# ループ脱出フラグ(regA)をゼロクリア
			lr35902_xor_to_regA regA

			# regEのビット0 == 0 ?
			lr35902_test_bitN_of_reg 0 regE
			(
				# regEのビット0 == 0 の場合

				# regEのビット0をセットする
				lr35902_set_bitN_of_reg 0 regE

				# ループ脱出フラグを設定
				lr35902_inc regA
			) >src/binbio_cell_growth.3.o
			local sz_3=$(stat -c '%s' src/binbio_cell_growth.3.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
			cat src/binbio_cell_growth.3.o
		) >src/binbio_cell_growth.1.o
		(
			# ptrHL != regD の場合

			# ループ脱出フラグ(regA)をゼロクリア
			lr35902_xor_to_regA regA

			# ptrHL == regD の場合の処理を飛ばす
			local sz_1=$(stat -c '%s' src/binbio_cell_growth.1.o)
			lr35902_rel_jump $(two_digits_d $sz_1)
		) >src/binbio_cell_growth.2.o
		local sz_2=$(stat -c '%s' src/binbio_cell_growth.2.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
		cat src/binbio_cell_growth.2.o	# ptrHL != regD
		cat src/binbio_cell_growth.1.o	# ptrHL == regD

		# regEを1ビット右ローテート
		## regBCをスタックへpush
		lr35902_push_reg regBC
		## regAをregBへ退避
		lr35902_copy_to_from regB regA
		## regEをregAへコピー
		lr35902_copy_to_from regA regE
		## regAを1ビット右ローテート
		lr35902_rot_regA_right
		## regAをregEへコピー
		lr35902_copy_to_from regE regA
		## regAをregBから復帰
		lr35902_copy_to_from regA regB
		## regBCをスタックからpop
		lr35902_pop_reg regBC

		# 処理したバイト数カウンタ(regC)をインクリメント
		lr35902_inc regC

		# regBの機械語バイナリサイズをデクリメント
		lr35902_dec regB

		# regB == 0 ?
		## regDEをスタックへpush
		lr35902_push_reg regDE
		## regAをregDへ退避
		lr35902_copy_to_from regD regA
		## regBをregAへコピー
		lr35902_copy_to_from regA regB
		## regA == 0 ?
		lr35902_compare_regA_and 00
		(
			# regA == 0 の場合

			# ループ脱出フラグを設定
			lr35902_inc regA
		) >src/binbio_cell_growth.4.o
		local sz_4=$(stat -c '%s' src/binbio_cell_growth.4.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
		cat src/binbio_cell_growth.4.o
		## regAをregDから復帰
		lr35902_copy_to_from regA regD
		## regDEをスタックからpop
		lr35902_pop_reg regDE

		# regA != 0 なら、1バイトずつチェックするループを脱出する
		## TODO
	) >src/binbio_cell_growth.5.o
	local sz_5=$(stat -c '%s' src/binbio_cell_growth.5.o)
	lr35902_rel_jump $(two_comp_d $((sz_5 + 2)))

	# regA = 8 - 処理したバイト数(regC)
	lr35902_set_reg regA 08
	lr35902_sub_to_regA regC

	# # regA != 0 ?
	# lr35902_compare_regA_and 00
	# (
	# 	# regA != 0 の場合

	# 	# regAの値だけregEを右ローテート
	# 	## TODO
	# ) >src/binbio_cell_growth.6.o
	# local sz_6=$(stat -c '%s' src/binbio_cell_growth.6.o)
	# lr35902_rel_jump_with_cond Z $(two_digits_d $sz_6)
	# cat src/binbio_cell_growth.6.o

	# regEを細胞の機械語バイナリの各バイトの取得フラグへ書き戻す
	## TODO

	# pop
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
}

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
