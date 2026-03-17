---
name: verl-npu-profiler
description: VeRL框架 NPU Profiling 采集指南。在用户需要进行VeRL训练性能分析、profiling采集、性能调优，或提到CPU/内存采集、不同level采集、step范围采集时自动应用。支持VeRL框架的完整profiling流程，包括配置、启动、结果分析。
---

# VeRL框架 NPU Profiling 采集指南

## 何时使用本 Skill

- 用户需要**VeRL训练性能分析**：使用VeRL框架进行训练性能分析
- 用户提到**profiling、profiler、性能调优**：需要对VeRL训练进行性能分析
- 用户需要**CPU/内存采集**：采集CPU、内存等性能数据
- 用户需要**不同level采集**：选择不同profiling级别（level0/level1/level2）
- 用户需要**step范围采集**：指定采集的step范围
- 用户遇到**VeRL profiling问题**：VeRL profiling配置或使用问题

---

## 快速开始

### 最简单的使用方式

```bash
# 在VeRL训练脚本中添加profiling配置
python train.py \
    --profiler.enable True \
    --profiler.tool npu \
    --profiler.save_path ./profiler_data \
    --profiler.tool_config.npu.level level1
```

### Python代码中使用

```python
from verl.utils.profiler import DistProfiler

# 创建profiler配置
config = {
    "enable": True,
    "tool": "npu",
    "ranks": [0],
    "save_path": "./profiler_data",
    "tool_config": {
        "npu": {
            "level": "level1",
            "contents": ["npu", "cpu", "memory"],
            "discrete": False,
        }
    }
}

# 启动profiler
profiler = DistProfiler(rank=0, config=config)
profiler.start()

# 训练代码
train_loop()

# 停止profiler
profiler.stop()
```

---

## 目录结构

```
verl-npu-profiler/
├── SKILL.md                              # 本文件
├── reference/
│   └── verl_profiler_config.md           # VeRL Profiler配置详解
└── scripts/
    └── verl_profiler_runner.py           # VeRL Profiler运行脚本
```

---

## 核心功能

### 1. Profiling Level 选择

| Level | 说明 | 性能影响 | 采集内容 | 适用场景 |
|-------|------|----------|----------|----------|
| **level0** | 基础采集 | < 5% | 算子耗时、基础统计 | 快速性能概览 |
| **level1** | 详细采集 | 10-20% | 算子耗时、内存、通信 | 常规性能分析（推荐） |
| **level2** | 完整采集 | > 30% | 全量数据、调用栈、详细内存 | 深度性能分析 |

### 2. 采集内容配置

| 内容类型 | 配置项 | 说明 |
|----------|--------|------|
| **NPU计算** | `npu` | NPU算子执行时间、AI Core利用率 |
| **CPU计算** | `cpu` | CPU算子执行时间、主机端耗时 |
| **内存** | `memory` | 内存分配、释放、峰值使用 |
| **通信** | `hccl` | HCCL通信耗时、带宽利用率 |

### 3. Step范围采集

```python
# 方式1：指定step范围
config = {
    "enable": True,
    "tool": "npu",
    "save_path": "./profiler_data",
    "tool_config": {
        "npu": {
            "level": "level1",
            "start_step": 10,   # 从第10步开始
            "end_step": 20,     # 到第20步结束
        }
    }
}

# 方式2：在代码中动态控制
profiler = DistProfiler(rank=0, config=config)

for step in range(total_steps):
    if step == 10:
        profiler.start()
    train_step()
    if step == 20:
        profiler.stop()
```

---

## 配置详解

### 完整配置示例

```yaml
# verl_profiler_config.yaml
profiler:
  enable: True
  tool: npu                    # 使用NPU profiler
  ranks: [0]                   # 采集的rank列表
  save_path: "./profiler_data" # 输出路径
  
  tool_config:
    npu:
      level: "level1"          # profiling级别
      contents:                # 采集内容
        - npu
        - cpu
        - memory
      discrete: False          # 是否离散模式
      start_step: 0            # 起始step
      end_step: -1             # 结束step (-1表示不限制)
      aic_metrics: "PipeUtilization"  # AI Core指标
      record_shapes: True      # 记录张量形状
      with_stack: False        # 记录调用栈
      with_modules: True       # 记录模块信息
```

