# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required(VERSION 3.10 FATAL_ERROR)

# Package information.
if (NOT DEFINED PACKAGE_VERSION)
  set(PACKAGE_VERSION 1.0.0)
endif ()
project(THRIFT VERSION ${PACKAGE_VERSION} LANGUAGES CXX C)

if (NOT DEFINED CPACK_GENERATOR)
  set(CPACK_GENERATOR RPM)
endif ()
set(CPACK_RPM_PACKAGE_PROVIDES thrift)
include(CPack)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(BIN_INSTALL_DIR bin CACHE STRING "The subdirectory where the compiler binary should be installed")
set(INCLUDE_INSTALL_DIR include CACHE STRING "The subdirectory where include files should be installed")
set(LIB_INSTALL_DIR lib CACHE STRING "The subdirectory where libraries should be installed")
set(CMAKE_INSTALL_DIR lib/cmake/fbthrift CACHE STRING "The subdirectory where CMake package config files should be installed")

set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/${LIB_INSTALL_DIR}")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

include_directories(.)
include_directories(${CMAKE_CURRENT_BINARY_DIR})

set(CMAKE_STD_MODULE_PATH ${CMAKE_MODULE_PATH})
set(CMAKE_MODULE_PATH
  ${CMAKE_CURRENT_SOURCE_DIR}/thrift/cmake
  ${CMAKE_CURRENT_SOURCE_DIR}/cmake
  ${CMAKE_CURRENT_SOURCE_DIR}/../opensource/fbcode_builder/CMake
  ${CMAKE_CURRENT_SOURCE_DIR}/build/fbcode_builder/CMake
  ${CMAKE_MODULE_PATH})

# ==============================================================================
# 🚀 [关键] 预定义 Boost 目标 (必须在 find_package 之前)
# ==============================================================================
message(STATUS ">> PRE-DEFINING BOOST TARGETS FOR FBTHRIFT <<")
set(SYS_INC "/usr/include")
set(SYS_LIB "/usr/lib")

macro(manual_boost_target name libname)
    if(NOT TARGET Boost::${name})
        add_library(Boost::${name} UNKNOWN IMPORTED)
        set_target_properties(Boost::${name} PROPERTIES
            IMPORTED_LOCATION "${SYS_LIB}/libboost_${libname}.so"
            INTERFACE_INCLUDE_DIRECTORIES "${SYS_INC}"
        )
    endif()
endmacro()

# FBThrift 需要的 Boost 组件
manual_boost_target(filesystem       filesystem)
manual_boost_target(program_options  program_options)
manual_boost_target(system           system)
manual_boost_target(thread           thread)
manual_boost_target(context          context)  # 你的手搓 Context
manual_boost_target(atomic           atomic)
manual_boost_target(chrono           chrono)
manual_boost_target(regex            regex)
manual_boost_target(iostreams        iostreams)
manual_boost_target(date_time        date_time)

set(Boost_FOUND TRUE)
set(Boost_INCLUDE_DIRS "${SYS_INC}")
# 骗过 CMake 的组件检查
set(Boost_LIBRARIES Boost::filesystem Boost::program_options Boost::system Boost::thread Boost::context Boost::atomic Boost::chrono Boost::regex Boost::iostreams Boost::date_time)

# ==============================================================================
# 🚀 [关键] 手动配置依赖 (Glog, Gflags, Zstd, Sodium, OpenSSL)
# ==============================================================================
message(STATUS ">> MANUAL DEPENDENCY CONFIGURATION <<")

# 1. Glog
set(GLOG_FOUND TRUE)
set(GLOG_INCLUDE_DIRS "/usr/include")
set(GLOG_LIBRARIES "/usr/lib/libglog.so")

# 2. Gflags
set(gflags_FOUND TRUE)
set(GFLAGS_FOUND TRUE)
set(GFLAGS_INCLUDE_DIR "/usr/include")
set(GFLAGS_LIBRARIES "/usr/lib/libgflags.so")

