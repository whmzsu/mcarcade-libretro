// bench_hermes.cpp —— 一次性实验：验证 Hermes JIT 在 Windows x64 是否生效
#include <cstdio>
#include <string>
#include <chrono>
#include <jsi/jsi.h>
#include <hermes/hermes.h>

namespace jsi = facebook::jsi;

static double run(bool jit, const char *code)
{
    printf("  run(jit=%d) creating runtime...\n", jit);
    ::hermes::vm::RuntimeConfig::Builder cfg;
    if (jit) cfg.withEnableJIT(true);   /* false 时用缺省值，不显式 set */
    auto rt = facebook::hermes::makeHermesRuntime(cfg.build());
    printf("  runtime ok, evaluating...\n");
    auto t0 = std::chrono::steady_clock::now();
    rt->evaluateJavaScript(std::make_unique<jsi::StringBuffer>(code), "bench.js");
    rt->drainMicrotasks();
    auto t1 = std::chrono::steady_clock::now();
    printf("  eval done, res=%g\n", rt->global().getProperty(*rt, "__res").asNumber());
    return std::chrono::duration<double, std::milli>(t1 - t0).count();
}

int main()
{
    setvbuf(stdout, NULL, _IONBF, 0);
    if (getenv("BENCH_ISOLATION")) {
        auto rt = facebook::hermes::makeHermesRuntime();
        printf("t1: 1+1 = %g\n", rt->evaluateJavaScript(std::make_unique<jsi::StringBuffer>("1+1"), "a.js").asNumber());
        printf("t2: globalThis = %d\n", (int)rt->global().getProperty(*rt, "globalThis").isObject());
        printf("t3: fib(10) = %g\n", rt->evaluateJavaScript(std::make_unique<jsi::StringBuffer>("function fib(n){return n<2?n:fib(n-1)+fib(n-2)}; fib(10)"), "b.js").asNumber());
        printf("t4: fib(27) = %g\n", rt->evaluateJavaScript(std::make_unique<jsi::StringBuffer>("function fib(n){return n<2?n:fib(n-1)+fib(n-2)}; fib(27)"), "c.js").asNumber());
        printf("t5: try/catch JS error\n");
        try {
            rt->evaluateJavaScript(std::make_unique<jsi::StringBuffer>("undefined_x.y = 1;"), "d.js");
        } catch (const jsi::JSError &e) {
            printf("t5 caught: %s\n", e.getMessage().substr(0, 40).c_str());
        }
    }
    printf("--- isolation ok, now bench ---\n");
    const char *fib =
        "function fib(n){ return n < 2 ? n : fib(n-1) + fib(n-2); }"
        "fib(27)";
    const char *loop =
        "(function(){ var s = 0;"
        "for (var i = 0; i < 20000000; i++) { s += i % 7; }"
        "return s; })()";
    printf("fib(27)  interp: %8.1f ms\n", run(false, fib));
    printf("fib(27)  jit:    %8.1f ms\n", run(true, fib));
    printf("loop     interp: %8.1f ms\n", run(false, loop));
    printf("loop     jit:    %8.1f ms\n", run(true, loop));
    return 0;
}
