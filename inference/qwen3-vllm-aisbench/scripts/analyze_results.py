#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AISBench 测试结果分析脚本
"""

import os
import json
import argparse
import datetime
import matplotlib.pyplot as plt
import numpy as np
from typing import Dict, List, Tuple


def load_test_results(result_dir: str) -> List[Dict]:
    """加载所有测试结果"""
    results = []
    
    # 遍历结果目录，加载所有JSON文件
    for filename in os.listdir(result_dir):
        if filename.startswith("result_") and filename.endswith(".json"):
            filepath = os.path.join(result_dir, filename)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    # 从文件名提取并发数
                    concurrency = int(filename.split("_")[1].split(".")[0])
                    data["concurrency"] = concurrency
                    results.append(data)
            except Exception as e:
                print(f"⚠️ 加载文件 {filename} 失败: {str(e)}")
    
    # 按并发数排序
    results.sort(key=lambda x: x["concurrency"])
    return results


def extract_metrics(results: List[Dict]) -> List[Dict]:
    """提取关键性能指标"""
    metrics = []
    
    for result in results:
        concurrency = result["concurrency"]
        
        # 提取整体统计信息
        stats = result.get("stats", {})
        throughput = stats.get("throughput", 0)  # tokens/s
        success_rate = stats.get("success_rate", 0) * 100
        
        # 提取延迟信息
        latencies = stats.get("latencies", {})
        ttft = latencies.get("ttft", {}).get("mean", 0) * 1000  # 转换为 ms
        tpot = latencies.get("tpot", {}).get("mean", 0) * 1000  # 转换为 ms
        
        metrics.append({
            "concurrency": concurrency,
            "throughput": throughput,
            "ttft": ttft,
            "tpot": tpot,
            "success_rate": success_rate
        })
    
    return metrics


def generate_charts(metrics: List[Dict], output_dir: str) -> Dict[str, str]:
    """生成可视化图表"""
    charts = {}
    
    # 提取数据
    concurrencies = [m["concurrency"] for m in metrics]
    throughputs = [m["throughput"] for m in metrics]
    ttfts = [m["ttft"] for m in metrics]
    tpots = [m["tpot"] for m in metrics]
    
    # 1. 吞吐率随并发数变化
    plt.figure(figsize=(10, 6))
    plt.plot(concurrencies, throughputs, marker='o', linewidth=2, markersize=8)
    plt.title('Throughput vs Concurrency', fontsize=14)
    plt.xlabel('Concurrency', fontsize=12)
    plt.ylabel('Throughput (tokens/s)', fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.xticks(concurrencies)
    
    throughput_chart = os.path.join(output_dir, "throughput_vs_concurrency.png")
    plt.savefig(throughput_chart, dpi=300, bbox_inches='tight')
    plt.close()
    charts["throughput"] = throughput_chart
    
    # 2. 延迟随并发数变化
    plt.figure(figsize=(10, 6))
    plt.plot(concurrencies, ttfts, marker='s', linewidth=2, markersize=8, label='TTFT (ms)')
    plt.plot(concurrencies, tpots, marker='^', linewidth=2, markersize=8, label='TPOT (ms)')
    plt.title('Latency vs Concurrency', fontsize=14)
    plt.xlabel('Concurrency', fontsize=12)
    plt.ylabel('Latency (ms)', fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.xticks(concurrencies)
    plt.legend(fontsize=12)
    
    latency_chart = os.path.join(output_dir, "latency_vs_concurrency.png")
    plt.savefig(latency_chart, dpi=300, bbox_inches='tight')
    plt.close()
    charts["latency"] = latency_chart
    
    # 3. 成功率随并发数变化
    plt.figure(figsize=(10, 6))
    plt.plot(concurrencies, [m["success_rate"] for m in metrics], marker='D', linewidth=2, markersize=8, color='green')
    plt.title('Success Rate vs Concurrency', fontsize=14)
    plt.xlabel('Concurrency', fontsize=12)
    plt.ylabel('Success Rate (%)', fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.xticks(concurrencies)
    plt.ylim(95, 100)
    
    success_chart = os.path.join(output_dir, "success_rate_vs_concurrency.png")
    plt.savefig(success_chart, dpi=300, bbox_inches='tight')
    plt.close()
    charts["success_rate"] = success_chart
    
    return charts


def generate_report(metrics: List[Dict], charts: Dict[str, str], output_dir: str) -> str:
    """生成Markdown格式的测试报告"""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    report_filename = f"performance_report_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
    report_path = os.path.join(output_dir, report_filename)
    
    # 找出最优性能点
    best_throughput = max(metrics, key=lambda x: x["throughput"])
    best_latency = min(metrics, key=lambda x: x["ttft"])
    
    # 生成报告内容
    report_content = []
    report_content.append("# Qwen3-8B vLLM-Ascend 性能测试报告")
    report_content.append("")
    report_content.append(f"## 测试概述")
    report_content.append(f"- 测试时间：{timestamp}")
    report_content.append(f"- 测试工具：AISBench")
    report_content.append(f"- 模型：Qwen3-8B")
    report_content.append(f"- 部署方式：vllm-ascend v0.17.0rc1")
    report_content.append(f"- 测试环境：Atlas 800I A2 NPU")
    report_content.append("")
    
    report_content.append(f"## 性能指标")
    report_content.append("")
    report_content.append(f"| 并发数 | 吞吐率 (tokens/s) | TTFT (ms) | TPOT (ms) | 成功率 (%) |")
    report_content.append(f"|--------|-------------------|-----------|-----------|------------|")
    
    for metric in metrics:
        report_content.append(f"| {metric['concurrency']} | {metric['throughput']:.0f} | {metric['ttft']:.0f} | {metric['tpot']:.0f} | {metric['success_rate']:.1f} |")
    
    report_content.append("")
    report_content.append(f"## 最优性能分析")
    report_content.append(f"- **最高吞吐率**：{best_throughput['throughput']:.0f} tokens/s (并发数: {best_throughput['concurrency']})")
    report_content.append(f"- **最低TTFT**：{best_latency['ttft']:.0f} ms (并发数: {best_latency['concurrency']})")
    report_content.append(f"- **平均TPOT**：{np.mean([m['tpot'] for m in metrics]):.0f} ms")
    report_content.append(f"- **平均成功率**：{np.mean([m['success_rate'] for m in metrics]):.1f}%")
    report_content.append("")
    
    report_content.append(f"## 可视化分析")
    report_content.append("")
    
    if "throughput" in charts:
        report_content.append(f"### 吞吐率随并发数变化")
        report_content.append(f"![Throughput vs Concurrency]({os.path.basename(charts['throughput'])})")
        report_content.append("")
    
    if "latency" in charts:
        report_content.append(f"### 延迟随并发数变化")
        report_content.append(f"![Latency vs Concurrency]({os.path.basename(charts['latency'])})")
        report_content.append("")
    
    if "success_rate" in charts:
        report_content.append(f"### 成功率随并发数变化")
        report_content.append(f"![Success Rate vs Concurrency]({os.path.basename(charts['success_rate'])})")
        report_content.append("")
    
    report_content.append(f"## 结论与建议")
    report_content.append(f"1. 在并发数为 {best_throughput['concurrency']} 时，模型达到最高吞吐率 {best_throughput['throughput']:.0f} tokens/s")
    report_content.append(f"2. 随着并发数增加，TTFT 逐渐增加，TPOT 相对稳定")
    report_content.append(f"3. 整体成功率保持在较高水平（{np.mean([m['success_rate'] for m in metrics]):.1f}%）")
    report_content.append(f"4. 建议在生产环境中使用并发数 {best_throughput['concurrency']} 以获得最佳性能")
    report_content.append("")
    report_content.append(f"## 测试配置详情")
    report_content.append(f"- 输入长度：512 tokens")
    report_content.append(f"- 输出长度：512 tokens")
    report_content.append(f"- 温度参数：0.7")
    report_content.append(f"- Top-p：0.95")
    report_content.append(f"- Top-k：50")
    
    # 写入报告文件
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(report_content))
    
    return report_path


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="AISBench测试结果分析脚本")
    parser.add_argument("--result-dir", type=str, default="./test_results", help="测试结果目录")
    parser.add_argument("--output-dir", type=str, default="./test_results", help="报告输出目录")
    
    args = parser.parse_args()
    
    print("========================================")
    print("AISBench 测试结果分析")
    print("========================================")
    
    # 加载测试结果
    print(f"\n1. 加载测试结果...")
    results = load_test_results(args.result_dir)
    if not results:
        print("❌ 未找到测试结果文件")
        return
    print(f"✅ 加载了 {len(results)} 个测试结果")
    
    # 提取性能指标
    print("\n2. 提取性能指标...")
    metrics = extract_metrics(results)
    print("✅ 性能指标提取完成")
    
    # 生成可视化图表
    print("\n3. 生成可视化图表...")
    charts = generate_charts(metrics, args.output_dir)
    print(f"✅ 生成了 {len(charts)} 个图表")
    
    # 生成测试报告
    print("\n4. 生成测试报告...")
    report_path = generate_report(metrics, charts, args.output_dir)
    print(f"✅ 测试报告已生成：{report_path}")
    
    print("\n========================================")
    print("分析完成！")
    print("========================================")


if __name__ == "__main__":
    main()