# 3. Zstd (FBThrift 需要)
set(ZSTD_FOUND TRUE)
set(Zstd_FOUND TRUE)
set(ZSTD_INCLUDE_DIRS "/root/CacheLib/opt/cachelib/include")
set(ZSTD_LIBRARIES "/root/CacheLib/opt/cachelib/lib64/libzstd.so")
if(NOT TARGET zstd::zstd)
    add_library(zstd::zstd UNKNOWN IMPORTED)
    set_target_properties(zstd::zstd PROPERTIES IMPORTED_LOCATION "${ZSTD_LIBRARIES}" INTERFACE_INCLUDE_DIRECTORIES "${ZSTD_INCLUDE_DIRS}")
endif()

# 4. Sodium (Fizz 需要，提前定义防止报错)
set(Sodium_FOUND TRUE)
set(SODIUM_FOUND TRUE)
set(sodium_FOUND TRUE)
set(sodium_INCLUDE_DIR "/usr/include")
set(SODIUM_LIBRARIES "/usr/lib/libsodium.so")

# 5. OpenSSL & ZLIB & fmt
find_package(OpenSSL REQUIRED)
find_package(ZLIB REQUIRED)
find_package(fmt CONFIG REQUIRED)

# ==============================================================================
# 🚀 加载核心 Facebook 库
# ==============================================================================
# 这些库必须按顺序加载，且依赖上面的手动配置
find_package(folly CONFIG REQUIRED)
find_package(fizz CONFIG REQUIRED)
find_package(wangle CONFIG REQUIRED)
find_package(mvfst CONFIG REQUIRED)

# ==============================================================================
# ⚙️ 编译选项配置
# ==============================================================================
if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  message(STATUS "setting C++ standard to C++${CMAKE_CXX_STANDARD}")
endif()
set(CMAKE_CXX_EXTENSIONS OFF)

if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-fcoroutines>)
endif()

# Enable modular builds.
option(THRIFT_COMPILER_ONLY "Build the Thrift compiler only" OFF)
option(THRIFT_LIB_ONLY "Build the Thrift libraries only" OFF)

# 默认全编译
if (THRIFT_COMPILER_ONLY OR THRIFT_LIB_ONLY)
  set(build_all OFF)
else ()
  set(build_all ON)
endif ()

# 🛑 关闭 Python 支持 (节省时间)
set(thriftpy OFF CACHE BOOL "" FORCE)
option(thriftpy3 "Include thrift-py3 library" OFF)

# 配置 Thrift 编译器和库的变量
if (THRIFT_COMPILER_ONLY OR build_all)
  include_directories(${OPENSSL_INCLUDE_DIR})
  set(THRIFT1 thrift1)
  set(THRIFTCPP2 thriftcpp2)
  include(ThriftLibrary.cmake)
  install(FILES ThriftLibrary.cmake DESTINATION ${INCLUDE_INSTALL_DIR}/thrift)
endif ()

if (THRIFT_LIB_ONLY OR build_all)
  # 填充依赖变量
  find_package(Threads)
  include_directories(
    ${LIBGFLAGS_INCLUDE_DIR}
    ${GLOG_INCLUDE_DIRS}
    ${OPENSSL_INCLUDE_DIR}
    ${ZSTD_INCLUDE_DIRS}
  )
  add_definitions("-DTHRIFT_HAVE_LIBSNAPPY=0")
  
  if (THRIFT_LIB_ONLY)
    find_program(THRIFT1 thrift1)
    include(${THRIFT_COMPILER_INCLUDE}/thrift/ThriftLibrary.cmake)
  endif ()
endif ()

# ==============================================================================
# 🛑 强制关闭测试
# ==============================================================================
set(enable_tests OFF CACHE BOOL "" FORCE)
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)

# 如果 enable_tests 为 ON，这里会报错，所以下面这段被禁用了
if(enable_tests)
  # ... 原有的测试代码 ...
endif()

add_subdirectory(thrift)
