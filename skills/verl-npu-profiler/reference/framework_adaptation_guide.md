
# NPU Profiler框架适配指南

## 概述

本指南展示如何在不同框架中集成NPU Profiler，包括：
- PyTorch原生框架
- verl框架
- xtuner框架
- 自定义框架

## 适配原则

1. **最小侵入性**：尽量不修改框架核心代码
2. **配置驱动**：通过配置文件控制profiling行为
3. **灵活扩展**：支持多种profiling模式和级别
4. **统一接口**：提供统一的API接口

## 1. PyTorch原生框架适配


# PyTorch原生框架适配NPU Profiler

import torch
import torch_npu
from universal_npu_profiler import profile_npu, UniversalNPUProfiler

# 方法1：使用上下文管理器
def train_with_context_manager():
    with profile_npu("./profiler_data", level="level1", with_memory=True):
        for epoch in range(epochs):
            for batch in dataloader:
                output = model(batch)
                loss = criterion(output, target)
                loss.backward()
                optimizer.step()


# 方法2：手动控制
def train_with_manual_control():
    profiler = UniversalNPUProfiler("./profiler_data")
    profiler.start()
    
    for epoch in range(epochs):
        for batch in dataloader:
            output = model(batch)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            profiler.step()  # 标记每个步骤
    
    profiler.stop()


# 方法3：装饰器
from universal_npu_profiler import profile_function

@profile_function("./profiler_data", level="level1")
def train_step(model, batch):
    output = model(batch)
    loss = criterion(output, target)
    loss.backward()
    optimizer.step()
    return loss


## 2. verl框架适配


# verl框架适配NPU Profiler

# 1. 配置文件方式（推荐）
# 在 verl/trainer/config/profiler/profiler.yaml 中配置：

profiler:
  enable: True
  tool: npu
  ranks: [0]
  save_path: "outputs/profile"
  
  tool_config:
    npu:
      level: "level1"
      contents: [npu, cpu, memory]
      discrete: False


# 2. 代码中使用
from verl.utils.profiler import DistProfiler, mark_annotate

# 初始化profiler
profiler = DistProfiler(
    rank=rank,
    config=profiler_config,
    tool_config=npu_tool_config
)

# 启动profiling
profiler.start(role="e2e", profile_step=global_steps)

# 训练循环
for step in range(total_steps):
    # 使用装饰器标注函数
    @mark_annotate(message="train_step", color="blue")
    def train_step():
        ...
    
    train_step()

# 停止profiling
profiler.stop()


# 3. 全局配置方式
# 在trainer配置中设置：
global_profiler:
  steps: [1, 10, 100]
  tool: npu
  save_path: ./outputs/profile


## 3. xtuner框架适配


# xtuner框架适配NPU Profiler

# 1. 使用内置NPU Profiler（已适配）
from xtuner.v1.profiler import profiling_time, profiling_memory
from pathlib import Path

# 时间profiling
with profiling_time(Path("./profiler_data")):
    train_step(model, batch)

# 内存profiling
with profiling_memory(Path("./profiler_data")):
    train_step(model, batch)


# 2. 使用通用NPU Profiler（推荐，更灵活）
from universal_npu_profiler import profile_npu

with profile_npu("./profiler_data", level="level1", with_memory=True):
    for step in range(total_steps):
        train_step(model, batch)


# 3. 使用Prober系统
from xtuner.v1.profiler import ProberList, TimeProber, AccProber

# 配置prober
prober_list = ["TimeProber", "AccProber"]

# 在trainer中启用
trainer = Trainer(
    model=model,
    profile_step=[10, 20, 50],
    profile_time=True,
    profile_memory=False,
    prober_list=prober_list,
)


# 4. 优化配置（基于verl经验）
from xtuner.v1.profiler.npu_profile import profiling_time
import torch_npu

# 自定义NPU profiler配置
@contextmanager
def optimized_profiling_time(profile_dir: Path):
    experimental_config = torch_npu.profiler._ExperimentalConfig(
        aic_metrics=torch_npu.profiler.AiCMetrics.PipeUtilization,
        profiler_level=torch_npu.profiler.ProfilerLevel.Level1,
        l2_cache=False,
    )
    
    with torch_npu.profiler.profile(
        activities=[torch_npu.profiler.ProfilerActivity.CPU, 
                   torch_npu.profiler.ProfilerActivity.NPU],
        on_trace_ready=torch_npu.profiler.tensorboard_trace_handler(str(profile_dir)),
        record_shapes=True,
        profile_memory=True,
        with_stack=False,
        experimental_config=experimental_config,
    ) as prof:
        yield
        prof.step()


