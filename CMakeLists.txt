# makecode_arcade_libretro —— MakeCode Arcade libretro 核心（Hermes 引擎版）
#
# 与旧核心（makecode-arcade-core，QuickJS）的区别：
#   游戏运行时换 Hermes（AOT 字节码 + 高速解释器 + 可选 JIT），
#   binary.js 额外编译成 Hermes 字节码并落盘缓存（二次加载零编译）。
#   内嵌 pxt 编译器（png → binary.js）仍走 QuickJS（久经考验，5 秒一次性开销）。
#
# 依赖：CMake 3.22+、Ninja、MSVC 2022（Windows）/ clang（Linux/macOS）、
#       Python 3、Node + pxtc 环境（仅构建期需要，见 tools/setup_pxtc.js）。
#
# 常用命令（Windows）：
#   cmake -B build -G Ninja
#   cmake --build build                      # → build/makecode_arcade_libretro.dll
#   python scripts\package.py（后续补）
#
# 可调参数：
#   -DPXTBUILD=E:/pxtbuild   pxtc 环境目录（默认取环境变量 PXTBUILD，再退 E:/pxtbuild）
#   -DHERMES_JIT=1           Hermes JIT：0 关 / 1 自动（默认）/ 2 强制开

cmake_minimum_required(VERSION 3.22)
project(makecode_arcade_libretro C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
# Hermes 公开头文件（jsi.h 用了 std::string::data() 非 const 重载）要求 C++20
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# 本机代码页是 GBK：Hermes 源码里的 UTF-8 字符串字面量会被读坏（C2001/C4819）
if(MSVC)
    add_compile_options(/utf-8)
endif()

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# ---------------------------------------------------------------- pxtc 环境
# 内嵌编译器载荷从 pxtc 环境里打包（构建期需要，运行期不需要 Node）。
if(NOT PXTBUILD)
    if(DEFINED ENV{PXTBUILD} AND NOT "$ENV{PXTBUILD}" STREQUAL "")
        set(PXTBUILD "$ENV{PXTBUILD}")
    else()
        set(PXTBUILD "E:/pxtbuild")
    endif()
endif()
message(STATUS "PXTBUILD = ${PXTBUILD}")

find_package(Python3 REQUIRED COMPONENTS Interpreter)

# ---------------------------------------------------------------- Hermes
# 用作 add_subdirectory 子项目，按需瘦身：
#   测试套件 / CLI 工具全关（hermesc 也不编：字节码生成走 in-process compileJS）
#   JIT 跟随平台自动开（x64 / arm64 支持；HERMESVM_ALLOW_JIT 0=关 1=自动 2=强制）
set(HERMES_ENABLE_TEST_SUITE   OFF CACHE BOOL "" FORCE)
set(HERMES_ENABLE_TOOLS        OFF CACHE BOOL "" FORCE)
set(HERMES_ENABLE_DEBUGGER     OFF CACHE BOOL "" FORCE)
set(HERMES_ENABLE_CORE_EXTENSIONS OFF CACHE BOOL "" FORCE)
set(HERMES_ENABLE_CONTRIB_EXTENSIONS OFF CACHE BOOL "" FORCE)
set(HERMES_ENABLE_NAPI         OFF CACHE BOOL "" FORCE)
set(HERMESVM_ALLOW_JIT         1 CACHE STRING "" FORCE)
set(HERMES_BUILD_APPLE_FRAMEWORK OFF CACHE BOOL "" FORCE)
add_subdirectory(third_party/hermes hermes_build)

# ---------------------------------------------------------------- 内嵌资源
# pxt_bundle.h          runtime JS + 官方 pxt sim（跑游戏）
# pxt_compiler_bundle.h pxt 编译器载荷（png 卡带内嵌编译，LZMA 压缩）
set(GEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/gen)
file(MAKE_DIRECTORY ${GEN_DIR})

set(PXT_BUNDLE_DEPS
    runtime/timers.js
    runtime/dom_mock.js
    runtime/audio.js
    runtime/glue.js
    third_party/pxt-sim/pxtsim.js
    third_party/pxt-sim/common-sim.js
    third_party/pxt-sim/sim.js)

add_custom_command(
    OUTPUT  ${GEN_DIR}/pxt_bundle.h
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/scripts/gen_bundle.py
            ${GEN_DIR}/pxt_bundle.h
    DEPENDS ${PXT_BUNDLE_DEPS} scripts/gen_bundle.py
    COMMENT "gen pxt_bundle.h (runtime JS + pxt sim)"
    VERBATIM)

add_custom_command(
    OUTPUT  ${GEN_DIR}/pxt_compiler_bundle.h
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/scripts/gen_compiler_bundle.py
            --pxt-core  ${PXTBUILD}/node_modules/pxt-core
            --pxt-arcade ${PXTBUILD}/node_modules/pxt-arcade
            --runtime   ${CMAKE_CURRENT_SOURCE_DIR}/runtime/compiler.js
            --out       ${GEN_DIR}/pxt_compiler_bundle.h
    DEPENDS runtime/compiler.js scripts/gen_compiler_bundle.py
    COMMENT "gen pxt_compiler_bundle.h (pxtc payload, needs PXTBUILD)"
    VERBATIM)

# ---------------------------------------------------------------- QuickJS（仅内嵌编译器用）
add_library(qjs_compiler STATIC
    third_party/quickjs/quickjs.c
    third_party/quickjs/dtoa.c
    third_party/quickjs/libregexp.c
    third_party/quickjs/libunicode.c)
target_include_directories(qjs_compiler PUBLIC third_party/quickjs)
# 编译器 runtime 是临时品，不需要它的 std 模块/网络
target_compile_definitions(qjs_compiler PRIVATE
    CONFIG_VERSION="quickjs"
    _CRT_SECURE_NO_WARNINGS)

# ---------------------------------------------------------------- 核心本体
# 用 OBJECT 库共享编译产物：SHARED core（给 RetroArch）+ core_test（自检）共用。
add_library(arcade_core_obj OBJECT
    src/core.cpp
    src/cart.c
    src/cache.c
    src/decompress.c
    src/compiler.c
    third_party/lzma/LzmaDec.c
    # miniz 用 Hermes 自带的 zip 版（external/zip/src，已在 hermesvm_a 里编好），
    # 自己再编一份会和它 mz_* 符号冲突
    # 生成的头注册进来，ninja 才会在编译前先跑 gen 脚本
    ${GEN_DIR}/pxt_bundle.h
    ${GEN_DIR}/pxt_compiler_bundle.h)
target_include_directories(arcade_core_obj PRIVATE
    src
    third_party/libretro
    third_party/quickjs
    third_party/lzma
    third_party/hermes/external/zip/src
    third_party/hermes/API
    third_party/hermes/API/jsi
    third_party/hermes/public
    ${GEN_DIR})
target_compile_definitions(arcade_core_obj PRIVATE _CRT_SECURE_NO_WARNINGS)

if(MSVC)
    # /EHsc：jsi/Hermes 用 C++ 异常报 JS 错误；utf-8 源码
    target_compile_options(arcade_core_obj PRIVATE /EHsc /utf-8)
    target_compile_definitions(arcade_core_obj PRIVATE
        NOMINMAX WIN32_LEAN_AND_MEAN)
endif()

# 核心动态库：libretro 命名硬要求，文件名不带 lib 前缀
add_library(makecode_arcade_libretro SHARED $<TARGET_OBJECTS:arcade_core_obj>)
set_target_properties(makecode_arcade_libretro PROPERTIES
    OUTPUT_NAME "makecode_arcade_libretro"
    PREFIX "")
target_link_libraries(makecode_arcade_libretro PRIVATE
    hermesvm_a
    compileJS
    qjs_compiler)

# ---------------------------------------------------------------- 自检
add_executable(core_test tests/core_test.c $<TARGET_OBJECTS:arcade_core_obj>)
target_include_directories(core_test PRIVATE
    src
    third_party/libretro
    third_party/quickjs
    third_party/hermes/API
    third_party/hermes/API/jsi
    third_party/hermes/public
    ${GEN_DIR})
target_link_libraries(core_test PRIVATE hermesvm_a compileJS qjs_compiler)
if(MSVC)
    target_compile_options(core_test PRIVATE /EHsc /utf-8)
    # retro_load_game 的 png 编译路径在 RetroArch 是 1MB 线程栈里跑的，
    # 自检也用小栈逼近（链接器栈保留 16MB 给 tsc 的深递归）
    target_link_options(core_test PRIVATE /STACK:16777216)
endif()

# 一次性实验：验证 Hermes JIT 是否生效（tools/bench_hermes.cpp）
add_executable(bench_hermes tools/bench_hermes.cpp)
target_include_directories(bench_hermes PRIVATE
    third_party/hermes/API
    third_party/hermes/API/jsi
    third_party/hermes/public)
target_link_libraries(bench_hermes PRIVATE hermesvm_a)
if(MSVC)
    target_link_options(bench_hermes PRIVATE /STACK:16777216)
    target_compile_options(bench_hermes PRIVATE /EHsc /utf-8)
endif()
