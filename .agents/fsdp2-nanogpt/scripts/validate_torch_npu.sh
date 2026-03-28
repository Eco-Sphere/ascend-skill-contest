#!/usr/bin/env bash
set -euo pipefail

WORK_ROOT=${WORK_ROOT:-/home}
PY_BIN="${WORK_ROOT}/conda_envs/fsdp2_nanogpt_npu/bin/python"

source /usr/local/Ascend/ascend-toolkit/set_env.sh

if [ ! -x "${PY_BIN}" ]; then
  echo "[ERROR] python not found: ${PY_BIN}"
  exit 1
fi

"${PY_BIN}" - <<'PY'
import torch
import torch_npu

print("torch", torch.__version__)
print("torch_npu", torch_npu.__version__)
print("npu_available", torch.npu.is_available())
print("npu_count", torch.npu.device_count())

if not torch.npu.is_available():
    raise SystemExit("[ERROR] torch.npu.is_available() is False")

torch.npu.set_device(0)
x = torch.randn(2, 3).npu()
y = x + x
print("tensor_device", y.device)
print("tensor_sum", float(y.sum().cpu()))
PY
