---
name: torch_npu_operator_tool
description: 提供 Torch NPU 算子 API 查询、单算子用例搭建、入参说明、版本兼容性判断和性能对比功能。在需要查询 torch_npu API 支持度、搭建单算子测试用例、了解入参含义、判断版本兼容性或对比算子性能时使用。

**【重要】本 skill 必须在获取实际运行环境信息后才能执行任何操作，严禁凭空捏造 API 信息或测试数据。**
**用户查询api信息是要在实际调用中使用，因此任何信息偏差都会导致使用失败，在没有明确信息前，请根据后续文档指导通过官网或者python代码的help实际获取，不可随意猜想**
**有执行代码的诉求时，直接执行，不要在本地生成额外的脚本**
**ssh登录的命令不止一种，请务必多尝试**
---

## 强制前置流程（必须执行）

> **⚠️ 每次用户触发本 skill 时，agent 必须使用 question 工具先询问用户以下信息，不可跳过！**

### 询问内容

使用 question 工具询问用户：

| 信息项 | 说明 | 询问示例 |
|--------|------|----------|
| **SSH连接** | 服务器IP、端口、用户名 | "请提供 NPU 服务器的 SSH 连接信息（IP:端口、用户名）" |
| **登录方式** | 密码或密钥 | "请提供登录密码或密钥" |
| **测试目标** | 要查询/测试的算子 | "您想查询或测试哪个算子？" |

### 获取环境信息

获取回答后，agent 必须登录服务器并执行以下命令获取真实版本信息：

```bash
# 获取 CANN 版本
cat /usr/local/Ascend/Ascend-cann-kernel-version

# 获取 PyTorch 和 torch_npu 版本
python -c "import torch; import torch_npu; print('PyTorch:', torch.__version__); print('torch_npu:', torch_npu.__version__)"

# 获取 NPU 设备名称
python -c "import torch_npu; print(torch_npu.npu.get_device_name(0))"
```

### 查询可用 API

```bash
# 查看所有 attention 相关算子
python -c "import torch_npu; print([x for x in dir(torch_npu) if 'attention' in x.lower() or 'flash' in x.lower()])"

# 获取特定算子详细信息
python -c "import torch_npu; help(torch_npu.npu_prompt_flash_attention)"
```

> **【关键原则】所有 API 信息、入参说明、性能数据必须来自实际查询结果，严禁从预存文件或文档中复制未经验证的信息。**

---

## 功能1: API 支持度查询

> **【必须操作】查询命令必须实际执行，禁止从预存文档复制未验证信息**

### 查询命令

```bash
# 查看所有 attention 相关算子
python -c "import torch_npu; print([x for x in dir(torch_npu) if 'attention' in x.lower() or 'flash' in x.lower()])"

# 获取特定算子完整签名和参数
python -c "import torch_npu; help(torch_npu.算子名称)"
```

### 输出格式（如查询结果为 xxx）

```
【API 支持度查询】

算子名称：torch_npu.xxx

函数原型：
（从 help 命令输出中复制）

支持的数据类型：
（从 help 命令输出中复制）

支持的数据格式：
（从 help 命令输出中复制）

支持的 PyTorch 版本：
（需查阅 CANN 文档或实际测试）

支持的芯片型号：
（需查阅 CANN 文档或实际测试）

约束说明：
（从实际测试中获取）
```

---

## 功能2: 单算子用例搭建

> **【必须操作】必须先通过 help 命令获取实际入参，禁止凭空构造调用代码**

### 步骤

1. **获取 API 签名**：`python -c "import torch_npu; help(torch_npu.算子名称)"`
2. **构造输入**：根据 API 要求构造 dtype、shape、布局
3. **编写调用代码**：基于实际 API 参数编写
4. **执行验证**：在实际环境中运行测试

### 输出格式

```
【单算子用例】

环境要求（从实际环境查询）：
- CANN：x.x
- PyTorch：x.x
- torch_npu：x.x

API 签名（从 help 输出复制）：
...

测试脚本位置：scripts/single_op_test.py

关键代码：
```python
import torch
import torch_npu

# 输入构造（根据实际 API 要求）
q = torch.randn(...).npu()
k = torch.randn(...).npu()
v = torch.randn(...).npu()

# 算子调用（根据实际 API 参数）
out = torch_npu.实际算子名(
    q, k, v,
    # 实际参数...
)

# 结果校验
print(f"输出 shape: {out.shape}")
```
```

---

