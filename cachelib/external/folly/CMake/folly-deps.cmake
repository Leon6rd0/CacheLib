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

include(CheckCXXSourceCompiles)
include(CheckCXXSymbolExists)
include(CheckIncludeFileCXX)
include(CheckFunctionExists)
include(CMakePushCheckState)

set(
  BOOST_LINK_STATIC "auto"
  CACHE STRING
  "Whether to link against boost statically or dynamically."
)
if("${BOOST_LINK_STATIC}" STREQUAL "auto")
  # Default to linking boost statically on Windows with MSVC
  if(MSVC)
    set(FOLLY_BOOST_LINK_STATIC ON)
  else()
    set(FOLLY_BOOST_LINK_STATIC OFF)
  endif()
else()
  set(FOLLY_BOOST_LINK_STATIC "${BOOST_LINK_STATIC}")
endif()
set(Boost_USE_STATIC_LIBS "${FOLLY_BOOST_LINK_STATIC}")
##find Boost cannot use in newer CMake like Cmake3.31 
##
#list(APPEND CMAKE_MODULE_PATH "/usr/share/cmake-3.31/Modules")

#set(Boost_NO_BOOST_CMAKE ON)
#find_package(Boost 1.69.0 REQUIRED
#  COMPONENTS
#    context
#    filesystem
#    program_options
#    regex
#    thread
#)
#list(APPEND FOLLY_LINK_LIBRARIES ${Boost_LIBRARIES})
#list(APPEND FOLLY_INCLUDE_DIRECTORIES ${Boost_INCLUDE_DIRS})

message(STATUS ">> BYPASSING FindBoost: Forcing Manual Boost Configuration <<")

set(Boost_FOUND TRUE)
set(Boost_INCLUDE_DIRS "/usr/include")
set(BOOST_LIBRARYDIR   "/usr/lib")

# 定义一个宏，用来“伪造”Boost目标
macro(manual_boost_target name libname)
    if(NOT TARGET Boost::${name})
        add_library(Boost::${name} UNKNOWN IMPORTED)
        set_target_properties(Boost::${name} PROPERTIES
            IMPORTED_LOCATION "${BOOST_LIBRARYDIR}/libboost_${libname}.so"
            INTERFACE_INCLUDE_DIRECTORIES "${Boost_INCLUDE_DIRS}"
        )
    endif()
endmacro()

# 手动创建所有 Folly 可能用到的 Boost 组件
# 注意：即使 Folly 原本没列出这么多，多写几个不报错，防止隐式依赖
# manual_boost_target(context          context)
manual_boost_target(filesystem       filesystem)
manual_boost_target(program_options  program_options)
manual_boost_target(regex            regex)
manual_boost_target(system           system)
manual_boost_target(thread           thread)
manual_boost_target(atomic           atomic)
manual_boost_target(chrono           chrono)

# 汇总变量 (Folly 的 CMakeLists.txt 需要用到这几个变量)
set(Boost_LIBRARIES
    # Boost::context
    Boost::filesystem
    Boost::program_options
    Boost::regex
    Boost::system
    Boost::thread
    Boost::atomic
    Boost::chrono
)

# 手动将它们链接到 Folly (替代原本的 list APPEND)
list(APPEND FOLLY_LINK_LIBRARIES ${Boost_LIBRARIES})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${Boost_INCLUDE_DIRS})

message(STATUS ">> Manual Boost Configuration Applied Successfully <<")


#find_package(DoubleConversion MODULE REQUIRED)
#list(APPEND FOLLY_LINK_LIBRARIES ${DOUBLE_CONVERSION_LIBRARY})
#list(APPEND FOLLY_INCLUDE_DIRECTORIES ${DOUBLE_CONVERSION_INCLUDE_DIR})

# ==========================================================
# 🚀 手动配置 Double Conversion (Buildroot 专用)
# ==========================================================
message(STATUS ">> BYPASSING FindDoubleConversion: Forcing Manual Configuration <<")

set(DOUBLE_CONVERSION_FOUND TRUE)
# Buildroot 通常把头文件放在 /usr/include/double-conversion
# 但源码引用通常是 <double-conversion/xxx.h>，所以 include 路径设为 /usr/include
set(DOUBLE_CONVERSION_INCLUDE_DIR "/usr/include")
set(DOUBLE_CONVERSION_LIBRARY "/usr/lib/libdouble-conversion.so")

