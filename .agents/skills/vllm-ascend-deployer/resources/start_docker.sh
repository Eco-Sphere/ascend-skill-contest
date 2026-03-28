#!/bin/bash
# vLLM-Ascend Docker Container Startup Script
# Usage: ./start_docker.sh <container-name> <npu-id> <image-id> [port]

set -e

# Configuration
CONTAINER_NAME="${1:-vllm-model}"
NPU_ID="${2:-0}"
IMAGE_ID="${3:-quay.io/ascend/vllm-ascend:v0.17.0}"
PORT="${4:-8000}"

# NPU Device
NPU_DEVICE="/dev/davinci${NPU_ID}"

echo "=========================================="
echo "vLLM-Ascend Container Startup"
echo "=========================================="
echo "Container Name: ${CONTAINER_NAME}"
echo "NPU Device: ${NPU_DEVICE}"
echo "Image: ${IMAGE_ID}"
echo "Port: ${PORT}"
echo "=========================================="

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container ${CONTAINER_NAME} already exists. Removing..."
    docker stop ${CONTAINER_NAME} 2>/dev/null || true
    docker rm ${CONTAINER_NAME} 2>/dev/null || true
fi

# Check NPU device exists
if [ ! -e "${NPU_DEVICE}" ]; then
    echo "Warning: NPU device ${NPU_DEVICE} not found!"
    echo "Available NPU devices:"
    ls -la /dev/davinci* 2>/dev/null || echo "No davinci devices found"
fi

# Start container
echo "Starting container..."
docker run -itd --privileged \
    --name="${CONTAINER_NAME}" \
    --net=host \
    --shm-size=16g \
    --device ${NPU_DEVICE} \
    --device /dev/davinci_manager \
    --device /dev/devmm_svm \
    --device /dev/hisi_hdc \
    -v /usr/local/dcmi:/usr/local/dcmi \
    -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
    -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
    -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
    -v /etc/ascend_install.info:/etc/ascend_install.info \
    -v /root/.cache:/root/.cache \
    -v /home:/home \
    -v /data:/data \
    -v /tmp:/tmp \
    -e ASCEND_DEVICE_ID=${NPU_ID} \
    ${IMAGE_ID} /bin/bash

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Container started successfully!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Enter container: docker exec -it ${CONTAINER_NAME} bash"
    echo "2. Start vLLM: vllm serve <model-path> --host 0.0.0.0 --port ${PORT}"
    echo "3. Check logs: docker exec ${CONTAINER_NAME} cat /tmp/vllm.log"
    echo ""
else
    echo "Failed to start container!"
    exit 1
fi
