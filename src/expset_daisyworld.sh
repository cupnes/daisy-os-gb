if [ "${SRC_EXPSET_DAISYWORLD_SH+is_defined}" ]; then
	return
fi
SRC_EXPSET_DAISYWORLD_SH=true

# main.shの中で一通りのシェルスクリプトの読み込みが終わった後でこのファイルが読み込まれる想定
# なので、main.shで既に読み込んでいるスクリプトは読み込む処理を書いていない

# 変数
## 固定値を返す評価関数が返す固定値
var_binbio_cell_eval_fixedval_val=c032
## 現在のステータス表示領域の状態
var_binbio_status_disp_status=c033
## 地表温度をインクリメント/デクリメントする前段のカウンタのアドレス
## 黒/白デイジーはこの変数をインクリメント/デクリメントする
var_binbio_surface_temp_prev_counter=c034
## 地表温度(-128〜127)のアドレス
var_binbio_surface_temp=c035

# 定数
## 白/黒デイジーの細胞データのデフォルト値
CELL_DEFAULT_FLAGS_DAISY=01
CELL_DEFAULT_LIFE_DURATION_DAISY=$BINBIO_CELL_LIFE_DURATION_INIT
CELL_DEFAULT_LIFE_LEFT_DAISY=$BINBIO_CELL_LIFE_DURATION_INIT
CELL_DEFAULT_FITNESS_DAISY=$BINBIO_CELL_FITNESS_INIT
CELL_DEFAULT_BIN_SIZE_DAISY=05
CELL_DEFAULT_BIN_DATA_0_DAISY=21
CELL_DEFAULT_BIN_DATA_1_DAISY=$(echo $var_binbio_surface_temp_prev_counter | cut -c3-4)
CELL_DEFAULT_BIN_DATA_2_DAISY=$(echo $var_binbio_surface_temp_prev_counter | cut -c1-2)
CELL_DEFAULT_BIN_DATA_3_DAISY_WHITE=35
CELL_DEFAULT_BIN_DATA_3_DAISY_BLACK=34
CELL_DEFAULT_BIN_DATA_4_DAISY=00
CELL_DEFAULT_COLLECTED_FLAGS_DAISY=00
## デイジーの生育適温(20℃)
DAISY_GROWING_TEMP=14
## 地表温度をインクリメント/デクリメントする前段カウンタのしきい値
## 前段カウンタの絶対値がこの値に達したら地表温度をインクリメント/デクリメントする
SURFACE_TEMP_INCDEC_PREV_COUNTER_TH=0a
## 評価関数番号
CELL_EVAL_NUM_FIXEDVAL=00	# 固定値を返す
CELL_EVAL_NUM_DAISYWORLD=$BINBIO_EXPSET_DAISYWORLD	# デイジーワールド実験用(実験セット番号と同じにする)
## 固定値を返す評価関数が返す固定値の初期値
CELL_EVAL_FIXEDVAL_VAL_INIT=ff
## ステータス表示領域の状態
STATUS_DISP_SHOW_SOFT_DESC=00	# ソフト説明表示状態
STATUS_DISP_SHOW_CELL_INFO=01	# 細胞ステータス情報表示状態
STATUS_DISP_SHOW_CELL_EVAL_SEL=02	# 評価関数選択表示状態
STATUS_DISP_SHOW_CELL_EVAL_CONF=03	# 評価関数設定表示状態
## 画面上のタイル座標/アドレス
### 地表温度
### TODO 「タイトル(TITLE)」というより「ラベル(LABEL)」
SURFACE_TEMP_TITLE_TCOORD_Y=00	# タイトルのタイル座標Y
SURFACE_TEMP_TITLE_TCOORD_X=03	# タイトルのタイル座標X
SURFACE_TEMP_VAL_TADR=980c	# 値のタイルアドレス
### 細胞表示
CELL_DISP_AREA_FRAME_UPPER_LEFT_TCOORD_Y=01
CELL_DISP_AREA_FRAME_UPPER_LEFT_TCOORD_X=00
CELL_DISP_AREA_FRAME_UPPER_LEFT_TADR=$(con_tcoord_to_tadr $CELL_DISP_AREA_FRAME_UPPER_LEFT_TCOORD_X $CELL_DISP_AREA_FRAME_UPPER_LEFT_TCOORD_Y)	# 細胞表示領域の枠線の左上
CELL_DISP_AREA_FRAME_LOWER_RIGHT_TCOORD_Y=09
CELL_DISP_AREA_FRAME_LOWER_RIGHT_TCOORD_X=0D
### 説明表示
#### 本作のタイトル
TITLE_DAISY_TCOORD_Y=02
TITLE_DAISY_TCOORD_X=0E
TITLE_WORLD_TCOORD_Y=03
TITLE_WORLD_TCOORD_X=0E
TITLE_DEMO_TCOORD_Y=04
TITLE_DEMO_TCOORD_X=0E
#### バージョン情報
VER_UPPER_DIVIDER_TCOORD_Y=05
VER_UPPER_DIVIDER_TCOORD_X=0E
VER_DAISY_TCOORD_Y=06
VER_DAISY_TCOORD_X=0E
VER_OS_TCOORD_Y=07
VER_OS_TCOORD_X=0E
VER_VER_TCOORD_Y=08
VER_VER_TCOORD_X=0E
VER_LOWER_DIVIDER_TCOORD_Y=09
VER_LOWER_DIVIDER_TCOORD_X=0E
#### デイジー説明
DAISY_DESC_WHITE_TCOORD_Y=0A
DAISY_DESC_WHITE_TCOORD_X=00
DAISY_DESC_BLACK_TCOORD_Y=0B
DAISY_DESC_BLACK_TCOORD_X=00
#### 捕食者説明
PREDATOR_DESC_TCOORD_Y=0C
PREDATOR_DESC_TCOORD_X=00
#### 操作説明
OPERATION_TITLE_TCOORD_Y=0D
OPERATION_TITLE_TCOORD_X=00
OPERATION_DIR_TCOORD_Y=0E
OPERATION_DIR_TCOORD_X=01
OPERATION_A_TCOORD_Y=0F
OPERATION_A_TCOORD_X=01
OPERATION_B_1_TCOORD_Y=10
OPERATION_B_1_TCOORD_X=01
OPERATION_B_2_TCOORD_Y=11
OPERATION_B_2_TCOORD_X=07
### 細胞情報表示
#### フラグ
FLAGS_LABEL_TCOORD_Y=02
FLAGS_LABEL_TCOORD_X=0E
FLAGS_PREF_VAL_TCOORD_Y=03
FLAGS_PREF_VAL_TCOORD_X=10
#### タイル座標
TCOORD_LABEL_TCOORD_Y=05
TCOORD_LABEL_TCOORD_X=0E
TCOORD_OPEN_BRACKET_TCOORD_Y=06
TCOORD_OPEN_BRACKET_TCOORD_X=0E
TCOORD_X_VAL_TADR=98CF
TCOORD_Y_VAL_TCOORD_Y=07
TCOORD_Y_VAL_TCOORD_X=0F
TCOORD_Y_VAL_TADR=$(con_tcoord_to_tadr $TCOORD_Y_VAL_TCOORD_X $TCOORD_Y_VAL_TCOORD_Y)
#### 余命/寿命
LIFE_LEFT_DURATION_TCOORD_Y=0A
LIFE_LEFT_DURATION_LABEL_TCOORD_X=00
LIFE_LEFT_VAL_TCOORD_X=0B
#### 適応度
FITNESS_TCOORD_Y=0C
FITNESS_LABEL_TCOORD_X=00
FITNESS_VAL_TCOORD_X=07
#### バイナリデータ・サイズ
BIN_DATA_SIZE_LABEL_SIZE_VAL_TCOORD_Y=0E
BIN_DATA_SIZE_LABEL_TCOORD_X=00
BIN_SIZE_VAL_TCOORD_X=0C
BIN_DATA_PREF_VAL_TCOORD_Y=0F
BIN_DATA_PREF_VAL_TCOORD_X=04
#### 取得フラグ
COLLECTED_FLAGS_LABEL_VAL_TCOORD_Y=11
COLLECTED_FLAGS_LABEL_TCOORD_X=00
COLLECTED_FLAGS_UNIT_VAL_TCOORD_X=09
### 評価関数選択
#### 評価関数選択ラベル
CELL_EVAL_SEL_LABEL_TCOORD_X=00
CELL_EVAL_SEL_LABEL_TCOORD_Y=0A
#### 評価関数選択外枠
CELL_EVAL_SEL_FRAME_TCOORD_X=00
CELL_EVAL_SEL_FRAME_TCOORD_Y=0B
CELL_EVAL_SEL_FRAME_WIDTH=0E
CELL_EVAL_SEL_FRAME_HEIGHT=07
#### 関数名
CELL_EVAL_SEL_DAISYWORLD_TCOORD_X=02
CELL_EVAL_SEL_DAISYWORLD_TCOORD_Y=0C
CELL_EVAL_SEL_FIXEDVAL_TCOORD_X=02
CELL_EVAL_SEL_FIXEDVAL_TCOORD_Y=0D
#### 関数設定別
## 画面上のマウスカーソル座標
### 地表温度の▲▼ボタンの範囲を示す
SURFACE_TEMP_UP_DOWN_BEGIN_Y=10	# ▲▼のY座標始端
SURFACE_TEMP_UP_DOWN_END_Y=17	# ▲▼のY座標終端
SURFACE_TEMP_UP_BEGIN_X=98	# ▲のX座標始端
SURFACE_TEMP_UP_END_X=9F	# ▲のX座標終端
SURFACE_TEMP_DOWN_BEGIN_X=A0	# ▼のX座標始端
SURFACE_TEMP_DOWN_END_X=A7	# ▼のX座標終端
### 評価関数選択
CELL_EVAL_SEL_BEGIN_MOUSE_Y=70	# 関数名領域のY座標始端
CELL_EVAL_SEL_DAISYWORLD_END_MOUSE_Y=77	# 関数名「でいじーわーるど」のY座標終端
CELL_EVAL_SEL_FIXEDVAL_END_MOUSE_Y=7F	# 関数名「こていち」のY座標終端
CELL_EVAL_SEL_BEGIN_MOUSE_X=10	# 関数名領域のX座標始端
CELL_EVAL_SEL_END_MOUSE_X=6F	# 関数名領域のX座標終端

