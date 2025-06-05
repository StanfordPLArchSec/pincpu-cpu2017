// trace_align.cpp
// Requires: C++23, GCC 15 or newer (for std::generator)
// Compile with: g++ -std=c++23 trace_align.cpp -o trace_align -lxxhash -lz

#include <generator>         // for std::generator
#include <coroutine>
#include <optional>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <zlib.h>            // for gzFile, gzopen, gzread, gzclose
#include <xxhash.h>          // for XXH32
#include <gperftools/profiler.h>
#include <cassert>
#include <absl/container/flat_hash_map.h>

#include "tracelib.hh"


// --------------------------------------------------------------------------------
// Utility: split a comma‐separated string into a vector<string>
// --------------------------------------------------------------------------------
static std::vector<std::string> split_commas(const std::string& s) {
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

// --------------------------------------------------------------------------------
// insttrace: generator<string>
//  - Build a map from BB‐hash → vector<inst> by reading bbhist_path (plaintext).
//  - Then open bbtrace_path (gzip) and read 4 bytes at a time (littleendian).
//  - Look up that 32‐bit hash in block_to_insts, then co_yield each inst.
// --------------------------------------------------------------------------------
std::generator<InstRef>
insttrace(const std::string& bbtrace_path, const std::string& bbhist_path) {
    // 1) Parse BB‐history file into a map: hash → vector<inst>
    absl::flat_hash_map<uint32_t, std::vector<InstRef>> block_to_insts;
    {
        std::ifstream in(bbhist_path);
        if (!in) {
            throw std::runtime_error("Failed to open BB‐history file: " + bbhist_path);
        }
        std::string line;
        while (std::getline(in, line)) {
            if (line.empty()) continue;
            std::istringstream iss(line);
            std::string count_s, block;
            iss >> count_s >> block;
            // Compute xxhash32(block)
            uint32_t h = XXH32(block.data(), block.size(), 0);
            if (block_to_insts.count(h)) {
                throw std::runtime_error("Duplicate block hash detected in BB‐history: " + block);
            }
            std::vector<InstRef> block_int;
            for (const std::string &inst : split_commas(block))
                block_int.push_back(getInstRef(std::stoull(inst, nullptr, 16)));
            block_to_insts[h] = std::move(block_int);
        }
    }

    // 2) Open the gzip‐compressed BB‐trace and read in 4‐byte chunks
    gzFile gz = gzopen(bbtrace_path.c_str(), "rb");
    if (!gz) {
        throw std::runtime_error("Failed to open gzip BB‐trace: " + bbtrace_path);
    }

    while (true) {
        unsigned char buf[4];
        int bytes_read = gzread(gz, buf, 4);
        if (bytes_read != 4) break;  // reached EOF or incomplete chunk
        // Interpret as little‐endian uint32_t
        uint32_t block_hash =
            static_cast<uint32_t>(buf[0]) |
            (static_cast<uint32_t>(buf[1]) << 8) |
            (static_cast<uint32_t>(buf[2]) << 16) |
            (static_cast<uint32_t>(buf[3]) << 24);

        auto it = block_to_insts.find(block_hash);
        if (it == block_to_insts.end()) {
            gzclose(gz);
            throw std::runtime_error("Block hash not found in BB‐history: " + std::to_string(block_hash));
        }
        for (const auto& inst : it->second) {
            co_yield inst;
        }
    }

    gzclose(gz);
    co_return;
}

// --------------------------------------------------------------------------------
// instloctrace: generator<pair<string, optional<string>>>
//  - For each inst from insttrace(...):
//      • Lookup locmap[inst] (if present) → loc.
//      • If loc is in lochist, yield {inst, loc}, else yield {inst, nullopt}.
// --------------------------------------------------------------------------------
std::generator<std::pair<InstRef, std::optional<LocRef>>>
instloctrace(const LocSet &lochist,
             const std::string& bbtrace_path,
             const std::string& bbhist_path,
             const std::string& locmap_path)
{
    auto locmap = parseLocmap(locmap_path);

    for (auto inst : insttrace(bbtrace_path, bbhist_path)) {
        std::optional<LocRef> loc_opt;
        // HOT: This is where ~78% of the runtime is spent.
        if (LocRef loc = locmap[inst]) {
            if (lochist.contains(loc)) {
                loc_opt = loc;
            }
        }
        co_yield std::make_pair(std::move(inst), std::move(loc_opt));
    }
    co_return;
}

// --------------------------------------------------------------------------------
// loctrace_with_instcount: generator<pair<string, size_t>>
//  - Walk instloctrace(...), keep a running inst_count.
//  - Whenever loc_opt.has_value(), yield {inst, inst_count}.
//  - After exhausting, assert inst_count>0 and yield {last_inst, inst_count}.
// --------------------------------------------------------------------------------
std::generator<std::pair<Addr, size_t>>
loctrace_with_instcount(const LocSet &lochist,
                        const std::string& bbtrace_path,
                        const std::string& bbhist_path,
                        const std::string& locmap_path)
{
    size_t inst_count = 0;
    Addr last_inst;

    for (auto [inst_ref, loc_opt] : instloctrace(lochist, bbtrace_path, bbhist_path, locmap_path)) {
        const Addr inst = inst_ref->value;
        last_inst = inst;
        if (loc_opt.has_value()) {
            co_yield std::make_pair(inst, inst_count);
        }
        ++inst_count;
    }

    if (inst_count == 0) {
        throw std::runtime_error("Empty trace in loctrace_with_instcount.");
    }
    // Yield final (last_inst, inst_count) just like the Python version
    co_yield std::make_pair(last_inst, inst_count);
    co_return;
}

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

int main(int argc, char* argv[]) {
    ProfilerStart("fast.prof");
    try {
        auto args = parse_args(argc, argv);

        // 1) Load lochist into an unordered_set
        auto lochist = parseLochist(args.lochist);

        // 2) Create one generator per triple (bbtrace, bbhist, locmap)
        size_t N = args.bbtraces.size();
        using PairType = std::pair<Addr, size_t>;

        std::vector<std::generator<PairType>> gens;
        gens.reserve(N);
        for (size_t i = 0; i < N; ++i) {
            gens.push_back(
                loctrace_with_instcount(
                    lochist,
                    args.bbtraces[i],
                    args.bbhists[i],
                    args.locmaps[i]
                )
            );
        }

        // 3) Obtain iterators & ends for each generator

        // 1) Deduce iterator and sentinel types:
        using Iter = decltype( gens[0].begin() );
        using Sent = decltype( gens[0].end() );

        // 2) Make your vectors of those types:
        std::vector<Iter>   its;   its.reserve(N);
        std::vector<Sent>   ends;  ends.reserve(N);
        std::vector<bool>   done;  done.reserve(N);

        // 3) Initialize by calling .begin() and .end():
        for (size_t i = 0; i < N; ++i) {
          its.push_back(  gens[i].begin() );
          ends.push_back( gens[i].end()   );
          done.push_back( its[i] == ends[i] );  // now comparing Iter vs. Sent is valid
        }
        // 4) Zip‐in‐lockstep
        while (true) {
            bool all_done = true;
            bool any_done = false;
            for (size_t i = 0; i < N; ++i) {
                if (done[i]) {
                    any_done = true;
                } else {
                    all_done = false;
                }
            }
            if (all_done) {
                // All generators reached end simultaneously → done
                break;
            }
            if (any_done && !all_done) {
                std::cerr << "Error: generator lengths do not match exactly.\n";
                return EXIT_FAILURE;
            }

            // Collect & print the current (inst, count) from each generator
            for (size_t i = 0; i < N; ++i) {
                const auto& [inst, count] = *its[i];
                std::cout << inst << ' ' << count;
                if (i + 1 < N) std::cout << ' ';
            }
            std::cout << '\n';

            // Advance all iterators
            for (size_t i = 0; i < N; ++i) {
                ++its[i];
                done[i] = (its[i] == ends[i]);
            }
        }

        return EXIT_SUCCESS;
    }
    catch (const std::exception& ex) {
        std::cerr << "Fatal error: " << ex.what() << "\n";
        return EXIT_FAILURE;
    }
}
