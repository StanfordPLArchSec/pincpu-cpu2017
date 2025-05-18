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
runcpu_build = os.path.abspath("wrap-runcpu-build")
runcpu_run = os.path.abspath("wrap-runcpu-run")
simpoint_exe = "../simpoint/bin/simpoint"
num_simpoints = 100 # Effectively unlimited.

wildcard_constraints:
    bench = r"6[0-9][0-9]\.[0-9a-zA-Z]+_s",
    input = r"[0-9]",
    sw = "[a-z]+",
    group = "[a-z]+",
    size = "(test|train|ref)",
    cptid = "[0-9]+",
    hwconf = "[a-z]+",
    type = "[a-z-]+",

compilers = ["base", "slh", "retpoline"]
groups = {
    "main": ["base", "slh", "retpoline"],
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
        script_opts = [
            "--stt",
            "--implicit-channel=Lazy",
            "--speculation-model=Ctrl",
        ],
    ),
}

include: "rules/cpu2017.smk"

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

resources_ref = {
    "602.gcc_s": {
        "mem": "16GiB",
        "hostmem": "20GiB",
    },
    "605.mcf_s": {
        "mem": "16GiB",
        "hostmem": "24GiB",
    },
    "631.deepsjeng_s": {
        "mem": "8GiB",
        "hostmem": "20GiB",
    },
    "657.xz_s": {
        "mem": "32GiB",
        "hostmem": "36GiB",
    },
    "603.bwaves_s": {
        "mem": "16GiB",
        "hostmem": "24GiB",
    },
    "607.cactuBSSN_s": {
        "mem": "16GiB",
        "hostmem": "20GiB",
    },
    "619.lbm_s": {
        "mem": "4GiB",
        "hostmem": "20GiB",
    },
    "621.wrf_s": {
        "stack": "128MiB",
    },
    "627.cam4_s": {
        "stack": "128MiB",
    },
    "628.pop2_s": {
        "mem": "2GiB",
        "stack": "2GiB",
    },
    "638.imagick_s": {
        "mem": "8GiB",
        "hostmem": "12GiB",
    },
    "649.fotonik3d_s": {
        "mem": "16GiB",
        "hostmem": "24GiB",
    },
    "654.roms_s": {
        "mem": "16GiB",
        "stack": "64MiB",
        "hostmem": "20GiB",
    },
}

resources_test = {}

resources = {
    "train": resources_train,
    "ref": resources_ref,
    "test": resources_test,
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

def compile_mem(w):
    d = {
        "621.wrf_s": "16GiB",
    }
    return d.get(w.bench, "8GiB")


# TODO: Consider making this a plain rule again.
checkpoint build_cpu2017_bench:
    output:
        exe = "{bench}/bin/{sw}/exe",
    params:
        cpu2017 = cpu2017,
        exe = get_exe,
        build = "{bench}/bin/{sw}",
    threads: 8
    resources:
        mem = compile_mem
    shell:
        # TODO: Might be able to use monitor_specrun_wrapper?
        "pushd {params.cpu2017} >/dev/null && source shrc && popd >/dev/null && "
        + runcpu_build + " --config=pincpu-{wildcards.sw} --tune=base --action=build --output_root=$PWD/{params.build} {wildcards.bench} && "
        "[ -f {params.exe} ] && [ -x {params.exe} ] && ln -sf {params.exe} {output.exe}"

rule valgrind:
    input:
        exe = "{bench}/bin/{sw}/exe"
    output:
        stamp = "{bench}/cpt/{size}/{sw}/{sw}/valgrind/stamp.txt"
    params:
        outdir = "{bench}/cpt/{size}/{sw}/{sw}/valgrind",
        workload = lambda w: r"\${workload}",
        build = "{bench}/bin/{sw}",
    shell:
        'rm -rf {params.outdir} && mkdir -p {params.outdir} && '
        r'outdir="$PWD/{params.outdir}/{params.workload}" && '
        r'monitor_wrapper="mkdir -p $outdir && /usr/bin/time -vo $outdir/time.txt -- valgrind --tool=exp-bbv -- \${{command}}" && '
        r'monitor_specrun_wrapper="/usr/bin/time -vo $PWD/{params.outdir}/time.txt -- $PWD/wrap-specinvoke.py -- \${{command}}" && '        
        'cd cpu2017 && source shrc && cd .. && '
        + runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} && '
        'touch {output.stamp}'



def get_gem5(w):
    gem5, = expand("../gem5/{sim}", sim = hwconfs[w.hwconf].sim)
    return os.path.abspath(gem5)


def o3_hostmem(w):
    return max(humanfriendly.parse_size(get_resources(w).hostmem),
               humanfriendly.parse_size("12GiB"))

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
    resources:
        runtime = "2w",
        mem = lambda w: humanfriendly.format_size(o3_hostmem(w)),
    shell:
        'rm -rf {params.outdir} && '
        r'outdir="$PWD/{params.outdir}/\${{workload}}" && '
        'cd cpu2017 && source shrc && cd .. && '
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py --stdout=$outdir/stdout.txt -- /usr/bin/time -vo $outdir/time.txt -- {input.gem5} -re --silent-redirect --outdir=$outdir --debug-flag=Heartbeat --debug-file=dbgout.txt {input.script} --output=stdout.txt --errout=stderr.txt --cpu-type=X86O3CPU --caches --max-stack-size={params.stack} --mem-size={params.sim_mem} {params.script_opts} -- \${{command}}" && '
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && '
        + runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} && '
        'touch {output.stamp}'

include: "rules/chunk.smk"
include: "rules/simpoint-legacy.smk"
include: "rules/simpoint-translation.smk"
include: "rules/traceval.smk" # Trace validation.
