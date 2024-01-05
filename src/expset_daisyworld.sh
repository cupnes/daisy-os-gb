if [ "${SRC_EXPSET_DAISYWORLD_SH+is_defined}" ]; then
	return
fi
SRC_EXPSET_DAISYWORLD_SH=true

# main.shの中で一通りのシェルスクリプトの読み込みが終わった後でこのファイルが読み込まれる想定
# なので、このファイル内で個別のシェルスクリプトの読み込みは行っていない。

# 定数
## # デイジーの生育適温(20℃)
DAISY_GROWING_TEMP=14
## 地表温度をインクリメント/デクリメントする前段カウンタのしきい値
## 前段カウンタの絶対値がこの値に達したら地表温度をインクリメント/デクリメントする
SURFACE_TEMP_INCDEC_PREV_COUNTER_TH=0a
## ステータス表示領域
STATUS_DISP_TADR_SURFACE_TEMP_TITLE=9805	# 地表温度のタイトルの箇所のタイルアドレス
STATUS_DISP_TADR_SURFACE_TEMP_VAL=980e	# 地表温度の値の箇所のタイルアドレス

# 変数
## 地表温度をインクリメント/デクリメントする前段のカウンタのアドレス
## 黒/白デイジーはこの変数をインクリメント/デクリメントする
var_binbio_surface_temp_prev_counter=c034
## 地表温度(-128〜127)のアドレス
var_binbio_surface_temp=c035

# 繰り返し使用する処理をファイル書き出し
## 現在の細胞が白デイジーか否か
## out : regA - 現在の細胞が白デイジーなら1、それ以外は0
## work: regBC, regHL
## ※ フラグレジスタは破壊される
{
	# push
	lr35902_push_reg regBC
	lr35902_push_reg regHL

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

	# pop
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
} >src/expset_daisyworld.is_daisy_white.o

