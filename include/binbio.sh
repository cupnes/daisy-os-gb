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
BINBIO_CELL_DATA_AREA_BEGIN=c090	# 最初のアドレス
BINBIO_CELL_DATA_AREA_END=c2f7	# 最後のアドレス
## ※ 「(最後のアドレス + 1) - 最初のアドレス」が
## 　 細胞データ構造のサイズの倍数であること
BINBIO_CELL_DATA_AREA_SIZE=$(four_digits $(calc16 "${BINBIO_CELL_DATA_AREA_END}-${BINBIO_CELL_DATA_AREA_BEGIN}+1"))

# タイル属性番号
BINBIO_TILE_FAMILY_NUM_NONE=00	# 属性なし
BINBIO_TILE_FAMILY_NUM_WIN=01	# ウィンドウ
BINBIO_TILE_FAMILY_NUM_CHAR=02	# 文字
BINBIO_TILE_FAMILY_NUM_ICON=03	# アイコン
BINBIO_TILE_FAMILY_NUM_CELL=04	# 細胞

# 初期値
## 初期細胞
BINBIO_CELL_LIFE_DURATION_INIT=80	# 寿命(兼余命)
BINBIO_CELL_FITNESS_INIT=80	# 適応度

# 関数のチューニングパラメータ
BINBIO_CELL_EVAL_BASE_FITNESS=7f	# 適応度のベース値
BINBIO_CELL_EVAL_ADD_UNIT=10	# 同種1タイルあたりの適応度の加算単位
