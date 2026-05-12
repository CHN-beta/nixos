cmake_minimum_required(VERSION 3.14)
project(sbatch-tui VERSION 0.0.0 LANGUAGES CXX)
enable_testing()
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message("Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

find_package(ftxui REQUIRED)
find_package(biu REQUIRED)

add_executable(sbatch-tui src/main.cpp src/vasp_gpu.cpp src/vasp_cpu.cpp src/mumax3.cpp src/fdtd.cpp)
target_compile_features(sbatch-tui PUBLIC cxx_std_23)
target_link_libraries(sbatch-tui PRIVATE ftxui::screen ftxui::dom ftxui::component biu::biu)
target_include_directories(sbatch-tui PRIVATE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
if(SBATCH_CONFIG)
  target_compile_definitions(sbatch-tui PRIVATE SBATCH_CONFIG="${SBATCH_CONFIG}")
endif()

install(TARGETS sbatch-tui RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

get_property(ImportedTargets DIRECTORY "${CMAKE_SOURCE_DIR}" PROPERTY IMPORTED_TARGETS)
message("Imported targets: ${ImportedTargets}")
message("List of compile features: ${CMAKE_CXX_COMPILE_FEATURES}")
