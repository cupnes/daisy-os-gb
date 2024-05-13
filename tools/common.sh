# スクリプト生成に際して何度も使用する定数と処理をまとめる

# タブ文字
TAB="$(printf '\\\011')"

# 引数で指定された関数の直前の関数名を出力
# - 第1引数: 関数名
#   - 接頭辞の"f_"は除いて指定する
#   - 例) binbio_cell_eval
print_before_func_name() {
	local func_name=$1

	awk "
	  /^a_$func_name=.\(four_digits .fadr\)\$/ {
	    print prev_line
	    exit
	  }
	  /^a_[a-z_]+=.\(four_digits .fadr\)\$/ {
	    prev_line = \$0
	  }
	" src/main.sh | sed -r 's/^a_([a-z_]+)=.\(four_digits .fadr\)$/\1/'
}
