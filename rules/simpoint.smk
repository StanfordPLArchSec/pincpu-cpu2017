checkpoint simpoint_legacy_bbv:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbv.py"),
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/simpoint-legacy/{size}/{sw}/bbv/stamp.txt",
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoint-legacy/{size}/{sw}/bbv",
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
        warmup   = 10000000,
        interval = 50000000,
    resources:
        runtime = "2d",
        mem = lambda w: get_resources(w).hostmem,
    shell:
        'rm -rf {params.outdir} && '
        r'outdir="$PWD/{params.outdir}/\${{workload}}" && '
        'cd cpu2017 && source shrc && cd .. && '
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py --stdout=$outdir/stdout.txt -- /usr/bin/time -vo $outdir/time.txt -- prlimit --as={params.hostmem} -- {input.gem5} -re --silent-redirect --outdir=$outdir --debug-flag=Heartbeat --debug-file=dbgout.txt {input.script} --output=stdout.txt --errout=stderr.txt --max-stack-size={params.stack} --mem-size={params.sim_mem} --bbv=$outdir/bbv.txt --bbvinfo=$outdir/bbvinfo.txt --warmup={params.warmup} --interval={params.interval} -- \${{command}}" && '
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && '
        + runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} && '
        'touch {output.stamp}'

def simpoint_legacy_bbv_dir(w):
    return os.path.dirname(checkpoints.simpoint_legacy_bbv.get(**w).output.stamp)

def simpoint_legacy_bbv_input(w):
    dir = simpoint_legacy_bbv_dir(w)
    path = os.path.join(dir, "{input}")
    expanded_path, = expand(path, **w)
    return expanded_path

def simpoint_legacy_bbv_file(w, name):
    dir = simpoint_legacy_bbv_input(w)
    return os.path.join(dir, name)
        
rule simpoint_legacy_simpoint:
    input:
        bbv = lambda w: simpoint_legacy_bbv_file(w, "bbv.txt"),
        exe = simpoint_exe,
    output:
        intervals = "{bench}/simpoint-legacy/{size}/{sw}/simpoint/{input}/intervals.txt",
        weights = "{bench}/simpoint-legacy/{size}/{sw}/simpoint/{input}/weights.txt",
    params:
        outdir = "{bench}/simpoint-legacy/{size}/{sw}/simpoint/{input}",
        num_simpoints = num_simpoints,
    shell:
        "rm -rf {params.outdir} && mkdir -p {params.outdir} && "
        "{input.exe} -loadFVFile {input.bbv} -maxK {params.num_simpoints} -saveSimpoints {output.intervals} -saveSimpointWeights {output.weights} -fixedLength off "
        "> {params.outdir}/stdout 2> {params.outdir}/stderr"

rule simpoint_legacy_simpoint_json:
    input:
        intervals = "{bench}/simpoint-legacy/{size}/{sw}/simpoint/{input}/intervals.txt",
        weights = "{bench}/simpoint-legacy/{size}/{sw}/simpoint/{input}/weights.txt",
        bbvinfo = "{bench}/simpoint-legacy/{size}/{sw}/bbv/{input}/bbvinfo.txt",
        exe = "helpers/simpoints.py",
    output:
        "{bench}/simpoint-legacy/{size}/{sw}/simpoint/{input}/simpoints.json"
    shell:
        "{input.exe} --intervals={input.intervals} --weights={input.weights} --bbvinfo={input.bbvinfo} > {output}"

# TODO: Better way to do this.
def simpoint_legacy_checkpoint_get_simpoints_json(w):
    bbv_dir = simpoint_legacy_bbv_dir(w)
    bbvs = glob.glob(bbv_dir + "/*/bbv.txt")
    simpoints = []
    for bbv in bbvs:
        tokens = bbv.split("/")
        tokens[-1] = "simpoints.json"
        tokens[-3] = "simpoint"
        simpoints.append("/".join(tokens))
    return simpoints
        
rule simpoint_legacy_checkpoint:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-cpt.py"),
        exe = "{bench}/bin/{sw}/exe",
        simpoints = simpoint_legacy_checkpoint_get_simpoints_json,
    output:
        stamp = "{bench}/simpoint-legacy/{size}/{sw}/cpt/stamp.txt",
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoint-legacy/{size}/{sw}/cpt",
        simpoints = r"{bench}/simpoint-legacy/{size}/{sw}/simpoint",
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
    resources:
        runtime = "2d",
        mem = lambda w: get_resources(w).hostmem,
    shell:
        'rm -rf {params.outdir} && mkdir -p {params.outdir} && '
        r'outdir="$PWD/{params.outdir}/\${{workload}}" && '
        'cd cpu2017 && source shrc && cd .. && '
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py --stdout=$outdir/stdout.txt -- /usr/bin/time -vo $outdir/time.txt -- prlimit --as={params.hostmem} -- {input.gem5} -re --silent-redirect --outdir=$outdir --debug-flag=Heartbeat --debug-file=dbgout.txt {input.script} --output=stdout.txt --errout=stderr.txt --max-stack-size={params.stack} --mem-size={params.sim_mem} --simpoints-json=$PWD/{params.simpoints}/\${{workload}}/simpoints.json -- \${{command}}" && '
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && '
        + runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} && '
        'touch {output.stamp}'
