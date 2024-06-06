inputs:
{
  options.nixos.services.nix-serve = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) stripeTabs attrsToList;
      inherit (inputs.config.nixos.services) nix-serve;
      inherit (builtins) map listToAttrs toString;
    in mkIf nix-serve.enable
    {
      services.nix-serve =
      {
        enable = true;
        openFirewall = true;
        secretKeyFile = inputs.config.sops.secrets."store/signingKey".path;
      };
      sops.secrets."store/signingKey" = {};
      nixos.services =
      {
        nginx = { enable = true; https.${nix-serve.hostname}.location."/".proxy.upstream = "http://127.0.0.1:5000"; };
        xray.client.v2ray-forwarder.noproxyTcpPorts = [ 5000 ];
      };
    };
}
