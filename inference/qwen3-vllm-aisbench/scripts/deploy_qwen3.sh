#!/bin/bash
# Qwen3-8B vLLM-Ascend 部署脚本

set -e

echo "========================================"
echo "Qwen3-8B vLLM-Ascend 部署脚本"
echo "========================================"

# 默认参数
MODEL_PATH="/data/models/Qwen3-8B"
SERVICE_PORT=8000
CONTAINER_NAME="vllm-ascend-qwen3"
VLLM_IMAGE="quay.io/ascend/vllm-ascend:v0.17.0rc1"

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
    echo "⏳ 正在下载Qwen3-8B模型..."
    # 这里使用modelscope下载Qwen3-8B模型
    if command -v python3 &> /dev/null; then
        pip3 install -q modelscope transformers
        python3 -c "
from modelscope import snapshot_download
snapshot_download('qwen/Qwen3-8B', cache_dir='$MODEL_PATH', ignore_file_pattern=['*.bin', '*.pt', '*.pth'])
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
    --device=/dev/davinci_manager:/dev/davinci_manager \
    --device=/dev/devmm_svm:/dev/devmm_svm \
    --device=/dev/hisi_hdc:/dev/hisi_hdc \
    -v "$MODEL_PATH":/workspace/models/Qwen3-8B \
    -e ASCEND_RT_VISIBLE_DEVICES=0 \
    "$VLLM_IMAGE" \
    python -m vllm.entrypoints.api_server \
        --model /workspace/models/Qwen3-8B \
        --host 0.0.0.0 \
        --port "$SERVICE_PORT" \
        --tensor-parallel-size 1 \
        --dtype float16

# 等待服务启动
echo "\n8. 等待服务启动..."
sleep 30

# 检查服务状态
echo "\n9. 检查服务状态..."
if curl -s http://localhost:"$SERVICE_PORT"/health | grep -q "healthy"; then
    echo "✅ vllm-ascend服务已成功启动！"
    echo "   服务地址：http://localhost:$SERVICE_PORT"
    echo "   容器名称：$CONTAINER_NAME"
else
    echo "❌ 服务启动失败，请检查容器日志："
    echo "   docker logs $CONTAINER_NAME"
    exit 1
fi

echo "\n========================================"
echo "部署完成！"
echo "========================================"
