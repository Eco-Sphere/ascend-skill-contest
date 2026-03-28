#!/usr/bin/env python3
"""
report.py — 从 benchmark JSON 结果生成 Markdown 测试报告
用法: python3 report.py --result-dir ./results --output benchmark_report.md
"""

import argparse
import json
import os
import sys
from datetime import datetime

def load_results(result_dir):
    results = []
    for fname in sorted(os.listdir(result_dir)):
        if not fname.endswith(".json"):
            continue
        path = os.path.join(result_dir, fname)
        try:
            with open(path) as f:
                d = json.load(f)
            d["_file"] = fname
            results.append(d)
        except Exception:
            pass
    return results

def sla_status(val, threshold):
    if threshold is None or val is None:
        return "—"
    return "✅" if val <= threshold else "❌"

def generate_report(result_dir, output, sla_ttft=None, sla_tpot=None):
    results = load_results(result_dir)
    if not results:
        print(f"⚠️  {result_dir} 中未找到 JSON 结果文件")
        sys.exit(1)

    lines = []
    lines.append(f"# vLLM Benchmark 测试报告")
    lines.append(f"\n**生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"**结果目录**: `{result_dir}`")

    if sla_ttft or sla_tpot:
        lines.append(f"**SLA 约束**: TTFT < {sla_ttft or '—'} ms，TPOT < {sla_tpot or '—'} ms")

    # 读取寻优结论
    sla_env = os.path.join(result_dir, "sla_result.env")
    if os.path.exists(sla_env):
        env = dict(line.strip().split("=", 1) for line in open(sla_env) if "=" in line)
        lines.append(f"\n## 🏆 SLA 寻优结论")
        lines.append(f"- **最优并发数**: {env.get('BEST_CONCURRENCY', '—')}")
        lines.append(f"- **最优吞吐**: {env.get('BEST_THROUGHPUT', '—')} tok/s")

    lines.append(f"\n## 详细测试结果\n")
    lines.append("| Case | 并发 | 输入Token | 输出Token | 吞吐(tok/s) | TTFT均值(ms) | TTFT P99(ms) | TPOT均值(ms) | TPOT P99(ms) | TTFT达标 | TPOT达标 |")
    lines.append("|------|------|-----------|-----------|-------------|--------------|--------------|--------------|--------------|----------|----------|")

    best_tput = 0
    best_row = None

    for i, d in enumerate(results):
        concurrency   = d.get("max_concurrency", d.get("concurrency", "—"))
        input_len     = d.get("mean_input_length", d.get("random_input_len", "—"))
        output_len    = d.get("mean_output_length", d.get("random_output_len", "—"))
        tput          = d.get("output_throughput", None)
        ttft_mean     = d.get("mean_ttft_ms", None)
        ttft_p99      = d.get("p99_ttft_ms", None)
        tpot_mean     = d.get("mean_tpot_ms", None)
        tpot_p99      = d.get("p99_tpot_ms", None)

        ttft_ok = sla_status(ttft_mean, sla_ttft)
        tpot_ok = sla_status(tpot_mean, sla_tpot)

        def fmt(v, dec=1):
            return f"{v:.{dec}f}" if isinstance(v, (int, float)) else str(v)

        row = (f"| {i+1} | {concurrency} | {fmt(input_len,0)} | {fmt(output_len,0)} "
               f"| {fmt(tput)} | {fmt(ttft_mean)} | {fmt(ttft_p99)} "
               f"| {fmt(tpot_mean)} | {fmt(tpot_p99)} | {ttft_ok} | {tpot_ok} |")
        lines.append(row)

        if tput and tput > best_tput:
            best_tput = tput
            best_row = i + 1

    if best_row and not os.path.exists(sla_env):
        lines.append(f"\n> **最高吞吐** 出现在 Case {best_row}，为 {best_tput:.1f} tok/s")

    lines.append(f"\n---\n*由 vllm-benchmark skill report.py 自动生成*")

    report = "\n".join(lines)
    with open(output, "w") as f:
        f.write(report)

    print(f"✅ 报告已生成：{output}")
    print(report)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--result-dir", default="./results")
    parser.add_argument("--output",     default="benchmark_report.md")
    parser.add_argument("--sla-ttft",   type=float, default=None)
    parser.add_argument("--sla-tpot",   type=float, default=None)
    args = parser.parse_args()
    generate_report(args.result_dir, args.output, args.sla_ttft, args.sla_tpot)
