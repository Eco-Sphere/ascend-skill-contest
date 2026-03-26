---
name: performance-testing
description: 对推理服务进行性能测试与寻优。在需要测试推理性能、压测、寻找最优吞吐时使用。
---

# Skill: performance-testing

对推理服务进行性能测试与寻优

## 关键词（用于触发skill）

**性能测试**、**压测**、**benchmark**、**TTFT**、**TPOT**、**最优吞吐**、**寻优**、**QPS**、**并发测试**、**vLLM**、**推理服务**

## 适用场景

- 对已部署的推理服务进行性能压测
- 寻找满足TTFT/TPOT要求的最优并发配置
- 搜索最大吞吐量的最优参数组合
- 测试推理服务在特定延迟要求下的最大QPS

## 典型触发Prompt

> "测试 175.99.1.2:8000 服务在满足 TTFT < 2s，TPOT < 50ms 情况下的最优吞吐"

## 前置条件

1. 推理服务已部署并运行（vLLM服务）
2. 测试工具已安装（vLLM benchmark 0.13.0+ 或 AISBench）
3. **可远程登录到测试服务器（SSH IP、用户名、密码或密钥）**
4. **确认测试镜像名称和拉起方式**
5. 确认NPU资源充足，无其他测试占用

> **⚠️ 重要：开始测试前必须先询问以下信息（全部必填，缺一不可！）**
> 1. **测试工具**：使用什么工具测试？（vLLM benchmark / AISBench / 其他）
> 2. **工具环境**：测试工具安装在哪里？如何访问？（本地安装/容器名称/远程服务器）
> 3. **数据集**：使用什么数据集？（random / synthetic / 具体数据集名称）
> 4. **测试数据条数**：需要测试多少条请求？（num-prompts数量）
> 5. 服务器SSH连接信息（IP、端口、用户名、密码/密钥）
> 6. vLLM镜像名称和标签（如 v0.17.0rc1）
> 7. 如何拉起镜像（docker run命令或已运行的容器名）
> 8. 测试服务的端口和模型名称

> **⚠️ 严格执行警告：开始任何测试前必须完成以下全部确认步骤，禁止跳过！**
> 1. 确认测试目的（快速验证/严谨测试）
> 2. 确认服务信息（地址、模型名）
> 3. 确认性能目标（TTFT、TPOT具体数值）
> 4. 确认测试数据（输入长度、输出长度）
> 5. **必须确认测试工具**
> 6. **必须确认工具环境位置/访问方式**
> 7. **必须确认数据集类型**
> 8. **必须确认测试数据条数**
> 9. **确认请求频率（request_rate）**
> 10. 动态调整并发策略（根据测试结果）
> 11. 生成完整配置确认单，等待用户明确确认[Y/N]
> 12. 检查服务状态后，方可开始测试

## 使用方法

```bash
# 发起性能测试（常见触发方式）
测试推理服务性能 --host 192.168.1.100 --port 8001 --model qwen3-vl-4b

# 测试最优吞吐
测试 192.168.1.100:8000 服务在满足 TTFT<2s,TPOT<50ms 情况下的最优吞吐

# 使用vLLM benchmark压测
使用 vllm bench 测试 192.168.1.100:8000 服务的 QPS 和延迟
```

---

## 测试用例参考

常规性能测试用例：

| 用例 | 说明 | 优先级 |
|------|------|--------|
| TC-01 | 标准性能测试：验证在指定输入输出长度下是否满足TTFT/TPOT目标 | 高 |
| TC-02 | 并发测试：不同并发数下的性能表现 | 高 |
| TC-03 | 寻优测试：满足指标约束下的最大吞吐配置 | 高 |

**测试执行原则**：
- 性能测试必须串行执行（避免相互影响）
- 测试前检查NPU占用和进程状态

---

## 测试流程

> **⚠️ 严格执行警告：必须按照以下步骤顺序执行，禁止跳过任何步骤！**
> - 禁止未确认测试配置就开始测试
> - 禁止未检查进程状态就开始测试
> - 禁止跳过寻优区间直接测其他值
> - 禁止测试完成后不生成Excel报告

### 测试前必须完成的配置确认单

> **⚠️ 开始测试前必须展示以下确认单并等待用户明确回复[Y]**

```
================================================================================
                       性能测试配置确认单
================================================================================

【服务信息】
  ● 推理服务地址：{HOST}:{PORT}
  ● 模型名称：{MODEL_NAME}

【性能目标】
  ● TTFT目标：< {TTFT_TARGET} ms
  ● TPOT目标：< {TPOT_TARGET} ms
  ● 优化目标：{OPTIMIZATION_GOAL}

【测试数据】
  ● 输入长度：{INPUT_LEN} token
  ● 输出长度：{OUTPUT_LEN} token

【测试规则】
  ● 数据条数 = 最大并发 × {NUM_MULTIPLIER}（{RULE_DESCRIPTION}）
  ● 请求频率(RPS)：{REQUEST_RATE}（0=全并发，从0开始寻优）
  ● 并发策略：动态调整（根据测试结果分析决定下一步）

================================================================================
                    前几步测试方案
================================================================================

【第1步】并发=1, num-prompts={NUM_PROMPTS_CONC1}
  → 测试完成后根据结果动态决定步幅

【动态步幅规则】
  · 非常充裕 (TTFT<{TTFT_TARGET}×30% 且 TPOT<{TPOT_TARGET}×30%) → 步幅×2
  · 比较充裕 (TTFT<{TTFT_TARGET}×50% 且 TPOT<{TPOT_TARGET}×50%) → 步幅×1.5
  · 接近限制 (TTFT<{TTFT_TARGET}×80% 或 TPOT<{TPOT_TARGET}×80%) → 步幅×1
  · 接近临界 (TTFT<{TTFT_TARGET} 或 TPOT<{TPOT_TARGET}) → 步幅÷2

【后续步骤】根据第1步结果动态决定
  → 连续2次满足且QPS下降 → 回退到最优配置并验证终止条件

================================================================================
  以上配置和测试方案是否确认？[Y/N]：
================================================================================
```

> **⚠️ 严格规则**：
> - 数据条数必须按公式计算：num-prompts = max-concurrency × {NUM_MULTIPLIER}
> - 每次测试后必须根据结果动态决定下一步并发数
> - 禁止随意更改已确认的参数
> - 禁止跳过步骤直接测其他值

