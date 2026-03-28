---
name: fsdp2-nanogpt-npu-migrate
description: >
  该 Skill 用于在 `<WORK_ROOT>` 工作区内，将 `PyTorch Examples/distributed/FSDP2`
  的 nanoGPT 训练样例从 GPU 迁移到昇腾 NPU，并按固定顺序完成环境预检、权重与
  checkpoint 路径查询、conda 环境复用或补齐、`torch`/`torch_npu` 安装校验、
  `torch_npu.npu_fusion_attention` 接入、`torchrun` 双卡训练、checkpoint 首次保存
  与二次恢复；当用户提到 FSDP2、nanoGPT、PyTorch Examples、GPU 转 NPU、torch_npu、
  昇腾分布式训练、checkpoint 恢复时触发。
metadata:
  short-description: FSDP2 nanoGPT 昇腾迁移执行手册
  category: Model-Migration
  tags: [fsdp2, nanogpt, pytorch-examples, ascend, npu, torch-npu, torchrun, checkpoint]
---

# FSDP2 nanoGPT 昇腾 NPU 迁移指南

说明：`<WORK_ROOT>` 表示当前任务允许操作的工作根目录，例如`/workspace/project` 或其他实际用户目录。以下命令中的 `<WORK_ROOT>` 需要按本机替换。

本 Skill 用于把 `https://github.com/pytorch/examples/tree/main/distributed/FSDP2` 中的 toy nanoGPT 训练样例迁移到昇腾 NPU，并完成一次 checkpoint 保存与一次 checkpoint 恢复验证。

## 前置条件

执行迁移前确认以下环境就绪：

| 项目 | 要求 |
|------|------|
| 硬件 | Ascend910 系列（至少 2 卡，推荐空闲 2 卡以上） |
| OS | openEuler / Ubuntu / KylinOS（aarch64 或 x86_64） |
| CANN | ≥ 8.0，推荐 8.5.0 或与 `torch_npu` 匹配版本 |
| Python | 3.10 – 3.11，推荐 3.11 |
| PyTorch | ≥ 2.7，且需与 CANN/`torch_npu` 版本匹配 |
| torch_npu | 与 PyTorch 主版本一致 |
| conda | `<WORK_ROOT>/miniconda3` 可用 |
| 源码 | 可访问 `pytorch/examples` 或已有 `<WORK_ROOT>/pytorch-examples/distributed/FSDP2` |

## 一、硬约束

- 所有工作路径限制在 `<WORK_ROOT>` 下。
- Skill 固定放在 `<WORK_ROOT>/create/fsdp2-nanogpt-npu-migrate`。
- conda 必须来自 `<WORK_ROOT>/miniconda3`。
- 优先复用 `<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu`；若环境缺失，再全新创建，禁止克隆已有环境。
- 使用 NPU 前必须先执行 `source /usr/local/Ascend/ascend-toolkit/set_env.sh`。
- 在任何安装、下载、修改代码、训练前，必须先做环境验证和权重路径查询。
- `<WORK_ROOT>/pytorch-examples/distributed/FSDP2` 已存在时必须复用，不得重复拉取。
- 若源码拉取或 Python 包安装失败，必须切镜像后重试。

## 二、适用场景

当用户出现以下需求时立即使用本 Skill：

- 将 `PyTorch Examples/distributed/FSDP2` 从 GPU 迁移到昇腾 NPU。
- 为 FSDP2 的 toy transformer/nanoGPT 接入 `torch_npu`。
- 在 NPU 上用 `torchrun` 启动至少 2 卡训练。
- 需要验证 checkpoint 首次保存与二次恢复。

## 三、执行顺序

严格按以下顺序执行，不允许跳步：

1. 环境验证。
2. 权重与 checkpoint 路径查询。
3. 源码路径复用检查。
4. conda 环境复用或补齐。
5. 安装 `torch`/`torch_npu` 与依赖。
6. 校验 NPU Python 运行时。
7. 修改 FSDP2 代码并接入 `torch_npu.npu_fusion_attention`。
8. 2 卡训练并生成 checkpoint。
9. 恢复训练并验证 checkpoint 加载。
10. 汇总产物与验证证据。

## 四、预检：先做环境验证，再做任何变更

### 4.1 环境验证

