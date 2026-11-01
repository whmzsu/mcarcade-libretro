/*
 * jit_probe —— 编译期/运行时 JIT 平台探针（一次性小工具）
 *
 * 1. 打印 vendored Hermes 内部 JIT Config 宏（HERMESVM_JIT 等），
 *    CI 用它断言发布平台是否带 JIT 编译产物。
 * 2. 再起一个 EnableJIT=true 的 runtime 跑一段热循环，
 *    能跑通说明 JIT 路径（若编译进来）至少能初始化、不崩。
 *
 * 注意：Config.h 是 Hermes 内部头，路径 third_party/hermes/include。
 */
#include <cstdio>
#include <chrono>

#include "hermes/VM/JIT/Config.h"
#include "hermes/hermes.h"
#include "jsi/jsi.h"

using namespace facebook;

int main()
{
    std::printf("HERMESVM_ALLOW_JIT built with: HERMESVM_JIT=%d X86_64=%d ARM64=%d\n",
                HERMESVM_JIT, HERMESVM_JIT_X86_64, HERMESVM_JIT_ARM64);

    ::hermes::vm::RuntimeConfig::Builder cfg;
    cfg.withEnableJIT(true);
    auto rt = facebook::hermes::makeHermesRuntime(cfg.build());

    auto t0 = std::chrono::steady_clock::now();
    /* 2000 万次迭代热循环：解释器 ~几百 ms，JIT 下更快；只要不崩即可 */
    double v = rt->evaluateJavaScript(
        std::make_unique<jsi::StringBuffer>(
            "(function(){ var s = 0;"
            "for (var i = 0; i < 20000000; i++) { s += i % 7; }"
            "return s; })()"),
        "jitprobe.js")
                   .asNumber();
    auto t1 = std::chrono::steady_clock::now();

    std::printf("hot loop ok: s=%g, %.1f ms\n", v,
                std::chrono::duration<double, std::milli>(t1 - t0).count());
    return 0;
}
