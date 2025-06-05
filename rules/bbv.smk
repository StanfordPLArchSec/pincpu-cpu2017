checkpoint bbv_translate:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbv.py"),
        exe = "{bench}/bin/{sw}/exe",
        waypoints = lambda w: expand(
            "{bench}/profile/{size}/{group}.{sw}/waypoints/{input}/waypoints.txt",
            **w, input = get_inputs(w)),
    output:
        stamp = "{bench}/simpoints/translate/{size}/{group}/{sw}/bbv/stamp.txt"
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoints/translate/{size}/{group}/{sw}/bbv",
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
        warmup = warmup, # TODO: Make this at top of Snakemake file.
        interval = interval, # TODO: Make this at top of Snakemake file.
        waypoints = lambda w: os.path.abspath(
            expand("{bench}/profile/{size}/{group}.{sw}/waypoints", **w)[0]),
        script_opts = "",
    shell:
        rules.cpu2017.shell_run_bench_gem5(
            runcpu_run,
            script_opts=" ".join([
                r"--bbv=$outdir/bbv.txt",
                r"--bbvinfo=$outdir/bbvinfo.txt",
                r"--warmup={params.warmup}",
                r"--interval={params.interval}",
                r"--waypoints={params.waypoints}/\${{workload}}/waypoints.txt",
            ]))

checkpoint bbv_legacy:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbv.py"),
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/simpoints/legacy/{size}/{sw}/{sw}/bbv/stamp.txt"
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoints/legacy/{size}/{sw}/{sw}/bbv",
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
        warmup = warmup, # TODO: Make this at top of Snakemake file.
        interval = interval, # TODO: Make this at top of Snakemake file.
        script_opts = "",
    shell:
        rules.cpu2017.shell_run_bench_gem5(
            runcpu_run,
            script_opts=" ".join([
                r"--bbv=$outdir/bbv.txt",
                r"--bbvinfo=$outdir/bbvinfo.txt",
                r"--warmup={params.warmup}",
                r"--interval={params.interval}",
            ]))
        

checkpoint bbv_valgrind:
    input:
        exe = "{bench}/bin/{sw}/exe",
        bbvinfo = "helpers/valgrind-bbvinfo.py",
    output:
        stamp = "{bench}/simpoints/valgrind/{size}/{sw}/{sw}/bbv/stamp.txt"
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoints/valgrind/{size}/{sw}/{sw}/bbv",
        interval = interval,
        warmup = warmup,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
    shell:
        rules.cpu2017.shell_run_bench(
            runcpu_run,
            command="prlimit --stack=unlimited -- valgrind --tool=exp-bbv --log-file=$outdir/valout.txt --bb-out-file=$outdir/bbv.txt --interval-size={params.interval} 2>$outdir/stderr.txt",
        ) + " && {input.bbvinfo} --warmup={params.warmup} {params.outdir}/*/bbv.txt"

# checkpoint bbv_valgrind_info:
#     input:
#         script = "helpers/valgrind-bbvinfo.py",
#         bbv = "{bench}/simpoints/valgrind/{size}/{sw}/{sw}/bbv/{input}/bbv.txt",
#     output:
#         "{bench}/simpoints/valgrind/{size}/{sw}/{sw}/bbv/{input}/bbvinfo.txt"
#     params:
#         warmup = warmup
#     shell:
#         "{input.script} --warmup={params.warmup} < {input.bbv} > {output}"
