---
name: vllm-benchmark
description: Use this skill when the user wants to benchmark, performance test, stress test, or find optimal throughput/concurrency of an existing LLM inference service using vLLM benchmark tool. Triggers on phrases like "测试推理服务性能", "benchmark xxx服务", "摸测吞吐", "寻优并发", "测试TTFT/TPOT", "性能压测". Do NOT trigger for model deployment tasks (use vllm-ascend skill instead). Requires a running inference service endpoint.
license: Apache 2.0
---

# vLLM Benchmark 推理服务性能摸测

使用 `vllm bench serve`（v0.13.0）对已有推理服务进行性能测试，支持 SLA 约束下自动寻优最优并发。

## 工作流程

### Step 1 — 探测服务信息（自动执行，无需用户干预）

```bash
# 1. 检查服务健康状态
curl -s http://<host>:<port>/health

# 2. 自动获取模型名（省去用户手动输入）
curl -s http://<host>:<port>/v1/models | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])"
```

若服务不可达：**询问用户** — "服务地址或端口无法访问，请确认服务是否正在运行，以及 host:port 是否正确？"

---

### Step 2 — 与用户交互确认测试配置

按以下顺序确认，有默认值则无需追问，**一次性提问，不要逐条询问**：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 测试模式 | `text`（纯文本） | 是否涉及多模态（图片/音频）？ |
| 数据集 | `random` | sharegpt / sonnet / random / hf / 本地路径 |
| 输入 token 数 | `512` | 仅 random 数据集有效 |
| 输出 token 数 | `128` | 仅 random 数据集有效 |
| 请求总数 | `200` | 每轮测试发送的请求数 |
| SLA 约束 | 无 | TTFT < ?ms，TPOT < ?ms（有则自动寻优） |
| 测试 case 数量 | `1` | 是否需要测试多个并发/输入输出组合？ |

**示例确认消息**（一次性发出）：
> 检测到服务：`Qwen/Qwen3-0.6B` on `localhost:8000`
> 请确认以下配置（直接回车使用默认值）：
> 1. 测试模式：text / multimodal？
> 2. 数据集：random（默认）/ sharegpt / sonnet / hf / 本地路径？
> 3. 输入/输出 token 数：512 / 128（默认）？
> 4. 总请求数：200（默认）？
> 5. SLA 约束（如 TTFT<2000ms TPOT<50ms，无则留空）？
> 6. 是否测试多个 case？

---

### Step 3 — 准备数据集（按需自动下载）

```bash
# random 数据集：无需下载，直接使用

# sharegpt 数据集：自动下载
wget -q -O ShareGPT_V3_unfiltered_cleaned_split.json \
  https://huggingface.co/datasets/anon8231489123/ShareGPT_Vicuna_unfiltered/resolve/main/ShareGPT_V3_unfiltered_cleaned_split.json

# sonnet 数据集：vllm 仓库内置，路径为 benchmarks/sonnet.txt
# 若不存在：
wget -q -O sonnet.txt \
  https://raw.githubusercontent.com/vllm-project/vllm/v0.13.0/benchmarks/sonnet.txt

# hf 数据集：
# 使用 --dataset-path <HuggingFace数据集名>，benchmark 工具自动下载
```

---

### Step 4 — 执行基准测试

#### 4a. 单次测试（无 SLA）

```bash
# 调用 scripts/bench.sh
bash scripts/bench.sh \
  --host localhost \
  --port 8000 \
  --model <auto-detected> \
  --dataset random \
  --input-len 512 \
  --output-len 128 \
  --num-prompts 200 \
  --concurrency 16 \
  --result-dir ./results
```

#### 4b. SLA 约束寻优（有 TTFT/TPOT 目标）

自动对并发数做**二分搜索**，找出满足 SLA 的最大并发（即最优吞吐）：

```bash
# 调用 scripts/sla_search.sh
bash scripts/sla_search.sh \
  --host localhost \
  --port 8000 \
  --model <auto-detected> \
  --dataset random \
  --input-len 512 \
  --output-len 128 \
  --num-prompts 200 \
  --sla-ttft 2000 \     # ms
  --sla-tpot 50 \       # ms
  --result-dir ./results
```

#### 4c. 多模态测试

```bash
vllm bench serve \
  --backend openai-chat \
  --host localhost --port 8000 \
  --model <model> \
  --endpoint /v1/chat/completions \
  --dataset-name hf \
  --dataset-path lmms-lab/llava-bench-in-the-wild \
  --num-prompts 100 \
  --max-concurrency 8 \
  --save-result --result-dir ./results
```

#### 4d. 多 case 批量测试

每个 case 依次执行 4a/4b，结果汇总到同一 `./results` 目录，最后统一生成报告。

---

### Step 5 — 生成测试报告

```bash
python3 scripts/report.py --result-dir ./results --output benchmark_report.md
```

报告包含：
- 每个 case 的 TTFT / TPOT / ITL / 吞吐 汇总表
- SLA 寻优结论（最优并发数 + 对应吞吐）
- 超出 SLA 的 case 标红提示

---

## 错误处理

| 错误现象 | 原因 | 处理方式 |
|----------|------|----------|
| `Connection refused` | 服务未启动 | 询问用户："服务是否已启动？请确认 host:port" |
| `/v1/models` 返回空 | 服务未加载完成 | 等待 30s 后重试，超时则提示用户 |
| `dataset not found` | 数据集路径不存在 | 自动尝试下载（见 Step 3），失败则询问用户路径 |
| `vllm bench: command not found` | 未激活正确环境 | 询问："vllm 0.13.0 安装在哪个 conda 环境或容器中？" |
| 所有并发均超 SLA | SLA 过严或服务性能不足 | 报告"当前服务无法满足该 SLA，最低延迟在并发=1 时为 X ms" |
| 端口未提供 | 用户未指定端口 | **主动询问**："请提供推理服务的端口号（如 8000）" |

---

## 关键参数速查

```bash
vllm bench serve \
  --backend        vllm                    # 固定值
  --host           localhost               # 服务地址
  --port           8000                    # 服务端口
  --model          <model_id>              # 从 /v1/models 自动获取
  --endpoint       /v1/completions         # 文本；多模态用 /v1/chat/completions
  --dataset-name   random|sharegpt|sonnet|hf
  --dataset-path   <path_or_hf_name>      # random 时不需要
  --random-input-len  512
  --random-output-len 128
  --num-prompts    200
  --max-concurrency   16                  # 并发数（寻优时由脚本控制）
  --request-rate   inf                    # inf = 最大压力
  --save-result                           # 保存 JSON 结果
  --result-dir     ./results
```
