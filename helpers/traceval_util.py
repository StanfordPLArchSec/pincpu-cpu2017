import gzip
import xxhash

# Generator for location traces.
def loctrace(lochist, bbtrace_path, bbhist_path, locmap_path):
    # Parse the bbhist file first, indexing by block hash.
    block_to_insts = dict()
    with open(bbhist_path) as f:
        for line in f:
            count, block = line.split()
            block_hash = xxhash.xxh32(block).intdigest()
            assert block_hash not in block_to_insts
            block_to_insts[block_hash] = block.split(",")

    # Build the locmap.
    locmap = dict()
    with open(locmap_path) as f:
        for line in f:
            inst, loc = line.split()
            locmap[inst] = loc


    with gzip.open(bbtrace_path, "rb") as f:
        while True:
            block_hash = f.read(4)
            if not block_hash:
                break
            assert len(block_hash) == 4
            block = int.from_bytes(block_hash, byteorder="little")
            insts = block_to_insts[block]
            for inst in insts:
                if inst in locmap:
                    loc = locmap[inst]

                    # Only return locations that are in the lochist.
                    if loc in lochist:
                        yield loc
