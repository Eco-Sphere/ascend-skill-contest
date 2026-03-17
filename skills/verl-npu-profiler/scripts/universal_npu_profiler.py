#!/usr/bin/env python3
"""
通用NPU Profiler适配脚本
可以在任意PyTorch框架中使用，提供统一的NPU profiling接口
"""

import os
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Optional, List, Dict, Any
from dataclasses import dataclass

try:
    import torch
    import torch_npu
    NPU_AVAILABLE = True
except ImportError:
    NPU_AVAILABLE = False


@dataclass
class NPUProfilerSettings:
    """NPU Profiler设置"""
    level: str = "level1"  # level0, level1, level2
    with_cpu: bool = True
    with_npu: bool = True
    with_memory: bool = False
    record_shapes: bool = False
    with_stack: bool = False
    aic_metrics: str = "PipeUtilization"
    l2_cache: bool = False


class UniversalNPUProfiler:
    """通用NPU Profiler类"""
    
    def __init__(
        self,
        save_path: str = "./profiler_data",
        settings: Optional[NPUProfilerSettings] = None,
    ):
        """
        初始化NPU Profiler
        
        Args:
            save_path: profiler数据保存路径
            settings: profiler设置，如果为None则使用默认设置
        """
        if not NPU_AVAILABLE:
            raise RuntimeError("NPU is not available. Please install torch_npu.")
        
        self.save_path = Path(save_path)
        self.save_path.mkdir(parents=True, exist_ok=True)
        
        self.settings = settings or NPUProfilerSettings()
        self._profiler = None
        self._is_running = False
    
    def _get_profiler_level(self):
        """获取profiler level"""
        level_map = {
            "level0": torch_npu.profiler.ProfilerLevel.Level0,
            "level1": torch_npu.profiler.ProfilerLevel.Level1,
            "level2": torch_npu.profiler.ProfilerLevel.Level2,
        }
        return level_map.get(self.settings.level.lower(), torch_npu.profiler.ProfilerLevel.Level1)
    
    def _get_aic_metrics(self):
        """获取AI Core metrics"""
        metrics_map = {
            "AiCoreNone": torch_npu.profiler.AiCMetrics.AiCoreNone,
            "PipeUtilization": torch_npu.profiler.AiCMetrics.PipeUtilization,
            "Memory": torch_npu.profiler.AiCMetrics.Memory,
            "MemoryL0": torch_npu.profiler.AiCMetrics.MemoryL0,
            "MemoryL1": torch_npu.profiler.AiCMetrics.MemoryL1,
            "ResourceConflictRatio": torch_npu.profiler.AiCMetrics.ResourceConflictRatio,
        }
        return metrics_map.get(self.settings.aic_metrics, torch_npu.profiler.AiCMetrics.PipeUtilization)
    
    def _get_activities(self):
        """获取profiler activities"""
        activities = []
        if self.settings.with_cpu:
            activities.append(torch_npu.profiler.ProfilerActivity.CPU)
        if self.settings.with_npu:
            activities.append(torch_npu.profiler.ProfilerActivity.NPU)
        return activities
    
    def start(self):
        """启动profiler"""
        if self._is_running:
            print("Warning: Profiler is already running.")
            return
        
        experimental_config = torch_npu.profiler._ExperimentalConfig(
            aic_metrics=self._get_aic_metrics(),
            profiler_level=self._get_profiler_level(),
            l2_cache=self.settings.l2_cache,
        )
        
        self._profiler = torch_npu.profiler.profile(
            activities=self._get_activities(),
            on_trace_ready=torch_npu.profiler.tensorboard_trace_handler(str(self.save_path)),
            record_shapes=self.settings.record_shapes,
            profile_memory=self.settings.with_memory,
            with_stack=self.settings.with_stack,
            experimental_config=experimental_config,
        )
        
        self._profiler.__enter__()
        self._is_running = True
        print(f"NPU Profiler started. Data will be saved to: {self.save_path}")
    
    def step(self):
        """标记一个profiling步骤"""
        if self._is_running and self._profiler:
            self._profiler.step()
    
    def stop(self):
        """停止profiler"""
        if not self._is_running:
            print("Warning: Profiler is not running.")
            return
        
        if self._profiler:
            self._profiler.__exit__(None, None, None)
            self._profiler = None
        
        self._is_running = False
        print(f"NPU Profiler stopped. Data saved to: {self.save_path}")
    
    def __enter__(self):
        self.start()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.stop()


