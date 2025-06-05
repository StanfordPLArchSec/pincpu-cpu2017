def shell_run_bench(runcpu_run, command, stdout=None):
    if stdout:
        stdout_arg = f"--stdout={stdout}"
    else:
        stdout_arg = ""
    cmd = \
        'rm -rf {params.outdir} && ' + \
        'mkdir -p {params.outdir} && ' + \
        r'outdir="$PWD/{params.outdir}/\${{workload}}" && ' + \
        'cd cpu2017 && source shrc && cd .. && ' + \
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py %s -- prlimit --as={params.hostmem} /usr/bin/time -vo $outdir/time.txt -- %s -- \${{command}}" && ' % (stdout_arg, command) + \
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && ' + \
        runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable ' + \
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} > {params.outdir}/specout.txt 2> {params.outdir}/specerr.txt && ' + \
        'touch {output.stamp}'
    return cmd
        

def shell_run_bench_gem5(runcpu_run, script_opts=""):
    cmd = \
        'rm -rf {params.outdir} && ' + \
        'mkdir -p {params.outdir} && ' + \
        r'outdir="$PWD/{params.outdir}/\${{workload}}" && ' + \
        'cd cpu2017 && source shrc && cd .. && ' + \
        r'monitor_wrapper="mkdir -p $outdir && $PWD/wrap.py --stdout=$outdir/stdout.txt -- prlimit --as={params.hostmem} /usr/bin/time -vo $outdir/time.txt -- prlimit --as={params.hostmem} -- {input.gem5} -re --silent-redirect --outdir=$outdir --debug-flag=Heartbeat --debug-file=dbgout.txt {input.script} --output=stdout.txt --errout=stderr.txt --max-stack-size={params.stack} --mem-size={params.sim_mem} {params.script_opts} %s -- \${{command}}" && ' % (script_opts) + \
        r'monitor_specrun_wrapper="$PWD/wrap-specinvoke.py -- \${{command}}" && ' + \
        runcpu_run + ' --config=pincpu-{wildcards.sw} --tune=base --action=run --output_root=$PWD/{params.build} --size={wildcards.size} --noreportable ' + \
        '--define monitor_wrapper="$monitor_wrapper" --define monitor_specrun_wrapper="$monitor_specrun_wrapper" {wildcards.bench} > {params.outdir}/specout.txt 2> {params.outdir}/specerr.txt && ' + \
        'touch {output.stamp}'
    return cmd
