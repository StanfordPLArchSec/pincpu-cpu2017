rule simpoint:
    input:
        bbv = lambda w: get_bbv,
        exe = simpoint_exe,
    output:
        intervals = "{bench}/simpoints/{type}/{size}/{group}/{sw}/simpoint/{input}/intervals.txt",
        weights = "{bench}/simpoints/{type}/{size}/{group}/{sw}/simpoint/{input}/weights.txt",
    params:
        outdir = "{bench}/simpoints/{type}/{size}/{group}/{sw}/simpoint/{input}",
        num_simpoints = num_simpoints, # TODO: This needs to be parameterizable.
    shell:
        "rm -rf {params.outdir} && mkdir -p {params.outdir} && "
        "{input.exe} -loadFVFile {input.bbv} -maxK {params.num_simpoints} -saveSimpoints {output.intervals} -saveSimpointWeights {output.weights} -fixedLength off "
        "> {params.outdir}/stdout 2> {params.outdir}/stderr"
