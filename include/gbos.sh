if [ "${INCLUDE_GBOS_SH+is_defined}" ]; then
	return
fi
INCLUDE_GBOS_SH=true

. include/gb.sh

GBOS_NULL=0000

GBOS_WX_DEF=00
GBOS_WY_DEF=00

# ウィンドウの見かけ上の幅/高さ
# (描画用の1タイル分の幅/高さは除く)
GBOS_WIN_WIDTH_T=$(calc16_2 "${GB_DISP_WIDTH_T}-2")
GBOS_WIN_HEIGHT_T=$(calc16_2 "${GB_DISP_HEIGHT_T}-2")
GBOS_WIN_DRAWABLE_WIDTH_T=$(calc16_2 "${GBOS_WIN_WIDTH_T}-2")
GBOS_WIN_DRAWABLE_HEIGHT_T=$(calc16_2 "${GBOS_WIN_HEIGHT_T}-3")
GBOS_WIN_DRAWABLE_BASE_XT=$(calc16_2 "${GBOS_WX_DEF}+2")
GBOS_WIN_DRAWABLE_MAX_XT=$(calc16_2 "${GBOS_WIN_DRAWABLE_BASE_XT}+${GBOS_WIN_DRAWABLE_WIDTH_T}-1")
GBOS_WIN_DRAWABLE_BASE_YT=$(calc16_2 "${GBOS_WY_DEF}+3")
GBOS_WIN_DRAWABLE_MAX_YT=$(calc16_2 "${GBOS_WIN_DRAWABLE_BASE_YT}+${GBOS_WIN_DRAWABLE_HEIGHT_T}-1")

# タイル座標原点からdrawable領域へのオフセット
GBOS_WIN_DRAWABLE_OFS_XT=02
GBOS_WIN_DRAWABLE_OFS_YT=03

# $var_btn_stat用のマスク
GBOS_DIR_KEY_MASK=0f	# $var_btn_stat の十字キー入力のみ抽出するマスク
GBOS_DOWN_KEY_MASK=08
GBOS_UP_KEY_MASK=04
GBOS_LEFT_KEY_MASK=02
GBOS_RIGHT_KEY_MASK=01
GBOS_BTN_KEY_MASK=f0	# $var_btn_stat のボタン入力のみ抽出するマスク
GBOS_START_KEY_MASK=80
GBOS_SELECT_KEY_MASK=40
GBOS_B_KEY_MASK=20
GBOS_A_KEY_MASK=10

# ボタン入力フラグのビット番号
GBOS_JOYP_BITNUM_RIGHT=0
GBOS_JOYP_BITNUM_LEFT=1
GBOS_JOYP_BITNUM_UP=2
GBOS_JOYP_BITNUM_DOWN=3
GBOS_JOYP_BITNUM_A=4
GBOS_JOYP_BITNUM_B=5
GBOS_JOYP_BITNUM_SELECT=6
GBOS_JOYP_BITNUM_START=7

GBOS_START_KEY_BITNUM=7
GBOS_SELECT_KEY_BITNUM=6
GBOS_B_KEY_BITNUM=5
GBOS_A_KEY_BITNUM=4
GBOS_DOWN_KEY_BITNUM=3
GBOS_UP_KEY_BITNUM=2
GBOS_LEFT_KEY_BITNUM=1
GBOS_RIGHT_KEY_BITNUM=0

# 描画アクション(DA)ステータス用定数
GBOS_DA_BITNUM_CLR_WIN=0
GBOS_DA_BITNUM_VIEW_DIR=1
GBOS_DA_BITNUM_VIEW_TXT=2
GBOS_DA_BITNUM_VIEW_IMG=3
GBOS_DA_BITNUM_RSTR_TILES=4
GBOS_DA_BITNUM_RUN_EXE=5

# サウンドのデフォルト値
GBOS_NR50_DEF_S02_LV=4
GBOS_NR50_DEF_S01_LV=4

# メディア番号
GBOS_MEDIA_TYPE_CARTROM=00
GBOS_MEDIA_TYPE_CARTRAM=01

# 特定用途のバンク番号
GBOS_CARTROM_BANK_SYS=01
GBOS_CARTRAM_BANK_DEF=00

# 特定用途のファイル番号
GBOS_SYSBANK_FNO_BEDIT=00

# OAM
GBOS_OAM_BASE_CSL=$GB_OAM_BASE
GBOS_OAM_NUM_CSL=00
GBOS_OAM_NUM_PCB=27

# EXEの実行時ロード先アドレス
GBOS_APP_MEM_BASE=$GB_WRAM1_BASE

# view_img()の画像表示ステータス
GBOS_VIEW_IMG_STAT_NONE=00	# 画像表示なし
GBOS_VIEW_IMG_STAT_WAIT_FOR_TDQEMP=01	# tdq消費待ち
GBOS_VIEW_IMG_STAT_DURING_IMG_DISP=02	# 画像表示中

# slide show
SS_CURRENT_FILE_NUM_INIT=00	# 現在のスライドのファイル番号の初期値
