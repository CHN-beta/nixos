{
  config,
  ...
}:
{
  config = {
    services.niks3-auto-upload = {
      enable = true;
      serverUrl = "https://nixcache.chn.moe";
      authTokenFile = config.nixos.system.sops.secrets."niks3/token".path;
    };
    nixos.system.sops.secrets."niks3/token" = { };
  };
}
