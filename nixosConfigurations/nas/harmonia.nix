{ config, ... }: {
  config = {
    services.harmonia.cache = {
      enable = true;
      signKeyPaths = [ config.nixos.system.sops.secrets."store/signingKey".path ];
      settings.bind = "127.0.0.1:4999";
    };
    nixos = {
      system.sops.secrets."store/signingKey" = { };
      services.nginx.https."nixcache.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:4999";
    };
  };
}
