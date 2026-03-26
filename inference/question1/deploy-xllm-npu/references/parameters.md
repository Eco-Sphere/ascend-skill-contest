# xLLM 启动参数详解

## A.1 基础参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--model` | 模型权重目录路径（**必填**） | `/models/Qwen3-0.6B` |
| `--devices` | 推理设备 | `npu:0` 或 `npu:0,npu:1`（多卡） |
| `--port` | HTTP 服务端口 | `18000` |
| `--master_node_addr` | 主节点地址（多机必填） | `127.0.0.1:9748` |
| `--nnodes` | 节点数（进程数） | `1`（单机）、`4`（4卡） |
| `--node_rank` | 当前节点编号 | `0`, `1`, `2`, `3` |

## A.2 KV Cache 参数（内存调优关键）

| 参数 | 说明 | 默认值 | 调优建议 |
|------|------|--------|----------|
| `--block_size` | 每个 KV cache block 的 token 数 | `128` | A3 建议 `128`，GPU 建议 `32` |
| `--max_memory_utilization` | 用于推理的内存比例（含模型权重和 KV cache） | `0.86` | 显存充足可设 `0.9`，紧张可设 `0.8` |
| `--max_cache_size` | KV cache 最大内存（字节），0=自动计算 | `0` | 通常不需要设置 |
| `--kv_cache_dtype` | KV cache 数据类型 | `auto` | `auto` 或 `int8`（仅 MLU 支持） |

**内存计算公式：**
```
KV Cache 容量 = 总内存 × max_memory_utilization - 模型权重占用
```

## A.3 Prefill 调度参数

| 参数 | 说明 | 默认值 | 调优建议 |
|------|------|--------|----------|
| `--enable_chunked_prefill` | 启用分块 prefill，将长序列分割处理 | `true` | **NPU 建议开启**，减少显存峰值 |
| `--enable_prefix_cache` | 启用前缀缓存，相同前缀的请求复用 KV | `false` | 对多轮对话场景提升明显 |
| `--max_tokens_per_batch` | 每批最大 token 数 | `10240` | 可根据并发需求调整 |
| `--max_seqs_per_batch` | 每批最大序列数 | `1024` | 可根据并发需求调整 |

## A.4 调度优化参数

| 参数 | 说明 | 默认值 | 调优建议 |
|------|------|--------|----------|
| `--enable_schedule_overlap` | 启用调度重叠，prefill 和 decode 并行 | `true` | **建议开启**，提升吞吐 |
| `--enable_shm` | 启用共享内存用于模型执行 | `true` | **NPU 建议开启**，减少数据传输 |
| `--enable_prefill_sp` | 启用 prefill 序列并行 | `false` | 仅多卡场景可能需要 |

## A.5 通信参数（NPU 多卡/多机）

| 参数 | 说明 | 示例值 |
|------|------|--------|
| `--communication_backend` | 通信后端 | `hccl`（NPU）、`nccl`（GPU） |
| `--HCCL_IF_BASE_PORT` | HCCL 通信基础端口 | `43432` |
| `--ASCEND_RT_VISIBLE_DEVICES` | 可见 NPU 设备 | `0` 或 `0,1,2,3` |

## A.6 Graph 执行参数（性能调优高级选项）

| 参数 | 说明 | 适用场景 |
|------|------|----------|
| `--enable_graph` | 启用图执行模式（CUDA/NPU/MLU Graph） | **decode 阶段优化**，减少 kernel launch 开销 |
| `--enable_graph_mode_decode_no_padding` | 图执行不 padding | 配合 `--enable_graph` 使用 |
| `--enable_prefill_piecewise_graph` | prefill 阶段使用分段图 | 长序列 prefill 优化 |
| `--max_tokens_for_graph_mode` | 图执行的最大 token 数，0=无限制 | 可限制大 token 使用图模式 |

## A.7 分布式推理参数

| 参数 | 说明 | 使用场景 |
|------|------|----------|
| `--dp_size` | 数据并行 size（MLA attention） | MoE 模型多卡 |
| `--ep_size` | 专家并行 size | MoE 模型多卡 |
| `--expert_parallel_degree` | 专家并行度数 | MoE 模型多卡 |

## A.8 服务质量参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--max_concurrent_requests` | 最大并发请求数，0=无限制 | `0` |
| `--num_request_handling_threads` | 请求处理线程数 | `4` |
| `--num_response_handling_threads` | 响应处理线程数 | 默认继承系统 |
