inputs:
{
	config =
		let
			inherit (inputs.lib) listToAttrs mkMerge;
			inherit (builtins) map;
			inherit (inputs.localLib) stripeTabs;
		in mkMerge
		[
			{
				users =
				{
					users =
					{
						root.shell = inputs.pkgs.zsh;
						chn =
						{
							isNormalUser = true;
							extraGroups = inputs.lib.intersectLists
								[ "adbusers" "networkmanager" "wheel" "wireshark" "libvirtd" "video" "audio" ]
								(builtins.attrNames inputs.config.users.groups);
							shell = inputs.pkgs.zsh;
							autoSubUidGidRange = true;
						};
					};
					mutableUsers = false;
				};
			}
			(mkMerge (map (user:
			{
				sops.secrets."password/${user}".neededForUsers = true;
				users.users.${user}.passwordFile = inputs.config.sops.secrets."password/${user}".path;
			}) [ "root" "chn" ]))
			{
				home-manager =
				{
					useGlobalPkgs = true;
					useUserPackages = true;
					users =
						let
							normal = { pkgs, ...}:
							{
								home.stateVersion = "22.11";
								programs.zsh =
								{
									enable = true;
									initExtraBeforeCompInit = stripeTabs
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

										alias todo="todo.sh"
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
									history =
									{
										extended = true;
										save = 100000000;
										size = 100000000;
										share = true;
									};
								};
								programs.direnv = { enable = true; nix-direnv.enable = true; };
							};
						in
						{
							root = normal;
							chn = normal;
						};
				};
			}
		];
}

# environment.persistence."/impermanence".users.chn =
# {
# 	directories =
# 	[
# 		"Desktop"
# 		"Documents"
# 		"Downloads"
# 		"Music"
# 		"repo"
# 		"Pictures"
# 		"Videos"

# 		".cache"
# 		".config"
# 		".gnupg"
# 		".local"
# 		".ssh"
# 		".android"
# 		".exa"
# 		".gnome"
# 		".Mathematica"
# 		".mozilla"
# 		".pki"
# 		".steam"
# 		".tcc"
# 		".vim"
# 		".vscode"
# 		".Wolfram"
# 		".zotero"

# 	];
# 	files =
# 	[
# 		".bash_history"
# 		".cling_history"
# 		".gitconfig"
# 		".gtkrc-2.0"
# 		".root_hist"
# 		".viminfo"
# 		".zsh_history"
# 	];
# };