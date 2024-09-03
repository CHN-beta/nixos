cmake_minimum_required(VERSION 3.14)
project(ufo VERSION 0 LANGUAGES CXX)
enable_testing()
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message("Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

find_package(yaml-cpp REQUIRED)
find_package(TBB REQUIRED)
find_package(Matplot++ REQUIRED)
find_package(biu REQUIRED)
find_package(Threads REQUIRED)

add_executable(ufo src/solver.cpp src/fold.cpp src/unfold.cpp src/plot.cpp src/main.cpp)
target_include_directories(ufo PRIVATE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(ufo PRIVATE yaml-cpp TBB::tbb Matplot++::matplot biu::biu)
target_compile_features(ufo PRIVATE cxx_std_23)

install(TARGETS ufo RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

get_property(ImportedTargets DIRECTORY "${CMAKE_SOURCE_DIR}" PROPERTY IMPORTED_TARGETS)
message("Imported targets: ${ImportedTargets}")
message("List of compile features: ${CMAKE_CXX_COMPILE_FEATURES}")

include(CTest)
add_test(NAME fold COMMAND ufo fold ${PROJECT_SOURCE_DIR}/test/fold/config.yaml)
add_test(NAME fold-compare COMMAND ${CMAKE_COMMAND} -E compare_files fold-output.yaml
  ${PROJECT_SOURCE_DIR}/test/fold/output.yaml)
set_tests_properties(fold-compare PROPERTIES DEPENDS fold)
