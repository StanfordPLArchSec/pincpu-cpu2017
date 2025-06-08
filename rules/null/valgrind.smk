rule null_valgrind:
    input:
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/null/{size}/{sw}/valgrind/stamp.txt",
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/null/{size}/{sw}/valgrind",
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem)
    shell:
        rules.cpu2017.shell_run_bench(
            runcpu_run,
            command="prlimit --stack=unlimited -- valgrind --tool=none --log-file=$outdir/valout.txt 2>$outdir/stderr.txt",
        )
