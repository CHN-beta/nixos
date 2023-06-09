{ pkgs }:
{
	enable = true;
	initExtraBeforeCompInit =
	''
		# p10k instant prompt
		P10K_INSTANT_PROMPT="$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh"
		[[ ! -r "$P10K_INSTANT_PROMPT" ]] || source "$P10K_INSTANT_PROMPT"

		HYPHEN_INSENSITIVE="true"
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
			name = "zsh-exa";
			src = pkgs.fetchFromGitHub
			{
				owner = "ptavares";
				repo = "zsh-exa";
				rev = "0.2.3";
				sha256 = "0vn3iv9d3c1a4rigq2xm52x8zjaxlza1pd90bw9mbbkl9iq8766r";
			};
		}
	];
}
