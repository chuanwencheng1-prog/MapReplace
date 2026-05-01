#!/usr/bin/env bash
# ============================================================
# fetch_darksword.sh
#   从 FilzaJailedDS 仓库拉取 DarkSword 沙箱逃逸源码到 ./DarkSword/
#   在 GitHub Actions / WSL / macOS / Linux 上均可运行。
# ============================================================
set -euo pipefail

REPO_URL="https://github.com/34306/FilzaJailedDS.git"
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${WORK_DIR}/DarkSword"
TMP_DIR="${WORK_DIR}/.darksword_tmp"

echo "============================================================"
echo "  Fetching DarkSword sources from: ${REPO_URL}"
echo "  Target: ${TARGET_DIR}"
echo "============================================================"

# 清理
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

# 克隆 (浅克隆 + 递归 submodule, ChOma 是子模块)
git clone --depth 1 --recurse-submodules "${REPO_URL}" "${TMP_DIR}/repo"

# 准备目标目录
rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"

# 拷贝核心文件
cp "${TMP_DIR}/repo/sandbox_escape.h" "${TARGET_DIR}/"
cp "${TMP_DIR}/repo/sandbox_escape.m" "${TARGET_DIR}/"
cp "${TMP_DIR}/repo/apfs_own.h"       "${TARGET_DIR}/"
cp "${TMP_DIR}/repo/apfs_own.m"       "${TARGET_DIR}/"

# 拷贝子目录 (完整)
for dir in kexploit kpf utils XPF; do
    if [ -d "${TMP_DIR}/repo/${dir}" ]; then
        cp -R "${TMP_DIR}/repo/${dir}" "${TARGET_DIR}/${dir}"
        echo "  ✓ copied ${dir}/"
    else
        echo "  ✗ MISSING: ${dir}/ (build 可能失败)"
    fi
done

# 清理临时目录
rm -rf "${TMP_DIR}"

# 快速健康检查
REQUIRED=(
    "${TARGET_DIR}/sandbox_escape.m"
    "${TARGET_DIR}/apfs_own.m"
    "${TARGET_DIR}/kexploit/kexploit_opa334.m"
    "${TARGET_DIR}/kexploit/krw.m"
    "${TARGET_DIR}/kpf/patchfinder.m"
    "${TARGET_DIR}/XPF/src/xpf.c"
    "${TARGET_DIR}/XPF/external/ChOma/src/MachO.c"
)
missing=0
for f in "${REQUIRED[@]}"; do
    if [ ! -f "$f" ]; then
        echo "  ✗ MISSING: $f"
        missing=1
    fi
done

if [ $missing -ne 0 ]; then
    echo
    echo "❌ 部分关键文件缺失。可能是上游仓库结构变更，请参考:"
    echo "    https://github.com/34306/FilzaJailedDS"
    exit 1
fi

echo
echo "✅ DarkSword 源码就绪: ${TARGET_DIR}"
echo "   现在可执行:  make package MR_WITH_DARKSWORD=1"
