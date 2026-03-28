#!/bin/bash
# Qwen3-32B vLLM-Ascend 部署脚本

set -e

echo "========================================"
echo "Qwen3-32B vLLM-Ascend 部署脚本"
echo "========================================"

# 默认参数
MODEL_PATH="/data/models/Qwen3-32B"
SERVICE_PORT=8113
CONTAINER_NAME="vllm-ascend-qwen3"
VLLM_IMAGE="quay.io/ascend/vllm-aisbench:v0.17.0rc1"

# 解析命令行参数
while getopts "p:o:c:h" opt; do
  case $opt in
    p) MODEL_PATH="$OPTARG" ;;
    o) SERVICE_PORT="$OPTARG" ;;
    c) CONTAINER_NAME="$OPTARG" ;;
    h) echo "Usage: $0 [-p model_path] [-o service_port] [-c container_name]" && exit 0 ;;
    *) echo "Invalid option -$OPTARG" >&2 && exit 1 ;;
  esac
done

echo "\n部署参数："
echo "- 模型路径：$MODEL_PATH"
echo "- 服务端口：$SERVICE_PORT"
echo "- 容器名称：$CONTAINER_NAME"
echo "- vLLM镜像：$VLLM_IMAGE"

# 检查Docker环境
echo "\n1. 检查Docker环境..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker"
    exit 1
fi

echo "✅ Docker已安装"

# 检查NPU设备
echo "\n2. 检查NPU设备..."
if ! ls /dev/davinci* &> /dev/null; then
    echo "❌ 未检测到NPU设备，请检查NPU驱动安装"
    exit 1
fi

echo "✅ 检测到NPU设备"

# 创建模型存储目录
echo "\n3. 创建模型存储目录..."
mkdir -p "$MODEL_PATH"
echo "✅ 模型目录创建完成：$MODEL_PATH"

# 检查模型是否已存在
echo "\n4. 检查模型是否已存在..."
if [ -f "$MODEL_PATH/config.json" ]; then
    echo "✅ 模型已存在，跳过下载"
else
    echo "⏳ 正在下载Qwen3-32B模型..."
    # 这里使用modelscope下载Qwen3-32B模型
    if command -v python3 &> /dev/null; then
        pip3 install -q modelscope transformers
        python3 -c "
from modelscope import snapshot_download
snapshot_download('vllm-ascend/Qwen3-32B-W8A8', cache_dir='$MODEL_PATH', ignore_file_pattern=['*.bin', '*.pt', '*.pth'])
"
    else
        echo "❌ Python3未安装，无法自动下载模型"
        echo "请手动下载模型至 $MODEL_PATH"
        exit 1
    fi
    echo "✅ 模型下载完成"
fi

# 拉取vllm-ascend镜像
echo "\n5. 拉取vllm-ascend镜像..."
if ! docker images | grep -q "$VLLM_IMAGE"; then
    docker pull "$VLLM_IMAGE"
else
    echo "✅ 镜像已存在，跳过拉取"
fi

# 停止并删除已存在的容器
echo "\n6. 检查容器状态..."
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo "⚠️ 容器 $CONTAINER_NAME 已存在，正在停止并删除..."
    docker stop "$CONTAINER_NAME" || true
    docker rm "$CONTAINER_NAME" || true
fi

# 创建并启动容器
echo "\n7. 创建并启动容器..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart=unless-stopped \
    --network=host \
    --device=/dev/davinci0:/dev/davinci0 \
    --device=/dev/davinci1:/dev/davinci1 \
    --device=/dev/davinci2:/dev/davinci2 \
    --device=/dev/davinci3:/dev/davinci3 \
    --device=/dev/davinci_manager:/dev/davinci_manager \
    --device=/dev/devmm_svm:/dev/devmm_svm \
    --device=/dev/hisi_hdc:/dev/hisi_hdc \
    -v "$MODEL_PATH":/workspace/models/Qwen3-32B-W8A8 \
    -v /usr/local/dcmi:/usr/local/dcmi \
    -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
    -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
    -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
    -v /etc/ascend_install.info:/etc/ascend_install.info \
    -v /root/.cache:/root/.cache \
    -e ASCEND_RT_VISIBLE_DEVICES=0,1,2,3 \
    -e TASK_QUEUE_ENABLE=1 \
    -e HCCL_OP_EXPANSION_MODE="AIV" \
    -e VLLM_ASCEND_ENABLE_FLASHCOMM1=1 \
    -e VLLM_USE_MODELSCOPE=True \
    -e PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256 \
    "$VLLM_IMAGE" \
    bash -c "cd /workspace && vllm serve vllm-ascend/Qwen3-32B-W8A8 --served-model-name qwen3 --trust-remote-code --async-scheduling --quantization ascend --distributed-executor-backend mp --tensor-parallel-size 4 --max-model-len 5500 --max-num-batched-tokens 40960 --compilation-config '{\"cudagraph_mode\": \"FULL_DECODE_ONLY\"}' --additional-config '{\"pa_shape_list\":[48,64,72,80], \"weight_prefetch_config\":{\"enabled\":true}}' --port 8113 --block-size 128 --gpu-memory-utilization 0.9"

# 等待服务启动
echo "\n8. 等待服务启动..."
sleep 30

# 检查服务状态
echo "\n9. 检查服务状态..."
# 使用curl命令验证服务
echo "正在发送测试请求..."
curl_response=$(curl -s -X POST http://localhost:8113/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3", "messages": [{"role": "user", "content": "Give me a short introduction to large language models."}], "temperature": 0.6, "top_p": 0.95, "top_k": 20, "max_completion_tokens": 100}')

if echo "$curl_response" | grep -q "choices"; then
    echo "✅ vllm-ascend服务已成功启动并正常响应！"
    echo "   服务地址：http://localhost:8113"
    echo "   容器名称：$CONTAINER_NAME"
else
    echo "❌ 服务启动失败或响应异常，请检查容器日志："
    echo "   docker logs $CONTAINER_NAME"
    echo "   响应内容：$curl_response"
    exit 1
fi

echo "\n========================================"
echo "部署完成！"
echo "========================================"
