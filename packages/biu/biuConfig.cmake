include("${CMAKE_CURRENT_LIST_DIR}/biuTargets.cmake")
find_package(magic_enum REQUIRED)
find_package(fmt REQUIRED)
find_package(Boost REQUIRED COMPONENTS headers iostreams filesystem system)
find_package(range-v3 REQUIRED)
find_path(NAMEOF_INCLUDE_DIR nameof.hpp REQUIRED)
find_package(Eigen3 REQUIRED)
find_package(HighFive REQUIRED)
find_path(ZPP_BITS_INCLUDE_DIR zpp_bits.h REQUIRED)
find_package(TgBot REQUIRED)
find_path(LIBBACKTRACE_INCLUDE_DIR backtrace.h REQUIRED)
find_library(LIBBACKTRACE_LIBRARY NAMES backtrace REQUIRED)
