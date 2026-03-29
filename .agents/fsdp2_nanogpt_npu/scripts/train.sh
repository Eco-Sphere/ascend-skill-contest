#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NPROC_PER_NODE=${NPROC_PER_NODE:-2}

echo "Starting FSDP2 nanoGPT training on NPU"
echo "Number of NPUs: $NPROC_PER_NODE"

torchrun --nproc_per_node=$NPROC_PER_NODE example.py \
    --use-npu-fusion \
    --max-iterations 10 \
    "$@"
