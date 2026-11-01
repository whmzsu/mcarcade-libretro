/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#ifndef HERMES_VM_JIT_CONFIG_H
#define HERMES_VM_JIT_CONFIG_H

#include "hermes/VM/sh_config.h"

#ifdef HERMESVM_JIT
#error HERMESVM_JIT must only be defined by this file
#endif

#if HERMESVM_ALLOW_JIT == 0
#define HERMESVM_JIT 0
#elif HERMESVM_ALLOW_JIT == 2
#define HERMESVM_JIT 1
#elif HERMESVM_ALLOW_JIT == 1

// Disable JIT on Apple platforms that prohibit it.
#ifdef __APPLE__
#include <TargetConditionals.h>
#if !defined(HERMESVM_JIT) &&                                      \
    !((defined(TARGET_OS_MACCATALYST) && TARGET_OS_MACCATALYST) || \
      (defined(TARGET_OS_OSX) && TARGET_OS_OSX))
#define HERMESVM_JIT 0
#endif
#endif

// If the JIT is allowed by configuration, enable it on platforms that support
// it.
#if !defined(HERMESVM_JIT) &&                                           \
    (defined(__aarch64__) || defined(_M_ARM64) ||                       \
     ((defined(__x86_64__) || defined(_M_X64)) && !defined(_WIN32))) && \
    (!defined(HERMESVM_COMPRESSED_POINTERS) ||                          \
     defined(HERMESVM_CONTIGUOUS_HEAP))
#define HERMESVM_JIT 1
#else
#define HERMESVM_JIT 0
#endif

#else
#error HERMESVM_ALLOW_JIT must have a value of 1 or 2
#endif

// Per-architecture JIT selectors. At most one is 1. Both are 0 when the JIT
// is disabled, or when HERMESVM_ALLOW_JIT=2 forces it on an architecture
// without a backend, which JitCurArch.h then rejects. Arch-specific sources
// self-guard on these so that both backend subtrees can be listed in the
// build unconditionally.
// [mcarcade note] 试过在 Windows x64 放行 JIT（上游刻意禁用）：x86-64 后端
// 用了 GCC 专属 __attribute__ 且 _setjmp 与 MSVC SEH 不兼容（C7552），
// 短期无法在 MSVC 下编译。维持上游行为：Windows 走 AOT 字节码 + 解释器，
// Linux/Android 自动开 JIT。
#if HERMESVM_JIT && (defined(__aarch64__) || defined(_M_ARM64))
#define HERMESVM_JIT_ARM64 1
#else
#define HERMESVM_JIT_ARM64 0
#endif
#if HERMESVM_JIT && (defined(__x86_64__) || defined(_M_X64)) && !defined(_WIN32)
#define HERMESVM_JIT_X86_64 1
#else
#define HERMESVM_JIT_X86_64 0
#endif

// Only enable perf profiling support on Linux/Android when JIT is enabled and
// HERMES_IS_MOBILE_BUILD is false.
#if HERMESVM_JIT && !defined(HERMES_IS_MOBILE_BUILD) && \
    (defined(__linux__) || defined(__ANDROID__))
#define HERMES_ENABLE_PERF_PROF
#endif

#endif // HERMES_VM_JIT_CONFIG_H