先执行：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
npu-smi info
ls <WORK_ROOT>/miniconda3
python3 --version
python3 - <<'PY'
import os
for key in ["ASCEND_HOME_PATH", "ASCEND_TOOLKIT_HOME", "ASCEND_OPP_PATH", "LD_LIBRARY_PATH"]:
    print(f"{key}={os.environ.get(key, '')}")
PY
```

判定标准：

- `npu-smi info` 能看到至少 2 张 NPU。
- `<WORK_ROOT>/miniconda3` 存在。
- `ASCEND_HOME_PATH` 或 `ASCEND_TOOLKIT_HOME` 不为空。

### 4.2 权重与 checkpoint 路径查询

虽然本任务不依赖外部预训练权重，但必须先查询本机已有产物，避免覆盖。

```bash
python3 - <<'PY'
from pathlib import Path
root = Path('<WORK_ROOT>')
patterns = ['**/*checkpoint*', '**/*.pt', '**/*.pth', '**/*.ckpt', '**/*.bin', '**/*.safetensors']
seen = set()
for pattern in patterns:
    for path in root.glob(pattern):
        value = str(path)
        if value not in seen:
            seen.add(value)
            print(value)
PY
```

补充检查：

```bash
ls -la <WORK_ROOT>/weight || true
ls -la <WORK_ROOT>/pytorch-examples/distributed/FSDP2 || true
```

处理原则：

- 若旧训练目录已存在 checkpoint，优先改用新的 `checkpoints_npu`。
- 若已有源码，直接复用。

## 五、源码路径策略

标准源码路径：

```bash
<WORK_ROOT>/pytorch-examples/distributed/FSDP2
```

先检查：

```bash
ls <WORK_ROOT>/pytorch-examples/distributed/FSDP2
```

不存在时再拉取：

```bash
git clone https://github.com/pytorch/examples <WORK_ROOT>/pytorch-examples
```

若 GitHub 失败，切镜像重试：

```bash
git clone https://gitcode.com/gh_mirrors/ex/examples <WORK_ROOT>/pytorch-examples
```

## 六、conda 环境

目标环境：

```bash
<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu
```

若环境不存在，执行：

```bash
<WORK_ROOT>/miniconda3/bin/conda create -y -p <WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu python=3.11
```

要求：

- 环境位于 `<WORK_ROOT>/conda_envs`。
- 不得使用 `conda create --clone`。
- 后续全部使用该环境中的 `python`/`pip`/`torchrun`。

## 七、安装软件包

### 7.1 基础原则

- 每次执行 NPU 相关 Python 命令前，都先 `source /usr/local/Ascend/ascend-toolkit/set_env.sh`。
- 优先安装 `torch==2.7.1` 与 `torch-npu==2.7.1.post2`。
- 若首次安装失败，优先切镜像。

### 7.2 安装命令

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu/bin/pip install \
  torch==2.7.1 \
  torch-npu==2.7.1.post2 \
  numpy

<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu/bin/pip install \
  attrs decorator psutil absl-py cloudpickle ml-dtypes scipy tornado pyyaml requests

<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu/bin/pip install \
  -r <WORK_ROOT>/pytorch-examples/distributed/FSDP2/requirements.txt
```

若失败，切镜像重试；阿里云镜像通常更稳：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu/bin/pip install -i https://mirrors.aliyun.com/pypi/simple --resume-retries 10 \
  torch==2.7.1 \
  torch-npu==2.7.1.post2 \
  numpy

<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu/bin/pip install -i https://mirrors.aliyun.com/pypi/simple \
  attrs decorator psutil absl-py cloudpickle ml-dtypes scipy tornado pyyaml requests
```

### 7.3 安装后校验

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu/bin/python - <<'PY'
import torch
import torch_npu
print('torch', torch.__version__)
print('torch_npu', torch_npu.__version__)
print('npu_available', torch.npu.is_available())
print('npu_count', torch.npu.device_count())
torch.npu.set_device(0)
x = torch.randn(2, 3).npu()
y = x + x
print('tensor_device', y.device)
PY
```

要求：

- `torch` 和 `torch_npu` 可导入。
- `torch.npu.is_available()` 为 `True`。
- `torch.npu.device_count()` 大于等于 2。
- 能在 `npu:0` 上完成最小张量计算。

说明：`torch.__version__` 显示 `2.7.1+cpu` 在 `torch_npu` 场景下属于正常现象。

## 八、代码适配要求

目标文件：

