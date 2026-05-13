if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

if [ -z "${BASHRC_SOURCED-}" ]; then
	export PATH=$HOME/.nix/state/gcroots/current/bin:$HOME/bin:$PATH
	ulimit -s unlimited
	export HISTFILESIZE=1000000
	export BASHRC_SOURCED=1
fi
