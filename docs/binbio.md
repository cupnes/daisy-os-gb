# バイナリ生物学のGB向け実装について
- バイトオーダーはリトルエンディアン

## データ構造
### `cell`: 細胞
| オフセット | 名前 | 内容 | 型 | 初期細胞[^init_cell]の値 |
| --- | --- | --- | --- | --- |
| 0 | `flags` | フラグ | ビットフィールド(1バイト) | 0x01 |
| 1 | `tile_x` | タイル座標(X) | 符号なし整数(1バイト) | 0x0a(10) |
| 2 | `tile_y` | タイル座標(Y) | 符号なし整数(1バイト) | 0x09 |
| 3 | `life_duration` | 寿命 | 符号なし整数(1バイト) | 0x0a(10) |
| 4 | `life_left` | 余命 | 符号なし整数(1バイト) | 0x0a(10) |
| 5 | `fitness` | 適応度 | 符号なし整数(1バイト) | 0x80(128) |
| 6 | `tile_num` | タイル番号 | 符号なし整数(1バイト) | 0x8b(細胞タイル) |
| 7 | `bin_size` | 機械語バイナリサイズ | 符号なし整数(1バイト) | 0x05 |
| 8 | `bin_data` | 機械語バイナリ | 機械語バイナリ列(5バイト) | 0x3e <タイル番号(1バイト)> cd <現在の細胞に指定されたタイル番号を設定する関数のアドレス(2バイト)> |
| 13 | `collected_flags` | 機械語バイナリの各バイトの取得フラグ | ビットフィールド(1バイト) | 0x00 |
- サイズ：14バイト
[^init_cell]: 開始時に存在する細胞

#### `flags`: フラグ
| ビット | 名前 | 内容 | 初期細胞の値 |
| --- | --- | --- | --- |
| 7-6 | - | 予約 | 0b0000 |
| 5-4 | `prey_cyc` | (捕食者のみ)捕食サイクルカウンタ | 0b00 |
| 3 | - | 予約 | 0 |
| 2 | `wrote_to_bg` | タイルデータのBGマップへの書込が完了した(=1)か否(=0)か | 1 |
| 1 | `fix` | fixモードが有効(=1)か否(=0)か | 0 |
| 0 | `alive` | この細胞が生きている(=1)か否(=0)か | 1 |

- ※ `wrote_to_bg`は、まだ分裂したばかりでミラー領域には反映されているがtdqからBGマップへの書込が完了していないという状態のデイジーを捕食者が捕食しないようにするためのフラグ
  - BGマップへの書込が完了していないデイジーを捕食してしまうと、捕食されてデイジーが死んだ後でtdqによるBGマップへの配置が行われる(その際にミラー領域へもそれが反映される)こととなってしまうため、そうならないようにする
  - 分裂時、BGマップへ該当のタイルデータを配置するエントリをtdqへ積んだ後、`wrote_to_bg`と`alive`を1にしたバイトを該当の細胞のflagsへ書き込むエントリもtdqへ積む
    - それ以外のビットが0にされてしまうが気にしない
      - 影響があるとすれば、`prey_cyc`がカウントアップされていたのが0に戻ってしまうくらい
  - 捕食者の捕食時の移動の際も「ミラー領域には反映されているがtdqからBGマップへの書込がまだ」という状況は発生し得るが、捕食者を捕食する存在がまだ居ないのでまだ問題にはならず、今の所特に対策もしない

#### `tile_x`・`tile_y`: タイル座標(X,Y)
- 8x8pxのタイル何個目か(0始まり)で表す座標系
- GBの背景マップサイズは256x256pxなので、タイル座標として取り得る値はX・Y共に0(0x00)〜31(0x1f)
  - その内、表示領域は160x144pxなので、表示されるのは20(0x14)x18(0x12)個のタイルの領域
- 変換式
  - ※ TILE_WIDTH = TILE_HEIGHT = 8
  - ピクセル座標(Px,Py) → タイル座標(Tx,Ty)
    - Tx = Px / TILE_WIDTH (小数点以下切り捨て)
    - Ty = Py / TILE_HEIGHT (小数点以下切り捨て)
  - タイル座標(Tx,Ty) → ピクセル座標(Px,Py)
    - Px = Tx * TILE_WIDTH
    - Py = Ty * TILE_HEIGHT
    - ※ この時、(Px,Py)は該当タイルの左上座標

