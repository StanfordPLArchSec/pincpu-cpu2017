import os
import sys
import glob
import types
import humanfriendly

container: "../docker/pincpu.sif"

gem5_pin_src = os.path.abspath("../gem5/pincpu")
gem5_pin_exe = gem5_pin_src + "/build/X86/gem5.opt"
gem5_pin_configs = gem5_pin_src + "/configs"
cpu2017 = os.path.abspath("cpu2017")
addr2line = "../llvm/build/bin/llvm-addr2line"
runcpu = os.path.abspath("myruncpu")

wildcard_constraints:
    bench = r"6[0-9][0-9]\.[0-9a-zA-Z]+_s",
    input = r"[0-9]",
    sw = "[a-z]+",
    group = "[a-z]+",
    size = "(test|train|ref)",

compilers = ["base", "slh"]
groups = {
    "main": ["base", "slh"],
}
    
def list_group(name):
    if name in compilers:
        return name
    else:
        return groups[name]

hwconfs = {
    "unsafe": types.SimpleNamespace(
        sim = "base",
        script_opts = [],
    ),
    "stt": types.SimpleNamespace(
        sim = "stt",
        script_opts = ["--implicit-channel=Lazy", "--speculation-model=CondCtrl"],
    ),
}

resources_train = {
    "631.deepsjeng_s": {
        "mem": "8GiB",
        "hostmem": "16GiB",
    },
    "657.xz_s": {
        "mem": "2GiB",
    },
    "603.bwaves_s": {
        "mem": "1GiB",
        "stack": "1GiB",
    },
    "619.lbm_s": {
        "mem": "4GiB",
        "hostmem": "8GiB",
    },
    "621.wrf_s": {
        "stack": "1GiB",
    },
    "627.cam4_s": {
        "mem": "2GiB",
        "stack": "1GiB",
    },
}

resources = {
    "train": resources_train,
}

def get_resources(w):
    default_resource = {
        "mem": "1GiB",
        "stack": "8MiB",
        "hostmem": "4GiB",
    }
    resource = resources[w.size].get(w.bench, default_resource)
    for key, default_value in default_resource.items():
        if key not in resource:
            resource[key] = default_value
    return types.SimpleNamespace(**resource)

# FIXME: The exe is actually at CPU/{bench}/build/{benchname}_s.
def get_exe(w):
    special = {
        "603.bwaves_s": "speed_bwaves_base.base-m64",
        "602.gcc_s": "sgcc_base.base-m64",
        "654.roms_s": "sroms_base.base-m64",
    }
    path = "{bench}/bin/{sw}/benchspec/CPU/{bench}/exe/"
    if w.bench in special:
        path += special[w.bench]
    else:
        benchname = w.bench.split(".")[-1]
        path += benchname + "_base.base-m64"
    exe, = expand(path, **w)
    return os.path.abspath(exe)

# TODO: Consider making this a plain rule again.
checkpoint build_cpu2017_bench:
    output:
        exe = "{bench}/bin/{sw}/exe",
    params:
        cpu2017 = cpu2017,
        exe = get_exe,
        build = "{bench}/bin/{sw}",
    threads: 8
    shell:
        # TODO: Might be able to use monitor_specrun_wrapper?
        "pushd {params.cpu2017} >/dev/null && source shrc && popd >/dev/null && "
        "runcpu --config=pincpu-{wildcards.sw} --tune=base --action=build --output_root=$PWD/{params.build} {wildcards.bench} && "
        "[ -f {params.exe} ] && [ -x {params.exe} ] && ln -sf {params.exe} {output.exe}"
        
checkpoint bbhist:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbhist.py"),
        exe = "{bench}/bin/{sw}/exe",
    output:
        # FIXME: This is not resilient to crashes.
        directory("{bench}/cpt/{size}/{sw}/{sw}/bbhist"),
    params:
        # TODO: inline.
        workload = lambda w: r"\${workload}",
        build = "{bench}/bin/{sw}",
    shell:
        'rm -rf {output} && '
        'wrap="$PWD/wrap.py" && '
        r'outdir="$PWD/{output}/{params.workload}" && '
        r'monitor_wrapper="$wrap --stdout=$outdir/stdout.txt -- {input.gem5} -re --silent-redirect --outdir=$outdir {input.script} --bbhist=$outdir/bbhist.txt -- \${{command}}" && '
        'runcpu --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" {wildcards.bench}'

def get_bbhist(wildcards):
    outdir = checkpoints.bbhist.get(**wildcards).output
    bbhist = expand(f"{outdir}/{{input}}/bbhist.txt", **wildcards)
    return bbhist

def get_inputs(wildcards):
    outdir = checkpoints.bbhist.get(**wildcards).output
    bbhists = glob.glob(f"{outdir}/*/bbhist.txt")
    inputs = []
    for bbhist in bbhists:
        inputs.append(os.path.basename(os.path.dirname(bbhist)))
    return inputs

