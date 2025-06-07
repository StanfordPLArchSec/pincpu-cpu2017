#include <vector>
#include <string>
#include <optional>
#include <stdexcept>
#include <cstdlib>
#include <cstdint>
#include <iostream>
#include <fstream>
#include <array>
#include <unordered_set>
#include <unordered_map>
#include <cassert>
#include <xxhash.h>
#include <cinttypes>
#include <zlib.h>
#include <err.h>

using InstAddr = uint64_t;
using InstCount = std::size_t;
using BlockHash = uint32_t;
using Loc = std::string;

// TODO: Refactor to share this with other implementations.
// --------------------------------------------------------------------------------
// Utility: split a comma‐separated string into a vector<string>
// --------------------------------------------------------------------------------
static std::vector<std::string> splitCommas(const std::string& s) {
    std::vector<std::string> result;
    size_t start = 0;
    while (start < s.size()) {
        auto comma = s.find(',', start);
        if (comma == std::string::npos) comma = s.size();
        result.emplace_back(s.substr(start, comma - start));
        start = comma + 1;
    }
    return result;
}

// TODO: Refactor: share these with other implementations.
static std::unordered_map<BlockHash, std::vector<InstAddr>>
parseBBHist(const std::string &path)
{
    std::unordered_map<BlockHash, std::vector<InstAddr>> result;
    std::ifstream f(path);
    if (!f) {
        std::cerr << "failed to open " << path << "\n";
        std::exit(1);
    }
    std::string count_s;
    std::string block;
    while (f >> count_s >> block) {
        const BlockHash h = XXH32(block.data(), block.size(), 0);
        auto &v = result[h];
        assert(v.empty());
        for (const std::string &inst : splitCommas(block))
            v.push_back(std::stoull(inst, nullptr, 16));
    }
    return result;
}

using LocSet = std::unordered_set<std::string>;

static LocSet
parseLochist(const std::string &path)
{
    std::ifstream in(path);
    if (!in) {
        std::cerr << "failed to open " << path << "\n";
        std::exit(1);
    }

    LocSet result;
    std::string count;
    std::string loc;
    while (in >> count >> loc) {
        [[maybe_unused]] const bool inserted =
            result.insert(std::move(loc)).second;
        assert(inserted);
    }

    return result;
}

using LocMap = std::unordered_map<InstAddr, Loc>;

static LocMap
parseLocmap(const std::string &path)
{
    std::ifstream in(path);
    if (!in) {
        std::cerr << "failed to open " << path << "\n";
        std::exit(1);
    }

    LocMap locmap;
    InstAddr inst_addr;
    std::string loc;
    while (in >> std::hex >> inst_addr >> loc) {
        assert(!locmap.contains(inst_addr));
        locmap[inst_addr] = std::move(loc);
    }

    return locmap;
}

struct InstInfo
{
    InstAddr addr;
    const Loc *loc;

    InstInfo(InstAddr addr, const Loc *loc)
        : addr(addr), loc(loc)
    {
    }
};

using TraceInfo = std::vector<InstInfo>;

struct BlockGenerator
{
    std::unordered_map<BlockHash, TraceInfo> traces;
    gzFile gz;

    BlockGenerator(const std::string &bbtrace_path,
                     const std::string &bbhist_path,
                     const std::string &locmap_path,
                     const LocSet &locset)
    {
        const auto blockhash_to_insts = parseBBHist(bbhist_path);
        const auto locmap = parseLocmap(locmap_path);

        // Populate traces.
        for (const auto &[blockhash, insts] : blockhash_to_insts) {
            auto &trace = traces[blockhash];
            assert(trace.empty());
            for (InstAddr inst : insts) {
                const Loc *locp = nullptr;
                const auto locmap_it = locmap.find(inst);
                if (locmap_it != locmap.end()) {
                    const std::string &loc = locmap_it->second;
                    const auto locset_it = locset.find(loc);
                    if (locset_it != locset.end())
                        locp = &*locset_it;
                }
                trace.emplace_back(inst, locp);
            }
        }

        // Open bbtrace.
        gz = gzopen(bbtrace_path.c_str(), "rb");
        if (!gz) {
            std::cerr << "failed to open " << bbtrace_path << "\n";
            std::exit(1);
        }
    }
    
    BlockGenerator(BlockGenerator &&o)
        : traces(std::move(o.traces)), gz(o.gz)
    {
        o.gz = nullptr;
    }

    ~BlockGenerator()
    {
        if (gz)
            gzclose(gz);
    }

    // TODO: Refactor. Identical to trace-filter-waypoint's impl.
    const TraceInfo *
    next()
    {
        uint32_t blockhash;
        const int bytes = gzread(gz, &blockhash, sizeof blockhash);
        if (bytes == 4) {
            return &traces[blockhash];
        } else if (bytes == 0) {
            return nullptr;
        } else {
            std::cerr << "read " << bytes << " bytes\n";
            std::exit(1);
        }
    }
    
};


struct InstGenerator
{
    BlockGenerator gen;
    const TraceInfo *block = nullptr;
    TraceInfo::const_iterator it;

