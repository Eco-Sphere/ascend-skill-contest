#!/bin/bash
# bench.sh — 单次 vLLM benchmark 运行封装
# 用法: bash bench.sh --host <host> --port <port> --model <model> [options]

set -e

HOST="localhost"
PORT="8000"
MODEL=""
DATASET="random"
DATASET_PATH=""
INPUT_LEN="512"
OUTPUT_LEN="128"
NUM_PROMPTS="200"
CONCURRENCY="16"
RESULT_DIR="./results"
ENDPOINT="/v1/completions"
BACKEND="vllm"

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)           HOST="$2";         shift 2 ;;
    --port)           PORT="$2";         shift 2 ;;
    --model)          MODEL="$2";        shift 2 ;;
    --dataset)        DATASET="$2";      shift 2 ;;
    --dataset-path)   DATASET_PATH="$2"; shift 2 ;;
    --input-len)      INPUT_LEN="$2";    shift 2 ;;
    --output-len)     OUTPUT_LEN="$2";   shift 2 ;;
    --num-prompts)    NUM_PROMPTS="$2";  shift 2 ;;
    --concurrency)    CONCURRENCY="$2";  shift 2 ;;
    --result-dir)     RESULT_DIR="$2";   shift 2 ;;
    --endpoint)       ENDPOINT="$2";     shift 2 ;;
    --multimodal)     ENDPOINT="/v1/chat/completions"; BACKEND="openai-chat"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# 自动获取 model 名
if [ -z "$MODEL" ]; then
  MODEL=$(curl -s "http://${HOST}:${PORT}/v1/models" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null)
  if [ -z "$MODEL" ]; then
    echo "❌ 无法获取模型名，请确认服务已启动：http://${HOST}:${PORT}"
    exit 1
  fi
  echo "✅ 自动检测到模型：$MODEL"
fi

mkdir -p "$RESULT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="${RESULT_DIR}/bench_c${CONCURRENCY}_${TIMESTAMP}.json"

echo "🚀 开始测试：并发=${CONCURRENCY} 输入=${INPUT_LEN} 输出=${OUTPUT_LEN}"

# 构建命令
CMD="vllm bench serve \
  --backend $BACKEND \
  --host $HOST \
  --port $PORT \
  --model $MODEL \
  --endpoint $ENDPOINT \
  --dataset-name $DATASET \
  --num-prompts $NUM_PROMPTS \
  --max-concurrency $CONCURRENCY \
  --request-rate inf \
  --save-result \
  --result-dir $RESULT_DIR"

# 追加数据集路径（非 random 时）
[ -n "$DATASET_PATH" ] && CMD="$CMD --dataset-path $DATASET_PATH"

# 追加 random 长度（random 数据集时）
if [ "$DATASET" = "random" ]; then
  CMD="$CMD --random-input-len $INPUT_LEN --random-output-len $OUTPUT_LEN"
fi

eval $CMD

# 从最新 JSON 提取关键指标
LATEST_JSON=$(ls -t ${RESULT_DIR}/*.json 2>/dev/null | head -1)
if [ -n "$LATEST_JSON" ]; then
  python3 -c "
import json
with open('$LATEST_JSON') as f:
    d = json.load(f)
print(f'  吞吐(tok/s):    {d.get(\"output_throughput\", \"N/A\"):.1f}')
print(f'  Mean TTFT(ms):  {d.get(\"mean_ttft_ms\", \"N/A\"):.1f}')
print(f'  P99  TTFT(ms):  {d.get(\"p99_ttft_ms\", \"N/A\"):.1f}')
print(f'  Mean TPOT(ms):  {d.get(\"mean_tpot_ms\", \"N/A\"):.1f}')
print(f'  P99  TPOT(ms):  {d.get(\"p99_tpot_ms\", \"N/A\"):.1f}')
" 2>/dev/null || true
fi
