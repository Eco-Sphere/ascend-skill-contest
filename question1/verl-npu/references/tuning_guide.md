# verl GRPO 训练调优指南

## 按 NPU 卡数推荐配置

### 8 卡配置
```bash
data.train_batch_size=16-64
actor_rollout_ref.rollout.gpu_memory_utilization=0.5-0.7
actor_rollout_ref.rollout.tensor_model_parallel_size=1-2
actor_rollout_ref.rollout.n=2-4
trainer.n_gpus_per_node=8
```

### 4 卡配置
```bash
data.train_batch_size=8-32
actor_rollout_ref.rollout.gpu_memory_utilization=0.4-0.6
actor_rollout_ref.rollout.tensor_model_parallel_size=1
actor_rollout_ref.rollout.n=2
trainer.n_gpus_per_node=4
```

### 2 卡配置
```bash
data.train_batch_size=4-16
actor_rollout_ref.rollout.gpu_memory_utilization=0.3-0.5
actor_rollout_ref.rollout.tensor_model_parallel_size=1
actor_rollout_ref.rollout.n=2
trainer.n_gpus_per_node=2
```

### 1 卡配置
```bash
data.train_batch_size=1-4
actor_rollout_ref.rollout.gpu_memory_utilization=0.2-0.3
actor_rollout_ref.rollout.tensor_model_parallel_size=1
actor_rollout_ref.rollout.n=1
trainer.n_gpus_per_node=1
```

## 显存优化策略

### 策略一：降低批次
```bash
data.train_batch_size=4
```

### 策略二：降低vLLM显存
```bash
actor_rollout_ref.rollout.gpu_memory_utilization=0.3
```

### 策略三：开启参数offload
```bash
actor_rollout_ref.actor.fsdp_config.param_offload=True
actor_rollout_ref.actor.fsdp_config.optimizer_offload=True
```

### 策略四：减少rollout样本数
```bash
actor_rollout_ref.rollout.n=1
```

## 性能优化策略

### 梯度检查点
```bash
actor_rollout_ref.model.enable_gradient_checkpointing=True
```

### 去除padding
```bash
actor_rollout_ref.model.use_remove_padding=True
actor_rollout_ref.rollout.enable_chunked_prefill=True
```

### 启用torch compile
```bash
actor_rollout_ref.actor.fsdp_config.use_torch_compile=True
```

## 学习率调度

### 常用学习率
| 模型大小 | 推荐学习率 |
|---------|-----------|
| 0.6B | 3e-6 |
| 1.8B | 1e-6 |
| 7B | 5e-7 |

### Warmup设置
```bash
actor_rollout_ref.actor.optim.lr_warmup_steps=100
actor_rollout_ref.actor.optim.lr_scheduler_type=cosine
```

## 算法参数

### GRPO配置
```bash
algorithm.adv_estimator=grpo
algorithm.norm_adv_by_std_in_grpo=True
algorithm.gamma=1.0
algorithm.lam=1.0
```

### KL控制
```bash
algorithm.kl_ctrl.type=fixed
algorithm.kl_ctrl.kl_coef=0.001
algorithm.kl_ctrl.target_kl=0.1
```