#### `bin_data`: 機械語バイナリ
- `ret`命令は含まない
  - 「代謝/運動」時に実行用の領域へコピーし、その際に末尾にret命令を追加する

#### `collected_flags`: 機械語バイナリ列の各バイトの取得フラグ
- 下位のビットから順に`bin_data`の1バイト目、2バイト目、3バイト目、・・・の取得済みを示すフラグ

### システム定数
| 名前 | 内容 | 型 |
| --- | --- | --- |
| `NULL` | ヌルポインタ(0x0000) | アドレス(2バイト) |
| `CELL_DATA_SIZE` | 細胞データ構造のサイズ[バイト] | 符号なし整数(1バイト) |
| `CELL_BIN_DATA_AREA_SIZE` | 細胞データ構造の機械語バイナリ領域のサイズ[バイト] | 符号なし整数(1バイト) |
| `BIN_LOAD_ADDR` | 細胞の機械語バイナリのロード先アドレス | アドレス(2バイト) |
| `CELL_DATA_AREA_BEGIN` | 細胞データ領域の最初のアドレス | アドレス(2バイト) |
| `CELL_DATA_AREA_END` | 細胞データ領域の最後のアドレス | アドレス(2バイト) |
| `CELL_DATA_AREA_SIZE` | 細胞データ領域のサイズ | アドレス(2バイト) |

### システム変数
| 名前 | 内容 | 型 | 初期値 |
| --- | --- | --- | --- |
| `error` | 関数実行のエラー状態 | 符号なし整数(1バイト) | 0 |
| `cur_cell_addr` | 現在対象としている細胞アドレス | アドレス(2バイト) | 初期細胞のアドレス |
| `mutation_probability` | 突然変異確率(0x00〜0xff) | 符号なし整数(1バイト) | 50 |

## 振る舞い
### `get_tile_family_num`: 指定されたタイルのタイル属性番号を返す
- 引数
  | レジスタ | 内容 |
  | --- | --- |
  | A | タイル番号 |
- 戻り値
  | レジスタ | 内容 |
  | --- | --- |
  | A | タイル属性番号 |
- 処理内容
  - 指定されたタイルのタイル属性番号を返す

### `set_tile_num`: 現在の細胞に指定されたタイル番号を設定する
- 引数
  | レジスタ | 内容 |
  | --- | --- |
  | A | タイル番号 |
- 処理内容
  1. 現在の細胞の`tile_num`へレジスタAの値を設定
  2. 設定されたタイルをマップへ描画
     1. 現在の細胞の`tile_x`,`tile_y`からVRAMアドレスを算出
     2. 算出したVRAMアドレスと細胞のタイル番号をtdqへエンキュー

### `eval`: 評価
- 戻り値
  | レジスタ | 内容 |
  | --- | --- |
  | A | 評価結果の適応度(0x00〜0xff) |
- 処理内容
  - 現在の細胞を評価し、適応度をレジスタAへ設定しreturn
  - なお、fixモードが有効な細胞に対しては、適応度へ常に0xffを設定

### `metabolism_and_motion`: 代謝/運動
- 処理内容
  1. 実行
     1. 現在の細胞の`bin_data`の`bin_size`分のバイナリを`BIN_LOAD_ADDR`へロード
     2. ロードした最終アドレス+1の位置にreturn命令を配置
     3. `BIN_LOAD_ADDR`を関数呼び出し
  2. 評価
     1. 評価関数(`eval`)を呼び出す
     2. 得られた適応度を細胞へ設定

### `get_code_comp`: コード化合物取得
- 戻り値
  | レジスタ | 内容 |
  | --- | --- |
  | A | 取得したコード化合物 |
- 処理内容
  - 0x00〜0xffの間で値を生成して返す
  - ここをどのように実装するかもチューニングポイントなので、具体的な処理は実験によって変わってくる

