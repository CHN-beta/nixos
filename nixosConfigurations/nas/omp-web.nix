{ config, pkgs, ... }:
{
  config = {
    systemd.services.omp-web = {
      description = "ompweb - Browser workspace for oh-my-pi";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        HOME = "/home/straycat";
        PATH = "/etc/profiles/per-user/straycat/bin:/run/current-system/sw/bin";
        OMP_WEB_OMP_BIN = "/etc/profiles/per-user/straycat/bin/omp";
        PI_CODING_AGENT_DIR = "/home/straycat/.omp/agent";
        OMP_WEB_HOSTNAME = "127.0.0.1";
        PORT = "30177";
        OMP_WEB_NO_OPEN = "1";
        OMP_WEB_DISABLE_AUTOUPDATE = "1";
      };
      serviceConfig = {
        Type = "simple";
        User = "straycat";
        Group = "straycat";
        WorkingDirectory = "/home/straycat";
        EnvironmentFile = config.nixos.system.sops.templates."omp-web.env".path;
        ExecStart = "${pkgs.localPkgs.ompweb}/bin/ompweb";
        Restart = "on-failure";
        RestartSec = 5;
      };
      enableDefaultPath = false;
    };
    nixos.system.sops = {
      secrets."omp-web/password" = { };
      templates."omp-web.env".content = ''
        OMP_WEB_PASSWORD=${config.nixos.system.sops.placeholder."omp-web/password"}
      '';
    };
    nixos.services.nginx.https."omp.chn.moe" = {
      global.extraConfig = ''
        proxy_buffering off;
        proxy_cache off;
        gzip off;
      '';
      location."/".proxy.upstream = "http://127.0.0.1:30177";
    };
  };
}