# この実験セットで使用するスクリプトを読み込む
. src/status_disp_cell_eval_conf.sh
. src/species_predator.sh
# INSERT_source_scripts

# 繰り返し使用する処理をファイル書き出し
## regAへ現在の細胞のtile_numを取得
## out : regA - 現在の細胞のtile_num
## work: regBC, regHL
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

	# regAへ自身のtile_numを取得
	lr35902_copy_to_from regA ptrHL

	# pop
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
} >src/expset_daisyworld.get_current_cell_tile_num.o
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
## 前段のカウンタの絶対値がしきい値以上であれば地表温度をインクリメント/デクリメントする
## work: regAF
{
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
			) >src/expset_daisyworld.apply_prev_counter.prev_counter_positive.ge_th.inc_st.o
			sz_apply_prev_counter_prev_counter_positive_ge_th_inc_st=$(stat -c '%s' src/expset_daisyworld.apply_prev_counter.prev_counter_positive.ge_th.inc_st.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_apply_prev_counter_prev_counter_positive_ge_th_inc_st)
			cat src/expset_daisyworld.apply_prev_counter.prev_counter_positive.ge_th.inc_st.o

			# 前段のカウンタをゼロクリア
			lr35902_xor_to_regA regA
			lr35902_copy_to_addr_from_regA $var_binbio_surface_temp_prev_counter
		) >src/expset_daisyworld.apply_prev_counter.prev_counter_positive.ge_th.o
		sz_apply_prev_counter_prev_counter_positive_ge_th=$(stat -c '%s' src/expset_daisyworld.apply_prev_counter.prev_counter_positive.ge_th.o)
		lr35902_rel_jump_with_cond C $(two_digits_d $sz_apply_prev_counter_prev_counter_positive_ge_th)
		cat src/expset_daisyworld.apply_prev_counter.prev_counter_positive.ge_th.o
	) >src/expset_daisyworld.apply_prev_counter.prev_counter_positive.o
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
			) >src/expset_daisyworld.apply_prev_counter.prev_counter_negative.ge_th.dec_st.o
			sz_apply_prev_counter_prev_counter_negative_ge_th_dec_st=$(stat -c '%s' src/expset_daisyworld.apply_prev_counter.prev_counter_negative.ge_th.dec_st.o)
			lr35902_rel_jump_with_cond Z $(two_digits_d $sz_apply_prev_counter_prev_counter_negative_ge_th_dec_st)
			cat src/expset_daisyworld.apply_prev_counter.prev_counter_negative.ge_th.dec_st.o

			# 前段のカウンタをゼロクリア
			lr35902_xor_to_regA regA
			lr35902_copy_to_addr_from_regA $var_binbio_surface_temp_prev_counter
		) >src/expset_daisyworld.apply_prev_counter.prev_counter_negative.ge_th.o
		sz_apply_prev_counter_prev_counter_negative_ge_th=$(stat -c '%s' src/expset_daisyworld.apply_prev_counter.prev_counter_negative.ge_th.o)
		lr35902_rel_jump_with_cond C $(two_digits_d $sz_apply_prev_counter_prev_counter_negative_ge_th)
		cat src/expset_daisyworld.apply_prev_counter.prev_counter_negative.ge_th.o

		# 前段のカウンタ >= 0の場合の処理を飛ばす
		sz_apply_prev_counter_prev_counter_positive=$(stat -c '%s' src/expset_daisyworld.apply_prev_counter.prev_counter_positive.o)
		lr35902_rel_jump $(two_digits_d $sz_apply_prev_counter_prev_counter_positive)
	) >src/expset_daisyworld.apply_prev_counter.prev_counter_negative.o
	sz_apply_prev_counter_prev_counter_negative=$(stat -c '%s' src/expset_daisyworld.apply_prev_counter.prev_counter_negative.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_apply_prev_counter_prev_counter_negative)
	cat src/expset_daisyworld.apply_prev_counter.prev_counter_negative.o
	cat src/expset_daisyworld.apply_prev_counter.prev_counter_positive.o
} >src/expset_daisyworld.apply_prev_counter.o

# 評価の実装 - デイジーワールド実験用
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval_daisyworld() {
	# push
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	# 前段のカウンタの絶対値がしきい値以上であれば地表温度をインクリメント/デクリメントする
	cat src/expset_daisyworld.apply_prev_counter.o

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
		) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.e_is_m128.o
		(
			# 0x7f >= regA の場合

			# regAへ誤差(regB - $DAISY_GROWING_TEMP)を設定
			lr35902_copy_to_from regA regB
			lr35902_sub_to_regA $DAISY_GROWING_TEMP

			# 0x7f < regA の場合の処理を飛ばす
			local sz_e_is_m128=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.e_is_m128.o)
			lr35902_rel_jump $(two_digits_d $sz_e_is_m128)
		) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.calc_e_2.o
		### regA < regB?
		local sz_calc_e_2=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.calc_e_2.o)
		lr35902_rel_jump_with_cond C $(two_digits_d $sz_calc_e_2)
		cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.calc_e_2.o
		cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.e_is_m128.o
	) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt.o
	(
		# regA >= $DAISY_GROWING_TEMP - 128 の場合

		# regAへ誤差(regA - $DAISY_GROWING_TEMP)を設定
		lr35902_sub_to_regA $DAISY_GROWING_TEMP

		# regA < $DAISY_GROWING_TEMP - 128 の場合の処理を飛ばす
		local sz_st_lt=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt.o)
		lr35902_rel_jump $(two_digits_d $sz_st_lt)
	) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.calc_e.o
	## regA < $DAISY_GROWING_TEMP - 128?
	local sz_calc_e=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.calc_e.o)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_calc_e)
	cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.calc_e.o
	cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt.o

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
		) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_ge_gt.w.o
		(
			# 現在の細胞 == 黒デイジーの場合

			# 適応度(regA) = 128(0x80) - 誤差(regB)
			## regA = 0x80
			lr35902_set_reg regA 80
			## regA -= regB
			lr35902_sub_to_regA regB

			# 現在の細胞 == 白デイジーの場合の処理を飛ばす
			local sz_st_ge_gt_w=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_ge_gt.w.o)
			lr35902_rel_jump $(two_digits_d $sz_st_ge_gt_w)
		) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_ge_gt.b.o
		local sz_st_ge_gt_b=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_ge_gt.b.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_st_ge_gt_b)
		cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_ge_gt.b.o	# 現在の細胞 == 黒デイジーの場合
		cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_ge_gt.w.o	# 現在の細胞 == 白デイジーの場合
	) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_ge_gt.o
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
		) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt_gt.w.o
		(
			# 現在の細胞 == 黒デイジーの場合

			# 適応度(regA) = 127(0x80) + 誤差の絶対値(regB)
			# ※ 誤差の絶対値は最大128なので、加算結果が256以上にならないように127へ足す
			## regA = 0x7f
			lr35902_set_reg regA 7f
			## regA += regB
			lr35902_add_to_regA regB

			# 現在の細胞 == 白デイジーの場合の処理を飛ばす
			local sz_st_lt_gt_w=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt_gt.w.o)
			lr35902_rel_jump $(two_digits_d $sz_st_lt_gt_w)
		) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt_gt.b.o
		local sz_st_lt_gt_b=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt_gt.b.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_st_lt_gt_b)
		cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt_gt.b.o	# 現在の細胞 == 黒デイジーの場合
		cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt_gt.w.o	# 現在の細胞 == 白デイジーの場合

		# 誤差 >= 0の場合の処理を飛ばす
		local sz_st_ge_gt=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_ge_gt.o)
		lr35902_rel_jump $(two_digits_d $sz_st_ge_gt)
	) >src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt_gt.o
	local sz_st_lt_gt=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt_gt.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_st_lt_gt)
	cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_lt_gt.o	# 誤差 < 0の場合
	cat src/expset_daisyworld.f_binbio_cell_eval_daisyworld.st_ge_gt.o	# 誤差 >= 0の場合

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_return
}

