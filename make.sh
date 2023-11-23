#!/bin/bash

usage() {
	echo -e "Usage:\t$0 ACTION [OPTION]"
	echo
	echo 'ACTION:'
	echo -e '\tbuild [--32kb-rom] [--2mb-rom-only]'
	echo -e '\tclean'
	echo -e '\thelp'
	echo -e '\trun'
}

TARGET=daisy-os
ROM_FILE_NAME=${TARGET}.gb
RAM_FILE_NAME=${TARGET}.sav
EMU=bgb
# ROM領域のファイルシステムイメージや作業ディレクトリに使用する名前
FS_ROM_NAME=fs_rom
# build時の各種ログを保存するファイル名
BUILD_LOG_NAME=build.log

if [ $# -eq 0 ]; then
	usage >&2
	exit 1
fi

case "$1" in
'build')
	action="$1"
	if [ $# -eq 2 ]; then
		opt="$2"
	else
		# 指定がない場合のデフォルトは32KB ROM
		opt='--32kb-rom'
	fi
	;;
'clean')
	action="$1"
	;;
'help')
	usage
	exit 0
	;;
'run')
	$EMU $ROM_FILE_NAME
	exit 0
	;;
*)
	usage >&2
	exit 1
	;;
esac

# set -uex
set -ue

. include/gb.sh
. src/main.sh

print_boot_kern() {
	if [ -f boot_kern.bin ]; then
		cat boot_kern.bin
		return
	fi

	(
		# 0x0000 - 0x00ff: リスタートと割り込みのベクタテーブル (256バイト)
		gbos_vec

		# 0x0100 - 0x014f: カートリッジヘッダ (80バイト)
		gbos_const >gbos_const.o
		local offset=$(stat -c '%s' gbos_const.o)
		local offset_hex=$(echo "obase=16;${offset}" | bc)
		local bc_form="obase=16;ibase=16;${GB_ROM_FREE_BASE}+${offset_hex}"
		local entry_addr=$(echo $bc_form | bc)
		bc_form="obase=16;ibase=16;${entry_addr}+10000"
		local entry_addr_4digits=$(echo $bc_form | bc | cut -c2-5)
		if [ "$opt" = "--32kb-rom" ]; then
			gb_cart_header_no_title $entry_addr_4digits
		else
			gb_cart_header_no_title_mbc1 $entry_addr_4digits
		fi

		# 0x0150 - 0x3fff: const(文字タイルデータ, グローバル関数),
		#                  main(init関数, イベントドリブン関数) (16048バイト),
		#                  パディング
		gbos_main >gbos_main.o
		cat gbos_const.o gbos_main.o
		## 16KBのサイズにするために残りをゼロ埋め
		local num_const_bytes=$(stat -c '%s' gbos_const.o)
		local num_main_bytes=$(stat -c '%s' gbos_main.o)
		local padding=$((GB_ROM_BANK_SIZE_NOHEAD - num_const_bytes \
							 - num_main_bytes))
		dd if=/dev/zero bs=1 count=$padding 2>/dev/null
		echo "print_boot_kern: num_const_bytes=$num_const_bytes, num_main_bytes=$num_main_bytes, padding=$padding" >>$BUILD_LOG_NAME
	) >boot_kern.bin
	cat boot_kern.bin
}

print_fs_system() {
	if [ -f fs_system.img ]; then
		cat fs_system.img
		return
	fi

	(
		mkdir -p fs_system

		# retrogstudy_07_yohgami_gb_XX.img
		for img_path in $(ls files_img/retrogstudy_07_yohgami_gb_??.img); do
			n=$(echo $img_path | rev | cut -d'.' -f2 | cut -d'_' -f1 | rev)
			cp $img_path fs_system/${n}00.img
		done

		tools/make_fs fs_system fs_system.img
	) >/dev/null
	cat fs_system.img
}

print_fs_ram0_orig() {
	if [ -f fs_ram0_orig.img ]; then
		cat fs_ram0_orig.img
		return
	fi

	(
		tools/make_ram0_files.sh

		tools/make_fs fs_ram0_orig fs_ram0_orig.img
	) >/dev/null
	cat fs_ram0_orig.img
}

# ROM領域のファイルシステムの作業ディレクトリを作成し、
# ファイルシステムへ格納するファイルを配置
make_fs_rom_workdir_and_put_files() {
	# 既に作業ディレクトリが存在していたら何もせずreturn
	if [ -d $FS_ROM_NAME ]; then
		return
	fi

	# 作業ディレクトリ作成
	mkdir $FS_ROM_NAME

	# ファイルシステムへ格納するファイルを配置
	## レトロゲーム勉強会#07のスライド
	## (retrogstudy_07_yohgami_gb_XX.img)
	for img_path in $(ls files_img/retrogstudy_07_yohgami_gb_??.img); do
		n=$(echo $img_path | rev | cut -d'.' -f2 | cut -d'_' -f1 | rev)
		cp $img_path $FS_ROM_NAME/00${n}.img
	done
}

