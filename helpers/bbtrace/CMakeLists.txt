cmake_minimum_required(VERSION 3.16)
project(pincpu_trace_tools CXX)

set(CMAKE_CXX_STANDARD 20 REQUIRED)

find_package(ZLIB REQUIRED)
find_library(XXHASH_LIB xxhash REQUIRED)

add_executable(trace-align-faster trace-align-faster.cc)
target_link_libraries(trace-align-faster PRIVATE ZLIB::ZLIB ${XXHASH_LIB})

add_executable(trace-filter-waypoints trace-filter-waypoints.cc)
target_link_libraries(trace-filter-waypoints PRIVATE ZLIB::ZLIB ${XXHASH_LIB})

add_executable(trace-align-best trace-align-best.cc)
target_link_libraries(trace-align-best PRIVATE ZLIB::ZLIB ${XXHASH_LIB} edlib)

add_executable(error error.cc)
