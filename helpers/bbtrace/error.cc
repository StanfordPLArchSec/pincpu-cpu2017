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
#include <gperftools/profiler.h>

using InstCount = std::uint64_t;

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

int main(int argc, char *argv[]) {
    ProfilerStart("error.prof");

    if (argc != 4) {
        std::cerr << "usage: " << argv[0] << " n reftrace exptrace\n";
        return EXIT_FAILURE;
    }

    const std::size_t n = std::atoi(argv[1]);
    const std::string ref_path = argv[2];
    const std::string exp_path = argv[3];
    
    // DEBUG
    AlignStream ref_stream(ref_path, n);
    std::vector<InstCount> ref_deltas;
    while (const std::vector<InstCount> *ref_deltas = ref_stream.next()) {
        for (int i : *ref_deltas)
            printf("%d ", i);
        printf("\n");
    }
}
