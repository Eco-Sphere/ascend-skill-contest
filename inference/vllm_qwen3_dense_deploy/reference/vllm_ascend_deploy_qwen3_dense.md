# Qwen3-Dense(Qwen3-0.6B/8B/32B)

## Introduction

Qwen3 is the latest generation of large language models in Qwen series, offering a comprehensive suite of dense and mixture-of-experts (MoE) models. Built upon extensive training, Qwen3 delivers groundbreaking advancements in reasoning, instruction-following, agent capabilities, and multilingual support.

Welcome to the tutorial on optimizing Qwen Dense models in the vLLM-Ascend environment. This guide will help you configure the most effective settings for your use case, with practical examples that highlight key optimization points. We will also explore how adjusting service parameters can maximize throughput performance across various scenarios.

This document will show the main verification steps of the model, including supported features, feature configuration, environment preparation, accuracy and performance evaluation.

The Qwen3 Dense models is first supported in [v0.8.4rc2](https://github.com/vllm-project/vllm-ascend/blob/main/docs/source/user_guide/release_notes.md#v084rc2---20250429). This example requires version **v0.11.0rc2**. Earlier versions may lack certain features.

## Supported Features

Refer to [supported features](../../user_guide/support_matrix/supported_models.md) to get the model's supported feature matrix.

Refer to [feature guide](../../user_guide/feature_guide/index.md) to get the feature's configuration.

## Environment Preparation

### Model Weight

- `Qwen3-0.6B`(BF16 version): require 1 Atlas 800 A3 (64G × 2) card or 1 Atlas 800I A2 (64G × 1) card. [Download model weight](https://modelers.cn/models/Modelers_Park/Qwen3-0.6B)
- `Qwen3-1.7B`(BF16 version): require 1 Atlas 800 A3 (64G × 2) card or 1 Atlas 800I A2 (64G × 1) card. [Download model weight](https://modelers.cn/models/Modelers_Park/Qwen3-1.7B)
- `Qwen3-4B`(BF16 version): require 1 Atlas 800 A3 (64G × 2) card or 1 Atlas 800I A2 (64G × 1) card. [Download model weight](https://modelers.cn/models/Modelers_Park/Qwen3-4B)
- `Qwen3-8B`(BF16 version): require 1 Atlas 800 A3 (64G × 2) card or 1 Atlas 800I A2 (64G × 1) card. [Download model weight](https://modelers.cn/models/Modelers_Park/Qwen3-8B)
- `Qwen3-14B`(BF16 version): require 1 Atlas 800 A3 (64G × 2) card or 2 Atlas 800I A2 (64G × 1) cards. [Download model weight](https://modelers.cn/models/Modelers_Park/Qwen3-14B)
- `Qwen3-32B`(BF16 version): require 2 Atlas 800 A3 (64G × 4) cards or 4 Atlas 800I A2 (64G × 4) cards. [Download model weight](https://modelers.cn/models/Modelers_Park/Qwen3-32B)
- `Qwen3-32B-W8A8`(Quantized version): require 2 Atlas 800 A3 (64G × 4) cards or 4 Atlas 800I A2 (64G × 4) cards. [Download model weight](https://www.modelscope.cn/models/vllm-ascend/Qwen3-32B-W8A8)

These are the recommended numbers of cards, which can be adjusted according to the actual situation.

It is recommended to download the model weight to the shared directory of multiple nodes, such as `/root/.cache/`

### Verify Multi-node Communication(Optional)

If you want to deploy multi-node environment, you need to verify multi-node communication according to [verify multi-node communication environment](../../installation.md#verify-multi-node-communication).

### Installation

You can use our official docker image for supporting Qwen3 Dense models.
Currently, we provide the all-in-one images.[Download images](https://quay.io/repository/ascend/vllm-ascend?tab=tags)

#### Docker Pull (by tag)

```{code-block} bash
   :substitutions:

docker pull quay.io/ascend/vllm-ascend:|vllm_ascend_version|

```

#### Docker run

```{code-block} bash
   :substitutions:

# Update --device according to your device (Atlas A2: /dev/davinci[0-7] Atlas A3:/dev/davinci[0-15]).
# Update the vllm-ascend image according to your environment.
# Note you should download the weight to /root/.cache in advance.
# For Atlas A2 machines:
# export IMAGE=quay.io/ascend/vllm-ascend:|vllm_ascend_version|
# For Atlas A3 machines:
export IMAGE=quay.io/ascend/vllm-ascend:|vllm_ascend_version|-a3
docker run --rm \
    --name vllm-ascend-env \
    --shm-size=1g \
    --net=host \
    --device /dev/davinci0 \
    --device /dev/davinci1 \
    --device /dev/davinci2 \
    --device /dev/davinci3 \
    --device /dev/davinci4 \
    --device /dev/davinci5 \
    --device /dev/davinci6 \
    --device /dev/davinci7 \
    --device /dev/davinci_manager \
    --device /dev/devmm_svm \
    --device /dev/hisi_hdc \
    -v /usr/local/dcmi:/usr/local/dcmi \
    -v /usr/local/Ascend/driver/tools/hccn_tool:/usr/local/Ascend/driver/tools/hccn_tool \
    -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
    -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
    -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
    -v /etc/ascend_install.info:/etc/ascend_install.info \
    -v /root/.cache:/root/.cache \
    -it $IMAGE bash
```

The default workdir is `/workspace`, vLLM and vLLM Ascend code are placed in `/vllm-workspace` and installed in [development mode](https://setuptools.pypa.io/en/latest/userguide/development_mode.html) (`pip install -e`) to help developer immediately take place changes without requiring a new installation.

In the [Run docker container](./Qwen3-Dense.md#run-docker-container), detailed explanations are provided through specific examples.

In addition, if you don't want to use the docker image as above, you can also build all from source:

- Install `vllm-ascend` from source, refer to [installation](../../installation.md).

If you want to deploy multi-node environment, you need to set up environment on each node.

## Deployment

In this section, we will demonstrate best practices for adjusting hyperparameters in vLLM-Ascend to maximize inference throughput performance. By tailoring service-level configurations to fit different use cases, you can ensure that your system performs optimally across various scenarios. We will guide you through how to fine-tune hyperparameters based on observed phenomena, such as max_model_len, max_num_batched_tokens, and cudagraph_capture_sizes, to achieve the best performance.

The specific example scenario is as follows:

- The machine environment is an Atlas 800 A3 (64G*16)
- The LLM is Qwen3-32B-W8A8
- The data scenario is a fixed-length input of 3.5K and an output of 1.5K.
- The parallel configuration requirement is DP=1&TP=4
- If the machine environment is an **Atlas 800I A2(64G*8)**, the deployment approach stays identical.

### Run docker container

:::{note}

- vllm-ascend/Qwen3-32B-W8A8 is the default model path, replace this with your actual path.
- v0.11.0rc2-a3 is image tag, replace this with your actual tag.
- replace this with your actual port: '-p 8113:8113'.
- replace this with your actual card: '--device /dev/davinci0'.
:::

```{code-block} bash
   :substitutions:
# Update the vllm-ascend image
export IMAGE=quay.io/ascend/vllm-ascend:|vllm_ascend_version|
docker run --rm \
--name vllm-ascend \
--shm-size=1g \
--privileged=true \
--device /dev/davinci0 \
--device /dev/davinci1 \
--device /dev/davinci2 \
--device /dev/davinci3 \
--device /dev/davinci_manager \
--device /dev/devmm_svm \
--device /dev/hisi_hdc \
-v /usr/local/dcmi:/usr/local/dcmi \
-v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
-v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
-v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
-v /etc/ascend_install.info:/etc/ascend_install.info \
-v /root/.cache:/root/.cache \
-p 8113:8113 \
-it $IMAGE bash
```

### Online Inference on Multi-NPU

Run the following script to start the vLLM server on Multi-NPU.

This script is configured to achieve optimal performance under the above specific example scenarios,with batchsize = 72 on two A3 cards.

```bash
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

:::{note}

- vllm-ascend/Qwen3-32B-W8A8 is the default model path, replace this with your actual path.

- If the model is not a quantized model, remove the `--quantization ascend` parameter.

- **[Optional]** `--additional-config '{"pa_shape_list":[48,64,72,80]}'`: `pa_shape_list` specifies the batch sizes where you want to switch to the PA operator. This is a temporary tuning knob. Currently, the attention operator dispatch defaults to the FIA operator. In some batch-size (concurrency) settings, FIA may have suboptimal performance. By setting `pa_shape_list`, when the runtime batch size matches one of the listed values, vLLM-Ascend will replace FIA with the PA operator to prevent performance degradation. In the future, FIA will be optimized for these scenarios and this parameter will be removed.

- If the ultimate performance is desired, the cudagraph_capture_sizes parameter can be enabled, reference: [key-optimization-points](./Qwen3-Dense.md#key-optimization-points)、[optimization-highlights](./Qwen3-Dense.md#optimization-highlights). Here is an example of batchsize of 72: `--compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY", "cudagraph_capture_sizes":[1,8,24,48,60,64,72,76]}'`.
:::

Once your server is started, you can query the model with input prompts

```bash
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