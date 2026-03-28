# verl GRPO 训练配置参数详解

## 必需参数

### 数据配置
| 参数 | 说明 | 示例值 |
|------|------|--------|
| `data.train_files` | 训练数据parquet文件路径 | `/home/zzw/datasets/gsm8k/processed/train.parquet` |
| `data.val_files` | 验证数据parquet文件路径 | `/home/zzw/datasets/gsm8k/processed/val.parquet` |
| `data.train_batch_size` | 训练批次大小 | 8-64 |
| `data.max_prompt_length` | 最大prompt长度 | 256 |
| `data.max_response_length` | 最大响应长度 | 256 |

### 模型配置
| 参数 | 说明 | 示例值 |
|------|------|--------|
| `actor_rollout_ref.model.path` | 模型路径 | `/home/zzw/models/Qwen3-0.6B` |
| `actor_rollout_ref.model.enable_gradient_checkpointing` | 启用梯度检查点 | True |

### 训练器配置
| 参数 | 说明 | 示例值 |
|------|------|--------|
| `trainer.device` | 训练设备 | `npu` |
| `trainer.n_gpus_per_node` | GPU数量 | 8 |
| `trainer.total_training_steps` | 总训练步数 | 200 |
| `trainer.save_freq` | 保存频率 | 50 |
| `trainer.test_freq` | 测试频率 | 50 |
| `trainer.default_local_dir` | checkpoint保存目录 | `/home/zzw/checkpoints/...` |

## 可选参数（显存优化）

### 显存不足时开启
```bash
# 参数 offload
actor_rollout_ref.actor.fsdp_config.param_offload=True
actor_rollout_ref.actor.fsdp_config.optimizer_offload=True
```

### 降低批次大小
```bash
data.train_batch_size=4
actor_rollout_ref.rollout.gpu_memory_utilization=0.3
```

### 必需参数（vLLM配置）
```bash
actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=1
```

## 算法配置
```bash
algorithm.adv_estimator=grpo  # GRPO算法
algorithm.norm_adv_by_std_in_grpo=True  # 按标准差归一化优势
```

## Rollout配置
```bash
actor_rollout_ref.rollout.name=vllm  # 使用vLLM
actor_rollout_ref.rollout.n=2  # 每个prompt生成2个response
actor_rollout_ref.rollout.tensor_model_parallel_size=1  # TP并行度
```

## 优化器配置
```bash
actor_rollout_ref.actor.optim.lr=3e-6  # 学习率
actor_rollout_ref.actor.optim.optimizer=AdamW
actor_rollout_ref.actor.grad_clip=1.0  # 梯度裁剪
```

## 日志配置
```bash
trainer.logger=["console"]  # 仅控制台输出
# trainer.logger=["tensorboard"]  # 或使用tensorboard
```
