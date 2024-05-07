# This is really FOLLISH but it works
if [ -z "${BASHRC_SOURCED-}" ]; then
	if [[ $TERM == chn_unset_ls_colors* ]]; then
		export TERM=${TERM#*:}
		export CHN_LS_USE_COLOR=1
	fi
	if [[ $TERM == chn_cd* ]]; then
		export TERM=${TERM#*:}
		cd ~/${TERM%%:*}
		export TERM=${TERM#*:}
	fi
	if [[ $TERM == hpcstat_subaccount* ]]; then
		export TERM=${TERM#*:}
		export HPCSTAT_SUBACCOUNT=${TERM%%:*}
		export TERM=${TERM#*:}
	fi
	if [[ $TERM == chn_debug* ]]; then
		export TERM=${TERM#*:}
		export CHN_DEBUG=1
	fi
fi

if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

if [ -z "${BASHRC_SOURCED-}" ]; then
	export BASHRC_SOURCED=1
	export PATH=$PATH:$HOME/bin:$HOME/linwei/chn/software/scripts

	# script in ~/linwei/chn/software/hpcstat should have higher priority
	if [ -n "${SSH_AUTH_SOCK-}" ]; then
		export PATH=$HOME/linwei/chn/software/hpcstat/bin:$PATH
		export HPCSTAT_DATADIR=$HOME/linwei/chn/software/hpcstat/var/lib/hpcstat
		export HPCSTAT_SHAREDIR=$HOME/linwei/chn/software/hpcstat/share/hpcstat
		export HPCSTAT_SSH_BINDIR=$HOME/linwei/chn/software/hpcstat/bin
		export HPCSTAT_BSUB=/opt/ibm/lsfsuite/lsf/10.1/linux2.6-glibc2.3-x86_64/bin/bsub
		hpcstat login
		if [ "$?" -ne 0 ]; then
			exit 1
		fi
	fi

	# check if there exists non-interative login without ssh
	if [ -z "${SSH_CONNECTION-}" ]; then
		echo "Non-interactive login detected" >> $HOME/linwei/chn/log
	fi
fi

[ -n "$CHN_LS_USE_COLOR" ] && alias ls="ls --color=auto"
