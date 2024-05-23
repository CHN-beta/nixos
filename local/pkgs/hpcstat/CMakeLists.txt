cmake_minimum_required(VERSION 3.14)
project(hpcstat VERSION 0.0.0 LANGUAGES CXX)
enable_testing()
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message("Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

set(HPCSTAT_VERSION "unknown" CACHE STRING "Version of the hpcstat")

find_package(fmt REQUIRED)
find_package(Boost REQUIRED COMPONENTS headers filesystem)
find_package(SqliteOrm REQUIRED)
find_package(nlohmann_json REQUIRED)
find_path(ZPP_BITS_INCLUDE_DIR zpp_bits.h REQUIRED)
find_package(range-v3 REQUIRED)
find_path(NAMEOF_INCLUDE_DIR nameof.hpp REQUIRED)
find_package(date REQUIRED)
find_package(OpenXLSX REQUIRED)
find_package(httplib REQUIRED)

add_executable(hpcstat src/main.cpp src/env.cpp src/keys.cpp src/ssh.cpp src/sql.cpp src/lfs.cpp src/common.cpp
  src/push.cpp)
target_compile_features(hpcstat PUBLIC cxx_std_23)
target_include_directories(hpcstat PRIVATE ${PROJECT_SOURCE_DIR}/include ${ZPP_BITS_INCLUDE_DIR})
target_link_libraries(hpcstat PRIVATE fmt::fmt Boost::headers Boost::filesystem sqlite_orm::sqlite_orm
  nlohmann_json::nlohmann_json range-v3::range-v3 date::date date::date-tz OpenXLSX::OpenXLSX httplib::httplib)
target_compile_definitions(hpcstat PRIVATE HPCSTAT_VERSION="${HPCSTAT_VERSION}")

install(TARGETS hpcstat RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY share/ DESTINATION ${CMAKE_INSTALL_DATADIR}/hpcstat)

get_property(ImportedTargets DIRECTORY "${CMAKE_SOURCE_DIR}" PROPERTY IMPORTED_TARGETS)
message("Imported targets: ${ImportedTargets}")
message("List of compile features: ${CMAKE_CXX_COMPILE_FEATURES}")
