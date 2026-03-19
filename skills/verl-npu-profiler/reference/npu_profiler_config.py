"""
NPU Profiler优化配置
基于verl框架的NPU profiler经验，为xtuner框架提供优化的配置
"""

from dataclasses import dataclass
from typing import List, Optional
from enum import Enum


class ProfilerLevel(Enum):
    """NPU Profiler采集级别"""
    LEVEL_NONE = "Level0"  # 不采集
    LEVEL_0 = "Level0"     # 基础采集
    LEVEL_1 = "Level1"     # 详细采集
    LEVEL_2 = "Level2"     # 完整采集


class AiCMetrics(Enum):
    """AI Core指标类型"""
    AiCoreNone = "AiCoreNone"
    PipeUtilization = "PipeUtilization"  # 推荐用于性能分析
    Memory = "Memory"
    MemoryL0 = "MemoryL0"
    MemoryL1 = "MemoryL1"
    ResourceConflictRatio = "ResourceConflictRatio"


@dataclass
class NPUProfilerConfig:
    """NPU Profiler配置类"""
    
    # 基础配置
    enable: bool = True
    level: ProfilerLevel = ProfilerLevel.LEVEL_1
    save_path: str = "./profiler_data"
    
    # 采集内容配置
    with_cpu: bool = True
    with_npu: bool = True
    with_memory: bool = False
    record_shapes: bool = False
    with_stack: bool = False
    with_modules: bool = False
    
    # 高级配置
    aic_metrics: AiCMetrics = AiCMetrics.PipeUtilization
    l2_cache: bool = False
    op_attr: bool = False
    data_simplification: bool = True
    
    # 输出配置
    export_type: List[str] = None  # ["Text", "Db", "TensorBoard"]
    
    def __post_init__(self):
        if self.export_type is None:
            self.export_type = ["TensorBoard"]
    
    def get_experimental_config(self):
        """获取torch_npu.profiler._ExperimentalConfig配置"""
        import torch_npu
        
        return torch_npu.profiler._ExperimentalConfig(
            aic_metrics=getattr(torch_npu.profiler.AiCMetrics, self.aic_metrics.value),
            profiler_level=getattr(torch_npu.profiler.ProfilerLevel, self.level.value),
            l2_cache=self.l2_cache,
            op_attr=self.op_attr,
            data_simplification=self.data_simplification,
        )
    
    def get_activities(self):
        """获取profiler activities配置"""
        import torch_npu
        
        activities = []
        if self.with_cpu:
            activities.append(torch_npu.profiler.ProfilerActivity.CPU)
        if self.with_npu:
            activities.append(torch_npu.profiler.ProfilerActivity.NPU)
        
        return activities


# 预定义配置模板
PROFILER_CONFIGS = {
    "quick": NPUProfilerConfig(
        level=ProfilerLevel.LEVEL_0,
        with_memory=False,
        record_shapes=False,
        with_stack=False,
        aic_metrics=AiCMetrics.PipeUtilization,
    ),
    
    "standard": NPUProfilerConfig(
        level=ProfilerLevel.LEVEL_1,
        with_memory=True,
        record_shapes=True,
        with_stack=False,
        aic_metrics=AiCMetrics.PipeUtilization,
    ),
    
    "detailed": NPUProfilerConfig(
        level=ProfilerLevel.LEVEL_2,
        with_memory=True,
        record_shapes=True,
        with_stack=True,
        with_modules=True,
        aic_metrics=AiCMetrics.PipeUtilization,
        l2_cache=True,
    ),
    
    "memory": NPUProfilerConfig(
        level=ProfilerLevel.LEVEL_1,
        with_memory=True,
        aic_metrics=AiCMetrics.Memory,
    ),
}


def get_profiler_config(config_name: str = "standard") -> NPUProfilerConfig:
    """获取预定义的profiler配置
    
    Args:
        config_name: 配置名称，可选值：quick, standard, detailed, memory
    
    Returns:
        NPUProfilerConfig实例
    """
    if config_name not in PROFILER_CONFIGS:
        raise ValueError(f"Unknown config name: {config_name}. "
                        f"Available configs: {list(PROFILER_CONFIGS.keys())}")
    
    return PROFILER_CONFIGS[config_name]