- `<WORK_ROOT>/pytorch-examples/distributed/FSDP2/example.py`
- `<WORK_ROOT>/pytorch-examples/distributed/FSDP2/model.py`
- `<WORK_ROOT>/pytorch-examples/distributed/FSDP2/checkpoint.py`
- `<WORK_ROOT>/pytorch-examples/distributed/FSDP2/run_example.sh`

### 8.1 `example.py`

必须做到：

- 引入 `torch_npu`，但允许 CPU 路径安全降级。
- 新增 `--device-type`、`--checkpoint-dir`、`--steps`、`--batch-size`、`--seq-len`。
- NPU 路径使用 `hccl` backend。
- 按 `LOCAL_RANK` 调用 `torch.npu.set_device(rank)`。
- checkpoint 目录可配置，默认建议 `checkpoints_npu`。
- 首次训练无 checkpoint 时初始化，第二次自动恢复。
- 日志打印 device、backend、checkpoint 路径，以及“初始化训练/从 checkpoint 恢复”。

### 8.2 `model.py`

必须做到：

- NPU 张量路径优先使用 `torch_npu.npu_fusion_attention`。
- 非 NPU 路径回退到 `torch.nn.functional.scaled_dot_product_attention`。
- 保持输入输出 shape 不变。
- 使用因果 mask。

推荐实现：

```python
if x.device.type == "npu":
    output = torch_npu.npu_fusion_attention(
        query,
        key,
        value,
        head_num=self.n_heads,
        input_layout="BNSD",
        atten_mask=atten_mask,
        scale=1.0 / (self.head_dim ** 0.5),
        keep_prob=1.0 - dropout_p,
    )[0]
else:
    output = F.scaled_dot_product_attention(...)
```

注意：

- 若 `npu_fusion_attention` 返回 tuple，取第一个输出张量。
- mask dtype 优先使用 `bool`。
- 若融合算子与压缩 mask 不兼容，以本机可用配置优先。

### 8.3 `checkpoint.py` 与脚本

- 不破坏原有 `dtensor_api` 与 `dcp_api` 逻辑。
- 只做与 NPU、路径、日志相关的最小修改。
- `run_example.sh` 要支持 `npu` 和 `torchrun --nproc_per_node >= 2`。

## 九、推荐修改步骤

建议顺序：

1. 先改 `example.py`。
2. 再改 `model.py`。
3. 必要时补 `run_example.sh`。
4. 先做语法检查，再做双卡训练。

语法检查：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu/bin/python -m py_compile \
  <WORK_ROOT>/pytorch-examples/distributed/FSDP2/example.py \
  <WORK_ROOT>/pytorch-examples/distributed/FSDP2/model.py \
  <WORK_ROOT>/pytorch-examples/distributed/FSDP2/checkpoint.py
```

## 十、训练验证

### 10.1 首次训练：生成 checkpoint

通用命令模板：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
export ASCEND_RT_VISIBLE_DEVICES=<VISIBLE_DEVICES>
export MASTER_ADDR=<HOST_IPV4>
export MASTER_PORT=<TRAIN_PORT>
export HCCL_IF_IP=<HOST_IPV4>
export HCCL_SOCKET_IFNAME==<HOST_IFNAME>
export HCCL_SOCKET_FAMILY=AF_INET
export HCCL_CONNECT_TIMEOUT=600
export HCCL_EXEC_TIMEOUT=600
export GLOO_SOCKET_IFNAME=lo
export TP_SOCKET_IFNAME=lo
PYTHONPATH=<WORK_ROOT>/pytorch-examples/distributed/FSDP2 \
<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu/bin/torchrun \
  --nnodes=1 \
  --node_rank=0 \
  --nproc_per_node=2 \
  --master_addr ${MASTER_ADDR} \
  --master_port ${MASTER_PORT} \
  <WORK_ROOT>/pytorch-examples/distributed/FSDP2/example.py \
  --device-type npu \
  --checkpoint-dir <WORK_ROOT>/pytorch-examples/distributed/FSDP2/checkpoints_npu \
  --steps 10 \
  --batch-size 32 \
  --seq-len 64 \
  --mixed-precision
```

验证目录：

```bash
ls -R <WORK_ROOT>/pytorch-examples/distributed/FSDP2/checkpoints_npu
```

要求看到：

- `dtensor_api/<timestamp>/model_state_dict.pt`
- `dtensor_api/<timestamp>/optim_state_dict.pt`

### 10.2 第二次训练：加载 checkpoint

