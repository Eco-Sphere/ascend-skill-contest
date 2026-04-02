# vLLM Deploy

## Online Inference on Single-NPU
```
# set the NPU device number
export ASCEND_RT_VISIBLE_DEVICES=0

# Set the operator dispatch pipeline level to 1 and disable manual memory control in ACLGraph
export TASK_QUEUE_ENABLE=1

# [Optional] jemalloc
# jemalloc is for better performance, if `libjemalloc.so` is installed on your machine, you can turn it on.
# if os is Ubuntu
# export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2:$LD_PRELOAD
# if os is openEuler
# export LD_PRELOAD=/usr/lib64/libjemalloc.so.2:$LD_PRELOAD


# Enable the AIVector core to directly schedule ROCE communication
export HCCL_OP_EXPANSION_MODE="AIV"

vllm serve vllm-ascend/Qwen3-32B-W8A8 \
  --served-model-name qwen3 \
  --trust-remote-code \
  --async-scheduling \
  --quantization ascend \
  --distributed-executor-backend mp \
  --tensor-parallel-size 1 \
  --max-model-len 5500 \
  --max-num-batched-tokens 40960 \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY"}' \
  --additional-config '{"pa_shape_list":[48,64,72,80], "weight_prefetch_config":{"enabled":true}}' \
  --port 8113 \
  --block-size 128 \
  --gpu-memory-utilization 0.9
```

## Online Inference on Multi-NPU
```
# set the NPU device number
export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3

# Set the operator dispatch pipeline level to 1 and disable manual memory control in ACLGraph
export TASK_QUEUE_ENABLE=1

# [Optional] jemalloc
# jemalloc is for better performance, if `libjemalloc.so` is installed on your machine, you can turn it on.
# if os is Ubuntu
# export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2:$LD_PRELOAD
# if os is openEuler
# export LD_PRELOAD=/usr/lib64/libjemalloc.so.2:$LD_PRELOAD


# Enable the AIVector core to directly schedule ROCE communication
export HCCL_OP_EXPANSION_MODE="AIV"

# Enable FlashComm_v1 optimization when tensor parallel is enabled.
export VLLM_ASCEND_ENABLE_FLASHCOMM1=1

vllm serve vllm-ascend/Qwen3-32B-W8A8 \
  --served-model-name qwen3 \
  --trust-remote-code \
  --async-scheduling \
  --quantization ascend \
  --distributed-executor-backend mp \
  --tensor-parallel-size 4 \
  --max-model-len 5500 \
  --max-num-batched-tokens 40960 \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY"}' \
  --additional-config '{"pa_shape_list":[48,64,72,80], "weight_prefetch_config":{"enabled":true}}' \
  --port 8113 \
  --block-size 128 \
  --gpu-memory-utilization 0.9
```

## Check vLLM Online Serve By Curl Request
```
curl http://localhost:8113/v1/chat/completions -H "Content-Type: application/json" -d '{
  "model": "qwen3",
  "messages": [
    {"role": "user", "content": "Give me a short introduction to large language models."}
  ],
  "temperature": 0.6,
  "top_p": 0.95,
  "top_k": 20,
  "max_completion_tokens": 4096
}'
```

## References
如果想了解更多，请参考vLLM-Ascend官方文档：https://docs.vllm.ai/projects/ascend/en/latest/tutorials/models/Qwen3-Dense.html