# 評価の実装 - 固定値を返す
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval_fixedval() {
	# 前段のカウンタの絶対値がしきい値以上であれば地表温度をインクリメント/デクリメントする
	cat src/expset_daisyworld.apply_prev_counter.o

	# regAへ$var_binbio_cell_eval_fixedval_valの値を設定
	lr35902_copy_to_regA_from_addr $var_binbio_cell_eval_fixedval_val

	# return
	lr35902_return
}

# 現在の細胞を評価する
# out: regA - 評価結果の適応度(0x00〜0xff)
# ※ フラグレジスタは破壊される
f_binbio_cell_eval() {
	# regAへ現在の細胞のtile_numを取得
	cat src/expset_daisyworld.get_current_cell_tile_num.o

	# 繰り返し使用する処理をファイル書き出し
	## デイジーワールドの評価関数を呼び出してreturn
	(
		# 評価関数呼び出し
		lr35902_call $a_binbio_cell_eval_daisyworld

		# return
		lr35902_return
	) >src/expset_daisyworld.f_binbio_cell_eval.daisyworld.o
	local sz_daisyworld=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_eval.daisyworld.o)

	# regA == 白デイジー ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_WHITE
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisyworld)
	cat src/expset_daisyworld.f_binbio_cell_eval.daisyworld.o

	# regA == 黒デイジー ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_BLACK
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisyworld)
	cat src/expset_daisyworld.f_binbio_cell_eval.daisyworld.o

	# regA == 捕食者 ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_PREDATOR
	(
		# 評価関数呼び出し
		lr35902_call $a_binbio_cell_eval_predator

		# return
		lr35902_return
	) >src/f_binbio_cell_eval.predator.o
	local sz_predator=$(stat -c '%s' src/f_binbio_cell_eval.predator.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_predator)
	cat src/f_binbio_cell_eval.predator.o

	# INSERT_f_binbio_cell_eval

	# regAがその他の値の場合(現状、このパスには来ないはず)
	# もしこのパスに来るようであれば無限ループで止める
	infinite_halt

	# return
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
f_binbio_cell_mutation() {
	# push
	lr35902_push_reg regAF

	# regAへ現在の細胞のtile_numを取得
	cat src/expset_daisyworld.get_current_cell_tile_num.o

	# 繰り返し使用する処理をファイル書き出し
	## pop & return
	(
		lr35902_pop_reg regAF
		lr35902_return
	) >src/f_binbio_cell_mutation.pop_and_return.o
	## デイジーワールドの突然変異関数を呼び出してreturn
	(
		# 突然変異関数呼び出し
		lr35902_call $a_binbio_cell_mutation_daisy

		# pop & return
		cat src/f_binbio_cell_mutation.pop_and_return.o
	) >src/expset_daisyworld.f_binbio_cell_mutation.daisy.o
	local sz_daisy=$(stat -c '%s' src/expset_daisyworld.f_binbio_cell_mutation.daisy.o)

	# regA == 白デイジー ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_WHITE
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisy)
	cat src/expset_daisyworld.f_binbio_cell_mutation.daisy.o

	# regA == 黒デイジー ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_BLACK
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisy)
	cat src/expset_daisyworld.f_binbio_cell_mutation.daisy.o

	# regA == 捕食者 ?
	lr35902_compare_regA_and $GBOS_TILE_NUM_PREDATOR
	(
		# 突然変異関数呼び出し
		lr35902_call $a_binbio_cell_mutation_predator

		# pop & return
		cat src/f_binbio_cell_mutation.pop_and_return.o
	) >src/f_binbio_cell_mutation.predator.o
	local sz_predator=$(stat -c '%s' src/f_binbio_cell_mutation.predator.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_predator)
	cat src/f_binbio_cell_mutation.predator.o

	# INSERT_f_binbio_cell_mutation

	# regAがその他の値の場合(現状、このパスには来ないはず)
	# もしこのパスに来るようであれば無限ループで止める
	infinite_halt

	# pop & return
	cat src/f_binbio_cell_mutation.pop_and_return.o
}

# ソフト説明を画面へ配置
f_binbio_place_soft_desc() {
	# push
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# タイトルを配置
	con_print_xy_macro $TITLE_DAISY_TCOORD_X $TITLE_DAISY_TCOORD_Y $a_const_title_str_daisy
	con_print_xy_macro $TITLE_WORLD_TCOORD_X $TITLE_WORLD_TCOORD_Y $a_const_title_str_world
	con_print_xy_macro $TITLE_DEMO_TCOORD_X $TITLE_DEMO_TCOORD_Y $a_const_title_str_demo

	# バージョン情報を配置
	con_putxy_macro $VER_UPPER_DIVIDER_TCOORD_X $VER_UPPER_DIVIDER_TCOORD_Y '-'
	con_print_xy_macro $VER_DAISY_TCOORD_X $VER_DAISY_TCOORD_Y $a_const_ver_str_daisy
	con_print_xy_macro $VER_OS_TCOORD_X $VER_OS_TCOORD_Y $a_const_ver_str_os
	con_print_xy_macro $VER_VER_TCOORD_X $VER_VER_TCOORD_Y $a_const_ver_str_ver
	con_putxy_macro $VER_LOWER_DIVIDER_TCOORD_X $VER_LOWER_DIVIDER_TCOORD_Y '-'

	# デイジー説明を配置
	con_print_xy_macro $DAISY_DESC_WHITE_TCOORD_X $DAISY_DESC_WHITE_TCOORD_Y $a_const_daisy_desc_str_white
	con_print_xy_macro $DAISY_DESC_BLACK_TCOORD_X $DAISY_DESC_BLACK_TCOORD_Y $a_const_daisy_desc_str_black

	# 捕食者説明を配置
	con_print_xy_macro $PREDATOR_DESC_TCOORD_X $PREDATOR_DESC_TCOORD_Y $a_const_predator_desc_str

	# 操作説明を配置
	con_print_xy_macro $OPERATION_TITLE_TCOORD_X $OPERATION_TITLE_TCOORD_Y $a_const_operation_str_title
	con_print_xy_macro $OPERATION_DIR_TCOORD_X $OPERATION_DIR_TCOORD_Y $a_const_operation_str_dir
	con_print_xy_macro $OPERATION_A_TCOORD_X $OPERATION_A_TCOORD_Y $a_const_operation_str_a
	con_print_xy_macro $OPERATION_B_1_TCOORD_X $OPERATION_B_1_TCOORD_Y $a_const_operation_str_b_1
	con_print_xy_macro $OPERATION_B_2_TCOORD_X $OPERATION_B_2_TCOORD_Y $a_const_operation_str_b_2

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_return
}

