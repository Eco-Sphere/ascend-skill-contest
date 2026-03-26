---
name: "xllm-aisbench-test"
description: "使用ais_bench测试xllm性能。Invoke when user wants to benchmark xllm performance using ais_bench tool."
---

# xLLM Performance Testing with ais_bench

本技能用于使用 ais_bench 对 xllm 进行性能评测，包括精度测试和性能测试。

## 重要说明

**所有操作必须在 Docker 容器内执行！** Docker 外没有环境和权限。

 ais_bench 安装路径：`/usr/local/lib/python3.11/site-packages/ais_bench/`

## 测试前检查清单

### 1. 确认 Docker 容器名称/ID

```bash
docker ps -a | grep <容器名>
```

### 2. 确认 ais_bench 安装

```bash
docker exec <容器> pip list | grep ais_bench
```

### 3. 确认 xllm 服务运行正常

```bash
docker exec <容器> curl -s http://localhost:<端口>/v1/models
```

## 测试前配置确认

在开始测试前，请确认以下关键配置：

| 配置项 | 说明 | 示例值 |
|--------|------|--------|
| Docker 容器 | 测试使用的容器名称 | qwen3_next_xyx_0306 |
| 模型名称 | xllm 服务的模型名称 | Qwen3-Next-80B-A3B-Instruct |
| 服务 IP | 推理服务地址 | localhost |
| 服务端口 | 推理服务端口 | 18001 |
| 测试类型 | 精度测试 或 性能测试 | 性能测试 |
| 最大输出长度 | max_out_len | 2048 |
| 批量大小(并发) | batch_size | 16 |
| tokenizer 路径 | 模型权重路径 | /export/home/models/Qwen3-Next-80B-A3B-Instruct/ |

### 性能测试额外配置

| 配置项 | 说明 | 示例值 |
|--------|------|--------|
| 数据类型 | tokenid 或 string | string |
| 请求条数 | 总请求数 | 100 |
| 输入长度分布 | uniform/gaussian/zipf | uniform |
| 输入长度范围 | MinValue, MaxValue | 1, 2048 |
| 输出长度分布 | uniform/gaussian/zipf | gaussian |
| 输出长度参数 | Mean, Var, MinValue, MaxValue | 1024, 200, 1, 2048 |

## 配置修改步骤

### 1. 修改 vllm_api_general_stream.py（性能测试）

```bash
# 进入容器
docker exec -it <容器> /bin/bash

# 修改配置
sed -i 's|path="",|path="<tokenizer路径>",|g' /usr/local/lib/python3.11/site-packages/ais_bench/benchmark/configs/models/vllm_api/vllm_api_general_stream.py
sed -i 's/model="",/model="<模型名称>",/g' /usr/local/lib/python3.11/site-packages/ais_bench/benchmark/configs/models/vllm_api/vllm_api_general_stream.py
sed -i 's/host_port = <旧端口>/host_port = <新端口>/g' /usr/local/lib/python3.11/site-packages/ais_bench/benchmark/configs/models/vllm_api/vllm_api_general_stream.py
sed -i 's/max_out_len = <旧长度>/max_out_len = <新长度>/g' /usr/local/lib/python3.11/site-packages/ais_bench/benchmark/configs/models/vllm_api/vllm_api_general_stream.py
sed -i 's/batch_size=<旧值>/batch_size=<新值>/g' /usr/local/lib/python3.11/site-packages/ais_bench/benchmark/configs/models/vllm_api/vllm_api_general_stream.py

# 确认修改
cat /usr/local/lib/python3.11/site-packages/ais_bench/benchmark/configs/models/vllm_api/vllm_api_general_stream.py
```

### 2. 修改 synthetic_config.py（合成数据配置）

```bash
sed -i 's/"Type":"tokenid"/"Type":"<数据类型>"/g' /usr/local/lib/python3.11/site-packages/ais_bench/datasets/synthetic/synthetic_config.py
sed -i 's/"RequestCount": <旧值>/"RequestCount": <新值>/g' /usr/local/lib/python3.11/site-packages/ais_bench/datasets/synthetic/synthetic_config.py
sed -i 's/"MaxValue": <旧值>/"MaxValue": <新值>/g' /usr/local/lib/python3.11/site-packages/ais_bench/datasets/synthetic/synthetic_config.py

# 确认修改
cat /usr/local/lib/python3.11/site-packages/ais_bench/datasets/synthetic/synthetic_config.py
```

## 启动测试

### 性能测试

```bash
docker exec <容器> ais_bench --models vllm_api_general_stream --datasets synthetic_gen -m perf --debug
```

### 精度测试

```bash
docker exec <容器> ais_bench --model vllm_api_general_chat --datasets <数据集名> --debug
```

## 常用模型路径参考

| 模型 | tokenizer 路径 |
|------|---------------|
| Qwen3-Next-80B-A3B-Instruct | /export/home/models/Qwen3-Next-80B-A3B-Instruct/ |

## 常见问题排查

1. **Tokenizer path does not exist** - 确保 path 配置正确，指向包含 tokenizer.json 的目录
2. **Request failed: Exceeded maximum retry** - 检查 xllm 服务是否正常运行
3. **配置文件只读** - 使用 sed 命令修改，避免直接 vim 编辑

## 参考文档

- 精度评测：https://ais-bench-benchmark.readthedocs.io/zh-cn/latest/base_tutorials/scenes_intro/home.html#id2
- 性能评测：https://ais-bench-benchmark.readthedocs.io/zh-cn/latest/base_tutorials/scenes_intro/home.html#id5