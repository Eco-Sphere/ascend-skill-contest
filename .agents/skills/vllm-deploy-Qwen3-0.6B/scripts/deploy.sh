#!/bin/bash
# vLLM Ascend 一键部署脚本 — Qwen3-0.6B
# 用法: bash deploy.sh [模型名称] [端口]
# 示例: bash deploy.sh Qwen/Qwen3-0.6B 8000

set -e

MODEL=${1:-"Qwen/Qwen3-0.6B"}
PORT=${2:-8000}
CONTAINER_NAME="vllm-ascend"

echo "======================================"
echo " vLLM Ascend 部署脚本"
echo " 模型: $MODEL"
echo " 端口: $PORT"
echo "======================================"

# ── Step 1: 检查 Docker ──────────────────
if ! command -v docker &>/dev/null; then
  echo "❌ 错误：未找到 Docker，请先安装 Docker 后重试。"
  exit 1
fi

# ── Step 2: 清理同名容器 ─────────────────
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "⚠️  检测到同名容器，正在清理..."
  docker rm -f "$CONTAINER_NAME"
fi

# ── Step 3: 探测硬件型号，选择镜像 ───────
echo "🔍 探测昇腾硬件型号..."
NPU_INFO=$(npu-smi info 2>/dev/null | head -5 || echo "")

if echo "$NPU_INFO" | grep -qiE "910B|800T A2"; then
  IMAGE_TAG="v0.17.0rc1"
  echo "✅ 检测到 Atlas A2，使用镜像 tag: $IMAGE_TAG"
elif echo "$NPU_INFO" | grep -qiE "910C|800T A3"; then
  IMAGE_TAG="v0.17.0rc1-a3"
  echo "✅ 检测到 Atlas A3，使用镜像 tag: $IMAGE_TAG"
elif echo "$NPU_INFO" | grep -qiE "310P"; then
  IMAGE_TAG="v0.17.0rc1-310p"
  echo "✅ 检测到 Atlas 300I (310P)，使用镜像 tag: $IMAGE_TAG"
else
  echo "⚠️  无法自动识别硬件型号（npu-smi 输出如下）："
  echo "$NPU_INFO"
  echo ""
  read -p "请输入硬件类型 [A2/A3/310P，默认 A2]: " HW_TYPE
  HW_TYPE=${HW_TYPE:-A2}
  case "${HW_TYPE^^}" in
    A2)  IMAGE_TAG="v0.17.0rc1" ;;
    A3)  IMAGE_TAG="v0.17.0rc1-a3" ;;
    310P) IMAGE_TAG="v0.17.0rc1-310p" ;;
    *)   echo "❌ 未知型号，退出。"; exit 1 ;;
  esac
fi

IMAGE="quay.io/ascend/vllm-ascend:${IMAGE_TAG}"

# ── Step 4: 拉取镜像（失败自动切换源）────
echo "📦 拉取镜像: $IMAGE"
if ! docker pull "$IMAGE" 2>/dev/null; then
  echo "⚠️  主源拉取失败，切换至国内镜像源..."
  MIRROR_IMAGE="m.daocloud.io/${IMAGE}"
  if ! docker pull "$MIRROR_IMAGE"; then
    MIRROR_IMAGE="quay.nju.edu.cn/ascend/vllm-ascend:${IMAGE_TAG}"
    docker pull "$MIRROR_IMAGE" || { echo "❌ 镜像拉取失败，请检查网络。"; exit 1; }
  fi
  IMAGE="$MIRROR_IMAGE"
fi

# ── Step 5: 探测可用 NPU 设备 ────────────
DEVICES=""
for i in $(seq 0 15); do
  [ -e "/dev/davinci${i}" ] && DEVICES="$DEVICES --device /dev/davinci${i}"
done

if [ -z "$DEVICES" ]; then
  echo "❌ 未找到任何 /dev/davinciX 设备，请确认 NPU 驱动已安装。"
  exit 1
fi

echo "✅ 找到 NPU 设备: $(echo $DEVICES | tr ' ' '\n' | grep davinci[0-9] | tr '\n' ' ')"

# ── Step 6: 启动容器 ──────────────────────
echo "🚀 启动 vLLM 服务..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --shm-size=1g \
  $DEVICES \
  --device /dev/davinci_manager \
  --device /dev/devmm_svm \
  --device /dev/hisi_hdc \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
  -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  -v /root/.cache:/root/.cache \
  -p "${PORT}:8000" \
  "$IMAGE" \
  bash -c "export VLLM_USE_MODELSCOPE=true && vllm serve ${MODEL} --max-model-len 32768"

# ── Step 7: 等待服务就绪 ──────────────────
echo "⏳ 等待服务启动（最长 5 分钟，模型首次使用需下载）..."
for i in $(seq 1 60); do
  if docker logs "$CONTAINER_NAME" 2>&1 | grep -q "Application startup complete"; then
    echo ""
    echo "✅ 服务已就绪！"
    break
  fi
  printf "."
  sleep 5
  if [ $i -eq 60 ]; then
    echo ""
    echo "⚠️  超时，服务可能仍在下载模型，请运行以下命令查看进度："
    echo "   docker logs -f $CONTAINER_NAME"
    exit 0
  fi
done

# ── Step 8: 验证推理 ──────────────────────
echo ""
echo "🧪 验证推理..."
RESPONSE=$(curl -s http://localhost:${PORT}/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [{\"role\": \"user\", \"content\": \"你好！\"}],
    \"max_tokens\": 50,
    \"temperature\": 0.7
  }")

if echo "$RESPONSE" | grep -q "content"; then
  echo "✅ 推理验证通过！"
  echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
else
  echo "⚠️  推理返回异常，原始响应："
  echo "$RESPONSE"
fi

echo ""
echo "======================================"
echo "🎉 部署完成"
echo "   API 地址: http://localhost:${PORT}/v1"
echo "   停止服务: docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
echo "   查看日志: docker logs -f $CONTAINER_NAME"
echo "======================================"
