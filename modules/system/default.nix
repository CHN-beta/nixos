inputs:
{
	options.nixos.system = let inherit (inputs.lib) mkOption types; in
	{
		hostname = mkOption { type = types.nonEmptyStr; };
	};
	config = let inherit (inputs.lib) mkMerge mkIf; inherit (inputs.localLib) mkConditional; in mkMerge
	[
    { networking.hostName = inputs.config.nixos.system.hostname; }
  ];
}
