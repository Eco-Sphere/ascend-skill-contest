---
name: npu-transfer
description: 将PyTorch训练任务从GPU迁移到昇腾NPU的通用指南。在用户需要进行GPU到NPU的模型迁移、分布式训练适配、融合注意力算子接入时自动应用。支持根据用户指定的代码仓库自动分析并生成NPU适配代码。
---

# PyTorch GPU→NPU 迁移指南

## 何时使用本 Skill

- 用户需要**GPU到NPU迁移**：将PyTorch训练代码迁移到昇腾NPU
- 用户提供了**源代码路径**：指定需要迁移的代码仓库或文件
- 用户需要**分布式训练适配**：DDP/FSDP/DeepSpeed 等分布式框架迁移
- 用户需要**融合注意力算子**：接入`torch_npu.npu_fusion_attention`提升性能

---

## 迁移工作流程

### 第一步：分析源代码

当用户提供源代码路径时，按以下步骤分析：

1. **识别训练框架**：DDP / FSDP / FSDP2 / DeepSpeed / Megatron 等
2. **识别设备相关代码**：
   - 设备检测：`torch.cuda.is_available()` / `torch.accelerator.is_available()`
   - 设备初始化：`torch.cuda.set_device()` / `.cuda()` / `.to("cuda")`
   - 分布式后端：`nccl` / `gloo`
3. **识别注意力实现**：`F.scaled_dot_product_attention` / 自定义 attention
4. **识别其他 GPU 特定代码**：CUDA kernel、cuDNN 等

### 第二步：生成适配代码

根据分析结果，在用户指定的输出目录生成以下文件：

```
<output_dir>/
├── <original_name>_npu.py    # NPU适配的主脚本
├── model_npu.py              # NPU适配的模型（如需修改attention）
├── run_npu.sh                # NPU启动脚本
└── requirements_npu.txt      # NPU环境依赖
```

### 第三步：验证适配

1. 检查 NPU 环境：`torch.npu.is_available()`
2. 运行单卡测试
3. 运行多卡分布式测试
4. 验证 checkpoint 保存/加载

---

## 核心适配规则

### 1. 设备检测适配

```python
# GPU 原始代码
if torch.cuda.is_available():
    device = torch.device("cuda:0")

# 或 PyTorch 2.0+ 新 API
if torch.accelerator.is_available():
    device = torch.device(f"{torch.accelerator.current_accelerator()}:0")

# NPU 适配代码
if torch.npu.is_available():
    device = torch.device("npu:0")
```

### 2. 设备初始化适配

```python
# GPU 原始代码
torch.cuda.set_device(rank)
device = torch.device(f"cuda:{rank}")

# NPU 适配代码
torch.npu.set_device(rank)
device = torch.device(f"npu:{rank}")
```

### 3. 张量设备转移

```python
# GPU 原始代码
tensor = tensor.cuda()
tensor = tensor.to("cuda")

# NPU 适配代码
tensor = tensor.npu()
tensor = tensor.to("npu")
```

### 4. 分布式后端适配

```python
# GPU 原始代码
torch.distributed.init_process_group(backend="nccl")

# NPU 适配代码
torch.distributed.init_process_group(backend="hccl")
```

### 5. 融合注意力算子适配

```python
# GPU 原始代码
output = F.scaled_dot_product_attention(q, k, v, attn_mask=mask, dropout_p=dropout)

# NPU 适配代码
import torch_npu

output = torch_npu.npu_fusion_attention(
    q.contiguous(),
    k.contiguous(),
    v.contiguous(),
    self.num_heads,
    "BNSD",  # 必须使用 BNSD 格式: (batch, num_heads, seq_len, head_dim)
    keep_prob=1.0 - dropout,
    scale=1.0 / (self.head_dim ** 0.5),
    pre_tockens=seq_len,
    next_tockens=seq_len,
)[0]
```

**重要**：`npu_fusion_attention` 不支持 `BSND` 格式，必须使用 `BNSD` 格式。

---

## 适配模板

### NPUAttention 通用模板

