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

    TraceGenerator(TraceGenerator &&other)
        : traces(std::move(other.traces)),
          gz(other.gz)
    {
        other.gz = nullptr;
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

struct CountedInstGenerator
{
    TraceGenerator trace_generator;
    const TraceInfo *trace_info = nullptr;
    std::size_t i = 0;
    InstCount total_inst_count = 0;

    template <typename... Args>
    CountedInstGenerator(Args&&... args)
        : trace_generator(std::forward<Args>(args)...)
    {
    }

    bool 
    next(InstAddr &inst_addr, InstCount &inst_count)
    {
        while (!trace_info || i == trace_info->insts.size()) {
            const TraceInfo *new_trace_info = trace_generator.next();
            if (!new_trace_info)
                return false;
            if (trace_info)
                total_inst_count += trace_info->size;
            trace_info = new_trace_info;
            i = 0;
        }
        assert(trace_info);
        assert(!trace_info->insts.empty());
        assert(i < trace_info->insts.size());
        const auto &p = trace_info->insts[i];
        inst_addr = p.first;
        inst_count = total_inst_count + p.second;
        ++i;
        return true;
    }
};

struct DeltaInstGenerator
{
    CountedInstGenerator gen;
    InstCount prev_inst_count = 0;

    template <typename... Args>
    DeltaInstGenerator(Args&&... args)
        : gen(std::forward<Args>(args)...)
    {
    }

    bool
    next(InstAddr &inst_addr, InstCount &delta_inst_count)
    {
        InstCount cur_inst_count;
        if (!gen.next(inst_addr, cur_inst_count))
            return false;
        delta_inst_count = cur_inst_count - prev_inst_count;
        prev_inst_count = cur_inst_count;
        return true;
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
    bool compress = false;
};

static Arguments parse_args(int argc, char* argv[]) {
    Arguments args;
    std::string flag;
    for (int i = 1; i < argc; ++i) {
        std::string s(argv[i]);
        if (s == "--compress") {
            args.compress = true;
            flag.clear();
        } else if (s == "--bbtraces" || s == "--bbhists" || s == "--waypoints") {
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

template <typename Generator>
void
work(const auto &args, auto printf, auto out)
{
    std::vector<Generator> generators;
    for (std::size_t i = 0; i < args.bbtraces.size(); ++i)
        generators.emplace_back(args.bbtraces[i], args.bbhists[i], args.waypoints[i]);

    while (true) {
        bool first = true;
        for (auto &generator : generators) {
            InstAddr inst_addr;
            InstCount inst_count;
            if (!generator.next(inst_addr, inst_count))
                goto done;
            if (!first)
                printf(out, " ");
            if (!args.compress)
                printf(out, "%" PRIx64 " ", inst_addr);
            printf(out, "%zu", inst_count);
            first = false;
        }
        printf(out, "\n");
    }

  done:

    // Ensure that all generators were depleted.
    for (auto &generator : generators) {
        InstAddr inst_addr;
        InstCount inst_count;
        if (generator.next(inst_addr, inst_count)) {
            std::cerr << "generator not done\n";
            std::abort();
        }
    }
}


int
main(int argc, char *argv[])
{
    auto args = parse_args(argc, argv);

    if (args.compress) {
        gzFile gz = gzdopen(fileno(stdout), "wb");
        work<DeltaInstGenerator>(args, gzprintf, gz);
        gzclose(gz);
    } else {
        work<CountedInstGenerator>(args, fprintf, stdout);
    }
}
