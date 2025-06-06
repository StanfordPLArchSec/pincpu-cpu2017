#pragma once

#include <utility>
#include <unordered_set>
#include <sys/mman.h>
#include <err.h>
#include <cstdlib>


/**
 * Approach: Split 64-bit keys/indices into a pair of 32-bit indices.
 */
template <typename T>
class PageMap
{
    static inline constexpr std::size_t dirsize = (std::size_t(1) << 32) * sizeof(T *);
  public:
    template <typename InputIt>
    PageMap(InputIt first, InputIt last)
    {
        // mmap directory.
        directory = (T **) mmap(nullptr, dirsize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON | MAP_NORESERVE, -1, 0);
        if (directory == MAP_FAILED)
            err(EXIT_FAILURE, "mmap");

        // Populate the table.
        for (Input it = first; it != last; ++it)
            populate(it->first, it->second);
    }

    ~PageMap()
    {
        if (munmap(directory, dirsize) < 0)
            err(EXIT_FAILURE, "munmap");
    }

  private:
    T **directory;

    T *&
    getWritableDir(uint64_t key)
    {
        return directory[key >> 32];
    }

    void
    populate(uint64_t key, const T &value)
    {
        T *&dirent = getWritableDir(key);
        if (!dirent) {
            
        }
    }
};
