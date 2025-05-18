# TODO: Rename with prefix?
checkpoint bbhist:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbhist.py"),
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/simpoint-translation/{size}/{sw}/{sw}/bbhist/stamp.txt"
    params:
        outdir = "{bench}/simpoint-translation/{size}/{sw}/{sw}/bbhist",
        build = "{bench}/bin/{sw}",
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
    resources:
        runtime = "2d",
        mem = lambda w: get_resources(w).hostmem,
    shell:
        'rm -rf {params.outdir} && '
        r'outdir="$PWD/{params.outdir}/\${{workload}}" && '
        'cd cpu2017 && source shrc && cd .. && '
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py --stdout=$outdir/stdout.txt -- /usr/bin/time -vo $outdir/time.txt -- prlimit --as={params.hostmem} -- {input.gem5} -re --silent-redirect --outdir=$outdir --debug-flag=Heartbeat --debug-file=dbgout.txt {input.script} --output=stdout.txt --errout=stderr.txt --max-stack-size={params.stack} --mem-size={params.sim_mem} --bbhist=$outdir/bbhist.txt -- \${{command}}" && '
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && '
        + runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} && '
        'touch {output.stamp}'

# TODO: Rename.
def get_bbhist(wildcards):
    outdir = os.path.dirname(checkpoints.bbhist.get(**wildcards).output.stamp)
    print("get_bbhist: " + outdir)
    bbhist = expand(f"{outdir}/{{input}}/bbhist.txt", **wildcards)
    return bbhist

# TODO: Rename.
def get_inputs(wildcards):
    outdir = os.path.dirname(checkpoints.bbhist.get(**wildcards).output.stamp)
    bbhists = glob.glob(f"{outdir}/*/bbhist.txt")
    inputs = []
    print("get_inputs: " + outdir)
    for bbhist in bbhists:
        inputs.append(os.path.basename(os.path.dirname(bbhist)))
    return inputs

# TODO: For release, can combine these all into one step.
rule instlist:
    input:
        bbhist = get_bbhist,
        script = "helpers/instlist.py",
    output:
        "{bench}/simpoint-translation/{size}/{sw}/{sw}/instlist.{input}.txt"
    shell:
        "{input.script} < {input.bbhist} > {output}"

rule srclist:
    input:
        exe = "{bench}/bin/{sw}/exe",
        instlist = "{bench}/simpoint-translation/{size}/{sw}/{sw}/instlist.{input}.txt",
    output:
        "{bench}/simpoint-translation/{size}/{sw}/{sw}/srclist.{input}.txt",
    shell:
        addr2line + " --exe {input.exe} --output-style=JSON < {input.instlist} > {output}"

rule srclocs:
    input:
        srclist = "{bench}/simpoint-translation/{size}/{sw}/{sw}/srclist.{input}.txt",
        script = "helpers/srclocs.py",
    output:
        "{bench}/simpoint-translation/{size}/{sw}/{sw}/srclocs.{input}.txt",
    shell:
        "{input.script} --basename < {input.srclist} > {output}"

rule lehist:
    input:
        bbhist = get_bbhist,
        srclocs = "{bench}/simpoint-translation/{size}/{sw}/{sw}/srclocs.{input}.txt",
        script = "helpers/lehist.py",
    output:
        "{bench}/simpoint-translation/{size}/{sw}/{sw}/lehist.{input}.txt"
    shell:
        "{input.script} --bbhist={input.bbhist} --srclocs={input.srclocs} > {output}"

rule shlocedges:
    input:
        lehists = lambda w: \
            expand("{bench}/simpoint-translation/{size}/{sw}/{sw}/lehist.{input}.txt",
                   **w, sw = list_group(w.group)),
        script = "helpers/shlocedges.py",
    output:
        "{bench}/simpoint-translation/{size}/{group}/shlocedges.{input}.txt"
    shell:
        "mkdir -p $(dirname {output}) && "
        "{input.script} {input.lehists} > {output}"

