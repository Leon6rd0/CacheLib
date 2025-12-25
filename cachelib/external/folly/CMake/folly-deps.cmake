# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
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

# ==============================================================================
# 🚀 动态路径探测 (Dynamic Path Resolution)
# ==============================================================================

# 1. 确定当前脚本的位置 (CacheLib/cachelib/external/folly/CMake)
set(CURRENT_SCRIPT_DIR "${CMAKE_CURRENT_LIST_DIR}")

# 2. 回溯 4 层找到项目根目录 (CacheLib/)
get_filename_component(PROJECT_ROOT "${CURRENT_SCRIPT_DIR}/../../../../" ABSOLUTE)

# 3. 动态设定 opt 目录
set(OPT_DIR "${PROJECT_ROOT}/opt/cachelib")
set(OPT_LIB "${OPT_DIR}/lib64")
set(OPT_INC "${OPT_DIR}/include")

# 4. 动态设定 local_headers (用于 fast_float)
# 位置通常在 CacheLib/cachelib/external/local_headers (即脚本向上两层的 sibling)
get_filename_component(LOCAL_HEADERS_DIR "${CURRENT_SCRIPT_DIR}/../../local_headers" ABSOLUTE)

# 打印调试信息，让你确认路径是否正确
message(STATUS ">> [Folly-Deps] 自动探测路径:")
message(STATUS "   Project Root : ${PROJECT_ROOT}")
message(STATUS "   Opt Dir      : ${OPT_DIR}")
message(STATUS "   Local Headers: ${LOCAL_HEADERS_DIR}")

# 定义系统路径变量
set(SYS_INC "/usr/include")
set(SYS_LIB "/usr/lib")

set(FOLLY_LINK_LIBRARIES "")
set(FOLLY_INCLUDE_DIRECTORIES "")

# ==============================================================================
# 1. Boost (Manual Configuration)
# ==============================================================================
message(STATUS ">> Manual: Boost <<")
set(Boost_FOUND TRUE)
set(FOLLY_BOOST_LINK_STATIC OFF)

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

manual_boost_target(context          context)
manual_boost_target(filesystem       filesystem)
manual_boost_target(program_options  program_options)
manual_boost_target(regex            regex)
manual_boost_target(system           system)
manual_boost_target(thread           thread)
manual_boost_target(atomic           atomic)
manual_boost_target(chrono           chrono)

set(Boost_LIBRARIES 
    Boost::context Boost::filesystem Boost::program_options Boost::regex 
    Boost::system Boost::thread Boost::atomic Boost::chrono
)

list(APPEND FOLLY_LINK_LIBRARIES ${Boost_LIBRARIES})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${Boost_INCLUDE_DIRS})

# ==============================================================================
# 2. Double Conversion (Manual)
# ==============================================================================
message(STATUS ">> Manual: Double Conversion <<")
set(DOUBLE_CONVERSION_FOUND TRUE)
set(DOUBLE_CONVERSION_INCLUDE_DIR "${SYS_INC}")
set(DOUBLE_CONVERSION_LIBRARY "${SYS_LIB}/libdouble-conversion.so")

if(NOT TARGET double-conversion::double-conversion)
  add_library(double-conversion::double-conversion UNKNOWN IMPORTED)
  set_target_properties(double-conversion::double-conversion PROPERTIES
    IMPORTED_LOCATION "${DOUBLE_CONVERSION_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${DOUBLE_CONVERSION_INCLUDE_DIR}"
  )
endif()

list(APPEND FOLLY_LINK_LIBRARIES ${DOUBLE_CONVERSION_LIBRARY})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${DOUBLE_CONVERSION_INCLUDE_DIR})

# ==============================================================================
# 3. FastFloat (Header Only - Dynamic Path)
# ==============================================================================
message(STATUS ">> Manual: FastFloat <<")

if(EXISTS "${LOCAL_HEADERS_DIR}/fast_float/fast_float.h")
    message(STATUS "   Found local fast_float at: ${LOCAL_HEADERS_DIR}")
    list(APPEND FOLLY_INCLUDE_DIRECTORIES "${LOCAL_HEADERS_DIR}")
else()
    message(WARNING "!!!! Warning: Cannot find fast_float at ${LOCAL_HEADERS_DIR}. Compilation may fail if system headers are missing. !!!!")
endif()

# ==============================================================================
# 4. Gflags & Glog (Manual - Prioritize OPT)
# ==============================================================================
message(STATUS ">> Manual: Gflags & Glog <<")
set(LIBGFLAGS_FOUND TRUE)
set(FOLLY_HAVE_LIBGFLAGS TRUE)
set(GLOG_FOUND TRUE)
set(FOLLY_HAVE_LIBGLOG TRUE)

# Gflags
if(EXISTS "${OPT_LIB}/libgflags.so")
    set(LIBGFLAGS_LIBRARY "${OPT_LIB}/libgflags.so")
    set(LIBGFLAGS_INCLUDE_DIR "${OPT_INC}")
