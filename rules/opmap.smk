rule opmap:
    input:
        exe = "{bench}/bin/{sw}/exe",
        bbhist = get_bbhist_,
        script = "helpers/opmap.py",
    output:
        "{bench}/profile/{size}/{sw}/opmap/{input}/opmap.txt"
    shell:
        "{input.script} --exe {input.exe} --bbhist {input.bbhist} > {output}"
