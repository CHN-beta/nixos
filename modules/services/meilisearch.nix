inputs:
{
	options.nixos.services.meilisearch = let inherit (inputs.lib) mkOption types; in
	{
		enable = mkOption { type = types.bool; default = false; };
	};
	config =
		let
			inherit (inputs.config.nixos.services) meilisearch;
			inherit (inputs.lib) mkMerge mkAfter concatStringsSep mkIf;
			inherit (inputs.localLib) stripeTabs attrsToList;
			inherit (builtins) map listToAttrs filter;
		in mkIf meilisearch.enable
		{
			services.meilisearch =
			{
				enable = true;
				listenAddress = "0.0.0.0";
				noAnalytics = false;
				environment = "production";
				masterKeyEnvironmentFile = inputs.sops.template."meilisearch-env".path;
			};
			sops =
			{
				template."meilisearch-env".content = "MEILI_MASTER_KEY=${inputs.sops.placeholder.meilisearch}";
				secrets.meilisearch = {};
			};
		};
}
