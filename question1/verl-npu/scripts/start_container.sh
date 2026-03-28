#!/bin/bash
# verl 容器启动脚本
# 参数: $1=NPU卡数 (默认8)

NPU_COUNT=${1:-8}

# 生成 device 参数
DEVICES="--device /dev/davinci_manager --device /dev/devmm_svm --device /dev/hisi_hdc"
for i in $(seq 0 $((NPU_COUNT-1))); do
    DEVICES="$DEVICES --device /dev/davinci$i"
done

# 检查容器是否已存在，若存在则跳过
if docker ps -a | grep -q verl-npu; then
    if docker ps | grep -q verl-npu; then
        echo "Container 'verl-npu' is already running"
    else
        echo "Container 'verl-npu' exists but stopped, starting it..."
        docker start verl-npu
    fi
    echo "Skipping container creation"
else
    docker run -d --name verl-npu --network host --ipc=host --privileged \
        $DEVICES \
        -v /home:/home \
        -v /usr/local/Ascend/driver:/usr/local/Ascend/driver:ro \
        -v /usr/local/Ascend/add-ons:/usr/local/Ascend/add-ons:ro \
        -v /usr/local/sbin:/usr/local/sbin:ro \
        quay.io/ascend/verl:verl-8.3.rc1-910b-ubuntu22.04-py3.11-latest \
        sleep infinity
    echo "Container 'verl-npu' started with $NPU_COUNT NPU(s)"
fi