# 現在の細胞を評価する
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval() {
	# push
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# 前段のカウンタの絶対値がしきい値以上であれば地表温度をインクリメント/デクリメントする
	## 前段のカウンタ >= 0?
	lr35902_copy_to_regA_from_addr $var_binbio_surface_temp_prev_counter
	lr35902_test_bitN_of_reg 7 regA
	(
		# 前段のカウンタ >= 0(regAのMSBが0)の場合

		# 前段のカウンタ >= しきい値?
		lr35902_compare_regA_and $SURFACE_TEMP_INCDEC_PREV_COUNTER_TH
		(
			# 前段のカウンタ >= しきい値の場合

			# 地表温度 != 127(0x7f)?
			lr35902_copy_to_regA_from_addr $var_binbio_surface_temp
			lr35902_compare_regA_and 7f
			(
				# 地表温度 != 127の場合

				# 地表温度をインクリメント
				lr35902_inc regA
				lr35902_copy_to_addr_from_regA $var_binbio_surface_temp
			) >src/expset_daisyworld.f_binbio_cell_eval.prev_counter_positive.ge_th.inc_st.o
			local sz_prev_counter_positive_ge_th_inc_st=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.prev_counter_positive.ge_th.inc_st.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_prev_counter_positive_ge_th_inc_st)
			cat src/expset_daisyworld.f_binbio_cell_eval.prev_counter_positive.ge_th.inc_st.o

			# 前段のカウンタをゼロクリア
			lr35902_xor_to_regA regA
			lr35902_copy_to_addr_from_regA $var_binbio_surface_temp_prev_counter
		) >src/expset_daisyworld.f_binbio_cell_eval.prev_counter_positive.ge_th.o
		local sz_prev_counter_positive_ge_th=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.prev_counter_positive.ge_th.o)
		lr35902_rel_jump_with_cond C $(two_digits_d $sz_prev_counter_positive_ge_th)
		cat src/expset_daisyworld.f_binbio_cell_eval.prev_counter_positive.ge_th.o
	) >src/expset_daisyworld.f_binbio_cell_eval.prev_counter_positive.o
	(
		# 前段のカウンタ < 0(regAのMSBが1)の場合

		# 前段のカウンタの絶対値を取得
		lr35902_complement_regA
		lr35902_inc regA

		# 前段のカウンタの絶対値 >= しきい値?
		lr35902_compare_regA_and $SURFACE_TEMP_INCDEC_PREV_COUNTER_TH
		(
			# 前段のカウンタの絶対値 >= しきい値の場合

			# 地表温度 != -128(0x80)?
			lr35902_copy_to_regA_from_addr $var_binbio_surface_temp
			lr35902_compare_regA_and 80
			(
				# 地表温度 != -128の場合

				# 地表温度をデクリメント
				lr35902_dec regA
				lr35902_copy_to_addr_from_regA $var_binbio_surface_temp
			) >src/expset_daisyworld.f_binbio_cell_eval.prev_counter_negative.ge_th.dec_st.o
			local sz_prev_counter_negative_ge_th_dec_st=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.prev_counter_negative.ge_th.dec_st.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_prev_counter_negative_ge_th_dec_st)
			cat src/expset_daisyworld.f_binbio_cell_eval.prev_counter_negative.ge_th.dec_st.o

			# 前段のカウンタをゼロクリア
			lr35902_xor_to_regA regA
			lr35902_copy_to_addr_from_regA $var_binbio_surface_temp_prev_counter
		) >src/expset_daisyworld.f_binbio_cell_eval.prev_counter_negative.ge_th.o
		local sz_prev_counter_negative_ge_th=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.prev_counter_negative.ge_th.o)
		lr35902_rel_jump_with_cond C $(two_digits_d $sz_prev_counter_negative_ge_th)
		cat src/expset_daisyworld.f_binbio_cell_eval.prev_counter_negative.ge_th.o

		# 前段のカウンタ >= 0の場合の処理を飛ばす
		local sz_prev_counter_positive=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.prev_counter_positive.o)
		lr35902_rel_jump $(two_digits_d $sz_prev_counter_positive)
	) >src/expset_daisyworld.f_binbio_cell_eval.prev_counter_negative.o
	local sz_prev_counter_negative=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.prev_counter_negative.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_prev_counter_negative)
	cat src/expset_daisyworld.f_binbio_cell_eval.prev_counter_negative.o
	cat src/expset_daisyworld.f_binbio_cell_eval.prev_counter_positive.o

	# regAに地表温度を設定
	lr35902_copy_to_regA_from_addr $var_binbio_surface_temp

	# 誤差を算出
	# (誤差 = 地表温度 - 生育適温)
	## -129以下の値は8ビットの2の補数で表せない。
	## そのため、負の方向の誤差は-128までとしておきたい。
	## 誤差 = 地表温度(regA) - 生育適温($DAISY_GROWING_TEMP)が-128未満の場合は
	## 誤差 = -128とし、regA - $DAISY_GROWING_TEMPを計算する処理を飛ばす。
	## なお、regA - $DAISY_GROWING_TEMP < -128 は
	## regA < $DAISY_GROWING_TEMP - 128 と変形できるので、
	## 「regA」と「$DAISY_GROWING_TEMP - 128」を比較する。
	lr35902_compare_regA_and $(calc16_2_two_comp "$DAISY_GROWING_TEMP-80")
	(
		# regA < $DAISY_GROWING_TEMP - 128 の場合

		# 例えば $DAISY_GROWING_TEMP = 0x15 の時、
		# $DAISY_GROWING_TEMP - 128 は2の補数で 0x94 であり、
		# 「regA >= $DAISY_GROWING_TEMP - 128 の場合」へ本来は
		# 分岐させたい regA = 0x15 等もここに来てしまう。
		# そこで、regAが負の値である(2の補数としては0x80以上である)事も
		# 確認する。
		## 0x7f < regA
		### regB = regA
		lr35902_copy_to_from regB regA
		### regA = 0x7f
		lr35902_set_reg regA 7f
		### regAとregBを比較
		lr35902_compare_regA_and regB
		(
			# 0x7f < regA の場合

			# regAへ誤差として-128(2の補数:0x80)を設定
			lr35902_set_reg regA 80
		) >src/expset_daisyworld.f_binbio_cell_eval.e_is_m128.o
		(
			# 0x7f >= regA の場合

			# regAへ誤差(regB - $DAISY_GROWING_TEMP)を設定
			lr35902_copy_to_from regA regB
			lr35902_sub_to_regA $DAISY_GROWING_TEMP

			# 0x7f < regA の場合の処理を飛ばす
			local sz_e_is_m128=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.e_is_m128.o)
			lr35902_rel_jump $(two_digits_d $sz_e_is_m128)
		) >src/expset_daisyworld.f_binbio_cell_eval.calc_e_2.o
		### regA < regB?
		local sz_calc_e_2=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.calc_e_2.o)
		lr35902_rel_jump_with_cond C $(two_digits_d $sz_calc_e_2)
		cat src/expset_daisyworld.f_binbio_cell_eval.calc_e_2.o
		cat src/expset_daisyworld.f_binbio_cell_eval.e_is_m128.o
	) >src/expset_daisyworld.f_binbio_cell_eval.st_lt.o
	(
		# regA >= $DAISY_GROWING_TEMP - 128 の場合

		# regAへ誤差(regA - $DAISY_GROWING_TEMP)を設定
		lr35902_sub_to_regA $DAISY_GROWING_TEMP

		# regA < $DAISY_GROWING_TEMP - 128 の場合の処理を飛ばす
		local sz_st_lt=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.st_lt.o)
		lr35902_rel_jump $(two_digits_d $sz_st_lt)
	) >src/expset_daisyworld.f_binbio_cell_eval.calc_e.o
	## regA < $DAISY_GROWING_TEMP - 128?
	local sz_calc_e=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.calc_e.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_calc_e)
	cat src/expset_daisyworld.f_binbio_cell_eval.calc_e.o
	cat src/expset_daisyworld.f_binbio_cell_eval.st_lt.o

	# 誤差 >= 0?
	## regAのMSBが0か?
	lr35902_test_bitN_of_reg 7 regA
	(
		# 誤差 >= 0(regAのMSBが0)の場合

		# ⽣育適温より⾼いため、⽩デイジーへ⾼い適応度を設定

		# regAはsrc/expset_daisyworld.is_daisy_white.oで上書きされるので
		# regBへコピー
		lr35902_copy_to_from regB regA

		# 現在の細胞 == 白デイジー?
		cat src/expset_daisyworld.is_daisy_white.o
		lr35902_compare_regA_and 01
		(
			# 現在の細胞 == 白デイジーの場合

			# 適応度(regA) = 128(0x80) + 誤差(regB)
			## regA = 0x80
			lr35902_set_reg regA 80
			## regA += regB
			lr35902_add_to_regA regB
		) >src/expset_daisyworld.f_binbio_cell_eval.st_ge_gt.w.o
		(
			# 現在の細胞 == 黒デイジーの場合

			# 適応度(regA) = 128(0x80) - 誤差(regB)
			## regA = 0x80
			lr35902_set_reg regA 80
			## regA -= regB
			lr35902_sub_to_regA regB

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

		# regAへ誤差(regA)の絶対値を設定
		# この時点でregAは2の補数表現の負の値が設定されている。
		# そのため、ビット反転と1の加算で絶対値を取得する。
		## regAの各ビットを反転
		lr35902_complement_regA
		## regAへ1を加算
		lr35902_inc regA

		# regAはsrc/expset_daisyworld.is_daisy_white.oで上書きされるので
		# regBへコピー
		lr35902_copy_to_from regB regA

		# 現在の細胞 == 白デイジー?
		cat src/expset_daisyworld.is_daisy_white.o
		lr35902_compare_regA_and 01
		(
			# 現在の細胞 == 白デイジーの場合

			# 適応度(regA) = 128(0x80) - 誤差の絶対値(regB)
			## regA = 0x80
			lr35902_set_reg regA 80
			## regA -= regB
			lr35902_sub_to_regA regB
		) >src/expset_daisyworld.f_binbio_cell_eval.st_lt_gt.w.o
		(
			# 現在の細胞 == 黒デイジーの場合

			# 適応度(regA) = 127(0x80) + 誤差の絶対値(regB)
			# ※ 誤差の絶対値は最大128なので、加算結果が256以上にならないように127へ足す
			## regA = 0x7f
			lr35902_set_reg regA 7f
			## regA += regB
			lr35902_add_to_regA regB

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
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_return
}

# コード化合物取得
# out: regA - 取得したコード化合物
# ※ フラグレジスタは破壊される
# ※ 実装にバリエーションを持たせられるように関数に分けている
## 現在の細胞に不足しているコード化合物を取得する
## ※ 不足しているコード化合物が無かった場合、
## 　 自身のbin_dataの最後のコード化合物を取得する
_f_binbio_get_missing_code_comp() {
	# push
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 現在の細胞のアドレスをregHLへ取得
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# regBへ現在の細胞のbin_sizeを取得
	## regHLをbin_sizeまで進める
	lr35902_set_reg regDE 0007
	lr35902_add_to_regHL regDE
	## regBへbin_sizeを取得
	lr35902_copy_to_from regB ptrHL

	# regCへ現在の細胞のcollected_flagsを取得
	## regHLをcollected_flagsまで進める
	lr35902_set_reg regDE 0006
	lr35902_add_to_regHL regDE
	## regCへcollected_flagsを取得
	lr35902_copy_to_from regC ptrHL

	# 以降のループで使用するレジスタを初期化
	## regD: bin_dataの何バイト目か → 0で初期化
	lr35902_set_reg regD 00
	## regE: 不足しているコード化合物があったか? → 0で初期化
	lr35902_set_reg regE 00

	# regBをデクリメントしながら0になるまで繰り返す
	(
		# サイズ計算のためループの後半処理を予めファイルへ出力
		(
			# regC(collected_flags)を1ビット右ローテート
			lr35902_copy_to_from regA regC
			lr35902_rot_regA_right
			lr35902_copy_to_from regC regA

			# regD(bin_dataの何バイト目か)をインクリメント
			lr35902_inc regD

			# regB(bin_dataの未チェックバイト数)をデクリメント
			lr35902_dec regB

			# regB == 0?
			lr35902_copy_to_from regA regB
			lr35902_compare_regA_and 00
		) >src/expset_daisyworld.binbio_get_missing_code_comp.loop_bh.o
		local sz_loop_bh=$(stat -c '%s' src/expset_daisyworld.binbio_get_missing_code_comp.loop_bh.o)

		# regCのLSB == 0?
		lr35902_test_bitN_of_reg 0 regC
		(
			# regCのLSB == 0の場合

			# regE(不足しているコード化合物があったか?)へ1を設定
			lr35902_set_reg regE 01

			# ループを抜ける
			lr35902_rel_jump $(two_digits_d $((sz_loop_bh + 2)))
		) >src/expset_daisyworld.binbio_get_missing_code_comp.exit_loop.o
		local sz_exit_loop=$(stat -c '%s' src/expset_daisyworld.binbio_get_missing_code_comp.exit_loop.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_exit_loop)
		cat src/expset_daisyworld.binbio_get_missing_code_comp.exit_loop.o

		# ループ後半処理を出力
		cat src/expset_daisyworld.binbio_get_missing_code_comp.loop_bh.o
	) >src/expset_daisyworld.binbio_get_missing_code_comp.loop.o
	cat src/expset_daisyworld.binbio_get_missing_code_comp.loop.o
	local sz_loop=$(stat -c '%s' src/expset_daisyworld.binbio_get_missing_code_comp.loop.o)
	## regB != 0なら繰り返す
	lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_loop + 2)))	# 2

	# regE == 0?
	lr35902_copy_to_from regA regE
	lr35902_compare_regA_and 00
	(
		# regE == 0(不足しているコード化合物が無かった)の場合

		# regDをデクリメント
		# (bin_dataの最後のバイトを指すようにする)
		lr35902_dec regD
	) >src/expset_daisyworld.binbio_get_missing_code_comp.no_missing_code_comp.o
	local sz_no_missing_code_comp=$(stat -c '%s' src/expset_daisyworld.binbio_get_missing_code_comp.no_missing_code_comp.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_no_missing_code_comp)
	cat src/expset_daisyworld.binbio_get_missing_code_comp.no_missing_code_comp.o

	# この時点で、bin_dataの何バイト目を取得するかがregDに設定されている

	# regAへbin_dataのregDバイト目を取得
	## regHLをbin_dataまで戻す
	### regBCへ-5(2の補数で0xfffb)を設定
	lr35902_set_reg regBC fffb
	### regHL += regBC
	lr35902_add_to_regHL regBC
	## regHL += regD
	lr35902_set_reg regB 00
	lr35902_copy_to_from regC regD
	lr35902_add_to_regHL regBC
	## regAへregHLが指す先のバイトを取得
	lr35902_copy_to_from regA ptrHL

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_return
}
## 本体
f_binbio_get_code_comp() {
	_f_binbio_get_missing_code_comp
}