# ROM領域の16KB毎のファイルシステムイメージを生成
print_fs_rom() {
	make_fs_rom_workdir_and_put_files

	# 16KB毎のファイルシステムイメージ生成
	local FS_HEAD_SIZE=3
	local FILE_HEAD_SIZE=9
	local counter=$FS_HEAD_SIZE
	local bank_no=1	# ※ 今の実装ではバンク番号は10進数1桁以内の想定なので注意
	local sz
	## $bank_noのバンクに格納するファイルを配置するディレクトリ作成
	mkdir ${FS_ROM_NAME}_${bank_no}
	## 1ファイルずつ処理
	for f in $(ls $FS_ROM_NAME); do
		# ファイルヘッダサイズとファイルサイズの和を算出
		sz=$((FILE_HEAD_SIZE + $(stat -c '%s' $FS_ROM_NAME/$f)))

		# このファイルを加えるとバンクサイズを超えるか?
		if [ $((counter + sz)) -gt $GB_ROM_BANK_SIZE ]; then
			# バンクサイズを超える場合

			# ここまでのファイルリストでファイルシステム生成
			tools/make_fs ${FS_ROM_NAME}_${bank_no} ${FS_ROM_NAME}_${bank_no}.img

			# 32KB ROM作成時、バンク2以降は作成しないので、この時点でforループを抜ける
			if [ "$opt" = "--32kb-rom" ]; then
				break
			fi

			# 初期化
			## カウンタをゼロクリア
			counter=0
			## バンク番号をインクリメント
			bank_no=$((bank_no + 1))
			## 新しいバンク番号でディレクトリ作成
			mkdir ${FS_ROM_NAME}_${bank_no}
		fi

		# 現在のバンクのディレクトリへこのファイルをコピー
		cp $FS_ROM_NAME/$f ${FS_ROM_NAME}_${bank_no}/

		# カウンタにこのファイル分を加える
		counter=$((counter + sz))
	done
	## 32KB ROMでない場合、最後のバンクのファイルシステム生成
	if [ "$opt" != "--32kb-rom" ]; then
		tools/make_fs ${FS_ROM_NAME}_${bank_no} ${FS_ROM_NAME}_${bank_no}.img
	fi

	# 標準出力へ出力
	cat ${FS_ROM_NAME}_?.img

	# FS領域サイズを変数へ設定
	# (カートリッジROMサイズ - ブート・カーネルバンクサイズ(16KB))
	if [ "$opt" = "--32kb-rom" ]; then
		sz=$(((32 - 16) * 1024))
	else
		sz=$((((2 * 1024) - 16) * 1024))
	fi

	# カートリッジROMの残りを埋める
	## 必要なパディングサイズを算出
	for f in $(ls ${FS_ROM_NAME}_?.img); do
		sz=$((sz - (16 * 1024)))
	done
	## 標準出力へパディングを出力
	dd if=/dev/zero bs=1 count=$sz status=none
}

print_rom() {
	# 0x00 0000 - 0x00 3fff: Bank 000 (16KB)
	print_boot_kern
	# 0x00 4000 - : Bank 001 -
	print_fs_rom
}

print_fs_ram0() {
	if [ -f fs_ram0.img ]; then
		cat fs_ram0.img
		return
	fi

	tools/make_fs fs_ram0_orig fs_ram0.img ram >/dev/null
	cat fs_ram0.img
}

print_ram() {
	# 0x0000 - 0x1fff: Bank 0 (8KB)
	print_fs_ram0

	# 0x2000 - 0x7fff: Bank 1 - 3 (24KB)
	dd if=/dev/zero bs=K count=24 2>/dev/null
}

build() {
	rm -f $BUILD_LOG_NAME
	print_rom >$ROM_FILE_NAME
	if [ "$opt" = "--32kb-rom" ] || [ "$opt" = "--2mb-rom-only" ]; then
		return
	fi
	print_ram >$RAM_FILE_NAME
}

clean_boot_kern() {
	rm -f src/*.o boot_kern.bin
}

clean_files_exe() {
	# binedit.exe
	make -C files_exe/binedit clean

	# cartram_formatter.exe
	make -C files_exe/cartram_formatter clean

	# lifegame_glider.exe
	make -C files_exe/lifegame_glider clean

	# lifegame_random.exe
	make -C files_exe/lifegame_random clean

	# # sound_ch2_C4D4E4F4G4A4B4C5.exe
	# make -C files_exe/sound_ch2_C4D4E4F4G4A4B4C5 clean

	# sound_ch2_rand.exe
	make -C files_exe/sound_ch2_rand clean
}

clean_files_txt() {
	# welcome.txt
	make -C files_txt/welcome clean
}

clean_fs_system() {
	clean_files_exe
	clean_files_txt
	rm -rf fs_system.img fs_system
}

clean_fs_ram0_orig() {
	rm -rf fs_ram0_orig.img fs_ram0_orig
}

clean_fs_rom() {
	rm -rf $FS_ROM_NAME*
}

clean_rom() {
	clean_boot_kern
	clean_fs_rom
	rm -f $ROM_FILE_NAME
}

clean_fs_ram0() {
	rm -f fs_ram0.img
}

clean_ram() {
	clean_fs_ram0
	rm -f $RAM_FILE_NAME
}

clean() {
	clean_rom
	clean_ram
	rm -f $BUILD_LOG_NAME
}

$action