# 创建 Folly 可能需要的导入目标 (以防万一)
if(NOT TARGET double-conversion::double-conversion)
  add_library(double-conversion::double-conversion UNKNOWN IMPORTED)
  set_target_properties(double-conversion::double-conversion PROPERTIES
    IMPORTED_LOCATION "${DOUBLE_CONVERSION_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${DOUBLE_CONVERSION_INCLUDE_DIR}"
  )
endif()

# 填充 Folly 变量
list(APPEND FOLLY_LINK_LIBRARIES ${DOUBLE_CONVERSION_LIBRARY})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${DOUBLE_CONVERSION_INCLUDE_DIR})

message(STATUS ">> Manual DoubleConversion Configuration Applied <<")
# ==========================================================


# ==============================================================================
# 🚀 最终适配版：Folly 手动配置 (Based on user's ls output)
# ==============================================================================

# 定义你的安装目录 (根据日志修改)
set(OPT_DIR "/root/CacheLib/opt/cachelib")
set(OPT_LIB "${OPT_DIR}/lib64")  # 注意：日志显示是 lib64
set(OPT_INC "${OPT_DIR}/include")

# 定义系统路径变量，方便统一修改
set(SYS_INC "/usr/include")
set(SYS_LIB "/usr/lib")

# --------------------------------------------------------
# 1. FastFloat (Header Only - CRITICAL!)
# --------------------------------------------------------
message(STATUS ">> Manual: FastFloat <<")
# 注意：如果你手动把头文件放到了其他地方，请修改这里！
get_filename_component(MY_LOCAL_HEADERS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../local_headers" ABSOLUTE)

if(EXISTS "${MY_LOCAL_HEADERS_DIR}/fast_float/fast_float.h")
    message(STATUS "   Found local fast_float at: ${MY_LOCAL_HEADERS_DIR}")
    # 将 my_headers 目录加入搜索路径
    # 这样代码里的 #include <fast_float/fast_float.h> 就能找到文件了
    list(APPEND FOLLY_INCLUDE_DIRECTORIES "${MY_LOCAL_HEADERS_DIR}")
else()
    message(FATAL_ERROR "!!!! Error: Cannot find local fast_float headers at ${MY_LOCAL_HEADERS_DIR}/fast_float/fast_float.h !!!!")
endif()

# --------------------------------------------------------
# 2. Gflags (已确认存在)
# --------------------------------------------------------
message(STATUS ">> Manual: Gflags <<")
set(LIBGFLAGS_FOUND TRUE)
set(FOLLY_HAVE_LIBGFLAGS TRUE)
# 优先找 opt，找不到找系统
if(EXISTS "${OPT_LIB}/libgflags.so")
    set(LIBGFLAGS_LIBRARY "${OPT_LIB}/libgflags.so")
    set(LIBGFLAGS_INCLUDE_DIR "${OPT_INC}")
else()
    set(LIBGFLAGS_LIBRARY "${SYS_LIB}/libgflags.so")
    set(LIBGFLAGS_INCLUDE_DIR "${SYS_INC}")
endif()

list(APPEND FOLLY_LINK_LIBRARIES ${LIBGFLAGS_LIBRARY})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${LIBGFLAGS_INCLUDE_DIR})
set(FOLLY_LIBGFLAGS_LIBRARY ${LIBGFLAGS_LIBRARY})
set(FOLLY_LIBGFLAGS_INCLUDE ${LIBGFLAGS_INCLUDE_DIR})
# --------------------------------------------------------
# 3. Glog (已确认存在)
# --------------------------------------------------------
message(STATUS ">> Manual: Glog <<")
set(GLOG_FOUND TRUE)
set(FOLLY_HAVE_LIBGLOG TRUE)

if(EXISTS "${OPT_LIB}/libglog.so")
    set(GLOG_LIBRARY "${OPT_LIB}/libglog.so")
    set(GLOG_INCLUDE_DIR "${OPT_INC}")
else()
    set(GLOG_LIBRARY "${SYS_LIB}/libglog.so")
    set(GLOG_INCLUDE_DIR "${SYS_INC}")
