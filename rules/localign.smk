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

rule localign_fast2:
    input:
        bbtraces = lambda w: [get_bbtrace(w, sw=sw) for sw in list_group(w.group)],
        bbhists  = lambda w: [get_bbhist__(**w, sw=sw) for sw in list_group(w.group)],
        waypoints = lambda w: expand("{bench}/profile/{size}/{group}.{sw}/waypoints/{input}/waypoints.txt", **w, sw=list_group(w.group)),
        script   = "helpers/bbtrace/trace-align-faster",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/localign-fast2.txt.gz"
    shell:
        "{input.script} --compress --bbtraces {input.bbtraces} --bbhists {input.bbhists} --waypoints {input.waypoints} > {output}"
        

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

rule localign_best2:
    input:
        locmaps  = lambda w: expand("{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",   **w, sw=list_group(w.group)),
        bbtraces = lambda w: [get_bbtrace(w, sw=sw) for sw in list_group(w.group)],
        bbhists  = lambda w: [get_bbhist__(**w, sw=sw) for sw in list_group(w.group)],
        opmaps   = lambda w: expand("{bench}/profile/{size}/{sw}/opmap/{input}/opmap.txt", **w, sw=list_group(w.group)),
        lochist  = "{bench}/profile/{size}/{group}/lochist/{input}/lochist-filtered2.txt",
        script   = "helpers/bbtrace/trace-align-best",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/localign-best2.txt.gz"
    shell:
        "{input.script} --compress --lochist {input.lochist} --locmaps {input.locmaps} "
        "--bbtraces {input.bbtraces} --bbhists {input.bbhists} --opmaps {input.opmaps} | gzip > {output}"
        
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

rule locerror2:
    input:
        ref = "{bench}/profile/{size}/{group}/localign/{input}/localign-best2.txt.gz",
        exp = "{bench}/profile/{size}/{group}/localign/{input}/localign-fast2.txt.gz",
        script = "helpers/bbtrace/error",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/errhist.txt"
    params:
        n = lambda w: len(list_group(w.group)),
    shell:
        "{input.script} {params.n} <(gunzip < {input.ref}) <(gunzip < {input.exp}) > {output}"

rule locstats:
    input:
        errhist = "{bench}/profile/{size}/{group}/localign/{input}/errhist.txt",
        script = "helpers/bbtrace/errstats.py",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/errstats.txt"
    shell:
        "{input.script} < {input.errhist} > {output}"

