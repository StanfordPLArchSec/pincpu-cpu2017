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
#include <zlib.h>
#include <err.h>

using InstAddr = uint64_t;
using InstCount = std::size_t;
using BlockHash = uint32_t;

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

static std::unordered_set<InstAddr>
parseWaypoints(const std::string &path)
{
    std::unordered_set<InstAddr> set;
    std::ifstream f(path);
    if (!f) {
        std::cerr << "failed to open " << path << "\n";
        std::exit(1);
    }
    InstAddr inst;
    while (f >> std::hex >> inst)
        set.insert(inst);
    return set;
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

struct TraceInfo
{
    std::vector<std::pair<InstAddr, InstCount>> insts;
    std::size_t size = 0;

    bool valid() const { return size; }
    operator bool() const { return valid(); }
};

struct TraceGenerator
{
    static inline constexpr std::size_t tracelen = std::size_t(std::numeric_limits<BlockHash>::max()) + 1;
    std::unordered_map<BlockHash, TraceInfo> traces;
    gzFile gz;

    TraceGenerator(const std::string &bbtrace_path,
                   const std::string &bbhist_path,
                   const std::string &waypoints_path)
    {
        const auto waypoints = parseWaypoints(waypoints_path);
        const auto blockhash_to_insts = parseBBHist(bbhist_path);

        // Populate traces.
        for (const auto &[blockhash, insts] : blockhash_to_insts) {
            auto &trace = traces[blockhash];
            for (std::size_t i = 0; i < insts.size(); ++i) {
                const InstAddr inst = insts[i];
                if (waypoints.contains(inst))
                    trace.insts.emplace_back(inst, i);
            }
            trace.size = insts.size();
        }

        // Open bbtrace.
        gz = gzopen(bbtrace_path.c_str(), "rb");
        if (!gz) {
            std::cerr << "failed to open " << bbtrace_path << "\n";
            std::exit(1);
        }
    }

    ~TraceGenerator()
    {
        gzclose(gz);
    }

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
    std::vector<std::string> waypoints;
    std::string lochist;
};

static Arguments parse_args(int argc, char* argv[]) {
    Arguments args;
    std::string flag;
    for (int i = 1; i < argc; ++i) {
        std::string s(argv[i]);
        if (s == "--bbtraces" || s == "--bbhists" || s == "--waypoints") {
            flag = s;
        } else if (!flag.empty()) {
            if (flag == "--bbtraces") {
                args.bbtraces.push_back(s);
            } else if (flag == "--bbhists") {
                args.bbhists.push_back(s);
            } else if (flag == "--waypoints") {
                args.waypoints.push_back(s);
            } else {
                throw std::runtime_error("Internal error: unrecognized flag state");
            }
        } else {
            throw std::runtime_error("Unexpected argument: " + s);
        }
    }

    if (args.bbtraces.empty() || args.bbhists.empty() || args.waypoints.empty()) {
        throw std::runtime_error("Must provide --bbtraces, --bbhists, --waypoints (each ≥1 file) and --lochist <file>");
    }
    if (args.bbtraces.size() != args.bbhists.size() ||
        args.bbtraces.size() != args.waypoints.size()) {
        throw std::runtime_error("Counts of bbtraces, bbhists, and locmaps must match exactly.");
    }
    return args;
}


int
main(int argc, char *argv[])
{
    auto args = parse_args(argc, argv);

    // DEBUG: Print out the first block stream.
    TraceGenerator test_gen(args.bbtraces[0], args.bbhists[0], args.waypoints[0]);
    while (const TraceInfo *trace = test_gen.next()) {
        std::cout << trace << "\n";
    }
}
