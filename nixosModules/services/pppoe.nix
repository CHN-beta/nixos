# from https://github.com/NixRTR/nixos-router/blob/427da4a8f126b88fab32c7054c5331dab8de42f7/modules/router.nix
{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.pppoe = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          interface = lib.mkOption { type = lib.types.nonEmptyStr; };
        };
      }
    );
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) pppoe;
    in
    lib.mkIf (pppoe != null) {
      environment.systemPackages = [ pkgs.rp-pppoe ];
      services.pppd = {
        enable = true;
        peers.${pppoe.interface} = {
          enable = true;
          autostart = true;
          config = ''
            plugin ${pkgs.rp-pppoe}/lib/rp-pppoe.so
            nic-${pppoe.interface}
            file ${config.nixos.system.sops.templates."pppoe.conf".path}
            noauth
            persist
            maxfail 0
            holdoff 5
            noipdefault
            defaultroute
            replacedefaultroute
            lcp-echo-interval 15
            lcp-echo-failure 3
            usepeerdns
          '';
        };
      };
      nixos.system.sops = {
        templates."pppoe.conf".content = ''
          user "${config.nixos.system.sops.placeholder."pppoe/user"}"
          password "${config.nixos.system.sops.placeholder."pppoe/password"}"
        '';
        secrets = {
          "pppoe/user" = { };
          "pppoe/password" = { };
        };
      };
    };
}