```python
import torch
import torch.nn as nn
import torch_npu

class NPUAttention(nn.Module):
    def __init__(self, hidden_size, num_heads, dropout=0.0, causal=False):
        super().__init__()
        self.hidden_size = hidden_size
        self.num_heads = num_heads
        self.head_dim = hidden_size // num_heads
        self.dropout = dropout
        self.causal = causal
        
        self.q_proj = nn.Linear(hidden_size, hidden_size, bias=False)
        self.k_proj = nn.Linear(hidden_size, hidden_size, bias=False)
        self.v_proj = nn.Linear(hidden_size, hidden_size, bias=False)
        self.o_proj = nn.Linear(hidden_size, hidden_size, bias=False)
    
    def forward(self, hidden_states, attention_mask=None):
        batch_size, seq_len, _ = hidden_states.shape
        
        q = self.q_proj(hidden_states).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        k = self.k_proj(hidden_states).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        v = self.v_proj(hidden_states).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        
        pre_tockens = seq_len if self.causal else 2147483647
        next_tockens = seq_len if self.causal else 2147483647
        
        output = torch_npu.npu_fusion_attention(
            q.contiguous(),
            k.contiguous(),
            v.contiguous(),
            self.num_heads,
            "BNSD",
            keep_prob=1.0 - (self.dropout if self.training else 0),
            scale=1.0 / (self.head_dim ** 0.5),
            pre_tockens=pre_tockens,
            next_tockens=next_tockens,
        )[0]
        
        output = output.transpose(1, 2).contiguous().view(batch_size, seq_len, self.hidden_size)
        return self.o_proj(output)
```

### NPU 分布式训练启动脚本

```bash
#!/bin/bash

# 设置环境变量
export HCCL_CONNECT_TIMEOUT=1800
export HCCL_EXEC_TIMEOUT=1800

# 获取 NPU 数量
NPU_COUNT=$(npu-smi info | grep -c "910" || echo "2")

# 启动训练
torchrun --nproc_per_node $NPU_COUNT train_npu.py "$@"
```

---

## 环境配置

### 第一步：检测可用环境

```bash
# 查看可用的 conda 环境
conda env list

# 选择包含 torch_npu 的环境（通常名称包含 torch、npu、ascend 等关键词）
# 常见环境名称示例：
# - torch280_py310_diffusion
# - torch_npu
# - ascend-pytorch
# - pt_npu_env
```

### 第二步：激活并验证环境

```bash
# 激活环境（替换为实际环境名称）
conda activate <your-torch-npu-env>

# 验证 torch_npu 安装
python -c "import torch; print('PyTorch:', torch.__version__)"

# 验证 NPU 可用性
python -c "import torch; import torch_npu; print('torch_npu:', torch_npu.__version__); print('NPU available:', torch.npu.is_available()); print('NPU count:', torch.npu.device_count())"

# 验证 NPU 硬件状态
npu-smi info
```

### 第三步：依赖安装（如需）

```bash
# 如果环境没有 torch_npu，根据 CANN 版本安装
pip install torch-npu

# 验证安装
python -c "import torch_npu; print(torch_npu.__version__)"
```

### 环境变量配置

```bash
# HCCL 通信超时
export HCCL_CONNECT_TIMEOUT=1800
export HCCL_EXEC_TIMEOUT=1800

# 调试选项
export HCCL_DEBUG=INFO
```

---

## 常见问题

### Q1: `unsupported layout: BSND`

**原因**：`npu_fusion_attention` 不支持 `BSND` 格式。

**解决**：使用 `BNSD` 格式，确保 q/k/v 形状为 `(batch, num_heads, seq_len, head_dim)`。

### Q2: `query must be contiguous`

**原因**：输入张量不连续。

**解决**：调用 `.contiguous()` 确保张量连续。

### Q3: HCCL 初始化失败

**解决**：
```bash
export HCCL_CONNECT_TIMEOUT=1800
export HCCL_EXEC_TIMEOUT=1800
```

---

## 参考资源

- [torch_npu 文档](https://gitee.com/ascend/pytorch)
- [昇腾开发文档](https://www.hiascend.com/document)
- [HCCL 开发指南](https://www.hiascend.com/document/detail/zh/canncommercial/80RC2/devg/auxiliarydevg/hccllog_000033.html)
