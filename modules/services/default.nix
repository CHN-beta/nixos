inputs:
{
	options.nixos.services = let inherit (inputs.lib) mkOption types; in
	{
		impermanence =
		{
			enable = mkOption { type = types.bool; default = false; };
			persistence = mkOption { type = types.nonEmptyStr; default = "/nix/persistent"; };
		};
    snapper =
    {
      enable = mkOption { type = types.bool; default = false; };
      configs = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
    };
		kmscon.enable = mkOption { type = types.bool; default = false; };
		fontconfig.enable = mkOption { type = types.bool; default = false; };
		u2f.enable = mkOption { type = types.bool; default = false; };
		sops =
		{
			enable = mkOption { type = types.bool; default = false; };
			keyPathPrefix = mkOption { type = types.str; default = ""; };
		};
		samba =
		{
			enable = mkOption { type = types.bool; default = false; };
			wsdd = mkOption { type = types.bool; default = false; };
			private = mkOption { type = types.bool; default = false; };
			hostsAllowed = mkOption { type = types.str; default = "127."; };
			shares = mkOption
			{
				type = types.attrsOf (types.submodule { options =
				{
					comment = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
					path = mkOption { type = types.nonEmptyStr; };
				};});
				default = {};
			};
		};
		sshd.enable = mkOption { type = types.bool; default = false; };
	};
	config =
		let
			inherit (inputs.lib) mkMerge mkIf;
			inherit (inputs.localLib) stripeTabs attrsToList;
			inherit (inputs.config.nixos) services;
		in mkMerge
		[
			(
				mkIf services.impermanence.enable
				{
					environment.persistence."${services.impermanence.persistence}" =
					{
						hideMounts = true;
						directories =
						[
							"/etc/NetworkManager/system-connections"
							"/home"
							"/root"
							"/var"
						];
						files =
						[
							"/etc/machine-id"
							"/etc/ssh/ssh_host_ed25519_key.pub"
							"/etc/ssh/ssh_host_ed25519_key"
							"/etc/ssh/ssh_host_rsa_key.pub"
							"/etc/ssh/ssh_host_rsa_key"
						];
					};
				}
			)
			(
				mkIf services.snapper.enable
				{
					services.snapper.configs =
						let
							f = (config:
							{
								inherit (config) name;
								value =
								{
									SUBVOLUME = config.value;
									TIMELINE_CREATE = true;
									TIMELINE_CLEANUP = true;
									TIMELINE_MIN_AGE = 1800;
									TIMELINE_LIMIT_HOURLY = "10";
									TIMELINE_LIMIT_DAILY = "7";
									TIMELINE_LIMIT_WEEKLY = "1";
									TIMELINE_LIMIT_MONTHLY = "0";
									TIMELINE_LIMIT_YEARLY = "0";
								};
							});
						in
							builtins.listToAttrs (builtins.map f (attrsToList services.snapper.configs));
				}
			)
			(
				mkIf services.kmscon.enable
				{
					services.kmscon =
					{
						enable = true;
						fonts = [{ name = "FiraCode Nerd Font Mono"; package = inputs.pkgs.nerdfonts; }];
					};
				}
			)
			(
				mkIf services.fontconfig.enable
				{
					fonts =
					{
						fontDir.enable = true;
						fonts = with inputs.pkgs;
							[ noto-fonts source-han-sans source-han-serif source-code-pro hack-font jetbrains-mono nerdfonts ];
						fontconfig.defaultFonts =
						{
							emoji = [ "Noto Color Emoji" ];
							monospace = [ "Noto Sans Mono CJK SC" "Sarasa Mono SC" "DejaVu Sans Mono"];
							sansSerif = [ "Noto Sans CJK SC" "Source Han Sans SC" "DejaVu Sans" ];
							serif = [ "Noto Serif CJK SC" "Source Han Serif SC" "DejaVu Serif" ];
						};
					};
				}
			)
			(
				mkIf services.u2f.enable
				{
					security.pam =
					{
						u2f = { enable = true; cue = true; authFile = ./u2f_keys; };
						services = builtins.listToAttrs (builtins.map (name: { inherit name; value = { u2fAuth = true; }; })
							[ "login" "sudo" "su" "kde" "polkit-1" ]);
					};
				}
			)
			(
				mkIf services.sops.enable
				{
					sops =
					{
						defaultSopsFile = ../../secrets/${inputs.config.networking.hostName}.yaml;
						# sops start before impermanence, so we need to use the absolute path
						age.sshKeyPaths = [ "${services.sops.keyPathPrefix}/etc/ssh/ssh_host_ed25519_key" ];
						gnupg.sshKeyPaths = [ "${services.sops.keyPathPrefix}/etc/ssh/ssh_host_rsa_key" ];
					};
				}
			)
			(
				mkIf services.samba.enable
				{
					# make shares visible for windows 10 clients
					services =
					{
						samba-wsdd.enable = services.samba.wsdd;
						samba =
						{
							enable = true;
							openFirewall = !services.samba.private;
							securityType = "user";
							extraConfig = stripeTabs
							''
								workgroup = WORKGROUP
								server string = Samba Server
								server role = standalone server
								hosts allow = ${services.samba.hostsAllowed}
								dns proxy = no
							'';
							#	obey pam restrictions = yes
							#	encrypt passwords = no
							shares = builtins.listToAttrs (builtins.map
								(share:
								{
									name = share.name;
									value =
									{
										comment = if share.value.comment != null then share.value.comment else share.name;
										path = share.value.path;
										browseable = true;
										writeable = true;
										"create mask" = "664";
										"force create mode" = "644";
										"directory mask" = "2755";
										"force directory mode" = "2755";
									};
								})
								(attrsToList services.samba.shares));
						};
					};
				}
			)
			(
				mkIf services.sshd.enable { services.openssh.enable = true; }
			)
		];
}
