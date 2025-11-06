inputs:
{
  options.nixos.services.derp = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "derp.headscale.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) derp; in inputs.lib.mkIf (derp != null)
  {
    services.tailscale.derper =
    {
      enable = true;
      domain = derp.hostname;
      configureNginx = false;
      # TODO: set after tailscale works
      # verifyClients = true;
    };
    nixos.services.nginx =
    {
      https.${derp.hostname} =
      {
        global =
        {
          rewriteHttps = false;
          extraConfig =
          ''
            proxy_buffering off;
            proxy_read_timeout 3600s;
          '';
        };
        location."/".proxy =
        {
          upstream = "http://127.0.0.1:${builtins.toString inputs.config.services.tailscale.derper.port}";
          websocket = true;
        };
      };
      http.${derp.hostname}.proxy.upstream =
        "http://127.0.0.1:${builtins.toString inputs.config.services.tailscale.derper.port}";
    };
  };
}
