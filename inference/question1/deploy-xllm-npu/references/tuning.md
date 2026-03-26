# 性能调优建议

## D.1 NPU A3 环境推荐配置

```bash
--max_memory_utilization=0.86    # 留内存给系统
--block_size=128                 # NPU 推荐 128
--enable_chunked_prefill=true    # 必开，减少显存峰值
--enable_schedule_overlap=true    # 必开，提升吞吐
--enable_shm=true                # 必开，减少数据传输
--enable_graph=true              # 可选，decode 优化
```

## D.2 不同场景调优

| 场景 | 推荐配置 |
|------|----------|
| **高并发短请求** | 增大 `max_concurrent_requests`，开启 `enable_prefix_cache` |
| **长序列请求** | 开启 `enable_chunked_prefill=true` |
| **低延迟需求** | 关闭 `enable_schedule_overlap`，减小 `block_size` |
| **高吞吐需求** | 开启 `enable_schedule_overlap`，增大 `max_tokens_per_batch` |
| **多轮对话** | 开启 `enable_prefix_cache=true` |

## D.3 显存/内存不足时

1. 降低 `max_memory_utilization`：从 `0.86` 降到 `0.8` 或 `0.75`
2. 减小 `block_size`：从 `128` 降到 `64`
3. 关闭 `enable_shm`：牺牲性能换内存

## D.4 性能瓶颈排查

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| GPU/NPU 利用率低 | `enable_schedule_overlap` 未开启 | 开启该选项 |
| 首 Token 延迟高 | `enable_chunked_prefill` 未开启 | 开启该选项 |
| 吞吐低 | `max_tokens_per_batch` 过小 | 增大该值 |
| 显存溢出 | `max_memory_utilization` 过高 | 降低该值 |

## D.5 各场景参数调整建议

### 高并发场景
```bash
--max_concurrent_requests=1000
--enable_prefix_cache=true
--max_tokens_per_batch=2048
--max_seqs_per_batch=2048
```

### 长序列场景
```bash
--enable_chunked_prefill=true
--max_tokens_for_graph_mode=0
--enable_prefill_piecewise_graph=true
```

### 低延迟场景
```bash
--enable_schedule_overlap=false
--block_size=64
--enable_prefix_cache=false
```
