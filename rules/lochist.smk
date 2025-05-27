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
