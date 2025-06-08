.PHONY: all

all: trace-align-fast trace-align-faster

trace-align-fast: trace-align-fast.cc tracelib.cc
	g++-15 -std=c++23 -o $@ $^ -fcoroutines -lxxhash -O2 -g -lz -lprofiler -labsl_raw_hash_set -labsl_hash -labsl_raw_logging_internal

trace-align-faster: trace-align-faster.cc
	g++-15 -std=c++23 -o $@ $^ -lxxhash -O2 -g -lz -lprofiler

trace-filter-waypoints: trace-filter-waypoints.cc
	g++-15 -std=c++23 -o $@ $^ -lxxhash -O2 -g -lz -lprofiler

trace-align-best: trace-align-best.cc
	g++ -std=c++23 -o $@ $^ -lxxhash -O3 -g -lz -lprofiler -I/usr/include -ledlib -DNDEBUG -DNASSERT

error: error.cc
	g++ -std=c++23 -o $@ $^ -O2 -g -lprofiler