# ソフト説明をクリア
f_binbio_clear_soft_desc() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regDE

	# タイトルをクリア
	con_delch_tadr_num_macro $TITLE_DAISY_TCOORD_X $TITLE_DAISY_TCOORD_Y $((sz_const_title_str_daisy - 1))
	con_delch_tadr_num_macro $TITLE_WORLD_TCOORD_X $TITLE_WORLD_TCOORD_Y $((sz_const_title_str_world - 1))
	con_delch_tadr_num_macro $TITLE_DEMO_TCOORD_X $TITLE_DEMO_TCOORD_Y $((sz_const_title_str_demo - 1))

	# バージョン情報をクリア
	con_delch_tadr_num_macro $VER_UPPER_DIVIDER_TCOORD_X $VER_UPPER_DIVIDER_TCOORD_Y 1
	con_delch_tadr_num_macro $VER_DAISY_TCOORD_X $VER_DAISY_TCOORD_Y $((sz_const_ver_str_daisy - 1))
	con_delch_tadr_num_macro $VER_OS_TCOORD_X $VER_OS_TCOORD_Y $((sz_const_ver_str_os - 1))
	con_delch_tadr_num_macro $VER_VER_TCOORD_X $VER_VER_TCOORD_Y $((sz_const_ver_str_ver - 1))
	con_delch_tadr_num_macro $VER_LOWER_DIVIDER_TCOORD_X $VER_LOWER_DIVIDER_TCOORD_Y 1

	# デイジー説明をクリア
	con_delch_tadr_num_macro $DAISY_DESC_WHITE_TCOORD_X $DAISY_DESC_WHITE_TCOORD_Y $((sz_const_daisy_desc_str_white - 1))
	con_delch_tadr_num_macro $DAISY_DESC_BLACK_TCOORD_X $DAISY_DESC_BLACK_TCOORD_Y $((sz_const_daisy_desc_str_black - 1))

	# 捕食者説明をクリア
	con_delch_tadr_num_macro $PREDATOR_DESC_TCOORD_X $PREDATOR_DESC_TCOORD_Y $((sz_const_predator_desc_str - 1))

	# 操作説明をクリア
	con_delch_tadr_num_macro $OPERATION_TITLE_TCOORD_X $OPERATION_TITLE_TCOORD_Y $((sz_const_operation_str_title - 1))
	con_delch_tadr_num_macro $OPERATION_DIR_TCOORD_X $OPERATION_DIR_TCOORD_Y $((sz_const_operation_str_dir - 1))
	con_delch_tadr_num_macro $OPERATION_A_TCOORD_X $OPERATION_A_TCOORD_Y $((sz_const_operation_str_a - 1))
	con_delch_tadr_num_macro $OPERATION_B_1_TCOORD_X $OPERATION_B_1_TCOORD_Y $((sz_const_operation_str_b_1 - 1))
	con_delch_tadr_num_macro $OPERATION_B_2_TCOORD_X $OPERATION_B_2_TCOORD_Y $((sz_const_operation_str_b_2 - 1))

	# pop & return
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
	lr35902_return
}

