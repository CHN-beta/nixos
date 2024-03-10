# 硬件

* CPU：16 核 32 线程。
* 内存：96 G。
* 显卡：
  * 4090：24 G 显存。
  * 3090：24 G 显存。
* 硬盘：12 T。

更详细的硬件如果需要的话，自己去看吧。

# 队列系统（SLURM）

## 基本概念

队列系统使用 slurm。这是个在集群上广泛使用的队列系统，可靠性应该会比之前好很多。
学校的 hpc 上用的是 PBS，和这个不一样，但很多概念是相通的，例如队列、节点等（当然这里只有一个队列和一个节点）。
这里只简单记录一下如何使用。更多内容，网上随便搜一下 slurm 的教程就可以找到很多介绍，也可以看官网文档。

slurm 限制 CPU 按照核（而不是线程）分配，
  提交任务时， `sbatch` 命令中的 `cpu` 或者 `core` （它俩是同义词）都是指核的数量而不是线程数
  （也就是说，实际运行的线程数要再乘以 2）。

一些软件（例如 VASP）支持两个层面的并行，一个叫 MPI，一个叫 OpenMP，实际运行的线程数是两者的乘积。
MPI 并行的数量就是提交任务时指定的 task 的数量，
  OpenMP 并行的数量等于提交任务时指定的分配给每个 task 的 CPU 的数量再乘以 2，
  也就是最终的线程数等于指定的 CPU 数量乘以 2。
此外对于 VASP 还有一个限制：当使用 GPU 时，MPI 并行的数量必须等于 GPU 的数量，否则 VASP 会在开头报个警告然后只用 CPU 计算（但不会报错）。
其它大多使用 MPI 并行的软件没有这个限制。

## 常用命令

提交一个 VASP GPU 任务的例子：

```bash
sbatch --gpus=1 --ntasks-per-gpu=1 --job-name="my great job" vasp-nvidia-6.4.0 mpirun vasp-std
```

* `--gpus=1` 指定使用一个 GPU（排到这个任务时哪个空闲就使用哪个）。
  可以指定具体使用哪个GPU，例如 `--gpus=4090:1`。2080 Ti 需要写为 `2080_ti`。
  这个选项可以简写为 `-G`。
  这个选项实际上是 `--gres` 选项的一种简便写法，当需求更复杂时（例如，指定使用一个 3090 和一个 4090）时，就需要用 `--gres`。
  例如：`--gres=gpu:3090:1,gpu:4090:1`。
  “gre” 是 “generic resource” 的缩写。
* `--ntasks-per-gpu=1` 是一定要写的。
* `--job-name=` 指定任务的名字。可以简写为 `-J`。也可以不指定。
* 默认情况下，一个 task 会搭配分配一个 CPU 核（两个线程），一般不用修改。如果一定要修改，用 `--cpus-per-task`。

提交一个 VASP CPU 任务的例子：

```bash
sbatch --ntasks=2 --cpus-per-task=2 --job-name="my great job" vasp-gnu-6.4.0 mpirun vasp-std
```

* `--ntasks=2` 指定在 MPI 层面上并行的数量。
  可以简写为 `-n`。
* `--cpus-per-task=2` 指定每个 task 使用的 CPU 核的数量，OpenMP 并行的数量等于这个数再乘以 2。

要列出已经提交（包括已经完成、取消、失败）的任务：

```bash
squeue -t all -l
```

取消一个任务：

```bash
# 按任务的 id 取消
scancel 114514
# 按任务的名字取消
scancel -n my_great_job
# 取消一个用户的所有任务
scancel -u chn
```

要将自己已经提交的一个任务优先级提到最高（只是自己已经提交任务的最高，不影响别人的任务）：

```bash
scontrol top job_id
```

## `sbatch` 的更多参数

```bash
# 提交一个新任务，但是礼让后面的任务（推迟到指定时间再开始排队）
--begin=16:00 --begin=now+1hour
# 指定工作目录
--chdir=/path/to/your/workdir
# 指定备注
--comment="my great job"
# 指定任务的 ddl，算不完就杀掉
--deadline=now+1hour
# 标准错误输出写到别的文件里
--error=error.log
# 将一些环境变量传递给任务（=ALL是默认行为）
--export=ALL,MY_ENV_VAR=my_value
# 不传递现在的环境变量
--export=NONE
# 打开一个文件作为标准输入
--input=
# 发生一些事件（任务完成等）时发邮件
--mail-type=NONE,BEGIN,END,FAIL,REQUEUE,ALL --mail-user=chn@chn.moe
# 要求分配内存（不会真的限制内存使用，只是在分配资源时会考虑）
--mem=20G --mem-per-cpu --mem-per-gpu
# 输出文件是否覆盖
--open-mode={append|truncate}
# 指定输出文件
-o, --output=<filename_pattern>
# 不排队，直接跑（超额分配）
-s, --oversubscribe
# 包裹一个二进制程序
--wrap=
```

# 支持的连接协议

## SSH

ssh 就是 putty winscp 之类的工具使用的那个协议。

* 地址：xmupc1.chn.moe
* 端口：6007
* 用户名：自己名字的拼音首字母
* 可以用密码登陆，也可以用证书登陆。

