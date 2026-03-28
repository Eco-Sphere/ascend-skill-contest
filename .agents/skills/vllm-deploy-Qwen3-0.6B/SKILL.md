---
name: vllm-ascend
description: Use this skill to deploy LLM inference service using vLLM on Huawei Ascend NPU. Triggers on any request like "用vllm部署模型", "vllm ascend部署", "deploy model with vllm on NPU/昇腾". Default model is Qwen/Qwen3-0.6B unless user specifies otherwise.
license: Apache 2.0
---

# vLLM Ascend 部署指南

## 工作流程

收到部署请求后，按以下步骤执行：

**Step 1 — 收集必要信息（缺什么问什么）**

| 信息 | 默认值 | 如何获取 |
|------|--------|----------|
| 模型名称 | `Qwen/Qwen3-0.6B` | 用户未指定时使用默认值 |
| 硬件型号 | 自动探测 | 运行 `npu-smi info` 读取第一行输出 |
| 端口 | `8000` | 自动使用，无需询问 |
| 容器名 | `vllm-ascend` | 自动使用，无需询问 |
| 模型来源 | ModelScope（国内）| 自动使用，无需询问 |

> 若用户只说"部署Qwen3-0.6B"，无需任何追问，直接从 Step 2 开始执行。

---

**Step 2 — 自动探测硬件，选择镜像**

```bash
npu-smi info | head -5
```

根据输出结果判断：

| 输出关键字 | 硬件 | 镜像 Tag |
|-----------|------|---------|
| `910B` / `Atlas 800T A2` | Atlas A2 | `v0.17.0rc1` |
| `910C` / `Atlas 800T A3` | Atlas A3 | `v0.17.0rc1-a3` |
| `310P` | Atlas 300I | `v0.17.0rc1-310p` |
| 无法识别 | ❓ | **询问用户**："您的昇腾硬件型号是 A2、A3 还是 310P？" |

---

**Step 3 — 启动容器**

执行 `scripts/deploy.sh`，或直接运行以下命令（以 A2 单卡为例，`IMAGE_TAG` 按 Step 2 替换）：

```bash
export MODEL=${MODEL:-Qwen/Qwen3-0.6B}
export IMAGE=quay.io/ascend/vllm-ascend:v0.17.0rc1   # 按硬件替换 tag
export PORT=${PORT:-8000}

docker run -d \
  --name vllm-ascend \
  --shm-size=1g \
  --device /dev/davinci0 \
  --device /dev/davinci_manager \
  --device /dev/devmm_svm \
  --device /dev/hisi_hdc \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
  -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  -v /root/.cache:/root/.cache \
  -p ${PORT}:8000 \
  $IMAGE \
  bash -c "export VLLM_USE_MODELSCOPE=true && vllm serve ${MODEL} --max-model-len 32768"
```

> **国内网络**：镜像拉取失败时自动切换镜像源：
> ```bash
> docker pull m.daocloud.io/quay.io/ascend/vllm-ascend:v0.17.0rc1
> # 或
> docker pull quay.nju.edu.cn/ascend/vllm-ascend:v0.17.0rc1
> ```

---

**Step 4 — 等待服务就绪并验证**

```bash
# 等待服务启动（最多 5 分钟）
echo "等待服务启动..."
for i in $(seq 1 60); do
  if docker logs vllm-ascend 2>&1 | grep -q "Application startup complete"; then
    echo "✅ 服务已就绪"
    break
  fi
  sleep 5
done

# 验证推理
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-0.6B",
    "messages": [{"role": "user", "content": "你好，请介绍一下你自己。"}],
    "max_tokens": 100,
    "temperature": 0.7
  }' | python3 -m json.tool
```

成功响应示例：
```json
{
  "choices": [{
    "message": {"role": "assistant", "content": "你好！我是通义千问..."}
  }]
}
```

---

## 错误处理

| 错误现象 | 原因 | 解决方法 |
|----------|------|----------|
| `docker: command not found` | Docker 未安装 | 询问用户："请先安装 Docker，或您是否想使用 pip 方式部署？" |
| `docker: Error response... device not found` | NPU 设备号不存在 | 运行 `ls /dev/davinci*` 查看实际设备号，更新 `--device` 参数 |
| 镜像拉取超时 / 失败 | 网络问题 | 自动切换至 `m.daocloud.io` 或 `quay.nju.edu.cn` 镜像源 |
| `libatb.so not found` | NNAL 未安装 | 使用官方预构建镜像（已包含 NNAL），不要使用 pip 安装版本 |
| 容器名冲突 `name already in use` | 同名容器已存在 | 运行 `docker rm -f vllm-ascend` 后重试 |
| 服务 5 分钟内未就绪 | 模型下载中 | 运行 `docker logs -f vllm-ascend` 查看进度，耐心等待 |
| `OOM` / 显存不足 | 卡数不足 | 增加 `--device /dev/davinci1` 并添加 `--tensor-parallel-size 2` |
| 端口被占用 | 8000 已被占用 | 询问用户："8000 端口已被占用，请问使用哪个端口？" |

---

## 多卡部署（进阶，按需使用）

仅在用户要求或单卡 OOM 时使用：

```bash
# 4 卡示例
docker run -d \
  --name vllm-ascend \
  --shm-size=4g \
  --device /dev/davinci0 --device /dev/davinci1 \
  --device /dev/davinci2 --device /dev/davinci3 \
  --device /dev/davinci_manager \
  --device /dev/devmm_svm \
  --device /dev/hisi_hdc \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
  -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  -v /root/.cache:/root/.cache \
  -p 8000:8000 \
  quay.io/ascend/vllm-ascend:v0.17.0rc1 \
  bash -c "export VLLM_USE_MODELSCOPE=true && vllm serve Qwen/Qwen3-0.6B --tensor-parallel-size 4 --max-model-len 32768"
```

---

## 本地模型路径（进阶，按需使用）

若用户已下载模型到本地：

```bash
# 询问用户："模型文件存放在哪个路径？"
export LOCAL_MODEL_PATH=/path/to/model   # 替换为实际路径

docker run -d \
  --name vllm-ascend \
  --shm-size=1g \
  --device /dev/davinci0 \
  --device /dev/davinci_manager \
  --device /dev/devmm_svm \
  --device /dev/hisi_hdc \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
  -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  -v ${LOCAL_MODEL_PATH}:${LOCAL_MODEL_PATH} \
  -p 8000:8000 \
  quay.io/ascend/vllm-ascend:v0.17.0rc1 \
  bash -c "vllm serve ${LOCAL_MODEL_PATH} --max-model-len 32768"
```

---

## 停止服务

```bash
docker stop vllm-ascend && docker rm vllm-ascend
```