# ステータス表示領域の更新
f_binbio_update_status_disp() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# カーソル位置を温度情報の値の位置へ設定
	lr35902_set_reg regA $(echo $SURFACE_TEMP_VAL_TADR | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_con_tadr_bh
	lr35902_set_reg regA $(echo $SURFACE_TEMP_VAL_TADR | cut -c1-2)
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

# 細胞ステータス情報のラベルを画面へ配置
f_binbio_place_cell_info_labels() {
	# push
	lr35902_push_reg regDE	# con_print_xy_macro()で変更する
	lr35902_push_reg regHL	# con_print_xy_macro()で変更する

	# フラグのラベルを配置
	con_print_xy_macro $FLAGS_LABEL_TCOORD_X $FLAGS_LABEL_TCOORD_Y $a_const_cell_status_str_flags

	# タイル座標のラベルを配置
	con_print_xy_macro $TCOORD_LABEL_TCOORD_X $TCOORD_LABEL_TCOORD_Y $a_const_cell_status_str_coord

	# 余命/寿命のラベルを配置
	con_print_xy_macro $LIFE_LEFT_DURATION_LABEL_TCOORD_X $LIFE_LEFT_DURATION_TCOORD_Y $a_const_cell_status_str_life_left_duration

	# 適応度のラベルを配置
	con_print_xy_macro $FITNESS_LABEL_TCOORD_X $FITNESS_TCOORD_Y $a_const_cell_status_str_fitness

	# バイナリとサイズのラベルを配置
	con_print_xy_macro $BIN_DATA_SIZE_LABEL_TCOORD_X $BIN_DATA_SIZE_LABEL_SIZE_VAL_TCOORD_Y $a_const_cell_status_str_bin_data_size

	# 取得フラグのラベルを配置
	con_print_xy_macro $COLLECTED_FLAGS_LABEL_TCOORD_X $COLLECTED_FLAGS_LABEL_VAL_TCOORD_Y $a_const_cell_status_str_collected_flags

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_return
}

# 細胞ステータス情報の値を画面へ配置
# in : regHL - 対象の細胞のアドレス
f_binbio_place_cell_info_val() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE	# con_print_xy_macro()で変更する
	lr35902_push_reg regHL

	# フラグを配置
	## regAへflagsを取得
	lr35902_copy_to_from regA ptrHL
	## aliveフラグ == 0 ?
	lr35902_test_bitN_of_reg 0 regA
	(
		# aliveフラグ == 0 の場合

		# pop & return
		lr35902_pop_reg regAF
		lr35902_return
	) >src/expset_daisyworld.f_binbio_place_cell_info.alive_eq_0.o
	local sz_alive_eq_0=$(stat -c '%s' src/expset_daisyworld.f_binbio_place_cell_info.alive_eq_0.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_alive_eq_0)
	cat src/expset_daisyworld.f_binbio_place_cell_info.alive_eq_0.o
	## regHLをregBCへ退避
	lr35902_copy_to_from regC regL
	lr35902_copy_to_from regB regH
	## 16進数の接頭辞を配置
	con_print_xy_macro $FLAGS_PREF_VAL_TCOORD_X $FLAGS_PREF_VAL_TCOORD_Y $a_const_pref_hex
	## 値を配置
	lr35902_call $a_print_regA

	# タイル座標を配置
	## regBCからregHLを復帰
	lr35902_copy_to_from regL regC
	lr35902_copy_to_from regH regB
	## '('を配置
	con_putxy_macro $TCOORD_OPEN_BRACKET_TCOORD_X $TCOORD_OPEN_BRACKET_TCOORD_Y '('
	## X座標の値を配置
	### カーソル位置を設定
	con_set_cursor $TCOORD_X_VAL_TADR
	### regHLをtile_xまで進める
	lr35902_inc regHL
	### regAへtile_xを取得
	lr35902_copy_to_from regA ptrHL
	### regAの値を10進数で配置
	lr35902_call $a_print_regA_signed_dec
	## '、'を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_TOUTEN
	lr35902_call $a_putch
	## Y座標の値を配置
	### カーソル位置を設定
	con_set_cursor $TCOORD_Y_VAL_TADR
	### regHLをtile_yまで進める
	lr35902_inc regHL
	### regAへtile_yを取得
	lr35902_copy_to_from regA ptrHL
	### regAの値を10進数で配置
	lr35902_call $a_print_regA_signed_dec
	## ')'を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_CLOSE_BRACKET
	lr35902_call $a_putch

	# 余命/寿命を配置
	## 余命の値を配置
	### カーソル位置を設定
	con_set_cursor $(con_tcoord_to_tadr $LIFE_LEFT_VAL_TCOORD_X $LIFE_LEFT_DURATION_TCOORD_Y)
	### life_leftのアドレスをregHLへ設定
	lr35902_set_reg regBC 0002
	lr35902_add_to_regHL regBC
	### regAへlife_leftを取得
	lr35902_copy_to_from regA ptrHL
	### regAの値を10進数で配置
	lr35902_call $a_print_regA_signed_dec
	## '/'を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_SLASH
	lr35902_call $a_putch
	## 寿命の値を配置
	### life_durationのアドレスをregHLへ設定
	lr35902_set_reg regBC $(two_comp_4 1)
	lr35902_add_to_regHL regBC
	### regAへlife_durationを取得
	lr35902_copy_to_from regA ptrHL
	### regAの値を10進数で配置
	lr35902_call $a_print_regA_signed_dec

	# 適応度を配置
	## regHLをregBCへ退避
	lr35902_copy_to_from regC regL
	lr35902_copy_to_from regB regH
	## カーソル位置を設定
	con_set_cursor $(con_tcoord_to_tadr $FITNESS_VAL_TCOORD_X $FITNESS_TCOORD_Y)
	## 16進数の接頭辞を配置
	lr35902_set_reg regHL $a_const_pref_hex
	lr35902_call $a_print
	## 値を配置
	### fitnessのアドレスをregHLへ設定
	lr35902_set_reg regHL 0002
	lr35902_add_to_regHL regBC
	### regAへfitnessを取得
	lr35902_copy_to_from regA ptrHL
	### regAの値を16進数で配置
	lr35902_call $a_print_regA

	# バイナリとサイズを配置
	## サイズの値を配置
	### カーソル位置を設定
	con_set_cursor $(con_tcoord_to_tadr $BIN_SIZE_VAL_TCOORD_X $BIN_DATA_SIZE_LABEL_SIZE_VAL_TCOORD_Y)
	### bin_sizeのアドレスをregHLへ設定
	lr35902_set_reg regBC 0002
	lr35902_add_to_regHL regBC
	### regAへbin_sizeを取得
	lr35902_copy_to_from regA ptrHL
	### regAの値を10進数で配置
	lr35902_call $a_print_regA_signed_dec
	## ')'を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_CLOSE_BRACKET
	lr35902_call $a_putch
	## regHLをregBCへ退避
	lr35902_copy_to_from regC regL
	lr35902_copy_to_from regB regH
	## 16進数の接頭辞を配置
	con_print_xy_macro $BIN_DATA_PREF_VAL_TCOORD_X $BIN_DATA_PREF_VAL_TCOORD_Y $a_const_pref_hex
	## regBCからregHLを復帰
	lr35902_copy_to_from regL regC
	lr35902_copy_to_from regH regB
	## ※ この時点でregAにはサイズが設定されている
	## バイナリを配置
	### regA == 0 ?
	lr35902_compare_regA_and 00
	(
		# regA != 0 の場合

		# regHLをbin_dataのアドレスまで進める
		lr35902_inc regHL

		# regCへregA(サイズ)をコピー
		lr35902_copy_to_from regC regA

		# 1バイトずつ半角スペース区切りで配置
		(
			# アドレスregHLの値をregAへ取得
			lr35902_copy_to_from regA ptrHL

			# regAの値を16進数で配置
			lr35902_call $a_print_regA

			# アドレスregHLを進める
			lr35902_inc regHL

			# ' 'を配置
			lr35902_set_reg regB $GBOS_TILE_NUM_SPC
			lr35902_call $a_putch

			# regCをデクリメント
			lr35902_dec regC

			# regCと0を比較
			lr35902_copy_to_from regA regC
			lr35902_compare_regA_and 00
		) >src/expset_daisyworld.f_binbio_place_cell_info.bin_data_loop.o
		cat src/expset_daisyworld.f_binbio_place_cell_info.bin_data_loop.o
		local sz_bin_data_loop=$(stat -c '%s' src/expset_daisyworld.f_binbio_place_cell_info.bin_data_loop.o)
		## regC != 0なら繰り返す
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_bin_data_loop + 2)))	# 2
	) >src/expset_daisyworld.f_binbio_place_cell_info.bin_size_ne_0.o
	local sz_bin_size_ne_0=$(stat -c '%s' src/expset_daisyworld.f_binbio_place_cell_info.bin_size_ne_0.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_bin_size_ne_0)
	cat src/expset_daisyworld.f_binbio_place_cell_info.bin_size_ne_0.o

	# 取得フラグを配置
	## ※ この時点でregHLにcollected_flagsのアドレスが設定されている
	## regHLをregBCへ退避
	lr35902_copy_to_from regC regL
	lr35902_copy_to_from regB regH
	## カーソル位置を設定
	con_set_cursor $(con_tcoord_to_tadr $COLLECTED_FLAGS_UNIT_VAL_TCOORD_X $COLLECTED_FLAGS_LABEL_VAL_TCOORD_Y)
	## 16進数の接頭辞を配置
	lr35902_set_reg regHL $a_const_pref_hex
	lr35902_call $a_print
	## regBCからregHLを復帰
	lr35902_copy_to_from regL regC
	lr35902_copy_to_from regH regB
	## 値を配置
	### regAへcollected_flagsを取得
	lr35902_copy_to_from regA ptrHL
	### regAの値を16進数で配置
	lr35902_call $a_print_regA

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 細胞ステータス情報をクリア
f_binbio_clear_cell_info() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regDE

	# 関数内で使用する定数を定義
	local F_PRINT_REGA_LEN=2	# f_print_regA()が出す文字数
	local F_PRINT_REGA_SIGNED_DEC_LEN=4	# f_print_regA_signed_dec()が出す文字数
	local BIN_DATA_STR_LEN=14	# bin_data部分の文字数
	## TODO デイジーワールド実験では常に bin_size == 5 なのでこの様にしているが、もしそれが変わるならこの定数も変える必要がある

	# フラグをクリア
	## ラベルをクリア
	con_delch_tadr_num_macro $FLAGS_LABEL_TCOORD_X $FLAGS_LABEL_TCOORD_Y $((sz_const_cell_status_str_flags - 1))
	## 16進数の接頭辞と値をクリア
	con_delch_tadr_num_macro $FLAGS_PREF_VAL_TCOORD_X $FLAGS_PREF_VAL_TCOORD_Y $(((sz_const_pref_hex - 1) + F_PRINT_REGA_LEN))

	# タイル座標をクリア
	## ラベルをクリア
	con_delch_tadr_num_macro $TCOORD_LABEL_TCOORD_X $TCOORD_LABEL_TCOORD_Y $((sz_const_cell_status_str_coord - 1))
	## '('とX座標の値と'、'をクリア
	con_delch_tadr_num_macro $TCOORD_OPEN_BRACKET_TCOORD_X $TCOORD_OPEN_BRACKET_TCOORD_Y $((1 + F_PRINT_REGA_SIGNED_DEC_LEN + 1))
	## Y座標の値と')'をクリア
	con_delch_tadr_num_macro $TCOORD_Y_VAL_TCOORD_X $TCOORD_Y_VAL_TCOORD_Y $((F_PRINT_REGA_SIGNED_DEC_LEN + 1))

	# 余命/寿命をクリア
	## ラベルと値をクリア
	con_delch_tadr_num_macro $LIFE_LEFT_DURATION_LABEL_TCOORD_X $LIFE_LEFT_DURATION_TCOORD_Y $(((sz_const_cell_status_str_life_left_duration - 1) + F_PRINT_REGA_SIGNED_DEC_LEN + 1 + F_PRINT_REGA_SIGNED_DEC_LEN))

	# 適応度をクリア
	## ラベルと値をクリア
	con_delch_tadr_num_macro $FITNESS_LABEL_TCOORD_X $FITNESS_TCOORD_Y $(((sz_const_cell_status_str_fitness - 1) + (sz_const_pref_hex - 1) + F_PRINT_REGA_LEN))

	# バイナリとサイズをクリア
	## ラベルとサイズの値と')'をクリア
	con_delch_tadr_num_macro $BIN_DATA_SIZE_LABEL_TCOORD_X $BIN_DATA_SIZE_LABEL_SIZE_VAL_TCOORD_Y $(((sz_const_cell_status_str_bin_data_size - 1) + F_PRINT_REGA_SIGNED_DEC_LEN + 1))
	## 16進数の接頭辞とバイナリの値をクリア
	con_delch_tadr_num_macro $BIN_DATA_PREF_VAL_TCOORD_X $BIN_DATA_PREF_VAL_TCOORD_Y $(((sz_const_pref_hex - 1) + BIN_DATA_STR_LEN))

	# 取得フラグをクリア
	## ラベルと16進数の接頭辞と値をクリア
	con_delch_tadr_num_macro $COLLECTED_FLAGS_LABEL_TCOORD_X $COLLECTED_FLAGS_LABEL_VAL_TCOORD_Y $(((sz_const_cell_status_str_collected_flags - 1) + (sz_const_pref_hex - 1) + F_PRINT_REGA_LEN))

	# pop & return
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
	lr35902_return
}

