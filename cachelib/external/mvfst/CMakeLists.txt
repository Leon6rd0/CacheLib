# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

cmake_minimum_required(VERSION 3.10)

project(mvfst)

if (NOT DEFINED PACKAGE_VERSION)
  set(PACKAGE_VERSION "0")
endif()

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  set(CMAKE_CXX_EXTENSIONS OFF)
  message(STATUS "setting C++ standard to C++${CMAKE_CXX_STANDARD}")
endif()

set(CMAKE_MODULE_PATH
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake"
  "${CMAKE_CURRENT_SOURCE_DIR}/opensource/fbcode_builder/CMake"
  "${CMAKE_CURRENT_SOURCE_DIR}/build/fbcode_builder/CMake"
  ${CMAKE_MODULE_PATH})

if (NOT DEFINED CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR "lib")
endif()
set(CMAKE_INSTALL_MODULE_DIR ${CMAKE_INSTALL_LIBDIR}/cmake/mvfst CACHE STRING
    "The subdirectory where CMake module files should be installed")

# 🚫 [修改] 屏蔽 FB 内部构建脚本 (Buildroot 不需要)
# include(FBBuildOptions)
# fb_activate_static_library_option()

set(QUIC_FBCODE_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ==============================================================================
# 🚀 [关键步骤] 预定义 Boost 目标
#    必须在 find_package(folly) 之前执行，否则配置会失败
# ==============================================================================
message(STATUS ">> PRE-DEFINING BOOST TARGETS FOR MVFST <<")
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

# 包含你自己编译的 context 以及 mvfst 需要的其他组件
manual_boost_target(iostreams        iostreams)
manual_boost_target(thread           thread)
manual_boost_target(filesystem       filesystem)
manual_boost_target(regex            regex)
manual_boost_target(context          context)  # 你的手搓 Context
manual_boost_target(date_time        date_time)
manual_boost_target(program_options  program_options)
manual_boost_target(system           system)   # Folly 需要

set(Boost_FOUND TRUE)
set(Boost_INCLUDE_DIRS "${SYS_INC}")
# 骗过 CMake 的组件检查
set(Boost_LIBRARIES 
    Boost::iostreams Boost::thread Boost::filesystem Boost::regex 
    Boost::context Boost::date_time Boost::program_options Boost::system
)

# ==============================================================================
# 🚀 [关键步骤] 手动配置 Sodium (防止 Fizz 报错)
# ==============================================================================
set(Sodium_FOUND TRUE)
set(SODIUM_FOUND TRUE)
set(sodium_INCLUDE_DIR "/usr/include")
set(SODIUM_LIBRARY "/usr/lib/libsodium.so")
set(SODIUM_LIBRARIES "/usr/lib/libsodium.so")

# ==============================================================================
# 🚀 [关键步骤] 手动配置 Gflags / Glog
# ==============================================================================
# Gflags
set(gflags_FOUND TRUE)
set(GFLAGS_FOUND TRUE)
set(GFLAGS_INCLUDE_DIR "/usr/include")
set(GFLAGS_LIBRARIES "/usr/lib/libgflags.so")
set(LIBGFLAGS_LIBRARY "/usr/lib/libgflags.so")
set(LIBGFLAGS_INCLUDE_DIR "/usr/include")

# Glog
set(GLOG_FOUND TRUE)
set(GLOG_INCLUDE_DIRS "/usr/include")
set(GLOG_LIBRARIES "/usr/lib/libglog.so")

# ==============================================================================
# 🚀 加载核心依赖
# ==============================================================================
find_package(fmt REQUIRED)
find_package(folly CONFIG REQUIRED)
find_package(fizz CONFIG REQUIRED) # 注意这里改用小写 fizz，通常生成的 Config 是这个名字
find_package(Threads)

# 手动设置 Gflags 依赖变量 (替代原有复杂逻辑)
SET(GFLAG_DEPENDENCIES "")
list(APPEND QUIC_EXTRA_LINK_LIBRARIES ${LIBGFLAGS_LIBRARY})
list(APPEND QUIC_EXTRA_INCLUDE_DIRECTORIES ${LIBGFLAGS_INCLUDE_DIR})

# 编译选项
if(NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
list(APPEND _QUIC_BASE_COMPILE_OPTIONS -Wall -Wextra)
endif()

list(APPEND _QUIC_COMMON_COMPILE_OPTIONS ${_QUIC_BASE_COMPILE_OPTIONS})

if(NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
  list(APPEND _QUIC_COMMON_COMPILE_OPTIONS
    -Woverloaded-virtual
    -Wnon-virtual-dtor
    -Wtype-limits
    -Wunused-value
  )
endif()

SET(LIBFIZZ_LIBRARY ${FIZZ_LIBRARIES})
SET(LIBFIZZ_INCLUDE_DIR ${FIZZ_INCLUDE_DIR})

# ==============================================================================
# 🛑 强制关闭测试 (Buildroot 环境下不要开)
# ==============================================================================
option(BUILD_TESTS "BUILD_TESTS" OFF)
if(BUILD_TESTS)
  enable_testing()
  include(QuicTest)
endif()

add_subdirectory(quic)

install(
  EXPORT mvfst-exports
  FILE mvfst-targets.cmake
  NAMESPACE mvfst::
  DESTINATION ${CMAKE_INSTALL_MODULE_DIR}
)

include(CMakePackageConfigHelpers)
configure_package_config_file(
  cmake/mvfst-config.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/mvfst-config.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_MODULE_DIR}
)
install(
  FILES ${CMAKE_CURRENT_BINARY_DIR}/mvfst-config.cmake
  DESTINATION ${CMAKE_INSTALL_MODULE_DIR}
)
