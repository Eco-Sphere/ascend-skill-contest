# Supported Models on vLLM-Ascend

This document lists the models supported by vLLM-Ascend on Huawei Atlas servers.

## Officially Supported Models

### Qwen Series

| Model | Parameters | Memory (FP16) | Single NPU | Notes |
|-------|------------|---------------|------------|-------|
| Qwen2.5-0.5B-Instruct | 0.5B | ~1 GB | Yes | Lightweight, fast |
| Qwen2.5-1.5B-Instruct | 1.5B | ~3 GB | Yes | Good balance |
| Qwen2.5-3B-Instruct | 3B | ~6 GB | Yes | |
| Qwen2.5-7B-Instruct | 7B | ~14 GB | Yes | Popular choice |
| Qwen2.5-14B-Instruct | 14B | ~28 GB | Yes | |
| Qwen2.5-32B-Instruct | 32B | ~64 GB | Yes* | Requires low memory util |
| Qwen2.5-72B-Instruct | 72B | ~144 GB | No | Requires 2-4 NPUs (TP) |
| Qwen3-4B | 4B | ~8 GB | Yes | Latest generation |
| Qwen3-8B | 8B | ~16 GB | Yes | |
| Qwen3-14B | 14B | ~28 GB | Yes | |
| Qwen3-32B | 32B | ~64 GB | Yes* | |

### Llama Series

| Model | Parameters | Memory (FP16) | Single NPU | Notes |
|-------|------------|---------------|------------|-------|
| Llama-2-7b-hf | 7B | ~14 GB | Yes | |
| Llama-2-13b-hf | 13B | ~26 GB | Yes | |
| Llama-2-70b-hf | 70B | ~140 GB | No | Requires 2-4 NPUs |
| Llama-3-8B | 8B | ~16 GB | Yes | |
| Llama-3-70B | 70B | ~140 GB | No | Requires 2-4 NPUs |
| Llama-3.1-8B | 8B | ~16 GB | Yes | |
| Llama-3.1-70B | 70B | ~140 GB | No | Requires 2-4 NPUs |

### DeepSeek Series

| Model | Parameters | Memory (FP16) | Single NPU | Notes |
|-------|------------|---------------|------------|-------|
| deepseek-llm-7b-base | 7B | ~14 GB | Yes | |
| deepseek-llm-67b-base | 67B | ~134 GB | No | Requires 2-4 NPUs |
| DeepSeek-V2-Lite | 16B | ~32 GB | Yes* | MoE architecture |
| DeepSeek-R1-Distill-Qwen-7B | 7B | ~14 GB | Yes | Reasoning model |
| DeepSeek-R1-Distill-Qwen-32B | 32B | ~64 GB | Yes* | Reasoning model |

### Baichuan Series

| Model | Parameters | Memory (FP16) | Single NPU | Notes |
|-------|------------|---------------|------------|-------|
| Baichuan2-7B-Base | 7B | ~14 GB | Yes | |
| Baichuan2-13B-Base | 13B | ~26 GB | Yes | |

### Other Models

| Model | Parameters | Memory (FP16) | Single NPU | Notes |
|-------|------------|---------------|------------|-------|
| Yi-6B | 6B | ~12 GB | Yes | |
| Yi-34B | 34B | ~68 GB | No | Requires 2 NPUs |
| InternLM2-7B | 7B | ~14 GB | Yes | |
| InternLM2-20B | 20B | ~40 GB | Yes* | |
| GLM-4-9B | 9B | ~18 GB | Yes | |

## Model Architecture Support

vLLM-Ascend supports the following model architectures:

- `LlamaForCausalLM` - Llama, Llama2, Llama3, Yi, Vicuna
- `Qwen2ForCausalLM` - Qwen2, Qwen2.5
- `Qwen3ForCausalLM` - Qwen3 series
- `DeepseekV2ForCausalLM` - DeepSeek V2
- `DeepseekV3ForCausalLM` - DeepSeek V3
- `BaichuanForCausalLM` - Baichuan series
- `InternLM2ForCausalLM` - InternLM2
- `ChatGLMModel` - GLM series

## Quantized Models

vLLM-Ascend supports the following quantization formats:

| Format | Description | Support Status |
|--------|-------------|----------------|
| AWQ | Activation-aware Quantization | Supported |
| GPTQ | Post-training Quantization | Supported |
| FP8 | 8-bit Floating Point | Experimental |

## Memory Requirements

### Estimation Formula

```
Memory (GB) = Parameters (B) × 2 (FP16) × 1.1 (overhead)
```

### KV Cache Memory

Additional memory for KV cache:
- `max_model_len` × `max_num_seqs` × 2 × hidden_dim × 2 bytes

Example for Qwen2.5-7B:
- 4096 × 256 × 2 × 3584 × 2 ≈ 15 GB KV cache

### Recommended Settings

| Model Size | max_model_len | gpu_memory_utilization |
|------------|---------------|------------------------|
| < 7B | 8192 | 0.9 |
| 7B - 14B | 4096 | 0.8 |
| 14B - 32B | 4096 | 0.7 |
| 32B+ | 2048 | 0.6 |

## Model Download Sources

### Hugging Face
```bash
# Using huggingface-cli
pip install huggingface_hub
huggingface-cli download Qwen/Qwen2.5-7B-Instruct --local-dir /path/to/model

# Using git
git clone https://huggingface.co/Qwen/Qwen2.5-7B-Instruct
```

### ModelScope (China)
```bash
# Using modelscope
pip install modelscope
modelscope download --model Qwen/Qwen2.5-7B-Instruct --local_dir /path/to/model

# Or set environment variable
export VLLM_USE_MODELSCOPE=true
vllm serve Qwen/Qwen2.5-7B-Instruct
```

## References

- [vLLM-Ascend Documentation](https://docs.vllm.ai/projects/ascend/en/latest/)
- [vLLM Official Documentation](https://docs.vllm.ai/)
- [Huawei Ascend Hub](https://ascendhub.huawei.com/)
