rule simpoint:
    input:
        bbv = get_bbv,
        exe = simpoint_exe,
    output:
        intervals = "{bench}/simpoints/{type}/{size}/{group}/{sw}/simpoint.k{maxk}/{input}/intervals.txt",
        weights = "{bench}/simpoints/{type}/{size}/{group}/{sw}/simpoint.k{maxk}/{input}/weights.txt",
    params:
        outdir = "{bench}/simpoints/{type}/{size}/{group}/{sw}/simpoint.k{maxk}/{input}",
    shell:
        "rm -rf {params.outdir} && mkdir -p {params.outdir} && "
        "{input.exe} -loadFVFile {input.bbv} -maxK {wildcards.maxk} -saveSimpoints {output.intervals} -saveSimpointWeights {output.weights} -fixedLength off "
        "> {params.outdir}/stdout 2> {params.outdir}/stderr"

rule simpoint_json:
    input:
        intervals = lambda w: \
            expand("{bench}/simpoints/{type}/{size}/{group}/{sw}/simpoint.k{maxk}/{input}/intervals.txt",
                   **w, sw=group_leader(w.group)),
        weights = lambda w: \
            expand("{bench}/simpoints/{type}/{size}/{group}/{sw}/simpoint.k{maxk}/{input}/weights.txt",
                   **w, sw=group_leader(w.group)),
        bbvinfo = lambda w: get_bbvinfo(w, sw=group_leader(w.group)),
        script = "helpers/simpoints.py",
    output:
        "{bench}/simpoints/{type}/{size}/{group}/simpoint.k{maxk}.i{input}.json",
    shell:
        "{input.script} --intervals={input.intervals} --weights={input.weights} --bbvinfo={input.bbvinfo} > {output}"
