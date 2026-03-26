# 单机多卡与多机多卡配置

## 单机多卡配置

### 双卡示例

```bash
export ASCEND_RT_VISIBLE_DEVICES=0,1
export HCCL_IF_BASE_PORT=43432

NNODES=2
START_DEVICE=0
START_PORT=18000

for (( i=0; i<NNODES; i++ )); do
  PORT=$((START_PORT + i))
  DEVICE=$((START_DEVICE + i))
  LOG_FILE="$LOG_DIR/node_$i.log"

  "$XLLM_BIN" \
    --model "$MODEL_PATH" \
    --devices="npu:$DEVICE" \
    --port "$PORT" \
    --master_node_addr="127.0.0.1:9748" \
    --nnodes="$NNODES" \
    --node_rank="$i" \
    --max_memory_utilization=0.86 \
    --block_size=128 \
    --communication_backend="hccl" \
    --enable_chunked_prefill=true \
    --enable_schedule_overlap=true \
    --enable_shm=true > "$LOG_FILE" 2>&1 &
done
```

### 四卡示例

```bash
export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3
NNODES=4
START_DEVICE=0
```

### 关键环境变量

| 环境变量 | 说明 | 示例 |
|----------|------|------|
| `ASCEND_RT_VISIBLE_DEVICES` | 可见 NPU 设备 | `0,1,2,3` |
| `HCCL_IF_BASE_PORT` | HCCL 通信基础端口 | `43432` |

---

## 多机多卡配置

### 双机双卡示例

**机器 1（主节点）：**
```bash
export ASCEND_RT_VISIBLE_DEVICES=0,1
MASTER_NODE_ADDR="10.18.1.1:9748"  # 机器1的IP

NNODES=2
for (( i=0; i<NNODES; i++ )); do
  PORT=$((18000 + i))
  DEVICE=$i
  "$XLLM_BIN" \
    --model "$MODEL_PATH" \
    --devices="npu:$DEVICE" \
    --port "$PORT" \
    --master_node_addr="$MASTER_NODE_ADDR" \
    --nnodes="$NNODES" \
    --node_rank="$i" \
    ... > "log/node_$i.log" 2>&1 &
done
```

**机器 2（从节点）：**
```bash
export ASCEND_RT_VISIBLE_DEVICES=0,1
MASTER_NODE_ADDR="10.18.1.1:9748"  # 指向机器1

NNODES=2
for (( i=0; i<NNODES; i++ )); do
  PORT=$((18000 + i))
  DEVICE=$i
  "$XLLM_BIN" \
    --model "$MODEL_PATH" \
    --devices="npu:$DEVICE" \
    --port "$PORT" \
    --master_node_addr="$MASTER_NODE_ADDR" \
    --nnodes="$NNODES" \
    --node_rank="$i" \
    ... > "log/node_$i.log" 2>&1 &
done
```

### 多机配置要点

| 要点 | 说明 |
|------|------|
| 网络互通 | 各节点间需能通过 IP 访问 |
| MASTER_NODE_ADDR | 统一指向主节点 IP |
| node_rank | 全局唯一，不能重复 |
| HCCL 配置 | 确保 HCCL 正确识别所有节点 |

### 多机 HCCL 排查

```bash
# 检查 HCCL 通信
export HCCL_DEBUG=1
# 查看日志中的 HCCL 相关输出
```
