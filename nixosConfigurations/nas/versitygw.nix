{
  config,
  lib,
  pkgs,
  ...
}:
{
  nixos.system.sops = {
    secrets."versitygw/secret" = { };
    templates."versitygw.env".content = ''
      ROOT_SECRET_ACCESS_KEY=${config.nixos.system.sops.placeholder."versitygw/secret"}
    '';
  };
  systemd.services.versitygw = {
    description = "Versity S3 Gateway";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ config.nixos.system.sops.templates."versitygw.env".content ];
    environment = {
      VGW_PORT = "127.0.0.1:7070";
      VGW_REGION = "us-east-1";
      ROOT_ACCESS_KEY_ID = "versitygw";
    };
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.versitygw} posix /var/lib/versitygw";
      EnvironmentFile = config.nixos.system.sops.templates."versitygw.env".path;
      DynamicUser = true;
      StateDirectory = [ "versitygw" ];
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
