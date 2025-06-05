rule waypoints:
    input:
        lochist = "{bench}/profile/{size}/{group}/lochist/{input}/lochist.txt",
        locmap = "{bench}/profile/{size}/{sw}/locmap/{input}/locmap.txt",
        script = "helpers/waypoints.py",
    output:
        "{bench}/profile/{size}/{group}.{sw}/waypoints/{input}/waypoints.txt"
    shell:
        "{input.script} --lochist={input.lochist} --locmap={input.locmap} > {output}"
