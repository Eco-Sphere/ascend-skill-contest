# Reference

Original FSDP2 code from: https://github.com/pytorch/examples/tree/main/distributed/FSDP2

Files:
- example.py: Main training script
- model.py: Transformer model implementation
- checkpoint.py: Checkpoint save/load utilities
- utils.py: Model inspection utilities
- requirements.txt: Dependencies

Key changes for NPU adaptation:
1. Added NPU device detection and initialization
2. Integrated torch_npu.npu_fusion_attention
3. Changed distributed backend from NCCL to HCCL for NPU
4. Added checkpoint save/load support for resume training
