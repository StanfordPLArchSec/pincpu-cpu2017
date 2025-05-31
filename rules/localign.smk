# TODO: Compress.
rule localign_fast:
    input:
        locmaps  = lambda w: expand("{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",   **w, sw=list_group(w.group)),
        bbtraces = lambda w: [get_bbtrace(w, sw=sw) for sw in list_group(w.group)],
        bbhists  = lambda w: expand("{bench}/profile/{size}/{sw}/bbhist/{input}/bbhist.txt", **w, sw=list_group(w.group)),
        lochist  = "{bench}/profile/{size}/{group}/lochist/{input}/lochist.txt",
        script   = "helpers/traceval-align-fast.py",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/localign-fast.txt"
    shell:
        "{input.script} --lochist {input.lochist} --locmaps {input.locmaps} --bbtraces {input.bbtraces} --bbhists {input.bbhists} > {output}"

rule localign_best:
    input:
        locmaps  = lambda w: expand("{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",   **w, sw=list_group(w.group)),
        bbtraces = lambda w: [get_bbtrace(w, sw=sw) for sw in list_group(w.group)],
        bbhists  = lambda w: expand("{bench}/profile/{size}/{sw}/bbhist/{input}/bbhist.txt", **w, sw=list_group(w.group)),
        exes     = lambda w: expand("{bench}/bin/{sw}/exe", **w, sw=list_group(w.group)),
        lochist  = "{bench}/profile/{size}/{group}/lochist/{input}/lochist-filtered.txt",
        script   = "helpers/traceval-align-best.py",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/localign-best.txt"
    shell:
        "{input.script} --lochist {input.lochist} --locmaps {input.locmaps} "
        "--bbtraces {input.bbtraces} --bbhists {input.bbhists} --exes {input.exes} > {output}"

rule locerror:
    input:
        ref = "{bench}/profile/{size}/{group}/localign/{input}/localign-best.txt",
        exp = "{bench}/profile/{size}/{group}/localign/{input}/localign-fast.txt",
        script = "helpers/traceval-error.py",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/locerror.txt"
    shell:
        "{input.script} {input.ref} {input.exp} > {output}"
