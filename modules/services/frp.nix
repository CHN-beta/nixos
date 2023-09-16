inputs:
{
  options.nixos.services = let inherit (inputs.lib) mkOption types; in
  {
    frpClient =
    {
      enable = mkOption { type = types.bool; default = false; };
      serverName = mkOption { type = types.nonEmptyStr; };
      user = mkOption { type = types.nonEmptyStr; };
      tcp = mkOption
      {
        type = types.attrsOf (types.submodule (inputs:
        {
          options =
          {
            localIp = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
            localPort = mkOption { type = types.ints.unsigned; };
            remoteIp = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
            remotePort = mkOption { type = types.ints.unsigned; default = inputs.config.localPort; };
          };
        }));
        default = {};
      };
    };
    frpServer =
    {
      enable = mkOption { type = types.bool; default = false; };
      serverName = mkOption { type = types.nonEmptyStr; };
    };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.config.nixos.services) frpClient frpServer;
      inherit (builtins) map listToAttrs;
    in mkMerge
    [
      (
        mkIf frpClient.enable
        {
          systemd.services.frpc =
            let
              frpc = "${inputs.pkgs.frp}/bin/frpc";
              config = inputs.config.sops.templates."frpc.ini";
            in
            {
              description = "Frp Client Service";
              after = [ "network.target" ];
              serviceConfig =
              {
                Type = "simple";
                User = "frp";
                Restart = "always";
                RestartSec = "5s";
                ExecStart = "${frpc} -c ${config.path}";
                LimitNOFILE = 1048576;
              };
              wantedBy= [ "multi-user.target" ];
              restartTriggers = [ config.file ];
            };
          sops =
          {
            templates."frpc.ini" =
            {
              owner = inputs.config.users.users.frp.name;
              group = inputs.config.users.users.frp.group;
              content = inputs.lib.generators.toINI {}
              (
                {
                  common =
                  {
                    server_addr = frpClient.serverName;
                    server_port = 7000;
                    token = inputs.config.sops.placeholder."frp/token";
                    user = frpClient.user;
                    tls_enable = true;
                  };
                }
                // (listToAttrs (map
                  (tcp:
                  {
                    name = tcp.name;
                    value =
                    {
                      type = "tcp";
                      local_ip = tcp.value.localIp;
                      local_port = tcp.value.localPort;
                      remote_port = tcp.value.remotePort;
                      use_compression = true;
                    };
                  })
                  (attrsToList frpClient.tcp))
                )
              );
            };
            secrets."frp/token" = {};
          };
          users = { users.frp = { isSystemUser = true; group = "frp"; }; groups.frp = {}; };
        }
      )
      (
        mkIf frpServer.enable
        {
          systemd.services.frps =
            let
              frps = "${inputs.pkgs.frp}/bin/frps";
              config = inputs.config.sops.templates."frps.ini";
            in
            {
              description = "Frp Server Service";
              after = [ "network.target" ];
              serviceConfig =
              {
                Type = "simple";
                User = "frp";
                Restart = "on-failure";
                RestartSec = "5s";
                ExecStart = "${frps} -c ${config.path}";
                LimitNOFILE = 1048576;
              };
              wantedBy= [ "multi-user.target" ];
              restartTriggers = [ config.file ];
            };
          sops =
          {
            templates."frps.ini" =
            {
              owner = inputs.config.users.users.frp.name;
              group = inputs.config.users.users.frp.group;
              content = inputs.lib.generators.toINI {}
              {
                common = let cert = inputs.config.security.acme.certs.${frpServer.serverName}.directory; in
                {
                  bind_port = 7000;
                  bind_udp_port = 7000;
                  token = inputs.config.sops.placeholder."frp/token";
                  tls_cert_file = "${cert}/full.pem";
                  tls_key_file = "${cert}/key.pem";
                  tls_only = true;
                  user_conn_timeout = 30;
                };
              };
            };
            secrets."frp/token" = {};
          };
          nixos.services.acme = { enable = true; certs = [ frpServer.serverName ]; };
          security.acme.certs.${frpServer.serverName}.group = "frp";
          users = { users.frp = { isSystemUser = true; group = "frp"; }; groups.frp = {}; };
          networking.firewall.allowedTCPPorts = [ 7000 ];
        }
      )
    ];
}
