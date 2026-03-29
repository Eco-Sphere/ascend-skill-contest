# FSDP2 nanoGPT NPU 训练迁移

将 PyTorch Examples 仓库中 FSDP2 的 nanoGPT 训练任务从 GPU 环境迁移到昇腾 NPU 环境，完成分布式训练流程验证。

## 触发条件

用户需要将 PyTorch FSDP2 分布式训练任务从 GPU 迁移到华为昇腾 NPU 时使用此 Skill。

## 环境要求

- 昇腾 NPU 服务器（≥2 卡）
- Python 3.8+
- torch >= 2.7.0
- torch_npu >= 2.7.0

## 步骤

### 步骤 1：安装 NPU 环境

安装适配 NPU 的 PyTorch 和 torch_npu：

```bash
pip install torch>=2.7.0
pip install torch_npu>=2.7.0
```

### 步骤 2：进入工作目录

```bash
cd fsdp2_nanogpt_npu/scripts
```

### 步骤 3：启动多卡训练

使用 torchrun 启动 NPU 分布式训练（≥2 卡）：

```bash
torchrun --nproc_per_node=2 example.py --use-npu-fusion --max-iterations 10
```

参数说明：
- `--nproc_per_node`: NPU 卡数（≥2）
- `--use-npu-fusion`: 启用 NPU 融合算子
- `--max-iterations`: 训练迭代次数
- `--mixed-precision`: 启用混合精度
- `--explicit-prefetching`: 启用显式预取
- `--dcp-api`: 使用 DCP API 保存 checkpoint

### 步骤 4：验证 Checkpoint

第一次训练完成后，checkpoint 保存在 `checkpoints/` 目录。

第二次训练自动加载 checkpoint 继续训练：

```bash
torchrun --nproc_per_node=2 example.py --use-npu-fusion
```

## 关键适配点

1. **NPU 设备识别**：自动检测 npu/cuda 设备
2. **NPU 分布式初始化**：使用 HCCL 后端
3. **Fusion Attention**：接入 `torch_npu.npu_fusion_attention`

## 文件结构

```
fsdp2_nanogpt_npu/
├── SKILL.md
├── scripts/
│   ├── model.py          # NPU 适配的模型（含 fusion attention）
│   ├── example.py        # 主训练脚本
│   ├── checkpoint.py     # Checkpoint 保存/加载
│   ├── utils.py          # 工具函数
│   ├── train.sh          # 训练启动脚本
│   └── requirements.txt  # 依赖
└── reference/
```

## 常见问题

1. **NPU 不可用**：确认昇腾驱动和 CANN 已正确安装
2. **多卡训练失败**：确认 NPU 间网络互通（HCCL 需支持 allreduce）
3. **Fusion Attention 报错**：确认 torch_npu 版本支持 NPUFusionAttention
