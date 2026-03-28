# MindSpeed-LLM Profiling 数据采集

## 描述

该 Skill 指导用户使用 MindSpeed-LLM 框架完成昇腾芯片上的模型训练 Profiling 数据采集。当用户需要分析训练性能、定位性能瓶颈或优化训练效率时，此 Skill 被触发。

## 触发条件

用户请求以下任一场景时触发：
- 采集 MindSpeed-LLM 训练过程的性能数据
- 获取 CPU、内存、NPU 算子耗时等分析数据
- 分析不同 level 和采集 step 范围的性能数据

---

## 快速开始

### 1. 添加 Profiling 参数

在训练脚本中定义 `PROFILE_ARGS` 变量：

```bash
PROFILE_ARGS="
    --profile \
    --profile-step-start 13 \
    --profile-step-end 15 \
    --profile-ranks 0 \
    --profile-level level1 \
    --profile-with-cpu \
    --profile-with-memory \
    --profile-save-path ./profile_dir
"
```

### 2. 修改训练命令

在 `torchrun` 命令中添加 `$PROFILE_ARGS`：

```bash
torchrun $DISTRIBUTED_ARGS pretrain_gpt.py \
    $GPT_ARGS $DATA_ARGS $OUTPUT_ARGS $OPTIMIZE_ARGS \
    $TRAIN_ARGS $MODEL_PARALLEL_ARGS $PROFILE_ARGS \
    --load ${CKPT_LOAD_DIR} --save ${CKPT_SAVE_DIR} \
    --distributed-backend nccl --transformer-impl local
```

### 3. 执行训练

```bash
cd /work/MindSpeed-LLM
bash examples/mcore/qwen3/pretrain_qwen3_8b_4K_ptd.sh
```

### 4. 验证数据落盘

```bash
ls -la ./profile_dir/
```

---

## 参数说明

| 参数 | 说明 |
|------|------|
| `--profile` | 启用 profiling 采集 |
| `--profile-step-start` | 开始步骤（包含），如 13 |
| `--profile-step-end` | 结束步骤（不包含），如 15 采集 13-14 步 |
| `--profile-level` | 采集级别：level0/level1（推荐）/level2 |
| `--profile-with-cpu` | 采集 CPU 活动数据 |
| `--profile-with-memory` | 采集内存分配/释放事件 |
| `--profile-ranks` | 采集卡号，0 表示 0 号卡 |
| `--profile-save-path` | 数据保存路径 |

---

## Level 说明

| Level | 采集内容 |
|-------|----------|
| level0 | 基础算子耗时 |
| level1 | AICore 利用率、通信算子耗时（推荐） |
| level2 | 含缓存、内存等详细信息 |

---

## 输出目录结构

```
profile_dir/
└── w24_xxxx_ascend_pt/
    ├── ASCEND_PROFILER_OUTPUT/   # NPU 算子数据
    ├── FRAMEWORK/                # 框架数据
    ├── PROF_000001_xxxxx/
    │   ├── device_0/              # NPU 设备数据
    │   └── host/                  # CPU/内存数据
    ├── profiler_info_0.json
    └── profiler_metadata.json
```

---

## 常用配置示例

### 示例 1：采集 13-14 步 CPU 和内存（常用）

```bash
PROFILE_ARGS="
    --profile \
    --profile-step-start 13 \
    --profile-step-end 15 \
    --profile-ranks 0 \
    --profile-level level1 \
    --profile-with-cpu \
    --profile-with-memory \
    --profile-save-path ./profile_dir
"
```

### 示例 2：采集详细堆栈和 Shape 信息

```bash
PROFILE_ARGS="
    --profile \
    --profile-step-start 5 \
    --profile-step-end 10 \
    --profile-ranks 0 \
    --profile-level level2 \
    --profile-with-cpu \
    --profile-with-memory \
    --profile-with-stack \
    --profile-record-shapes \
    --profile-save-path ./profile_detail
"
```

### 示例 3：采集所有卡数据

```bash
PROFILE_ARGS="
    --profile \
    --profile-step-start 0 \
    --profile-step-end -1 \
    --profile-ranks -1 \
    --profile-level level2 \
    --profile-with-cpu \
    --profile-with-memory \
    --profile-save-path ./profile_all
"
```

---

## 错误处理

### 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| ASCEND_PROFILER_OUTPUT 为空 | 训练被提前终止 | 确保训练运行到 profile-step-end 指定的步骤 |
| 数据未生成 | CANN 未正确安装 | 确认 ASCEND_PROFILER 环变量已设置 |
| 权限错误 | 路径无写权限 | 检查 profile-save-path 目录权限 |

### 依赖检查

- CANN 工具已安装
- MindSpeed-LLM 环境已配置
- 训练脚本路径正确

---

## 参考文档

- MindSpeed-LLM Profiling 文档：`/work/MindSpeed-LLM/docs/zh/pytorch/tools/profiling.md`
- MindStudio Insight：用于可视化分析 profiling 数据
