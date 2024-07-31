# cmake_minimum_required(VERSION 3.30)
cmake_minimum_required(VERSION 3.29)
project(winjob VERSION 0.0.0 LANGUAGES CXX)
enable_testing()
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message("Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

set(WINJOB_VERSION "unknown" CACHE STRING "Version of the winjob")

find_package(Boost REQUIRED COMPONENTS headers filesystem)

add_executable(winjob src/winjob.cpp src/windows.cpp)
# target_compile_features(winjob PRIVATE cxx_std_26)
target_compile_options(winjob PRIVATE "-std=c++26")
target_include_directories(winjob PRIVATE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(winjob PRIVATE Boost::headers Boost::filesystem ws2_32 wsock32)
target_compile_definitions(winjob PRIVATE winjob_VERSION="${winjob_VERSION}")

add_executable(winjobd src/winjobd.cpp)
# target_compile_features(winjob PRIVATE cxx_std_26)
target_compile_options(winjobd PRIVATE "-std=c++26")
target_include_directories(winjobd PRIVATE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(winjobd PRIVATE Boost::headers Boost::filesystem ws2_32 wsock32)
target_compile_definitions(winjobd PRIVATE winjob_VERSION="${winjob_VERSION}")

install(TARGETS winjob RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(TARGETS winjobd RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

get_property(ImportedTargets DIRECTORY "${CMAKE_SOURCE_DIR}" PROPERTY IMPORTED_TARGETS)
message("Imported targets: ${ImportedTargets}")
message("List of compile features: ${CMAKE_CXX_COMPILE_FEATURES}")
