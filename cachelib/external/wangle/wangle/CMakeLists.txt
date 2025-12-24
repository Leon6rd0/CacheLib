# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.

cmake_minimum_required(VERSION 3.5)

if (NOT DEFINED PACKAGE_VERSION)
  set(PACKAGE_VERSION "1.0.0")
endif()

project("wangle" VERSION ${PACKAGE_VERSION} LANGUAGES CXX C)

# ------------------------------------------------------------------------------
# 1. 基础配置
# ------------------------------------------------------------------------------
if (NOT DEFINED CPACK_GENERATOR)
  set(CPACK_GENERATOR "RPM")
endif()
include(CPack)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  set(CMAKE_CXX_EXTENSIONS OFF)
  message(STATUS "setting C++ standard to C++${CMAKE_CXX_STANDARD}")
endif()

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_MODULE_PATH
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/"
  "${CMAKE_CURRENT_SOURCE_DIR}/../opensource/fbcode_builder/CMake"
  "${CMAKE_CURRENT_SOURCE_DIR}/../build/fbcode_builder/CMake"
  ${CMAKE_MODULE_PATH})

# 🚫 [修改] 屏蔽 FB 内部构建脚本
# include(FBBuildOptions)
# fb_activate_static_library_option()

SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(INCLUDE_INSTALL_DIR include CACHE STRING "The subdirectory where header files should be installed")
set(LIB_INSTALL_DIR lib CACHE STRING "The subdirectory where libraries should be installed")
set(CMAKE_INSTALL_DIR lib/cmake/wangle CACHE STRING "The subdirectory where CMake package config files should be installed")

# ==============================================================================
# 🚀 [关键步骤] 预定义 Boost 目标
#    必须在 find_package(folly) 之前执行，否则 Folly 配置文件会报错找不到 Boost
# ==============================================================================
message(STATUS ">> PRE-DEFINING BOOST TARGETS FOR WANGLE <<")
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

# 包含你自己编译的 context
manual_boost_target(filesystem       filesystem)
manual_boost_target(program_options  program_options)
manual_boost_target(regex            regex)
manual_boost_target(system           system)
manual_boost_target(thread           thread)
manual_boost_target(atomic           atomic)
manual_boost_target(chrono           chrono)
manual_boost_target(context          context) 

set(Boost_FOUND TRUE)
set(Boost_INCLUDE_DIRS "${SYS_INC}")
set(Boost_LIBRARIES Boost::context Boost::filesystem Boost::program_options Boost::regex Boost::system Boost::thread Boost::atomic Boost::chrono)

# ==============================================================================
# 🚀 [关键步骤] 手动配置其他依赖 (Glog, Gflags, Libevent, DoubleConversion, Sodium)
# ==============================================================================
message(STATUS ">> MANUAL DEPENDENCY CONFIGURATION <<")

# 1. Glog
set(GLOG_FOUND TRUE)
set(GLOG_INCLUDE_DIRS "/usr/include")
set(GLOG_LIBRARIES "/usr/lib/libglog.so")

# 2. Gflags
set(gflags_FOUND TRUE)
set(GFLAGS_FOUND TRUE)
set(GFLAGS_INCLUDE_DIRS "/usr/include")
set(GFLAGS_LIBRARIES "/usr/lib/libgflags.so")

# 3. Libevent
set(LibEvent_FOUND TRUE)
set(LIBEVENT_LIB "/usr/lib/libevent.so")
set(LIBEVENT_INCLUDE_DIR "/usr/include")

# 4. Double Conversion (Wangle 需要)
set(DoubleConversion_FOUND TRUE)
set(DOUBLE_CONVERSION_INCLUDE_DIR "/usr/include")
set(DOUBLE_CONVERSION_LIBRARY "/usr/lib/libdouble-conversion.so")
if(NOT TARGET double-conversion::double-conversion)
  add_library(double-conversion::double-conversion UNKNOWN IMPORTED)
  set_target_properties(double-conversion::double-conversion PROPERTIES IMPORTED_LOCATION "${DOUBLE_CONVERSION_LIBRARY}" INTERFACE_INCLUDE_DIRECTORIES "${DOUBLE_CONVERSION_INCLUDE_DIR}")
endif()

# 5. Sodium (Fizz 需要)
set(Sodium_FOUND TRUE)
set(sodium_INCLUDE_DIR "/usr/include")
set(SODIUM_LIBRARIES "/usr/lib/libsodium.so")
if(NOT TARGET sodium)
  add_library(sodium UNKNOWN IMPORTED)
  set_target_properties(sodium PROPERTIES IMPORTED_LOCATION "${SODIUM_LIBRARIES}" INTERFACE_INCLUDE_DIRECTORIES "${sodium_INCLUDE_DIR}")
endif()

message(STATUS ">> MANUAL CONFIGURATION DONE <<")

