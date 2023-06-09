{
	config.programs.zsh =
	{
		enable = true;
		syntaxHighlighting.enable = true;
		autosuggestions.enable = true;
		enableCompletion = true;
		ohMyZsh =
		{
			enable = true;
			plugins = [ "git" "colored-man-pages" "extract" "history-substring-search" "autojump" ];
		};
	};
}
