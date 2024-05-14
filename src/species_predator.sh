# 生物種「捕食者」用のスクリプト

# [定数]

# 適応度
SPECIES_PREDATOR_FITNESS=7f



# [関数]

# 捕食者用評価関数
# 定義された固定値を適応度として返す
# out: regA - 評価結果の適応度(0x00〜0xff)
f_binbio_cell_eval_predator() {
	# 戻り値としてregAへ固定値を設定
	lr35902_set_reg regA $SPECIES_PREDATOR_FITNESS

	# return
	lr35902_return
}

# 捕食者用成長関数
f_binbio_cell_growth_predator() {
	# push
	## TODO

	# TODO

	# pop & return
	## TODO
	lr35902_return
}

# 捕食者用突然変異関数
f_binbio_cell_mutation_predator() {
	# push
	## TODO

	# TODO

	# pop & return
	## TODO
	lr35902_return
}