# 突然変異
# in : regHL - 対象の細胞のアドレス
## 白デイジーは黒デイジーへ、黒デイジーは白デイジーへ変異させる
f_binbio_cell_mutation() {
	# push
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# regHLをtile_numまで進める
	lr35902_set_reg regBC 0006
	lr35902_add_to_regHL regBC

	# regAへ対象の細胞のtile_numを取得
	lr35902_copy_to_from regA ptrHL

	# regA == 白デイジーのタイル?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_WHITE
	(
		# regA == 白デイジーのタイルの場合

		# 対象の細胞のtile_numを黒デイジーのタイルへ変更
		lr35902_set_reg regA $GBOS_TILE_NUM_DAISY_BLACK
		lr35902_copy_to_from ptrHL regA

		# regHLをbin_dataの4バイト目(bin_data + 3)まで進める
		lr35902_set_reg regBC 0005
		lr35902_add_to_regHL regBC

		# bin_dataの4バイト目をinc命令(0x34)へ変更
		lr35902_set_reg regA 34
		lr35902_copy_to_from ptrHL regA
	) >src/expset_daisyworld.binbio_cell_mutation.is_white.o
	(
		# regA != 白デイジーのタイルの場合

		# 対象の細胞のtile_numを白デイジーのタイルへ変更
		lr35902_set_reg regA $GBOS_TILE_NUM_DAISY_WHITE
		lr35902_copy_to_from ptrHL regA

		# regHLをbin_dataの4バイト目(bin_data + 3)まで進める
		lr35902_set_reg regBC 0005
		lr35902_add_to_regHL regBC

		# bin_dataの4バイト目をdec命令(0x35)へ変更
		lr35902_set_reg regA 35
		lr35902_copy_to_from ptrHL regA

		# regA == 白デイジーのタイルの場合の処理を飛ばす
		local sz_is_white=$(stat -c '%s' src/expset_daisyworld.binbio_cell_mutation.is_white.o)
		lr35902_rel_jump $(two_digits_d $sz_is_white)
	) >src/expset_daisyworld.binbio_cell_mutation.is_not_white.o
	local sz_is_not_white=$(stat -c '%s' src/expset_daisyworld.binbio_cell_mutation.is_not_white.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_is_not_white)
	cat src/expset_daisyworld.binbio_cell_mutation.is_not_white.o	# regA != 白デイジーのタイルの場合
	cat src/expset_daisyworld.binbio_cell_mutation.is_white.o	# regA == 白デイジーのタイルの場合

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_return
}

