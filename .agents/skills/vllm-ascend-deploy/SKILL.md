---
name: vllm-ascend-deploy
description: 在昇腾NPU上使用vLLM部署大语言模型服务。在需要部署vLLM推理服务或在昇腾NPU上运行推理时使用。
---

# Skill: vllm-ascend-deploy

在昇腾NPU上使用vLLM部署大语言模型

## 适用场景

- 快速在昇腾NPU服务器上部署vLLM推理服务
- Agentic Coding场景下自动化部署推理框架

## 前置要求

1. 昇腾NPU服务器（Atlas 800I A2/A3系列）
2. Docker已安装
3. 模型文件已放置在服务器上（如 `/home/weights/MODEL_NAME`）

> 部署前会自动校验模型是否被vllm-ascend支持，如模型不存在将提示下载

## 使用方法

### 基本用法

```bash
# 使用默认配置部署模型（使用NPU 0）
使用vllm部署模型 /home/weights/MODEL_NAME
```

### 指定参数

```bash
# 指定使用NPU 2，端口8002
使用vllm在NPU 2上部署模型 /home/weights/MODEL_NAME --port 8002
```

## 部署步骤

### 1. 环境检查

在执行部署前，验证当前是否在昇腾NPU服务器上：

```bash
# 检查是否存在npu-smi命令
which npu-smi || command -v npu-smi || echo "npu-smi not found"
```

如不在服务器上，需要先连接：

```bash
# 用户名@IP地址
ssh ${USER}@${SERVER_IP}
# 或使用 plink (Windows)
plink -pw ${PASSWORD} ${USER}@${SERVER_IP}
```

确认连接成功后，再继续执行后续步骤。

### 2. 模型支持校验

在部署前，校验目标模型是否被当前vllm-ascend镜像版本支持。

#### 2.1: 获取当前镜像版本

```bash
docker images | grep vllm-ascend
```

根据本地最高版本（排除main）确定对应的模型支持列表。

#### 2.2: 匹配模型支持列表

**v0.17.0rc1 (当前最新)**:
- DeepSeek V3/3.1, V3.2, R1
- Qwen3, Qwen3-Coder, Qwen3-Moe, Qwen3-Next, QwQ-32B, Qwen3.5
- Qwen2.5, Qwen2
- GLM-4.x, GLM-5, Kimi-K2-Thinking, Kimi-K2.5
- Minimax-M2.5 (实验)
- Qwen3-VL, Qwen2.5-VL (多模态)
- Qwen3-Embedding, Qwen3-Reranker (Pooling模型)

**v0.13.0**:
- DeepSeek V3/3.1, R1
- Qwen3, Qwen3-Next, Qwen2.5
- GLM-4.x, Kimi-K2-Thinking
- InternVL, Minimax-M2, Whisper (实验)

> 如果当前镜像版本不包含目标模型，参考官方文档获取最新支持列表：
> https://docs.vllm.ai/projects/ascend/en/latest/user_guide/support_matrix/supported_models.html

### 3. 检查/下载模型

检查模型权重目录是否存在：

```bash
ls -la ${MODEL_PATH}
```

如果模型目录不存在或为空：
1. 询问用户是否有本地模型权重
2. 如用户无本地权重，从以下渠道下载：

**HuggingFace**:
```bash
huggingface-cli download ${MODEL_NAME} --local-dir ${MODEL_PATH}
```

**ModelScope**:
```bash
modelscope download --model ${MODEL_NAME} --local_dir ${MODEL_PATH}
```

**Modelers**:
```bash
# 根据模型名称从 https://www.modelers.cn 下载
```

> 下载前检查磁盘空间：`df -h ${MODEL_PATH}`

### 4. 检查NPU状态

检查服务器上NPU的占用情况，选择空闲的NPU：

```bash
npu-smi info
```

查看 `Process memory` 列，选择空闲的NPU卡。

### 5. 检查端口冲突

检查指定端口是否已被占用：

```bash
netstat -tlnp | grep ${PORT}
```

如端口被占用，选择其他端口或停止占用进程。

### 6. 检查并拉取镜像

#### 6.1 确定硬件型号

```bash
npu-smi info
```

