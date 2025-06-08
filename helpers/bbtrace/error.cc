#include <iostream>
#include <cstdlib>
#include <string>
#include <fstream>
#include <sstream>
#include <vector>
#include <cassert>
#include <cstring>
#include <cstdio>
#include <err.h>
#include <cstdint>
#include <unordered_map>
#include <set>
#include <gperftools/profiler.h>

using InstCount = std::uint64_t;
using SignedInstCount = std::int64_t;

struct CompressedTraceStream
{
    FILE *in;
    std::vector<InstCount> v;

    CompressedTraceStream(const std::string &path, std::size_t n)
        : v(n)
    {
        if ((in = std::fopen(path.c_str(), "r")) == nullptr)
            err(EXIT_FAILURE, "fopen");
    }        

    const std::vector<InstCount> *
    next()
    {
        char line[256];
        if (!std::fgets(line, sizeof line, in)) {
            if (std::feof(in))
                return nullptr;
            err(EXIT_FAILURE, "fgets");
        }

        char *s = line;
        for (auto it = v.begin(); it != v.end(); ++it) {
            const char *token = strsep(&s, " ");
            assert(token);
            *it = std::atoi(token);
        }

        return &v;
    }
};

struct AlignStream
{
    CompressedTraceStream in;
    std::vector<InstCount> prev;

    AlignStream(const std::string &path, std::size_t n)
        : in(path, n), prev(n, 0)
    {
    }

    const std::vector<InstCount> *
    next()
    {
        const auto *delta = in.next();
        if (!delta)
            return nullptr;

        assert(delta->size() == prev.size());

        std::transform(prev.begin(), prev.end(), delta->begin(),
                       prev.begin(), std::plus<InstCount>());

        return &prev;
    }
};

struct Bound
{
    std::vector<InstCount> ref_begin;
    std::vector<InstCount> ref_end;
    std::vector<InstCount> exp;
    InstCount weight = 0;

    Bound(std::size_t n)
        : ref_begin(n, 0),
          ref_end(n, 0),
          exp(n, 0)
    {
    }
};

struct BoundStream
{
    AlignStream &ref_stream;
    AlignStream &exp_stream;
    Bound bound;

    BoundStream(AlignStream &ref_stream, AlignStream &exp_stream, std::size_t n)
        : ref_stream(ref_stream), exp_stream(exp_stream), bound(n)
    {
    }

    const Bound *
    next()
    {
        // Get the next exp.
        const auto *exp_ptr = exp_stream.next();
        if (!exp_ptr)
            return nullptr;
        const auto &exp = *exp_ptr;

        // Shift the reference interval if needed.
        while (exp[0] > bound.ref_end[0]) {
            bound.ref_begin = bound.ref_end;
            const auto *ref_ptr = ref_stream.next();
            assert(ref_ptr); // TODO: Check in python if we can do this too. There, we return.
            bound.ref_end = *ref_ptr;
        }

        assert(bound.ref_begin[0] <= exp[0] && exp[0] <= bound.ref_end[0]);

        bound.weight = exp[0] - bound.exp[0];
        bound.exp = exp;

        return &bound;
    }
};

static InstCount
computeSingleError(InstCount a, InstCount b)
{
    if (a < b) {
        return b - a;
    } else {
        return a - b;
    }
}

static void
computeErrorExact(const std::vector<InstCount> &ref,
                  const std::vector<InstCount> &exp,
                  std::vector<InstCount> &out)
{
    assert(ref[0] == exp[0]);
    assert(ref.size() == exp.size());
    assert(out.size() == ref.size() - 1);

    std::transform(ref.begin() + 1, ref.end(), exp.begin() + 1, out.begin(), computeSingleError);
}

