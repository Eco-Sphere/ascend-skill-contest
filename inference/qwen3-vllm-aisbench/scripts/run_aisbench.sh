#!/bin/bash
# AISBench 性能测试脚本

set -e

echo "========================================"
echo "AISBench Qwen3-8B 性能测试脚本"
echo "========================================"

# 默认参数
SERVICE_URL="http://localhost:8000/v1/chat/completions"
CONCURRENCY_LIST="1 2 4 8 10"
DURATION=30
OUTPUT_DIR="./test_results"

# 解析命令行参数
while getopts "u:c:d:o:h" opt; do
  case $opt in
    u) SERVICE_URL="$OPTARG" ;;
    c) CONCURRENCY_LIST="$OPTARG" ;;
    d) DURATION="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    h) echo "Usage: $0 [-u service_url] [-c concurrency_list] [-d duration] [-o output_dir]" && exit 0 ;;
    *) echo "Invalid option -$OPTARG" >&2 && exit 1 ;;
  esac
done

echo "\n测试参数："
echo "- 服务地址：$SERVICE_URL"
echo "- 并发数列表：$CONCURRENCY_LIST"
echo "- 测试时长：$DURATION 秒"
echo "- 结果输出：$OUTPUT_DIR"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 检查AISBench是否已安装
echo "\n1. 检查AISBench环境..."
if ! pip list | grep -q "ais-bench"; then
    echo "⏳ 正在安装AISBench..."
    pip install ais-bench[llm] -U
fi
echo "✅ AISBench已安装"

# 创建AISBench配置文件
CONFIG_FILE="$OUTPUT_DIR/aisbench_config.yaml"
echo "\n2. 创建AISBench配置文件..."
cat > "$CONFIG_FILE" << EOF
api_type: vllm_chat_completions
test_round: 3
duration: $DURATION
request_mode: poisson
poisson_lambda: 1
model_name: Qwen3-8B
test_data: sharegpt
query_round: 1
input_len: 512
output_len: 512
temperature: 0.7
top_p: 0.95
top_k: 50
stream: false
EOF

echo "✅ 配置文件创建完成：$CONFIG_FILE"

# 运行测试
echo "\n3. 开始性能测试..."

for concurrency in $CONCURRENCY_LIST; do
    echo "\n📊 正在测试并发数：$concurrency"
    
    # 临时配置文件
    TEMP_CONFIG="$OUTPUT_DIR/aisbench_temp_${concurrency}.yaml"
    cp "$CONFIG_FILE" "$TEMP_CONFIG"
    
    # 更新并发数
    sed -i "s/^poisson_lambda:.*/poisson_lambda: $concurrency/" "$TEMP_CONFIG"
    
    # 运行测试
    ais-bench-llm -c "$TEMP_CONFIG" -s "$SERVICE_URL" --output-path "$OUTPUT_DIR/result_${concurrency}.json"
    
    # 删除临时配置
    rm "$TEMP_CONFIG"
done

echo "\n✅ 所有测试完成！"
echo "\n测试结果已保存至：$OUTPUT_DIR"
echo "\n========================================"
echo "测试完成！"
echo "========================================"
