#!/bin/bash
# Qwen3-8B vLLM-Ascend 完整部署与测试流程脚本

set -e

echo "========================================"
echo "Qwen3-8B vLLM-Ascend 完整部署与测试流程"
echo "========================================"

# 默认参数
MODEL_PATH="/data/models/Qwen3-8B"
SERVICE_PORT=8000
CONTAINER_NAME="vllm-ascend-qwen3"
CONCURRENCY_LIST="1 2 4 8 10"
DURATION=30
OUTPUT_DIR="./test_results"

# 解析命令行参数
while getopts "p:o:c:n:d:h" opt; do
  case $opt in
    p) MODEL_PATH="$OPTARG" ;;
    o) SERVICE_PORT="$OPTARG" ;;
    c) CONCURRENCY_LIST="$OPTARG" ;;
    n) CONTAINER_NAME="$OPTARG" ;;
    d) OUTPUT_DIR="$OPTARG" ;;
    h) echo "Usage: $0 [-p model_path] [-o service_port] [-c concurrency_list] [-n container_name] [-d output_dir]" && exit 0 ;;
    *) echo "Invalid option -$OPTARG" >&2 && exit 1 ;;
  esac
done

echo "\n流程参数："
echo "- 模型路径：$MODEL_PATH"
echo "- 服务端口：$SERVICE_PORT"
echo "- 容器名称：$CONTAINER_NAME"
echo "- 并发数列表：$CONCURRENCY_LIST"
echo "- 测试时长：$DURATION 秒"
echo "- 结果输出：$OUTPUT_DIR"

# 确保脚本目录正确
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "\n========================================"
echo "步骤 1：部署 Qwen3-8B 模型服务"
echo "========================================"

# 执行部署脚本
"$SCRIPT_DIR/deploy_qwen3.sh" -p "$MODEL_PATH" -o "$SERVICE_PORT" -c "$CONTAINER_NAME"

echo "\n========================================"
echo "步骤 2：使用 AISBench 进行性能测试"
echo "========================================"

# 执行测试脚本
"$SCRIPT_DIR/run_aisbench.sh" -u "http://localhost:$SERVICE_PORT/v1/chat/completions" -c "$CONCURRENCY_LIST" -d "$DURATION" -o "$OUTPUT_DIR"

echo "\n========================================"
echo "步骤 3：分析测试结果并生成报告"
echo "========================================"

# 执行分析脚本
python3 "$SCRIPT_DIR/analyze_results.py" --result-dir "$OUTPUT_DIR" --output-dir "$OUTPUT_DIR"

echo "\n========================================"
echo "🎉 完整流程执行完成！"
echo "========================================"
echo "\n📋 总结："
echo "- 模型服务已部署在：http://localhost:$SERVICE_PORT"
echo "- 容器名称：$CONTAINER_NAME"
echo "- 测试结果已保存至：$OUTPUT_DIR"
echo "- 性能报告已生成在：$OUTPUT_DIR"
echo "\n📊 您可以查看测试报告了解详细性能指标"
echo "\n🔧 常用命令："
echo "- 查看服务状态：curl http://localhost:$SERVICE_PORT/health"
echo "- 查看容器日志：docker logs -f $CONTAINER_NAME"
echo "- 停止服务：docker stop $CONTAINER_NAME"
echo "- 重启服务：docker restart $CONTAINER_NAME"
