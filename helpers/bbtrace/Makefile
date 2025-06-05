
trace-align-fast: trace-align-fast.cc tracelib.cc
	g++-15 -std=c++23 -o $@ $^ -fcoroutines -lxxhash -O2 -g -lz -lprofiler -labsl_raw_hash_set -labsl_hash -labsl_raw_logging_internal
