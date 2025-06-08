#include <iostream>
#include <cstdlib>
#include <string>
#include <fstream>
#include <sstream>
#include <vector>
#include <cassert>
#include <gperftools/profiler.h>

struct CompressedTraceStream
{
    std::ifstream in;

    CompressedTraceStream(const std::string &path)
    {
        in.open(path);
        if (!in) {
            std::cerr << "error: failed to open file: " << path << "\n";
            std::exit(1);
        }
    }

    bool
    next(std::vector<int> &v)
    {
        assert(v.empty());

        std::string line;
        std::getline(in, line);
        if (!in)
            return false;
        assert(!line.empty());
        std::istringstream is(line);
        int delta;
        while (is >> delta)
            v.push_back(delta);
        assert(!v.empty());
        return true;
    }
};

int main(int argc, char *argv[]) {
    ProfilerStart("error.prof");

    if (argc != 3) {
        std::cerr << "usage: " << argv[0] << " reftrace exptrace\n";
        return EXIT_FAILURE;
    }

    const std::string ref_path = argv[1];
    const std::string exp_path = argv[2];

    // DEBUG
    CompressedTraceStream ref_stream(ref_path);
    std::vector<int> ref_deltas;
    while (ref_stream.next(ref_deltas)) {
        for (int i : ref_deltas)
            printf("%d ", i);
        printf("\n");
        ref_deltas.clear();
    }
}