## 功能3: 入参与返回说明

> **【必须操作】必须通过 help 命令获取实际参数，禁止从文档复制未验证信息**

---

## 功能4: 版本兼容性判断

> **【必须操作】必须基于实际环境版本和实际测试结果进行判断**

```
【版本兼容性判断】

当前环境（实际执行命令获取）：
- CANN：x.x（执行 cat /usr/local/Ascend/Ascend-cann-kernel-version）
- PyTorch：x.x（执行 python -c "import torch; print(torch.__version__)"）
- torch_npu：x.x
- 芯片：x.x（执行 python -c "import torch_npu; print(torch_npu.npu.get_device_name(0))"）

实际测试结果：
- [ ] 算子A：测试通过/失败
- [ ] 算子B：测试通过/失败

兼容性结果：根据实际测试填写
```

---

## 功能5: 性能对比测试

> **【必须操作】必须实际执行测试脚本并记录真实数据，禁止填写未验证的占位数据**

### 执行步骤

1. 登录 NPU 环境
2. 执行性能测试脚本：`python scripts/perf_comparison.py`
3. 记录实际测试数据

### 测试脚本位置

`scripts/perf_comparison.py`

### 输出格式

```
【性能对比测试】

测试环境（实际查询）：
- 芯片：（实际执行获取）
- CANN：（实际执行获取）
- PyTorch：（实际执行获取）
- torch_npu：（实际执行获取）
- 配置：N heads, head_dim=M, dtype=bfloat16

测试结果（实际执行获取）：

| Seq Length | npu_fusion_attention | npu_fused_infer_attention_score | npu_prompt_flash_attention |
|------------|----------------------|----------------------------------|----------------------------|
| 1024       | （实际数据）         | （实际数据）                     | （实际数据）               |
| 2048       | （实际数据）         | （实际数据）                     | （实际数据）               |
| ...        | ...                  | ...                              | ...                        |

结果解读：根据实际数据填写
选择建议：根据实际数据填写
```

## 参考文档（动态获取）

详细 API 参考和版本说明请通过以下方式获取：

### 1. 在线文档查询

- [Ascend Extension for PyTorch 自定义API](https://www.hiascend.com/document/detail/zh/Pytorch/730/apiref/torchnpuCustomsapi/docs/context/overview.md) - torch_npu 自定义算子 API
- [PyTorch 原生 API 支持度](https://www.hiascend.com/document/detail/zh/Pytorch/730/apiref/PyTorchNativeapi/docs/zh/native_apis/pytorch_2-9-0/overview.md) - 原生 PyTorch API 支持情况
- [CANN 版本说明](https://www.hiascend.com/document/detail/zh/Pytorch/730/releasenote/docs/zh/release_notes/release_notes.md) - torch_npu 版本与 CANN 对应关系
- [兼容性查询助手](https://www.hiascend.com/hardware/compatibility) - 硬件与软件兼容性查询

### 2. 本地 help 命令查询

在 NPU 环境中运行以下命令获取实时 API 信息：

```bash
# 查看所有 attention 相关算子
python -c "import torch_npu; print([x for x in dir(torch_npu) if 'attention' in x.lower()])"

# 获取特定算子的详细帮助
python -c "import torch_npu; help(torch_npu.npu_XXXXXX)"

# 获取版本信息
python -c "import torch; import torch_npu; print('PyTorch:', torch.__version__); print('torch_npu:', torch_npu.__version__)"
```

> **注意**：由于 API 会随版本更新，建议通过上述方式实时获取最新信息，而非使用预记录的文档。

---

## 测试脚本

> **【重要】以下脚本为框架模板，必须根据实际查询结果填充 API 调用代码**

性能测试脚本位置：
- `scripts/single_op_test.py` - 单算子功能测试框架（需填充实际 API）
- `scripts/perf_comparison.py` - 性能对比测试框架（需填充实际 API）

使用前必须：
1. 登录 NPU 环境
2. 查询实际 API：`python -c "import torch_npu; help(torch_npu.算子名)"`
3. 根据查询结果填充脚本中的 API 调用代码
4. 执行脚本获取实际数据

---

## 限制说明

> **【关键原则】**
> - 本 Skill 仅支持昇腾 NPU 环境
> - 禁止凭空捏造任何 API 信息、入参或性能数据
> - 所有信息必须来自实际查询或测试结果
> - 性能数据因硬件配置和负载可能略有差异
> - 版本兼容性需以官方文档和实际测试为准