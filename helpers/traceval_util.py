import gzip
import xxhash

def parse_lochist(f):
    lochist = {}
    for line in f:
        count, loc = line.split()
        lochist[loc] = count
    return lochist

def parse_locmap(f):
    locmap = {}
    for line in f:
        inst, loc = line.split()
        locmap[inst] = loc
    return locmap
        

# Generator for location traces.
def insttrace(bbtrace_path, bbhist_path):
    # Parse the bbhist file first, indexing by block hash.
    block_to_insts = dict()
    with open(bbhist_path) as f:
        for line in f:
            count, block = line.split()
            block_hash = xxhash.xxh32(block).intdigest()
            assert block_hash not in block_to_insts
            block_to_insts[block_hash] = block.split(",")

    with gzip.open(bbtrace_path, "rb") as f:
        while True:
            block_hash = f.read(4)
            if not block_hash:
                break
            assert len(block_hash) == 4
            block = int.from_bytes(block_hash, byteorder="little")
            insts = block_to_insts[block]
            for inst in insts:
                yield inst

# TODO: Rename.
def instloctrace(lochist, bbtrace_path, bbhist_path, locmap_path):
    # Parse the locmap.
    with open(locmap_path) as f:
        locmap = parse_locmap(f)

    for inst in insttrace(bbtrace_path, bbhist_path):
        loc = None
        if inst in locmap:
            loc = locmap[inst]
            if loc not in lochist:
                loc = None
        yield inst, loc

# TODO: Rename.
def loctrace(lochist, bbtrace_path, bbhist_path, locmap_path):
    for inst, loc in instloctrace(lochist, bbtrace_path, bbhist_path, locmap_path):
        if loc:
            yield loc

