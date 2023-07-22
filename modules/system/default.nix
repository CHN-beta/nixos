inputs:
{
	options.nixos.system = let inherit (inputs.lib) mkOption types; in
	{
		hostname = mkOption { type = types.nonEmptyStr; };
    march = mkOption { type = types.nullOr types.nonEmptyStr; };
	};
	config = let inherit (inputs.lib) mkMerge mkIf; inherit (inputs.localLib) mkConditional stripeTabs; in mkMerge
	[
    # generic
    {
      systemd.services =
      {
        nix-daemon = { environment = { TMPDIR = "/var/cache/nix"; }; serviceConfig = { CacheDirectory = "nix"; }; };
        systemd-tmpfiles-setup = { environment = { SYSTEMD_TMPFILES_FORCE_SUBVOL = "0"; }; };
      };
      nix.settings.system-features = [ "nixos-test" "benchmark" ];
      services.udev.extraRules = stripeTabs
			''
				ACTION=="add|change", KERNEL=="[sv]d[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
				ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
			'';
      networking.networkmanager.enable = true;
    }
    # hostname
    { networking.hostName = inputs.config.nixos.system.hostname; }
    # march
    (
      mkConditional (inputs.config.nixos.system.march != null)
        {
          nixpkgs =
          {
            hostPlatform = { system = "x86_64-linux"; gcc =
              { arch = inputs.config.nixos.system.march; tune = inputs.config.nixos.system.march; }; };
            config.qchem-config.optArch = inputs.config.nixos.system.march;
          };
          nix.settings.system-features = [ "gccarch-${inputs.config.nixos.system.march}" ];
          boot.kernelPatches =
          [{
            name = "native kernel";
            patch = null;
            extraStructuredConfig =
            {
              GENERIC_CPU = inputs.lib.kernel.no;
              "M${inputs.lib.strings.toUpper inputs.config.nixos.system.march}" = inputs.lib.kernel.yes;
            };
          }];
        }
        { nixpkgs.hostPlatform = inputs.lib.mkDefault "x86_64-linux"; }
    )
  ];
}