**在获得用户明确[Y]确认之前，禁止执行任何测试命令！**

### 第1步：交互确认测试信息

#### 1.1 确认测试目的（首要问题）

首先必须明确测试目的，选择不同的测试模式：

| 测试模式 | 适用场景 | 需要确认的信息 |
|---------|---------|---------------|
| **快速验证** | 验证测试环境是否正常工作、快速检查服务可用性 | 只需提供：服务地址、模型名称 |
| **严谨测试** | 性能评估、寻优、提交正式测试报告 | 需确认所有测试细节 |

> **交互询问**：
> ```
> 请确认测试目的：
> 1. 快速验证测试环境（使用默认配置快速测试）
> 2. 严谨测试（需要满足特定性能指标）
> 
> 请输入选项 [1/2]：
> ```

---

#### 1.2 快速验证模式（仅验证环境）

**所需信息（必须提供）**：

| 信息项 | 说明 | 是否必填 | 默认值 |
|--------|------|---------|--------|
| 推理服务地址 | IP:端口 | **必填** | 无 |
| 模型名称 | 服务注册的模型名 | **必填** | 无 |

**默认测试配置**（用户确认后可使用）：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 输入长度 | 512 | token数 |
| 输出长度 | 256 | token数 |
| 并发数 | 1 | 单次请求 |
| 测试工具 | **无默认值，必须询问用户** | vLLM benchmark / AISBench / 其他 |
| 工具环境 | **无默认值，必须询问** | 本地安装/容器名称/远程服务器 |
| 数据集 | random | random / synthetic / 具体数据集名称 |
| num-prompts | 10 | 少量请求快速验证 |

> **⚠️ 重要：快速验证模式也必须询问以下项目**
> - 测试工具是什么？（必填）
> - 测试工具在哪里？（必填）
> - 使用什么数据集？（必填）
> - 测试多少条数据？（必填）

> **确认提示**：
>
> ```
> 快速验证配置：
> - 服务地址：{用户输入}
> - 模型名称：{用户输入}
> - 输入长度：512（默认）
> - 输出长度：256（默认）
> - 并发数：1（默认）
> - 测试工具：{用户输入}（必填）
> - 工具环境：{用户输入}（必填）
> - 数据集：{用户输入}（必填）
> - 数据条数：{用户输入}（必填）
> 
> 是否使用上述配置开始测试？[Y/N]
> ```

---

#### 1.3 严谨测试模式（完整配置确认）

**第一步：服务侧信息（必须提供）**

| 信息项 | 说明 | 是否必填 | 默认值 |
|--------|------|---------|--------|
| 推理服务地址 | IP:端口 | **必填** | 无 |
| 模型名称 | 服务注册的模型名 | **必填** | 无 |

**第二步：性能目标（必须提供）**

| 信息项 | 说明 | 是否必填 | 默认值 | 备注 |
|--------|------|---------|--------|------|
| TTFT目标 | 首token延迟要求(ms) | **必填** | 2000 | 如<2000ms |
| TPOT目标 | 每token延迟要求(ms) | **必填** | 50 | 如<50ms |
| P99延迟目标 | 可选，99分位延迟要求 | 选填 | 无 | 如<500ms |
| 优化目标 | 寻优方向 | **必填** | 最大吞吐 | 搜索最大吞吐 / 满足延迟下优化QPS |

**第三步：测试数据配置**

| 信息项 | 说明 | 是否必填 | 默认值 | 备注 |
|--------|------|---------|--------|------|
| 输入长度 | 提示词token数 | **必填** | 512 | |
| 输出长度 | 生成内容token数 | **必填** | 256 | |
| 数据集 | 测试使用的数据集 | 选填 | random | random/ShareGPT/synthetic |
| 是否多模态 | 是否测试视觉模型 | 选填 | 否 | 是时需确认图像处理 |

> **⚠️ 重要：确认数字单位**
> - 用户说"1k"时必须确认是1000还是1024
> - 例如"输入1k输出1k" → 确认"k"是1000还是1024
> - 建议默认按1024理解，但必须主动询问用户确认

**第四步：测试工具与并发配置**

| 信息项 | 说明 | 是否必填 | 默认值 | 备注 |
|--------|------|---------|--------|------|
| 测试工具 | 压测工具选择 | **必填** | 无 | vLLM / AISBench / 其他 |
| 工具环境 | 测试工具的安装位置/访问方式 | **必填** | 无 | 本地安装/容器名称/SSH远程 |
| 数据集 | 测试使用的数据集 | **必填** | 无 | random / synthetic / 具体数据集名称 |
| 测试数据条数 | 测试prompt数量 | **必填** | 无 | 必须≥最大并发 |
| 并发测试范围 | 动态调整，根据上次测试结果决定 | 选填 | 动态调整 | 初始1，根据结果决定下一步 |
| 请求频率(RPS) | 每秒请求数，0=全并发 | **必填** | 0 | 0=同时发送所有请求，必须明确询问用户 |
| 是否动态调节 | 是否根据结果自动调整参数 | 选填 | 是 | 仅用于寻优 |

> **⚠️ 严格禁止：以下项目无默认值，必须明确询问用户获取答案！**
> - 测试工具是什么？（不能跳过！）
> - 测试工具在哪里/如何访问？（不能跳过！）
> - 使用什么数据集？（不能跳过！）
> - 测试多少条数据？（不能跳过！）

**第五步：终止条件（寻优用）**

| 信息项 | 说明 | 是否必填 | 默认值 |
|--------|------|---------|--------|
| 终止条件 | 达到目标后是否继续搜索 | 选填 | 微调±1验证后终止 |
| 最大迭代次数 | 寻优最大尝试次数 | 选填 | 30 |

