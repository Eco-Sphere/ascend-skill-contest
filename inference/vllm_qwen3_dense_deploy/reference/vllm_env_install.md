# VLLM Environment Install

## Docker Pull
```
docker pull quay.io/ascend/vllm-ascend:v0.17.0rc1
```

## Docker Run
```
export IMAGE=quay.io/ascend/vllm-ascend:v0.18.0rc1
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

The default workdir is /workspace, vLLM and vLLM Ascend code are placed in /vllm-workspace and installed in development mode (pip install -e) to help developer immediately take place changes without requiring a new installation.

## Check vLLM Environment
```
pip list | grep vLLM
```