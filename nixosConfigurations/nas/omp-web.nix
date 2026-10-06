{
  pkgs,
  ...
}:
{
  config = {
    systemd.services.omp-web = {
      description = "omp-web - Browser workspace for oh-my-pi";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        HOME = "/home/straycat";
        PATH = "/etc/profiles/per-user/straycat/bin:/run/current-system/sw/bin";
      };
      serviceConfig = {
        Type = "simple";
        User = "straycat";
        Group = "straycat";
        WorkingDirectory = "/home/straycat";
        ExecStart = "${pkgs.localPkgs.omp-web.backend}/bin/omp-web";
        Restart = "on-failure";
        RestartSec = 5;
      };
      enableDefaultPath = false;
    };
    users.users.nginx.extraGroups = [ "shadow" ];
    # anyway to make it better?
    security.pam.services."nginx-omp".text = ''
      auth required pam_succeed_if.so user in straycat
      auth required pam_unix.so
      account required pam_unix.so
    '';
    nixos.services.nginx.https."omp.chn.moe" = {
      global.extraConfig = ''
        proxy_buffering off;
        proxy_cache off;
        gzip off;
        auth_pam "omp-web";
        auth_pam_service_name "nginx-omp";
      '';
      location = {
        "/api".proxy.upstream = "http://127.0.0.1:30141";
        "/".static = {
          root = "${pkgs.localPkgs.omp-web.ui}";
          index = [ "index.html" ];
          tryFiles = [
            "$uri"
            "$uri/"
            "/index.html"
          ];
        };
      };
    };
  };
}
