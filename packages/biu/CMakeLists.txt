cmake_minimum_required(VERSION 3.14)
project(biu LANGUAGES CXX)
enable_testing()
include(GNUInstallDirs)

option(BUILD_SHARED_LIBS "Build using shared libraries" ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message("Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

find_package(magic_enum REQUIRED)
find_package(fmt REQUIRED)
find_package(Boost REQUIRED COMPONENTS headers iostreams filesystem)
find_package(range-v3 REQUIRED)
find_path(NAMEOF_INCLUDE_DIR nameof.hpp REQUIRED)
find_package(Eigen3 REQUIRED)

add_library(biu src/common.cpp)
target_include_directories(biu PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}> ${NAMEOF_INCLUDE_DIR} ${ZPP_BITS_INCLUDE_DIR})
target_link_libraries(biu PUBLIC magic_enum::magic_enum fmt::fmt Boost::headers Boost::iostreams Boost::filesystem
  range-v3::range-v3 Eigen3::Eigen)
set_property(TARGET biu PROPERTY CXX_STANDARD 23 CXX_STANDARD_REQUIRED ON)
install(TARGETS biu EXPORT biuTargets LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(EXPORT biuTargets FILE biuTargets.cmake NAMESPACE biu:: DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/biu)
install(FILES biuConfig.cmake DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/biu)

get_property(ImportedTargets DIRECTORY "${CMAKE_SOURCE_DIR}" PROPERTY IMPORTED_TARGETS)
message("Imported targets: ${ImportedTargets}")
message("List of compile features: ${CMAKE_CXX_COMPILE_FEATURES}")

include(CTest)
add_executable(test-serialize test/serialize.cpp)
target_link_libraries(test-serialize PRIVATE biu)
set_property(TARGET test-serialize PROPERTY CXX_STANDARD 23 CXX_STANDARD_REQUIRED ON)
add_test(NAME test-serialize COMMAND test-serialize)
add_executable(test-process test/process.cpp)
target_link_libraries(test-process PRIVATE biu)
set_property(TARGET test-process PROPERTY CXX_STANDARD 23 CXX_STANDARD_REQUIRED ON)
add_test(NAME test-process COMMAND test-process)
add_executable(test-eigen test/eigen.cpp)
target_link_libraries(test-eigen PRIVATE biu)
set_property(TARGET test-eigen PROPERTY CXX_STANDARD 23 CXX_STANDARD_REQUIRED ON)
add_test(NAME test-eigen COMMAND test-eigen)
