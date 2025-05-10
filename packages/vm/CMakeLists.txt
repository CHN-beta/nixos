cmake_minimum_required(VERSION 3.14)
project(vm VERSION 0.0.0 LANGUAGES CXX)
enable_testing()
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message("Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

find_package(biu REQUIRED)

add_executable(vm src/main.cpp)
target_compile_features(vm PUBLIC cxx_std_23)
target_link_libraries(vm PRIVATE biu::biu)
if(VM_CONFIG)
  target_compile_definitions(vm PRIVATE VM_CONFIG="${VM_CONFIG}")
endif()

install(TARGETS vm RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

get_property(ImportedTargets DIRECTORY "${CMAKE_SOURCE_DIR}" PROPERTY IMPORTED_TARGETS)
message("Imported targets: ${ImportedTargets}")
message("List of compile features: ${CMAKE_CXX_COMPILE_FEATURES}")
