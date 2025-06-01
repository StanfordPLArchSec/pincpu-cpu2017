#pragma once

#include <sys/mman.h>
#include <err.h>
#include <cstdlib>

template <typename T>
class mmap_vector
{
  public:
    mmap_vector(std::size_t n)
    {
        const std::size_t unaligned_size = n * sizeof(T);
        len = ((unaligned_size - 1) | 0xfff) + 1;
        base = (T *) mmap(nullptr, len, PROT_READ | PROT_WRITE,
                          MAP_PRIVATE | MAP_ANON | MAP_NORESERVE,
                          -1, 0);
        if (base == MAP_FAILED)
            err(EXIT_FAILURE, "mmap");
    }

    ~mmap_vector()
    {
        if (munmap(base, len) < 0)
            err(EXIT_FAILURE, "munmap");
    }

    T &
    operator[](std::size_t index)
    {
        return base[index];
    }
    
  private:
    T *base;
    std::size_t len;
};