## 4. 自定义框架适配


# 自定义框架适配NPU Profiler

from universal_npu_profiler import UniversalNPUProfiler, profile_npu

class CustomTrainer:
    def __init__(self, model, profiler_config=None):
        self.model = model
        self.profiler = None
        
        if profiler_config:
            self.profiler = UniversalNPUProfiler(
                save_path=profiler_config.get("save_path", "./profiler_data"),
                settings=NPUProfilerSettings(
                    level=profiler_config.get("level", "level1"),
                    with_memory=profiler_config.get("with_memory", False),
                    record_shapes=profiler_config.get("record_shapes", False),
                    with_stack=profiler_config.get("with_stack", False),
                )
            )
    
    def train(self, dataloader, epochs):
        if self.profiler:
            self.profiler.start()
        
        try:
            for epoch in range(epochs):
                for batch in dataloader:
                    self._train_step(batch)
                    
                    if self.profiler:
                        self.profiler.step()
        finally:
            if self.profiler:
                self.profiler.stop()
    
    def _train_step(self, batch):
        # 你的训练逻辑
        output = self.model(batch)
        loss = self.criterion(output, batch.target)
        loss.backward()
        self.optimizer.step()


# 使用示例
trainer = CustomTrainer(
    model=model,
    profiler_config={
        "save_path": "./profiler_data",
        "level": "level1",
        "with_memory": True,
        "record_shapes": True,
    }
)

trainer.train(dataloader, epochs=10)


## 适配检查清单

### 基础检查
- [ ] 确认torch_npu已正确安装
- [ ] 确认NPU设备可用
- [ ] 确认profiler配置正确

### 功能检查
- [ ] Profiler可以正常启动和停止
- [ ] 生成的trace文件可以正常打开
- [ ] 性能数据完整且准确

### 性能检查
- [ ] Profiling对训练性能的影响在可接受范围内
- [ ] 内存使用正常，无内存泄漏
- [ ] 多卡训练时profiling正常工作

### 结果检查
- [ ] Trace文件包含完整的训练过程
- [ ] 可以使用Ascend Insight或TensorBoard查看结果
- [ ] 性能瓶颈可以准确定位

## 常见问题

### Q1: Profiler启动失败
**原因**: torch_npu未正确安装或NPU设备不可用
**解决**: 
```bash
pip install torch-npu
python -c "import torch_npu; print(torch_npu.npu.is_available())"
```

### Q2: 生成的trace文件为空
**原因**: Profiling时间过短或未调用step()
**解决**: 确保profiling持续时间足够长，并正确调用step()方法

### Q3: 性能影响过大
**原因**: Profiling级别过高或采集内容过多
**解决**: 降低level到level0，减少采集内容

### Q4: 多卡训练时只有部分rank有数据
**原因**: 只对部分rank启用了profiling
**解决**: 配置all_ranks=True或指定完整的ranks列表

## 最佳实践

1. **分级profiling**：
   - 初步分析：使用level0
   - 详细分析：使用level1
   - 深度分析：使用level2

2. **选择性采集**：
   - 只profile关键步骤
   - 只采集需要的信息
   - 避免同时开启所有采集选项

3. **合理使用模式**：
   - 开发调试：使用装饰器或上下文管理器
   - 性能测试：使用配置文件方式
   - 生产环境：使用条件性profiling

4. **结果分析**：
   - 使用Ascend Insight进行可视化分析
   - 关注性能瓶颈和热点
   - 结合业务场景优化

## 参考资料

- [PyTorch Profiler文档](https://pytorch.org/tutorials/recipes/recipes/profiler_recipe.html)
- [torch_npu Profiler文档](https://gitee.com/ascend/pytorch/blob/master/torch_npu/profiler/README.md)
- [Ascend Insight使用指南](https://www.hiascend.com/document/detail/zh/mindstudio/50RC2/msug/ug/ascendinsight_ug_0001.html)
