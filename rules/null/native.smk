rule null_native:
    input:
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/null/{size}/{sw}/native/stamp.txt",
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/null/{size}/{sw}/native",
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem)
    shell:
        rules.cpu2017.shell_run_bench(
            runcpu_run,
            command="prlimit --stack=unlimited --as={params.hostmem}",
        )
