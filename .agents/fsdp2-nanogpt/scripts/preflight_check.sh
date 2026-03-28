#!/usr/bin/env bash
set -euo pipefail

WORK_ROOT=${WORK_ROOT:-/home}
CONDA_DIR="${WORK_ROOT}/miniconda3"
SRC_DIR="${WORK_ROOT}/pytorch-examples/distributed/FSDP2"

source /usr/local/Ascend/ascend-toolkit/set_env.sh

if [ ! -d "${CONDA_DIR}" ]; then
  echo "[ERROR] miniconda3 not found: ${CONDA_DIR}"
  exit 1
fi

echo "[INFO] NPU visibility"
npu-smi info

echo "[INFO] Ascend environment"
python3 - <<'PY'
import os
for key in ["ASCEND_HOME_PATH", "ASCEND_TOOLKIT_HOME", "ASCEND_OPP_PATH"]:
    print(f"{key}={os.environ.get(key, '')}")
PY

echo "[INFO] Candidate weight and checkpoint paths"
WORK_ROOT="${WORK_ROOT}" python3 - <<'PY'
from pathlib import Path
import os
root = Path(os.environ['WORK_ROOT'])
patterns = ['**/*checkpoint*', '**/*.pt', '**/*.pth', '**/*.ckpt', '**/*.bin', '**/*.safetensors']
seen = set()
for pattern in patterns:
    for path in root.glob(pattern):
        value = str(path)
        if value not in seen:
            seen.add(value)
            print(value)
PY

echo "[INFO] Source path status"
if [ -d "${SRC_DIR}" ]; then
  ls "${SRC_DIR}"
else
  echo "[WARN] source path not found: ${SRC_DIR}"
fi