### 配置参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enable` | bool | False | 是否启用profiler |
| `tool` | str | "npu" | profiler工具类型 |
| `ranks` | list | [0] | 采集的rank列表 |
| `save_path` | str | "./profile" | 输出路径 |
| `level` | str | "level1" | profiling级别 |
| `contents` | list | ["npu"] | 采集内容列表 |
| `discrete` | bool | False | 离散模式（每步独立采集） |
| `start_step` | int | 0 | 起始step |
| `end_step` | int | -1 | 结束step |
| `aic_metrics` | str | "PipeUtilization" | AI Core指标类型 |

---

## 使用场景

### 场景1：快速性能概览

```bash
# 使用level0进行快速概览
python train.py \
    --profiler.enable True \
    --profiler.tool npu \
    --profiler.tool_config.npu.level level0 \
    --profiler.save_path ./quick_profile
```

### 场景2：详细性能分析

```bash
# 使用level1进行详细分析，采集CPU和内存
python train.py \
    --profiler.enable True \
    --profiler.tool npu \
    --profiler.tool_config.npu.level level1 \
    --profiler.tool_config.npu.contents "[npu, cpu, memory]" \
    --profiler.save_path ./detailed_profile
```

### 场景3：特定step范围采集

```bash
# 只采集第10-20步
python train.py \
    --profiler.enable True \
    --profiler.tool npu \
    --profiler.tool_config.npu.level level1 \
    --profiler.tool_config.npu.start_step 10 \
    --profiler.tool_config.npu.end_step 20 \
    --profiler.save_path ./step_range_profile
```

### 场景4：多卡训练采集

```bash
# 采集rank 0和rank 1
python train.py \
    --profiler.enable True \
    --profiler.tool npu \
    --profiler.ranks "[0, 1]" \
    --profiler.tool_config.npu.level level1 \
    --profiler.save_path ./multi_rank_profile
```

### 场景5：内存问题分析

```bash
# 专注内存分析
python train.py \
    --profiler.enable True \
    --profiler.tool npu \
    --profiler.tool_config.npu.level level1 \
    --profiler.tool_config.npu.contents "[npu, memory]" \
    --profiler.tool_config.npu.aic_metrics Memory \
    --profiler.save_path ./memory_profile
```

---

## 结果分析

### 查看结果

**使用Ascend Insight**：

```bash
# 启动Ascend Insight
ascend-insight

# 导入trace文件
# File -> Open -> 选择profiler_data目录
```

**使用TensorBoard**：

```bash
# 启动TensorBoard
tensorboard --logdir=./profiler_data

# 浏览器访问
# http://localhost:6006
```

### 结果文件结构

```
profiler_data/
├── rank0/
│   ├── trace.json              # Chrome Trace格式
│   ├── memory_snapshot.pickle  # 内存快照
│   └── summary.json            # 汇总信息
├── rank1/
│   └── ...
└── overview.json               # 全局概览
```

### 关键指标解读

| 指标 | 说明 | 优化方向 |
|------|------|----------|
| **AI Core利用率** | 计算单元使用效率 | 提高算子融合、减少通信 |
| **内存峰值** | 最大内存使用量 | 减少batch size、使用gradient checkpointing |
| **通信耗时** | HCCL通信时间 | 优化通信拓扑、使用overlap |
| **Host耗时** | CPU端处理时间 | 优化数据加载、减少Python开销 |

---

## 常见问题排查

### Q1: Profiler启动失败

**症状**：`RuntimeError: NPU is not available`

**解决**：

```bash
# 检查torch_npu安装
python -c "import torch_npu; print(torch_npu.npu.is_available())"

# 检查NPU设备
npu-smi info
```

