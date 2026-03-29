import argparse
import os
import sys

import torch
import torch.nn as nn

torch._inductor.config.disable_progress = True
torch._dynamo.config.suppress_errors = True

try:
    import torch_npu
    from torch_npu.npu import NPUAccelerator
    NPU_AVAILABLE = True
except ImportError:
    NPU_AVAILABLE = False

from checkpoint import Checkpointer
from model import ModelArgs, Transformer
from torch.distributed.fsdp import fully_shard, MixedPrecisionPolicy
from utils import inspect_mixed_precision, inspect_model


def get_device():
    return torch.device("cpu")


def verify_min_device_count(min_devices: int = 2) -> bool:
    if NPU_AVAILABLE and torch.npu.is_available():
        return torch.npu.device_count() >= min_devices
    elif torch.cuda.is_available():
        return torch.cuda.device_count() >= min_devices
    return True


def set_modules_to_forward_prefetch(model, num_to_forward_prefetch):
    for i, layer in enumerate(model.layers):
        if i >= len(model.layers) - num_to_forward_prefetch:
            break
        layers_to_prefetch = [
            model.layers[i + j] for j in range(1, num_to_forward_prefetch + 1)
        ]
        layer.set_modules_to_forward_prefetch(layers_to_prefetch)


def set_modules_to_backward_prefetch(model, num_to_backward_prefetch):
    for i, layer in enumerate(model.layers):
        if i < num_to_backward_prefetch:
            continue
        layers_to_prefetch = [
            model.layers[i - j] for j in range(1, num_to_backward_prefetch + 1)
        ]
        layer.set_modules_to_backward_prefetch(layers_to_prefetch)


def init_distributed():
    rank = int(os.environ.get("LOCAL_RANK", 0))
    world_size = int(os.environ.get("WORLD_SIZE", 1))
    
    device = get_device()
    
    if world_size == 1 and rank == 0:
        return rank, world_size, device
    
    torch.distributed.init_process_group(backend="gloo")
    
    return rank, world_size, device


def main(args):
    _min_device_count = 2
    if not verify_min_device_count(min_devices=_min_device_count):
        print(f"Unable to locate sufficient {_min_device_count} devices to run this example. Exiting.")
        exit()

    rank, world_size, device = init_distributed()
    
    print(f"Running on rank {rank}, world_size {world_size}, device {device}")

    torch.manual_seed(0)
    vocab_size = 1024
    batch_size = 32
    seq_len = 64
    model_args = ModelArgs(
        n_layers=10,
        n_heads=4,
        vocab_size=vocab_size,
        max_seq_len=seq_len,
        dropout_p=0,
        use_npu_fusion=args.use_npu_fusion and NPU_AVAILABLE,
    )
    
    with torch.device("meta"):
        model = Transformer(model_args)
    
    checkpointer = Checkpointer("checkpoints", dcp_api=args.dcp_api)
    if checkpointer.last_training_time is None:
        model.to_empty(device=torch.device("cpu"))
        model.reset_parameters()
    
    fsdp_kwargs = {}
    if args.mixed_precision:
        fsdp_kwargs["mp_policy"] = MixedPrecisionPolicy(
            param_dtype=torch.bfloat16,
            reduce_dtype=torch.float32,
        )
    
    for layer in model.layers:
        fully_shard(layer, **fsdp_kwargs)
    fully_shard(model, **fsdp_kwargs)

    if rank == 0:
        inspect_model(model)

    if args.explicit_prefetching:
        set_modules_to_forward_prefetch(model, num_to_forward_prefetch=2)
        set_modules_to_backward_prefetch(model, num_to_backward_prefetch=2)

    if checkpointer.last_training_time is None:
        model.to_empty(device=device)
    else:
        checkpointer.load_model(model)
    
    if args.mixed_precision:
        inspect_mixed_precision(model)

    optim = torch.optim.Adam(model.parameters(), lr=1e-2)
    if checkpointer.last_training_time is not None:
        checkpointer.load_optim(model, optim)

    for iteration in range(args.max_iterations):
        if args.explicit_prefetching:
            model.unshard()
        x = torch.randint(0, vocab_size, (batch_size, seq_len), device=device)
        loss = model(x).sum()
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        optim.step()
        optim.zero_grad()
        
        if rank == 0 and iteration % 2 == 0:
            print(f"Iteration {iteration}, Loss: {loss.item()}")

    checkpointer.save(model, optim)
    torch.distributed.destroy_process_group()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PyTorch FSDP2 NPU example")
    parser.add_argument("--explicit-prefetching", action="store_true", default=False)
    parser.add_argument("--mixed-precision", action="store_true", default=False)
    parser.add_argument("--dcp-api", action="store_true", default=False)
    parser.add_argument("--use-npu-fusion", action="store_true", default=True)
    parser.add_argument("--max-iterations", type=int, default=10)
    args = parser.parse_args()
    
    main(args)