> **⚠️ 重要：请求频率(request_rate)必须明确确认！**
> - 用户未明确指定时，必须询问："请求频率是多少？（0=全并发，其他数值=每秒N个请求）"
> - 不能假设默认值为0，必须获得用户明确回复
> 
> **完整交互示例（严谨测试）**：
> ```
> === 严谨测试配置确认 ===
> 
> 【服务信息】
> 1. 推理服务地址（IP:端口）[必填]：192.168.1.100:8001
> 2. 模型名称 [必填]：qwen3-0.6b
> 
> 【性能目标】
> 3. TTFT目标(ms) [必填，默认2000]：2000
> 4. TPOT目标(ms) [必填，默认50]：50
> 5. P99延迟目标(ms) [选填]：500
> 6. 优化目标 [必填，默认最大吞吐]：最大吞吐
> 
> 【测试数据】
> 7. 输入长度 [必填，默认512]：512
> 8. 输出长度 [必填，默认256]：256
> 9. 是否多模态 [选填，默认否]：否

> 【工具与并发】
> 10. 测试工具 [必填，无默认值]：vLLM
> 11. 工具环境 [必填，无默认值]：本地/容器/远程
> 12. 数据集 [必填，无默认值]：random/synthetic/数据集名
> 13. 测试数据条数 [必填，无默认值]：100
> 15. 并发测试范围 [选填，动态调整]：动态（根据测试结果决定）
> 16. 请求频率(RPS) [必填，必须明确询问]：0（用户确认）
> 17. 是否动态调节 [选填，默认是]：是

> 【终止条件】
> 18. 最大迭代次数 [选填，默认20]：20
> ```

**生成确认表格**（用户确认后显示）：

```
============================================================
           性能测试配置确认单（示例）
============================================================

【服务信息】
  服务地址：192.168.1.100:8001
  模型名称：qwen3-0.6b

【性能目标】
  TTFT目标：< 2000 ms
  TPOT目标：< 50 ms
  P99延迟：< 500 ms
  优化目标：最大吞吐

【测试数据】
  输入长度：512 token
  输出长度：256 token
  数据集：random（必填）
  多模态：否

【测试配置】
  测试工具：vLLM benchmark（必填）
  工具环境：本地安装（必填）
  数据条数：并发×3（必填）
  并发范围：动态调整（根据测试结果分析决定）
  请求频率：0（全并发）
  动态调节：是
  最大迭代：20

======================================================================
                    前几步测试方案
======================================================================

【第1步】并发=1, num-prompts=3
  → 根据TTFT/TPOT结果决定步幅

【动态步幅规则】
  · 非常充裕 (TTFT<600ms 且 TPOT<15ms) → 步幅×2 (如1→2→4→8...)
  · 比较充裕 (TTFT<1000ms 且 TPOT<25ms) → 步幅×1.5 (如8→12→18...)
  · 接近限制 (TTFT<1600ms 或 TPOT<40ms) → 步幅×1 (如18→24→32...)
  · 接近临界 (TTFT<2000ms 或 TPOT<50ms) → 步幅÷2 (如32→36→40...)

【后续步骤】根据上一步结果动态决定下一步并发

======================================================================
  以上配置和测试方案是否确认？[Y/N]：
======================================================================
```

> **重要**：用户最终确认后，方可开始测试

### 第2步：检查服务状态（重要）

**⚠️ 严格警告：每次测试前必须执行此检查，否则测试结果无效！禁止跳过此步骤！**

**性能测试必须是串行的**：
- 多个性能测试同时运行会互相干扰，影响测试准确性
- 不同测试之间需等待至少30秒，确保上一个测试完全结束

**每次测试前【必须】执行以下全部检查（禁止跳过任何一项）**：

```bash
# 步骤1：检查是否有benchmark进程在运行（重要！）
ps aux | grep -E "vllm bench|aisbench" | grep -v grep
# 如果有进程，终止它：pkill -f "vllm bench"

# 步骤2：等待30秒确保进程完全结束
sleep 30

# 步骤3：检查NPU占用情况
npu-smi info

# 步骤4：检查是否有vllm进程正在服务
ps aux | grep vllm | grep -v grep

# 步骤5：确认服务API可访问
curl -s http://${HOST}:${PORT}/v1/models | grep -q "model" && echo "服务正常"
```

> **⚠️ 强制要求**：
> - 以上5个步骤【必须全部执行】，缺一不可
> - 如果发现其他测试在运行，必须等待或终止后再测试
> - 终止命令：`pkill -f "vllm bench"`
> - 只有全部检查通过后才能开始测试

### 第3步：执行性能测试并寻优

#### 5.1 寻优参数定义

寻优过程中，以下参数均可作为搜索维度，**需要联合分析**：

| 参数 | 说明 | 最小步长 | 初始值 | 调整范围 |
|------|------|---------|--------|---------|
| 并发数(concurrency) | 同时发送的请求数 | 1 | 1 | 1~N |
| 请求频率(request_rate) | 每秒发送的请求数 | 0.1 | 0 | 0=全并发 或 具体RPS |

> **重要**：并发数和请求频率互相影响：
> - `request_rate=0` 表示同时发送所有请求，此时实际并发等于请求数
> - `request_rate>0` 时，实际并发 = min(并发数, request_rate × 时间)
> - 寻优时需要**同时遍历**两个参数的组合

#### 5.2 终止条件判断

寻优终止条件：**TTFT和TPOT同时满足要求，且调整任一可调参数（并发或请求频率）都会导致指标不满足**

```
终止条件 = (TTFT < TTFT目标 AND TPOT < TPOT目标) AND 
           ((调整并发±1后 不满足约束) OR (调整请求频率±步长后 不满足约束))
```

> **说明**：只有当**同时**满足以下条件时才能终止：
> 1. 当前配置满足TTFT和TPOT目标
> 2. 降低或增加并发都无法满足目标
> 3. 降低或增加请求频率都无法满足目标

#### 5.3 寻优流程

> **双参数寻优策略**：并发数和请求频率需要联合搜索

```
开始
  ↓
初始化: 并发=1, 请求频率=初始值(0=全并发)
  ↓
执行测试(并发, 请求频率)组合
  ↓
┌─ 分析结果 ──────────────────────┐
│ 判断: TTFT<T目标 AND TPOT<T目标 │
└────────────────────────────────┘
       ↓                    ↓
     通过                  不通过
       ↓                    ↓
┌──────────────────┐   ┌──────────────────────────┐
│ 记录当前配置     │   │ 判断是否已找到            │
│ 尝试调整:       │   │ 更高参数值的通过配置     │
│   - 并发±1      │   │                          │
│   - 请求频率±步长│  │ 是→以该配置为起点继续    │
│                 │   │ 否→降低参数或结束       │
│ 判断: 通过?     │   │                          │
└────────┬────────┘   └──────────────────────────┘
          │
          ↓
     ┌───────────────┐
     │ 验证终止条件   │
     │ (并发±1 且    │
     │  请求频率±步长)│
     └───────┬───────┘
          ↓        ↓
       满足      不满足
          ↓        ↓
        结束     继续搜索
```

