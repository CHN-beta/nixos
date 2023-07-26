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
	};
	config = let inherit (inputs.lib) mkMerge mkIf; inherit (inputs.localLib) stripeTabs attrsToList; in mkMerge
	[
		(
			mkIf inputs.config.nixos.services.impermanence.enable
			{
				environment.persistence."${inputs.config.nixos.services.impermanence.persistence}" =
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
      mkIf inputs.config.nixos.services.snapper.enable
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
            builtins.listToAttrs (builtins.map f (attrsToList inputs.config.nixos.services.snapper.configs));
      }
    )
		(
			mkIf inputs.config.nixos.services.kmscon.enable
			{
				services.kmscon =
				{
					enable = true;
					fonts = [{ name = "FiraCode Nerd Font Mono"; package = inputs.pkgs.nerdfonts; }];
				};
			}
		)
		(
			mkIf inputs.config.nixos.services.fontconfig.enable
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
  ];
}