static void
computeErrorApprox(const Bound &block, std::vector<InstCount> &out)
{
    for (std::size_t i = 1; i < block.exp.size(); ++i) {
        const InstCount left_err = computeSingleError(block.ref_begin[i], block.exp[i]);
        const InstCount right_err = computeSingleError(block.ref_end[i], block.exp[i]);
        out[i - 1] = std::max(left_err, right_err);
    }
}

static void
computeError(const Bound &block, std::vector<InstCount> &out)
{
    assert(out.size() == block.exp.size() - 1);

    if (block.ref_begin[0] == block.exp[0]) {
        computeErrorExact(block.ref_begin, block.exp, out);
    } else if (block.ref_end[0] == block.exp[0]) {
        computeErrorExact(block.ref_end, block.exp, out);
    } else {
        computeErrorApprox(block, out);
    }
}

using ErrHist = std::unordered_map<InstCount, std::size_t>;

static InstCount
work(BoundStream &bound_stream, std::size_t n, std::vector<ErrHist> &errhists)
{
    std::vector<InstCount> error(n - 1);
    InstCount ref_instcount = 0;
    while (const Bound *bound = bound_stream.next()) {
#if 0
        const auto print_arr = [] (const auto &v) {
            bool first = true;
            for (InstCount x : v) {
                if (!first)
                    printf(",");
                printf("%lu", x);
                first = false;
            }
        };
        printf("ref_begin=");
        print_arr(bound->ref_begin);
        printf(" ref_end=");
        print_arr(bound->ref_end);
        printf(" exp=");
        print_arr(bound->exp);
        printf(" weight=%lu\n", bound->weight);
#endif

        ref_instcount = bound->ref_end[0];

        // Compute error.
        computeError(*bound, error);

#if 0
        // Print out the errhist (same as --errhist python option).
        printf("%lu %lu", bound->weight, bound->exp[0]);
        for (InstCount x : error)
            printf(" %lu", x);
        printf("\n");
#endif

        // Update the histograms.
        for (std::size_t i = 0; i < n - 1; ++i)
            errhists[i][error[i]] += bound->weight;
    }

    return ref_instcount;
}

int main(int argc, char *argv[]) {
    ProfilerStart("error.prof");

    if (argc != 4) {
        std::cerr << "usage: " << argv[0] << " n reftrace exptrace\n";
        return EXIT_FAILURE;
    }

    const std::size_t n = std::atoi(argv[1]);
    const std::string ref_path = argv[2];
    const std::string exp_path = argv[3];

    AlignStream ref_stream(ref_path, n);
    AlignStream exp_stream(exp_path, n);
    BoundStream bound_stream(ref_stream, exp_stream, n);
    std::vector<ErrHist> errhists(n - 1);

    const InstCount ref_instcount = work(bound_stream, n, errhists);

    // Dump the histograms.
    std::set<InstCount> errhist_keys;
    for (const auto &errhist : errhists)
        for (const auto &[key, _] : errhist)
            errhist_keys.insert(key);
    for (InstCount error : errhist_keys) {
        printf("%lu", error);
        for (const auto &errhist : errhists) {
            const auto it = errhist.find(error);
            if (it == errhist.end()) {
                printf(" -");
            } else {
                const double weight = it->second;
                const auto norm_weight = weight / ref_instcount;
                printf(" %f", norm_weight);
            }
        }
        printf("\n");
    }

#if 0
    for (std::size_t i = 0; i < n - 1; ++i) {
        for (const auto &[error, weight] : errhists[i]) {
            const double norm_weight = static_cast<double>(weight) / ref_instcount;
            printf("%zu %lu %f\n", i, error, norm_weight);
        }
    }
#endif

#if 0
    // DEBUG
    while (const std::vector<InstCount> *ref_deltas = ref_stream.next()) {
        for (int i : *ref_deltas)
            printf("%d ", i);
        printf("\n");
    }
    while (const std::vector<InstCount> *exp_deltas = exp_stream.next()) {
        for (int i : *exp_deltas)
            printf("%d ", i);
        printf("\n");
    }
#endif
}
