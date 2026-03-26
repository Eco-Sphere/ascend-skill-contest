---
name: deploy-xllm-npu
description: 在本项目中指导在 NPU 环境下部署与启动 xLLM 推理服务，包含 NPU Docker 镜像拉取、容器启动、xLLM 编译和以 Qwen3 为例的启动脚本。当用户在本项目中提到在 NPU 上部署、安装、启动或重启 xLLM 服务时使用。
---

# 在 NPU 上部署与启动 xLLM

## 使用场景

在本仓库中，当用户需要在 **NPU（A2/A3 等）** 环境部署或启动 xLLM 时，使用本 Skill：

- 拉取并启动 NPU 开发镜像
- 在容器内编译 xLLM（非 release 镜像）
- 以 Qwen3 为例启动 xLLM 服务（单机单卡 / 单机多卡）

详细参数说明和性能调优建议见 [references/](references/) 目录。

---

## 一、NPU 环境 Docker 准备

### 1. 拉取 NPU 开发镜像

```bash
# A2 x86/arm 或 A3 arm
docker pull quay.io/jd_xllm/xllm-ai:xllm-dev-a3-arm-20260306
```

### 2. 启动 NPU 开发容器

```bash
docker run -it \
  --ipc=host -u 0 --name xllm-npu \
  --privileged --network=host \
  --device=/dev/davinci0 --device=/dev/davinci_manager \
  --device=/dev/devmm_svm --device=/dev/hisi_hdc \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
  -v /usr/local/Ascend/add-ons/:/usr/local/Ascend/add-ons/ \
  -v /usr/local/sbin/npu-smi:/usr/local/sbin/npu-smi \
  -v /usr/local/sbin/:/usr/local/sbin/ \
  -v /var/log/npu/conf/slog/slog.conf:/var/log/npu/conf/slog/slog.conf \
  -v /var/log/npu/slog/:/var/log/npu/slog \
  -v /var/log/npu/profiling/:/var/log/npu/profiling \
  -v /var/log/npu/dump/:/var/log/npu/dump \
  -v /export/home/weinan5/xyx/xllm:/root/xllm \
  -v /export/home/models:/models \
  -w /root/xllm \
  quay.io/jd_xllm/xllm-ai:xllm-dev-a3-arm-20260306 \
  /bin/bash
```

**注意事项：**
- 同名容器冲突时使用 `--name xllm-npu-new`
- 建议将 xllm 源码和模型目录挂载到容器内

---

## 二、容器内编译 xLLM

> **release 镜像**（tag 带版本号）可跳过，镜像已含 `/usr/local/bin/xllm`

### 1. 初始化子模块

```bash
cd /root/xllm
git config --global --add safe.directory /root/xllm
git submodule update --init -f
```

### 2. 编译（A3 必加 `--device a3`）

```bash
# 第一次编译需20-50分钟
export http_proxy=http://bamboo-proxy.jd.com:80
export https_proxy=http://bamboo-proxy.jd.com:80
python3 setup.py build --device a3
```

**编译产物：** `/root/xllm/build/xllm/core/server/xllm`

---

## 三、启动 xLLM 服务（Qwen3-0.6B）

### 1. 创建启动脚本

在容器内创建 `/root/run_xllm.sh`：

```bash
#!/bin/bash
set -e
rm -rf core.*

source /usr/local/Ascend/ascend-toolkit/set_env.sh
source /usr/local/Ascend/nnal/atb/set_env.sh

export ASCEND_RT_VISIBLE_DEVICES=0
export HCCL_IF_BASE_PORT=43432

MODEL_PATH="/models/Qwen3-0.6B"
MASTER_NODE_ADDR="127.0.0.1:9748"
START_PORT=18000
NNODES=1
XLLM_BIN="/root/xllm/build/xllm/core/server/xllm"
LOG_DIR="log"

mkdir -p $LOG_DIR

for (( i=0; i<NNODES; i++ )); do
  "$XLLM_BIN" \
    --model "$MODEL_PATH" \
    --devices="npu:$i" \
    --port $((START_PORT + i)) \
    --master_node_addr="$MASTER_NODE_ADDR" \
    --nnodes=$NNODES --node_rank=$i \
    --max_memory_utilization=0.86 --block_size=128 \
    --communication_backend=hccl \
    --enable_chunked_prefill=true \
    --enable_schedule_overlap=true \
    --enable_shm=true > "$LOG_DIR/node_$i.log" 2>&1 &
done
echo "xLLM started, logs in $LOG_DIR/"
```

### 2. 启动并验证

```bash
bash /root/run_xllm.sh
sleep 10
ps aux | grep xllm | grep -v grep
cat /root/xllm/log/node_0.log | tail -5
```

**成功标志：** 看到 `Server[xllm::APIService] is serving on port=18000`

### 3. 测试服务（curl）

```bash
curl -s -X POST http://127.0.0.1:18000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen3-0.6B","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}'
```

**收到模型回复=部署成功！**

---

## 四、答复流程

1. **确认环境**：NPU驱动、镜像tag、**代理配置**
2. **启动容器**：用上述 docker run 命令
3. **编译**：`--device a3` + 代理
4. **启动**：提供脚本或直接命令
5. **验证**：curl 测试

---

## 五、references 目录说明

| 文件 | 内容 |
|------|------|
| `references/parameters.md` | xLLM 启动参数详解 |
| `references/tuning.md` | 性能调优建议 |
| `references/multi_card.md` | 单机/多机多卡配置 |
| `references/troubleshooting.md` | 常见问题排查 |
