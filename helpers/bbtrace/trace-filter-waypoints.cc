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
#include <algorithm>
#include <zlib.h>
#include <err.h>

using InstAddr = uint64_t;
using InstCount = std::size_t;
using BlockHash = uint32_t;
using LocCount = std::size_t;

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

using LocHist = std::unordered_map<std::string, LocCount>;

static LocHist
parseLochist(const std::string &path)
{
    std::ifstream in(path);
    if (!in) {
        std::cerr << "failed to open " << path << "\n";
        std::exit(1);
    }

    LocHist lochist;
    LocCount count;
    std::string loc;
    while (in >> std::dec >> count >> loc) {
        assert(lochist.count(loc) == 0);
        assert(count > 0);
        lochist[loc] = count;
    }

    return lochist;
}

using LocMap = std::unordered_map<InstAddr, std::string>;

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
    


using TraceInfo = std::vector<LocCount *>;

// TODO: Refactor to share code with trace-align-faster.cc's implementation.
struct BlockedLocationGenerator
{
    std::unordered_map<BlockHash, TraceInfo> traces;
    gzFile gz;

    BlockedLocationGenerator(const std::string &bbtrace_path,
                             const std::string &bbhist_path,
                             const std::string &locmap_path,
                             LocHist &lochist)
    {
        const auto blockhash_to_insts = parseBBHist(bbhist_path);
        const auto locmap = parseLocmap(locmap_path);

        // Populate traces.
        for (const auto &[blockhash, insts] : blockhash_to_insts) {
            auto &trace = traces[blockhash];
            assert(trace.empty());
            for (InstAddr inst : insts) {
                const auto locmap_it = locmap.find(inst);
                if (locmap_it != locmap.end()) {
                    const std::string &loc = locmap_it->second;
                    const auto lochist_it = lochist.find(loc);
                    if (lochist_it != lochist.end()) {
                        LocCount *p = &lochist_it->second;
                        trace.push_back(p);
                    }
                }
            }
        }

        // Open bbtrace.
        gz = gzopen(bbtrace_path.c_str(), "rb");
        if (!gz) {
            std::cerr << "failed to open " << bbtrace_path << "\n";
            std::exit(1);
        }
    }

    // TODO: Why do we even need this move operator?
    BlockedLocationGenerator(BlockedLocationGenerator &&o)
        : traces(std::move(o.traces)), gz(o.gz)
    {
        o.gz = nullptr;
    }

    ~BlockedLocationGenerator()
    {
        if (gz)
            gzclose(gz);
    }

    TraceInfo *
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

struct LocationGenerator
{
    BlockedLocationGenerator gen;
    TraceInfo *block = nullptr;
    TraceInfo::iterator it;

    template <typename... Args>
    LocationGenerator(Args&&... args)
        : gen(std::forward<Args>(args)...)
    {
    }

    LocCount *
    next()
    {
      start:
        while (!block || it == block->end()) {
            block = gen.next();
            if (!block)
                return nullptr;
            it = block->begin();
        }
        assert(block);
        assert(!block->empty());
        assert(it != block->end());
        if (!**it) {
            ++it;
            goto start;
        }
        LocCount *p = *it;
        ++it;
        assert(p);
        return p;
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
    std::string lochist;
};

static Arguments parse_args(int argc, char* argv[]) {
    Arguments args;
    std::string flag;
    for (int i = 1; i < argc; ++i) {
        std::string s(argv[i]);
        if (s == "--bbtraces" || s == "--bbhists" || s == "--locmaps" || s == "--lochist") {
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

    // Parse lochist.
    auto lochist = parseLochist(args.lochist);

    // Instantiate generators.
    std::vector<LocationGenerator> gens;
    for (std::size_t i = 0; i < args.bbtraces.size(); ++i)
        gens.emplace_back(args.bbtraces[i], args.bbhists[i], args.locmaps[i], lochist);

    // Main loop.
    std::vector<LocCount *> locs;
    while (true) {
        locs.clear();
        for (auto &gen : gens)
            locs.push_back(gen.next());
        if (!locs[0]) {
            for (LocCount *p : locs)
                assert(!p);
            break;
        }
        const bool deactivate = std::any_of(locs.begin() + 1, locs.end(), [&] (auto x) { return x != locs.front(); });
        if (deactivate) {
            for (LocCount *p : locs)
                *p = 0;
        }
    }

    // Print out filtered lochist.
    for (const auto &[loc, count] : lochist) {
        if (count)
            std::cout << std::dec << count << " " << loc << "\n";
    }
}
