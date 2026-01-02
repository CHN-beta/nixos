# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs
export PATH=/data/gpfs01/wlin/.nix/state/gcroots/current/bin:$HOME/bin:$PATH
ulimit -s unlimited
