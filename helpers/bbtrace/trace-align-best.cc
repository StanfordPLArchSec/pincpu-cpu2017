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
#include <edlib.h>
#include <gperftools/profiler.h>

using InstAddr = uint64_t;
using InstCount = std::size_t;
using BlockHash = uint32_t;
using Loc = std::string;
using Op = std::string;

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
    const Op *op;

    InstInfo(InstAddr addr, const Loc *loc, const Op *op)
        : addr(addr), loc(loc), op(op)
    {
    }
};

using TraceInfo = std::vector<InstInfo>;

const Op *
internOp(std::string &&op)
{
    static std::unordered_set<std::string> ops;
    const auto it = ops.insert(std::move(op)).first;
    return &*it;
}

using OpMap = std::unordered_map<InstAddr, const Op *>;
static OpMap
parseOpmap(const std::string &path)
{
    std::ifstream in(path);
    if (!in) {
        std::cerr << "failed to open " << path << "\n";
        std::exit(1);
    }

    OpMap result;
    InstAddr inst;
    std::string op;
    while (in >> std::hex >> inst >> op)
        result[inst] = internOp(std::move(op));

    return result;
}

struct BlockGenerator
{
    std::unordered_map<BlockHash, TraceInfo> traces;
    gzFile gz;

    BlockGenerator(const std::string &bbtrace_path,
                   const std::string &bbhist_path,
                   const std::string &locmap_path,
                   const std::string &opmap_path,
                   const LocSet &locset)
    {
        const auto blockhash_to_insts = parseBBHist(bbhist_path);
        const auto locmap = parseLocmap(locmap_path);
        const auto opmap = parseOpmap(opmap_path);

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
                trace.emplace_back(inst, locp, opmap.at(inst));
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

static std::vector<int>
getExpAlignment(const std::string &ref, const std::string &exp,
                const std::string_view &alignment)
{
    std::vector<int> exp_align;
    if (exp.empty()) {
        for (const auto &x : ref)
            exp_align.push_back(-1);
        return exp_align;
    }
    
    auto ref_it = ref.begin();
    auto exp_it = exp.begin();
    for (const char directive : alignment) {
        switch (directive) {
          case 0: // match
          case 3: // mismatch
            assert(ref_it != ref.end());
            assert(exp_it != exp.end());
            exp_align.push_back(exp_it - exp.begin());
            ++ref_it;
            ++exp_it;
            break;

          case 2: // insertion into exp
            assert(exp_it != exp.end());
            ++exp_it;
            break;
            
          case 1: // insertion into ref
            assert(ref_it != ref.end());
            exp_align.push_back(-1);
            ++ref_it;
            break;

          default:
            std::cerr << "bad edlib opcode\n";
            std::abort();
        }
    }

    assert(exp_align.size() == ref.size());

    return exp_align;
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
    std::vector<std::string> opmaps;
    std::string lochist;
    bool compress = false;
};

static Arguments parse_args(int argc, char* argv[]) {
    Arguments args;
    std::string flag;
    for (int i = 1; i < argc; ++i) {
        std::string s(argv[i]);
        if (s == "--compress") {
            args.compress = true;
        }
        else if (s == "--bbtraces" || s == "--bbhists" || s == "--locmaps" || s == "--lochist" || s == "--opmaps") {
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
            else if (flag == "--opmaps") {
                args.opmaps.push_back(s);
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

template <typename Print>
void
work(const auto &args, Print print)
{
    const std::size_t n = args.bbtraces.size();

    // Parse lochist.
    const auto locset = parseLochist(args.lochist);

    // Instantiate generators.
    std::vector<BatchGenerator> gens;
    for (std::size_t i = 0; i < n; ++i)
        gens.emplace_back(args.bbtraces[i], args.bbhists[i],
                          args.locmaps[i], args.opmaps[i], locset);

    // Main loop.
    std::vector<std::vector<const InstInfo *>> chunks(n);
    std::vector<InstCount> instcounts(n, 0);
    std::vector<const Op *> ops;
    std::vector<std::string> seqs(n);
    std::vector<std::vector<int>> subaligns(n - 1);
    while (true) {
        for (std::size_t i = 0; i < gens.size(); ++i) {
            auto &gen = gens[i];
            auto &chunk = chunks[i];
            chunk.clear();
            if (!gen.next(std::back_inserter(chunk)))
                goto done;
        }

        // Are these all located singletons?
        const Loc *singleton_loc;
        auto &ref_chunk = chunks[0];
        if (!ref_chunk.empty() && (singleton_loc = ref_chunk[0]->loc)) {
            for (const auto &chunk : chunks) {
                assert(chunk.size() == 1);
                assert(chunk[0]->loc == singleton_loc);
            }

            // Print out the trace: addr1 count1 ... addrn countn.
            for (std::size_t i = 0; i < chunks.size(); ++i) {
                const auto &chunk = chunks[i];
                print.print(chunk[0]->addr, instcounts[i]);
            }
            print.newline();
        } else if (ref_chunk.empty()) {
            // If the reference block is empty, then skip.
        } else {
            // Otherwise, we need to match these somehow.
            // First, collect the set of opcodes.
            ops.clear();
            for (const auto &chunk : chunks)
                for (const InstInfo *x : chunk)
                    ops.push_back(x->op);
            std::sort(ops.begin(), ops.end());
            ops.erase(std::unique(ops.begin(), ops.end()), ops.end());

            const auto op_to_char = [&ops] (const Op *op) -> char {
                static const char s[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMOPQRSTUVWXYZ";
                assert(ops.size() <= sizeof s);
                const auto ops_it = std::lower_bound(ops.begin(), ops.end(), op);
                assert(ops_it != ops.end());
                assert(*ops_it == op);
                const std::size_t idx = ops_it - ops.begin();
                return s[idx];
            };

            // Map each chunk to opcodes.
            for (std::size_t i = 0; i < gens.size(); ++i) {
                auto &seq = seqs[i];
                seq.clear();
                const auto &chunk = chunks[i];
                for (const InstInfo *x : chunk)
                    seq.push_back(op_to_char(x->op));
            }

            // Align each chunk using edlib.
            const auto &seq_ref = seqs[0];
            EdlibAlignConfig conf = edlibDefaultAlignConfig();
            conf.task = EDLIB_TASK_PATH;
            for (std::size_t i = 1; i < seqs.size(); ++i) {
                const auto &seq_exp = seqs[i];
                const auto result = edlibAlign(seq_ref.data(), seq_ref.size(),
                                               seq_exp.data(), seq_exp.size(), conf);
#if 0
                std::cerr << seq_ref << " " << seq_exp << " " << result.editDistance
                          << " ";
                for (std::size_t i = 0; i < result.alignmentLength; ++i)
                    std::cerr << (int) result.alignment[i];
                std::cerr << "\n";
#endif
                 const std::string_view alignment_str(
                    reinterpret_cast<const char *>(result.alignment),
                    std::size_t(result.alignmentLength));
                subaligns[i - 1] = getExpAlignment(seq_ref, seq_exp, alignment_str);
                edlibFreeAlignResult(result);
            }

            // For each ref subalignment position, if the exps were successfully aligned,
            // then print those out.
            for (std::size_t i = 0; i < ref_chunk.size(); ++i) {
                const bool valid = std::all_of(
                    subaligns.begin(), subaligns.end(), [i] (const auto &subalign) -> bool {
                        return subalign[i] >= 0;
                    });
                if (valid) {
                    // Print out ref addr and count.
                    const InstInfo *ref_x = ref_chunk[i];
                    print.print(ref_x->addr, instcounts[0] + i);

                    // Print out addr and count.
                    for (std::size_t j = 1; j < n; ++j) {
                        const auto &subalign = subaligns[j - 1];
                        const int idx = subalign[i];
                        const auto &chunk = chunks[j];
                        const InstInfo *exp_x = chunk[idx];
                        print.print(exp_x->addr, instcounts[j] + idx);
                    }
                    print.newline();
                }
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

struct FullPrinter
{
    bool first = true;

    void
    print(InstAddr addr, InstCount count)
    {
        if (first) {
            first = false;
        } else {
            std::cout << " ";
        }
        std::cout << std::hex << addr << " " << std::dec << count;
    }

    void
    newline()
    {
        std::cout << "\n";
        first = true;
    }
};

struct CompressedPrinter
{
    std::vector<InstCount> prev;
    std::size_t i = 0;
    gzFile gz;

    CompressedPrinter(std::size_t n)
        : prev(n, 0)
    {
        gz = gzdopen(fileno(stdout), "wb");
        if (!gz) {
            std::cerr << "failed to open gzip stdout\n";
            std::exit(1);
        }
    }

    ~CompressedPrinter()
    {
        gzclose(gz);
    }

    void
    print(InstAddr addr, InstCount cur)
    {
        assert(i < prev.size());
        if (i > 0)
            gzprintf(gz, " ");
        const InstCount delta = cur - prev[i];
        gzprintf(gz, "%d", delta);
        prev[i] = cur;
        ++i;
    }

    void
    newline()
    {
        gzprintf(gz, "\n");
        i = 0;
    }
};

int
main(int argc, char *argv[])
{
    ProfilerStart("best.prof");
    auto args = parse_args(argc, argv);

    const std::size_t n = args.bbtraces.size();

    if (args.compress) {
        work(args, CompressedPrinter(n));
    } else {
        work(args, FullPrinter());
    }
}