# ------------------------------------------------------------------------------
# 2. 加载核心库
# ------------------------------------------------------------------------------
find_package(folly CONFIG REQUIRED)
find_package(fizz CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(Threads REQUIRED)

if (UNIX AND NOT APPLE)
  find_package(Librt)
endif()

include(CheckAtomic)

# ------------------------------------------------------------------------------
# 3. 源码定义
# ------------------------------------------------------------------------------
set(WANGLE_HEADER_DIRS acceptor bootstrap channel client codec service ssl util)

foreach(dir ${WANGLE_HEADER_DIRS})
  file(GLOB_RECURSE headers ${dir}/*.h)
  set(WANGLE_HEADERS ${WANGLE_HEADERS} ${headers})
endforeach()

set(WANGLE_SOURCES
  acceptor/Acceptor.cpp
  acceptor/AcceptorHandshakeManager.cpp
  acceptor/ConnectionManager.cpp
  acceptor/EvbHandshakeHelper.cpp
  acceptor/FizzAcceptorHandshakeHelper.cpp
  acceptor/FizzConfigUtil.cpp
  acceptor/LoadShedConfiguration.cpp
  acceptor/ManagedConnection.cpp
  acceptor/SecureTransportType.cpp
  acceptor/SocketOptions.cpp
  acceptor/SSLAcceptorHandshakeHelper.cpp
  acceptor/TLSPlaintextPeekingCallback.cpp
  acceptor/TransportInfo.cpp
  bootstrap/ServerBootstrap.cpp
  channel/FileRegion.cpp
  channel/Pipeline.cpp
  client/persistence/FilePersistenceLayer.cpp
  client/persistence/PersistentCacheCommon.cpp
  client/ssl/SSLSessionCacheData.cpp
  client/ssl/SSLSessionCacheUtils.cpp
  client/ssl/SSLSessionCallbacks.cpp
  codec/LengthFieldBasedFrameDecoder.cpp
  codec/LengthFieldPrepender.cpp
  codec/LineBasedFrameDecoder.cpp
  ssl/PasswordInFileFactory.cpp
  ssl/ServerSSLContext.cpp
  ssl/SSLContextManager.cpp
  ssl/SSLSessionCacheManager.cpp
  ssl/SSLUtil.cpp
  ssl/TLSTicketKeyManager.cpp
  ssl/TLSCredProcessor.cpp
  ssl/TLSInMemoryTicketProcessor.cpp
  util/FilePoller.cpp
)

add_library(wangle ${WANGLE_HEADERS} ${WANGLE_SOURCES})

include(CheckLibraryExists)
check_library_exists(ssl SSL_SESSION_dup "${OPENSSL_SSL_LIBRARY}" WANGLE_HAVE_SSL_SESSION_DUP)
if(WANGLE_HAVE_SSL_SESSION_DUP)
  target_compile_definitions(wangle PRIVATE WANGLE_HAVE_SSL_SESSION_DUP)
endif()

if (BUILD_SHARED_LIBS)
  set_target_properties(wangle PROPERTIES VERSION ${PACKAGE_VERSION})
endif()

# ------------------------------------------------------------------------------
# 4. 包含与链接
# ------------------------------------------------------------------------------
target_include_directories(
  wangle
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/..>
    $<INSTALL_INTERFACE:${INCLUDE_INSTALL_DIR}>
    ${FIZZ_INCLUDE_DIR}
    ${FOLLY_INCLUDE_DIR}
    ${Boost_INCLUDE_DIRS}
    ${OPENSSL_INCLUDE_DIR}
    ${GLOG_INCLUDE_DIRS}
    ${GFLAGS_INCLUDE_DIRS}
    ${LIBEVENT_INCLUDE_DIR}
    ${DOUBLE_CONVERSION_INCLUDE_DIR}
)

target_link_libraries(wangle PUBLIC
  ${FOLLY_LIBRARIES}
  ${FIZZ_LIBRARIES}
  ${Boost_LIBRARIES}
  ${OPENSSL_LIBRARIES}
  ${GLOG_LIBRARIES}
  ${GFLAGS_LIBRARIES}
  ${LIBEVENT_LIB}
  ${DOUBLE_CONVERSION_LIBRARY}
  ${CMAKE_DL_LIBS}
  ${LIBRT_LIBRARIES}
  Threads::Threads
  sodium
)

# ------------------------------------------------------------------------------
# 5. 安装配置
# ------------------------------------------------------------------------------
install(TARGETS wangle EXPORT wangle-exports DESTINATION ${LIB_INSTALL_DIR})

foreach(dir ${WANGLE_HEADER_DIRS})
  install(DIRECTORY ${dir} DESTINATION "${INCLUDE_INSTALL_DIR}/wangle" FILES_MATCHING PATTERN "*.h")
endforeach()

include(CMakePackageConfigHelpers)
configure_package_config_file(
  cmake/wangle-config.cmake.in
  wangle-config.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_DIR}
  PATH_VARS INCLUDE_INSTALL_DIR CMAKE_INSTALL_DIR
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/wangle-config.cmake DESTINATION ${CMAKE_INSTALL_DIR})
install(EXPORT wangle-exports FILE wangle-targets.cmake NAMESPACE wangle:: DESTINATION ${CMAKE_INSTALL_DIR})

# ------------------------------------------------------------------------------
# 6. 🛑 强制关闭测试和示例 (Buildroot 环境下不要开)
# ------------------------------------------------------------------------------
option(BUILD_TESTS "BUILD_TESTS" OFF)
option(BUILD_EXAMPLES "BUILD_EXAMPLES" OFF)

if(BUILD_TESTS)
  # 测试代码已省略，因为我们设为了 OFF
endif()

if(BUILD_EXAMPLES)
  # 示例代码已省略
endif()
