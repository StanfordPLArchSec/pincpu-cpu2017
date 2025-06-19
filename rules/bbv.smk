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
    resources:
        runtime = "2d",
        mem = lambda w: get_resources(w).hostmem,
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
        stamp = "{bench}/simpoints/legacy/{size}/{group}/{sw}/bbv/stamp.txt"
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoints/legacy/{size}/{group}/{sw}/bbv",
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
        warmup = warmup, # TODO: Make this at top of Snakemake file.
        interval = interval, # TODO: Make this at top of Snakemake file.
        script_opts = "",
    resources:
        runtime = "2d",
        mem = lambda w: get_resources(w).hostmem,
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
        stamp = "{bench}/simpoints/valgrind/{size}/{group}/{sw}/bbv/stamp.txt"
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoints/valgrind/{size}/{group}/{sw}/bbv",
        interval = interval,
        warmup = warmup,
        stack = lambda w: humanfriendly.parse_size(get_resources(w).stack),
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
    shell:
        rules.cpu2017.shell_run_bench(
            runcpu_run,
            command="prlimit --stack=unlimited -- valgrind --tool=exp-bbv --main-stacksize={params.stack} --log-file=$outdir/valout.txt --bb-out-file=$outdir/bbv.txt --interval-size={params.interval} 2>$outdir/stderr.txt",
        ) + " && {input.bbvinfo} --warmup={params.warmup} {params.outdir}/*/bbv.txt"

checkpoint_bbv_lut = {
    "valgrind": checkpoints.bbv_valgrind,
    "legacy": checkpoints.bbv_legacy,
    "translate": checkpoints.bbv_translate,
}

def get_bbv_shared(w, path, **kwargs):
    outdir = os.path.dirname(checkpoint_bbv_lut[w.type].get(**w, **kwargs).output.stamp)
    bbv, = expand(outdir + "/{input}/" + path, input=w.input)
    return bbv

def get_bbv(w, **kwargs):
    return get_bbv_shared(w, "bbv.txt", **kwargs)

def get_bbvinfo(w, **kwargs):
    return get_bbv_shared(w, "bbvinfo.txt", **kwargs)
    
