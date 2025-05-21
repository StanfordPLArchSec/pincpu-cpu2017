chunk_interval = 2000000000
chunk_warmup   =  500000000

checkpoint chunk:
    input:
        gem5 = lambda w: os.path.abspath("../gem5/pincpu/build/X86/gem5.opt"),
        script = lambda w: os.path.abspath("../gem5/pincpu/configs/pin-chunk.py"),
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/chunk/{size}/{sw}/cpt/stamp.txt",
    params:
        # TODO: This should be unified, get_script_opts(w).
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/chunk/{size}/{sw}/cpt",
        script_opts = f"--interval={chunk_interval} --warmup={chunk_warmup}", # TODO: Remove.
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
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py --stdout=$outdir/stdout.txt -- /usr/bin/time -vo $outdir/time.txt -- prlimit --as={params.hostmem} -- {input.gem5} -re --silent-redirect --outdir=$outdir --debug-flag=Heartbeat --debug-file=dbgout.txt {input.script} --output=stdout.txt --errout=stderr.txt --max-stack-size={params.stack} --mem-size={params.sim_mem} {params.script_opts} -- \${{command}}" && '
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && '
        + runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} && '
        'touch {output.stamp}'

# TODO: Qualify name with 'chunk'.
def get_checkpoint_dir(wildcards):
    chunk_output = checkpoints.chunk.get(**wildcards).output
    return os.path.dirname(chunk_output.stamp)

# TODO: Qualify name with 'chunk'.
def get_checkpoint(wildcards):
    outdir = get_checkpoint_dir(wildcards)
    return expand("{outdir}/{input}/cpt.{cptid}/m5.cpt",
                  outdir = outdir,
                  **wildcards)

# TODO: Qualify name with 'chunk'.
def get_checkpoints(wildcards):
    outdir = get_checkpoint_dir(wildcards)
    paths = glob.glob(f"{outdir}/*/cpt.*/m5.cpt")
    res = []
    for path in paths:
        cptname = path.split("/")[-2]
        if re.match(r"cpt.\d+", cptname):
            res.append(path)
    return res

rule chunk_manifest:
    input: "{bench}/chunk/{size}/{sw}/cpt/stamp.txt"
    output: "{bench}/chunk/{size}/{sw}/cpt/manifest.txt"
    run:
        chunks = []
        for cptdir in glob.glob(f"{os.path.dirname(input[0])}/*/cpt.[0-9]*"):
            workload, cptname = cptdir.split("/")[-2:]
            workload = int(workload)
            cptid = int(cptname.split(".")[1])
            chunks.append((workload, cptid))
        with open(output[0], "wt") as f:
            for workload, cptid in chunks:
                print(workload, cptid, file=f)

rule chunk_run:
    input:
        gem5 = lambda w: get_gem5(w) + "/build/X86/gem5.opt",
        script = lambda w: get_gem5(w) + "/configs/deprecated/example/se.py",
        exe = "{bench}/bin/{sw}/exe",
        cpt = get_checkpoint,
    output:
        stamp = "{bench}/chunk/{size}/{sw}/exp/{hwconf}/{input}/{cptid}/stamp.txt",
    params:
        # TODO: This should be unified, get_script_opts(w).
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/chunk/{size}/{sw}/exp/{hwconf}/{input}/{cptid}",
        cptdir = "{bench}/chunk/{size}/{sw}/cpt/{input}",
        script_opts = lambda w: hwconfs[w.hwconf].script_opts,
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
    resources:
        runtime = "1d",
        mem = lambda w: get_resources(w).hostmem,
    shell:
        'rm -rf {params.outdir} && '
        'mkdir -p {params.outdir} && '
        '/usr/bin/time -vo {params.outdir}/time.txt -- {input.gem5} -re --silent-redirect --outdir={params.outdir} --debug-flag=Heartbeat --debug-file=dbgout.txt '
        '{input.script} --output=stdout.txt --errout=stderr.txt --cpu-type=X86O3CPU --caches --max-stack-size={params.stack} --mem-size={params.sim_mem} '
        '--checkpoint-dir={params.cptdir} '
        '--checkpoint-restore=$(({wildcards.cptid}+1)) '
        '--restore-simpoint-checkpoint '
        '{params.script_opts} '
        '-- {input.exe} '
        '&& touch {output.stamp} '

def chunk_run_all_input(w):
    out = []
    for path in get_checkpoints(w):
        input, cptdir = path.split("/")[-3:-1]
        cptid = cptdir.split(".")[-1]
        if input == w.input:
            out.extend(
                expand("{bench}/chunk/{size}/{sw}/exp/{hwconf}/{input}/{cptid}/stamp.txt",
                       cptid = cptid, **w))
    return out
        
rule chunk_run_all_input:
    input: chunk_run_all_input
    output: "{bench}/chunk/{size}/{sw}/exp/{hwconf}/{input}/all"

def chunk_run_all_inputs(w):
    out = []
    for path in get_checkpoints(w):
        input, cptdir = path.split("/")[-3:-1]
        cptid = cptdir.split(".")[-1]
        out.extend(expand("{bench}/chunk/{size}/{sw}/exp/{hwconf}/{input}/{cptid}/stamp.txt",
                          input = input,
                          cptid = cptid,
                          **w))
    return out
        
rule chunk_run_all:
    input: chunk_run_all_inputs
    output: "{bench}/chunk/{size}/{sw}/exp/{hwconf}/all"
