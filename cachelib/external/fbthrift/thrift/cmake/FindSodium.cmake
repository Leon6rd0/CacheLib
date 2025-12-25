# ==============================================================================
# 🚀 救命版 FindSodium.cmake (放入 thrift/cmake)
# ==============================================================================
message(STATUS ">> LOADED: Custom FindSodium.cmake from thrift/cmake <<")

set(SODIUM_INCLUDE_DIR "/usr/include")
set(SODIUM_LIBRARY "/usr/lib/libsodium.so")

set(Sodium_FOUND TRUE)
set(SODIUM_FOUND TRUE)
set(sodium_FOUND TRUE)

set(SODIUM_LIBRARIES "${SODIUM_LIBRARY}")
set(SODIUM_INCLUDE_DIRS "${SODIUM_INCLUDE_DIR}")

if(NOT TARGET sodium)
    add_library(sodium UNKNOWN IMPORTED)
    set_target_properties(sodium PROPERTIES
        IMPORTED_LOCATION "${SODIUM_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${SODIUM_INCLUDE_DIR}"
    )
endif()