从一台服务器登陆到其它服务器，只需要使用 `ssh`` 命令：

```bash
ssh jykang
ssh xmupc1
ssh xmupc2
ssh user@host
```

直接从另外一台服务器下载文件，可以使用 `rsync` 命令：

```bash
rsync -avzP jykang:/path/to/remote/directory_or_file /path/to/local/directory
```

将另外一个服务器的某个目录挂载到这个服务器，可以使用 `sshfs` 命令：

```bash
sshfs jykang:/path/to/remote/directory /path/to/local/directory
```

用完之后记得卸载（不卸载也不会有什么后果，只是怕之后忘记了以为这是本地的目录，以及如果网络不稳定的话，运行在这里的软件可能会卡住）：

```bash
umount /path/to/local/directory
```

如果不喜欢敲命令来挂载/卸载远程目录，也可以 RDP 登陆后用 dolphin。

## RDP

就是 windows 那个远程桌面。

* 地址：xmupc1.chn.moe
* 用户名：自己名字的拼音首字母
* 密码和 ssh 一样（使用同样的验证机制）。

RDP 暂时没有硬件加速（就是半透明之类的特效会有点卡），但也是能用的。

## samba

samba 就是 windows 共享文件夹的那个协议。

* 地址：xmupc1.chn.moe
* 用户名：自己名字的拼音首字母
* 初始密码和 ssh 一样，你可以自己修改密码（使用 `smbpasswd` 命令）。samba 的密码和 ssh/rdp 的密码是分开的，它们使用不同的验证机制。

在 windows 上，可以直接在资源管理器中输入 `\\xmupc1.chn.moe` 访问。
也可以将它作为一个网络驱动器添加（地址同样是 `\\xmupc1.chn.moe`）。

# 其它软件

我自己电脑上有的软件，服务器都有装，用于科研的比如 VESTA 什么的。可以自己去菜单里翻一翻。

## 操作系统

操作系统是 NixOS，是一个相对来说比较小众的系统。
它是一个所谓“函数式”的系统。
也就说，理想情况下，系统的状态（包括装了什么软件、每个软件和服务的设置等等）是由一组配置文件唯一决定的（这组配置文件放在 `/etc/nixos` 中）。
要修改系统的状态（新增软件、修改设置等等），只需要修改这组配置文件，然后要求系统应用这组配置文件就可以了，
  系统会自动计算出应该怎么做（增加、删除、修改哪些文件，重启哪些服务等等）。
这样设计有许多好处，例如可以方便地回滚到之前任意一个时刻的状态（方便在调试时试错）；
  一份配置文件可以描述多台机器的系统，在一台上调试好后在其它机器上直接部署；
  以及适合抄或者引用别人写好的配置文件。

以上都是对于管理员来说的好处。对于用户来说的好处不是太多，但是也有一些。
举个例子，如果用户需要使用一个没有安装的软件（例如 `phonopy`，当然实际上这个已经装了），只需要在要执行的命令前加一个逗号：

```bash
, phonopy --dim 2 2 2
```

系统就会帮你下载所有的依赖，并在一个隔离的环境中运行这个命令（不会影响这之后系统的状态）。

还有一个命令可能也有用，叫 `try`。
它会在当前的文件系统上添加一个 overlay，之后执行的命令对文件的修改只会发生在这个 overlay 上；
  命令执行完成后，它会告诉你哪些文件发生了改变，然后可以选择实际应用这些改变还是丢弃这些改变。
例如：

```bash
try phonopy --dim 2 2 2
```

这个命令和 NixOS 无关，只是突然想起来了。

## 文件系统

文件系统是 BtrFS。它的好处有：

* 同样的内容只占用一份空间；以及内容会被压缩存储（在读取时自动解压）。这样大致可以节省一半左右的空间。
  例如现在 xll 目录里放了 213 G 文件，但只占用了 137 G 空间。
* 每小时自动备份，放置在 `/nix/persistent/.snapshots` 中，大致上会保留最近一周的备份。如果你误删了什么文件，可以去里面找回。

## ZSH

所谓 “shell” 就是将敲击的一行行命令转换成操作系统能理解的系统调用（C 语言的函数）的那个东西，也就是负责解释敲进去的命令的意思的那个程序。

大多情况下默认的 shell 是 bash，但我装的服务器上用 zsh。
zsh 几乎完全兼容 bash 的语法，除此以外有一些顺手的功能：
* 如果忘记了曾经输入过的一个命令，输入其中的几个连续的字母或者单词（不一定是开头的几个字母），然后按 `↑` 键，就会自动在历史命令中依次搜索。
  例如我输入 `install` 按几下 `↑` 键，就可以找到 `sudo nixos-rebuild boot --flake . --install-bootloader --option substituters https://nix-store.chn.moe` 这个东西。
* 如果从头开始输入一个曾经输入过的命令，会用浅灰色提示这个命令。要直接补全全部命令，按 `→` 键。要补全一个单词，按 `Ctrl` + `→` 键。
* 常用的命令，以及常用命令的常用选项，按几下 `tab` 键，会自动补全或者弹出提示。