**寻优策略建议**：
1. 先固定请求频率=0（全并发），搜索最优并发
2. 再以最优并发为基础，尝试不同请求频率
3. 最后在最优邻域内联合验证

> **⚠️ 关键：寻优逻辑必须正确**
> 
> 当配置A满足约束、配置B不满足约束时：
> - 如果A=128满足、B=256不满足 → **最优在128-256之间**，继续搜索128-256区间
> - 如果A=64满足、B=128不满足 → **最优在64-128之间**，继续搜索64-128区间
> - **不能跳过区间直接测其他值**

#### 5.4 寻优结果分析（重要）

每次获得测试结果后，必须进行以下分析：

**步骤1：数据汇总表（联合分析并发和请求频率）**

> **原则**：测试结果汇总应完整且真实，保留所有指标数据

| 并发 | 请求频率 | TTFT均值 | TTFT中位数 | TTFT P99 | TTFT最大 | TPOT均值 | TPOT中位数 | TPOT P99 | TPOT最大 | QPS | 请求吞吐 | 输入吞吐 | 输出吞吐 | 总吞吐 | 请求失败 | TTFT达标 | TPOT达标 | 状态 |
|------|---------|----------|------------|----------|----------|----------|------------|----------|----------|-----|----------|----------|----------|--------|----------|----------|----------|------|
| 1 | 0 | | | | | | | | | | | | | | | ✅/❌ | ✅/❌ | |
| 2 | 0 | | | | | | | | | | | | | | | ✅/❌ | ✅/❌ | |
| ... | ... | | | | | | | | | | | | | | | | | |
| N | 0 | | | | | | | | | | | | | | | ✅/❌ | ✅/❌ | |
| N | 1.0 | | | | | | | | | | | | | | | ✅/❌ | ✅/❌ | |

**指标说明**：

| 指标 | 说明 | 来源 |
|------|------|------|
| TTFT均值/中位数/P99/最大 | 首 token 时间 (Time To First Token) | mean_ttft_ms, median_ttft_ms, p99_ttft_ms, max_ttft_ms |
| TPOT均值/中位数/P99/最大 | 每 token 输出时间 (Time Per Output Token) | mean_tpot_ms, median_tpot_ms, p99_tpot_ms, max_tpot_ms |
| QPS | 每秒成功完成请求数 | qps |
| 请求吞吐 | 每秒处理的请求数 | request_throughput |
| 输入吞吐 | 每秒处理的输入 token 数 | input_throughput |
| 输出吞吐 | 每秒生成的输出 token 数 | output_throughput |
| 总吞吐 | 每秒处理的 token 总数 | total_token_throughput |
| 请求失败 | 失败的请求数 | failures |

**步骤2：绘制趋势**

- TTFT随并发/请求频率变化的趋势
- TPOT随并发/请求频率变化的趋势  
- QPS随并发/请求频率变化的趋势（3D曲面或等高线图更佳）

**步骤3：判断是否满足约束**

- 筛选出所有 TTFT<TTFT目标 且 TPOT<TPOT目标 的配置
- 如果没有满足要求的配置，输出分析报告说明无法满足要求

**步骤4：确定最优配置**

```
最优配置 = 满足约束(TTFT和TPOT)的 (并发, 请求频率) 组合中 QPS 最高的那个
```

**步骤5：动态决定下一次并发数（重要）**

> **⚠️ 严格禁止使用固定倍数列表（如1,2,4,8,16）！每次测试后必须根据结果分析决定下一次并发**

#### 5.5.1 步幅计算规则

根据当前测试结果距离目标的余量，动态决定步幅：

| 距离目标余量 | 判断条件 | 步幅策略 |
|------------|---------|---------|
| **非常充裕** | TTFT < 目标×30% 且 TPOT < 目标×30% | 步幅×2（如16→32→64...） |
| **比较充裕** | TTFT < 目标×50% 且 TPOT < 目标×50% | 步幅×1.5（如16→24→36...） |
| **接近限制** | TTFT < 目标×80% 或 TPOT < 目标×80% | 步幅×1（如16→24→32...） |
| **接近临界** | TTFT < 目标 或 TPOT < 目标 | 步幅减半（如16→20→24...） |

> **示例**：目标TTFT<1000ms, TPOT<40ms
> - 并发=8: TTFT=150ms, TPOT=10ms → 距离目标非常充裕 → 步幅翻倍 → 并发=16
> - 并发=16: TTFT=280ms, TPOT=18ms → 比较充裕 → 步幅×1.5 → 并发=24
> - 并发=24: TTFT=450ms, TPOT=28ms → 接近限制 → 步幅1 → 并发=32
> - 并发=32: TTFT=680ms, TPOT=35ms → 接近临界 → 步幅减半 → 并发=36

#### 5.5.2 完整动态调整流程

根据当前测试结果，按以下规则决定下一次并发：

| 当前状态 | 下一步并发选择策略 |
|---------|-------------------|
| **TTFT和TPOT都满足** | 根据余量计算步幅，继续测试直到刚好不满足 |
| **TTFT或TPOT不满足，且之前有满足的配置** | 在最近满足和不满足的并发数之间做二分搜索 |
| **TTFT或TPOT不满足，且之前没有满足的配置** | 降低并发继续测试 |
| **连续2次满足且QPS下降** | 已经在最优点附近，回退到上一个满足且QPS最高的配置 |

**动态调整示例**：

```
初始：并发=1 → 满足（TTFT=50,TPOT=8）→ 距离充裕×2 → 并发=2
并发=2 → 满足（TTFT=80,TPOT=12）→ 距离充裕×2 → 并发=4
并发=4 → 满足（TTFT=150,TPOT=18）→ 比较充裕×1.5 → 并发=6
并发=6 → 满足（TTFT=220,TPOT=25）→ 接近限制×1 → 并发=8
并发=8 → 满足（TTFT=350,TPOT=32）→ 接近临界÷2 → 并发=10
并发=10 → 满足（TTFT=500,TPOT=38）→ 接近临界÷2 → 并发=11
并发=11 → 不满足 → 区间在10-11之间
二分搜索：并发=10 → 最优
```

