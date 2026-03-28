# Qwen3-32B vLLM-Ascend 部署与 AISBench 性能测试 Skill

## 1. Skill 基本信息

| 项目 | 说明 |
|------|------|
| Skill 名称 | qwen3-vllm-aisbench |
| 版本 | 1.1.0 |
| 作者 | AI Assistant |
| 更新时间 | 2026-03-29 |
| 功能描述 | 在 Atlas 800I A2 NPU 机器上，使用 vllm-ascend 部署 Qwen3-32B 模型，并通过 AISBench 进行性能测试与分析 |

## 2. 使用场景

- 在 Atlas 800I A2 NPU 机器上快速部署 Qwen3-32B 模型服务
- 对部署的模型服务进行自动化性能测试
- 生成可视化的性能分析报告
- 验证模型在 NPU 上的推理性能

## 3. 功能介绍

- ✅ 自动下载 Qwen3-32B 模型权重
- ✅ 支持 vllm-ascend 镜像拉取与容器创建
- ✅ 一键式启动 vllm-ascend 服务
- ✅ 集成 AISBench 进行性能测试
- ✅ 自动生成可视化性能分析报告

## 4. 前置条件

- 已安装 Docker 环境
- 已配置 NPU 驱动与固件
- 具备网络连接（用于下载模型与镜像）
- 具备足够的磁盘空间（建议 > 50GB）

## 5. 使用说明

### 5.1 基本使用

**Prompt 示例：**
```
在 Atlas 800I A2 机器上部署 Qwen3-8B 模型并使用 AISBench 进行性能测试
```

### 5.2 详细交互流程

#### 步骤 1：确认环境

```
正在检查 Docker 环境...
✅ Docker 已安装
正在检查 NPU 设备...
✅ 检测到 Atlas 800I A2 NPU 设备

请确认是否继续执行部署与测试流程？(y/n)
```

#### 步骤 2：配置参数

```
请配置部署参数：
1. 模型存储路径 [默认: /data/models/Qwen3-8B]
2. 服务端口 [默认: 8000]
3. 容器名称 [默认: vllm-ascend-qwen3]
4. 测试并发数 [默认: 1,2,4,8,10]

请输入配置项（直接回车使用默认值）：
```

#### 步骤 3：执行部署

```
开始执行部署流程...
1. 正在拉取 vllm-aisbench 镜像...
2. 正在下载 Qwen3-32B 模型...
3. 正在创建 Docker 容器...
4. 正在配置环境变量和启动参数...
5. 正在启动 vllm-ascend 服务...

✅ 部署完成！服务已在 http://localhost:8113 启动
```

#### 步骤 4：执行性能测试

```
开始执行 AISBench 性能测试...
正在测试并发数：1
正在测试并发数：2
正在测试并发数：4
正在测试并发数：8
正在测试并发数：10

✅ 测试完成！正在生成分析报告...
```

#### 步骤 5：查看测试结果

```
# Qwen3-32B vLLM-Ascend 性能测试报告

## 测试概述
- 测试时间：2026-03-29 15:30:00
- 测试工具：AISBench
- 模型：Qwen3-32B (W8A8量化)
- 部署方式：vllm-ascend v0.17.0rc1
- 服务地址：http://localhost:8113

## 测试数据集
- C-Eval
- MMLU
- GPQA
- MATH-500

## 性能指标

| 数据集 | 平均吞吐率 (tokens/s) | 平均 TTFT (ms) | 平均 TPOT (ms) | 平均成功率 (%) |
|--------|-------------------|-----------|-----------|------------|
| C-Eval | 850              | 1200       | 45        | 98.5       |
| MMLU   | 920              | 1350       | 48        | 97.8       |
| GPQA   | 780              | 1420       | 52        | 96.5       |
| MATH-500 | 650              | 1600       | 58        | 95.2       |

## 可视化分析
- 生成各数据集吞吐率对比曲线
- 生成各数据集延迟指标对比曲线
- 生成成功率对比图表

✅ 报告已保存至：performance_report_20260329_153000.md
```

## 6. 脚本说明

### 6.1 部署脚本（deploy_qwen3.sh）

用于自动化部署 Qwen3-8B 模型服务

### 6.2 测试脚本（run_aisbench.sh）

用于执行 AISBench 性能测试

### 6.3 分析脚本（analyze_results.py）

用于生成可视化性能分析报告

## 7. 错误处理

### 7.1 常见错误

#### 错误 1：Docker 未安装
```
❌ 未检测到 Docker 环境
请安装 Docker：https://docs.docker.com/get-docker/
```

#### 错误 2：NPU 设备不可用
```
❌ 未检测到 NPU 设备
请检查 NPU 驱动安装：https://www.hiascend.com/document/detail/zh/driver-development/instg/instg_000011.html
```

#### 错误 3：模型下载失败
```
❌ Qwen3-8B 模型下载失败
请检查网络连接或手动下载模型至 /data/models/Qwen3-8B
```

#### 错误 4：服务启动失败
```
❌ vllm-ascend 服务启动失败
请查看容器日志：docker logs vllm-ascend-qwen3
```

## 8. 更新日志

| 版本 | 更新内容 | 更新时间 |
|------|----------|----------|
| 1.0.0 | 初始版本，支持 Qwen3-8B 部署与 AISBench 测试 | 2026-03-29 |
