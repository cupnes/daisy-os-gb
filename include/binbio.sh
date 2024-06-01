if [ "${INCLUDE_BINBIO_SH+is_defined}" ]; then
	return
fi

. include/common.sh

INCLUDE_BINBIO_SH=true

# 細胞データ構造のサイズ[バイト]
BINBIO_CELL_DATA_SIZE=0e

# 細胞のデータ構造のフラグ
BINBIO_CELL_FLAGS_BIT_FIX=1

# 細胞データ構造の機械語バイナリ領域のサイズ[バイト]
BINBIO_CELL_BIN_DATA_AREA_SIZE=05
## collected_flagsにbin_data分のビットがセットされた状態
BINBIO_CELL_COLLECTED_FLAGS_ALL_SET=1f

# 細胞の機械語バイナリのロード先アドレス
BINBIO_BIN_LOAD_ADDR=c007

# 細胞データ領域
BINBIO_CELL_DATA_AREA_BEGIN=c03c	# 最初のアドレス
BINBIO_CELL_DATA_AREA_END=c2f7	# 最後のアドレス
## ※ 「(最後のアドレス + 1) - 最初のアドレス」が
## 　 細胞データ構造のサイズの倍数であること
BINBIO_CELL_DATA_AREA_SIZE=$(four_digits $(calc16 "${BINBIO_CELL_DATA_AREA_END}-${BINBIO_CELL_DATA_AREA_BEGIN}+1"))

# 適応度の最大値
BINBIO_CELL_MAX_FITNESS=ff

# タイル属性番号
BINBIO_TILE_FAMILY_NUM_NONE=00	# 属性なし
BINBIO_TILE_FAMILY_NUM_WIN=01	# ウィンドウ
BINBIO_TILE_FAMILY_NUM_CHAR=02	# 文字
BINBIO_TILE_FAMILY_NUM_ICON=03	# アイコン
BINBIO_TILE_FAMILY_NUM_CELL=04	# 細胞

# 実験セット番号
BINBIO_EXPSET_HELLO=00	# アルファベットタイルの中から"HELLO"を形成
BINBIO_EXPSET_DAISY=01	# アルファベットタイルの中から"DAISY"を形成
BINBIO_EXPSET_HELLOWORLD=02	# 全タイルの中から"こんにちは、せかい!"を形成
BINBIO_EXPSET_DAISYWORLD=03	# デイジーワールド

# 初期値
## システム変数
### 突然変異の発生しやすさを固定で設定する(1=有効/0=無効)
### - 有効な場合、突然変異の発生しやすさは固定でvar_binbio_mutation_probability
### - 無効な場合、突然変異の発生しやすさは「0xff - 適応度」
BINBIO_FIX_MUTATION_PROBABILITY=0
### 突然変異の発生しやすさ
BINBIO_MUTATION_PROBABILITY_INIT=c0
### 現在の実験セット番号
BINBIO_EXPSET_NUM_INIT=$BINBIO_EXPSET_DAISYWORLD
# BINBIO_EXPSET_NUM_INIT=$BINBIO_EXPSET_HELLO
## 初期細胞
BINBIO_CELL_TILE_X_INIT=06	# タイル座標(X)
BINBIO_CELL_TILE_Y_INIT=05	# タイル座標(Y)
BINBIO_CELL_LIFE_DURATION_INIT=1e	# 寿命(兼余命)
BINBIO_CELL_FITNESS_INIT=80	# 適応度

# 細胞表示領域
## 左上隅のタイル座標 = (STX, STY)
## 右下隅のタイル座標 = (ETX, ETY)
## ※ 計算で使う都合上、16進数のアルファベットは大文字で設定すること
if [ "$BINBIO_EXPSET_NUM_INIT" = "$BINBIO_EXPSET_DAISYWORLD" ]; then
	BINBIO_CELL_DISP_AREA_STX=01
	BINBIO_CELL_DISP_AREA_STY=02
	BINBIO_CELL_DISP_AREA_ETX=0C
	BINBIO_CELL_DISP_AREA_ETY=08
else
	BINBIO_CELL_DISP_AREA_STX=00
	BINBIO_CELL_DISP_AREA_STY=00
	BINBIO_CELL_DISP_AREA_ETX=$(calc16_2 "${GB_DISP_WIDTH_T}-1")
	BINBIO_CELL_DISP_AREA_ETY=$(calc16_2 "${GB_DISP_HEIGHT_T}-1")
fi
## 更新周期
BINBIO_CELL_DISP_AREA_UPDATE_CYC=0a	# 10

# 関数のチューニングパラメータ
BINBIO_CELL_EVAL_BASE_FITNESS=7f	# 適応度のベース値
BINBIO_CELL_EVAL_FAMILY_ADD_UNIT=10	# 同種1タイルあたりの適応度の加算単位
BINBIO_CELL_EVAL_HELLOWORLD_ADD_UNIT_OWN=9b	# 自分自身が所望のタイルである場合のベース値
BINBIO_CELL_EVAL_HELLOWORLD_ADD_UNIT_H=32	# 近傍に所望のタイルがある場合の加算単位①
BINBIO_CELL_EVAL_HELLOWORLD_ADD_UNIT_Q=19	# 近傍に所望のタイルがある場合の加算単位②
BINBIO_CELL_EVAL_DAISY_ADD_UNIT_OWN=a9	# 自分自身が所望のタイルである場合のベース値
BINBIO_CELL_EVAL_DAISY_ADD_UNIT=56	# 近傍に所望のタイルがある場合の加算単位①
BINBIO_CELL_EVAL_DAISY_ADD_UNIT_H=2b	# 近傍に所望のタイルがある場合の加算単位②
BINBIO_CELL_EVAL_HELLO_MAX_ALPHA_DIS=19	# アルファベット間の最大距離(25)
BINBIO_CELL_EVAL_HELLO_LIFE_ON_FIX=ff	# fixモード時の寿命(兼余命)
BINBIO_EVENT_BTN_START_RELEASE_EXPSET=$BINBIO_EXPSET_HELLO	# スタートボタンで選択する実験セット番号
BINBIO_EVENT_BTN_SELECT_RELEASE_EXPSET=$BINBIO_EXPSET_HELLOWORLD	# セレクトボタンで選択する実験セット番号
