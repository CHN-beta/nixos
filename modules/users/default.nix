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
						root =
						{
							shell = inputs.pkgs.zsh;
							hashedPassword = "$y$j9T$.UyKKvDnmlJaYZAh6./rf/$65dRqishAiqxCE6LEMjqruwJPZte7uiyYLVKpzdZNH5";
							openssh.authorizedKeys.keys =
							[
								("sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPLByi05vCA95EfpgrCIXzkuyUWsyh"
									+ "+Vso8FsUNFwPXFAAAABHNzaDo= chn@chn.moe")
							];
						};
						chn =
						{
							isNormalUser = true;
							extraGroups = inputs.lib.intersectLists
								[ "adbusers" "networkmanager" "wheel" "wireshark" "libvirtd" "video" "audio" ]
								(builtins.attrNames inputs.config.users.groups);
							shell = inputs.pkgs.zsh;
							autoSubUidGidRange = true;
							hashedPassword = "$y$j9T$xJwVBoGENJEDSesJ0LfkU1$VEExaw7UZtFyB4VY1yirJvl7qS7oiF49KbEBrV0.hhC";
						};
					};
					mutableUsers = false;
				};
			}
			# (mkMerge (map (user:
			# {
			# 	sops.secrets."password/${user}".neededForUsers = true;
			# 	users.users.${user}.passwordFile = inputs.config.sops.secrets."password/${user}".path;
			# }) [ "root" "chn" ]))
			{
				home-manager =
				{
					useGlobalPkgs = true;
					useUserPackages = true;
					users =
						let
							normal = { gui ? false }: { pkgs, ...}:
							{
								home.stateVersion = "22.11";
								programs =
								{
									zsh =
									{
										enable = true;
										initExtraBeforeCompInit = stripeTabs
										''
											# p10k instant prompt
											typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
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
										];
										history =
										{
											extended = true;
											save = 100000000;
											size = 100000000;
											share = true;
										};
									};
									direnv = { enable = true; nix-direnv.enable = true; };
									git =
									{
										enable = true;
										lfs.enable = true;
										userEmail = "chn@chn.moe";
										userName = "chn";
										extraConfig =
										{
											core.editor = if gui then "code --wait" else "vim";
											advice.detachedHead = false;
											merge.conflictstyle = "diff3";
											diff.colorMoved = "default";
										};
										package = pkgs.gitFull;
										delta =
										{
											enable = true;
											options =
											{
												side-by-side = true;
												navigate = true;
												syntax-theme = "GitHub";
												light = true;
												zero-style = "syntax white";
												line-numbers-zero-style = "#ffffff";
											};
										};
									};
									ssh =
									{
										enable = true;
										controlMaster = "auto";
										controlPersist = "1m";
										matchBlocks = builtins.listToAttrs
										(
											(map
												(host:
												{
													name = host.name;
													value = { host = host.name; hostname = host.value; user = "chn"; };
												})
												(inputs.localLib.attrsToList
												{
													vps3 = "vps3.chn.moe";
													vps4 = "vps4.chn.moe";
													vps5 = "vps5.chn.moe";
													vps6 = "vps6.chn.moe";
													vps7 = "vps7.chn.moe";
													nas = "192.168.1.188";
												}))
											++ (map
												(host:
												{
													name = host;
													value =
													{
														host = host;
														hostname = "hpc.xmu.edu.cn";
														user = host;
														extraOptions = { PubkeyAcceptedAlgorithms = "+ssh-rsa"; HostkeyAlgorithms = "+ssh-rsa"; };
													};
												})
												[ "wlin" "jykang" "hwang" ])
										)
										// {
											xmupc1 =
											{
												host = "xmupc1";
												hostname = "office.chn.moe";
												user = "chn";
												port = 6007;
											};
											xmupc1-ext =
											{
												host = "xmupc1-ext";
												hostname = "vps3.chn.moe";
												user = "chn";
												port = 6007;
											};
											xmuhk =
											{
												host = "xmuhk";
												hostname = "10.26.14.56";
												user = "xmuhk";
												# identityFile = "~/.ssh/xmuhk_id_rsa";
											};
											xmuhk2 =
											{
												host = "xmuhk2";
												hostname = "183.233.219.132";
												user = "xmuhk";
												port = 62022;
											};
										};
									};
									vim =
									{
										enable = true;
										defaultEditor = true;
										settings =
										{
											number = true;
											expandtab = false;
											shiftwidth = 2;
											tabstop = 2;
										};
										extraConfig = inputs.localLib.stripeTabs
										''
											set clipboard=unnamedplus
											colorscheme evening
										'';
									};
								};
							};
						in
						{
							root = normal { gui = false; };
							chn = normal { gui = inputs.config.nixos.system.gui.enable; };
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