rule resume:
    input:
        gem5 = lambda w: get_gem5(w) + "/build/X86/gem5.opt",
        script = lambda w: get_gem5(w) + "/configs/deprecated/example/se.py",
        exe = "{bench}/bin/{sw}/exe",
        cpt = get_checkpoint,
    output:
        stamp = "{bench}/simpoints/{type}/{size}/{group}/{sw}/exp/{hwconf}/{input}/{cptid}/stamp.txt",
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/simpoints/{type}/{size}/{group}/{sw}/exp/{hwconf}/{input}/{cptid}",
        cptdir = "{bench}/simpoints/{type}/{size}/{group}/{sw}/cpt/{input}",
        script_opts = lambda w: hwconfs[w.hwconf].script_opts,
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
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

rule resume_all_input:
    input:
        lambda w: expand("{bench}/simpoints/{type}/{size}/{group}/{sw}/exp/{hwconf}/{input}/{cptid}/stamp.txt",
                         **w, cptid=get_cptids(w))
    output:
        "{bench}/simpoints/{type}/{size}/{group}/{sw}/exp/{hwconf}/{input}/all"

rule resume_all_stats:
    input:
        stamps = lambda w: expand("{bench}/simpoints/{type}/{size}/{group}/{sw}/exp/{hwconf}/{input}/{cptid}/stamp.txt",
                                  **w, cptid=get_cptids(w)),
        simpoints = "{bench}/simpoints/{type}/{size}/{group}/simpoint.{input}.json",
        bbhist = "{bench}/profile/{size}/{sw}/bbhist/{input}/bbhist.txt",
        script = "helpers/simpoint-stats.py",
    output:
        "{bench}/simpoints/{type}/{size}/{group}/{sw}/exp/{hwconf}/{input}/stats.txt"
    shell:
        "{input.script} --simpoints={input.simpoints} --bbhist={input.bbhist} {input.stamps} > {output}"
