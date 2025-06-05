#include "tracelib.hh"

#include <unordered_map>
#include <fstream>
#include <sstream>
#include <cassert>

static std::unordered_map<std::string, Loc> locs;
static std::unordered_map<Addr, Inst> insts;

LocRef
getLocRef(const std::string &loc)
{
    return &locs.emplace(loc, Loc(locs.size(), loc)).first->second;
}

InstRef
getInstRef(Addr inst)
{
    return &insts.emplace(inst, Inst(insts.size(), inst)).first->second;
}

LocSet
parseLochist(const std::string &path)
{
    std::ifstream in(path);
    if (!in)
        throw std::runtime_error("Failed to open lochist file: " + path);        
    
    std::vector<bool> lochist;
    std::string line;
    while (std::getline(in, line)) {
        if (line.empty())
            continue;
        std::istringstream iss(line);
        std::string count, loc;
        iss >> count >> loc;
        assert(!loc.empty());

        auto it = getLocRef(loc);
        if (it->id >= lochist.size())
            lochist.resize(it->id + 1);
        lochist[it->id] = true;
    }
    return LocSet(std::move(lochist));
}

LocMap
parseLocmap(const std::string &path)
{
    std::ifstream in(path);
    if (!in) {
        throw std::runtime_error("Failed to open locmap file: " + path);
    }
    std::vector<LocRef> locmap;
    std::string line;
    while (std::getline(in, line)) {
        if (line.empty())
            continue;
        std::istringstream iss(line);
        Addr inst;
        std::string loc;
        iss >> std::hex >> inst >> loc;
        assert(inst);
        assert(!loc.empty());

        auto it = getInstRef(inst);
        if (it->id >= locmap.size())
            locmap.resize(it->id + 1);
        locmap[it->id] = getLocRef(loc);
    }
    return LocMap(std::move(locmap));
}
