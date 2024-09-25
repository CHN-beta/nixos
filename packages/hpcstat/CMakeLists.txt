# cmake_minimum_required(VERSION 3.30)
cmake_minimum_required(VERSION 3.29)
project(hpcstat VERSION 0.0.0 LANGUAGES CXX)
enable_testing()
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message("Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

set(HPCSTAT_VERSION "unknown" CACHE STRING "Version of the hpcstat")

find_package(Boost REQUIRED COMPONENTS url)
find_package(SqliteOrm REQUIRED)
find_package(nlohmann_json REQUIRED)
find_package(date REQUIRED)
find_package(httplib REQUIRED)
find_package(termcolor REQUIRED)
find_package(biu REQUIRED)
find_package(OpenXLSX REQUIRED)

add_executable(hpcstat src/main.cpp src/env.cpp src/keys.cpp src/ssh.cpp src/sql.cpp src/lfs.cpp src/common.cpp
  src/push.cpp src/disk.cpp)
# target_compile_features(hpcstat PRIVATE cxx_std_26)
target_compile_options(hpcstat PRIVATE "-std=c++26")
target_include_directories(hpcstat PRIVATE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(hpcstat PRIVATE Boost::url sqlite_orm::sqlite_orm nlohmann_json::nlohmann_json date::date
  date::date-tz httplib::httplib termcolor::termcolor biu::biu OpenXLSX::OpenXLSX)
target_compile_definitions(hpcstat PRIVATE HPCSTAT_VERSION="${HPCSTAT_VERSION}")

install(TARGETS hpcstat RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY share/ DESTINATION ${CMAKE_INSTALL_DATADIR}/hpcstat)

get_property(ImportedTargets DIRECTORY "${CMAKE_SOURCE_DIR}" PROPERTY IMPORTED_TARGETS)
message("Imported targets: ${ImportedTargets}")
message("List of compile features: ${CMAKE_CXX_COMPILE_FEATURES}")

include(CTest)
add_executable(test-main test/main.cpp)
target_link_libraries(test-main PRIVATE biu::biu)
set_property(TARGET test-main PROPERTY CXX_STANDARD 23 CXX_STANDARD_REQUIRED ON)
add_test(NAME test-main COMMAND test-main)
