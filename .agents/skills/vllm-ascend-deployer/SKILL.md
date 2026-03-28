---
name: "vllm-ascend-deployer"
description: "Deploys LLM models using vLLM-Ascend on Huawei Atlas servers. Invoke when user needs to deploy models on Ascend NPU or mentions vLLM-Ascend deployment."
---

# vLLM-Ascend 模型部署技能

本技能提供在华为 Atlas 800I A2 服务器上使用 vLLM-Ascend 部署大语言模型的完整工作流程。

## 前置条件

1. **服务器访问**：拥有 Atlas 800I A2 服务器的 SSH 访问权限
2. **Docker 环境**：已安装 Docker 并配置好 Ascend 设备支持
3. **模型权重**：已下载的模型权重文件，存放在可访问的目录
4. **vLLM-Ascend 镜像**：Docker 镜像 ID 或名称（如 `quay.io/ascend/vllm-ascend:v0.17.0`）

## 快速开始

### 第一步：检查 NPU 状态

部署前，先检查哪些 NPU 卡可用：

```bash
npu-smi info
```

查找 HBM 使用率低的卡（空闲卡）。每张 Atlas 800I A2 的 NPU 有 64GB HBM 内存。

### 第二步：部署模型

按照下方部署工作流程启动模型服务。

## 部署工作流程

### 1. 确认资源信息

首先，收集以下信息：
- **模型路径**：模型权重的绝对路径（如 `/home/weights/Qwen3-4B`）
- **Docker 镜像**：镜像 ID 或名称（如 `0fa7e4550d22` 或 `quay.io/ascend/vllm-ascend:v0.17.0`）
- **NPU 设备**：使用哪个 NPU（如 `/dev/davinci1` 表示 NPU 1）
- **服务端口**：API 服务端口（默认：8000）

### 2. 启动 Docker 容器

使用 `resources/start_docker.sh` 中的容器启动脚本模板：

```bash
docker run -itd --privileged \
  --name=<container-name> \
  --net=host \
  --shm-size=16g \
  --device /dev/davinci<N> \
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
  <image-id> /bin/bash
```

### 3. 启动 vLLM 服务

在容器内启动 vLLM 服务：

```bash
vllm serve <model-path> \
  --host 0.0.0.0 \
  --port <port> \
  --dtype float16 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.7
```

### 4. 验证部署

测试 API 端点：

```bash
curl http://localhost:<port>/v1/models
```

## 配置参数说明

### vLLM 参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--model` | 模型权重路径 | 必填 |
| `--host` | 绑定的主机地址 | 0.0.0.0 |
| `--port` | 服务端口 | 8000 |
| `--dtype` | 数据类型（float16/bfloat16） | auto |
| `--max-model-len` | 最大序列长度 | 模型默认值 |
| `--gpu-memory-utilization` | GPU 内存使用比例 | 0.9 |
| `--tensor-parallel-size` | 张量并行使用的 NPU 数量 | 1 |
| `--max-num-seqs` | 最大并发序列数 | 256 |

### Docker 参数

| 参数 | 说明 |
|------|------|
| `--device /dev/davinci<N>` | 指定 NPU 设备 |
| `--shm-size` | 共享内存大小 |
| `--net=host` | 使用主机网络 |
| `-v` | 卷挂载 |

## 内存估算

估算模型是否能放入可用的 NPU 内存：

| 模型规模 | 参数量 | FP16 内存占用（约） |
|----------|--------|---------------------|
| Qwen2.5-0.5B | 0.5B | ~1 GB |
| Qwen2.5-1.5B | 1.5B | ~3 GB |
| Qwen2.5-3B | 3B | ~6 GB |
| Qwen3-4B | 4B | ~8 GB |
| Qwen2.5-7B | 7B | ~14 GB |
| Qwen2.5-14B | 14B | ~28 GB |
| Qwen2.5-32B | 32B | ~64 GB |
| Qwen2.5-72B | 72B | ~144 GB（需 2 张 NPU） |

**计算公式**：内存 (GB) ≈ 参数量 (B) × 2 (FP16) × 1.1 (额外开销)

## 支持的模型

完整支持模型列表请参考 `resources/supported_models.md`。

### Atlas 800I A2 已验证模型

- Qwen2.5 系列（0.5B - 72B）
- Qwen3 系列（4B, 8B, 14B, 32B）
- Llama 2/3 系列
- DeepSeek 系列
- Baichuan 系列

## API 使用示例

### 查看模型列表
```bash
curl http://<server-ip>:<port>/v1/models
```

### 对话补全（Chat Completions）
```python
import requests

response = requests.post(
    'http://<server-ip>:<port>/v1/chat/completions',
    json={
        'model': '<model-path>',
        'messages': [{'role': 'user', 'content': '你好！'}],
        'max_tokens': 100
    }
)
print(response.json())
```

### 文本补全（Text Completions）
```python
response = requests.post(
    'http://<server-ip>:<port>/v1/completions',
    json={
        'model': '<model-path>',
        'prompt': '从前有座山',
        'max_tokens': 100
    }
)
```

## 故障排除

常见问题及解决方案请参考 `resources/troubleshooting.md`。

### 常见问题快速处理

1. **内存不足**：降低 `--gpu-memory-utilization` 或 `--max-model-len`
2. **找不到 NPU**：检查设备映射 `--device /dev/davinci<N>`
3. **模型加载失败**：验证模型路径和格式是否正确
4. **网络无法访问**：确保使用 `--host 0.0.0.0` 且端口可访问

## 资源文件

| 文件 | 说明 |
|------|------|
| `resources/start_docker.sh` | Docker 容器启动脚本模板 |
| `resources/test_api.py` | API 测试脚本 |
| `resources/supported_models.md` | 支持模型参考列表 |
| `resources/troubleshooting.md` | 故障排除指南 |
| `resources/quick_reference.md` | 快速参考卡片 |

## 完整部署示例

```bash
# 1. 检查 NPU 状态
npu-smi info

# 2. 启动容器（使用 NPU 1）
docker run -itd --privileged --name=qwen3-4b \
  --net=host --shm-size=16g \
  --device /dev/davinci1 \
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
  quay.io/ascend/vllm-ascend:v0.17.0 /bin/bash

# 3. 启动 vLLM 服务
docker exec qwen3-4b bash -c 'nohup vllm serve /home/weights/Qwen3-4B \
  --host 0.0.0.0 --port 8002 \
  --dtype float16 --max-model-len 4096 \
  --gpu-memory-utilization 0.7 > /tmp/vllm.log 2>&1 &'

# 4. 查看日志
docker exec qwen3-4b tail -f /tmp/vllm.log

# 5. 测试 API
curl http://localhost:8002/v1/models
```

## 运维管理

### 停止服务
```bash
docker exec <container> pkill -f vllm
docker stop <container>
```

### 更新镜像
```bash
docker pull quay.io/ascend/vllm-ascend:v0.17.0
docker stop <container>
docker rm <container>
# 使用新镜像重新部署
```

### 查看日志
```bash
docker exec <container> cat /tmp/vllm.log
docker logs <container>
```