### Q2: 生成的trace文件为空

**症状**：trace文件大小为0或无法打开

**解决**：

```python
# 确保profiling持续时间足够长
# 至少运行10步以上
config["tool_config"]["npu"]["start_step"] = 5   # 跳过warmup
config["tool_config"]["npu"]["end_step"] = 20    # 采集15步
```

### Q3: 性能影响过大

**症状**：训练速度明显下降（>50%）

**解决**：

```python
# 方法1：降低level
config["tool_config"]["npu"]["level"] = "level0"

# 方法2：减少采集内容
config["tool_config"]["npu"]["contents"] = ["npu"]

# 方法3：使用离散模式
config["tool_config"]["npu"]["discrete"] = True
```

### Q4: 内存不足

**症状**：Profiling过程中OOM

**解决**：

```python
# 关闭内存采集
config["tool_config"]["npu"]["contents"] = ["npu", "cpu"]

# 或使用离散模式
config["tool_config"]["npu"]["discrete"] = True
```

### Q5: 多卡训练时只有部分rank有数据

**症状**：只有部分rank有trace文件

**解决**：

```python
# 确保配置了正确的ranks
config["ranks"] = [0, 1, 2, 3]  # 采集所有rank

# 或只采集特定rank
config["ranks"] = [0]  # 只采集rank 0
```

---

## 最佳实践

### 1. 分级profiling策略

```python
# 第一轮：快速概览
config["tool_config"]["npu"]["level"] = "level0"
# 运行训练，分析结果

# 第二轮：详细分析
config["tool_config"]["npu"]["level"] = "level1"
config["tool_config"]["npu"]["contents"] = ["npu", "cpu", "memory"]
# 运行训练，定位问题

# 第三轮：深度分析
config["tool_config"]["npu"]["level"] = "level2"
# 运行训练，深入分析
```

### 2. 选择性采集

```python
# 只关注计算性能
config["tool_config"]["npu"]["contents"] = ["npu"]

# 只关注内存问题
config["tool_config"]["npu"]["contents"] = ["npu", "memory"]
config["tool_config"]["npu"]["aic_metrics"] = "Memory"

# 只关注通信问题
config["tool_config"]["npu"]["contents"] = ["npu", "hccl"]
```

### 3. 条件性profiling

```python
import os

# 通过环境变量控制
ENABLE_PROFILING = os.getenv("ENABLE_PROFILING", "false").lower() == "true"

if ENABLE_PROFILING:
    config["enable"] = True
```

### 4. 结合训练阶段

```python
# 只在稳定训练阶段profiling
config["tool_config"]["npu"]["start_step"] = 100  # 跳过warmup
config["tool_config"]["npu"]["end_step"] = 150    # 采集50步
```

---

## 参考资源

### 文档

- **VeRL Profiler配置**: `reference/verl_profiler_config.md`
- **VeRL Profiler运行脚本**: `scripts/verl_profiler_runner.py`

### 外部资源

- [PyTorch Profiler文档](https://pytorch.org/tutorials/recipes/recipes/profiler_recipe.html)
- [torch_npu Profiler文档](https://gitee.com/ascend/pytorch/blob/master/torch_npu/profiler/README.md)
- [Ascend Insight使用指南](https://www.hiascend.com/document/detail/zh/mindstudio/50RC2/msug/ug/ascendinsight_ug_0001.html)
- [VeRL框架文档](https://github.com/volcengine/verl)

---

## 总结

本skill提供了VeRL框架完整的NPU Profiling采集方案：

1. **多级别采集**：支持level0/level1/level2三种级别
2. **灵活配置**：支持CPU、内存、通信等多种采集内容
3. **Step范围控制**：支持指定采集的step范围
4. **多卡支持**：支持多卡训练的profiling采集
5. **问题排查**：提供完整的常见问题解决方案

通过本skill，可以在VeRL框架中快速完成性能数据采集，定位训练瓶颈，优化训练效率。
