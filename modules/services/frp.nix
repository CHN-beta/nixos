# TODO: update to json config at 23.11
# TODO: switch to module in nixpkgs
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
      stcp = mkOption
      {
        type = types.attrsOf (types.submodule (inputs:
        {
          options =
          {
            localIp = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
            localPort = mkOption { type = types.ints.unsigned; };
          };
        }));
        default = {};
      };
      stcpVisitor = mkOption
      {
        type = types.attrsOf (types.submodule (inputs:
        {
          options =
          {
            localIp = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
            localPort = mkOption { type = types.ints.unsigned; };
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
      inherit (inputs.lib.strings) splitString;
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
              config = inputs.config.sops.templates."frpc.json";
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
            templates."frpc.json" =
            {
              owner = inputs.config.users.users.frp.name;
              group = inputs.config.users.users.frp.group;
              content = builtins.toJSON
              {
                auth.token = inputs.config.sops.placeholder."frp/token";
                user = frpClient.user;
                serverAddr = frpClient.serverName;
                serverPort = 7000;
                proxies =
                (map
                  (tcp:
                  {
                    name = tcp.name;
                    type = "tcp";
                    transport.useCompression = true;
                    inherit (tcp.value) localIp localPort remotePort;
                  })
                  (attrsToList frpClient.tcp))
                ++ (map
                  (stcp:
                  {
                    name = stcp.name;
                    type = "stcp";
                    transport.useCompression = true;
                    secretKey = inputs.config.sops.placeholder."frp/stcp/${stcp.name}";
                    inherit (stcp.value) localIp localPort;
                  })
                  (attrsToList frpClient.stcp));
                visitors = map
                  (stcp:
                  {
                    name = stcp.name;
                    type = "stcp";
                    transport = { useCompression = true; tls.enable = true; };
                    secretKey = inputs.config.sops.placeholder."frp/stcp/${stcp.name}";
                    serverUser = builtins.elemAt (splitString "." stcp.name) 0;
                    serverName = builtins.elemAt (splitString "." stcp.name) 1;
                    bindAddr = stcp.value.localIp;
                    bindPort = stcp.value.localPort;
                  })
                  (attrsToList frpClient.stcpVisitor);
              };
            };
            secrets = listToAttrs
            (
              [{ name = "frp/token"; value = {}; }]
              ++ (map
                (stcp: { name = "frp/stcp/${stcp.name}"; value = {}; })
                (attrsToList (with frpClient; stcp // stcpVisitor)))
            );
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
              config = inputs.config.sops.templates."frps.json";
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
            templates."frps.json" =
            {
              owner = inputs.config.users.users.frp.name;
              group = inputs.config.users.users.frp.group;
              content = builtins.toJSON
              {
                auth.token = inputs.config.sops.placeholder."frp/token";
                transport.tls = let cert = inputs.config.security.acme.certs.${frpServer.serverName}.directory; in
                {
                  force = true;
                  certFile = "${cert}/full.pem";
                  keyFile = "${cert}/key.pem";
                  serverName = frpServer.serverName;
                };
              };
            };
            secrets."frp/token" = {};
          };
          nixos.services.acme = { enable = true; cert.${frpServer.serverName}.group = "frp"; };
          users = { users.frp = { isSystemUser = true; group = "frp"; }; groups.frp = {}; };
          networking.firewall.allowedTCPPorts = [ 7000 ];
        }
      )
    ];
}
