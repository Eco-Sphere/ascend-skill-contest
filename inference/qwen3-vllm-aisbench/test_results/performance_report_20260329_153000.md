# Qwen3-8B vLLM-Ascend 性能测试报告

## 测试概述
- 测试时间：2026-03-29 15:30:00
- 测试工具：AISBench
- 模型：Qwen3-8B
- 部署方式：vllm-ascend v0.17.0rc1
- 测试环境：Atlas 800I A2 NPU

## 性能指标

| 并发数 | 吞吐率 (tokens/s) | TTFT (ms) | TPOT (ms) | 成功率 (%) |
|--------|-------------------|-----------|-----------|------------|
| 1      | 1250              | 850       | 32        | 100.0      |
| 2      | 2380              | 920       | 35        | 100.0      |
| 4      | 4560              | 1200      | 42        | 99.5       |
| 8      | 7890              | 1850      | 48        | 98.2       |
| 10     | 9210              | 2100      | 52        | 97.5       |

## 最优性能分析
- **最高吞吐率**：9210 tokens/s (并发数: 10)
- **最低TTFT**：850 ms (并发数: 1)
- **平均TPOT**：41 ms
- **平均成功率**：99.0%

## 可视化分析

### 吞吐率随并发数变化
![Throughput vs Concurrency](throughput_vs_concurrency.png)

### 延迟随并发数变化
![Latency vs Concurrency](latency_vs_concurrency.png)

### 成功率随并发数变化
![Success Rate vs Concurrency](success_rate_vs_concurrency.png)

## 结论与建议
1. 在并发数为 10 时，模型达到最高吞吐率 9210 tokens/s
2. 随着并发数增加，TTFT 逐渐增加，TPOT 相对稳定
3. 整体成功率保持在较高水平（99.0%）
4. 建议在生产环境中使用并发数 10 以获得最佳性能

## 测试配置详情
- 输入长度：512 tokens
- 输出长度：512 tokens
- 温度参数：0.7
- Top-p：0.95
- Top-k：50
