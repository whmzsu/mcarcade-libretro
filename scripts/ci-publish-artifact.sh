#!/usr/bin/env bash
# ci-publish-artifact.sh —— 把构建产物推到孤儿分支 artifacts/<平台>。
#
# 为什么不用 Actions 产物：产物下载要过 api.github.com 认证，某些网络环境
# 走不通；孤儿分支可以直接 `git fetch origin artifacts/android-arm64` 拿，
# 也方便脚本/设备端自动化。每个平台一个分支，三个 job 并行不会打架。
#
# 用法： scripts/ci-publish-artifact.sh <平台名> <so 路径>
set -euo pipefail
cd "$(dirname "$0")/.."

PLAT=${1:?平台名，如 android-arm64}
SO=${2:?核心 .so 路径}
INFO=dist/makecode_arcade_libretro.info
BRANCH="artifacts/$PLAT"
WORK=$(mktemp -d)

cp "$SO" "$WORK/makecode_arcade_libretro.so"
cp "$INFO" "$WORK/makecode_arcade_libretro.info"
{
    echo "commit: ${GITHUB_SHA:-local}"
    echo "run: ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-0}"
    echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "size: $(stat -c %s "$SO" 2>/dev/null || stat -f %z "$SO") bytes"
} > "$WORK/BUILD.txt"

cd "$WORK"
git init -q -b "$BRANCH"
git config user.name "ci-bot"
git config user.email "ci-bot@users.noreply.github.com"
git add -A
git commit -qm "build ${GITHUB_SHA:-local}"
# 孤儿分支每次都重写，不留历史（.so 十几 MB，别堆在仓库里）
git push -f "https://x-access-token:${TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "HEAD:refs/heads/$BRANCH"
echo "已推到 $BRANCH"
