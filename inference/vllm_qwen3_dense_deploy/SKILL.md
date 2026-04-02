---
name: vllm-qwen3-dense-deploy
description: 使用 vllm-Ascend 在线部署Qwen3-Dense系列模型服务。触发场景：用户需要使用vLLM-Ascend在线部署模型服务化 时主动使用此 Skill。
---

# vLLM-Ascend Deploy Skill

用户需要测试 vLLM-Ascend 在线部署模型，使用vllm-ascend在线部署Qwen3-Dense模型服务，实现推理服务，并且能通过curl请求成功返回。

## 快速开始

1. **确认场景**：使用vllm-ascend在线部署Qwen3-Dense系列模型服务。
2. **拉起服务**：`vllm server xxx`
3. **服务测试**：`curl http://host_ip:port/v1/chat/completions xxxx`

> **提示**：未安装vllm环境、不清楚vllm服务化参数含义时，查阅 `reference/vllm_ascend_deploy_qwen3_dense.md`

---

## 使用场景

当用户需要使用vllm-ascend部署Qwen3-Dense系列模型时，使用此skill。

## 前置条件

### 测试环境

| 参数 | 说明 | 示例 |
|------|------|------|
| `<host_ip>` | vLLM 服务所在服务器的 IP 地址 | localhost, 192.168.1.100 |
| `<port>` | vLLM 服务的端口号 | 8000, 8001, 8113 |
| `<model_path>` | 模型权重路径 | /home/weights/Qwen3-VL-30B |

可用选项：
| 参数 | 值 |
|------|-----|
| 服务 IP | 本地 (localhost) |
| 服务端口 | 8113 |
| 模型路径 | /home/zjj/weight/Qwen3-0.6B/ |

### 环境要求

1. **vLLM-Ascend 环境已安装**
   ```bash
   pip list | grep vllm
   pip show vllm
   pip show vllm-ascend
   ```
   如果vLLM环境未安装，请参考 references/vllm_env_install.md，通过镜像容器部署安装环境。

2. **NPU环境确认**
   ```bash
   npu-smi info
   ```
---

## 测试流程

### 步骤1：环境准备：
1. 安装vllm和vllm-ascend环境，确保环境已经安装。
```BASH
pip list | grep vllm
```
如果vLLM环境未安装，请参考 references/vllm_env_install.md，通过镜像容器部署安装环境。

2. 查看NPU环境，设置device
通过`npu-smi info`命令查看哪张卡空着。
使用
```
export ASCEND_RT_VISIBLE_DEVICES=
```
命令设置device_id

### 步骤2：使用vllm serve命令拉起模型在线服务
1. 准备脚本：
查阅 `reference/vllm_deploy.md`，在工作目录下生成deploy_xx.sh脚本文件，需要配置服务化参数：
- `vllm serve vllm-ascend/Qwen3-32B-W8A8`: 需要把`vllm-ascend`改成模型路径
- `model`: qwen3 (vLLM 注册的模型名)
- `host_ip`: localhost
- `host_port`: 8113

2. 拉起服务：
执行生成的deploy_xx.sh脚本文件，拉起在线服务：


### 步骤3：使用curl命令测试
1. 准备脚本：
查阅 `reference/vllm_deploy.md`，在工作生成test_xx.sh文件，在文件中，使用 curl 请求验证服务是否能正常处理请求。

2. 请求测试：
执行test_xx.sh文件，发送请求后能正常返回，且返回的内容符合逻辑。

### 步骤4：关闭服务
测试完成后，停止vllm serve服务。
通过一下命令查询PID，然后Kill：
```
ps aux | grep VLLM
```

### 步骤 5：生成结果文件
文件中需要记录 部署信息、部署命令、测试结果（测试命令、测试状态、服务返回内容）、注意事项 ... 等内容。

## 预期输出
test_xx.sh脚本发送请求后能正常返回，且返回的内容符合逻辑，格式化输出请求的内容，和返回的内容。

## 注意事项
1. **FlashComm1 不支持单卡**: `VLLM_ASCEND_ENABLE_FLASHCOMM1` 只在 `tensor-parallel-size > 1` 时使用
2. **NPU卡配置**: Qwen3-0.6B 使用单卡即可运行（通过`export ASCEND_RT_VISIBLE_DEVICE=xx`设置）
3. **结果记录**：记录请求的问题和返回的内容结果保存到工作目录文件中。

## 故障排除
对于参数详情和测试结果解读，查阅vLLM-Ascend Docs： https://docs.vllm.ai/projects/ascend/en/latest/tutorials/models/Qwen3-Dense.html。

