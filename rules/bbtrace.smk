checkpoint bbtrace:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbtrace.py"),
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/profile/{size}/{sw}/bbtrace/stamp.txt"
    params:
        outdir = "{bench}/profile/{size}/{sw}/bbtrace",
        build = "{bench}/bin/{sw}",
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
        script_opts = "",
    resources:
        runtime = "2d",
        mem = lambda w: get_resources(w).hostmem,
    shell:
        rules.cpu2017.shell_run_bench_gem5(
            runcpu_run, script_opts="--bbtrace $outdir/bbtrace.txt.gz")

# TODO: Unify with other functions doing similar tasks. Lots of repeated code.
def get_bbtrace(w, **kwargs):
    outdir = os.path.dirname(checkpoints.bbtrace.get(**w, **kwargs).output.stamp)
    bbtrace, = expand(outdir + "/{input}/bbtrace.txt.gz", input=w.input)
    return bbtrace
