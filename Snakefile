import os
import sys
import glob

gem5_pin_src = os.path.abspath("../gem5/pincpu")
gem5_pin_exe = gem5_pin_src + "/build/X86/gem5.opt"
gem5_pin_configs = gem5_pin_src + "/configs"
cpu2017 = os.path.abspath("cpu2017")
addr2line = "../llvm/build/bin/llvm-addr2line"

wildcard_constraints:
    bench = r"6[0-9][0-9]\.[0-9a-zA-Z]+_s",
    input = r"[0-9]",
    sw = "[a-z]+",
    group = "[a-z]+",
    size = "(test|train|ref)",

# TODO: Consider making this a plain rule again.
checkpoint build_cpu2017_bench:
    output:
        directory("{bench}/bin/{sw}")
    params:
        cpu2017 = cpu2017
    threads: 8
    shell:
        "pushd {params.cpu2017} >/dev/null && source shrc && popd >/dev/null && "
        "runcpu --config=pincpu-{wildcards.sw} --tune=base --action=build --output_root=$PWD/{output} {wildcards.bench}"

def get_exe(wildcards):
    outdir = checkpoints.build_cpu2017_bench.get(**wildcards).output
    # Find the only executable under */exe/*.
    exes = []
    for path in glob.glob(f"{outdir}/**/exe/*", recursive=True):
        if os.path.isfile(path) and os.access(path, os.X_OK):
            exes.append(path)
    if len(exes) > 1:
        print("[!] Found multiple executables!", file=sys.stderr)
        exit(1)
    elif len(exes) == 0:
        print(f"[!] Found no executables in directory {outdir}!", file=sys.stderr)
        print(f"[!] glob: {outdir}/**/exe/*", file=sys.stderr)
        exit(1)
    return exes[0]
        
        
    
        
checkpoint bbhist:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbhist.py"),
        build = "{bench}/bin/{sw}",
    output:
        directory("{bench}/cpt/{size}/{sw}/{sw}/bbhist")
    params:
        workload = lambda w: r"\${workload}"
    shell:
        'rm -rf {output} && '
        'wrap="$PWD/wrap.py" && '
        r'outdir="$PWD/{output}/{params.workload}" && '
        r'monitor_wrapper="$wrap --stdout=$outdir/stdout.txt -- {input.gem5} -re --silent-redirect --outdir=$outdir {input.script} --bbhist=$outdir/bbhist.txt -- \${{command}}" && '
        'runcpu --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{input.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" {wildcards.bench}'

def get_bbhist(wildcards):
    outdir = checkpoints.bbhist.get(**wildcards).output
    bbhist = expand(f"{outdir}/{{input}}/bbhist.txt", **wildcards)
    return bbhist
        
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
        exe = get_exe,
        instlist = "{bench}/cpt/{size}/{sw}/{sw}/instlist.{input}.txt",
    output:
        "{bench}/cpt/{size}/{sw}/{sw}/srclist.{input}.txt",
    shell:
        addr2line + " --exe {input.exe} --output-style=JSON < {input.instlist} > {output}"

