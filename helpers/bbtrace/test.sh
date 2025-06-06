#!/bin/bash

set -e

/usr/bin/time ./helpers/bbtrace/trace-align-fast --lochist 602.gcc_s/profile/test/main/lochist/0/lochist.txt --locmaps 602.gcc_s/profile/test/base/locmap/0/locmap.txt 602.gcc_s/profile/test/slh/locmap/0/locmap.txt 602.gcc_s/profile/test/retpoline/locmap/0/locmap.txt --bbtraces 602.gcc_s/profile/test/base/bbtrace/0/bbtrace.txt.gz 602.gcc_s/profile/test/slh/bbtrace/0/bbtrace.txt.gz 602.gcc_s/profile/test/retpoline/bbtrace/0/bbtrace.txt.gz --bbhists 602.gcc_s/profile/test/base/bbhist/0/bbhist.txt 602.gcc_s/profile/test/slh/bbhist/0/bbhist.txt 602.gcc_s/profile/test/retpoline/bbhist/0/bbhist.txt | ./helpers/bbtrace/align-compress.py | gzip > test.txt.gz
diff test.txt.gz 602.gcc_s/profile/test/main/localign/0/localign-fast.txt.gz


# /usr/bin/time  ./helpers/bbtrace/trace-align-fast --lochist 623.xalancbmk_s/profile/test/main/lochist/0/lochist.txt --locmaps 623.xalancbmk_s/profile/test/base/locmap/0/locmap.txt 623.xalancbmk_s/profile/test/slh/locmap/0/locmap.txt 623.xalancbmk_s/profile/test/retpoline/locmap/0/locmap.txt --bbtraces 623.xalancbmk_s/profile/test/{base,slh,retpoline}/bbtrace/0/bbtrace.txt.gz --bbhists 623.xalancbmk_s/profile/test/{base,slh,retpoline}/bbhist/0/bbhist.txt >/dev/null
