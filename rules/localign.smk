rule localign:
    input:
        lochist  = "{bench}/profile/{size}/{group}/lochist/{input}/lochist{suffix}.txt", # TODO: FIXME
        locmaps  = lambda w: expand("{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",   **w, sw=list_group(w.group)),
        bbtraces = lambda w: [get_bbtrace(w, sw=sw) for sw in list_group(w.group)],
        bbhists  = lambda w: expand("{bench}/profile/{size}/{sw}/bbhist/{input}/bbhist.txt", **w, sw=list_group(w.group)),
        script   = "helpers/traceval-align.py",
    output:
        "{bench}/profile/{size}/{group}/localign/{input}/localign{suffix}.txt"
    shell:
        "{input.script} --lochist {input.lochist} --locmaps {input.locmaps} --bbtraces {input.bbtraces} --bbhists {input.bbhists} > {output}"

