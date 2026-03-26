# 常见问题排查

## 服务启动失败

### 症状：进程启动后立即退出

**检查步骤：**
```bash
# 查看日志
cat /root/xllm/log/node_0.log | tail -50

# 检查 NPU 设备
ls -la /dev/davinci*
npu-smi info
```

**常见原因：**
- NPU 设备不可用 → 检查 `--device` 参数
- 模型路径错误 → 确认 `--model` 路径存在
- 端口被占用 → 更换 `--port`

---

### 症状：`SIGBUS` 或 `SIGSEGV`

**可能原因：**
- 共享内存配置问题
- 内存不足

**解决方案：**
```bash
# 关闭共享内存
--enable_shm=false

# 降低内存使用
--max_memory_utilization=0.75
```

---

## 编译问题

### 症状：子模块更新失败

```bash
# 强制更新
git submodule update --init -f

# 或重新克隆
git clone --recurse-submodules https://github.com/jd-opensource/xllm
```

### 症状：编译卡住或超时

```bash
# 配置代理
export http_proxy=http://bamboo-proxy.jd.com:80
export https_proxy=http://bamboo-proxy.jd.com:80

# 使用 ninja 加速
export MAX_JOBS=640
```

### 症状：缺少 xllm_kernels

**错误信息：**
```
/usr/local/xllm_kernels/include/xllm_kernels/core/include: No such file or directory
```

**解决方案：** 使用 `--install-xllm-kernels=true` 编译，或从镜像中查找已编译的 kernel。

---

## 服务运行问题

### 症状：服务启动成功但 curl 请求超时

**检查步骤：**
```bash
# 检查端口监听
ss -tlnp | grep 18000

# 检查进程状态
ps aux | grep xllm | grep -v grep

# 查看日志中的请求处理
tail -f /root/xllm/log/node_0.log
```

### 症状：NPU 子进程报错 `TBE Subprocess raise error`

**可能原因：**
- NPU 驱动不匹配
- 模型与设备不兼容

**解决方案：**
- 确认使用的是 A3 镜像
- 确认编译时加了 `--device a3`

---

## 日志分析

### 关键日志标识

| 日志关键词 | 含义 |
|------------|------|
| `Server[xllm::APIService] is serving on port=18000` | 服务启动成功 |
| `Worker#0 connect to 127.0.0.1:9748 success` | Worker 连接成功 |
| `Successfully initialized kv cache` | KV cache 初始化成功 |
| `Init_model_async succeed` | 模型加载成功 |
| `SIGINT was installed` | 信号处理器就绪 |
| `TBE Subprocess raise error` | NPU 子进程异常 |

### 日志级别调整

```bash
# 设置日志级别
export ASCEND_GLOBAL_LOG_LEVEL=0  # 0=DEBUG, 1=INFO, 2=WARNING, 3=ERROR
```

---

## 性能问题

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| 首 Token 延迟高 | 未开 chunked prefill | `--enable_chunked_prefill=true` |
| 吞吐低 | 未开调度重叠 | `--enable_schedule_overlap=true` |
| 显存溢出 | 内存比例过高 | `--max_memory_utilization=0.8` |
| 频繁 OOM | block_size 过大 | `--block_size=64` |

---

## 参考文档

- 官方启动文档：`docs/zh/getting_started/launch_xllm.md`
- 在线服务部署：`docs/zh/getting_started/online_service.md`
- 离线服务部署：`docs/zh/getting_started/offline_service.md`
- 多机部署：`docs/zh/getting_started/multi_machine.md`
- CLI 参考：`docs/zh/cli_reference.md`
