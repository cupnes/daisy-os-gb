# スライドショーについて
## スライドショーの作り方

### 1. 画像を用意する
- 解像度が160 x 144 pxであること
- 後続の手順の都合上、画像はリポジトリ直下の`files_img`ディレクトリに「`<識別子>_gb_[0-9][0-9].png`」というファイル名で用意すること

### 2. GB用の画像形式へ変換する

リポジトリ直下で以下を実行する。
```Shell
$ img_id=<識別子>
$ cd files_img
$ for src_img in ${img_id}_gb_??.png; do
    date
    name=$(echo $src_img | cut -d'.' -f1)
    dst_img="${name}.img"
    echo "converting $src_img to $dst_img"
    ../tools/conv_img $src_img $dst_img
  done
```

### 3. 作成した画像を取り込むようにmake.shを書き換える
シェル関数`make_fs_rom_workdir_and_put_files`内の`image_name_head`変数へ「`<識別子>`」を設定するようにする。

### 4. 最後のスライドのバンク・ファイル番号の更新とスライドショー機能の有効化を行う
include/gbos.shの`SS_LAST_BANK_FILE_NUM`を更新し、`SS_ENABLE`へ`1`を設定するようにする。`SS_LAST_BANK_FILE_NUM`の設定については[build.md](build.md)を参照。

### 5. ビルド、実行
リポジトリ直下で以下を実行する。
```Shell
$ ./make.sh clean && ./make.sh build --2mb-rom-32kb-ram && ./make.sh run
````

## 実装について
スライドショーの処理はsrc/main.sh内で各所に分散して実装されている。

### f_binbio_event_btn_right_release()
- 画像表示状態 != 画像表示中 の場合：
  1. 特に何もしない
- そうではない場合：
  1. 次のスライドを指定して`f_view_img()`呼び出し

### f_binbio_event_btn_left_release()
- 画像表示状態 != 画像表示中 の場合：
  1. 特に何もしない
- そうではない場合：
  1. 前のスライドを指定して`f_view_img()`呼び出し

### f_binbio_event_btn_start_release()
- 画像表示状態 == 画像表示なし の場合：
  1. 現在のスライドのバンク・ファイル番号を変数から取得
  2. `f_view_img()`呼び出し
- 画像表示状態 == tdq消費待ち の場合：
  1. 特に何もしない
- 画像表示状態 == 画像表示中 の場合：
  1. `f_quit_img()`呼び出し

### event_driven()
- 画像表示状態 == 画像表示なし の場合：
  1. バイナリ生物周期処理を実施
- 画像表示状態 == tdq消費待ち の場合：
  1. 現在のスライドのバンク・ファイル番号を変数から取得
  2. `f_view_img()`呼び出し

## 画像表示状態の状態遷移
画像表示状態はinclude/vars.shの`var_view_img_state`変数で管理される。

各状態を表す定数はinclude/gbos.shに定義されていて、各定数と状態遷移については以下の通り。

- 画像表示なし($GBOS_VIEW_IMG_STAT_NONE)
  - f_view_img() 呼び出しにより、この関数内で以下のように遷移する
    - tdqが空でない場合：
      - tdq消費待ち($GBOS_VIEW_IMG_STAT_WAIT_FOR_TDQEMP)へ遷移
    - tdqが空の場合：
      - 画像表示中($GBOS_VIEW_IMG_STAT_DURING_IMG_DISP)へ遷移
- 画像表示中($GBOS_VIEW_IMG_STAT_DURING_IMG_DISP)
  - f_quit_img() 呼び出しにより、この関数内で以下のように遷移する
    - 画像表示なし($GBOS_VIEW_IMG_STAT_NONE)へ遷移
