# vLLM-Ascend Quick Reference Card

## NPU Commands

```bash
# Check NPU status
npu-smi info

# Check specific NPU
npu-smi info -t board -i 0

# List NPU devices
ls -la /dev/davinci*
```

## Docker Commands

```bash
# Start container
docker run -itd --privileged --name=<name> --net=host --shm-size=16g \
  --device /dev/davinci<N> --device /dev/davinci_manager \
  --device /dev/devmm_svm --device /dev/hisi_hdc \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
  -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  -v /root/.cache:/root/.cache -v /home:/home -v /data:/data \
  <image> /bin/bash

# Enter container
docker exec -it <name> bash

# View logs
docker logs <name>
docker exec <name> cat /tmp/vllm.log

# Stop and remove
docker stop <name> && docker rm <name>
```

## vLLM Commands

```bash
# Basic serve
vllm serve <model-path> --host 0.0.0.0 --port 8000

# With options
vllm serve <model-path> \
  --host 0.0.0.0 \
  --port 8000 \
  --dtype float16 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.7

# Background mode
nohup vllm serve <model-path> ... > /tmp/vllm.log 2>&1 &
```

## API Endpoints

```bash
# Health check
curl http://localhost:8000/health

# List models
curl http://localhost:8000/v1/models

# Chat completion
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "<model>", "messages": [{"role": "user", "content": "Hello"}]}'

# Text completion
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "<model>", "prompt": "Hello"}'
```

## Memory Estimation

| Model | FP16 Memory | Recommended NPU |
|-------|-------------|-----------------|
| 7B | ~14 GB | 1x 64GB NPU |
| 14B | ~28 GB | 1x 64GB NPU |
| 32B | ~64 GB | 1x 64GB NPU (low util) |
| 70B | ~140 GB | 2-4x 64GB NPU (TP) |

## Common Parameters

| Parameter | Description | Typical Value |
|-----------|-------------|---------------|
| `--max-model-len` | Max sequence length | 2048-8192 |
| `--gpu-memory-utilization` | Memory ratio | 0.6-0.9 |
| `--max-num-seqs` | Concurrent requests | 64-256 |
| `--tensor-parallel-size` | NPU count for TP | 1-4 |
| `--dtype` | Data type | float16 |

## Troubleshooting Quick Fixes

| Issue | Quick Fix |
|-------|-----------|
| OOM | Reduce `--gpu-memory-utilization` |
| NPU busy | Use different NPU or kill process |
| Network error | Use `--host 0.0.0.0` |
| Model not found | Check volume mounts |
| Slow inference | Enable ACL graph |