查看NPU芯片型号：
- **910B系列** (如910B3) -> A2 -> 使用不带后缀的镜像（如 `main`、`v0.17.0rc1`）
- **910C系列** (如910C3) -> A3 -> 使用带 `a3` 后缀的镜像（如 `main-a3`、`v0.17.0rc1-a3`）
- **310系列** -> 310p -> 使用带 `310p` 后缀的镜像（如 `main-310p`、`v0.17.0rc1-310p`）

#### 6.2 获取最新可用镜像版本

从本地镜像或远程仓库获取版本列表，排除 `main` 后选择最高版本号。

**本地检查**:
```bash
docker images | grep vllm-ascend
```

**远程获取**:
```bash
curl -sL https://quay.io/api/v1/repository/ascend/vllm-ascend/tag?limit=50
```

> 注意：使用 `-L` 参数处理HTTP重定向

版本命名规则：
- 无后缀（如 `v0.17.0rc1`）-> A2 (910B系列)
- `-a3` 后缀（如 `v0.17.0rc1-a3`）-> A3 (910C系列)
- `-310p` 后缀 -> 310p

#### 6.3 拉取镜像（如果未安装或版本过低）

根据步骤6.2确定的版本号（${IMAGE_VERSION}）和硬件型号拉取：

```bash
# A2系列 (910B)
docker pull quay.io/ascend/vllm-ascend:${IMAGE_VERSION}

# A3系列 (910C)
docker pull quay.io/ascend/vllm-ascend:${IMAGE_VERSION}-a3

# 如拉取失败，尝试国内镜像源
docker pull m.daocloud.io/quay.io/ascend/vllm-ascend:${IMAGE_VERSION}

# 华为云镜像可能需要认证
docker pull swr.cn-south-1.myhuaweicloud.com/ascendhub/vllm-ascend:${IMAGE_VERSION}
```

### 7. 启动容器

#### 7.1 检查并清理已有容器

检查同名容器是否存在：

```bash
docker ps -a | grep ${MODEL_NAME}-vllm
```

如存在，**询问用户是否可清理**，确认后可执行：

```bash
# 停止并删除同名容器
docker stop ${MODEL_NAME}-vllm 2>/dev/null
docker rm ${MODEL_NAME}-vllm 2>/dev/null
```

> 注意：清理容器将中断该模型已有的推理服务，请确保业务已做好准备

#### 7.2 启动新容器

```bash
docker run -dit \
  --privileged \
  --name ${MODEL_NAME}-vllm \
  --net=host \
  --shm-size=1g \
  --device /dev/davinci0 \
  --device /dev/davinci1 \
  --device /dev/davinci2 \
  --device /dev/davinci3 \
  --device /dev/davinci4 \
  --device /dev/davinci5 \
  --device /dev/davinci6 \
  --device /dev/davinci7 \
  --device /dev/davinci_manager \
  --device /dev/devmm_svm \
  --device /dev/hisi_hdc \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/Ascend/driver/tools/hccn_tool:/usr/local/Ascend/driver/tools/hccn_tool \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
  -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  -v /root/.cache:/root/.cache \
  -v /home:/home \
  -v /mnt:/mnt \
  quay.io/ascend/vllm-ascend:${IMAGE_TAG} \
  bash
```

### 8. 启动vLLM服务

在容器内执行：

```bash
#!/bin/bash
cd /workspace
# 优先使用软链接cann，如不存在则动态获取版本
if [ -L /usr/local/Ascend/cann ]; then
  CANN_VERSION="cann"
elif [ -d /usr/local/Ascend/cann-8.5.1 ]; then
  CANN_VERSION="cann-8.5.1"
else
  CANN_VERSION=$(ls -d /usr/local/Ascend/cann-* 2>/dev/null | head -1 | xargs basename)
fi
source /usr/local/Ascend/${CANN_VERSION}/set_env.sh
export ASCEND_RT_VISIBLE_DEVICES=${NPU_ID}
nohup vllm serve ${MODEL_PATH} \
  --host 0.0.0.0 \
  --port ${PORT} \
  --trust-remote-code \
  --dtype half \
  --max-model-len ${MAX_LEN} \
  --served-model-name ${MODEL_NAME} > /vllm.log 2>&1 &
echo "vllm started"
```

关键点：
- `ASCEND_RT_VISIBLE_DEVICES` 设置要使用的NPU卡号（根据步骤4选择）
- `MODEL_PATH` 模型路径（如 /home/weights/Qwen3-0.6B）
- `PORT` 服务端口（默认8001）
- `MODEL_NAME` 服务模型名（用于API识别）
- 确保模型路径下有权重文件（config.json, *.safetensors等）

