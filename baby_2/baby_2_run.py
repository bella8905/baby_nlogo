import os
import shutil
import pandas as pd

def post_process_csv( _table_in, _table_out ):
	table_tmp = _table_in + ".tmp"
	run_number_col = "[run number]"

	with open( _table_in, "r" ) as f:
		lines = f.readlines()
	
	with open( table_tmp, "w" ) as f:
		# title line starts with "run number"
		title_line_start = '"' + run_number_col + '"'
		print( title_line_start )
		found_title_line = False
		for line in lines:
			if line.startswith( title_line_start ):
				found_title_line = True
			if found_title_line:
				f.write( line )

	df = pd.read_csv( table_tmp )
	print( "before sorting" )
	print( df )
	# print( df.keys )
	sorted_df = df.sort_values(by=[run_number_col, "[step]"], ascending=True)
	print( "after sorting" )
	print(sorted_df) 

	sorted_df.to_csv( _table_out, index_label=False, index=False )
	os.remove( table_tmp )


def run_model( _headless_sh_path, _model_in, _experiment, _table_out, _repetition = 1 ):
	if not _model_in or not _experiment or not _table_out: return false

	suffix = 0
	while _repetition > 0:
		_repetition = _repetition - 1
		suffix = suffix + 1

		table_out = _table_out + "_" + str(suffix) + ".csv"
		script = _headless_sh_path + " --model " + _model_in + " --experiment " + _experiment + " --table " + table_out
		print( script ) 
		# result = os.system( script )
		#/Users/bellaq/Desktop/NetLogo\ 6.2.2/netlogo-headless.sh --model ./baby_2.nlogo --experiment "experiment_test" --table "./baby_2.csv"

		table_out_processed = _table_out + "_" + str(suffix) + "_p.csv"
		post_process_csv( table_out, table_out_processed )


def main():
	headless_sh_path = "/Users/bellaq/Desktop/NetLogo\ 6.2.2/netlogo-headless.sh"
	model_in = "./baby_2.nlogo"
	experiment = "experiment_test"
	table_out = "./baby_2"
	repetition = 1
	run_model( headless_sh_path, model_in, experiment, table_out, repetition )

	return 0


if __name__ == '__main__':
	main()

