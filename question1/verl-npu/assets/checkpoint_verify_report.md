# verl GRPO 训练验证报告

## 实验信息

| 项目 | 内容 |
|------|------|
| 实验名称 | verl_grpo_demo |
| 模型 | Qwen3-0.6B |
| 数据集 | gsm8k |
| 算法 | GRPO |
| 设备 | NPU |

## 训练配置

```
actor_rollout_ref.model.path: {model_path}
data.train_files: {train_data}
data.val_files: {val_data}
data.train_batch_size: {batch_size}
actor_rollout_ref.rollout.n: {rollout_n}
actor_rollout_ref.rollout.gpu_memory_utilization: {gpu_mem}
trainer.n_gpus_per_node: {n_gpus}
trainer.total_training_steps: {total_steps}
```

## Checkpoint 验证结果

### 第一次训练
- 训练步数: 20
- 保存频率: 10
- Checkpoint路径: {checkpoint_dir}/verify1/global_step_20

### 第二次加载训练
- 起始步数: 20
- 继续训练步数: 5
- 总步数: 25
- Checkpoint路径: {checkpoint_dir}/verify2

### 验证结果
- [ ] 第一次训练成功保存checkpoint
- [ ] 第二次成功加载checkpoint
- [ ] 第二次能继续训练并生成新的checkpoint
- [ ] 训练过程无报错

## 日志文件

- 第一次训练日志: {work_dir}/verify1_log.txt
- 第二次训练日志: {work_dir}/verify2_log.txt

## 结论

- [ ] 验证通过
- [ ] 验证失败

---
验证时间: {timestamp}
