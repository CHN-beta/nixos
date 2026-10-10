{
  config,
  pkgs,
  lib,
  ...
}:
{
  config =
    let
      mkConfig =
        {
          port,
          user,
          domain,
        }:
        {
          systemd.services."omp-web-${user}" = {
            description = "ompweb - Browser workspace for oh-my-pi";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            environment = {
              HOME = "/home/${user}";
              PATH = "/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin";
              OMP_WEB_OMP_BIN = "/etc/profiles/per-user/${user}/bin/omp";
              PI_CODING_AGENT_DIR = "/home/${user}/.omp/agent";
              OMP_WEB_HOSTNAME = "127.0.0.1";
              PORT = "${toString port}";
              OMP_WEB_NO_OPEN = "1";
              OMP_WEB_DISABLE_AUTOUPDATE = "1";
            };
            serviceConfig = {
              Type = "simple";
              User = "${user}";
              Group = "${user}";
              WorkingDirectory = "/home/${user}";
              EnvironmentFile = config.nixos.system.sops.templates."omp-web-${user}.env".path;
              ExecStart = "${pkgs.localPkgs.ompweb}/bin/ompweb";
              Restart = "on-failure";
              RestartSec = 5;
            };
            enableDefaultPath = false;
          };
          nixos.system.sops = {
            secrets."omp-web/${user}" = { };
            templates."omp-web-${user}.env".content = ''
              OMP_WEB_PASSWORD=${config.nixos.system.sops.placeholder."omp-web/${user}"}
            '';
          };
          nixos.services.nginx.https."${domain}.chn.moe" = {
            global.extraConfig = ''
              proxy_buffering off;
              proxy_cache off;
              gzip off;
            '';
            location."/".proxy.upstream = "http://127.0.0.1:${toString port}";
          };
        };
    in
    [
      {
        port = 30177;
        user = "straycat";
        domain = "omp";
      }
      {
        port = 30178;
        user = "wyh";
        domain = "ompwyh";
      }
    ]
    |> map mkConfig
    |> lib.mkMerge;
}