    template <typename... Args>
    InstGenerator(Args&&... args)
        : gen(std::forward<Args>(args)...)
    {
    }

    const InstInfo *
    next()
    {
        while (!block || it == block->end()) {
            block = gen.next();
            if (!block)
                return nullptr;
            it = block->begin();
        }
        assert(block);
        assert(!block->empty());
        assert(it != block->end());
        return &*it++;
    }
};

struct BatchGenerator
{
    InstGenerator gen;
    const InstInfo *x = nullptr; // Singleton located instruction.

    template <typename... Args>
    BatchGenerator(Args&&... args)
        : gen(std::forward<Args>(args)...)
    {
    }

    template <typename OutputIt>
    bool
    next(OutputIt out)
    {
        // If we have a singleton located instruction, yield it.
        if (x) {
            *out++ = x;
            x = nullptr;
            return true;
        }

        // Otherwise, read until the next located instruction (or end).
        // Yield the intermediate non-located instructions.
        bool end = true;
        while (true) {
            const InstInfo *y = gen.next();
            if (!y)
                return !end;
            end = false;
            if (y->loc) {
                x = y;
                return true;
            }
            *out++ = y;
        }
    }
};





// --------------------------------------------------------------------------------
// Simple argument parsing. Expect exactly these flags (order‐independent):
//   --bbtraces <f1> <f2> …
//   --bbhists <h1> <h2> …
//   --locmaps <m1> <m2> …
//   --lochist <single_file>
// The counts of bbtraces, bbhists, and locmaps must match.
// --------------------------------------------------------------------------------
struct Arguments {
    std::vector<std::string> bbtraces;
    std::vector<std::string> bbhists;
    std::vector<std::string> locmaps;
    std::vector<std::string> exes;
    std::string lochist;
};

static Arguments parse_args(int argc, char* argv[]) {
    Arguments args;
    std::string flag;
    for (int i = 1; i < argc; ++i) {
        std::string s(argv[i]);
        if (s == "--bbtraces" || s == "--bbhists" || s == "--locmaps" || s == "--lochist" || s == "--exes") {
            flag = s;
            if (s == "--lochist") {
                if (i + 1 >= argc) {
                    throw std::runtime_error("--lochist requires exactly one argument");
                }
                args.lochist = argv[++i];
                flag.clear();
            }
        }
        else if (!flag.empty()) {
            if (flag == "--bbtraces") {
                args.bbtraces.push_back(s);
            }
            else if (flag == "--bbhists") {
                args.bbhists.push_back(s);
            }
            else if (flag == "--locmaps") {
                args.locmaps.push_back(s);
            }
            else if (flag == "--exes") {
                args.exes.push_back(s);
            }
            else {
                throw std::runtime_error("Internal error: unrecognized flag state");
            }
        }
        else {
            throw std::runtime_error("Unexpected argument: " + s);
        }
    }

    if (args.bbtraces.empty() || args.bbhists.empty() || args.locmaps.empty() || args.lochist.empty()) {
        throw std::runtime_error("Must provide --bbtraces, --bbhists, --locmaps (each ≥1 file) and --lochist <file>");
    }
    if (args.bbtraces.size() != args.bbhists.size() ||
        args.bbtraces.size() != args.locmaps.size()) {
        throw std::runtime_error("Counts of bbtraces, bbhists, and locmaps must match exactly.");
    }
    return args;
}

int
main(int argc, char *argv[])
{
    auto args = parse_args(argc, argv);
    auto &os = std::cout;

    // Parse lochist.
    const auto locset = parseLochist(args.lochist);

    // Instantiate generators.
    std::vector<BatchGenerator> gens;
    for (std::size_t i = 0; i < args.bbtraces.size(); ++i)
        gens.emplace_back(args.bbtraces[i], args.bbhists[i], args.locmaps[i], locset);

    // Main loop.
    std::vector<std::vector<const InstInfo *>> chunks(gens.size());
    std::vector<InstCount> instcounts(gens.size(), 0);
    while (true) {
        for (std::size_t i = 0; i < gens.size(); ++i) {
            auto &gen = gens[i];
            auto &chunk = chunks[i];
            chunk.clear();
            if (!gen.next(std::back_inserter(chunk)))
                goto done;
        }

        // Are these all located singletons?
        if (!chunks[0].empty()) {
            if (const Loc *loc = chunks[0][0]->loc) {
                for (const auto &chunk : chunks) {
                    assert(chunk.size() == 1);
                    assert(chunk[0]->loc == loc);
                }

                // Print out the trace: addr1 count1 ... addrn countn.
                for (std::size_t i = 0; i < chunks.size(); ++i) {
                    const auto &chunk = chunks[i];
                    if (i > 0)
                        os << " ";
                    os << std::hex << chunk[0]->addr << std::dec << " " << instcounts[i];
                }
                os << "\n";
            }
        }

        // Update instcounts.
        for (std::size_t i = 0; i < gens.size(); ++i)
            instcounts[i] += chunks[i].size();
    }

  done:
    for (auto &gen : gens) {
        std::vector<const InstInfo *> tmp;
        assert(!gen.next(std::back_inserter(tmp)));
    }
}
