#!/bin/bash
# verl Checkpoint 保存与加载验证脚本（快速验证版）

# 参数检查
if [ $# -lt 4 ]; then
    echo "Usage: $0 <work_dir> <model_path> <train_data> <val_data>"
    echo "Example: $0 /home/zzw30069617 /home/z30069617/models/Qwen3-0.6B /home/z30069617/datasets/gsm8k/processed/train.parquet /home/z30069617/datasets/gsm8k/processed/val.parquet"
    exit 1
fi

WORK_DIR=$1
MODEL_PATH=$2
TRAIN_DATA=$3
VAL_DATA=$4

echo "=== Step 1: 训练3步并保存checkpoint ==="

docker exec verl-npu bash -lc "
source /usr/local/Ascend/ascend-toolkit/set_env.sh;
cd ${WORK_DIR}/verl;
python -m verl.trainer.main_ppo \
    algorithm.adv_estimator=grpo \
    data.train_files=${TRAIN_DATA} \
    data.val_files=${VAL_DATA} \
    data.train_batch_size=256 \
    data.max_prompt_length=256 \
    data.max_response_length=256 \
    actor_rollout_ref.model.path=${MODEL_PATH} \
    actor_rollout_ref.actor.optim.lr=3e-6 \
    actor_rollout_ref.model.enable_gradient_checkpointing=True \
    actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.actor.ppo_mini_batch_size=256 \
    actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.ref.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.rollout.gpu_memory_utilization=0.3 \
    actor_rollout_ref.rollout.n=2 \
    actor_rollout_ref.rollout.tensor_model_parallel_size=1 \
    trainer.project_name=verl_grpo_demo \
    trainer.experiment_name=verify_checkpoint \
    trainer.device=npu \
    trainer.n_gpus_per_node=2 \
    trainer.save_freq=3 \
    trainer.test_freq=3 \
    trainer.total_epochs=1 \
    trainer.total_training_steps=3 \
    trainer.logger=[\"console\"] \
    trainer.default_local_dir=${WORK_DIR}/checkpoints/verify1 \
    > ${WORK_DIR}/verify1_log.txt 2>&1
"

echo "等待checkpoint保存完成..."
sleep 20

CHECKPOINT_DIR=$(ls -td ${WORK_DIR}/checkpoints/verify1/global_step_* 2>/dev/null | head -1)

if [ -z "$CHECKPOINT_DIR" ]; then
    echo "ERROR: No checkpoint found in ${WORK_DIR}/checkpoints/verify1/"
    exit 1
fi

echo "Checkpoint保存于: $CHECKPOINT_DIR"

echo ""
echo "=== Step 2: 加载checkpoint继续训练2步 ==="

docker exec verl-npu bash -lc "
source /usr/local/Ascend/ascend-toolkit/set_env.sh;
cd ${WORK_DIR}/verl;
python -m verl.trainer.main_ppo \
    algorithm.adv_estimator=grpo \
    data.train_files=${TRAIN_DATA} \
    data.val_files=${VAL_DATA} \
    data.train_batch_size=256 \
    data.max_prompt_length=256 \
    data.max_response_length=256 \
    actor_rollout_ref.model.path=${CHECKPOINT_DIR} \
    actor_rollout_ref.actor.optim.lr=3e-6 \
    actor_rollout_ref.model.enable_gradient_checkpointing=True \
    actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.actor.ppo_mini_batch_size=256 \
    actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.ref.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.rollout.gpu_memory_utilization=0.3 \
    actor_rollout_ref.rollout.n=2 \
    actor_rollout_ref.rollout.tensor_model_parallel_size=1 \
    trainer.project_name=verl_grpo_demo \
    trainer.experiment_name=verify_checkpoint \
    trainer.device=npu \
    trainer.n_gpus_per_node=2 \
    trainer.save_freq=2 \
    trainer.test_freq=2 \
    trainer.total_epochs=1 \
    trainer.total_training_steps=5 \
    trainer.logger=[\"console\"] \
    trainer.default_local_dir=${WORK_DIR}/checkpoints/verify2 \
    > ${WORK_DIR}/verify2_log.txt 2>&1
"

echo "验证完成！检查日志:"
echo "  - 第一次训练: ${WORK_DIR}/verify1_log.txt"
echo "  - 第二次加载训练: ${WORK_DIR}/verify2_log.txt"
echo "  - Checkpoint: $CHECKPOINT_DIR"
