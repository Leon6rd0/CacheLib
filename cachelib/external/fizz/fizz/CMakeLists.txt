# Copyright (c) 2018, Facebook, Inc.
# All rights reserved.

cmake_minimum_required(VERSION 3.5)

if (NOT DEFINED PACKAGE_VERSION)
  set(PACKAGE_VERSION "1.0.0")
endif()

project("fizz" VERSION ${PACKAGE_VERSION} LANGUAGES CXX C)

if (NOT DEFINED CPACK_GENERATOR)
  set(CPACK_GENERATOR "RPM")
endif()
include(CPack)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 20)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  set(CMAKE_CXX_EXTENSIONS OFF)
  message(STATUS "setting C++ standard to C++${CMAKE_CXX_STANDARD}")
endif()

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_MODULE_PATH
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake"
  "${CMAKE_CURRENT_SOURCE_DIR}/../opensource/fbcode_builder/CMake"
  "${CMAKE_CURRENT_SOURCE_DIR}/../build/fbcode_builder/CMake"
  ${CMAKE_MODULE_PATH})

# 🚫 已注释 (Buildroot 不需要这个)
# include(FBBuildOptions)
# fb_activate_static_library_option()

SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(INCLUDE_INSTALL_DIR include CACHE STRING "The subdirectory where header files should be installed")
set(LIB_INSTALL_DIR lib CACHE STRING "The subdirectory where libraries should be installed")
set(BIN_INSTALL_DIR bin CACHE STRING "The subdirectory where binaries should be installed")
set(CMAKE_INSTALL_DIR lib/cmake/fizz CACHE STRING "The subdirectory where CMake package config files should be installed")

