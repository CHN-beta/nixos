# slurm

队列系统换成了 slurm。这是个正经的队列系统（不像之前那样是临时手搓的）可靠性应该会好很多。
hpc 上用的是 PBS，和这个不一样，但很多概念是相通的，例如队列、节点等（当然这里只有一个队列和一个节点）。
网上随便搜一下 slurm 的教程就可以找到很多介绍，也可以看官网文档。这里简单记录一下如何使用。

## 提交新任务

```bash
# 提交一个新任务，默认会占用队列中的全部资源（包括GPU和CPU），一般不要这样干
sbatch all_resources_is_mine.sh
# 提交一个新任务，但是礼让后面的任务（推迟到指定时间再开始排队）
sbatch --begin=16:00 my_great_job.sh
sbatch --begin=now+1hour my_great_job.sh
# 使用别的工作目录
sbatch --chdir=/path/to/your/workdir my_great_job.sh
# 指定备注
sbatch --comment="my great job" my_great_job.sh
# 提交 GPU 任务时，指定每个 GPU 配几个 CPU 核（不需要再设置 cpus-per-task）
sbatch --cpus-per-gpu=2 my_gpu_job.sh
# 每个 task 使用多少 CPU 核
sbatch --cpus-per-task=4 my_great_job.sh
# 指定任务的 ddl，算不完就杀掉
sbatch --deadline=now+1hour my_great_job.sh
# 标准错误输出写到别的文件里
sbatch --error=error.log my_great_job.sh
```

## 列出已经提交的任务

```bash
squeue
# 如果想列出更多信息
squeue -t all -l
```

## 取消任务

```bash
# 按任务的 id 取消
scancel 114514
# 按任务的名字取消
scancel -n my_great_job
# 取消一个用户的所有任务
scancel -u chn
```