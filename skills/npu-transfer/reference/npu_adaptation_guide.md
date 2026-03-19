# NPU 适配详解

本文档详细说明将 PyTorch FSDP2 训练任务从 GPU 迁移到昇腾 NPU 的关键适配点。

---

## 1. 设备检测适配

### 1.1 API 对照表

| 功能 | GPU | NPU |
|------|-----|-----|
| 检测可用性 | `torch.accelerator.is_available()` | `torch.npu.is_available()` |
| 获取设备数量 | `torch.accelerator.device_count()` | `torch.npu.device_count()` |
| 设置当前设备 | `torch.accelerator.device_index(rank)` | `torch.npu.set_device(rank)` |
| 获取设备属性 | `torch.cuda.get_device_properties(i)` | `torch.npu.get_device_properties(i)` |
| 设备类型字符串 | `cuda` | `npu` |

### 1.2 代码示例

```python
import torch

# GPU 检测
if torch.accelerator.is_available():
    gpu_count = torch.accelerator.device_count()
    print(f"Found {gpu_count} GPUs")

# NPU 检测
if torch.npu.is_available():
    npu_count = torch.npu.device_count()
    print(f"Found {npu_count} NPUs")
    for i in range(npu_count):
        props = torch.npu.get_device_properties(i)
        print(f"  NPU {i}: {props.name}, Memory: {props.total_memory / 1e9:.1f} GB")
```

---

## 2. 设备初始化适配

### 2.1 分布式训练初始化

```python
import os
import torch
import torch.distributed as dist

rank = int(os.environ["LOCAL_RANK"])

# GPU 初始化
device = torch.device(f"cuda:{rank}")
torch.cuda.set_device(rank)
dist.init_process_group(backend="nccl")

# NPU 初始化
device = torch.device(f"npu:{rank}")
torch.npu.set_device(rank)
dist.init_process_group(backend="hccl")
```

### 2.2 张量设备转移

```python
# GPU
tensor = tensor.cuda()
tensor = tensor.to("cuda")
tensor = tensor.to(device)

# NPU
tensor = tensor.npu()
tensor = tensor.to("npu")
tensor = tensor.to(device)
```

---

## 3. 分布式后端适配

### 3.1 后端选择

| 硬件 | 后端 | 说明 |
|------|------|------|
| NVIDIA GPU | `nccl` | NVIDIA Collective Communication Library |
| 昇腾 NPU | `hccl` | Huawei Collective Communication Library |
| CPU | `gloo` | 通用后端 |

### 3.2 HCCL 环境变量

```bash
# 连接超时设置（秒）
export HCCL_CONNECT_TIMEOUT=1800
export HCCL_EXEC_TIMEOUT=1800

# 调试选项
export HCCL_DEBUG=INFO

# 性能调优
export HCCL_INTRA_ROCE_ENABLE=1
export HCCL_INTRA_PCIE_ENABLE=1
```

---

## 4. 融合注意力算子适配

### 4.1 npu_fusion_attention 完整 API

```python
torch_npu.npu_fusion_attention(
    query,                  # (batch, num_heads, seq_len, head_dim) for BNSD
    key,                    # (batch, num_heads, seq_len, head_dim) for BNSD
    value,                  # (batch, num_heads, seq_len, head_dim) for BNSD
    head_num,               # 注意力头数量
    input_layout,           # "BNSD" 或 "SBH"
    pse=None,               # 位置编码（可选）
    padding_mask=None,      # 填充掩码（可选）
    atten_mask=None,        # 注意力掩码（可选）
    scale=1.0,              # 缩放因子
    pre_tockens=2147483647, # 前向token数量
    next_tockens=2147483647,# 后向token数量
    keep_prob=1.0,          # 保留概率
    sync=False,             # 是否同步
    inner_precise=0,        # 内部精度
)[0]                        # 返回元组，取第一个元素
```

### 4.2 输入格式详解

