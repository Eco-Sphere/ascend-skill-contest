#!/bin/bash
# AISBench 性能测试脚本

set -e

echo "========================================"
echo "AISBench Qwen3-32B 性能测试脚本"
echo "========================================"

# 默认参数
SERVICE_URL="http://localhost:8113/v1/chat/completions"
DATASETS=("ceval_gen_0_shot_cot_chat_prompt.py" "mmlu_gen_0_shot_cot_chat_prompt.py" "gpqa_gen_0_shot_str.py" "math500_gen_0_shot_cot_chat_prompt.py")
OUTPUT_DIR="./test_results"

# 解析命令行参数
while getopts "u:d:o:h" opt; do
  case $opt in
    u) SERVICE_URL="$OPTARG" ;;
    d) DATASETS=($OPTARG) ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    h) echo "Usage: $0 [-u service_url] [-d datasets] [-o output_dir]" && exit 0 ;;
    *) echo "Invalid option -$OPTARG" >&2 && exit 1 ;;
  esac
done

echo "\n测试参数："
echo "- 服务地址：$SERVICE_URL"
echo "- 测试数据集：${DATASETS[@]}"
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
echo "\n2. 配置AISBench..."
# 确保配置文件存在
ais_bench_config_dir="~/.ais_bench/configs/models/vllm_api"
mkdir -p "$ais_bench_config_dir"

# 创建或更新配置文件
vllm_config_file="$ais_bench_config_dir/vllm_api_general_chat.py"
cat > "$vllm_config_file" << EOF
from ais_bench.benchmark.models import VLLMCustomAPIChat
from ais_bench.benchmark.utils.model_postprocessors import extract_non_reasoning_content

models = [
    dict(
        attr="service",
        type=VLLMCustomAPIChat,
        abbr='vllm-api-general-chat',
        path="vllm-ascend/Qwen3-32B-W8A8",
        model="qwen3",
        request_rate=0,
        retry=2,
        host_ip="localhost",
        host_port=8113,
        max_out_len=4096,
        temperature=0.6,
        top_p=0.95,
        top_k=20,
        stream=False
    )
]
EOF

echo "✅ AISBench配置完成：$vllm_config_file"

# 运行测试
echo "\n3. 开始性能测试..."

for dataset in "${DATASETS[@]}"; do
    echo "\n📊 正在测试数据集：$dataset"
    
    # 运行测试
    ais_bench --models vllm_api_general_chat --datasets "$dataset" --summarizer default_perf --mode perf --output-path "$OUTPUT_DIR/result_${dataset%.py}.json"
done

echo "\n✅ 所有测试完成！"
echo "\n测试结果已保存至：$OUTPUT_DIR"
echo "\n========================================"
echo "测试完成！"
echo "========================================"
