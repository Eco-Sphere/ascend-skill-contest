#!/usr/bin/env bash
set -euo pipefail

WORK_ROOT=${WORK_ROOT:-/home}
ENV_PY="${WORK_ROOT}/conda_envs/fsdp2_nanogpt_npu/bin"
SRC_DIR="${WORK_ROOT}/pytorch-examples/distributed/FSDP2"
CKPT_DIR="${WORK_ROOT}/pytorch-examples/distributed/FSDP2/checkpoints_npu"

source /usr/local/Ascend/ascend-toolkit/set_env.sh
VISIBLE_DEVICES=${VISIBLE_DEVICES:-6,7}
MASTER_ADDR=${MASTER_ADDR:-175.100.2.7}
MASTER_PORT=${MASTER_PORT:-29563}
HOST_IPV4=${HOST_IPV4:-175.100.2.7}
HOST_IFNAME=${HOST_IFNAME:-enp189s0f0}

if [ ! -d "${CKPT_DIR}" ]; then
  echo "[ERROR] checkpoint dir not found: ${CKPT_DIR}"
  exit 1
fi

PYTHONPATH=${SRC_DIR} ASCEND_RT_VISIBLE_DEVICES=${VISIBLE_DEVICES} HCCL_IF_IP=${HOST_IPV4} HCCL_SOCKET_IFNAME=${HOST_IFNAME} HCCL_SOCKET_FAMILY=AF_INET HCCL_CONNECT_TIMEOUT=600 HCCL_EXEC_TIMEOUT=600 GLOO_SOCKET_IFNAME=lo TP_SOCKET_IFNAME=lo "${ENV_PY}/torchrun" \
  --nnodes=1 \
  --node_rank=0 \
  --nproc_per_node=2 \
  --master_addr=${MASTER_ADDR} \
  --master_port=${MASTER_PORT} \
  "${SRC_DIR}/example.py" \
  --device-type npu \
  --checkpoint-dir "${CKPT_DIR}" \
  --steps 3 \
  --batch-size 32 \
  --seq-len 64 \
  --mixed-precision