# TODO: For release, can combine these all into one step.
rule instlist:
    input:
        bbhist = get_bbhist,
        script = "helpers/instlist.py",
    output:
        "{bench}/cpt/{size}/{sw}/{sw}/instlist.{input}.txt"
    shell:
        "{input.script} < {input.bbhist} > {output}"

rule srclist:
    input:
        exe = "{bench}/bin/{sw}/exe",
        instlist = "{bench}/cpt/{size}/{sw}/{sw}/instlist.{input}.txt",
    output:
        "{bench}/cpt/{size}/{sw}/{sw}/srclist.{input}.txt",
    shell:
        addr2line + " --exe {input.exe} --output-style=JSON < {input.instlist} > {output}"

rule srclocs:
    input:
        srclist = "{bench}/cpt/{size}/{sw}/{sw}/srclist.{input}.txt",
        script = "helpers/srclocs.py",
    output:
        "{bench}/cpt/{size}/{sw}/{sw}/srclocs.{input}.txt",
    shell:
        "{input.script} --basename < {input.srclist} > {output}"

rule lehist:
    input:
        bbhist = get_bbhist,
        srclocs = "{bench}/cpt/{size}/{sw}/{sw}/srclocs.{input}.txt",
        script = "helpers/lehist.py",
    output:
        "{bench}/cpt/{size}/{sw}/{sw}/lehist.{input}.txt"
    shell:
        "{input.script} --bbhist={input.bbhist} --srclocs={input.srclocs} > {output}"

rule shlocedges:
    input:
        lehists = lambda w: \
            expand("{bench}/cpt/{size}/{sw}/{sw}/lehist.{input}.txt",
                   **w, sw = list_group(w.group)),
        script = "helpers/shlocedges.py",
    output:
        "{bench}/cpt/{size}/{group}/shlocedges.{input}.txt"
    shell:
        "mkdir -p $(dirname {output}) && "
        "{input.script} {input.lehists} > {output}"

rule instwaypts:
    input:
        bbhist = "{bench}/cpt/{size}/{sw}/{sw}/bbhist/{input}/bbhist.txt",
        srclocs = "{bench}/cpt/{size}/{sw}/{sw}/srclocs.{input}.txt",
        shlocedges = "{bench}/cpt/{size}/{group}/shlocedges.{input}.txt",
        script = "helpers/instwaypts.py",
    output:
        "{bench}/cpt/{size}/{group}/{sw}/instwaypts.{input}.txt"
    shell:
        "{input.script} --bbhist={input.bbhist} --srclocs={input.srclocs} --shlocedges={input.shlocedges} > {output}"

rule bbv:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbv.py"),
        exe = "{bench}/bin/{sw}/exe",
        instwaypts = lambda w: \
            expand("{bench}/cpt/{size}/{group}/{sw}/instwaypts.{input}.txt", **w, input = get_inputs(w))
    output:
        directory("{bench}/cpt/{size}/{sw}/{sw}/bbv")
    params:
        build = "{bench}/bin/{sw}",        
    shell:
        # TODO: Refactor with bbhist.
        'rm -rf {output} && '
        'wrap="$PWD/wrap.py" && '
        r'outdir="$PWD/{output}/\${{workload}}" && '
        r'monitor_wrapper="$wrap --stdout=$outdir/stdout.txt -- {input.gem5} -re --silent-redirect --outdir=$outdir {input.script} --bbv=$outdir/bbv.txt --bbvinfo=$outdir/bbvinfo.txt --warmup={params.warmup} --interval={params.interval} --waypoints={input.instwaypts} -- \${{command}}" && '
        'runcpu --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" {wildcards.bench}'

def get_gem5(w):
    gem5, = expand("../gem5/{sim}", sim = hwconfs[w.hwconf].sim)
    return os.path.abspath(gem5)

rule o3:
    input:
        gem5 = lambda w: get_gem5(w) + "/build/X86/gem5.opt",
        script = lambda w: get_gem5(w) + "/configs/deprecated/example/se.py",
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/o3/{size}/{sw}/{hwconf}/stamp.txt",
    params:
        # TODO: This should be unified, get_script_opts(w).
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/o3/{size}/{sw}/{hwconf}",
        script_opts = lambda w: hwconfs[w.hwconf].script_opts,
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
    resources:
        runtime = "2w",
        mem = lambda w: get_resources(w).hostmem,
    shell:
        'rm -rf {params.outdir} && '
        r'outdir="$PWD/{params.outdir}/\${{workload}}" && '
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py --stdout=$outdir/stdout.txt -- /usr/bin/time -vo $outdir/time.txt -- prlimit --as={params.hostmem} -- {input.gem5} -re --silent-redirect --outdir=$outdir --debug-flag=Heartbeat --debug-file=dbgout.txt {input.script} --output=stdout.txt --errout=stderr.txt --cpu-type=X86O3CPU --caches --max-stack-size={params.stack} --mem-size={params.sim_mem} {params.script_opts} -- \${{command}}" && '
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && '
        + runcpu + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} && '
        'touch {output.stamp}'