# ステータス表示領域の更新
f_binbio_update_status_disp() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# カーソル位置を温度情報の値の位置へ設定
	lr35902_set_reg regA $(echo $STATUS_DISP_TADR_SURFACE_TEMP_VAL | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_con_tadr_bh
	lr35902_set_reg regA $(echo $STATUS_DISP_TADR_SURFACE_TEMP_VAL | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_con_tadr_th

	# 現在の地表温度をregAへ設定
	lr35902_set_reg regHL $var_binbio_surface_temp
	lr35902_copy_to_from regA ptrHL

	# f_print_regA_signed_dec()を呼び出す
	lr35902_call $a_print_regA_signed_dec

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
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
	for byte_in_inst in 21 $(echo $var_binbio_surface_temp_prev_counter | cut -c3-4) $(echo $var_binbio_surface_temp_prev_counter | cut -c1-2) 34 00; do
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
	## binbio_surface_temp_prev_counter = 0
	lr35902_copy_to_addr_from_regA $var_binbio_surface_temp_prev_counter
	## binbio_status_disp_counter = 0
	lr35902_copy_to_addr_from_regA $var_binbio_status_disp_counter
	## binbio_surface_temp = $DAISY_GROWING_TEMP
	lr35902_set_reg regA $DAISY_GROWING_TEMP
	lr35902_copy_to_addr_from_regA $var_binbio_surface_temp

	# 初期細胞をマップへ配置
	## タイル座標をVRAMアドレスへ変換
	lr35902_call $a_tcoord_to_addr
	## VRAMアドレスと細胞のタイル番号をtdqへエンキュー
	### VRAMアドレスをregDEへ設定
	lr35902_copy_to_from regD regH
	lr35902_copy_to_from regE regL
	### tdqへエンキューする
	lr35902_call $a_enq_tdq

	# ステータス表示領域を初期化
	## カーソル位置を設定
	lr35902_set_reg regA $(echo $STATUS_DISP_TADR_SURFACE_TEMP_TITLE | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_con_tadr_bh
	lr35902_set_reg regA $(echo $STATUS_DISP_TADR_SURFACE_TEMP_TITLE | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_con_tadr_th
	## "ちひようおんと゛："を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_HIRA_CHI
	lr35902_call $a_putch
	lr35902_set_reg regB $GBOS_TILE_NUM_HIRA_HI
	lr35902_call $a_putch
	lr35902_set_reg regB $GBOS_TILE_NUM_HIRA_YO
	lr35902_call $a_putch
	lr35902_set_reg regB $GBOS_TILE_NUM_HIRA_U
	lr35902_call $a_putch
	lr35902_set_reg regB $GBOS_TILE_NUM_HIRA_O
	lr35902_call $a_putch
	lr35902_set_reg regB $GBOS_TILE_NUM_HIRA_N
	lr35902_call $a_putch
	lr35902_set_reg regB $GBOS_TILE_NUM_HIRA_TO
	lr35902_call $a_putch
	lr35902_set_reg regB $GBOS_TILE_NUM_DAKUTEN
	lr35902_call $a_putch
	lr35902_set_reg regB $GBOS_TILE_NUM_COLON
	lr35902_call $a_putch
	## 現在の地表温度の値を配置
	lr35902_call $a_binbio_update_status_disp
	## "゜Ｃ"を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_HANDAKUTEN
	lr35902_call $a_putch
	lr35902_set_reg regB $(get_alpha_tile_num 'C')
	lr35902_call $a_putch

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}
