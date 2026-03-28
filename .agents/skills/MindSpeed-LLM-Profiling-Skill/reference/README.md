# Profiling 采集参考文档

## 官方文档

- MindSpeed-LLM Profiling 文档：`/work/MindSpeed-LLM/docs/zh/pytorch/tools/profiling.md`
- CANN Profiling 工具：https://www.hiascend.com/document/detail/zh/canncommercial/82RC1/devaids/Profiling/atlasprofiling_16_0033.html
- MindStudio Insight：https://gitcode.com/Ascend/msinsight

## 相关路径

- 训练脚本示例：`/work/MindSpeed-LLM/examples/mcore/qwen3/pretrain_qwen3_8b_4K_ptd.sh`
- 默认 profile 输出：`./profile_dir`

## 采集参数快速参考

```bash
# 启用采集
--profile

# 采集范围（必选）
--profile-step-start 12      # 从第12步开始
--profile-step-end 14         # 到第14步结束（采集12-13步）

# 采集级别
--profile-level level1        # 推荐级别

# 采集内容
--profile-ranks 0             # 采集0号卡
--profile-with-cpu            # 采集CPU数据
--profile-with-memory         # 采集内存数据
--profile-with-stack          # 采集堆栈
--profile-record-shapes       # 采集shape

# 输出路径
--profile-save-path ./profile_dir
```
