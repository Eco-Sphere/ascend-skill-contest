#!/bin/bash
# verl GRPO 训练启动脚本

# 参数检查
if [ $# -lt 4 ]; then
    echo "Usage: $0 <work_dir> <model_path> <train_data> <val_data> [n_gpus] [save_freq] [total_steps]"
    echo "Example: $0 /home/zzw30069617 /home/z30069617/models/Qwen3-0.6B /home/z30069617/datasets/gsm8k/processed/train.parquet /home/z30069617/datasets/gsm8k/processed/val.parquet 2 3 3"
    exit 1
fi

WORK_DIR=$1
MODEL_PATH=$2
TRAIN_DATA=$3
VAL_DATA=$4
N_GPUS=${5:-2}
SAVE_FREQ=${6:-3}
TOTAL_STEPS=${7:-3}

# 计算显存利用率和批次大小
if [ $N_GPUS -eq 8 ]; then
    GPU_MEM=0.5
    BATCH_SIZE=64
elif [ $N_GPUS -eq 4 ]; then
    GPU_MEM=0.4
    BATCH_SIZE=32
elif [ $N_GPUS -eq 2 ]; then
    GPU_MEM=0.3
    BATCH_SIZE=256
else
    GPU_MEM=0.2
    BATCH_SIZE=128
fi

LOG_FILE="${WORK_DIR}/training_log.txt"

docker exec verl-npu bash -lc "
source /usr/local/Ascend/ascend-toolkit/set_env.sh;
cd ${WORK_DIR};
if [ ! -d \"verl\" ]; then
    echo \"Cloning verl repository...\";
    git clone https://github.com/verl-project/verl.git;
fi
cd ${WORK_DIR}/verl;
nohup python -m verl.trainer.main_ppo \
    algorithm.adv_estimator=grpo \
    data.train_files=${TRAIN_DATA} \
    data.val_files=${VAL_DATA} \
    data.train_batch_size=${BATCH_SIZE} \
    data.max_prompt_length=256 \
    data.max_response_length=256 \
    actor_rollout_ref.model.path=${MODEL_PATH} \
    actor_rollout_ref.actor.optim.lr=3e-6 \
    actor_rollout_ref.model.enable_gradient_checkpointing=True \
    actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.actor.ppo_mini_batch_size=${BATCH_SIZE} \
    actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.ref.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.rollout.gpu_memory_utilization=${GPU_MEM} \
    actor_rollout_ref.rollout.n=2 \
    actor_rollout_ref.rollout.tensor_model_parallel_size=1 \
    trainer.project_name=verl_grpo_demo \
    trainer.experiment_name=qwen3_0_6b_gsm8k \
    trainer.device=npu \
    trainer.n_gpus_per_node=${N_GPUS} \
    trainer.save_freq=${SAVE_FREQ} \
    trainer.test_freq=${SAVE_FREQ} \
    trainer.total_epochs=1 \
    trainer.total_training_steps=${TOTAL_STEPS} \
    trainer.logger=[\"console\"] \
    trainer.default_local_dir=${WORK_DIR}/checkpoints/verl_grpo_demo \
    > ${LOG_FILE} 2>&1 &
echo \"Training started, log: ${LOG_FILE}\"
"

echo "Log file: ${LOG_FILE}"
echo "Monitor with: tail -f ${LOG_FILE}"
