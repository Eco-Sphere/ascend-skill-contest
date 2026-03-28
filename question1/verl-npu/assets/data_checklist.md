# verl GRPO 训练数据准备检查清单

## 1. 模型文件检查

- [ ] 模型目录存在: `<model_path>`
- [ ] 包含 `config.json`
- [ ] 包含 `model.safetensors` 或 `pytorch_model.bin`
- [ ] 包含 `tokenizer.json` 或 `tokenizer_config.json`
- [ ] 包含 `tokenizer.model` 或 `vocab.json`

## 2. 数据文件检查

- [ ] 训练数据parquet存在: `<train_data>`
- [ ] 验证数据parquet存在: `<val_data>`

### parquet文件要求

数据应包含以下列（以gsm8k为例）:
- `prompt` 或 `question`: 输入问题
- `answer` 或 `response`: 期望答案
- `content`: 完整对话内容

## 3. 目录权限检查

- [ ] 工作目录可写: `<work_dir>`
- [ ] checkpoint目录可创建: `<work_dir>/checkpoints`
- [ ] 日志目录可写: `<work_dir>/logs`

## 4. 容器挂载检查

- [ ] `/home` 正确挂载
- [ ] Ascend driver 正确挂载
- [ ] Ascend add-ons 正确挂载

## 5. 验证命令

```bash
# 检查模型
ls -la <model_path>

# 检查数据
python -c "import pandas as pd; df = pd.read_parquet('<train_data>'); print(df.columns)"

# 检查目录权限
ls -la <work_dir>
```

---
检查时间: __________
