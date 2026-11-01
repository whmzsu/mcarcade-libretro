#!/usr/bin/env bash
# ci-smoke.sh —— CI 冒烟自检：ping.js（纯 JS 路径）+ ping.png（内嵌编译器全链路）
#
# 判定标准与本地验证一致：输出 PPM 的非黑像素必须 > 100
# （本机参考值：ping 90 帧 = 389 非黑像素，两引擎逐字节一致）。
#
# 用法： scripts/ci-smoke.sh [core_test 路径]
set -euo pipefail
CT=${1:-./build/core_test}
cd "$(dirname "$0")/.."

# png 编译路径要 16MB 栈；-Wl,-z,stack-size 已设，但 rlimit 太小会盖掉它
ulimit -s unlimited 2>/dev/null || ulimit -s 65536 2>/dev/null || true

check() {
    local cart=$1 frames=$2
    local out
    out=$(mktemp --suffix=.ppm)
    echo "--- $cart ($frames 帧)"
    if ! "$CT" "$cart" "$out" "$frames" > smoke.log 2>&1; then
        echo "core_test 失败，日志尾部："
        tail -30 smoke.log
        exit 1
    fi
    grep -a "booted" smoke.log || { echo "没看到 booted，日志尾部："; tail -10 smoke.log; exit 1; }
    python3 - "$out" <<'EOF'
import sys
d = open(sys.argv[1], "rb").read()
i = 0
for _ in range(3):
    i = d.index(b"\n", i) + 1
px = d[i:]
assert len(px) == 160 * 120 * 3, f"尺寸不对: {len(px)}"
nb = sum(1 for j in range(0, len(px), 3) if px[j] or px[j+1] or px[j+2])
assert nb > 100, f"画面几乎全黑: non-black={nb}"
print(f"    non-black pixels = {nb} (参考值 389)")
EOF
    rm -f "$out" smoke.log
}

check tests/data/ping.js 90
check tests/data/ping.png 90
echo "冒烟自检通过"
