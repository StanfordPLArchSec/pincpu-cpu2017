#pragma once

#include <string>
#include <cstdlib>
#include <vector>
#include <cstdint>

using Addr = uint64_t;

// TODO: Make these private.
struct Loc
{
    std::size_t id;
    std::string value;

    Loc(std::size_t id, const std::string &value)
        : id(id), value(value)
    {
    }
};
using LocRef = Loc *;

struct Inst
{
    std::size_t id;
    Addr value;

    Inst(std::size_t id, Addr value)
        : id(id), value(value)
    {
    }
};
using InstRef = Inst *;

class LocSet
{
  public:
    LocSet(std::vector<bool> &&bv)
        : bv(bv)
    {
    }

    bool
    contains(Loc *loc) const
    {
        if (loc->id >= bv.size())
            return false;
        return bv[loc->id];
    }

  private:
    const std::vector<bool> bv;
};

class LocMap
{
  public:
    LocMap(std::vector<LocRef> &&vec)
        : vec(vec)
    {
    }

    LocRef
    operator[](InstRef inst) const
    {
        if (inst->id >= vec.size())
            return nullptr;
        return vec[inst->id];
    }

  private:
    const std::vector<LocRef> vec;
};

LocRef getLocRef(const std::string &loc);
InstRef getInstRef(Addr inst);
LocSet parseLochist(const std::string &path);
LocMap parseLocmap(const std::string &path);

