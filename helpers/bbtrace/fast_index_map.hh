#pragma once

#include <array>
#include <bitset>
#include <cstdint>
#include <stdexcept>

template <typename T>
class FastIndexMap
{
  public:
    template <typename InputIt>
    FastIndexMap(InputIt first, InputIt last)
    {
        for (auto it = first; it != last; ++it) {
            const uint64_t key = it->first;
            const uint32_t hashed_key = hash(key);
            ValueType &value = vec[hashed_key];
            if (value)
                throw std::runtime_error("FastIndexMap key collision");
            value = std::make_pair(it->first, it->second);
        }
    }

    const T *
    find(uint64_t key) const
    {
        const uint32_t hashed_key = hash(key);
        const ValueType &value = vec[hashed_key];
        if (!value)
            return nullptr;
        if (value->first != key)
            throw std::runtime_error("FastIndexMap key collision");
        return &value->second;
    }

  private:
    using ValueType = std::optional<std::pair<uint64_t, T>>;
    std::array<ValueType, std::size_t(1) << 32> vec;

    static uint32_t
    hash(uint64_t index)
    {
        return static_cast<uint32_t>(index);
    }
};
