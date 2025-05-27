# TODO: Rename single -> run/single?
# TODO: Programmatically get bbhist path.
# TODO: Only should have to print once.

rule locmap:
    input:
        exe = "{bench}/bin/{sw}/exe",
        bbhist = get_bbhist_,
        addr2line = addr2line,
        script = "helpers/locmap.py",
    output:
        "{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",
    shell:
        "{input.script} -- {input.addr2line} --exe {input.exe} --output-style=LLVM --basenames < {input.bbhist} > {output}"