### `growth`: 成長
- 処理内容
  1. 適応度に応じて環境から一つコード化合物を取得する
     1. 0x00〜0xffの間の乱数を生成
     2. 乱数は、現在の細胞の`fitness`の値より小さいか？
        - そうである場合、コード化合物取得関数(`get_code_comp`)を呼び出す
  2. コード化合物が取得できた場合の処理
     1. 現在の細胞の`bin_data`の中に取得したコード化合物と同じものが存在したら、対応する`collected_flags`のビットをセットする

### `is_dividable`: 分裂可能か？
- 戻り値
  | レジスタ | 内容 |
  | --- | --- |
  | A | 分裂可能なら1、そうでないなら0 |
- 処理内容
  - 現在の細胞の`collected_flags`の`bin_data`に対応する全てのビットがセットされていたら分裂可能

### `clear_cell_data_area`: 細胞データ領域をゼロクリア
- 処理内容
  - 細胞データ領域全体を0x00で上書きする

### `find_cell_data_by_tile_xy`: 指定されたタイル座標の細胞のアドレスを取得
- 引数
  | レジスタ | 内容 |
  | --- | --- |
  | D | タイル座標Y |
  | E | タイル座標X |
- 戻り値
  | レジスタ | 内容 |
  | --- | --- |
  | HL | 細胞アドレス(指定された座標に細胞が存在しない場合はNULL) |
- 処理内容
  - 細胞データ領域内で指定されたタイル座標の細胞を探し、そのアドレスを返す

### `alloc`: 細胞データ領域を確保
- 戻り値
  | レジスタ | 内容 |
  | --- | --- |
  | HL | 確保した領域のアドレス(確保できなかった場合は`NULL`) |
- 処理内容
  1. `CELL_DATA_AREA_BEGIN`から`CELL_DATA_SIZE`バイト毎に`flags`.`alive`が0の場所を探す
  2. 見つけた領域のアドレスをレジスタHLへ設定しreturn
  3. `CELL_DATA_AREA_END`まで到達しても見つからなかった場合、レジスタHLへ`NULL`を設定しreturn

### `find_free_neighbor`: 近傍の空き座標を探す
- 戻り値
  | レジスタ | 内容 |
  | --- | --- |
  | D | 見つけたY座標(見つからなかった場合は0xff) |
  | E | 見つけたX座標(見つからなかった場合は0xff) |
- 処理内容
  1. `cur_cell_addr`から現在の細胞データを参照し`tile_x`・`tile_y`を取得
  2. 現在の細胞の8近傍を左上から順に時計回りでチェック
  3. 何も配置されていない座標を見つけたら、その座標をレジスタD・Eへ設定しreturn
     - その座標に何か配置されているか否かは、0xdc00以降のタイルミラー領域をチェックすることで行う
  4. 何も配置されていない座標が見つからなかった場合は、レジスタD・Eへ共に0xffを設定しreturn

### `mutation`: 突然変異
- 引数
  | レジスタ | 内容 |
  | --- | --- |
  | HL | 対象の細胞のアドレス |
- 処理内容
  - 指定された細胞を突然変異させる
  - 今の所、`bin_data`の2バイト目(タイル番号)をランダムに変更するのみ
    - 単に0x01〜0x8b(139)(使用可能なタイル番号、139種)の間で乱数を生成するだけ

### `division`: 分裂
- 方針
  - 突然変異は`bin_data`の2バイト目(タイル番号)のみで行う
