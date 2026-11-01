#!/usr/bin/env bash
# ci-build.sh —— CI 上的统一两步构建（host hermesc → 主构建）
#
# Hermes 需要 host 架构的 hermesc 来编译内部 JavaScript（InternalJavaScript），
# 交叉编译时（Android arm64）主构建里编不出 host 工具，所以永远是两步：
#   1. build-host/：host 原生只编 hermesc（HERMES_BUILD_HERMESC_ONLY，vendored 补丁）
#   2. 主构建：-DIMPORT_HOST_COMPILERS 导入上一步的产物
#
# 用法：PXTBUILD=/path scripts/ci-build.sh <build-dir> [主构建额外 cmake 参数...]
# 环境变量：
#   PXTBUILD     pxtc 环境目录（CI 由 tools/setup_pxtc.js 准备）
#   CI_TARGETS   要编的目标，默认 "makecode_arcade_libretro core_test jit_probe"；
#                Android 交叉构建时外部设成只编核心库
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
BUILD=${1:?usage: ci-build.sh <build-dir> [cmake args...]}
shift
TARGETS=${CI_TARGETS:-"makecode_arcade_libretro core_test jit_probe"}

# ---- 第 1 步：host 原生 hermesc -----------------------------------------
cmake -B build-host -S third_party/hermes -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DHERMES_ENABLE_TOOLS=ON \
    -DHERMES_BUILD_HERMESC_ONLY=ON \
    -DHERMES_ENABLE_TEST_SUITE=OFF \
    -DHERMES_ENABLE_DEBUGGER=OFF \
    -DHERMES_ENABLE_NAPI=OFF \
    -DHERMES_ENABLE_CORE_EXTENSIONS=OFF \
    -DHERMESVM_ALLOW_JIT=0
cmake --build build-host --target hermesc -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"

# ---- 第 2 步：主构建 -----------------------------------------------------
cmake -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DPXTBUILD="${PXTBUILD:?PXTBUILD 未设置}" \
    -DIMPORT_HOST_COMPILERS="$ROOT/build-host/ImportHostCompilers.cmake" \
    "$@"
cmake --build "$BUILD" --target $TARGETS -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"

echo "=== 产物 ==="
ls -lh "$BUILD"/makecode_arcade_libretro.* 2>/dev/null || true