# 評価関数選択を画面へ配置
f_binbio_place_cell_eval_sel() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# ラベルを配置
	con_print_xy_macro $CELL_EVAL_SEL_LABEL_TCOORD_X $CELL_EVAL_SEL_LABEL_TCOORD_Y $a_const_select_cell_eval

	# 外枠を配置
	con_draw_rect_macro $CELL_EVAL_SEL_FRAME_TCOORD_X $CELL_EVAL_SEL_FRAME_TCOORD_Y $CELL_EVAL_SEL_FRAME_WIDTH $CELL_EVAL_SEL_FRAME_HEIGHT

	# 評価関数選択の外枠内に関数名を配置
	## デイジーワールド
	con_print_xy_macro $CELL_EVAL_SEL_DAISYWORLD_TCOORD_X $CELL_EVAL_SEL_DAISYWORLD_TCOORD_Y $a_const_cell_eval_daisyworld
	## 固定値
	con_print_xy_macro $CELL_EVAL_SEL_FIXEDVAL_TCOORD_X $CELL_EVAL_SEL_FIXEDVAL_TCOORD_Y $a_const_cell_eval_fixedval

	# 現在選択されている関数に応じた処理
	## regAへ現在の評価関数番号を取得
	lr35902_copy_to_regA_from_addr $var_binbio_expset_num
	## regA == デイジーワールド ?
	lr35902_compare_regA_and $CELL_EVAL_NUM_DAISYWORLD
	(
		# regA == デイジーワールド の場合

		# デイジーワールドの関数名の左に「→」を配置
		con_putxy_macro $(calc16_2 "${CELL_EVAL_SEL_DAISYWORLD_TCOORD_X}-1") $CELL_EVAL_SEL_DAISYWORLD_TCOORD_Y '→'

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regDE
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >src/expset_daisyworld.f_binbio_place_cell_eval_sel.daisyworld.o
	local sz_daisyworld=$(stat -c '%s' src/expset_daisyworld.f_binbio_place_cell_eval_sel.daisyworld.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_daisyworld)
	cat src/expset_daisyworld.f_binbio_place_cell_eval_sel.daisyworld.o
	## regA == 固定値 ?
	lr35902_compare_regA_and $CELL_EVAL_NUM_FIXEDVAL
	(
		# regA == 固定値 の場合

		# デイジーワールドの関数名の左に「→」を配置
		con_putxy_macro $(calc16_2 "${CELL_EVAL_SEL_FIXEDVAL_TCOORD_X}-1") $CELL_EVAL_SEL_FIXEDVAL_TCOORD_Y '→'

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regDE
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >src/expset_daisyworld.f_binbio_place_cell_eval_sel.fixedval.o
	local sz_fixedval=$(stat -c '%s' src/expset_daisyworld.f_binbio_place_cell_eval_sel.fixedval.o)
	lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_fixedval)
	cat src/expset_daisyworld.f_binbio_place_cell_eval_sel.fixedval.o

	# regAがその他の値の場合(現状、このパスには来ないはず)
	# もしこのパスに来るようであれば無限ループで止める
	infinite_halt

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 評価関数選択をクリア
f_binbio_clear_cell_eval_sel() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regDE

	# ラベルをクリア
	con_delch_tadr_num_macro $CELL_EVAL_SEL_LABEL_TCOORD_X $CELL_EVAL_SEL_LABEL_TCOORD_Y $((sz_const_select_cell_eval - 1))

	# 枠線と中身をクリア
	con_clear_rect_macro $CELL_EVAL_SEL_FRAME_TCOORD_X $CELL_EVAL_SEL_FRAME_TCOORD_Y $CELL_EVAL_SEL_FRAME_WIDTH $CELL_EVAL_SEL_FRAME_HEIGHT

	# pop & return
	lr35902_pop_reg regDE
	lr35902_pop_reg regAF
	lr35902_return
}

# 指定されたアドレスへ白/黒デイジーのデフォルト値を設定
# in : regB  - 白/黒どちらか?(タイル番号で指定)
#      regD  - 白/黒デイジーのタイル座標Y
#      regE  - 白/黒デイジーのタイル座標X
#      regHL - デフォルト値を設定する領域の先頭アドレス
f_binbio_cell_set_default_daisy() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regHL

	# flags
	lr35902_set_reg regA $CELL_DEFAULT_FLAGS_DAISY
	lr35902_copyinc_to_ptrHL_from_regA

	# tile_x
	lr35902_copy_to_from regA regE
	lr35902_copyinc_to_ptrHL_from_regA

	# tile_y
	lr35902_copy_to_from regA regD
	lr35902_copyinc_to_ptrHL_from_regA

	# life_duration
	lr35902_set_reg regA $CELL_DEFAULT_LIFE_DURATION_DAISY
	lr35902_copyinc_to_ptrHL_from_regA

	# life_left
	lr35902_set_reg regA $CELL_DEFAULT_LIFE_LEFT_DAISY
	lr35902_copyinc_to_ptrHL_from_regA

	# fitness
	lr35902_set_reg regA $CELL_DEFAULT_FITNESS_DAISY
	lr35902_copyinc_to_ptrHL_from_regA

	local obj_pref=src/f_binbio_cell_set_default_daisy

	# tile_num
	lr35902_copy_to_from regA regB
	lr35902_copyinc_to_ptrHL_from_regA

	# bin_size
	lr35902_set_reg regA $CELL_DEFAULT_BIN_SIZE_DAISY
	lr35902_copyinc_to_ptrHL_from_regA

	# bin_data
	lr35902_copy_to_from regA regB
	lr35902_compare_regA_and $GBOS_TILE_NUM_DAISY_WHITE
	local byte_in_inst
	(
		# 白デイジーの場合

		# 地表温度を下げる命令列を配置
		for byte_in_inst in \
			$CELL_DEFAULT_BIN_DATA_0_DAISY \
				$CELL_DEFAULT_BIN_DATA_1_DAISY \
				$CELL_DEFAULT_BIN_DATA_2_DAISY \
				$CELL_DEFAULT_BIN_DATA_3_DAISY_WHITE \
				$CELL_DEFAULT_BIN_DATA_4_DAISY; do
			lr35902_set_reg regA $byte_in_inst
			lr35902_copyinc_to_ptrHL_from_regA
		done
	) >$obj_pref.bin_data.white.o
	(
		# 黒デイジーの場合

		# 地表温度を上げる命令列を配置
		for byte_in_inst in \
			$CELL_DEFAULT_BIN_DATA_0_DAISY \
				$CELL_DEFAULT_BIN_DATA_1_DAISY \
				$CELL_DEFAULT_BIN_DATA_2_DAISY \
				$CELL_DEFAULT_BIN_DATA_3_DAISY_BLACK \
				$CELL_DEFAULT_BIN_DATA_4_DAISY; do
			lr35902_set_reg regA $byte_in_inst
			lr35902_copyinc_to_ptrHL_from_regA
		done

		# 白デイジーの場合の処理を飛ばす
		local sz_bin_data_white=$(stat -c '%s' $obj_pref.bin_data.white.o)
		lr35902_rel_jump $(two_digits_d $sz_bin_data_white)
	) >$obj_pref.bin_data.black.o
	local sz_bin_data_black=$(stat -c '%s' $obj_pref.bin_data.black.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_bin_data_black)
	cat $obj_pref.bin_data.black.o
	cat $obj_pref.bin_data.white.o

	# collected_flags
	lr35902_set_reg regA $CELL_DEFAULT_COLLECTED_FLAGS_DAISY
	lr35902_copy_to_from ptrHL regA

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regAF
	lr35902_return
}

