{
  lib,
  config,
  pkgs,
  self,
  ...
}:
{
  options.nixos.services.antigravity-route = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) antigravity-route;
      package = pkgs.callPackage self.inputs.antigravity-route { };
    in
    lib.mkIf (antigravity-route != null) {
      systemd.services.antigravity-route = {
        description = "Antigravity Route Service";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          DynamicUser = true;
          StateDirectory = "antigravity-route";
          WorkingDirectory = "/var/lib/antigravity-route";
          ExecStart = "${lib.getExe package} daemon --datadir /var/lib/antigravity-route";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
      environment.systemPackages = [ package ];
    };
}
