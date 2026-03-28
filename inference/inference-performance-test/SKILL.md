# 推理服务化性能测试 Skill

## 1. Skill 基本信息

| 项目 | 说明 |
|------|------|
| Skill 名称 | inference-performance-test |
| 版本 | 1.0.0 |
| 作者 | AI Assistant |
| 更新时间 | 2026-03-29 |
| 功能描述 | 使用 vLLM benchmark 0.13.0 对推理服务进行自动化性能测试，支持多模态测试、多种数据集和多测试用例 |

## 2. 使用场景

- 对推理服务进行自动化性能测试，包括吞吐率、延迟等关键指标
- 针对不同模型和配置进行性能对比分析
- 快速验证推理服务在不同负载下的性能表现
- 生成结构化的性能测试报告

## 3. 功能介绍

- ✅ 支持 vLLM benchmark 0.13.0 工具
- ✅ 支持多模态测试（文本/图像）
- ✅ 支持多种数据集（自动下载缺失数据集）
- ✅ 交互式参数配置
- ✅ 支持多测试用例并行执行
- ✅ 自动生成性能测试报告

## 4. 前置条件

- 已安装 vLLM benchmark 0.13.0
- 已启动待测试的推理服务
- 具备网络连接（用于下载数据集）

## 5. 使用说明

### 5.1 基本使用

**Prompt 示例：**
```
测试 http://localhost:8000 服务在满足 TTFT < 2s，TPOT < 50ms 情况下的最优吞吐。
```

### 5.2 详细交互流程

#### 步骤 1：确认测试环境

```
正在检查 vLLM benchmark 环境...
✅ vLLM benchmark 0.13.0 已就绪
请确认待测试的推理服务地址：
```

#### 步骤 2：选择测试方式

```
请选择测试方式：
1. 文本生成测试
2. 多模态测试（文本+图像）
```

#### 步骤 3：选择测试数据集

```
请选择测试数据集：
1. ShareGPT-50K
2. Alpaca-52K
3. custom (需提供路径)
```

#### 步骤 4：配置测试参数

```
请配置测试参数：
- 输入 token 数范围：[min, max]
- 输出 token 数范围：[min, max]
- 采样参数：
  - temperature: 0.7
  - top_p: 0.95
- 发送速率（请求/秒）：[min, max]
- 并发数范围：[min, max]
```

#### 步骤 5：确认测试用例

```
已配置以下测试用例：
1. 服务：http://localhost:8000，并发：1-10，输入：50-100token，输出：100-200token
2. 服务：http://localhost:8001，并发：1-5，输入：100-200token，输出：200-300token

是否开始测试？(y/n)
```

### 5.3 测试执行

```
开始执行测试用例 1...
正在测试并发数：1
正在测试并发数：2
...
正在测试并发数：10
测试用例 1 完成

开始执行测试用例 2...
...
所有测试用例执行完成！
```

## 6. 测试报告

### 6.1 报告结构

```
# 推理服务性能测试报告

## 测试概述
- 测试时间：2026-03-29 14:30:00
- 测试工具：vLLM benchmark 0.13.0
- 测试服务：http://localhost:8000

## 测试配置
- 数据集：ShareGPT-50K
- 输入 token 数：50-100
- 输出 token 数：100-200
- 采样参数：temperature=0.7, top_p=0.95

## 性能指标

| 并发数 | 吞吐率 (requests/s) | TTFT (ms) | TPOT (ms) | 成功率 (%) |
|--------|---------------------|-----------|-----------|------------|
| 1      | 12.5                | 850       | 32        | 100        |
| 2      | 23.8                | 920       | 35        | 100        |
| 5      | 56.2                | 1200      | 42        | 99.5       |
| 10     | 98.7                | 1850      | 48        | 98.2       |

## 最优配置
- 满足条件：TTFT < 2s，TPOT < 50ms
- 最优并发数：10
- 最优吞吐率：98.7 requests/s

## 分析与建议
- 服务在并发数 10 时达到最优性能
- TTFT 和 TPOT 均满足要求
- 建议在生产环境中使用并发数 8-10 以获得最佳性能
```

### 6.2 可视化图表（可选）

- 吞吐率随并发数变化曲线
- TTFT 随并发数变化曲线
- TPOT 随并发数变化曲线

## 7. 错误处理

### 7.1 常见错误

#### 错误 1：vLLM benchmark 未安装
```
❌ 未检测到 vLLM benchmark 0.13.0
请安装：pip install vllm[benchmark]==0.13.0
```

#### 错误 2：推理服务不可达
```
❌ 无法连接到推理服务：http://localhost:8000
请检查服务是否已启动或地址是否正确
```

#### 错误 3：数据集下载失败
```
❌ 数据集 ShareGPT-50K 下载失败
请检查网络连接或手动提供数据集路径
```

#### 错误 4：参数配置错误
```
❌ 输入参数错误：最小并发数不能大于最大并发数
请重新配置参数
```

### 7.2 错误恢复

- 环境错误：提供详细的安装/配置指导
- 网络错误：建议检查网络或使用本地数据集
- 参数错误：提供参数范围和格式示例

## 8. 高级功能

### 8.1 自定义测试脚本

```
# scripts/run_benchmark.py
import subprocess
import json

def run_benchmark(api_url, concurrency, input_len, output_len, temperature=0.7, top_p=0.95):
    cmd = [
        "python", "-m", "vllm.benchmark",
        "--api-url", api_url,
        "--concurrency", str(concurrency),
        "--input-len", str(input_len),
        "--output-len", str(output_len),
        "--temperature", str(temperature),
        "--top-p", str(top_p),
        "--json-output",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(result.stdout)
```

### 8.2 批量测试配置

```json
// scripts/batch_config.json
{
  "test_cases": [
    {
      "api_url": "http://localhost:8000",
      "concurrency_range": [1, 10],
      "input_len_range": [50, 100],
      "output_len_range": [100, 200],
      "sampling_params": {
        "temperature": 0.7,
        "top_p": 0.95
      }
    },
    {
      "api_url": "http://localhost:8001",
      "concurrency_range": [1, 5],
      "input_len_range": [100, 200],
      "output_len_range": [200, 300],
      "sampling_params": {
        "temperature": 0.8,
        "top_p": 0.9
      }
    }
  ]
}
```

## 9. 更新日志

| 版本 | 更新内容 | 更新时间 |
|------|----------|----------|
| 1.0.0 | 初始版本，支持基本性能测试功能 | 2026-03-29 |