# バイナリ生物環境の初期化
# in : regA - 実験セット番号
f_binbio_init() {
	local i

	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regDE
	lr35902_push_reg regHL

	# 実験セット番号変数を初期化
	lr35902_copy_to_addr_from_regA $var_binbio_expset_num

	# 細胞データ領域をゼロクリア
	lr35902_call $a_binbio_clear_cell_data_area

	# 初期細胞を生成(デイジー)
	## 細胞データ領域の最初のアドレスをregHLへ設定
	lr35902_set_reg regHL $BINBIO_CELL_DATA_AREA_BEGIN
	## flags = 0x01
	lr35902_set_reg regA 01
	lr35902_copyinc_to_ptrHL_from_regA
	## tile_x = $BINBIO_CELL_TILE_X_INIT
	lr35902_set_reg regA $BINBIO_CELL_TILE_X_INIT
	lr35902_copyinc_to_ptrHL_from_regA
	### 後のためにregEにも設定
	lr35902_copy_to_from regE regA
	## tile_y = $BINBIO_CELL_TILE_Y_INIT
	lr35902_set_reg regA $BINBIO_CELL_TILE_Y_INIT
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

	# 初期細胞をマップへ配置(デイジー)
	## タイル座標をVRAMアドレスへ変換
	lr35902_call $a_tcoord_to_addr
	## regDEをスタックへ退避
	lr35902_push_reg regDE
	## VRAMアドレスと細胞のタイル番号をtdqへエンキュー
	### VRAMアドレスをregDEへ設定
	lr35902_copy_to_from regD regH
	lr35902_copy_to_from regE regL
	### tdqへエンキューする
	lr35902_call $a_enq_tdq
	## regDEをスタックから復帰
	lr35902_pop_reg regDE
	## この時点でタイルミラー領域へも手動で反映
	### タイル座標(regE, regD)をミラーアドレス(regHL)へ変換
	lr35902_call $a_tcoord_to_mrraddr
	### ミラー領域へタイル番号を書き込み
	lr35902_copy_to_from ptrHL regB

	# 初期細胞を生成(捕食者1)
	lr35902_set_reg regB $GBOS_TILE_NUM_PREDATOR
	lr35902_set_reg regD $BINBIO_CELL_TILE_Y_INIT
	lr35902_set_reg regE $(calc16_2 "${BINBIO_CELL_TILE_X_INIT}+2")
	lr35902_call $a_binbio_place_cell

	# 初期細胞をマップへ配置(捕食者1)
	## タイル座標をVRAMアドレスへ変換
	lr35902_call $a_tcoord_to_addr
	## regDEをスタックへ退避
	lr35902_push_reg regDE
	## VRAMアドレスと細胞のタイル番号をtdqへエンキュー
	### VRAMアドレスをregDEへ設定
	lr35902_copy_to_from regD regH
	lr35902_copy_to_from regE regL
	### tdqへエンキューする
	lr35902_call $a_enq_tdq
	## regDEをスタックから復帰
	lr35902_pop_reg regDE
	## この時点でタイルミラー領域へも手動で反映
	### タイル座標(regE, regD)をミラーアドレス(regHL)へ変換
	lr35902_call $a_tcoord_to_mrraddr
	### ミラー領域へタイル番号を書き込み
	lr35902_copy_to_from ptrHL regB

	# 初期細胞を生成(捕食者2)
	lr35902_set_reg regB $GBOS_TILE_NUM_PREDATOR
	lr35902_set_reg regD $(calc16_2 "${BINBIO_CELL_TILE_Y_INIT}-2")
	lr35902_set_reg regE $(calc16_2 "${BINBIO_CELL_TILE_X_INIT}-2")
	lr35902_call $a_binbio_place_cell

	# 初期細胞をマップへ配置(捕食者2)
	## タイル座標をVRAMアドレスへ変換
	lr35902_call $a_tcoord_to_addr
	## regDEをスタックへ退避
	lr35902_push_reg regDE
	## VRAMアドレスと細胞のタイル番号をtdqへエンキュー
	### VRAMアドレスをregDEへ設定
	lr35902_copy_to_from regD regH
	lr35902_copy_to_from regE regL
	### tdqへエンキューする
	lr35902_call $a_enq_tdq
	## regDEをスタックから復帰
	lr35902_pop_reg regDE
	## この時点でタイルミラー領域へも手動で反映
	### タイル座標(regE, regD)をミラーアドレス(regHL)へ変換
	lr35902_call $a_tcoord_to_mrraddr
	### ミラー領域へタイル番号を書き込み
	lr35902_copy_to_from ptrHL regB

	# その他のシステム変数へ初期値を設定
	## cur_cell_addr = $BINBIO_CELL_DATA_AREA_BEGIN
	lr35902_set_reg regA $(echo $BINBIO_CELL_DATA_AREA_BEGIN | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_bh
	lr35902_set_reg regA $(echo $BINBIO_CELL_DATA_AREA_BEGIN | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_binbio_cur_cell_addr_th
	if [ $BINBIO_FIX_MUTATION_PROBABILITY -eq 1 ]; then
		## mutation_probability
		lr35902_set_reg regA $BINBIO_MUTATION_PROBABILITY_INIT
		lr35902_copy_to_addr_from_regA $var_binbio_mutation_probability
	fi
	## cell_eval_fixedval_val = $CELL_EVAL_FIXEDVAL_VAL_INIT
	lr35902_set_reg regA $CELL_EVAL_FIXEDVAL_VAL_INIT
	lr35902_copy_to_addr_from_regA $var_binbio_cell_eval_fixedval_val
	## get_code_comp_counter_addr = 0x0000
	lr35902_xor_to_regA regA
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_bh
	lr35902_copy_to_addr_from_regA $var_binbio_get_code_comp_all_counter_addr_th
	## binbio_surface_temp_prev_counter = 0
	lr35902_copy_to_addr_from_regA $var_binbio_surface_temp_prev_counter
	## binbio_status_disp_counter = 0
	lr35902_copy_to_addr_from_regA $var_binbio_status_disp_counter
	## binbio_cell_eval_conf_paramno = 0
	lr35902_copy_to_addr_from_regA $var_binbio_cell_eval_conf_paramno
	## binbio_status_disp_status = $STATUS_DISP_SHOW_SOFT_DESC
	lr35902_set_reg regA $STATUS_DISP_SHOW_SOFT_DESC
	lr35902_copy_to_addr_from_regA $var_binbio_status_disp_status
	## binbio_surface_temp = $DAISY_GROWING_TEMP
	lr35902_set_reg regA $DAISY_GROWING_TEMP
	lr35902_copy_to_addr_from_regA $var_binbio_surface_temp

	# 地表温度情報をマップへ配置
	## カーソル位置を設定しタイトル文字列を配置
	con_print_xy_macro $SURFACE_TEMP_TITLE_TCOORD_X $SURFACE_TEMP_TITLE_TCOORD_Y $a_const_surface_temp_str_title
	## 現在の地表温度の値を配置
	lr35902_call $a_binbio_update_status_disp
	## 単位とボタンを配置
	lr35902_set_reg regHL $a_const_surface_temp_str_unit_and_btn
	lr35902_call $a_print

	# 細胞表示領域の枠線をマップへ配置
	## カーソル位置を"┌"の位置へ設定
	lr35902_set_reg regA $(echo $CELL_DISP_AREA_FRAME_UPPER_LEFT_TADR | cut -c3-4)
	lr35902_copy_to_addr_from_regA $var_con_tadr_bh
	lr35902_set_reg regA $(echo $CELL_DISP_AREA_FRAME_UPPER_LEFT_TADR | cut -c1-2)
	lr35902_copy_to_addr_from_regA $var_con_tadr_th
	## "┌"を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_UPPER_LEFT_BAR
	lr35902_call $a_putch
	## 上側と下側の"─"を配置する数を算出
	local num_horizontal_bars=$(bc <<< "ibase=16;$BINBIO_CELL_DISP_AREA_ETX - $BINBIO_CELL_DISP_AREA_STX + 1")
	## "─"(上側)を$num_horizontal_bars個分配置
	for i in $(seq $num_horizontal_bars); do
		# "─"(上側)を配置
		lr35902_set_reg regB $GBOS_TILE_NUM_UPPER_BAR
		lr35902_call $a_putch
	done
	## "┐"を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_UPPER_RIGHT_BAR
	lr35902_call $a_putch
	## 右側と左側の"│"を配置する数を算出
	local num_vertical_bars=$(bc <<< "ibase=16;$BINBIO_CELL_DISP_AREA_ETY - $BINBIO_CELL_DISP_AREA_STY + 1")
	## カーソル位置をregHLへ取得し、1文字分戻す
	lr35902_copy_to_regA_from_addr $var_con_tadr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_con_tadr_th
	lr35902_copy_to_from regH regA
	lr35902_dec regHL
	## 1行分のタイル数をregDEへ設定
	lr35902_set_reg regDE $(four_digits $GB_SC_WIDTH_T)
	## "│"(右側)を$num_vertical_bars個分配置
	for i in $(seq $num_vertical_bars); do
		# regHLへregDEを加算し、カーソル位置の変数へ設定
		lr35902_add_to_regHL regDE
		lr35902_copy_to_from regA regL
		lr35902_copy_to_addr_from_regA $var_con_tadr_bh
		lr35902_copy_to_from regA regH
		lr35902_copy_to_addr_from_regA $var_con_tadr_th

		# "│"(右側)を配置
		lr35902_set_reg regB $GBOS_TILE_NUM_RIGHT_BAR
		lr35902_call $a_putch
	done
	## regHLへregDEを加算し、カーソル位置の変数へ設定
	lr35902_add_to_regHL regDE
	lr35902_copy_to_from regA regL
	lr35902_copy_to_addr_from_regA $var_con_tadr_bh
	lr35902_copy_to_from regA regH
	lr35902_copy_to_addr_from_regA $var_con_tadr_th
	## "┘"を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_LOWER_RIGHT_BAR
	lr35902_call $a_putch
	## regHLへ"┌"の位置を設定
	lr35902_set_reg regA $(echo $CELL_DISP_AREA_FRAME_UPPER_LEFT_TADR | cut -c3-4)
	lr35902_copy_to_from regL regA
	lr35902_set_reg regA $(echo $CELL_DISP_AREA_FRAME_UPPER_LEFT_TADR | cut -c1-2)
	lr35902_copy_to_from regH regA
	## "│"(左側)を$num_vertical_bars個分配置
	for i in $(seq $num_vertical_bars); do
		# regHLへregDEを加算し、カーソル位置の変数へ設定
		lr35902_add_to_regHL regDE
		lr35902_copy_to_from regA regL
		lr35902_copy_to_addr_from_regA $var_con_tadr_bh
		lr35902_copy_to_from regA regH
		lr35902_copy_to_addr_from_regA $var_con_tadr_th

		# "│"(左側)を配置
		lr35902_set_reg regB $GBOS_TILE_NUM_LEFT_BAR
		lr35902_call $a_putch
	done
	## regHLへregDEを加算し、カーソル位置の変数へ設定
	lr35902_add_to_regHL regDE
	lr35902_copy_to_from regA regL
	lr35902_copy_to_addr_from_regA $var_con_tadr_bh
	lr35902_copy_to_from regA regH
	lr35902_copy_to_addr_from_regA $var_con_tadr_th
	## "└"を配置
	lr35902_set_reg regB $GBOS_TILE_NUM_LOWER_LEFT_BAR
	lr35902_call $a_putch
	## "─"(下側)を$num_horizontal_bars個分配置
	for i in $(seq $num_horizontal_bars); do
		# "─"(上側)を配置
		lr35902_set_reg regB $GBOS_TILE_NUM_LOWER_BAR
		lr35902_call $a_putch
	done

	# ソフト説明をマップへ配置
	lr35902_call $a_binbio_place_soft_desc

	# pop & return
	lr35902_pop_reg regHL
	lr35902_pop_reg regDE
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 白/黒デイジー用の成長関数
# 現在の細胞の機械語バイナリの中に取得したコード化合物と同じものが存在したら、
# 対応するcollected_flagsのビットをセットする
# in  : regHL - 現在の細胞のfitnessのアドレス
f_binbio_cell_growth_daisy() {
	# push
	lr35902_push_reg regAF
	lr35902_push_reg regBC
	lr35902_push_reg regHL

	local obj

	# regHLへ現在の細胞のアドレスを設定する
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA

	# regHLのアドレスをfitnessの位置まで進める
	lr35902_set_reg regBC 0005
	lr35902_add_to_regHL regBC

	# regBへ現在の細胞の適応度を取得
	lr35902_copy_to_from regB ptrHL

	# regAへ乱数を取得
	lr35902_call $a_get_rnd

	# regA(乱数) < regB(現在の細胞の適応度) ?
	lr35902_compare_regA_and regB
	obj=src/f_binbio_cell_growth_daisy.pop_and_return.o
	(
		# regA(乱数) >= regB(現在の細胞の適応度) の場合

		# pop & return
		lr35902_pop_reg regHL
		lr35902_pop_reg regBC
		lr35902_pop_reg regAF
		lr35902_return
	) >$obj
	local sz_pop_and_return=$(stat -c '%s' $obj)
	lr35902_rel_jump_with_cond C $(two_digits_d $sz_pop_and_return)
	cat $obj

	# push
	lr35902_push_reg regDE

	# コード化合物を取得
	lr35902_call $a_binbio_get_code_comp

	# 取得したコード化合物をregDへコピー
	lr35902_copy_to_from regD regA

	# regHLのアドレスをbin_sizeの位置まで進める
	lr35902_inc regHL
	lr35902_inc regHL

	# bin_sizeをregBへコピー
	lr35902_copy_to_from regB ptrHL

	# regBCをスタックへpush
	lr35902_push_reg regBC

	# regHLのアドレスをcollected_flagsの位置まで進める
	lr35902_set_reg regBC 0006
	lr35902_add_to_regHL regBC

	# 取得フラグをregEへコピー
	lr35902_copy_to_from regE ptrHL

	# regHLのアドレスをbin_dataの位置まで戻す
	lr35902_set_reg regBC $(two_comp_4 5)
	lr35902_add_to_regHL regBC

	# regBCをスタックからpop
	lr35902_pop_reg regBC

	# regCをゼロクリア(処理したバイト数のカウンタにする)
	lr35902_set_reg regC 00

	# bin_dataを1バイトずつチェック
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
			) >src/f_binbio_cell_growth_daisy.3.o
			local sz_3=$(stat -c '%s' src/f_binbio_cell_growth_daisy.3.o)
			lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_3)
			cat src/f_binbio_cell_growth_daisy.3.o
		) >src/f_binbio_cell_growth_daisy.1.o
		(
			# ptrHL != regD の場合

			# ループ脱出フラグ(regA)をゼロクリア
			lr35902_xor_to_regA regA

			# ptrHL == regD の場合の処理を飛ばす
			local sz_1=$(stat -c '%s' src/f_binbio_cell_growth_daisy.1.o)
			lr35902_rel_jump $(two_digits_d $sz_1)
		) >src/f_binbio_cell_growth_daisy.2.o
		local sz_2=$(stat -c '%s' src/f_binbio_cell_growth_daisy.2.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_2)
		cat src/f_binbio_cell_growth_daisy.2.o	# ptrHL != regD
		cat src/f_binbio_cell_growth_daisy.1.o	# ptrHL == regD

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

		# アドレスregHLをインクリメント
		lr35902_inc regHL

		# 処理したバイト数カウンタ(regC)をインクリメント
		lr35902_inc regC

		# regBのbin_sizeをデクリメント
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
			lr35902_inc regD
		) >src/f_binbio_cell_growth_daisy.4.o
		local sz_4=$(stat -c '%s' src/f_binbio_cell_growth_daisy.4.o)
		lr35902_rel_jump_with_cond NZ $(two_digits_d $sz_4)
		cat src/f_binbio_cell_growth_daisy.4.o
		## regAをregDから復帰
		lr35902_copy_to_from regA regD
		## regDEをスタックからpop
		lr35902_pop_reg regDE

		# regA != 0 なら、1バイトずつチェックするループを脱出する
		lr35902_compare_regA_and 00
		(
			# ループを脱出
			lr35902_rel_jump $(two_digits_d 2)
		) >src/f_binbio_cell_growth_daisy.7.o
		local sz_7=$(stat -c '%s' src/f_binbio_cell_growth_daisy.7.o)
		lr35902_rel_jump_with_cond Z $(two_digits_d $sz_7)
		cat src/f_binbio_cell_growth_daisy.7.o
	) >src/f_binbio_cell_growth_daisy.5.o
	cat src/f_binbio_cell_growth_daisy.5.o
	local sz_5=$(stat -c '%s' src/f_binbio_cell_growth_daisy.5.o)
	lr35902_rel_jump $(two_comp_d $((sz_5 + 2)))	# 2

	# regA = 8 - 処理したバイト数(regC)
	lr35902_set_reg regA 08
	lr35902_sub_to_regA regC

	# regA != 0 ?
	lr35902_compare_regA_and 00
	(
		# regA != 0 の場合

		# regAをregBへコピー
		lr35902_copy_to_from regB regA

		# regEをregAへコピー
		lr35902_copy_to_from regA regE

		# regBの値だけregAを右ローテート
		(
			# regAを1ビット右ローテート
			lr35902_rot_regA_right

			# regBをデクリメント
			lr35902_dec regB
		) >src/f_binbio_cell_growth_daisy.8.o
		cat src/f_binbio_cell_growth_daisy.8.o
		local sz_8=$(stat -c '%s' src/f_binbio_cell_growth_daisy.8.o)
		lr35902_rel_jump_with_cond NZ $(two_comp_d $((sz_8 + 2)))

		# regAをregEへコピー
		lr35902_copy_to_from regE regA
	) >src/f_binbio_cell_growth_daisy.6.o
	local sz_6=$(stat -c '%s' src/f_binbio_cell_growth_daisy.6.o)
	lr35902_rel_jump_with_cond Z $(two_digits_d $sz_6)
	cat src/f_binbio_cell_growth_daisy.6.o

	# regEを細胞のcollected_flagsへ書き戻す
	## regHLへ現在の細胞のアドレスを設定する
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_bh
	lr35902_copy_to_from regL regA
	lr35902_copy_to_regA_from_addr $var_binbio_cur_cell_addr_th
	lr35902_copy_to_from regH regA
	## regHLのアドレスをcollected_flagsの位置まで進める
	lr35902_set_reg regBC 000d
	lr35902_add_to_regHL regBC
	## ptrHLへregEの値を設定
	lr35902_copy_to_from ptrHL regE

	# pop & return
	lr35902_pop_reg regDE
	lr35902_pop_reg regHL
	lr35902_pop_reg regBC
	lr35902_pop_reg regAF
	lr35902_return
}

# 白/黒デイジー用の突然変異関数
# in : regHL - 対象の細胞のアドレス
## 白デイジーは黒デイジーへ、黒デイジーは白デイジーへ変異させる
f_binbio_cell_mutation_daisy() {
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
