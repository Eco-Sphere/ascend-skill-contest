#!/bin/bash
# sla_search.sh — 在 SLA 约束下二分搜索最优并发数
# 用法: bash sla_search.sh --sla-ttft 2000 --sla-tpot 50 [其他参数同 bench.sh]

set -e

HOST="localhost"; PORT="8000"; MODEL=""; DATASET="random"
DATASET_PATH=""; INPUT_LEN="512"; OUTPUT_LEN="128"
NUM_PROMPTS="200"; RESULT_DIR="./results"
SLA_TTFT=""; SLA_TPOT=""
MIN_C=1; MAX_C=128

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)         HOST="$2";         shift 2 ;;
    --port)         PORT="$2";         shift 2 ;;
    --model)        MODEL="$2";        shift 2 ;;
    --dataset)      DATASET="$2";      shift 2 ;;
    --dataset-path) DATASET_PATH="$2"; shift 2 ;;
    --input-len)    INPUT_LEN="$2";    shift 2 ;;
    --output-len)   OUTPUT_LEN="$2";   shift 2 ;;
    --num-prompts)  NUM_PROMPTS="$2";  shift 2 ;;
    --sla-ttft)     SLA_TTFT="$2";     shift 2 ;;
    --sla-tpot)     SLA_TPOT="$2";     shift 2 ;;
    --max-concurrency) MAX_C="$2";     shift 2 ;;
    --result-dir)   RESULT_DIR="$2";   shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# 自动获取 model 名
if [ -z "$MODEL" ]; then
  MODEL=$(curl -s "http://${HOST}:${PORT}/v1/models" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null)
  [ -z "$MODEL" ] && { echo "❌ 无法获取模型名，请确认服务已启动"; exit 1; }
  echo "✅ 自动检测到模型：$MODEL"
fi

mkdir -p "$RESULT_DIR"

# 检查单次测试是否满足 SLA
check_sla() {
  local c=$1
  local extra_args="--random-input-len $INPUT_LEN --random-output-len $OUTPUT_LEN"
  [ -n "$DATASET_PATH" ] && extra_args="--dataset-path $DATASET_PATH"

  vllm bench serve \
    --backend vllm --host $HOST --port $PORT \
    --model "$MODEL" --endpoint /v1/completions \
    --dataset-name $DATASET $extra_args \
    --num-prompts $NUM_PROMPTS \
    --max-concurrency $c \
    --request-rate inf \
    --save-result --result-dir "$RESULT_DIR" \
    --result-filename "sla_c${c}.json" \
    2>/dev/null

  python3 - <<PYEOF
import json, sys
try:
    with open("${RESULT_DIR}/sla_c${c}.json") as f:
        d = json.load(f)
    ttft = d.get("mean_ttft_ms", 9999)
    tpot = d.get("mean_tpot_ms", 9999)
    tput = d.get("output_throughput", 0)
    ttft_ok = (not "${SLA_TTFT}" or ttft <= float("${SLA_TTFT}" or 9999))
    tpot_ok = (not "${SLA_TPOT}" or tpot <= float("${SLA_TPOT}" or 9999))
    print(f"  并发={${c}} TTFT={ttft:.0f}ms TPOT={tpot:.0f}ms 吞吐={tput:.1f}tok/s {'✅' if ttft_ok and tpot_ok else '❌'}")
    sys.exit(0 if ttft_ok and tpot_ok else 1)
except Exception as e:
    print(f"  ⚠️  解析结果失败: {e}")
    sys.exit(1)
PYEOF
}

echo ""
echo "🔍 开始 SLA 寻优（TTFT<${SLA_TTFT}ms TPOT<${SLA_TPOT}ms）"
echo "   搜索范围：并发 ${MIN_C} ~ ${MAX_C}"
echo ""

BEST_C=0
BEST_TPUT=0
LO=$MIN_C; HI=$MAX_C

# 先验证并发=1 的基线
echo "▶ 基线测试（并发=1）..."
if check_sla 1; then
  BEST_C=1
  BEST_TPUT=$(python3 -c "
import json
with open('${RESULT_DIR}/sla_c1.json') as f: d=json.load(f)
print(f\"{d.get('output_throughput',0):.1f}\")" 2>/dev/null || echo "0")
else
  echo "❌ 并发=1 时已超出 SLA，当前服务无法满足此约束。"
  echo "建议：放宽 SLA 要求，或检查服务配置。"
  exit 1
fi

# 二分搜索
while [ $LO -le $HI ]; do
  MID=$(( (LO + HI) / 2 ))
  [ $MID -le 1 ] && { LO=2; continue; }
  echo "▶ 测试并发=${MID}..."
  if check_sla $MID; then
    BEST_C=$MID
    BEST_TPUT=$(python3 -c "
import json
with open('${RESULT_DIR}/sla_c${MID}.json') as f: d=json.load(f)
print(f\"{d.get('output_throughput',0):.1f}\")" 2>/dev/null || echo "0")
    LO=$(( MID + 1 ))
  else
    HI=$(( MID - 1 ))
  fi
done

echo ""
echo "══════════════════════════════════════"
echo "🏆 寻优结果"
echo "   最优并发数：${BEST_C}"
echo "   最优吞吐  ：${BEST_TPUT} tok/s"
echo "   SLA 约束  ：TTFT<${SLA_TTFT}ms  TPOT<${SLA_TPOT}ms"
echo "══════════════════════════════════════"
echo "BEST_CONCURRENCY=${BEST_C}" >> "${RESULT_DIR}/sla_result.env"
echo "BEST_THROUGHPUT=${BEST_TPUT}" >> "${RESULT_DIR}/sla_result.env"