endif()

list(APPEND FOLLY_LINK_LIBRARIES ${GLOG_LIBRARY})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${GLOG_INCLUDE_DIR})

# --------------------------------------------------------
# 4. fmt (在 opt 中 - 关键修正!)
# --------------------------------------------------------
message(STATUS ">> Manual: fmt <<")

if(EXISTS "${OPT_LIB}/libfmt.so")
    set(FMT_LIB_PATH "${OPT_LIB}/libfmt.so")
    set(FMT_INC_PATH "${OPT_INC}")
else()
    set(FMT_LIB_PATH "${SYS_LIB}/libfmt.so")
    set(FMT_INC_PATH "${SYS_INC}")
endif()

if(NOT TARGET fmt::fmt)
    add_library(fmt::fmt UNKNOWN IMPORTED)
    set_target_properties(fmt::fmt PROPERTIES
        IMPORTED_LOCATION "${FMT_LIB_PATH}"
        INTERFACE_INCLUDE_DIRECTORIES "${FMT_INC_PATH}"
    )
endif()
# --------------------------------------------------------
# 5. Zstd (在 opt 中)
# --------------------------------------------------------
message(STATUS ">> Manual: Zstd <<")
if(EXISTS "${OPT_LIB}/libzstd.so")
    set(FOLLY_HAVE_LIBZSTD TRUE)
    list(APPEND FOLLY_INCLUDE_DIRECTORIES "${OPT_INC}")
    list(APPEND FOLLY_LINK_LIBRARIES "${OPT_LIB}/libzstd.so")
endif()
# --------------------------------------------------------
# 4. LibEvent (已确认存在)
# --------------------------------------------------------
message(STATUS ">> Manual: LibEvent <<")
set(LIBEVENT_LIB "${SYS_LIB}/libevent.so")
set(LIBEVENT_INCLUDE_DIR "${SYS_INC}")

list(APPEND FOLLY_LINK_LIBRARIES ${LIBEVENT_LIB})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${LIBEVENT_INCLUDE_DIR})

# --------------------------------------------------------
# 5. ZLIB (已确认存在)
# --------------------------------------------------------
message(STATUS ">> Manual: ZLIB <<")
set(ZLIB_FOUND TRUE)
set(FOLLY_HAVE_LIBZ TRUE)
set(ZLIB_LIBRARIES "${SYS_LIB}/libz.so")
set(ZLIB_INCLUDE_DIRS "${SYS_INC}")

list(APPEND FOLLY_INCLUDE_DIRECTORIES ${ZLIB_INCLUDE_DIRS})
list(APPEND FOLLY_LINK_LIBRARIES ${ZLIB_LIBRARIES})
list(APPEND CMAKE_REQUIRED_LIBRARIES ${ZLIB_LIBRARIES})
# --------------------------------------------------------
# 8. Boost (我们在 Buildroot 里，通常在 /usr/lib)
# --------------------------------------------------------
message(STATUS ">> Manual: Boost (System) <<")
set(Boost_FOUND TRUE)
set(Boost_INCLUDE_DIRS "${SYS_INC}")
set(BOOST_LIBRARYDIR   "${SYS_LIB}")

macro(manual_boost_target name libname)
    if(NOT TARGET Boost::${name})
        add_library(Boost::${name} UNKNOWN IMPORTED)
        set_target_properties(Boost::${name} PROPERTIES
            IMPORTED_LOCATION "${BOOST_LIBRARYDIR}/libboost_${libname}.so"
            INTERFACE_INCLUDE_DIRECTORIES "${Boost_INCLUDE_DIRS}"
        )
    endif()
endmacro()

#manual_boost_target(context          context)
manual_boost_target(filesystem       filesystem)
manual_boost_target(program_options  program_options)
manual_boost_target(regex            regex)
manual_boost_target(system           system)
manual_boost_target(thread           thread)
manual_boost_target(atomic           atomic)
manual_boost_target(chrono           chrono)

set(Boost_LIBRARIES Boost::filesystem Boost::program_options Boost::regex Boost::system Boost::thread Boost::atomic Boost::chrono)

