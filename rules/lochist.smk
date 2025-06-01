rule single_lochist:
    input:
        exe = "{bench}/bin/{sw}/exe",
        bbhist = get_bbhist_,
        locmap = "{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",
        script = "helpers/lochist.py",
    output:
        "{bench}/profile/{size}/{sw}/lochist/{input}/lochist.txt"
    shell:
        "{input.script} --locmap {input.locmap} --bbhist {input.bbhist} > {output}"

rule group_lochist:
    input:
        lochists = lambda w: expand("{bench}/profile/{size}/{sw}/lochist/{input}/lochist.txt", **w, sw=list_group(w.group)),
        script = "helpers/shlochist.py",
    output:
        "{bench}/profile/{size}/{group}/lochist/{input}/lochist.txt"
    shell:
        "{input.script} {input.lochists} > {output}"

rule group_lochist_filtered:
    input:
        lochist  = "{bench}/profile/{size}/{group}/lochist/{input}/lochist.txt",
        locmaps  = lambda w: expand("{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",   **w, sw=list_group(w.group)),
        bbtraces = lambda w: [get_bbtrace(w, sw=sw) for sw in list_group(w.group)],
        bbhists  = lambda w: [get_bbhist__(**w, sw=sw) for sw in list_group(w.group)],
        script   = "helpers/traceval-filter-lochist.py",
    output:
        "{bench}/profile/{size}/{group}/lochist/{input}/lochist-filtered.txt",
    shell:
        "{input.script} < {input.lochist} --bbtraces {input.bbtraces} --bbhists {input.bbhists} --locmaps {input.locmaps} > {output}"
