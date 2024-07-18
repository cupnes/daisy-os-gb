if [ "${INCLUDE_VARS_SH+is_defined}" ]; then
	return
fi
INCLUDE_VARS_SH=true

var_mouse_x=c000	# マウスカーソルX座標
var_mouse_y=c001	# マウスカーソルY座標
# ※ OBJ座標系は右下原点なので
# 　 マウスカーソル座標はカーソル先端(左上)から(X,Y)=(+8,+16)ピクセル
var_btn_stat=c002	# 現在のキー状態を示す変数
var_win_xt=c003	# ウィンドウのX座標(タイル番目)
var_win_yt=c004	# ウィンドウのY座標(タイル番目)
var_prv_btn=c005	# 前回のキー状態を示す変数
var_draw_act_stat=c006	# 描画アクション(DA)ステータス

var_da_var1=c007	# DA用変数1
			# - view_txt: 残り文字数(下位8ビット)
var_da_var2=c008	# DA用変数2
			# - view_txt: 残り文字数(上位8ビット)
var_da_var3=c009	# DA用変数3
			# - view_txt: 次に配置する文字のアドレス下位8ビット
var_da_var4=c00a	# DA用変数4
			# - view_txt: 次に配置する文字のアドレス上位8ビット
var_da_var5=c00b	# DA用変数5
			# - view_txt: 次に配置するウィンドウタイル座標Y
var_da_var6=c00c	# DA用変数6
			# - view_txt: 次に配置するウィンドウタイル座標X
# 0xc007 - 0xc00c の6バイトはバイナリ生物用にも使用している
# (include/binbio.sh 参照)

var_clr_win_nyt=c00d	# - clr_win: 次にクリアするウィンドウタイル座標Y
var_view_img_state=c00e	# view_img: ステート番号
var_view_img_ntadr_bh=c00f	# view_img: 次に使用するタイルアドレス(下位8ビット)
var_view_img_ntadr_th=c010	# view_img: 次に使用するタイルアドレス(上位8ビット)
var_ss_current_bank_file_num=c011	# slide show: 現在のスライドのバンク・ファイル番号
var_current_rom_bank_no=c012	# 0x4000〜の領域の現在のバンク番号
var_view_img_nyt=c013	# view_img: 次に描画するウィンドウタイル座標Y
var_view_img_nxt=c014	# view_img: 次に描画するウィンドウタイル座標X
var_win_stat=c015	# ウィンドウステータス
var_view_dir_file_th=c016	# view_dir: 表示するのは何番目のファイルか(0始まり)

# tdq用変数
var_tdq_head_bh=c017	# tdq.head[7:0]
var_tdq_head_th=c018	# tdq.head[15:8]
var_tdq_tail_bh=c019	# tdq.tail[7:0]
var_tdq_tail_th=c01a	# tdq.tail[15:8]
var_tdq_stat=c01b	# tdq.stat

var_app_release_btn=c01c	# アプリ用ボタンリリースフラグ

var_error=c01d	# 関数実行のエラー状態

# 実行ファイル用変数は使い終わったらゼロクリアすること
# bineditはこの変数が0か否かで、
# ファイル右クリックで呼び出されたか
# bineditを直接起動したかを判定している
var_exe_1=c01e	# 実行ファイル用変数1
var_exe_2=c01f	# 実行ファイル用変数2

var_mouse_enable=c020	# マウスの有効(=0x01)/無効(=0x00)
var_fs_base_bh=c021	# ファイルシステム先頭アドレス(下位8ビット)
var_fs_base_th=c022	# ファイルシステム先頭アドレス(上位8ビット)

# th == 0x00は、
# ・画面クリア
# ・var_con_tadr_{th,bh}を$CON_TADR_BASEへ更新
# が必要であることを示す
var_con_tadr_bh=c023	# コンソールで次に描画するタイルアドレス(下位8ビット)
var_con_tadr_th=c024	# コンソールで次に描画するタイルアドレス(上位8ビット)

# 実行ファイル用変数
var_exe_3=c025	# ファイルタイプ

# タイマーハンドラの実体
# タイマー割り込みで、このアドレスへジャンプしてくる
# push AF -> push HLの後、ここへジャンプしてくるため
# 最低限、pop HL(0xe1) -> pop AF(0xf1) -> reti(0xd9) は行うこと
# タイマーハンドラの実装はinclude/timer.shのtimer_init_handler()
# 2022-09-22現在、timer_init_handler()で$var_timer_handlerに並べているのは
# 上記したpop HL・pop AF・retiの3バイト
# ただし、今後、タイマーハンドラに色々と実装するかもしれない事を考えて
# 100バイトの領域は確保しておくことにする
var_timer_handler=c026
# ↑100(0x64)バイトは確保しておくということで、
# 　0xc026 - 0xc089 は変数等に使わないこと
# ↑タイマーハンドラ使っていないので100バイトも確保するのはやめる
# ↑100バイトは不要だが、init()で呼び出されるtimer_init_handler()で
# 　pop HL・pop AF・retiの3バイトを配置しているので0xc026 - 0xc028は使わないほうが良い

# 0xc029 - 0xc02f : 未使用

# バイナリ生物用変数
var_binbio_cell_eval_conf_paramno=c030	# 評価関数設定で現在選択中のパラメータ番号
var_binbio_status_disp_counter=c031	# ステータス表示領域で使用するカウンタ
## 実験セット側で独自定義している領域(0xc032 - 0xc035)(ここから)
### 実験セット: HELLO
### ※ src/main.shに専用関数が残っているため、専用変数もここに残している
var_binbio_get_code_comp_hello_counter=c033	# get_code_comp_hello()で使用するカウンタ
var_binbio_get_code_comp_hello_addr_bh=c034	# get_code_comp_hello()で使用するアドレス(下位8ビット)
var_binbio_get_code_comp_hello_addr_th=c035	# get_code_comp_hello()で使用するアドレス(上位8ビット)
## 実験セット側で独自定義している領域(0xc032 - 0xc035)(ここまで)
var_binbio_expset_num=c036	# 現在の実験セット番号(※ デイジーワールド実験ではvar_binbio_expset_numを現在の評価関数番号に使う)
var_binbio_get_code_comp_all_counter_addr_bh=c037	# get_code_comp_all()で使用するカウンタ/アドレス(下位8ビット)
var_binbio_get_code_comp_all_counter_addr_th=c038	# get_code_comp_all()で使用するカウンタ/アドレス(上位8ビット)
var_binbio_cur_cell_addr_bh=c039	# 現在対象としている細胞アドレス(下位8ビット)
var_binbio_cur_cell_addr_th=c03a	# 現在対象としている細胞アドレス(上位8ビット)
var_binbio_mutation_probability=c03b	# 突然変異確率

# 0xc03c - 0xc2f7 : 細胞データ領域
# (include/binbio.sh 参照)

# 乱数(線形合同法)
var_lgcs_xn=c2f8	# 線形合同法(LGCs)のX_n
var_lgcs_tile_sum=c2f9	# 前回の乱数取得時のマウスカーソルのX座標とY座標の和

# 0xc2fa - 0xc2ff : 未使用

# 0xc300 - 0xcefd : TDQ
# (include/tdq.sh 参照)

var_dbg_over_vblank=cf00	# vblank期間を超えたことを示すフラグ

# 0xdc00 - : タイルミラー領域
