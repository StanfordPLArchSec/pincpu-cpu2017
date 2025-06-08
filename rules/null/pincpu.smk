rule null_pincpu:
    input:
        gem5 = gem5_pin_exe,
        script = os.path.join(gem5_pin_configs, "pin.py"),
        exe = "{bench}/bin/{sw}/exe",
    output:
        stamp = "{bench}/null/{size}/{sw}/pincpu/stamp.txt",
    params:
        build = "{bench}/bin/{sw}",
        outdir = "{bench}/null/{size}/{sw}/pincpu",
        sim_mem = lambda w: get_resources(w).mem,
        stack = lambda w: get_resources(w).stack,        
        hostmem = lambda w: humanfriendly.parse_size(get_resources(w).hostmem),
        script_opts = "",
    shell:
        rules.cpu2017.shell_run_bench_gem5(runcpu_run, script_opts="")
