# verl NPU 部署常见问题排查

## 容器启动问题

### libascend_hal.so 找不到
**症状**: 容器内提示找不到 `libascend_hal.so`

**解决**: 确认挂载了 Ascend 驱动
```bash
-v /usr/local/Ascend/driver:/usr/local/Ascend/driver:ro
-v /usr/local/Ascend/add-ons:/usr/local/Ascend/add-ons:ro
```

### NPU 设备不可见
**症状**: `npu-smi: command not found`

**解决**: 确认挂载了 NPU 设备
```bash
--device /dev/davinci0 --device /dev/davinci1 ...
```

## 训练运行问题

### AssertionError: Please set at least one of 'actor.ppo_micro_batch_size'
**症状**: 启动训练时报错

**解决**: 添加必需参数
```bash
actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=1
```

### OOM (Out of Memory)
**症状**: 训练过程中内存不足报错

**解决**:
1. 降低批次大小
```bash
data.train_batch_size=4
```

2. 降低vLLM显存利用
```bash
actor_rollout_ref.rollout.gpu_memory_utilization=0.3
```

3. 开启offload
```bash
actor_rollout_ref.actor.fsdp_config.param_offload=True
actor_rollout_ref.actor.fsdp_config.optimizer_offload=True
```

### vLLM 超时
**症状**: vLLM rollout 超时

**解决**:
```bash
actor_rollout_ref.rollout.gpu_memory_utilization=0.2
actor_rollout_ref.rollout.n=1
```

### wandb 报错
**症状**: wandb 登录或连接错误

**解决**: 使用控制台日志
```bash
trainer.logger=["console"]
```

### NCCL 通信超时
**症状**: `NCCL timeout` 错误

**解决**:
1. 检查NPU连接状态
2. 增加超时时间
```bash
actor_rollout_ref.nccl_timeout=1200
```

## Checkpoint 问题

### Checkpoint 加载失败
**解决**: 
1. 确认checkpoint路径正确
2. 确认模型结构一致

### 训练中断后恢复
```bash
# 使用checkpoint路径作为model.path
actor_rollout_ref.model.path=/home/zzw/checkpoints/verify1/global_step_20
```

## 性能问题

### 训练速度慢
**优化建议**:
1. 启用梯度检查点: `enable_gradient_checkpointing=True`
2. 使用更大的批次: 根据显存调整
3. 调整 TP/PP 并行度

### vLLM 启动慢
**优化建议**:
```bash
actor_rollout_ref.rollout.enforce_eager=False  # 使用CUDA图
```

## 环境验证命令

```bash
# 检查NPU
npu-smi info

# 检查容器内NPU
docker exec verl-npu bash -lc "source /usr/local/Ascend/ascend-toolkit/set_env.sh && npu-smi info"

# 检查Python环境
docker exec verl-npu python -V && pip show verl

# 查看运行日志
docker logs -f verl-npu

# 进入容器调试
docker exec -it verl-npu bash
```
