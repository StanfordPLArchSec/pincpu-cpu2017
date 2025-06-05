# TODO: Rename rule to bbhist, once we decomission the old one.
checkpoint bbhist_:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbhist.py"),
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/profile/{size}/{sw}/bbhist/stamp.txt",
    params:
        outdir = "{bench}/profile/{size}/{sw}/bbhist",
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
            runcpu_run, script_opts="--bbhist=$outdir/bbhist.txt")

def get_bbhist__(**w):
    outdir = os.path.dirname(checkpoints.bbhist_.get(**w).output.stamp)
    bbhist, = expand(outdir + "/{input}/bbhist.txt", input=w["input"])
    return bbhist

# TODO: Rename function to get_bbhist.
def get_bbhist_(w):
    return get_bbhist__(**w)
