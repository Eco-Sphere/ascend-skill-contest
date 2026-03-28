#!/bin/bash
# MindSpeed-LLM Profiling 数据验证脚本
# 依赖：bash, ls
# 用法: bash scripts/check_profile.sh [profile_dir]

set -e

PROFILE_DIR=${1:-"./profile_dir"}

if [ ! -d "$PROFILE_DIR" ]; then
    echo "错误: 目录 $PROFILE_DIR 不存在"
    exit 1
fi

echo "检查 Profiling 数据目录: $PROFILE_DIR"
echo "========================================"

# 查找profiling输出目录
PROF_DIR=$(ls -td "$PROFILE_DIR"/*_ascend_pt 2>/dev/null | head -1)

if [ -z "$PROF_DIR" ]; then
    echo "错误: 未找到 ascend_pt 目录"
    exit 1
fi

echo -e "\n[1] Profiling 目录: $PROF_DIR"
ls -la "$PROF_DIR"

# 检查 ASCEND_PROFILER_OUTPUT
echo -e "\n[2] ASCEND_PROFILER_OUTPUT (NPU 数据):"
if [ -d "$PROF_DIR/ASCEND_PROFILER_OUTPUT" ]; then
    echo "  ✓ 目录存在"
    ls "$PROF_DIR/ASCEND_PROFILER_OUTPUT/" | head -5
else
    echo "  ✗ ASCEND_PROFILER_OUTPUT 目录缺失"
    exit 1
fi

# 检查关键文件
echo -e "\n[3] 关键文件检查:"
check_file() {
    if [ -f "$1" ]; then
        echo "  ✓ $(basename $1)"
    else
        echo "  ✗ $(basename $1) 缺失"
    fi
}

check_file "$PROF_DIR/profiler_info_0.json"
check_file "$PROF_DIR/profiler_metadata.json"

# 检查 HOST 数据
echo -e "\n[4] Host 数据 (CPU/内存):"
if [ -d "$PROF_DIR/PROF_000001/host/data" ]; then
    echo "  ✓ host 数据存在"
else
    echo "  ✗ host 数据缺失"
fi

# 检查 DEVICE 数据
echo -e "\n[5] Device 数据 (NPU):"
if [ -d "$PROF_DIR/PROF_000001/device_0/data" ]; then
    echo "  ✓ device 数据存在"
else
    echo "  ✗ device 数据缺失"
fi

echo -e "\n========================================"
echo "Profiling 数据采集成功！"