# ==========================================================
# 🚀 核心依赖配置 (Folly, Fmt, OpenSSL)
# ==========================================================
# Folly 和 Fmt 之前的日志显示能找到，这里保留原样
find_package(folly CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(Threads REQUIRED)

# ==========================================================
# 🚀 批量手动配置 (Glog, Sodium, Gflags, Libevent, ZLIB, Zstd)
# ==========================================================
message(STATUS ">> STARTING MANUAL CONFIGURATION <<")

# 1. Glog
message(STATUS ">> Manual: Glog")
set(GLOG_FOUND TRUE)
set(GLOG_INCLUDE_DIRS "/usr/include")
set(GLOG_LIBRARIES "/usr/lib/libglog.so")

# 2. Sodium (你之前 SCP 进去的)
message(STATUS ">> Manual: Sodium")
set(Sodium_FOUND TRUE)
set(SODIUM_FOUND TRUE)
set(sodium_INCLUDE_DIR "/usr/include") # 注意大小写匹配 Fizz 源码习惯
set(SODIUM_INCLUDE_DIRS "/usr/include")
set(SODIUM_LIBRARIES "/usr/lib/libsodium.so")
# 创建 target 防止报错
if(NOT TARGET sodium)
  add_library(sodium UNKNOWN IMPORTED)
  set_target_properties(sodium PROPERTIES IMPORTED_LOCATION "${SODIUM_LIBRARIES}" INTERFACE_INCLUDE_DIRECTORIES "${SODIUM_INCLUDE_DIRS}")
endif()
set(FIZZ_HAVE_SODIUM ON)

# 3. Zstd (复用你之前的配置)
message(STATUS ">> Manual: Zstd")
set(ZSTD_INCLUDE_DIR "/root/CacheLib/opt/cachelib/include")
set(ZSTD_LIBRARY "/root/CacheLib/opt/cachelib/lib64/libzstd.so")
set(Zstd_FOUND TRUE)
set(ZSTD_FOUND TRUE)
set(ZSTD_LIBRARIES ${ZSTD_LIBRARY})
set(ZSTD_INCLUDE_DIRS ${ZSTD_INCLUDE_DIR})
if(NOT TARGET zstd::zstd)
  add_library(zstd::zstd UNKNOWN IMPORTED)
  set_target_properties(zstd::zstd PROPERTIES IMPORTED_LOCATION "${ZSTD_LIBRARY}" INTERFACE_INCLUDE_DIRECTORIES "${ZSTD_INCLUDE_DIR}")
endif()

# 4. Gflags
message(STATUS ">> Manual: Gflags")
set(gflags_FOUND TRUE)
set(GFLAGS_FOUND TRUE)
set(GFLAGS_INCLUDE_DIR "/usr/include")
set(GFLAGS_LIBRARIES "/usr/lib/libgflags.so")
set(LIBGFLAGS_LIBRARY "/usr/lib/libgflags.so")
set(LIBGFLAGS_INCLUDE_DIR "/usr/include")

# 5. Libevent
message(STATUS ">> Manual: Libevent")
set(Libevent_FOUND TRUE)
set(LIBEVENT_LIB "/usr/lib/libevent.so")
set(LIBEVENT_INCLUDE_DIR "/usr/include")

# 6. ZLIB
message(STATUS ">> Manual: ZLIB")
set(ZLIB_FOUND TRUE)
set(ZLIB_LIBRARIES "/usr/lib/libz.so")
set(ZLIB_INCLUDE_DIRS "/usr/include")
if(NOT TARGET ZLIB::ZLIB)
  add_library(ZLIB::ZLIB UNKNOWN IMPORTED)
  set_target_properties(ZLIB::ZLIB PROPERTIES IMPORTED_LOCATION "${ZLIB_LIBRARIES}" INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIRS}")
endif()

message(STATUS ">> MANUAL CONFIGURATION DONE <<")

# ==========================================================

if (UNIX AND NOT APPLE)
  find_package(Librt)
endif()

include(CheckAtomic)

# 初始化变量
SET(FIZZ_SHINY_DEPENDENCIES "")
SET(FIZZ_LINK_LIBRARIES "")
SET(FIZZ_INCLUDE_DIRECTORIES "")

# 手动填充 Gflags 变量
list(APPEND FIZZ_LINK_LIBRARIES ${LIBGFLAGS_LIBRARY})
list(APPEND FIZZ_INCLUDE_DIRECTORIES ${LIBGFLAGS_INCLUDE_DIR})
list(APPEND CMAKE_REQUIRED_LIBRARIES ${LIBGFLAGS_LIBRARY})
list(APPEND CMAKE_REQUIRED_INCLUDES ${LIBGFLAGS_INCLUDE_DIR})

# 手动填充 Libevent 变量
list(APPEND FIZZ_LINK_LIBRARIES ${LIBEVENT_LIB})
list(APPEND FIZZ_INCLUDE_DIRECTORIES ${LIBEVENT_INCLUDE_DIR})

# 可选依赖
find_package(liboqs 0.11.0 CONFIG)
if (liboqs_FOUND)
  set(FIZZ_HAVE_OQS TRUE)
endif()

find_package(aegis CONFIG)
if(aegis_FOUND)
    set(FIZZ_HAVE_LIBAEGIS TRUE)
endif()

include(FizzOptions)
include(FizzSources)

configure_file(fizz-config.h.in ${CMAKE_CURRENT_BINARY_DIR}/generated/fizz/fizz-config.h)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/generated/fizz/fizz-config.h DESTINATION ${INCLUDE_INSTALL_DIR}/fizz/)

# 定义 Header 目录
set(FIZZ_HEADER_DIRS
  backend
  backend/liboqs
  backend/openssl
  backend/openssl/certificate
  backend/openssl/crypto
  backend/openssl/crypto/aead
  backend/openssl/crypto/exchange
  backend/openssl/crypto/signature
  client
  compression
  crypto
  crypto/aead
  crypto/exchange
  crypto/hpke
  crypto/signature
  crypto/openssl
  experimental/crypto/exchange
  experimental/ktls
  experimental/util
  extensions/clientpadding
  extensions/delegatedcred
  extensions/exportedauth
  extensions/tokenbinding
  protocol
  protocol/clock
  protocol/ech
  record
  server
  util
  tool
)