@contextmanager
def profile_npu(
    save_path: str = "./profiler_data",
    level: str = "level1",
    with_memory: bool = False,
    record_shapes: bool = False,
    with_stack: bool = False,
):
    """
    NPU Profiling上下文管理器
    
    Args:
        save_path: profiler数据保存路径
        level: profiler级别 (level0, level1, level2)
        with_memory: 是否记录内存信息
        record_shapes: 是否记录张量形状
        with_stack: 是否记录调用栈
    
    Example:
        >>> with profile_npu("./my_profile", level="level1"):
        ...     # 你的训练代码
        ...     model(input_data)
    """
    settings = NPUProfilerSettings(
        level=level,
        with_memory=with_memory,
        record_shapes=record_shapes,
        with_stack=with_stack,
    )
    
    profiler = UniversalNPUProfiler(save_path, settings)
    profiler.start()
    
    try:
        yield profiler
    finally:
        profiler.stop()


def profile_function(
    func,
    save_path: str = "./profiler_data",
    level: str = "level1",
    **kwargs
):
    """
    函数装饰器：自动对函数进行profiling
    
    Args:
        func: 要profiling的函数
        save_path: profiler数据保存路径
        level: profiler级别
        **kwargs: 其他profiler参数
    
    Example:
        >>> @profile_function("./my_profile", level="level1")
        ... def train_step(model, data):
        ...     return model(data)
    """
    def wrapper(*args, **func_kwargs):
        with profile_npu(save_path, level=level, **kwargs):
            return func(*args, **func_kwargs)
    
    return wrapper


# 便捷函数
def quick_profile(save_path: str = "./profiler_data"):
    """快速profiling（level0，最小性能影响）"""
    return profile_npu(save_path, level="level0")


def standard_profile(save_path: str = "./profiler_data"):
    """标准profiling（level1，平衡性能和详细信息）"""
    return profile_npu(save_path, level="level1", with_memory=True, record_shapes=True)


def detailed_profile(save_path: str = "./profiler_data"):
    """详细profiling（level2，完整信息，较大性能影响）"""
    return profile_npu(save_path, level="level2", with_memory=True, record_shapes=True, with_stack=True)


# 使用示例
if __name__ == "__main__":
    print("=" * 60)
    print("NPU Profiler适配脚本使用示例")
    print("=" * 60)
    
    print("\n方法1：使用上下文管理器")
    print("-" * 60)
    print("""
with profile_npu("./my_profile", level="level1"):
    # 你的训练代码
    output = model(input_data)
    loss = criterion(output, target)
    loss.backward()
""")
    
    print("\n方法2：使用装饰器")
    print("-" * 60)
    print("""
@profile_function("./my_profile", level="level1")
def train_step(model, data):
    return model(data)

# 调用函数时自动profiling
train_step(model, data)
""")
    
    print("\n方法3：使用便捷函数")
    print("-" * 60)
    print("""
# 快速profiling
with quick_profile("./quick_profile"):
    model(input_data)

# 标准profiling
with standard_profile("./standard_profile"):
    model(input_data)

# 详细profiling
with detailed_profile("./detailed_profile"):
    model(input_data)
""")
    
    print("\n方法4：手动控制")
    print("-" * 60)
    print("""
profiler = UniversalNPUProfiler("./my_profile")
profiler.start()

# 训练循环
for epoch in range(epochs):
    for batch in dataloader:
        output = model(batch)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()
        profiler.step()  # 标记每个步骤

profiler.stop()
""")
    
    print("\n" + "=" * 60)
    print("配置选项说明")
    print("=" * 60)
    print("""
Level配置：
  - level0: 基础采集，最小性能影响
  - level1: 详细采集，平衡性能和详细信息（推荐）
  - level2: 完整采集，最大性能影响

采集选项：
  - with_cpu: 是否采集CPU信息
  - with_npu: 是否采集NPU信息
  - with_memory: 是否采集内存信息
  - record_shapes: 是否记录张量形状
  - with_stack: 是否记录调用栈

AI Core Metrics：
  - PipeUtilization: 流水线利用率（推荐用于性能分析）
  - Memory: 内存使用情况
  - ResourceConflictRatio: 资源冲突率
""")
    
    print("=" * 60)