- 処理内容(通常時)
  1. 細胞データ領域を確保(`alloc`)
     - 確保できなかった場合、ここでreturnする
  2. 近傍の空き座標を探す(`find_free_neighbor`)
     - 近傍に空き座標が無かった場合、ここでreturnする
  3. 確保した領域へ細胞データを設定
     | 名前 | 設定値 |
     | --- | --- |
     | `flags` | 0x01 |
     | `tile_x`, `tile_y` | 2.で見つけた座標 |
     | `life_duration` | 親の`life_duration` |
     | `life_left` | 親の`life_duration` |
     | `fitness` | 親の`fitness` |
     | `tile_num` | 親の`tile_num` |
     | `bin_size` | 親の`bin_size` |
     | `bin_data` | 親の`bin_data` |
     | `collected_flags` | 0x00 |
  4. `mutation_probability`に応じて突然変異(突然変異のしやすさが固定の場合、そうでない場合は[適応度に応じて突然変異のしやすさが決まる](../include/binbio.sh#L46-L51))
     1. 0x00〜0xffの間の乱数を生成
     2. 生成した乱数が`mutation_probability`より小さいなら、突然変異する(`mutation`)
  5. 生まれた細胞をマップへ描画
     1. 生まれた細胞の`tile_x`,`tile_y`からVRAMアドレスを算出
     2. 算出したVRAMアドレスと細胞のタイル番号をtdqへエンキュー
     3. この時点でタイルミラー領域へも手動で反映
  6. 親細胞の`collected_flags`を0x00にする
- 処理内容(fixモード時)
  1. 現在の細胞データの以下のフィールドを以下の値で上書き
     | 名前 | 設定値 |
     | --- | --- |
     | `flags` | 0x03 |
     | `life_left` | `life_duration`の値 |
     | `collected_flags` | 0x00 |
  2. 細胞をマップへ描画
     1. `tile_x`,`tile_y`からVRAMアドレスを算出
     2. 算出したVRAMアドレスと細胞のタイル番号をtdqへエンキュー
     3. この時点でタイルミラー領域へも手動で反映

### `death`: 死
- 処理内容
  1. マップに描画されているタイルを消去
     1. 現在の細胞の`tile_x`,`tile_y`からVRAMアドレスを算出
     2. 算出したVRAMアドレスと空白タイル(`GBOS_TILE_NUM_SPC`)をtdqへエンキュー
     3. この時点でタイルミラー領域へも手動で反映
  2. 現在の細胞の`alive`フラグをクリアする

### `init`: 初期化
- 処理内容
  1. 細胞データ領域をゼロクリア(`clear_cell_data_area`)
  2. 初期細胞を生成
  3. システム変数へ初期値を設定
  4. 初期細胞をマップへ配置

### `select_next_cell`: 次の細胞を選択
- 処理内容
  1. `cur_cell_addr`以降で`flags`.`alive`がセットされている細胞を探す
     - `CELL_DATA_AREA_END`を超えてしまったら、`CELL_DATA_AREA_BEGIN`から探す
  2. 細胞が見つかった場合
     - 見つけた細胞のアドレスを`cur_cell_addr`へ設定
     - 変数`error`へ0を設定
  3. `cur_cell_addr`に戻ってきても細胞が見つからなかった場合
     - 変数`error`へ1を設定

### `do_cycle`: 1周期分の周期動作を実施
- 処理内容
  1. 代謝/運動(`metabolism_and_motion`)を実施
  2. 成長(`growth`)を実施
  3. (fixモード無効時のみ)分裂可能か(`is_dividable`)？
     - 可能なら、分裂(`division`)を実施
  4. 細胞の余命(`life_left`)をデクリメント
  5. 余命が0になったか？
     - 0になったら、死(`death`)を実施
       - (fixモード有効時のみ)分裂可能かチェック(`is_dividable`)し、可能なら分裂(`division`)する
  6. 次の細胞を選択(`select_next_cell`)
     - 変数`error`が0でなかった場合、初期化(`init`)を実施

### `event_btn_a_release`: バイナリ生物環境用のAボタンリリースイベントハンドラ
- 処理内容
  1. マウスカーソル座標をタイル座標へ変換
  2. タイル座標に対応する細胞アドレスを取得
     - タイル座標に細胞が存在しなかった場合は何もせずreturn
  3. 取得した細胞の`flags`.`fix`をトグルする

### `event_btn_b_release`: バイナリ生物環境用のBボタンリリースイベントハンドラ
- 処理内容
  1. マウスカーソル座標をタイル座標へ変換
  2. タイル座標に対応する細胞アドレスを取得
     - タイル座標に細胞が存在しなかった場合は何もせずreturn
  3. 取得した細胞に対して死を実施する(`death`)
     - 取得した細胞が現在の細胞であった場合、次の細胞の選択も実施する(`select_next_cell`)
       - 絶滅した場合、初期化を実施する(`init`)
