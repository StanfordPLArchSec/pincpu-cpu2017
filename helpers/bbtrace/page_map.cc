#include "page_map.hh"

#include <csignal>
#include <vector>

static sigaction old_segv_handler;
static std::vector<void **> maps;

static template <typename T **>
createMap()
{
    

}