**步骤6：验证终止条件（关键）**

找到最优配置后，必须验证**所有可调参数**：

```
终止条件满足 = (调整并发±1后 不满足约束) AND (调整请求频率±步长后 不满足约束)
```

即：只有当**同时**满足以下条件才能终止：
1. 降低或增加并发都无法满足目标
2. 降低或增加请求频率都无法满足目标

如果终止条件满足，说明已找到最优值；
如果不满足，说明还可以继续优化，需要扩大搜索范围。

> **⚠️ 验证终止条件时必须测试邻域配置**：
> - 并发-1 和 并发+1
> - 请求频率-0.5 和 请求频率+0.5（如果之前没测过）

**示例分析**（联合搜索并发和请求频率）：

假设测试结果如下（TTFT目标<2000ms, TPOT目标<50ms）：

| 并发 | 请求频率 | TTFT均值 | TTFT P99 | TPOT均值 | TPOT P99 | QPS | 请求吞吐 | 输入吞吐 | 输出吞吐 | 总吞吐 | 失败 | 状态 |
|------|---------|----------|----------|----------|----------|-----|----------|----------|----------|--------|------|------|
| 64 | 0 | 520 | 680 | 38 | 45 | 12.5 | 12.5 | 3200 | 1600 | 4800 | 0 | ✅ |
| 96 | 0 | 780 | 1050 | 42 | 50 | 14.2 | 14.2 | 4600 | 2300 | 6900 | 0 | ✅ |
| 128 | 0 | 1100 | 1450 | 46 | 55 | 15.1 | 15.1 | 5800 | 2900 | 8700 | 0 | ✅ |
| 128 | 1.0 | 950 | 1280 | 44 | 52 | 14.8 | 14.8 | 5500 | 2750 | 8250 | 0 | ✅ |
| 128 | 2.0 | 820 | 1100 | 42 | 48 | 14.2 | 14.2 | 5200 | 2600 | 7800 | 0 | ✅ |
| 160 | 0 | 1450 | 1900 | 52 | 62 | 14.0 | 14.0 | 5100 | 2550 | 7650 | 2 | ❌ TPOT超 |
| 192 | 0 | 1800 | 2400 | 58 | 70 | 12.5 | 12.5 | 4500 | 2250 | 6750 | 5 | ❌ TTFT/TPOT超 |

分析：
1. 满足约束的配置：64,96,128系列
2. 最优配置：并发=128, 请求频率=0, QPS=15.1
3. 验证终止条件：
   - 并发127: 需要测试（未测）
   - 并发129: 需要测试（未测）
   - 请求频率0.5: 需要测试（未测）
   - 请求频率1.5: 需要测试（未测）
4. 结论：如所有邻域配置都不满足约束，则128,0为最优

**输出格式**：

```
=== 寻优分析报告 ===

测试条件：TTFT<{目标}ms, TPOT<{目标}ms

测试结果汇总：
| 并发 | 请求频率 | TTFT均值 | TTFT P99 | TPOT均值 | TPOT P99 | QPS | 请求吞吐 | 输入吞吐 | 输出吞吐 | 失败数 | 状态 |
|------|---------|----------|----------|----------|----------|-----|----------|----------|----------|--------|------|
...

满足约束的配置：[列表]

最优配置：并发={N}, 请求频率={R}, QPS={X}, TTFT={Y}ms, TPOT={Z}ms

终止条件验证：
- 并发{N-1}: {满足/不满足}约束
- 并发{N+1}: {满足/不满足}约束
- 请求频率{R-步长}: {满足/不满足}约束
- 请求频率{R+步长}: {满足/不满足}约束

结论：{已找到最优值 / 需要继续搜索}
```

#### 5.5 执行测试（vLLM benchmark）

> **⚠️ 严格警告：每次执行测试前必须执行完整检查流程，禁止跳过！**

**测试前检查流程（必须全部执行）**：

```
步骤1：参数校验（每次必做）
  - 检查 num-prompts >= max-concurrency（否则测试无效）
  - 按照用户确认的"测试数据条数"参数校验实际数量
  - 如果不满足用户要求，修正参数后再执行

步骤2：进程检查
  - 执行 `ps aux | grep -E "vllm bench|aisbench" | grep -v grep` 确认无其他测试
  - 如有进程在运行，等待或终止后再测

步骤3：间隔等待
  - 测试之间间隔30秒
```

**参数校验原则**：
```
# ⚠️ 严格规则：数据条数必须按用户确认的规则计算
# 用户可能指定：
# - 具体数值（如 100）→ 固定使用
# - 公式（如 "最大并发×3"）→ 动态计算
# - "根据并发自动计算" → num-prompts = max-concurrency × 3

# 每次测试前必须校验：
num_prompts_needed = max_concurrency * MULTIPLIER  # 用户指定的倍数
if actual_num_prompts != num_prompts_needed:
    print(f"⚠️ 错误: 用户要求num-prompts={num_prompts_needed}，实际为{actual_num_prompts}")
    print(f"必须修正为: num-prompts={num_prompts_needed}")
    # 禁止跳过！必须使用正确值重新执行
```

首先检查vLLM版本：

```bash
# 在测试容器中检查vLLM版本
docker exec ${CONTAINER_NAME} vllm --version

# 或查看vllm bench帮助确认版本
docker exec ${CONTAINER_NAME} vllm bench --help
```

##### v0.17.0+ 版本（推荐）

```bash
# 单次测试（使用openai后端 + completions接口）
docker exec ${CONTAINER_NAME} vllm bench serve \
  --backend openai \
  --model ${MODEL_NAME} \
  --base-url http://${HOST}:${PORT}/v1 \
  --endpoint /completions \
  --num-prompts ${NUM_PROMPTS} \
  --max-concurrency ${CONCURRENCY} \
  --random-input-len ${INPUT_LEN} \
  --random-output-len ${OUTPUT_LEN} \
  --tokenizer /path/to/model \
  --save-result \
  --result-dir /tmp/benchmark_results/iter_${ITER_NO}
```

