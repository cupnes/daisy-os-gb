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

# 初期値
## システム変数
BINBIO_MUTATION_PROBABILITY_INIT=c0	# 突然変異の発生しやすさ
BINBIO_EXPSET_NUM_INIT=$BINBIO_EXPSET_HELLO	# 現在の実験セット番号
## 初期細胞
BINBIO_CELL_LIFE_DURATION_INIT=c0	# 寿命(兼余命)
BINBIO_CELL_FITNESS_INIT=80	# 適応度

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
