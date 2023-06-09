{ pkgs }:
{
	enable = true;
	initExtraBeforeCompInit =
	''
		# p10k instant prompt
		P10K_INSTANT_PROMPT="$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh"
		[[ ! -r "$P10K_INSTANT_PROMPT" ]] || source "$P10K_INSTANT_PROMPT"

		HYPHEN_INSENSITIVE="true"

		export PATH=~/bin:$PATH

		function br
		{
			local cmd cmd_file code
			cmd_file=$(mktemp)
			if broot --outcmd "$cmd_file" "$@"; then
				cmd=$(<"$cmd_file")
				command rm -f "$cmd_file"
				eval "$cmd"
			else
				code=$?
				command rm -f "$cmd_file"
				return "$code"
			fi
		}
	'';
	plugins =
	[
		{
			file = "powerlevel10k.zsh-theme";
			name = "powerlevel10k";
			src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
		}
		{
			file = "p10k.zsh";
			name = "powerlevel10k-config";
			src = ./p10k-config;
		}
		{
			name = "zsh-lsd";
			src = pkgs.fetchFromGitHub
			{
        owner = "z-shell";
        repo = "zsh-lsd";
        rev = "029a9cb0a9b39c9eb6c5b5100dd9182813332250";
				sha256 = "sha256-oWjWnhiimlGBMaZlZB+OM47jd9hporKlPNwCx6524Rk=";
      };
		}
		# {
		# 	name = "zsh-exa";
		# 	src = pkgs.fetchFromGitHub
		# 	{
		# 		owner = "ptavares";
		# 		repo = "zsh-exa";
		# 		rev = "0.2.3";
		# 		sha256 = "0vn3iv9d3c1a4rigq2xm52x8zjaxlza1pd90bw9mbbkl9iq8766r";
		# 	};
		# }
	];
}
