#!/usr/bin/env bash
set -euo pipefail

WORK_ROOT=${WORK_ROOT:-/home}
CONDA_BIN="${WORK_ROOT}/miniconda3/bin/conda"
ENV_DIR="${WORK_ROOT}/conda_envs/fsdp2_nanogpt_npu"
PIP_BIN="${ENV_DIR}/bin/pip"
REQ_FILE="${WORK_ROOT}/pytorch-examples/distributed/FSDP2/requirements.txt"

if [ ! -x "${CONDA_BIN}" ]; then
  echo "[ERROR] conda not found: ${CONDA_BIN}"
  exit 1
fi

if [ ! -f "${REQ_FILE}" ]; then
  echo "[ERROR] requirements file not found: ${REQ_FILE}"
  exit 1
fi

source /usr/local/Ascend/ascend-toolkit/set_env.sh

if [ ! -d "${ENV_DIR}" ]; then
  "${CONDA_BIN}" create -y -p "${ENV_DIR}" python=3.11
fi

"${PIP_BIN}" install -i https://mirrors.aliyun.com/pypi/simple --resume-retries 10 \
  torch==2.7.1 torch-npu==2.7.1.post2 numpy

"${PIP_BIN}" install -i https://mirrors.aliyun.com/pypi/simple \
  attrs decorator psutil absl-py cloudpickle ml-dtypes scipy tornado pyyaml requests

"${PIP_BIN}" install -i https://mirrors.aliyun.com/pypi/simple -r "${REQ_FILE}"

echo "[INFO] install finished: ${ENV_DIR}"
