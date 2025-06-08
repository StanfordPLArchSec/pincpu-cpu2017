rule null_pin:
    input:
        exe = "{bench}/bin/{sw}/exe",
        pin = os.path.abspath("../gem5/pincpu/ext/pin/pin"),
    output:
        stamp = "{bench}/null/{size}/{sw}/pin/stamp.txt",
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/null/{size}/{sw}/pin",
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem)
    shell:
        rules.cpu2017.shell_run_bench(
            runcpu_run,
            command="prlimit --stack=unlimited --as={params.hostmem} -- {input.pin} 2>$outdir/stderr.txt",
        )
        