foreach(dir ${FIZZ_HEADER_DIRS})
  file(GLOB_RECURSE headers ${dir}/*.h)
  set(FIZZ_HEADERS ${FIZZ_HEADERS} ${headers})
endforeach()

add_library(fizz ${FIZZ_LIBRARY_SOURCES})

if (BUILD_SHARED_LIBS)
  set_target_properties(fizz PROPERTIES VERSION ${PACKAGE_VERSION})
endif()

get_filename_component(FIZZ_BASE_DIR ${CMAKE_SOURCE_DIR}/.. ABSOLUTE)

target_include_directories(
  fizz
  PUBLIC
    $<BUILD_INTERFACE:${FIZZ_BASE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/generated>
    $<INSTALL_INTERFACE:${INCLUDE_INSTALL_DIR}>
    ${FOLLY_INCLUDE_DIR}
    ${OPENSSL_INCLUDE_DIR}
    ${sodium_INCLUDE_DIR}
    ${ZSTD_INCLUDE_DIR}
  PRIVATE
    ${GLOG_INCLUDE_DIRS}
    ${FIZZ_INCLUDE_DIRECTORIES}
)

target_link_libraries(fizz
  PUBLIC
    ${FOLLY_LIBRARIES}
    ${OPENSSL_LIBRARIES}
    sodium
    Threads::Threads
    ZLIB::ZLIB
    ${ZSTD_LIBRARY}
  PRIVATE
    ${GLOG_LIBRARIES}
    ${GFLAGS_LIBRARIES}
    ${FIZZ_LINK_LIBRARIES}
    ${CMAKE_DL_LIBS}
    ${LIBRT_LIBRARIES})

if (liboqs_FOUND)
  target_link_libraries(fizz PRIVATE OQS::oqs)
endif()

if (aegis_FOUND)
    target_link_libraries(fizz PRIVATE aegis::aegis)
endif()

if (${CMAKE_CXX_COMPILER_ID} STREQUAL MSVC)
  target_compile_options(fizz PUBLIC /bigobj)
endif()

install(
  TARGETS fizz
  EXPORT fizz-exports
  DESTINATION ${LIB_INSTALL_DIR}
)

foreach(dir ${FIZZ_HEADER_DIRS})
  get_filename_component(PARENT_DIR "/${dir}" DIRECTORY)
  install(DIRECTORY ${dir} DESTINATION "${INCLUDE_INSTALL_DIR}/fizz${PARENT_DIR}"
          FILES_MATCHING PATTERN "*.h"
          PATTERN "test" EXCLUDE)
endforeach()

include(CMakePackageConfigHelpers)
configure_package_config_file(
  cmake/fizz-config.cmake.in
  fizz-config.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_DIR}
  PATH_VARS INCLUDE_INSTALL_DIR CMAKE_INSTALL_DIR
)
install(
  FILES ${CMAKE_CURRENT_BINARY_DIR}/fizz-config.cmake
  DESTINATION ${CMAKE_INSTALL_DIR}
)
install(EXPORT fizz-exports
        FILE fizz-targets.cmake
        NAMESPACE fizz::
        DESTINATION ${CMAKE_INSTALL_DIR})

# ==========================================================
# 🛑 强制关闭测试和示例 (Buildroot 环境下不要开，省时省内存)
# ==========================================================
option(BUILD_TESTS "BUILD_TESTS" OFF)
option(BUILD_EXAMPLES "BUILD_EXAMPLES" OFF)

# 下面的代码是测试相关的，因为上面设为 OFF，所以会被跳过
if(BUILD_TESTS)
  # ... (省略测试代码) ...
endif()

if(BUILD_EXAMPLES)
  # ... (省略示例代码) ...
endif()
