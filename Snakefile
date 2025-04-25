import os

gem5_pin_src = os.path.abspath("../gem5/pincpu")
gem5_pin_exe = gem5_pin_src + "/build/X86/gem5.opt"
gem5_pin_configs = gem5_pin_src + "/configs"
cpu2017 = os.path.abspath("cpu2017")

wildcard_constraints:
    bench = r"6[0-9][0-9]\.[0-9a-zA-Z]+_s",
    input = r"[0-9]",
    sw = "[a-z]+",
    group = "[a-z]+",
    size = "(test|train|ref)",

rule build_cpu2017_bench:
    output:
        directory("{bench}/bin/{sw}")
    params:
        cpu2017 = cpu2017
    threads: 8
    shell:
        "pushd {params.cpu2017} >/dev/null && source shrc && popd >/dev/null && "
        "runcpu --config=pincpu-{wildcards.sw} --tune=base --action=build --output_root=$PWD/{output} {wildcards.bench}"

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
    
# rule _pincpu:
#     input:
#         gem5 = gem5_pin_exe,
# 
# rule bbhist:
#     input:
        
