# slurm

## 基本概念

队列系统换成了 slurm。这是个正经的队列系统（不像之前那样是临时手搓的），可靠性应该会好很多。
hpc 上用的是 PBS，和这个不一样，但很多概念是相通的，例如队列、节点等（当然这里只有一个队列和一个节点）。
这里简单记录一下如何使用。更多内容，网上随便搜一下 slurm 的教程就可以找到很多介绍，也可以看官网文档。

先说明一下机器的硬件配置：16 个核，每个核 2 线程，也就是总共 32 个线程。
slurm 限制 CPU 按照核（而不是线程）分配，
  之后的 `sbatch` 命令中的 `cpu` 或者 `core` （它俩是同义词）都是指核的数量而不是线程数
  （实际运行的线程数要乘以 2）。

VASP 支持两个层面的并行，一个叫 MPI，一个叫 OpenMP，实际运行的线程数是两者的乘积。
MPI 并行的数量等于提交任务时指定的 task 的数量，
  OpenMP 并行的数量等于提交任务时指定的分配给每个 task 的 CPU 的数量再乘以 2，
  也就是最终的线程数等于指定的 CPU 数量乘以 2。
此外还有一个限制：当使用 GPU 时，MPI 并行的数量必须等于 GPU 的数量，否则 VASP 会在开头报个警告然后只用 CPU 计算。

## 常用命令

提交一个 VASP GPU 任务的例子：

```bash
sbatch --gpus=1 --job-name="my great job" vasp-nvidia-6.4.0 mpirun vasp-std
```

* `--gpus=1` 指定使用一个 GPU（排到这个任务时哪个空闲就使用哪个）。
  可以指定具体使用哪个GPU，例如 `--gpus=4090:1`。
  可以简写为 `-G`。
* `--job-name=` 指定任务的名字。可以简写为 `-J`。也可以不指定。
* 默认情况下，一个 GPU 会搭配一个 CPU 核（两个线程），一般不用修改。

提交一个 VASP CPU 任务的例子：

```bash
sbatch --ntasks=2 --cpus-per-task=2 --job-name="my great job" vasp-gnu-6.4.0 mpirun vasp-std
```

* `--ntasks=2` 指定在 MPI 层面上并行的数量。
  可以简写为 `-n`。
* `--cpus-per-task=2` 指定每个 task 使用的 CPU 核的数量，OpenMP 并行的数量等于这个数再乘以 2。

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
# 将一些环境变量传递给任务（=ALL是默认行为）
sbatch --export=ALL,MY_ENV_VAR=my_value my_great_job.sh
# 不传递现在的环境变量
sbatch --export=NONE my_great_job.sh
# 打开一个文件作为标准输入
--input=
-J, --job-name
--mail-type=NONE, BEGIN, END, FAIL, REQUEUE, ALL
--mail-user
--mem=20G
--mem-per-cpu or --mem-per-gpu
不会真的限制
-n, --ntasks
--ntasks-per-core
--ntasks-per-gpu
--ntasks-per-node
--open-mode={append|truncate}
-o, --output=<filename_pattern>
# 不排队，直接跑（超额分配）
-s, --oversubscribe
# --priority
--wrap=
scontrol top job_id
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