### 9. 验证服务

持续动态检查日志，判断服务是否正常启动：

```bash
# 循环检查日志（最多等待10分钟，超时询问用户）
for i in {1..60}; do
  # 检查vllm进程是否还在运行
  RUNNING=$(docker exec ${MODEL_NAME}-vllm ps aux 2>/dev/null | grep -v grep | grep vllm)
  
  LOG=$(docker exec ${MODEL_NAME}-vllm cat /vllm.log 2>/dev/null | tail -30)
  
  # 进程已退出，检查是否失败
  if [ -z "$RUNNING" ]; then
    # 过滤掉warning/info后检查是否有错误
    ERROR_LINES=$(echo "$LOG" | grep -viE "warning|INFO" | grep -iE "error|exception|failed|traceback")
    if [ -n "$ERROR_LINES" ]; then
      echo "启动失败，进程已退出，错误日志："
      echo "$ERROR_LINES"
      exit 1
    else
      echo "进程异常退出，日志："
      echo "$LOG"
      exit 1
    fi
  fi
  
  # 进程还在运行，检查是否有启动成功标志
  if echo "$LOG" | grep -q "Started server process\|started server\|Uvicorn running"; then
    echo "vLLM服务启动成功"
    break
  fi
  
  # 进程在运行但有错误日志
  ERROR_LINES=$(echo "$LOG" | grep -viE "warning|INFO" | grep -iE "error|exception|failed|traceback")
  if [ -n "$ERROR_LINES" ]; then
    echo "启动失败，错误日志："
    echo "$ERROR_LINES"
    exit 1
  fi
  
  # 每30秒输出一次进度
  if [ $((i % 3)) -eq 0 ]; then
    echo "等待启动中... ($((i * 10))秒)"
  fi
  
  # 超时10分钟后询问用户
  if [ $i -eq 60 ]; then
    echo "服务启动超过10分钟仍未就绪"
    echo "请选择："
    echo "  1) 继续等待（每30秒询问一次）"
    echo "  2) 查看当前日志"
    echo "  3) 终止部署"
  fi
  
  sleep 10
done

# 验证API可访问
curl -s http://localhost:${PORT}/v1/models | grep -q "qwen\|model" && echo "API验证通过"

# 简单对话测试
echo "=== 对话测试 ==="
RESPONSE=$(curl -s http://localhost:${PORT}/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL_NAME}\",
    \"messages\": [{\"role\": \"user\", \"content\": \"你是谁\"}],
    \"max_tokens\": 100
  }")

# 兼容python3不存在的情况
if command -v python3 &> /dev/null; then
  echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])" 2>/dev/null || echo "$RESPONSE"
else
  echo "$RESPONSE"
fi
```

## 常见问题

### Q: 启动失败提示"Free memory on device is less than desired"

A: 选择其他空闲的NPU卡，或确保选中的NPU基础显存占用较低。

### Q: 容器启动后立即退出

A: 确保使用 `-dit` 参数而非 `-d`，并检查设备挂载是否正确。

### Q: vllm命令找不到

A: 检查CANN环境变量是否正确加载，执行 `source /usr/local/Ascend/cann-*/set_env.sh`

### Q: 镜像拉取失败

A: 检查网络连接，或尝试使用国内镜像源（见步骤6.3）

### Q: 服务启动失败

A: 查看日志排查：
```bash
docker exec ${MODEL_NAME}-vllm cat /vllm.log
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| MODEL_PATH | 模型文件路径 | 必填 |
| NPU_ID | 使用的NPU卡号 | 0 |
| PORT | 服务端口 | 8001 |
| MODEL_NAME | 服务模型名 | 取自模型目录名 |
| MAX_LEN | 最大模型长度 | 1024 |
| DTYPE | 数据类型 | half |
| IMAGE_VERSION | 镜像版本（不含后缀） | v0.17.0rc1 |
| IMAGE_TAG | 完整镜像标签 | v0.17.0rc1 (A2) / v0.17.0rc1-a3 (A3) |

## 参考

- [vLLM Ascend官方文档](https://docs.vllm.ai/projects/ascend/en/latest/user_guide/support_matrix/supported_models.html)
- [Ascend Model Deploy](https://github.com/vllm-project/vllm-ascend)
- [镜像仓库](https://quay.io/repository/ascend/vllm-ascend)