**参数说明**：
| 参数 | 说明 |
|------|------|
| --backend | 测试后端（openai用于completions, openai-chat用于chat接口） |
| --base-url | 服务基础URL |
| --endpoint | API端点（/completions 或 /chat/completions） |
| --max-concurrency | 最大并发数 |
| --random-input-len | 输入长度 |
| --random-output-len | 输出长度 |
| --tokenizer | 本地tokenizer路径（网络不通时必须指定） |

> **⚠️ 重要提醒：并发数设置规则**
> 
> `max-concurrency` 必须小于等于 `num-prompts`，否则实际并发等于 max-concurrency，无法测试高并发场景。
> 
> 例如：`--num-prompts 50 --max-concurrency 1000` 实际最大并发只有50（测试无效）
> 
> 正确设置：高并发测试必须 `num-prompts >= max-concurrency`
> - 测试并发128：`--num-prompts 200 --max-concurrency 128`
> - 测试并发256：`--num-prompts 300 --max-concurrency 256`

##### v0.13.0 版本

```bash
# 单次测试
python -m vllm.benchmark_serving \
  --host ${HOST} \
  --port ${PORT} \
  --model ${MODEL_NAME} \
  --backend vllm \
  --num-prompts ${NUM_PROMPTS} \
  --concurrency ${CONCURRENCY} \
  --input-len ${INPUT_LEN} \
  --output-len ${OUTPUT_LEN} \
  --save-result \
  --result-dir ./benchmark_results/iter_${ITER_NO}
```

#### 5.6 执行测试（AISBench）

> **重要：AISBench测试容器环境要求**
> - 容器需要挂载模型权重路径：`/home/weights:/home/weights`
> - 容器需要挂载Ascend相关路径确保CANN可用
> - 模型名称必须与服务返回的`/v1/models`接口中的`id`一致（注意带完整路径如`/home/weights/Qwen3-VL-4B-Instruct`）

> **注意：AISBench数据集会自动下载到容器内**  
> 如果测试过程中报数据集不存在，需要在容器内预下载或使用synthetic（合成）数据集

**推荐：使用SyntheticDataset进行性能测试（无需外部数据集）**

```python
# 完整的AISBench性能测试配置示例
from ais_bench.benchmark.models import VLLMCustomAPIChat
from ais_bench.benchmark.datasets import SyntheticDataset
from ais_bench.benchmark.openicl.icl_prompt_template import PromptTemplate
from ais_bench.benchmark.openicl.icl_retriever import ZeroRetriever
from ais_bench.benchmark.openicl.icl_inferencer import GenInferencer

models = [
    dict(
        attr="service",
        type=VLLMCustomAPIChat,
        abbr="vllm-perf-test",
        path="/home/weights/Qwen3-VL-4B-Instruct",  # 模型权重路径（用于tokenizer）
        model="/home/weights/Qwen3-VL-4B-Instruct",  # 模型名称（必须与/v1/models返回的id一致）
        request_rate=0,  # 0=全并发，或具体RPS值
        retry=2,
        host_ip="${HOST}",  # 推理服务IP
        host_port=${PORT},  # 推理服务端口
        max_out_len=${OUTPUT_LEN},
        batch_size=${CONCURRENCY},  # 并发数
        trust_remote_code=False,
        generation_kwargs=dict(
            temperature=0.5,
            top_k=10,
            top_p=0.95,
            seed=None,
        ),
    )
]

datasets = [
    dict(
        abbr='synthetic',
        type=SyntheticDataset,
        path='ais_bench/datasets/synthetic',
        reader_cfg=dict(
            input_columns=['question'],
            output_column='answer'
        ),
        infer_cfg=dict(
            prompt_template=dict(
                type=PromptTemplate,
                template="{question}"
            ),
            retriever=dict(type=ZeroRetriever),
            inferencer=dict(type=GenInferencer, is_synthetic=True)
        ),
        eval_cfg=dict()
    )
]
```

```bash
# 执行性能测试
ais_bench /path/to/config.py --mode perf --num-prompts ${NUM_PROMPTS} -w /tmp/aisbench_results
```

**常用参数说明：**
| 参数 | 说明 |
|------|------|
| model | 模型名称，**必须与API返回的id一致** |
| path | tokenizer路径，用于性能测试时tokenize |
| host_ip | 推理服务IP |
| host_port | 推理服务端口 |
| max_out_len | 最大输出token数 |
| batch_size | 并发数 |
| request_rate | 请求速率，0=全并发 |

**错误排查：**
1. `The model 'xxx' does not exist` → 模型名不匹配，检查`curl http://host:port/v1/models`返回的id
2. `libascend_hal.so: cannot open shared object file` → 容器缺少CANN依赖，检查Ascend相关挂载
3. `Dataset path is not exist` → 使用synthetic数据集或预下载真实数据集

### 第6步：结果分析

#### 6.1 解析测试结果

> **⚠️ 重要：每次测试完成后必须生成Excel报告**

```bash
# 使用脚本生成Excel报告（测试完成后自动执行）
python scripts/generate_report.py --result-dir ./benchmark_results --target-ttft 2000 --target-tpot 50
```

> **报告必须包含的字段**：
> - 并发数、请求频率
> - TTFT均值、TTFT P99
> - TPOT均值、TPOT P99
> - QPS、请求吞吐、输入吞吐、输出吞吐、总吞吐
> - TTFT达标状态、TPOT达标状态
> - 标记满足约束的最优配置

