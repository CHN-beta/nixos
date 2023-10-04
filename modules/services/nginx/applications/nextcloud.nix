inputs:
{
  options.nixos.services.nginx.applications.nextcloud = let inherit (inputs.lib) mkOption types; in
  {
    instance.enable = mkOption
    {
      type = types.addCheck types.bool (value: value -> inputs.config.nixos.services.nextcloud.enable);
      default = false;
    };
    proxy =
    {
      enable = mkOption
      {
        type = types.addCheck types.bool
          (value: value -> !inputs.config.nixos.services.nginx.applications.nextcloud.instance.enable);
        default = false;
      };
      upstream = mkOption { type = types.nonEmptyStr; };
    };
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications) nextcloud;
      inherit (inputs.lib) mkIf mkMerge;
      inherit (inputs.localLib) attrsToList;
      inherit (builtins) map listToAttrs;
    in mkMerge
    [
      (mkIf (nextcloud.instance.enable)
      {
        nixos.services.nginx.http.${inputs.config.nixos.services.nextcloud.hostname}.rewriteHttps = true;
        services.nginx.virtualHosts.${inputs.config.nixos.services.nextcloud.hostname} = mkMerge
        [
          (inputs.config.services.nextcloud.nginx.recommendedConfig { upstream = "127.0.0.1"; })
          { listen = [ { addr = "0.0.0.0"; port = 8417; ssl = true; extraParameters = [ "proxy_protocol" ]; } ]; }
        ];
      })
      (mkIf (nextcloud.proxy.enable)
      {
        nixos.services.nginx.streamProxy.map.${inputs.config.nixos.services.nextcloud.hostname} =
        {
          upstream = "${nextcloud.proxy.upstream}:8417";
          rewriteHttps = true;
          proxyProtocol = true;
        };
      })
    ];
}
