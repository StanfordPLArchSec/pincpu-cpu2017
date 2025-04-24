import os

gem5_pin_src = os.path.abspath("../gem5/pincpu")
gem5_pin_exe = gem5_pin_src + "/build/X86_MESI_Three_Level/gem5.opt"
gem5_pin_configs = gem5_pin_src + "/configs"
cpu2017 = os.path.abspath("cpu2017")

rule build_cpu2017_bench:
    output:
        directory("{bench}/bin/{sw}")
    params:
        cpu2017 = cpu2017
    threads: 8
    shell:
        "pushd {params.cpu2017} >/dev/null && source shrc && popd >/dev/null && "
        "runcpu --config=pincpu-{wildcards.sw} --tune=base --action=build --output_root=$PWD/{output} {wildcards.bench}"

# rule _pincpu:
#     input:
#         gem5 = gem5_pin_exe,
# 
# rule bbhist:
#     input:
        