```bash
# 提取完整指标（所有可用字段）
python -c "
import json
import glob
import os

results = []
for f in glob.glob('./benchmark_results/**/results.json', recursive=True):
    with open(f) as fp:
        data = json.load(fp)
        m = data.get('result_metrics', {})
        
        # 解析并发和请求频率（从目录名或配置中获取）
        iter_dir = os.path.dirname(f)
        iter_name = os.path.basename(iter_dir)
        
        r = {
            'iteration': iter_name,
            'concurrency': data.get('concurrency', 0),
            'request_rate': data.get('request_rate', 0),
            
            # TTFT 指标
            'ttft_mean': m.get('mean_ttft_ms', 0),
            'ttft_median': m.get('median_ttft_ms', 0),
            'ttft_p99': m.get('p99_ttft_ms', 0),
            'ttft_max': m.get('max_ttft_ms', 0),
            'ttft_min': m.get('min_ttft_ms', 0),
            
            # TPOT 指标
            'tpot_mean': m.get('mean_tpot_ms', 0),
            'tpot_median': m.get('median_tpot_ms', 0),
            'tpot_p99': m.get('p99_tpot_ms', 0),
            'tpot_max': m.get('max_tpot_ms', 0),
            'tpot_min': m.get('min_tpot_ms', 0),
            
            # 吞吐量指标
            'qps': m.get('qps', 0),
            'request_throughput': m.get('request_throughput', 0),
            'input_throughput': m.get('input_throughput', 0),
            'output_throughput': m.get('output_throughput', 0),
            'total_token_throughput': m.get('total_token_throughput', 0),
            
            # 请求级延迟
            'latency_mean': m.get('latency_mean_ms', 0),
            'latency_p50': m.get('latency_p50_ms', 0),
            'latency_p99': m.get('latency_p99_ms', 0),
            
            # 错误统计
            'failures': m.get('failures', 0),
            'total_requests': data.get('num_prompts', 0),
        }
        results.append(r)

target_ttft = ${TARGET_TTFT}  # ms
target_tpot = ${TARGET_TPOT}  # ms

print('=== 测试结果（完整指标）===')
print(f'并发 | 请求频率 | TTFT均值 | TTFT中位数 | TTFT P99 | TTFT最大 | TPOT均值 | TPOT中位数 | TPOT P99 | TPOT最大 | QPS | 请求吞吐 | 输入吞吐 | 输出吞吐 | 总吞吐 | 失败/总计 | 状态')
print('-' * 200)
for r in sorted(results, key=lambda x: (x['concurrency'], x['request_rate'])):
    status = '通过' if r['ttft_mean'] < target_ttft and r['tpot_mean'] < target_tpot else '不通过'
    print(f\"{r['concurrency']:4d} | {r['request_rate']:5.1f} | {r['ttft_mean']:8.1f} | {r['ttft_median']:9.1f} | {r['ttft_p99']:7.1f} | {r['ttft_max']:7.1f} | {r['tpot_mean']:8.1f} | {r['tpot_median']:9.1f} | {r['tpot_p99']:7.1f} | {r['tpot_max']:7.1f} | {r['qps']:5.2f} | {r['request_throughput']:8.2f} | {r['input_throughput']:8.2f} | {r['output_throughput']:8.2f} | {r['total_token_throughput']:8.2f} | {r['failures']:3d}/{r['total_requests']:3d} | {status}\")
"
```

> **注意**：不同版本的 vLLM benchmark 输出的字段可能略有差异，以上代码会尝试读取所有可用字段，字段不存在时默认为 0

#### 6.2 寻优判断逻辑

```python
def check_termination(results, target_ttft, target_tpot):
    """
    检查是否满足终止条件（联合验证并发和请求频率）
    终止条件: TTFT和TPOT都满足要求，且微调任一参数会导致不满足
    """
    # 找到所有满足要求的配置
    valid = [r for r in results if r['ttft_mean'] < target_ttft and r['tpot_mean'] < target_tpot]
    
    if not valid:
        return False, "无满足要求的配置"
    
    # 按QPS排序，找到最优
    best = max(valid, key=lambda x: x['qps'])
    best_conc = best['concurrency']
    best_rate = best['request_rate']
    
    # 检查并发方向：降低或增加并发是否会导致不满足
    lower_conc_valid = any(
        r['concurrency'] == best_conc - 1 and r['request_rate'] == best_rate and
        r['ttft_mean'] < target_ttft and r['tpot_mean'] < target_tpot 
        for r in results
    )
    higher_conc_valid = any(
        r['concurrency'] == best_conc + 1 and r['request_rate'] == best_rate and
        r['ttft_mean'] < target_ttft and r['tpot_mean'] < target_tpot 
        for r in results
    )
    
    # 检查请求频率方向：在相同并发下，调节请求频率是否还能满足
    rate_step = 0.5  # 请求频率调整步长
    lower_rate_valid = any(
        r['concurrency'] == best_conc and 
        abs(r['request_rate'] - max(0, best_rate - rate_step)) < 0.01 and
        r['ttft_mean'] < target_ttft and r['tpot_mean'] < target_tpot 
        for r in results
    )
    higher_rate_valid = any(
        r['concurrency'] == best_conc and 
        abs(r['request_rate'] - (best_rate + rate_step)) < 0.01 and
        r['ttft_mean'] < target_ttft and r['tpot_mean'] < target_tpot 
        for r in results
    )
    
    # 终止条件：当前是最优点，且两个方向调节都会导致不满足
    if not lower_conc_valid and not higher_conc_valid and not lower_rate_valid and not higher_rate_valid:
        return True, f"已找到最优配置: 并发={best_conc}, 请求频率={best_rate}, QPS={best['qps']:.2f}"
    else:
        return False, f"未达到最优，并发={best_conc},请求频率={best_rate}时QPS最高但可继续调整"
```

### 第7步：生成测试报告

> **提示**：可直接使用 `scripts/generate_report.py` 脚本生成报告

```bash
# 使用脚本生成Excel报告
python scripts/generate_report.py --result-dir ./benchmark_results --target-ttft 2000 --target-tpot 50
```

#### 7.2 测试截图处理

如需在Excel中包含测试截图：

```python
# 在Excel中添加截图sheet
ws_screenshot = wb.create_sheet("测试截图")

# 插入图片
img = Image('test_screenshot.png')
ws_screenshot.add_image(img, 'A1')
```

---

## 寻优示例

### 示例：Qwen3-VL-4B-Instruct 性能测试（输入512tok，输出256tok，目标TTFT<2000ms，TPOT<50ms）

> **注意**：以下为示例数据，用于说明动态调整流程。实际测试结果取决于硬件、模型和服务配置。

