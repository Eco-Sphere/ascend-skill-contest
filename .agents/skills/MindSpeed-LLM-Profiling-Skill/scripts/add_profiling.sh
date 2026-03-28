#!/bin/bash
# MindSpeed-LLM Profiling 参数生成脚本
# 依赖：bash, echo
# 用法: bash scripts/add_profiling.sh [step_start] [step_end] [profile_level] [save_path]

STEP_START=${1:-13}
STEP_END=${2:-15}
PROFILE_LEVEL=${3:-"level1"}
SAVE_PATH=${4:-"./profile_dir"}

cat << EOF

# Profiling 参数（添加到训练脚本中）
PROFILE_ARGS="
    --profile \\
    --profile-step-start ${STEP_START} \\
    --profile-step-end ${STEP_END} \\
    --profile-ranks 0 \\
    --profile-level ${PROFILE_LEVEL} \\
    --profile-with-cpu \\
    --profile-with-memory \\
    --profile-save-path ${SAVE_PATH}
"

# 在 torchrun 命令中添加 \$PROFILE_ARGS
EOF

echo "参数生成完成"
