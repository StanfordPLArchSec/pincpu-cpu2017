checkpoint bbtrace:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin-bbtrace.py"),
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/profile/{size}/{sw}/bbtrace/stamp.txt"
    params:
        outdir = "{bench}/profile/{size}/{sw}/bbtrace",
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
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py --stdout=$outdir/stdout.txt -- /usr/bin/time -vo $outdir/time.txt -- prlimit --as={params.hostmem} -- {input.gem5} -re --silent-redirect --outdir=$outdir --debug-flag=Heartbeat --debug-file=dbgout.txt {input.script} --output=stdout.txt --errout=stderr.txt --max-stack-size={params.stack} --mem-size={params.sim_mem} --bbtrace $outdir/bbtrace.txt.gz -- \${{command}}" && '
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && '
        + runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable '
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} && '
        'touch {output.stamp}'

# TODO: Unify with other functions doing similar tasks. Lots of repeated code.
def get_bbtrace(w, **kwargs):
    outdir = os.path.dirname(checkpoints.bbtrace.get(**w, **kwargs).output.stamp)
    bbtrace, = expand(outdir + "/{input}/bbtrace.txt.gz", input=w.input)
    return bbtrace