恢复训练指向同一目录，并更换新的 `MASTER_PORT`：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
export ASCEND_RT_VISIBLE_DEVICES=<VISIBLE_DEVICES>
export MASTER_ADDR=<HOST_IPV4>
export MASTER_PORT=<RESUME_PORT>
export HCCL_IF_IP=<HOST_IPV4>
export HCCL_SOCKET_IFNAME==<HOST_IFNAME>
export HCCL_SOCKET_FAMILY=AF_INET
export HCCL_CONNECT_TIMEOUT=600
export HCCL_EXEC_TIMEOUT=600
export GLOO_SOCKET_IFNAME=lo
export TP_SOCKET_IFNAME=lo
PYTHONPATH=<WORK_ROOT>/pytorch-examples/distributed/FSDP2 \
<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu/bin/torchrun \
  --nnodes=1 \
  --node_rank=0 \
  --nproc_per_node=2 \
  --master_addr ${MASTER_ADDR} \
  --master_port ${MASTER_PORT} \
  <WORK_ROOT>/pytorch-examples/distributed/FSDP2/example.py \
  --device-type npu \
  --checkpoint-dir <WORK_ROOT>/pytorch-examples/distributed/FSDP2/checkpoints_npu \
  --steps 10 \
  --batch-size 32 \
  --seq-len 64 \
  --mixed-precision
```

恢复成功证据至少包含：

- 检测到最近 checkpoint 时间戳。
- 打印 `Loading optimizer state from checkpoint`。
- 打印 `Resuming from checkpoint ...`。

### 10.3 常见启动问题

- `hostname` 无法解析：不要依赖 `--standalone`，显式设置 `MASTER_ADDR`、`MASTER_PORT`。
- `Failed to bind the IP port`：更换 `MASTER_PORT`，并确保 `HCCL_IF_IP` 是本机真实 IPv4。
- HCCL 冲突：优先检查残留进程与被占用端口。

本机实测示例：

- `<WORK_ROOT>=/home`
- `ASCEND_RT_VISIBLE_DEVICES=6,7`
- `HOST_IFNAME=enp189s0f0`
- `HOST_IPV4=175.100.2.7`
- `TRAIN_PORT=29561`
- `RESUME_PORT=29563`

## 十一、建议交付脚本

目录：`<WORK_ROOT>/create/fsdp2-nanogpt-npu-migrate/scripts`

- `preflight_check.sh`：环境验证与路径查询。
- `create_env_and_install.sh`：环境补齐与安装。
- `validate_torch_npu.sh`：运行时验证。
- `run_fsdp2_npu.sh`：首次训练。
- `resume_fsdp2_npu.sh`：恢复训练。
- `verify_fsdp2_npu.sh`：串联执行预检、安装、运行时校验、首次训练和恢复训练。

脚本要求：

- 使用绝对路径。
- 统一正斜杠路径。
- 失败时 `exit 1`。
- 开头使用 `set -euo pipefail`。

## 十二、结果汇报模板

```text
1. 环境验证结果
   - NPU 卡数：
   - CANN 环境变量：
   - conda 路径：<WORK_ROOT>/miniconda3

2. 权重与源码复用结果
   - 复用源码：<WORK_ROOT>/pytorch-examples/distributed/FSDP2
   - 复用权重/历史产物：

3. 环境信息
   - conda 环境：<WORK_ROOT>/conda_envs/fsdp2_nanogpt_npu
   - torch 版本：
   - torch_npu 版本：

4. 代码修改信息
   - 修改文件：
   - `npu_fusion_attention` 接入位置：

5. 训练验证信息
   - 首次训练命令：
   - 首次 checkpoint 路径：
   - 第二次恢复命令：
   - 恢复成功证据：
```

## 十三、交付物

```text
<WORK_ROOT>/create/fsdp2-nanogpt-npu-migrate/
├── SKILL.md
└── scripts/
    ├── preflight_check.sh
    ├── create_env_and_install.sh
    ├── validate_torch_npu.sh
    ├── run_fsdp2_npu.sh
    └── resume_fsdp2_npu.sh
```

如已完成实机适配，还应补充：

- `<WORK_ROOT>/pytorch-examples/distributed/FSDP2` 下的 NPU 适配代码。
- `checkpoints_npu` 目录。
- 恢复训练日志证据。

该 Skill 的目标不是“给建议”，而是直接引导 Agent 完成从预检到 checkpoint 恢复验证的全流程。
