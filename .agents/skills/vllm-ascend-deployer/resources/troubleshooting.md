# Troubleshooting Guide for vLLM-Ascend

This guide covers common issues and solutions when deploying models with vLLM-Ascend on Huawei Atlas servers.

## Table of Contents

1. [NPU Device Issues](#npu-device-issues)
2. [Memory Issues](#memory-issues)
3. [Model Loading Issues](#model-loading-issues)
4. [Docker Issues](#docker-issues)
5. [Network Issues](#network-issues)
6. [Performance Issues](#performance-issues)
7. [Error Messages Reference](#error-messages-reference)

---

## NPU Device Issues

### Issue: NPU Not Detected

**Symptoms:**
```
RuntimeError: No NPU device found
```

**Solutions:**
1. Check NPU status:
   ```bash
   npu-smi info
   ```

2. Verify device files exist:
   ```bash
   ls -la /dev/davinci*
   ```

3. Check driver installation:
   ```bash
   cat /usr/local/Ascend/driver/version.info
   ```

4. Ensure Docker has device access:
   ```bash
   docker run --rm --device /dev/davinci0 quay.io/ascend/vllm-ascend:v0.17.0 npu-smi info
   ```

### Issue: NPU Already in Use

**Symptoms:**
```
RuntimeError: NPU device is busy or occupied
```

**Solutions:**
1. Check which process is using the NPU:
   ```bash
   npu-smi info
   # Look for processes in the output
   ```

2. Find and kill the process:
   ```bash
   ps aux | grep vllm
   kill -9 <pid>
   ```

3. Or use a different NPU:
   ```bash
   # Change --device /dev/davinci0 to --device /dev/davinci1
   ```

### Issue: NPU Memory Fragmentation

**Symptoms:**
```
RuntimeError: Failed to allocate memory on NPU
```

**Solutions:**
1. Reset NPU (requires root):
   ```bash
   npu-smi set -t reset -i <npu-id>
   ```

2. Restart Docker container:
   ```bash
   docker restart <container-name>
   ```

---

## Memory Issues

### Issue: Out of Memory (OOM)

**Symptoms:**
```
OutOfMemoryError: NPU out of memory
RuntimeError: [Ascend] Memory allocation failed
```

**Solutions:**

1. **Reduce GPU memory utilization:**
   ```bash
   vllm serve <model> --gpu-memory-utilization 0.6
   ```

2. **Reduce max model length:**
   ```bash
   vllm serve <model> --max-model-len 2048
   ```

3. **Reduce max num sequences:**
   ```bash
   vllm serve <model> --max-num-seqs 64
   ```

4. **Use tensor parallelism (multiple NPUs):**
   ```bash
   vllm serve <model> --tensor-parallel-size 2
   ```

### Issue: Memory Estimation Error

**Symptoms:**
```
ValueError: The model's max seq len is too large for the available GPU memory
```

**Solutions:**
1. Check available memory:
   ```bash
   npu-smi info
   ```

2. Calculate required memory:
   - Model weights: Parameters × 2 bytes (FP16)
   - KV cache: max_len × max_seqs × hidden_dim × 4 bytes
   - Overhead: ~10% additional

3. Adjust parameters accordingly.

### Issue: Insufficient Memory for KV Cache

**Symptoms:**
```
RuntimeError: Cannot allocate KV cache
```

**Solutions:**
1. Reduce block size:
   ```bash
   vllm serve <model> --block-size 8
   ```

2. Enable prefix caching:
   ```bash
   vllm serve <model> --enable-prefix-caching
   ```

---

## Model Loading Issues

### Issue: Model Not Found

**Symptoms:**
```
FileNotFoundError: Model not found at /path/to/model
```

**Solutions:**
1. Verify model path exists:
   ```bash
   ls -la /path/to/model
   ```

2. Check Docker volume mount:
   ```bash
   docker inspect <container> | grep Mounts -A 20
   ```

3. Ensure path is mounted:
   ```bash
   docker run ... -v /path/to/model:/model ...
   ```

### Issue: Unsupported Model Architecture

**Symptoms:**
```
KeyError: Unsupported model architecture: XXXForCausalLM
```

**Solutions:**
1. Check if model is supported in `supported_models.md`

2. Try specifying trust_remote_code:
   ```bash
   vllm serve <model> --trust-remote-code
   ```

3. Check vLLM-Ascend version compatibility

### Issue: Model Download Failed

**Symptoms:**
```
ConnectionError: Failed to download model from huggingface.co
```

**Solutions:**
1. Use ModelScope mirror:
   ```bash
   export VLLM_USE_MODELSCOPE=true
   vllm serve Qwen/Qwen2.5-7B-Instruct
   ```

2. Pre-download model:
   ```bash
   pip install modelscope
   modelscope download --model Qwen/Qwen2.5-7B-Instruct
   ```

3. Use offline mode with local path:
   ```bash
   vllm serve /local/path/to/model
   ```

### Issue: Checkpoint Loading Error

**Symptoms:**
```
RuntimeError: Failed to load checkpoint
```

**Solutions:**
1. Verify checkpoint files:
   ```bash
   ls -la /path/to/model/*.safetensors
   ls -la /path/to/model/*.bin
   ```

2. Check model config:
   ```bash
   cat /path/to/model/config.json
   ```

3. Try different load format:
   ```bash
   vllm serve <model> --load-format safetensors
   ```

---

## Docker Issues

### Issue: Container Fails to Start

**Symptoms:**
```
Error: failed to start container
docker: Error response from daemon
```

**Solutions:**
1. Check Docker logs:
   ```bash
   docker logs <container>
   ```

2. Verify device permissions:
   ```bash
   ls -la /dev/davinci*
   chmod 666 /dev/davinci*  # If needed
   ```

3. Check if image exists:
   ```bash
   docker images | grep vllm
   ```

### Issue: Container Exits Immediately

**Symptoms:**
```
Container starts but exits right away
```

**Solutions:**
1. Run interactively to debug:
   ```bash
   docker run -it --rm <image> /bin/bash
   ```

2. Check entrypoint:
   ```bash
   docker inspect <image> | grep Entrypoint
   ```

3. Use bash as entrypoint:
   ```bash
   docker run -it <image> /bin/bash
   ```

### Issue: Volume Mount Permission Denied

**Symptoms:**
```
PermissionError: [Errno 13] Permission denied
```

**Solutions:**
1. Check directory permissions:
   ```bash
   ls -la /path/to/directory
   ```

2. Run with proper user:
   ```bash
   docker run -u $(id -u):$(id -g) ...
   ```

3. Use privileged mode:
   ```bash
   docker run --privileged ...
   ```

---

## Network Issues

### Issue: API Not Accessible Externally

**Symptoms:**
```
curl: Failed to connect to host
Connection refused
```

**Solutions:**
1. Ensure host binding:
   ```bash
   vllm serve <model> --host 0.0.0.0
   ```

2. Check port is open:
   ```bash
   netstat -tlnp | grep <port>
   ```

3. Check firewall:
   ```bash
   firewall-cmd --list-ports
   firewall-cmd --add-port=<port>/tcp
   ```

4. Use host network:
   ```bash
   docker run --net=host ...
   ```

### Issue: Port Already in Use

**Symptoms:**
```
OSError: [Errno 98] Address already in use
```

**Solutions:**
1. Find process using port:
   ```bash
   lsof -i :<port>
   ```

2. Kill the process:
   ```bash
   kill -9 <pid>
   ```

3. Use different port:
   ```bash
   vllm serve <model> --port 8001
   ```

---

## Performance Issues

### Issue: Slow Inference

**Symptoms:**
- Very slow token generation
- High latency

**Solutions:**
1. Enable CUDA graph (ACL graph on Ascend):
   ```bash
   vllm serve <model> --enforce-eager  # Disable if needed
   ```

2. Optimize batch size:
   ```bash
   vllm serve <model> --max-num-seqs 128
   ```

3. Use tensor parallelism for large models:
   ```bash
   vllm serve <model> --tensor-parallel-size 2
   ```

### Issue: Slow Model Loading

**Symptoms:**
- Model takes very long to load

**Solutions:**
1. Use safetensors format:
   ```bash
   vllm serve <model> --load-format safetensors
   ```

2. Enable fast loading:
   ```bash
   vllm serve <model> --fast-load
   ```

---

## Error Messages Reference

### Common Error Patterns

| Error Pattern | Likely Cause | Solution |
|--------------|--------------|----------|
| `RuntimeError: [Ascend]` | Ascend-specific error | Check NPU status, driver |
| `OutOfMemoryError` | Memory exhaustion | Reduce parameters, use TP |
| `FileNotFoundError` | Missing files | Check paths, mounts |
| `ConnectionError` | Network issues | Check network, firewall |
| `ValueError: Invalid` | Invalid parameter | Check parameter values |
| `KeyError` | Missing key/config | Check model config |

### Log Analysis

**Check vLLM logs:**
```bash
docker exec <container> cat /tmp/vllm.log
docker logs <container>
```

**Enable debug logging:**
```bash
export VLLM_LOGGING_LEVEL=DEBUG
vllm serve <model>
```

---

## Getting Help

1. **Check Documentation:**
   - [vLLM-Ascend Docs](https://docs.vllm.ai/projects/ascend/)
   - [vLLM Docs](https://docs.vllm.ai/)

2. **Check Logs:**
   - Container logs: `docker logs <container>`
   - vLLM logs: `/tmp/vllm.log` inside container
   - System logs: `dmesg | grep -i ascend`

3. **Community Support:**
   - GitHub Issues: vllm-project/vllm-ascend
   - Huawei Ascend Community

4. **System Information:**
   ```bash
   npu-smi info
   cat /usr/local/Ascend/driver/version.info
   docker version
   ```
