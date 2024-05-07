# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

export PATH=$PATH:/data/gpfs01/wlin/bin

# User specific aliases and functions
export PATH=/data/gpfs01/wlin/bin/vaspkit.1.4.1/bin:${PATH}
#export PATH=~/bin:/data/gpfs01/wlin/opt/mpich_ifort/bin:$PATH
#export LD_LIBRARY_PATH=/data/gpfs01/wlin/opt/mpich_ifort/lib:$LD_LIBRARY_PATH
#export PATH=~/bin:/data/gpfs01/wlin/opt/mpich/bin:$PATH
#export LD_LIBRARY_PATH=/data/gpfs01/wlin/opt/mpich/lib:$LD_LIBRARY_PATH
export P4_RSHCOMMAND=ssh
 shopt -s cdspell
 export HISTCONTROL=ignoredups
#shopt -s histappend
 PROMPT_COMMAND='history -a'
 export C3_RSH="ssh -x"
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
alias grep='grep --color'
USER_IP=`who -u am i 2>/dev/null| awk '{print $NF}'|sed -e 's/[()]//g'` 
 
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  `whoami`@${USER_IP}: "
export HISTFILESIZE=1000000
export PROMPT_COMMAND="history -a; history -r;  $PROMPT_COMMAND"
shopt -s histappend
# Auto add env parameter $PROMPT_COMMAND when use non-Linux tty login by ssh.
if [ "$SSH_CONNECTION" != '' -a "$TERM" != 'linux' ]; then
declare -a HOSTIP
HOSTIP=`echo $SSH_CONNECTION |awk '{print $3}'`
export PROMPT_COMMAND='echo -ne "\033]0;${USER}@$HOSTIP:[${HOSTNAME%%.*}]:${PWD/#$HOME/~} \007"'
fi
ulimit -s unlimited
export PYTHONPATH=/data/gpfs01/wlin/bin/VaspBandUnfolding-master:${PYTHONPATH}

# vsts, see https://theory.cm.utexas.edu/vtsttools/scripts.html
export PATH=$PATH:/data/gpfs01/wlin/yjj/vtstscripts-1022
export PERL5LIB=/data/gpfs01/wlin/yjj/vtstscripts-1022

