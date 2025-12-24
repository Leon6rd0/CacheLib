# ==============================================================================
# 🚀 自制 FindSodium.cmake 
#    用于解决 fizz-config.cmake 找不到 Sodium 的问题
# ==============================================================================

message(STATUS ">> Using Custom FindSodium.cmake for Buildroot <<")

# 1. 定义库路径 (指向你的 SCP 目标路径)
set(SODIUM_INCLUDE_DIR "/usr/include")
set(SODIUM_LIBRARY "/usr/lib/libsodium.so")

# 2. 标记为已找到
set(Sodium_FOUND TRUE)
set(SODIUM_FOUND TRUE)
set(sodium_FOUND TRUE)

# 3. 填充标准变量
set(SODIUM_LIBRARIES "${SODIUM_LIBRARY}")
set(SODIUM_INCLUDE_DIRS "${SODIUM_INCLUDE_DIR}")

# 4. 创建导入目标 (Target) - 防止报错
if(NOT TARGET sodium)
    add_library(sodium UNKNOWN IMPORTED)
    set_target_properties(sodium PROPERTIES
        IMPORTED_LOCATION "${SODIUM_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${SODIUM_INCLUDE_DIR}"
    )
endif()

message(STATUS ">> Custom Sodium Found: ${SODIUM_LIBRARY} <<")
