---
name: verl-npu
description: "verl NPU 容器化部署与 GRPO 训练验证。按官方 Ascend Quick Start 完成环境搭建、容器部署、GRPO训练及checkpoint验证。"
keywords:
  - verl
  - NPU
  - GRPO
  - RLHF
  - Docker
  - Ascend
---

# verl NPU 部署 Skill

> 仅用于容器内 NPU 训练场景，按流程顺序执行。

## 前置信息

使用前需确认以下信息：
- **SSH连接**: 服务器 `root@<host>`，密钥在 `C:\Users\zzw\.ssh\id_rsa`
- **工作目录**: `<work_dir>`（宿主机）
- **模型路径**: `<model_path>`
- **数据路径**: `<train_data>`, `<val_data>`
- **NPU卡数**: `<n_gpus>`

## 核心流程

### Step 1: 环境检查
```bash
# 在服务器执行
npu-smi info -l
docker --version
docker images | grep verl
```

### Step 2: 启动容器
```bash
# 方式1: 使用脚本（参数为NPU卡数）
./scripts/start_container.sh 8

# 方式2: 手动启动
docker run -d --name verl-npu --network host --ipc=host --privileged \
  --device /dev/davinci_manager --device /dev/devmm_svm --device /dev/hisi_hdc \
  --device /dev/davinci0 --device /dev/davinci1 --device /dev/davinci2 --device /dev/davinci3 \
  --device /dev/davinci4 --device /dev/davinci5 --device /dev/davinci6 --device /dev/davinci7 \
  -v /home:/home \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver:ro \
  -v /usr/local/Ascend/add-ons:/usr/local/Ascend/add-ons:ro \
  -v /usr/local/sbin:/usr/local/sbin:ro \
  quay.io/ascend/verl:verl-8.3.rc1-910b-ubuntu22.04-py3.11-latest \
  sleep infinity
```

### Step 3: 克隆仓库（在容器内的工作目录）
```bash
# 在容器内执行，确保工作目录有 verl 仓库
docker exec verl-npu bash -lc "
cd <work_dir>;
git clone https://github.com/verl-project/verl.git;
ls -la
"
```

### Step 4: 运行 GRPO 训练

**方式1: 使用脚本**
```bash
./scripts/run_grpo.sh <work_dir> <model_path> <train_data> <val_data> [n_gpus] [save_freq] [total_steps]

# 示例
./scripts/run_grpo.sh /home/zzw30069617 /home/z30069617/models/Qwen3-0.6B \
  /home/z30069617/datasets/gsm8k/processed/train.parquet \
  /home/z30069617/datasets/gsm8k/processed/val.parquet 8 50 200
```

**方式2: 手动运行**
```bash
docker exec verl-npu bash -lc "
source /usr/local/Ascend/ascend-toolkit/set_env.sh;
cd <work_dir>/verl;
python -m verl.trainer.main_ppo \
  algorithm.adv_estimator=grpo \
  data.train_files=<train_data> \
  data.val_files=<val_data> \
  data.train_batch_size=8 \
  data.max_prompt_length=256 \
  data.max_response_length=256 \
  actor_rollout_ref.model.path=<model_path> \
  actor_rollout_ref.actor.optim.lr=3e-6 \
  actor_rollout_ref.model.enable_gradient_checkpointing=True \
  actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=1 \
  actor_rollout_ref.rollout.name=vllm \
  actor_rollout_ref.rollout.gpu_memory_utilization=0.4 \
  actor_rollout_ref.rollout.n=2 \
  actor_rollout_ref.rollout.tensor_model_parallel_size=1 \
  trainer.project_name=verl_grpo_demo \
  trainer.experiment_name=qwen3_0_6b_gsm8k \
  trainer.device=npu \
  trainer.n_gpus_per_node=<n_gpus> \
  trainer.save_freq=50 \
  trainer.test_freq=50 \
  trainer.total_epochs=1 \
  trainer.total_training_steps=200 \
  trainer.logger=[\"console\"] \
  trainer.default_local_dir=<work_dir>/checkpoints/verl_grpo_demo
"
```

### Step 5: Checkpoint 验证（快速版：3步保存+2步加载）
```bash
./scripts/verify_checkpoint.sh <work_dir> <model_path> <train_data> <val_data>
```
> 验证流程：训练3步保存checkpoint → 加载checkpoint继续训练2步 → 验证成功

### Step 6: 容器管理
```bash
./scripts/manage_container.sh status   # 查看状态
./scripts/manage_container.sh logs      # 查看日志
./scripts/manage_container.sh exec      # 进入容器
./scripts/manage_container.sh stop      # 停止容器
./scripts/manage_container.sh remove    # 删除容器
```

## 模块说明

```
verl-npu/
├── SKILL.md                    # 主入口（本文件）
├── scripts/                    # 固定操作脚本
│   ├── start_container.sh     # 容器启动脚本
│   ├── manage_container.sh    # 容器管理脚本
│   ├── run_grpo.sh            # GRPO训练脚本
│   ├── verify_checkpoint.sh  # Checkpoint验证脚本
│   └── check_env.sh          # 环境检查脚本
├── assets/                     # 输出模板
│   ├── training_config.yaml  # 训练配置模板
│   ├── data_checklist.md     # 数据准备检查清单
│   └── checkpoint_verify_report.md  # 验证报告模板
└── references/                 # 详细参考
    ├── config_guide.md        # 配置参数详解
    ├── troubleshooting.md    # 问题排查指南
    ├── tuning_guide.md       # 调优指南
    └── scheme.json           # 变量schema定义
```

## 参考文档

- 官方文档: https://verl.readthedocs.io/en/latest/ascend_tutorial/quick_start/ascend_quick_start.html
- 配置参数: `references/config_guide.md`
- 问题排查: `references/troubleshooting.md`
- 调优指南: `references/tuning_guide.md`
