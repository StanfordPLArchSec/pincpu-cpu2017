# TODO: Compress.
rule localign_fast:
    input:
        locmaps  = lambda w: expand("{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",   **w, sw=list_group(w.group)),
        bbtraces = lambda w: [get_bbtrace(w, sw=sw) for sw in list_group(w.group)],
        bbhists  = lambda w: [get_bbhist__(**w, sw=sw) for sw in list_group(w.group)],
        lochist  = "{bench}/profile/{size}/{group}/lochist/{input}/lochist.txt",
        script   = "helpers/traceval-align-fast.py",
        compress = "helpers/bbtrace/align-compress.py",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/localign-fast.txt.gz"
    shell:
        "{input.script} --lochist {input.lochist} --locmaps {input.locmaps} --bbtraces {input.bbtraces} --bbhists {input.bbhists} | "
        "{input.compress} | gzip > {output}"

rule localign_best:
    input:
        locmaps  = lambda w: expand("{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",   **w, sw=list_group(w.group)),
        bbtraces = lambda w: [get_bbtrace(w, sw=sw) for sw in list_group(w.group)],
        bbhists  = lambda w: [get_bbhist__(**w, sw=sw) for sw in list_group(w.group)],
        exes     = lambda w: expand("{bench}/bin/{sw}/exe", **w, sw=list_group(w.group)),
        lochist  = "{bench}/profile/{size}/{group}/lochist/{input}/lochist-filtered.txt",
        script   = "helpers/traceval-align-best.py",
        compress = "helpers/bbtrace/align-compress.py",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/localign-best.txt.gz"
    shell:
        "{input.script} --lochist {input.lochist} --locmaps {input.locmaps} "
        "--bbtraces {input.bbtraces} --bbhists {input.bbhists} --exes {input.exes} | {input.compress} | gzip > {output}"

rule locerror:
    input:
        ref = "{bench}/profile/{size}/{group}/localign/{input}/localign-best.txt.gz",
        exp = "{bench}/profile/{size}/{group}/localign/{input}/localign-fast.txt.gz",
        script = "helpers/traceval-error.py",
        decompress = "helpers/bbtrace/align-decompress.py",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/locerror.txt"
    shell:
        "{input.script} <(gunzip < {input.ref} | {input.decompress}) <(gunzip < {input.exp} | {input.decompress}) > {output}"