| 格式 | Query/Key/Value 形状 | 说明 |
|------|---------------------|------|
| `BNSD` | `(batch, num_heads, seq_len, head_dim)` | **推荐**，与 PyTorch 标准格式兼容 |
| `SBH` | `(seq_len, batch, hidden_dim)` | 紧凑格式，hidden_dim = num_heads * head_dim |

**重要**：`BSND` 格式不支持！

### 4.3 完整适配示例

```python
import torch
import torch.nn as nn
import torch_npu

class NPUFlashAttention(nn.Module):
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
        
        # 投影并 reshape 为 BNSD 格式
        q = self.q_proj(hidden_states).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        k = self.k_proj(hidden_states).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        v = self.v_proj(hidden_states).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        
        # 因果注意力设置
        pre_tockens = seq_len if self.causal else 2147483647
        next_tockens = seq_len if self.causal else 2147483647
        
        # NPU 融合注意力
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
        
        # reshape 回原始格式
        output = output.transpose(1, 2).contiguous().view(batch_size, seq_len, self.hidden_size)
        return self.o_proj(output)
```

### 4.4 常见错误及解决

| 错误信息 | 原因 | 解决方案 |
|----------|------|----------|
| `unsupported layout: BSND` | 使用了不支持的格式 | 改用 `BNSD` 格式 |
| `head_num is [4], but got query dim2 [64]` | head_num 与张量形状不匹配 | 检查 `num_heads` 参数和输入形状 |
| `query must be contiguous` | 输入张量不连续 | 调用 `.contiguous()` |

---

## 5. 混合精度训练

### 5.1 FSDP2 混合精度配置

```python
from torch.distributed.fsdp import MixedPrecisionPolicy

mp_policy = MixedPrecisionPolicy(
    param_dtype=torch.bfloat16,    # 参数使用 bfloat16
    reduce_dtype=torch.float32,    # 梯度归约使用 float32
)
```

### 5.2 NPU 精度支持

| 精度 | 支持情况 | 说明 |
|------|----------|------|
| `float32` | ✅ 完全支持 | 默认精度 |
| `float16` | ✅ 完全支持 | 需注意数值稳定性 |
| `bfloat16` | ✅ 完全支持 | **推荐**用于混合精度训练 |

---

## 6. Checkpoint 兼容性

### 6.1 保存 Checkpoint

```python
# GPU 和 NPU 代码相同
torch.save(model.state_dict(), "model.pt")
```

### 6.2 加载 Checkpoint

```python
# 跨设备加载
state_dict = torch.load("model.pt", map_location="cpu")
model.load_state_dict(state_dict)
model.to(device)  # 移动到目标设备
```

### 6.3 FSDP2 Checkpoint

```python
from torch.distributed.checkpoint.state_dict import get_model_state_dict, set_model_state_dict, StateDictOptions

# 保存
state_dict = get_model_state_dict(
    model,
    options=StateDictOptions(full_state_dict=True, cpu_offload=True)
)
if dist.get_rank() == 0:
    torch.save(state_dict, "model.pt")

# 加载
state_dict = torch.load("model.pt", map_location="cpu")
set_model_state_dict(
    model,
    state_dict,
    options=StateDictOptions(full_state_dict=True, broadcast_from_rank0=True)
)
```

---

## 7. 完整适配检查清单

- [ ] 安装 torch_npu 并验证版本
- [ ] 检测 NPU 可用性和数量
- [ ] 修改设备初始化代码（`torch.npu.set_device`）
- [ ] 设置 HCCL 后端
- [ ] 接入 `npu_fusion_attention`（使用 BNSD 格式）
- [ ] 配置混合精度训练（可选）
- [ ] 验证 checkpoint 保存/加载
- [ ] 测试多卡分布式训练

---

## 8. 参考资源

- [torch_npu 官方文档](https://gitee.com/ascend/pytorch)
- [昇腾开发文档](https://www.hiascend.com/document)
- [HCCL 开发指南](https://www.hiascend.com/document/detail/zh/canncommercial/80RC2/devg/auxiliarydevg/hccllog_000033.html)
- [npu_fusion_attention API](https://gitee.com/ascend/pytorch/blob/master/torch_npu/npu/functional.py)