rule instwaypts:
    input:
        bbhist = "{bench}/simpoint-translation/{size}/{sw}/{sw}/bbhist/{input}/bbhist.txt",
        srclocs = "{bench}/simpoint-translation/{size}/{sw}/{sw}/srclocs.{input}.txt",
        shlocedges = "{bench}/simpoint-translation/{size}/{group}/shlocedges.{input}.txt",
        script = "helpers/instwaypts.py",
    output:
        "{bench}/simpoint-translation/{size}/{group}/{sw}/instwaypts.{input}.txt"
    shell:
        "{input.script} --bbhist={input.bbhist} --srclocs={input.srclocs} --shlocedges={input.shlocedges} > {output}"

checkpoint simpoint_translation_bbv:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbv.py"),
        exe = "{bench}/bin/{sw}/exe",
        instwaypts = lambda w: \
            expand("{bench}/simpoint-translation/{size}/{group}/{sw}/instwaypts.{input}.txt", **w, input = get_inputs(w))
    output:
        stamp = "{bench}/simpoint-translation/{size}/{group}/{sw}/bbv/stamp.txt"
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoint-translation/{size}/{group}/{sw}/bbv",
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
        warmup   = 10000000,
        interval = 50000000,
        groupdir = "{bench}/simpoint-translation/{size}/{group}/{sw}",
    shell:
        # TODO: Refactor with duplicate code?
        'rm -rf {params.outdir} && '
        r'outdir="$PWD/{params.outdir}/\${{workload}}" && '
        'cd cpu2017 && source shrc && cd .. && '
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py --stdout=$outdir/stdout.txt -- /usr/bin/time -vo $outdir/time.txt -- prlimit --as={params.hostmem} -- {input.gem5} -re --silent-redirect --outdir=$outdir --debug-flag=Heartbeat --debug-file=dbgout.txt {input.script} --output=stdout.txt --errout=stderr.txt --max-stack-size={params.stack} --mem-size={params.sim_mem} --bbv=$outdir/bbv.txt --bbvinfo=$outdir/bbvinfo.txt --warmup={params.warmup} --interval={params.interval} --waypoints=$PWD/{params.groupdir}/instwaypts.\${{workload}}.txt -- \${{command}}" && '
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && '
        + runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} && '
        'touch {output.stamp}'

def simpoint_translation_bbv_dir(w):
    return os.path.dirname(checkpoints.simpoint_translation_bbv.get(**w).output.stamp)

def simpoint_translation_bbv_file(w, name):
    dir = simpoint_translation_bbv_dir(w)
    return expand(os.path.join(dir, "{input}", name), **w)

def simpoint_translation_simpoint_file(group, name):
    return "{bench}/simpoint-translation/{size}/{group}/" + list_group(group)[0] + "/simpoint/{input}/" + name

rule simpoint_translation_simpoint:
    input:
        bbv = lambda w: simpoint_legacy_bbv_file(w, "bbv.txt"),
        exe = simpoint_exe,
    output:
        intervals = "{bench}/simpoint-translation/{size}/{group}/{sw}/simpoint/{input}/intervals.txt",
        weights   = "{bench}/simpoint-translation/{size}/{group}/{sw}/simpoint/{input}/weights.txt",
    params:
        outdir = lambda w: "{bench}/simpoint-translation/{size}/{group}/{sw}/simpoint/{input}",
        num_simpoints = num_simpoints,
    shell:
        "rm -rf {params.outdir} && mkdir -p {params.outdir} && "
        "{input.exe} -loadFVFile {input.bbv} -maxK {params.num_simpoints} -saveSimpoints {output.intervals} -saveSimpointWeights {output.weights} -fixedLength off "
        "> {params.outdir}/stdout 2> {params.outdir}/stderr"

rule simpoint_translation_simpoint_json:
    input:
        intervals = lambda w: \
            expand("{bench}/simpoint-translation/{size}/{group}/{sw}/simpoint/{input}/intervals.txt", **w, sw = list_group(w.group)[0]),
        weights = lambda w: \
            expand("{bench}/simpoint-translation/{size}/{group}/{sw}/simpoint/{input}/intervals.txt", **w, sw = list_group(w.group)[0]),
        bbvinfo = lambda w: simpoint_translation_bbv_file({**dict(w), "sw": list_group(w.group)[0]}, "bbvinfo.txt"),
        exe = "helpers/simpoints.py",
    output:
        "{bench}/simpoint-translation/{size}/{group}/simpoint.{input}.json"
    shell:
        "{input.exe} --intervals={input.intervals} --weights={input.weights} --bbvinfo={input.bbvinfo} > {output}"
