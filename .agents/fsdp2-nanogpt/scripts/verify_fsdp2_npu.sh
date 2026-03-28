#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT=${WORK_ROOT:-/home}
CKPT_DIR="${WORK_ROOT}/pytorch-examples/distributed/FSDP2/checkpoints_npu"

echo "[INFO] Step 1/5: preflight check"
WORK_ROOT="${WORK_ROOT}" "${SCRIPT_DIR}/preflight_check.sh"

echo "[INFO] Step 2/5: install or update environment"
WORK_ROOT="${WORK_ROOT}" "${SCRIPT_DIR}/create_env_and_install.sh"

echo "[INFO] Step 3/5: validate torch_npu runtime"
WORK_ROOT="${WORK_ROOT}" "${SCRIPT_DIR}/validate_torch_npu.sh"

echo "[INFO] Step 4/5: first training run"
WORK_ROOT="${WORK_ROOT}" "${SCRIPT_DIR}/run_fsdp2_npu.sh"

if [ ! -d "${CKPT_DIR}" ]; then
  echo "[ERROR] checkpoint dir not found after first run: ${CKPT_DIR}"
  exit 1
fi

echo "[INFO] Step 5/5: resume training run"
WORK_ROOT="${WORK_ROOT}" "${SCRIPT_DIR}/resume_fsdp2_npu.sh"

echo "[INFO] Verification completed"
echo "[INFO] checkpoint dir: ${CKPT_DIR}"
ls -R "${CKPT_DIR}"
