inputs:
{
  options.nixos.packages.ssh = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) ssh; in inputs.lib.mkIf (ssh != null)
  {
    services.openssh.knownHosts =
      let servers =
      {
        vps4 =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIF7Y0tjt1XLPjqJ8HEB26W9jVfJafRQ3pv5AbPaxEc/Z";
          hostnames = [ "vps4.chn.moe" "104.234.37.61" ];
        };
        "initrd.vps4" =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIJkOPTFvX9f+Fn/KHOIvUgoRiJfq02T42lVGQhpMUGJq";
          hostnames = [ "initrd.vps4.chn.moe" "104.234.37.61" ];
        };
        vps6 =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIO5ZcvyRyOnUCuRtqrM/Qf+AdUe3a5bhbnfyhw2FSLDZ";
          hostnames = [ "vps6.chn.moe" "wireguard.vps6.chn.moe" "74.211.99.69" "192.168.83.1" ];
        };
        "initrd.vps6" =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIB4DKB/zzUYco5ap6k9+UxeO04LL12eGvkmQstnYxgnS";
          hostnames = [ "initrd.vps6.chn.moe" "74.211.99.69" ];
        };
        vps7 =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIF5XkdilejDAlg5hZZD0oq69k8fQpe9hIJylTo/aLRgY";
          hostnames = [ "vps7.chn.moe" "wireguard.vps7.chn.moe" "ssh.git.chn.moe" "144.126.144.62" "192.168.83.2" ];
        };
        "initrd.vps7" =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIGZyQpdQmEZw3nLERFmk2tS1gpSvXwW0Eish9UfhrRxC";
          hostnames = [ "initrd.vps7.chn.moe" "144.126.144.62" ];
        };
        nas =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIIktNbEcDMKlibXg54u7QOLt0755qB/P4vfjwca8xY6V";
          hostnames = [ "wireguard.nas.chn.moe" "192.168.1.2" "192.168.83.4" ];
        };
        "initrd.nas" =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIAoMu0HEaFQsnlJL0L6isnkNZdRq0OiDXyaX3+fl3NjT";
          hostnames = [ "initrd.nas.chn.moe" "192.168.1.2" ];
        };
        surface =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIFdm3DcfHdcLP0oSpVrWwIZ/b9lZuakBSPwCFz2BdTJ7";
          hostnames = [ "192.168.1.4" "wireguard.surface.chn.moe" "192.168.83.5" ];
        };
        pc =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIMSfREi19OSwQnhdsE8wiNwGSFFJwNGN0M5gN+sdrrLJ";
          hostnames = [ "wireguard.pc.chn.moe" "[office.chn.moe]:3673" "192.168.1.105" "192.168.83.3" ];
        };
        hpc =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIDVpsQW3kZt5alHC6mZhay3ZEe2fRGziG4YJWCv2nn/O";
          hostnames = [ "hpc.xmu.edu.cn" ];
        };
        github =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
          hostnames = [ "github.com" ];
        };
        xmupc1 =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAINTvfywkKRwMrVp73HfHTfjhac2Tn9qX/lRjLr09ycHp";
          hostnames = [ "[office.chn.moe]:6007" "[xmupc1.chn.moe]:6007" "wireguard.xmupc1.chn.moe" "192.168.83.6" ];
        };
        xmupc2 =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIJZ/+divGnDr0x+UlknA84Tfu6TPD+zBGmxWZY4Z38P6";
          hostnames = [ "[xmupc2.chn.moe]:6394" "wireguard.xmupc2.chn.moe" "192.168.83.7" ];
        };
        srv1-node0 =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIDm6M1D7dBVhjjZtXYuzMj2P1fXNWN3O9wmwNssxEeDs";
          hostnames = [ "srv1.chn.moe" "node0.srv1.chn.moe" "wireguard.node0.srv1.chn.moe" ];
        };
        srv1-node1 =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIIFmG/ZzLDm23NeYa3SSI0a0uEyQWRFkaNRE9nB8egl7";
          hostnames = [ "192.168.178.2" ];
        };
        srv1-node2 =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIDhgEApzHhVPDvdVFPRuJ/zCDiR1K+rD4sZzH77imKPE";
          hostnames = [ "192.168.178.3" ];
        };
        srv1-node3 =
        {
          ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIO/4xbQNz6KNcEdjtBMGY8wUoFK1sCgamKl/r+kVjd7O";
          hostnames = [ "192.168.178.4" ];
        };
      };
      in builtins.listToAttrs (builtins.map
        (server:
        {
          inherit (server) name;
          value =
          {
            publicKey = "ssh-ed25519 ${server.value.ed25519}";
            hostNames = server.value.hostnames;
          };
        })
        (inputs.localLib.attrsToList servers));
    programs.ssh =
    {
      # maybe better network performance
      package = inputs.pkgs.openssh_hpn;
      startAgent = true;
      enableAskPassword = true;
      askPassword = "${inputs.pkgs.systemd}/bin/systemd-ask-password";
      extraConfig = "AddKeysToAgent yes";
    };
    environment.sessionVariables.SSH_ASKPASS_REQUIRE = "prefer";
    nixos.user.sharedModules =
    [(hmInputs: {
      config.programs.ssh =
      {
        enable = true;
        controlMaster = "auto";
        controlPersist = "1m";
        compression = true;
        matchBlocks = builtins.listToAttrs
        (
          (builtins.map
            (host: { name = host; value = { inherit host; hostname = "${host}.chn.moe"; }; })
            [ "vps4" "vps6" "wireguard.vps6" "vps7" "wireguard.vps7" "wireguard.nas" ])
          ++ (builtins.map
            (host: { name = host; value = { inherit host; hostname = "${host}.chn.moe"; forwardX11 = true; }; })
            [ "wireguard.pc" "wireguard.surface" "wireguard.xmupc1" "wireguard.xmupc2" "srv1" "wireguard.srv1" ])
          ++ (builtins.map
            (host:
            {
              name = host;
              value =
              {
                host = host;
                hostname = "hpc.xmu.edu.cn";
                user = host;
                setEnv.TERM = "chn_unset_ls_colors:xterm-256color";
              };
            })
            [ "wlin" "hwang" ])
        )
        // rec {
          xmupc1 = { host = "xmupc1"; hostname = "xmupc1.chn.moe"; port = 6007; forwardX11 = true; };
          xmupc2 = { host = "xmupc2"; hostname = "xmupc2.chn.moe"; port = 6394; forwardX11 = true; };
          nas = { host = "nas"; hostname = "192.168.1.2"; forwardX11 = true; };
          pc = { host = "pc"; hostname = "192.168.1.3"; forwardX11 = true; };
          surface = { host = "surface"; hostname = "192.168.1.4"; forwardX11 = true; };
          gitea = { host = "gitea"; hostname = "ssh.git.chn.moe"; };
          jykang =
          {
            host = "jykang";
            hostname = "hpc.xmu.edu.cn";
            user = "jykang";
            forwardAgent = true;
            extraOptions.AddKeysToAgent = "yes";
          };
          "wireguard.jykang" = jykang // { host = "wireguard.jykang"; proxyJump = "wireguard.xmupc1"; };
          srv1-node1 = { host = "srv1-node1"; hostname = "192.168.178.2"; proxyJump = "srv1"; };
          srv1-node2 = { host = "srv1-node2"; hostname = "192.168.178.3"; proxyJump = "srv1"; };
          srv1-node3 = { host = "srv1-node3"; hostname = "192.168.178.4"; proxyJump = "srv1"; };
        };
      };
    })];
  };
}