else()
    set(LIBGFLAGS_LIBRARY "${SYS_LIB}/libgflags.so")
    set(LIBGFLAGS_INCLUDE_DIR "${SYS_INC}")
endif()

# Glog
if(EXISTS "${OPT_LIB}/libglog.so")
    set(GLOG_LIBRARY "${OPT_LIB}/libglog.so")
    set(GLOG_INCLUDE_DIR "${OPT_INC}")
else()
    set(GLOG_LIBRARY "${SYS_LIB}/libglog.so")
    set(GLOG_INCLUDE_DIR "${SYS_INC}")
endif()

list(APPEND FOLLY_LINK_LIBRARIES ${LIBGFLAGS_LIBRARY} ${GLOG_LIBRARY})
list(APPEND FOLLY_INCLUDE_DIRECTORIES ${LIBGFLAGS_INCLUDE_DIR} ${GLOG_INCLUDE_DIR})

set(FOLLY_LIBGFLAGS_LIBRARY ${LIBGFLAGS_LIBRARY})
set(FOLLY_LIBGFLAGS_INCLUDE ${LIBGFLAGS_INCLUDE_DIR})

# ==============================================================================
# 5. fmt (Manual - Prioritize OPT)
# ==============================================================================
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

# ==============================================================================
# 6. LibEvent & OpenSSL & ZLIB
# ==============================================================================
message(STATUS ">> Manual: LibEvent, OpenSSL, ZLIB <<")

list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libevent.so")

set(OPENSSL_FOUND TRUE)
list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libssl.so" "${SYS_LIB}/libcrypto.so")
list(APPEND FOLLY_INCLUDE_DIRECTORIES "${SYS_INC}")

set(ZLIB_FOUND TRUE)
set(FOLLY_HAVE_LIBZ TRUE)
list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libz.so")

# ==============================================================================
# 7. Optional Compression (Prioritize OPT for Zstd)
# ==============================================================================
message(STATUS ">> Manual: Checking Optional Libs <<")

if(EXISTS "${SYS_LIB}/libbz2.so")
    set(FOLLY_HAVE_LIBBZ2 TRUE)
    list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libbz2.so")
endif()

if(EXISTS "${SYS_LIB}/liblzma.so")
    set(FOLLY_HAVE_LIBLZMA TRUE)
    list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/liblzma.so")
endif()

# Zstd Check
if(EXISTS "${OPT_LIB}/libzstd.so")
    set(FOLLY_HAVE_LIBZSTD TRUE)
    list(APPEND FOLLY_LINK_LIBRARIES "${OPT_LIB}/libzstd.so")
    list(APPEND FOLLY_INCLUDE_DIRECTORIES "${OPT_INC}")
elseif(EXISTS "${SYS_LIB}/libzstd.so")
    set(FOLLY_HAVE_LIBZSTD TRUE)
    list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libzstd.so")
endif()

if(EXISTS "${SYS_LIB}/libiberty.a")
    list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libiberty.a")
endif()

if(EXISTS "${SYS_LIB}/libaio.so")
    list(APPEND FOLLY_LINK_LIBRARIES "${SYS_LIB}/libaio.so")
endif()

set(FOLLY_HAVE_LIBLZ4 FALSE)
set(FOLLY_HAVE_LIBSNAPPY FALSE)
set(FOLLY_HAVE_LIBDWARF FALSE)
set(FOLLY_HAVE_LIBUNWIND FALSE)
set(FOLLY_USE_SYMBOLIZER OFF) 

# ==============================================================================
# 8. System & Atomics
# ==============================================================================
list(APPEND FOLLY_LINK_LIBRARIES ${CMAKE_DL_LIBS})

check_cxx_source_compiles("
  #include <atomic>
  int main() { std::atomic<int> a; return a.fetch_add(1); }
" FOLLY_CPP_ATOMIC_BUILTIN)

if(NOT FOLLY_CPP_ATOMIC_BUILTIN)
  list(APPEND FOLLY_LINK_LIBRARIES atomic)
endif()

# ==============================================================================
# 9. FINAL TARGET CREATION: folly_deps
# ==============================================================================
message(STATUS ">> [Folly-Deps] Creating final folly_deps target... <<")

if(NOT TARGET folly_deps)
    add_library(folly_deps INTERFACE)
endif()

target_link_libraries(folly_deps INTERFACE fmt::fmt)
target_link_libraries(folly_deps INTERFACE ${FOLLY_LINK_LIBRARIES})

if(FOLLY_INCLUDE_DIRECTORIES)
    list(REMOVE_DUPLICATES FOLLY_INCLUDE_DIRECTORIES)
endif()
target_include_directories(folly_deps INTERFACE ${FOLLY_INCLUDE_DIRECTORIES})

if(FOLLY_ASAN_FLAGS)
    target_link_libraries(folly_deps INTERFACE ${FOLLY_ASAN_FLAGS})
endif()

message(STATUS ">> [Folly-Deps] Configuration Complete! <<")
