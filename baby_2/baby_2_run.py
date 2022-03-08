import os
import shutil

def post_process_csv( _table_in, _table_out ):
	if _table_in == _table_out:
		table_tmp = _table_in + ".tmp"
		shutil.copyfile( _table_in, table_tmp)
		_table_in = table_tmp


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

		post_process_csv( table_out, table_out )


def main():
	headless_sh_path = "/Users/bellaq/Desktop/NetLogo\ 6.2.2/netlogo-headless.sh"
	model_in = "./baby_2.nlogo"
	experiment = "experiment_test"
	table_out = "./baby_2"
	repetition = 5
	run_model( headless_sh_path, model_in, experiment, table_out, repetition )

	return 0


if __name__ == '__main__':
	main()