```
测试配置：--num-prompts 必须 >= --max-concurrency（确保实际并发能达到设置值）

【动态调整寻优过程】（根据余量动态决定步幅）
初始：并发=1    → TTFT=68ms,  TPOT=28ms, QPS=0.54   ✓ 距离充裕×2
并发=2    → TTFT=85ms,  TPOT=29ms, QPS=1.00   ✓ 距离充裕×2
并发=4    → TTFT=102ms, TPOT=30ms, QPS=2.02   ✓ 距离充裕×2
并发=8    → TTFT=145ms, TPOT=30ms, QPS=3.32   ✓ 距离充裕×2
并发=16   → TTFT=178ms, TPOT=31ms, QPS=4.70   ✓ 比较充裕×1.5
并发=24   → TTFT=250ms, TPOT=32ms, QPS=7.20   ✓ 比较充裕×1.5
并发=36   → TTFT=380ms, TPOT=34ms, QPS=10.50  ✓ 比较充裕×1.5
并发=54   → TTFT=520ms, TPOT=36ms, QPS=13.20  ✓ 接近限制×1
并发=72   → TTFT=680ms, TPOT=38ms, QPS=14.50  ✓ 接近限制×1
并发=90   → TTFT=850ms, TPOT=40ms, QPS=14.80  ✓ 接近临界÷2
并发=100  → TTFT=980ms, TPOT=42ms, QPS=14.20  ✗ TPOT超

【二分搜索区间（90-100）】
并发=95   → TTFT=910ms, TPOT=41ms, QPS=14.60  ✗ TPOT超
并发=92   → TTFT=880ms, TPOT=39ms, QPS=14.75  ✓ 接近临界÷2
并发=91   → TTFT=865ms, TPOT=39ms, QPS=14.78  ✓ 最优点

【终止验证】
并发=90   → TTFT=850ms, TPOT=40ms, QPS=14.80  ✓ QPS更高，回退
并发=92   → TTFT=880ms, TPOT=39ms, QPS=14.75  ✗ 不再测试

结论: 最优配置为并发=90, QPS=14.80, TTFT=850ms<2000ms, TPOT=40ms=目标

结论: 最优配置为并发=128, QPS=15.10, TTFT=890ms<2000ms, TPOT=39ms<50ms
     终止条件满足：并发127和129时QPS均低于最优值
```

### 并发与TTFT/TPOT关系总结

| 并发范围 | TTFT趋势 | TPOT趋势 | 说明 |
|---------|---------|---------|------|
| 1-64 | 逐渐增加 | 稳定<35ms | 性能线性增长 |
| 64-128 | 快速增加 | 略有增加 | 吞吐量持续上升 |
| 128-160 | 继续增加 | 接近限制 | 最优区间，QPS达峰值 |
| 160+ | 急剧增加 | 超过限制 | 服务压力过大，指标超标 |

> **寻优策略**：
> 1. 初始并发=1，测试后根据结果动态决定下一步
> 2. 满足约束时翻倍继续测试（1→2→4→8...），直到刚好不满足
> 3. 在临界区间做二分搜索定位最优
> 4. 验证：在最优值附近±1验证终止条件

---

## 常见问题

> **官方文档参考**：
> - vLLM benchmark: https://docs.vllm.ai/en/latest/cli/bench/serve/
> - AISBench: https://ais-bench-benchmark.readthedocs.io/zh-cn/latest/base_tutorials/all_params/cli_args.html#id2
> 
> 如果遇到参数或选项问题，请首先查阅官方文档

### Q: 测试失败提示连接超时

A: 检查服务是否正常运行：
```bash
curl http://${HOST}:${PORT}/v1/models
```

### Q: Bash命令执行超时 (Tool execution aborted)

A: ⚠️ **严格禁止直接同步执行长时间测试命令！**

vLLM性能测试耗时较长（5k输入1k输出可能需要5-10分钟），默认的bash超时(300秒)不够。**必须使用后台执行方式**：

1. **必须使用后台执行**：
```bash
# 后台执行测试
nohup vllm bench serve ... > /tmp/bench.log 2>&1 &
echo $! > /tmp/bench.pid

# 异步检查进度
for i in {1..60}; do
  sleep 30
  if ! kill -0 $(cat /tmp/bench.pid) 2>/dev/null; then
    break  # 测试结束
  fi
  tail -20 /tmp/bench.log
done

# 读取最终结果
cat /tmp/bench.log | tail -50
```
```bash
# 后台执行测试
nohup vllm bench serve ... > /tmp/bench.log 2>&1 &
echo $! > /tmp/bench.pid

# 异步检查进度
for i in {1..60}; do
  sleep 30
  if ! kill -0 $(cat /tmp/bench.pid) 2>/dev/null; then
    break  # 测试结束
  fi
  tail -20 /tmp/bench.log
done

# 读取最终结果
cat /tmp/bench.log | tail -50
```

> 注意：vLLM benchmark测试时间取决于输入输出长度和并发数，7k输入2k输出可能需要5-15分钟

### Q: TTFT过高

A: 
1. 检查NPU负载
2. 减少并发数
3. 降低输入长度

### Q: TPOT波动大

A: 检查是否有其他进程占用NPU资源

### Q: AISBench报错 "The model 'xxx' does not exist"

A: 
1. 先确认服务端的模型名称：
```bash
curl http://${HOST}:${PORT}/v1/models
```
2. 模型名称必须与返回的`id`完全一致（注意可能包含完整路径如`/home/weights/xxx`）
3. 修改配置文件中的`model`参数

### Q: AISBench报错 "libascend_hal.so: cannot open shared object file"

A: 
1. 容器缺少Ascend CANN依赖
2. 需要在容器启动时挂载：`/usr/local/Ascend:/usr/local/Ascend`
3. 或使用包含完整Ascend环境的容器

### Q: AISBench报错 "All requests failed"

A: 
1. 检查服务是否可访问：`curl http://${HOST}:${PORT}/v1/models`
2. 检查模型名称是否正确
3. 查看详细错误日志：`cat <work_dir>/logs/performances/<model>/<dataset>.out`

### Q: AISBench性能结果中没有TTFT/TPOT指标

A: AISBench结果包含：
- `seq_latency`: 端到端延迟
- `prefill_latency`: 预填充延迟（首token相关）
- `OutputTokenThroughput`: 输出token吞吐量，可推算TPOT
- 可通过h5文件获取详细时序数据

---

## 参数说明

> **完整参数列表请查阅官方文档**

常用参数：
- vLLM: `--model`, `--max-concurrency`, `--num-prompts`, `--random-input-len`, `--random-output-len`, `--request-rate`
- AISBench: `model`, `batch_size`, `request_rate`, `max_out_len`