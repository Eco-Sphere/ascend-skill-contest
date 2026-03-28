#!/bin/bash
# verl 环境检查脚本

echo "=== 宿主机环境检查 ==="

echo ""
echo "1. NPU 设备:"
npu-smi info -l

echo ""
echo "2. Docker 版本:"
docker --version

echo ""
echo "3. verl 镜像:"
docker images | grep verl

echo ""
echo "4. 容器状态:"
docker ps -a | grep verl-npu

echo ""
echo "=== 容器内环境检查 ==="

if docker ps | grep -q verl-npu; then
    echo ""
    echo "5. 容器内 NPU:"
    docker exec verl-npu bash -lc "source /usr/local/Ascend/ascend-toolkit/set_env.sh && npu-smi info" | head -20
    
    echo ""
    echo "6. Python 版本:"
    docker exec verl-npu python -V
    
    echo ""
    echo "7. verl 包:"
    docker exec verl-npu pip show verl
    
    echo ""
    echo "8. 工作目录挂载:"
    docker exec verl-npu ls -la /home/zzw30069617/ 2>/dev/null | head -10
else
    echo "Container 'verl-npu' not running"
fi
