# スライドショーの作り方

## 1. 画像を用意する
- 解像度が160 x 144 pxであること
- ファイル名に縛りは無いが、ここでは「`<識別子>_gb_[0-9][0-9].png`」というファイル名で用意したこととする

## 2. GB用の画像形式へ変換する
リポジトリ直下で以下を実行する。
```Shell
$ img_id=<識別子>
$ img_dir=/path/to/img_dir
$ i=1
$ for src_img in ${img_dir}/${img_id}_gb_??.png; do
    date
    echo "src_img=$src_img"
    tools/img22bpp $src_img files_imgs/${img_id}_gb_$(printf "%02d" $i).img
    i=$((i + 1))
  done
```

## 3. 作成した画像を取り込むようにmake.shを書き換える
シェル関数`make_fs_rom_workdir_and_put_files`内の`image_name_head`変数へ「`<識別子>`」を設定するようにする。

## 4. スライドショー機能を有効化する
include/gbos.shの`SS_ENABLE`へ`1`を設定するようにする。

## 5. ビルド、実行
リポジトリ直下で以下を実行する。
```Shell
$ ./make.sh clean && ./make.sh build --2mb-rom-only && ./make.sh run
````