list(APPEND FOLLY_LINK_LIBRARIES ${Boost_LIBRARIES})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${Boost_INCLUDE_DIRS})
# --------------------------------------------------------
# 6. OpenSSL (已确认存在)
# --------------------------------------------------------
message(STATUS ">> Manual: OpenSSL <<")
set(OPENSSL_FOUND TRUE)
set(OPENSSL_INCLUDE_DIR "${SYS_INC}")
set(OPENSSL_LIBRARIES "${SYS_LIB}/libssl.so" "${SYS_LIB}/libcrypto.so")

list(APPEND FOLLY_LINK_LIBRARIES ${OPENSSL_LIBRARIES})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${OPENSSL_INCLUDE_DIR})

# --------------------------------------------------------
# 7. 可选压缩库 (根据 ls 结果动态加载)
# --------------------------------------------------------

# BZip2 (已确认存在)
message(STATUS ">> Manual: BZip2 (Found) <<")
set(FOLLY_HAVE_LIBBZ2 TRUE)
list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libbz2.so")

# LibLZMA (已确认存在)
message(STATUS ">> Manual: LibLZMA (Found) <<")
set(FOLLY_HAVE_LIBLZMA TRUE)
list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/liblzma.so")

# Zstd (已确认存在)
message(STATUS ">> Manual: Zstd (Found) <<")
set(FOLLY_HAVE_LIBZSTD TRUE)
list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libzstd.so")

# LZ4 / Snappy (已确认缺失，自动跳过)
message(STATUS ">> Manual: LZ4/Snappy (Skipping - Not found) <<")
set(FOLLY_HAVE_LIBLZ4 FALSE)
set(FOLLY_HAVE_LIBSNAPPY FALSE)

# --------------------------------------------------------
# 8. Libiberty (已确认存在 .a)
# --------------------------------------------------------
message(STATUS ">> Manual: Libiberty (Found Static: libiberty.a) <<")
list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libiberty.a")

# --------------------------------------------------------
# 9. LibAIO (已确认存在)
# --------------------------------------------------------
message(STATUS ">> Manual: LibAIO (Found) <<")
list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libaio.so")

# --------------------------------------------------------
# 10. 其他缺失的可选库 (自动跳过)
# --------------------------------------------------------
message(STATUS ">> Manual: Skipping LibDwarf, LibUring, LibSodium, LibUnwind (Not found) <<")
set(LIBDWARF_FOUND FALSE)
set(FOLLY_HAVE_LIBDWARF FALSE)
set(LIBUNWIND_FOUND FALSE)
set(FOLLY_HAVE_LIBUNWIND FALSE)
set(FOLLY_USE_SYMBOLIZER OFF) # 缺少 Dwarf/Unwind 时必须关闭

# --------------------------------------------------------
# 11. 系统基础配置
# --------------------------------------------------------
list(APPEND FOLLY_LINK_LIBRARIES ${CMAKE_DL_LIBS})
list(APPEND CMAKE_REQUIRED_LIBRARIES ${CMAKE_DL_LIBS})

# C++ Atomic 检查 (保留原逻辑，通常 GCC 14 需要 libatomic)
check_cxx_source_compiles("
  #include <atomic>
  int main() { std::atomic<int> a; return a.fetch_add(1); }
" FOLLY_CPP_ATOMIC_BUILTIN)

if(NOT FOLLY_CPP_ATOMIC_BUILTIN)
  list(APPEND FOLLY_LINK_LIBRARIES atomic)
endif()

message(STATUS ">> Manual Config Complete. Good luck! <<")
# ==========================================================
# 12. 重建 folly_deps 目标 (关键！)
# ==========================================================
message(STATUS ">> Manual: Recreating folly_deps target <<")

add_library(folly_deps INTERFACE)
target_link_libraries(folly_deps INTERFACE fmt::fmt)
target_link_libraries(folly_deps INTERFACE ${FOLLY_LINK_LIBRARIES})

list(REMOVE_DUPLICATES FOLLY_INCLUDE_DIRECTORIES)
target_include_directories(folly_deps INTERFACE ${FOLLY_INCLUDE_DIRECTORIES})

if(FOLLY_ASAN_FLAGS)
    target_link_libraries(folly_deps INTERFACE ${FOLLY_ASAN_FLAGS})
endif()

message(STATUS ">> folly_deps Configured. Ready to build! <<")
