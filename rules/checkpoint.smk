checkpoint checkpoint:
    input:
        gem5 = gem5_pin_exe,
        script = gem5_pin_configs + "/pin-cpt.py",
        exe = "{bench}/bin/{sw}/exe",
        simpoints = lambda w: expand(
            "{bench}/simpoints/{type}/{size}/{group}/simpoint.{input}.json",
            **w, input=get_inputs(w)),
        waypoints = lambda w: expand(
            "{bench}/profile/{size}/{group}.{sw}/waypoints/{input}/waypoints.txt",
            **w, input=get_inputs(w)) if w.type == "translate" else [],
    output:
        stamp = "{bench}/simpoints/{type}/{size}/{group}/{sw}/cpt/stamp.txt",
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoints/{type}/{size}/{group}/{sw}/cpt",
        groupdir = lambda w: os.path.abspath(expand("{bench}/simpoints/{type}/{size}/{group}", **w)[0]),
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
        script_opts = "",
        waypoints = lambda w: os.path.abspath(expand(r"{bench}/profile/{size}/{group}.{sw}/waypoints/\${{workload}}/waypoints.txt",
                                                     **w)[0]) if w.type == "translate" else "",
    shell:
        rules.cpu2017.shell_run_bench_gem5(
            runcpu_run,
            script_opts=" ".join([
                r"--simpoints-json={params.groupdir}/simpoint.\${{workload}}.json",
                r"--waypoints={params.waypoints}",
            ]))

def get_checkpoint(w):
    cpt = os.path.dirname(checkpoints.checkpoint.get(**w).output.stamp)
    return f"{cpt}/{w.input}/cpt.{w.cptid}/m5.cpt"

def get_cptids(w):
    cpt = os.path.dirname(checkpoints.checkpoint.get(**w).output.stamp)
    cpts =  glob.glob(f"{cpt}/{w.input}/cpt.[0-9]*/m5.cpt")
    cptids = []
    for cpt in cpts:
        cptids.append(cpt.split("/")[-2].split(".")[-1])
    return cptids


