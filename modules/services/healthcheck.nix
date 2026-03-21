{ lib, config, pkgs, ... }:
{
  options.nixos.services.healthcheck = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services) healthcheck; in lib.mkIf (healthcheck != null)
  {
    systemd =
    {
      services.healthcheck.serviceConfig =
      {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "healthcheck"
        ''
          uuid="$(cat ${config.nixos.system.sops.secrets.healthcheck.path})"
          ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 10 --retry 5 "https://hc-ping.com/$uuid"
        '';
      };
      timers.healthcheck =
      {
        wantedBy = [ "timers.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        timerConfig = { OnCalendar = "*-*-* *:*:00"; Unit = "healthcheck.service"; };
      };
    };
    nixos.system.sops.secrets.healthcheck = {};
  };
}
