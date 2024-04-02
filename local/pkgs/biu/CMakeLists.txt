cmake_minimum_required(VERSION 3.14)
project(biu LANGUAGES CXX)
enable_testing()
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message("Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

find_package(magic_enum REQUIRED)
find_package(fmt REQUIRED)
find_package(Boost REQUIRED COMPONENTS headers iostreams)
# find_package(concurrencpp REQUIRED)
find_package(Eigen3 REQUIRED)
find_package(range-v3 REQUIRED)
find_path(NAMEOF_INCLUDE_DIR nameof.hpp REQUIRED)
# find_path(TGBOTCPP_INCLUDE_DIR tgbot/tgbot.h REQUIRED)
# find_library(TGBOTCPP_LIB libTgBot.a REQUIRED)
# find_path(BACKTRACE_INCLUDE_DIR backtrace.h REQUIRED)
# find_library(BACKTRACE_LIB backtrace REQUIRED)

# add_library(biu SHARED src/common.cpp src/logger.cpp src/string.cpp)
add_library(biu SHARED src/common.cpp)
target_include_directories(biu PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
  ${NAMEOF_INCLUDE_DIR} ${TGBOTCPP_INCLUDE_DIR})
target_link_libraries(biu PUBLIC
  magic_enum::magic_enum
  fmt::fmt
  Boost::headers Boost::iostreams
#   concurrencpp::concurrencpp
  Eigen3::Eigen
  range-v3::range-v3)
# ${TGBOTCPP_LIB} ${BACKTRACE_LIB})
set_property(TARGET biu PROPERTY CXX_STANDARD 23 CXX_STANDARD_REQUIRED ON CXX_EXTENSIONS OFF)
install(TARGETS biu EXPORT biuConfig)
install(EXPORT biuConfig NAMESPACE ${PROJECT_NAME}:: DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/biu)
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

get_property(ImportedTargets DIRECTORY "${CMAKE_SOURCE_DIR}" PROPERTY IMPORTED_TARGETS)
message("Imported targets: ${ImportedTargets}")
message("List of compile features: ${CMAKE_CXX_COMPILE_FEATURES}")
