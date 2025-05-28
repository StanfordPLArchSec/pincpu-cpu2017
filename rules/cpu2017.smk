cpu2017_bench_input_counts = {
    "ref": {
        600: 3,
        602: 3,
        625: 3,
        657: 2,
    },
    "train": {
        600: 5,
        602: 3,
        657: 2,
    },
    "test": {
        600: 2,
        657: 12,
    },
}

def cpu2017_num_inputs(bench, size):
    num = int(bench.split(".")[0])
    return cpu2017_bench_input_counts[size].get(num, 1)
    
def cpu2017_num_inputs_wildcard(w):
    return cpu2017_num_inputs(w.bench, w.size)

def cpu2017_expand_inputs(w, template):
    num_inputs = cpu2017_num_inputs_wildcard(w)
    return expand(template, **w, input=range(num_inputs))

def make_cpu2017_expand_inputs(template):
    return lambda w: cpu2017_expand_inputs(w, template)
