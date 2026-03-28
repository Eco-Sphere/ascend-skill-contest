#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
推理服务性能测试脚本
使用 vLLM benchmark 0.13.0 对推理服务进行性能测试
"""

import os
import sys
import json
import time
import argparse
import subprocess
import tempfile
import requests
from typing import List, Dict, Tuple, Any


def check_vllm_version() -> bool:
    """检查 vLLM benchmark 版本是否为 0.13.0"""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "vllm.benchmark", "--version"],
            capture_output=True,
            text=True,
            check=True
        )
        version = result.stdout.strip().split(" ")[-1]
        if version == "0.13.0":
            print("✅ vLLM benchmark 0.13.0 已就绪")
            return True
        else:
            print(f"❌ vLLM benchmark 版本错误: {version}，需要 0.13.0")
            return False
    except subprocess.CalledProcessError:
        print("❌ 未检测到 vLLM benchmark")
        return False


def check_service_availability(api_url: str) -> bool:
    """检查推理服务是否可达"""
    try:
        response = requests.get(f"{api_url}/health", timeout=5)
        if response.status_code == 200:
            print(f"✅ 推理服务 {api_url} 可正常访问")
            return True
        else:
            print(f"❌ 推理服务 {api_url} 返回状态码: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ 无法连接到推理服务 {api_url}: {str(e)}")
        return False


def download_dataset(dataset_name: str, save_dir: str = "./datasets") -> str:
    """下载测试数据集"""
    os.makedirs(save_dir, exist_ok=True)
    dataset_path = os.path.join(save_dir, f"{dataset_name}.jsonl")
    
    if os.path.exists(dataset_path):
        print(f"✅ 数据集 {dataset_name} 已存在: {dataset_path}")
        return dataset_path
    
    print(f"⏳ 正在下载数据集 {dataset_name}...")
    
    # 定义数据集下载链接
    dataset_urls = {
        "sharegpt": "https://huggingface.co/datasets/anon8231489123/ShareGPT_Vicuna_unfiltered/resolve/main/ShareGPT_V3_unfiltered_cleaned_split.json",
        "alpaca": "https://github.com/tatsu-lab/stanford_alpaca/raw/main/alpaca_data.json",
        "gsm8k": "https://huggingface.co/datasets/gsm8k/resolve/main/data/test.jsonl",
    }
    
    dataset_name_lower = dataset_name.lower()
    if dataset_name_lower not in dataset_urls:
        print(f"❌ 不支持的数据集: {dataset_name}")
        return ""
    
    try:
        response = requests.get(dataset_urls[dataset_name_lower], stream=True, timeout=300)
        response.raise_for_status()
        
        with open(dataset_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        print(f"✅ 数据集 {dataset_name} 下载完成: {dataset_path}")
        return dataset_path
    except requests.exceptions.RequestException as e:
        print(f"❌ 数据集 {dataset_name} 下载失败: {str(e)}")
        return ""


def run_vllm_benchmark(
    api_url: str,
    concurrency: int,
    input_len: int,
    output_len: int,
    temperature: float = 0.7,
    top_p: float = 0.95,
    dataset_path: str = "",
    duration: int = 30,
) -> Dict[str, Any]:
    """运行 vLLM benchmark 测试"""
    cmd = [
        sys.executable,
        "-m", "vllm.benchmark",
        "--api-url", api_url,
        "--concurrency", str(concurrency),
        "--input-len", str(input_len),
        "--output-len", str(output_len),
        "--temperature", str(temperature),
        "--top-p", str(top_p),
        "--duration", str(duration),
        "--json-output",
    ]
    
    if dataset_path:
        cmd.extend(["--dataset", dataset_path])
    
    print(f"📊 正在测试并发数: {concurrency}")
    print(f"   命令: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            timeout=300
        )
        
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"❌ 测试失败 (并发数 {concurrency}): {e.stderr}")
        return {}
    except json.JSONDecodeError:
        print(f"❌ 解析测试结果失败 (并发数 {concurrency})")
        return {}
    except subprocess.TimeoutExpired:
        print(f"❌ 测试超时 (并发数 {concurrency})")
        return {}


def run_performance_test(
    api_url: str,
    concurrency_range: Tuple[int, int],
    input_len_range: Tuple[int, int],
    output_len_range: Tuple[int, int],
    temperature: float = 0.7,
    top_p: float = 0.95,
    dataset_name: str = "",
    duration: int = 30,
) -> List[Dict[str, Any]]:
    """运行完整的性能测试"""
    # 检查环境
    if not check_vllm_version():
        return []
    
    if not check_service_availability(api_url):
        return []
    
    # 下载数据集
    dataset_path = ""
    if dataset_name:
        dataset_path = download_dataset(dataset_name)
        if not dataset_path:
            print("⚠️ 将使用默认数据集进行测试")
    
    # 运行测试
    results = []
    min_concurrency, max_concurrency = concurrency_range
    input_len = (input_len_range[0] + input_len_range[1]) // 2
    output_len = (output_len_range[0] + output_len_range[1]) // 2
    
    for concurrency in range(min_concurrency, max_concurrency + 1):
        result = run_vllm_benchmark(
            api_url=api_url,
            concurrency=concurrency,
            input_len=input_len,
            output_len=output_len,
            temperature=temperature,
            top_p=top_p,
            dataset_path=dataset_path,
            duration=duration,
        )
        
        if result:
            result["concurrency"] = concurrency
            results.append(result)
        
        # 测试间隔
        time.sleep(2)
    
    return results


def generate_report(results: List[Dict[str, Any]], config: Dict[str, Any]) -> str:
    """生成性能测试报告"""
    if not results:
        return "❌ 没有测试结果可生成报告"
    
    report = []
    report.append("# 推理服务性能测试报告")
    report.append("")
    report.append(f"## 测试概述")
    report.append(f"- 测试时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    report.append(f"- 测试工具: vLLM benchmark 0.13.0")
    report.append(f"- 测试服务: {config['api_url']}")
    report.append("")
    report.append(f"## 测试配置")
    report.append(f"- 数据集: {config.get('dataset_name', '默认')}")
    report.append(f"- 输入 token 数范围: {config['input_len_range']}")
    report.append(f"- 输出 token 数范围: {config['output_len_range']}")
    report.append(f"- 采样参数: temperature={config['temperature']}, top_p={config['top_p']}")
    report.append(f"- 并发数范围: {config['concurrency_range']}")
    report.append("")
    report.append(f"## 性能指标")
    report.append("")
    report.append(f"| 并发数 | 吞吐率 (requests/s) | TTFT (ms) | TPOT (ms) | 成功率 (%) |")
    report.append(f"|--------|---------------------|-----------|-----------|------------|")
    
    # 计算最优配置
    best_concurrency = 0
    best_throughput = 0
    
    for result in results:
        concurrency = result["concurrency"]
        throughput = result.get("throughput", 0)
        ttft = result.get("ttft", {}).get("mean", 0) * 1000  # 转换为 ms
        tpot = result.get("tpot", {}).get("mean", 0) * 1000  # 转换为 ms
        success_rate = result.get("success_rate", 0) * 100
        
        report.append(f"| {concurrency} | {throughput:.1f} | {ttft:.0f} | {tpot:.0f} | {success_rate:.1f} |")
        
        # 更新最优配置
        if throughput > best_throughput:
            best_throughput = throughput
            best_concurrency = concurrency
    
    report.append("")
    report.append(f"## 最优配置")
    report.append(f"- 最优并发数: {best_concurrency}")
    report.append(f"- 最优吞吐率: {best_throughput:.1f} requests/s")
    report.append("")
    report.append(f"## 分析与建议")
    report.append(f"- 服务在并发数 {best_concurrency} 时达到最优性能")
    
    # 检查是否满足用户要求
    if config.get("ttft_requirement"):
        ttft_requirement = config["ttft_requirement"]
        ttft_met = all(result.get("ttft", {}).get("mean", 0) * 1000 < ttft_requirement for result in results)
        report.append(f"- TTFT 要求: < {ttft_requirement}ms, {'满足' if ttft_met else '不满足'}")
    
    if config.get("tpot_requirement"):
        tpot_requirement = config["tpot_requirement"]
        tpot_met = all(result.get("tpot", {}).get("mean", 0) * 1000 < tpot_requirement for result in results)
        report.append(f"- TPOT 要求: < {tpot_requirement}ms, {'满足' if tpot_met else '不满足'}")
    
    report.append(f"- 建议在生产环境中使用并发数 {best_concurrency} 以获得最佳性能")
    
    return "\n".join(report)


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="推理服务性能测试脚本")
    parser.add_argument("--api-url", type=str, required=True, help="推理服务 API URL")
    parser.add_argument("--concurrency-min", type=int, default=1, help="最小并发数")
    parser.add_argument("--concurrency-max", type=int, default=10, help="最大并发数")
    parser.add_argument("--input-len-min", type=int, default=50, help="最小输入 token 数")
    parser.add_argument("--input-len-max", type=int, default=100, help="最大输入 token 数")
    parser.add_argument("--output-len-min", type=int, default=100, help="最小输出 token 数")
    parser.add_argument("--output-len-max", type=int, default=200, help="最大输出 token 数")
    parser.add_argument("--temperature", type=float, default=0.7, help="采样温度")
    parser.add_argument("--top-p", type=float, default=0.95, help="top-p 采样参数")
    parser.add_argument("--dataset", type=str, default="", help="测试数据集名称")
    parser.add_argument("--duration", type=int, default=30, help="每个并发数的测试时长（秒）")
    parser.add_argument("--ttft-requirement", type=float, default=0, help="TTFT 要求（ms）")
    parser.add_argument("--tpot-requirement", type=float, default=0, help="TPOT 要求（ms）")
    
    args = parser.parse_args()
    
    config = {
        "api_url": args.api_url,
        "concurrency_range": (args.concurrency_min, args.concurrency_max),
        "input_len_range": (args.input_len_min, args.input_len_max),
        "output_len_range": (args.output_len_min, args.output_len_max),
        "temperature": args.temperature,
        "top_p": args.top_p,
        "dataset_name": args.dataset,
        "ttft_requirement": args.ttft_requirement,
        "tpot_requirement": args.tpot_requirement,
    }
    
    print("🚀 开始推理服务性能测试")
    print("=" * 50)
    
    # 运行测试
    results = run_performance_test(
        api_url=args.api_url,
        concurrency_range=config["concurrency_range"],
        input_len_range=config["input_len_range"],
        output_len_range=config["output_len_range"],
        temperature=config["temperature"],
        top_p=config["top_p"],
        dataset_name=config["dataset_name"],
        duration=args.duration,
    )
    
    if results:
        print("=" * 50)
        print("📊 测试完成！生成性能报告如下：")
        print("=" * 50)
        
        report = generate_report(results, config)
        print(report)
        
        # 保存报告
        report_filename = f"performance_report_{time.strftime('%Y%m%d_%H%M%S')}.md"
        with open(report_filename, "w", encoding="utf-8") as f:
            f.write(report)
        
        print(f"\n✅ 报告已保存至: {report_filename}")
    else:
        print("❌ 测试失败，未生成任何结果")


if __name__ == "__main__":
    main()
