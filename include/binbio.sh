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
